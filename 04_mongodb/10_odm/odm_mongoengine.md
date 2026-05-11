# ODM with MongoEngine (`10_odm`)

> Translation / Переклад: [Українська](../../i18n/uk/04_mongodb/10_odm/odm_mongoengine.md)

These exercises walk through the **CRUD lifecycle** through an ODM — **MongoEngine** — instead of raw PyMongo. You define a Python class that mirrors the document shape, save instances of it, query through `Objects.objects`, then update and delete by predicate. Each exercise targets one step of the cycle.

Runnable companion file: [`10_odm/example.py`](example.py). The script drops the collection on every run so the captured output is deterministic.

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/example.py
```

Default connection (override with env vars):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Collection: `odm_products`

## Submodules (see their own lessons)

- [`01_selection_operators/`](01_selection_operators/) — `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$nin`, `$and`, `$or`, `$not`, `$exists`, `$regex` via MongoEngine `Q`.
- [`02_search_sorting_pagination/`](02_search_sorting_pagination/) — Motor + FastAPI + Pydantic for search, sorting, pagination.
- [`03_indexes/`](03_indexes/) — Motor + Python index creation, listing and dropping.
- [`04_agregation_functions/`](04_agregation_functions/) — Motor aggregation pipelines with `$group`, `$sum`, `$avg`, `$count`, `$max`, `$min`, `$match`, `$sort`, `$project`.

---

## Document model

```python
from datetime import datetime
from mongoengine import DateTimeField, Document, IntField, StringField, connect

class Product(Document):
    name = StringField(required=True, max_length=128)
    category = StringField(required=True, max_length=64)
    price = IntField(required=True, min_value=0)
    created_at = DateTimeField(default=datetime.utcnow)

    meta = {"collection": "odm_products"}
```

Initial seed (the script reuses `Product.drop_collection()` first to start clean):

| `name` | `category` | `price` |
|---|---|---|
| iPhone 14 | Smartphone | 899 |
| MacBook Air | Laptop | 1299 |
| Galaxy S23 | Smartphone | 799 |

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | The CRM use-case that motivates this step. |
| **What you'll learn** | The MongoEngine method and the underlying driver call. |
| **Document in play** | The fields touched. |
| **Task** | The concrete instruction. |
| **Expected result** | Real captured output. |
| **Hint** | The MongoEngine method name. |
| **Solution** | MongoEngine and `mongosh` versions. |
| **Step-by-step explanation** | How the ODM rewrites it and the typical mistakes. |

---

## Exercise 1 — Define the model and connect

### Context

Before any I/O, the application has to declare what a `Product` *is* and connect to MongoDB. The class becomes the source of truth — every field is validated and every save round-trips through it.

### What you'll learn

- Subclassing `Document` and declaring fields with constraints (`required`, `max_length`, `min_value`).
- The `meta = {"collection": "..."}` to pin the collection name.
- `connect(db=..., host=...)` to register a default alias.

### Document in play

| Field | Type | Constraint |
|---|---|---|
| `name` | string | `required`, `max_length=128` |
| `category` | string | `required`, `max_length=64` |
| `price` | int | `required`, `min_value=0` |
| `created_at` | datetime | `default=datetime.utcnow` |

### Task

Define the `Product` model, then `connect` to `mongodb://localhost:27017` against the `edu_academy_seed` database.

### Expected result

No printed output — the connection is silent if it succeeds. The next exercise prints rows after we've saved them.

### Hint

`connect(db=..., host=...)` returns immediately with a lazy connection; the actual TCP handshake happens on the first read/write.

### Solution

```python
import os
from datetime import datetime
from mongoengine import DateTimeField, Document, IntField, StringField, connect

MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB  = os.getenv("MONGODB_DB", "edu_academy_seed")

class Product(Document):
    name = StringField(required=True, max_length=128)
    category = StringField(required=True, max_length=64)
    price = IntField(required=True, min_value=0)
    created_at = DateTimeField(default=datetime.utcnow)

    meta = {"collection": "odm_products"}

connect(db=MONGODB_DB, host=MONGODB_URI)
```

```javascript
// mongosh equivalent: no model class, just choose the database
use("edu_academy_seed");
db.odm_products.findOne();
```

### Step-by-step explanation

1. **`StringField(required=True, max_length=128)`** is validated **client-side** by MongoEngine before sending the insert. If `name` is missing or too long, `.save()` raises `ValidationError` *before* hitting MongoDB.
2. **`IntField(min_value=0)`** rejects negative prices the same way.
3. **`DateTimeField(default=datetime.utcnow)`** stores the current UTC time when the document is created; pass `default=datetime.utcnow` (not `default=datetime.utcnow()`) — the function reference, not the call.
4. **`meta = {"collection": "odm_products"}`** locks the collection name. Without it MongoEngine would derive `product` from the class name.
5. **`connect()` is idempotent and supports aliases.** Multiple databases? Call it twice with `alias="other"` and refer to it via `meta = {"db_alias": "other"}`.

---

## Exercise 2 — Create (`.save()`)

### Context

