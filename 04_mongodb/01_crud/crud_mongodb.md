# CRUD in MongoDB (`01_crud`)

> Translation / Переклад: [Українська](../../i18n/uk/04_mongodb/01_crud/crud_mongodb.md)

These exercises walk through the **eight core CRUD operations** in MongoDB using **PyMongo** (Python) and the equivalent **mongosh** (JavaScript) commands. All examples run against the practice database `edu_academy_seed` and the collection **`products`**.

Runnable companion file: [`01_crud/example.py`](example.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/01_crud/example.py
```

Default connection settings (overridable via env vars):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

The script resets the collection with `delete_many({})` at the start of each run, so every exercise below produces deterministic, repeatable output.

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real catalog/admin app would run this operation. |
| **What you'll learn** | The PyMongo/mongosh constructs trained here. |
| **Collection in play** | Documents and fields actually touched. |
| **Task** | Concrete requirement (the exact filter/update/delete). |
| **Expected result** | Real output captured from a live `python example.py` run. |
| **Hint** | A single nudge toward the right method. |
| **Solution** | Working Python (PyMongo) **and** equivalent mongosh JavaScript. |
| **Step-by-step explanation** | What each part does and the BSON / `$set` / `_id` gotchas. |

---

## Map: SQL ↔ MongoDB CRUD operations

| Operation | SQL style | MongoDB / PyMongo |
|---|---|---|
| Add one record | `INSERT INTO products VALUES (...);` | `insert_one({...})` |
| Add many records | `INSERT INTO products VALUES (...), (...);` | `insert_many([{...}, {...}])` |
| Update one record | `UPDATE products SET ... WHERE ... LIMIT 1;` | `update_one({...}, {"$set": {...}})` |
| Update all matching | `UPDATE products SET ... WHERE ...;` | `update_many({...}, {"$set": {...}})` |
| Delete one record | `DELETE FROM products WHERE ... LIMIT 1;` | `delete_one({...})` |
| Delete all matching | `DELETE FROM products WHERE ...;` | `delete_many({...})` |
| Clear collection | `DELETE FROM products;` | `delete_many({})` |
| Drop collection | `DROP TABLE products;` | `drop()` |

## Collection schema

The `products` collection used here is intentionally small and flat:

```json
{ "_id": ObjectId("..."), "name": "iPhone 14", "category": "Phone", "price": 999 }
```

| Field | BSON type | Notes |
|---|---|---|
| `_id` | `ObjectId` | Server-generated unless you pass one explicitly. |
| `name` | `string` | Used as the natural key in update/delete filters below. |
| `category` | `string` | Sample values: `Phone`, `Laptop`, `Smartphone`. |
| `price` | `int` | Stored as a BSON 32-bit integer (Python `int`). |

---

## Exercise 1 — `insert_one` (add a single record)

### Context

The catalog editor publishes a brand-new SKU — only one document, and we want the generated `_id` back so the admin UI can show a confirmation link.

### What you'll learn

- Calling `insert_one` with a single document.
- That MongoDB auto-generates an `ObjectId` for `_id` if you don't supply one.
- The PyMongo `InsertOneResult` object (`.inserted_id`).

### Collection in play

| Collection | Fields written |
|---|---|
| `products` | `name`, `category`, `price` |

### Task

Insert one product `{ "name": "iPhone 14", "category": "Phone", "price": 999 }` into the empty `products` collection.

### Expected result

```text
After INSERT operations:
  name=iPhone 14, category=Phone, price=999
  ...
```

(real output from `python 04_mongodb/01_crud/example.py`, captured after step 2 — the script first inserts the one document, then three more in Exercise 2, then prints the four).

### Hint

`insert_one({...})` takes the **document** directly (not a list).

### Solution

```python
from pymongo import MongoClient

client = MongoClient("mongodb://localhost:27017")
products = client["edu_academy_seed"]["products"]

result = products.insert_one(
    {"name": "iPhone 14", "category": "Phone", "price": 999}
)
print(result.inserted_id)
```

```javascript
use edu_academy_seed
db.products.insertOne({ name: "iPhone 14", category: "Phone", price: 999 })
```

### Step-by-step explanation

1. **`insert_one`** receives a single dict — passing a list raises `TypeError`. Use `insert_many` for lists.
2. The **`_id` field is auto-generated** server-side as an `ObjectId` (a 12-byte BSON value). You can verify this with `result.inserted_id` in PyMongo or by reading the returned doc's `_id` in mongosh.
3. **Field order is preserved** in BSON, but you should never rely on it for queries — Mongo addresses fields by name.
4. **Numbers**: `999` in Python is sent as a 32-bit `Int32`. A Python `float` (e.g. `999.0`) would land as `Double`, which can affect `$type` queries later (see lesson `05_check_operators`).

---

## Exercise 2 — `insert_many` (bulk add)

### Context

We just imported three SKUs from the supplier's CSV. One round-trip with a batched write is much cheaper than three individual `insert_one` calls.

### What you'll learn

- Sending a list of documents in one network call.
- The returned `InsertManyResult.inserted_ids` (list, in insertion order).
- Why batched writes are dramatically faster than a Python loop.

### Collection in play

| Collection | Fields written |
|---|---|
| `products` | `name`, `category`, `price` |

### Task

After the single insert above, add three more documents in one call: `Galaxy S23` ($899, Phone), `MacBook Air` ($1299, Laptop), `Pixel 8` ($799, Phone).

### Expected result

```text
After INSERT operations:
  name=iPhone 14, category=Phone, price=999
  name=Galaxy S23, category=Phone, price=899
  name=MacBook Air, category=Laptop, price=1299
  name=Pixel 8, category=Phone, price=799
```

### Hint

`insert_many([...])` takes a **list** of documents. Returns one `_id` per inserted doc.

### Solution

```python
products.insert_many([
    {"name": "Galaxy S23", "category": "Phone", "price": 899},
    {"name": "MacBook Air", "category": "Laptop", "price": 1299},
    {"name": "Pixel 8", "category": "Phone", "price": 799},
])
```

```javascript
db.products.insertMany([
  { name: "Galaxy S23", category: "Phone", price: 899 },
  { name: "MacBook Air", category: "Laptop", price: 1299 },
  { name: "Pixel 8", category: "Phone", price: 799 }
])
```

### Step-by-step explanation

1. **One network round-trip** sends the whole batch. For thousands of rows, `insert_many` beats a loop of `insert_one` by 10-100×.
2. **`ordered=True` is the default.** If document #2 fails (duplicate `_id`, schema violation, etc.), documents #3+ are skipped. Pass `ordered=False` to keep going on errors and collect them at the end.
3. **Empty list raises** `InvalidOperation`. Always check `len(docs) > 0` before calling.
4. The returned **`inserted_ids` is positionally aligned** with the input list — index `i` corresponds to docs[i].

---

## Exercise 3 — `update_one` (modify a single doc)

### Context

The marketing team approved a price drop for the iPhone 14 only. We need to change exactly one document — the rest of the catalog must stay untouched.

### What you'll learn

- Using `update_one` with a filter and an update operator.
- The mandatory `$set` operator for partial updates.
- The `UpdateResult` fields: `matched_count` vs `modified_count`.

### Collection in play

| Collection | Filter field | Updated field |
|---|---|---|
| `products` | `name` | `price` |

### Task

Set `price = 899` on the document where `name == "iPhone 14"`.

### Expected result

```text
update_one matched=1, modified=1
```

### Hint

You **must** wrap the change in `{"$set": {...}}`. Passing the raw `{"price": 899}` as the second argument fails (or — worse — replaces the whole document in older drivers).

### Solution

```python
result = products.update_one(
    {"name": "iPhone 14"},
    {"$set": {"price": 899}},
)
print(f"matched={result.matched_count}, modified={result.modified_count}")
```

```javascript
db.products.updateOne(
  { name: "iPhone 14" },
  { $set: { price: 899 } }
)
```

### Step-by-step explanation

1. **First argument is the filter** — same shape as a `find()` query. If multiple documents match, only the **first one encountered** is updated (storage order, not stable).
2. **Second argument is the update specification**, which must start with an operator (`$set`, `$inc`, `$unset`, …). Without the operator, PyMongo 4+ raises `WriteError`.
3. **`matched_count`** is how many docs satisfied the filter; **`modified_count`** is how many actually changed. If the new value equals the old one, you'll see `matched=1, modified=0` — useful for detecting no-op updates.
4. To **insert if missing**, pass `upsert=True`; the result will then expose `.upserted_id`.

---

## Exercise 4 — `update_many` (modify every match)

### Context

Product taxonomy update: the company is rebranding every "Phone" as "Smartphone" across the catalog. One statement, every matching row.

### What you'll learn

- The difference between `update_one` and `update_many` (it's the only difference between them).
- Verifying how many documents the filter touched.

### Collection in play

| Collection | Filter field | Updated field |
|---|---|---|
| `products` | `category` | `category` |

### Task

Change `category` from `"Phone"` to `"Smartphone"` for **every** matching document.

### Expected result

```text
update_many matched=3, modified=3

After UPDATE operations:
  name=iPhone 14, category=Smartphone, price=899
  name=Galaxy S23, category=Smartphone, price=899
  name=MacBook Air, category=Laptop, price=1299
  name=Pixel 8, category=Smartphone, price=799
```

### Hint

Same shape as `update_one`, just rename the method.

### Solution

```python
result = products.update_many(
    {"category": "Phone"},
    {"$set": {"category": "Smartphone"}},
)
print(f"matched={result.matched_count}, modified={result.modified_count}")
```

```javascript
db.products.updateMany(
  { category: "Phone" },
  { $set: { category: "Smartphone" } }
)
```

### Step-by-step explanation

1. **`update_many` touches all matches.** This is the most common production pitfall — forgetting that `update_one` stops after the first hit and quietly leaving stale data.
2. **The MacBook Air is untouched** because its `category == "Laptop"` does not satisfy the filter — visible proof that the filter, not a loop, decides the scope.
3. **Operators are atomic per document.** While the write iterates, other writers can interleave between documents (MongoDB only guarantees per-document atomicity, not a transaction across all matches — use a session/transaction for that).

---

## Exercise 5 — `delete_one` (remove a single doc)

### Context

A customer reported that their reserved iPhone 14 listing must be pulled from the public catalog (legal hold). Remove exactly one document by name.

### What you'll learn

- Removing a single document.
- The `DeleteResult.deleted_count` (0 or 1).
- Why `delete_one` is safer than `delete_many` for ad-hoc admin actions.

### Collection in play

| Collection | Filter field |
|---|---|
| `products` | `name` |

### Task

Delete the document where `name == "iPhone 14"`.

### Expected result

```text
delete_one deleted=1
```

### Hint

`delete_one(filter)` — no second argument, no `$set`.

### Solution

```python
result = products.delete_one({"name": "iPhone 14"})
print(f"deleted={result.deleted_count}")
```

```javascript
db.products.deleteOne({ name: "iPhone 14" })
```

### Step-by-step explanation

1. **`delete_one` stops after the first match** in storage order. With duplicate names you have no guarantee *which* one goes.
2. **`deleted_count`** is `0` or `1`. To verify a deletion semantically (e.g. for audit logs), use `find_one_and_delete` which also returns the removed document.
3. **An empty filter `{}` deletes one *arbitrary* document.** Same trap as a `DELETE` without `WHERE` — never run it in production without a filter.

---

## Exercise 6 — `delete_many` (filtered)

### Context

The "Smartphone" category is being discontinued in this region. Remove every product that still carries that category.

### What you'll learn

- Removing all documents matching a filter in a single call.
- Verifying scope via `deleted_count`.

### Collection in play

| Collection | Filter field |
|---|---|
| `products` | `category` |

### Task

Delete every document with `category == "Smartphone"`.

### Expected result

```text
delete_many(category=Smartphone) deleted=2

After DELETE (filtered) operations:
  name=MacBook Air, category=Laptop, price=1299
```

### Hint

`delete_many({"category": "Smartphone"})`.

### Solution

```python
result = products.delete_many({"category": "Smartphone"})
print(f"deleted={result.deleted_count}")
```

```javascript
db.products.deleteMany({ category: "Smartphone" })
```

### Step-by-step explanation

1. **Why 2 and not 3?** Because Exercise 5 already deleted the iPhone 14 (which had been re-categorised to `Smartphone` in Exercise 4). Only Galaxy S23 and Pixel 8 remain in that category.
2. **`delete_many` is per-document atomic**, not a transaction. If the server crashes mid-iteration, you may see a partial delete — use sessions for all-or-nothing semantics.
3. Always **double-check the filter on a `find()` first** in production. There is no undo.

---

## Exercise 7 — `delete_many({})` (clear the collection)

### Context

End-of-class cleanup: empty the practice collection without dropping it (so indexes survive).

### What you'll learn

- The empty filter `{}` matches every document.
- The difference between "empty the collection" and "drop the collection" (next exercise).

### Collection in play

| Collection | Filter |
|---|---|
| `products` | `{}` (everything) |

### Task

Remove every remaining document, then verify the count is `0`.

### Expected result

```text
delete_many({}) deleted=1
Remaining docs in collection: 0
```

### Hint

`delete_many({})` plus `count_documents({})` to verify.

### Solution

```python
cleared = products.delete_many({})
print(f"deleted={cleared.deleted_count}")
print(f"remaining={products.count_documents({})}")
```

```javascript
db.products.deleteMany({})
db.products.countDocuments({})
```

### Step-by-step explanation

1. **`{}` is an "always true" filter** — same role as `WHERE 1=1` in SQL. It is the *only* way `delete_many` will sweep everything.
2. **`count_documents({})`** issues an aggregation that returns an accurate count. `estimated_document_count()` is faster but uses cached metadata — fine for dashboards, not for assertions in tests.
3. The **collection still exists** after this, just empty. All indexes, validators, and stats remain.

---

## Exercise 8 — `drop` (remove the collection entirely)

### Context

After the workshop we tear everything down — both data **and** the collection metadata (indexes, options). Next run starts from a truly clean slate.

### What you'll learn

- `drop()` deletes the collection itself, not just its rows.
- How to verify a collection is gone by listing collection names.

### Collection in play

| Collection | What happens |
|---|---|
| `products` | Removed completely |

### Task

Drop the `products` collection, then verify it is no longer listed in the database.

### Expected result

```text
Collection exists after drop: False
```

### Hint

`drop()` is parameterless. Verify via `db.list_collection_names()`.

### Solution

```python
products.drop()
print(COLLECTION_NAME in client["edu_academy_seed"].list_collection_names())
```

```javascript
db.products.drop()
db.getCollectionNames().includes("products")
```

### Step-by-step explanation

1. **`drop` removes**: documents, the collection entry in `system.namespaces`, every secondary index, and any per-collection options (validator, ttl, capped flag). It is **not** reversible without a backup.
2. **`delete_many({})` vs `drop()`**: the former keeps the collection ready for new inserts (cheap, keeps indexes); the latter is the equivalent of `DROP TABLE`. For routine resets in tests, prefer `delete_many({})`.
3. **Auto-recreation:** writing to a dropped collection auto-recreates it on the next insert, but **without the old indexes**. If you depended on a unique index, re-create it explicitly.

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `WriteError: Modifiers may not be applied to _id` | You tried to update `_id`. Don't — `_id` is immutable. Delete + re-insert instead. |
| `update_one` returns `matched=0` | Filter doesn't match any doc. Try `find_one(filter)` to see what the filter actually finds. |
| `update_one` returns `matched=1, modified=0` | The new value equals the old one — Mongo skips the write. Not an error. |
| `BulkWriteError` on `insert_many` | Duplicate `_id` or schema validation. Pass `ordered=False` to insert the survivors and inspect the `.details`. |
| `pymongo.errors.OperationFailure: not authorized` | Connect with a user that has `readWrite` on the database. |

Run the whole lesson end-to-end: `python 04_mongodb/01_crud/example.py`.