A back-office form submits three new products. Each instance is built in Python, then persisted with `.save()` — there's no SQL `INSERT` to write.

### What you'll learn

- The Active Record pattern: construct → `.save()` → persisted.
- That `.save()` runs validators first.
- That a fresh document gets a generated `_id` after `.save()`.

### Document in play

| Field | Type | Notes |
|---|---|---|
| All | — | Every field assigned. |

### Task

Drop the collection (to keep the run deterministic), then save three products.

### Expected result

The next exercise reads them back. Right now `Product.objects.count()` returns `3`.

### Hint

`Product(name=..., category=..., price=...).save()` for each row.

### Solution

```python
Product.drop_collection()

Product(name="iPhone 14",   category="Smartphone", price=899).save()
Product(name="MacBook Air", category="Laptop",    price=1299).save()
Product(name="Galaxy S23",  category="Smartphone", price=799).save()
```

```javascript
db.odm_products.deleteMany({});
db.odm_products.insertMany([
  { name: "iPhone 14",   category: "Smartphone", price: 899,  created_at: new Date() },
  { name: "MacBook Air", category: "Laptop",    price: 1299, created_at: new Date() },
  { name: "Galaxy S23",  category: "Smartphone", price: 799,  created_at: new Date() }
]);
```

### Step-by-step explanation

1. **Validators run on `.save()`** — not on `__init__`. You can construct an invalid `Product`; it only blows up when you persist.
2. **`Product.drop_collection()`** wipes both the documents and the indexes the model declared. Reset for a clean state.
3. **The `_id` is assigned post-save.** `p = Product(...); p.save(); print(p.id)` will print a fresh `ObjectId`.
4. **Bulk insert with `Product.objects.insert([...])`.** Faster than three `.save()` calls — single round-trip.

---

## Exercise 3 — Read all + sort (`Product.objects.order_by("name")`)

### Context

The "All products" page lists every row sorted alphabetically.

### What you'll learn

- Iterating `Product.objects` returns model instances, not dicts.
- `order_by("field")` ascending; `order_by("-field")` descending.
- `count()` for the matching count.

### Document in play

| Field | Type | Notes |
|---|---|---|
| All | — | Returned. |

### Task

Read every product, sorted by `name` ascending, and print "name | category | price" lines.

### Expected result

```text
All products count: 3
  Galaxy S23 | Smartphone | 799
  MacBook Air | Laptop | 1299
  iPhone 14 | Smartphone | 899
```

(MongoDB sorts uppercase ASCII before lowercase — so `iPhone 14` comes after `MacBook Air`.)

### Hint

`Product.objects.order_by("name")`.

### Solution

```python
all_docs = Product.objects.order_by("name")
print(f"All products count: {all_docs.count()}")
for doc in all_docs:
    print(f"  {doc.name} | {doc.category} | {doc.price}")
```

```javascript
db.odm_products.find({}).sort({ name: 1 });
db.odm_products.countDocuments({});
```

### Step-by-step explanation

1. **`Product.objects` is a lazy QuerySet.** Nothing hits MongoDB until you iterate, call `.count()`, slice, or coerce to a list.
2. **`order_by("name")` returns a *new* QuerySet** — querysets are immutable, like Django's.
3. **Sorting case sensitivity.** MongoDB sorts by raw BSON byte order by default. For locale-aware ordering, declare a collation: `Product.objects.order_by("name").collation({"locale": "en", "strength": 2})`.
4. **`.count()` runs a separate `countDocuments`.** Two round-trips: one for the count, one to fetch — see lesson `02_search_sorting_pagination` for the same trade-off.

---

## Exercise 4 — Filter (`Product.objects(category="Smartphone")`)

### Context

A category page only shows smartphones, and the storefront prefers the most expensive first.

### What you'll learn

- Keyword-argument filters (`category="Smartphone"`) are the ODM analogue of `find({"category": "Smartphone"})`.
- Reverse sort by prefixing the field with `-` (`order_by("-price")`).

### Document in play

| Field | Type | Notes |
|---|---|---|
| `category` | string | Filter. |
| `price` | int | Sort. |

### Task

Find every product with `category == "Smartphone"`, sort by `price` descending.

### Expected result

```text
Smartphones count: 2
  iPhone 14 | 899
  Galaxy S23 | 799
```

### Hint

`Product.objects(category="Smartphone").order_by("-price")`.

### Solution

```python
phones = Product.objects(category="Smartphone").order_by("-price")
print(f"Smartphones count: {phones.count()}")
for doc in phones:
    print(f"  {doc.name} | {doc.price}")
```

```javascript
db.odm_products
  .find({ category: "Smartphone" })
  .sort({ price: -1 });
```

### Step-by-step explanation

1. **Multiple kwargs are AND-ed.** `Product.objects(category="Smartphone", price__gt=800)` matches both predicates.
2. **`-price`** is MongoEngine's shorthand for `("price", -1)`.
3. **Chaining is fine.** `Product.objects(...).order_by(...).limit(5)` reads naturally.

---

## Exercise 5 — Update (`.update_one(set__price=...)`)

### Context

The price of `iPhone 14` is being slashed from 899 to 849. The change must be atomic — we can't temporarily corrupt the row.

### What you'll learn

- `Product.objects(filter).update_one(set__field=value)` for partial updates.
- The MongoEngine kwarg syntax `set__field` for `$set: {field: value}`.

### Document in play

| Field | Type | Notes |
|---|---|---|
| `price` | int | Updated. |

### Task

Update the price of `iPhone 14` to `849`, then re-read and verify.

### Expected result

```text
Updated iPhone 14 price: 849
```

### Hint

`Product.objects(name="iPhone 14").update_one(set__price=849)`.

### Solution

```python
Product.objects(name="iPhone 14").update_one(set__price=849)
iphone = Product.objects.get(name="iPhone 14")
print(f"Updated iPhone 14 price: {iphone.price}")
```

```javascript
db.odm_products.updateOne(
  { name: "iPhone 14" },
  { $set: { price: 849 } }
);
db.odm_products.findOne({ name: "iPhone 14" }, { _id: 0, price: 1 });
```

### Step-by-step explanation

1. **`set__price=849`** is rewritten by MongoEngine to `{$set: {price: 849}}`. The double underscore is the operator delimiter (like in selection: `__gt`, `__ne`).
2. **Other update operators are similar.** `inc__price=10` → `{$inc: {price: 10}}`; `push__tags="new"` → `{$push: {tags: "new"}}`; `pull__tags="old"` → `{$pull: {tags: "old"}}`.
3. **`update_one`** modifies at most one document. `update()` (alias `update_many`) modifies all matches.
4. **Validators run on save, not on update.** A raw `update_one(set__price=-100)` will succeed *despite* `IntField(min_value=0)` — the validator only fires through `.save()`. If full validation matters, do `obj.price = -100; obj.save()` (and catch `ValidationError`).
5. **`Product.objects.get()`** raises `DoesNotExist` if zero rows match, and `MultipleObjectsReturned` if more than one.

---

## Exercise 6 — Delete (`.delete()`)

### Context

`Galaxy S23` was discontinued — the row is removed from the catalogue.

### What you'll learn

- `Product.objects(filter).delete()` returns the number of rows removed.
- That `.delete()` is destructive and unconfirmed — wrap it in transactions for production code.

### Document in play

| Field | Type | Notes |
|---|---|---|
| All | — | Document removed. |

### Task

Delete the `Galaxy S23` row and verify there are now two products remaining.

### Expected result

```text
Remaining after delete: 2
```

### Hint

`Product.objects(name="Galaxy S23").delete()` then `Product.objects.count()`.

### Solution

```python
Product.objects(name="Galaxy S23").delete()
print(f"Remaining after delete: {Product.objects.count()}")
```

```javascript
db.odm_products.deleteOne({ name: "Galaxy S23" });
db.odm_products.countDocuments({});
```

### Step-by-step explanation

1. **Empty filter = "delete everything".** `Product.objects().delete()` empties the collection (no `_id_` filter required).
2. **Soft-delete pattern.** Most production code adds a `is_deleted = BooleanField(default=False)` and filters it out — the database row stays for audits.
3. **`delete()` does *not* run signals by default** unless you wire them up via MongoEngine's `signals` module. If you have cascade rules to enforce, they belong in a service layer or a `pre_delete` signal handler.
4. **`Product.objects.count()` returns the new total.** A fresh count avoids the off-by-one bug of "subtract one from the previous count" if a parallel writer also changed the collection.

---

## Quick reference

| Operation | MongoEngine | Raw mongosh |
|---|---|---|
| Connect | `connect(db=..., host=...)` | `use("edu_academy_seed")` |
| Insert one | `Product(...).save()` | `db.coll.insertOne({...})` |
| Read all | `Product.objects` | `db.coll.find({})` |
| Filter | `Product.objects(field=value)` | `db.coll.find({field: value})` |
| Sort | `.order_by("name")` / `"-name"` | `.sort({name: 1})` / `{name: -1}` |
| Update one | `.update_one(set__field=value)` | `db.coll.updateOne(filter, {$set: {...}})` |
| Delete | `.delete()` | `db.coll.deleteOne(...)` |
| Count | `.count()` | `db.coll.countDocuments({...})` |
| Get one (or raise) | `.objects.get(field=value)` | `db.coll.findOne({field: value})` |

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `ValidationError` on `.save()` | Required field missing or constraint violated. Inspect `e.errors` for details. |
| `DoesNotExist` from `.get()` | No document matched. Use `.first()` to get `None` instead. |
| Update doesn't run validators | True by design. Use `.save()` for full validation. |
| Sorting puts lowercase last | Default BSON sort is ASCII-byte-based. Add a `collation`. |
| `MongoEngineConnectionError: You have not defined a default connection` | You forgot `connect(...)` or used the wrong alias. |
| Index not picked up | MongoEngine `meta = {"indexes": [...]}` creates them lazily — call `Product.ensure_indexes()` once at startup. |
