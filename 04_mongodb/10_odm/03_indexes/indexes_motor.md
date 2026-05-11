# Indexes with Motor (`10_odm/03_indexes`)

> Translation / Переклад: [Українська](../../../i18n/uk/04_mongodb/10_odm/03_indexes/indexes_motor.md)

These exercises mirror lesson `09_indexes` but with the **async** Python driver, **Motor**. The same six index types appear (single, compound, unique, text, TTL, hashed), the same `explain` workflow proves they're being used — only the surrounding control flow is `async def`.

Runnable companion file: [`10_odm/03_indexes/main.py`](main.py). The script seeds three products, creates all six indexes, lists them, runs two demo queries, and drops the indexes again so the next run starts clean.

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/03_indexes/main.py
```

Default connection (override with env vars):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Collection: `odm_motor_indexes_products`

---

## Collection: `odm_motor_indexes_products`

The seed inserts three products (`SKU-1001`, `SKU-1002`, `SKU-1003`) with the fields each index targets:

```json
{
  "sku": "SKU-1001",
  "name": "iPhone 14",
  "category": "Smartphone",
  "description": "Apple smartphone",
  "price": 899,
  "created_at": ISODate("..."),
  "expires_at": ISODate("...")
}
```

| `sku` | `name` | `category` | `price` | `description` |
|---|---|---|---|---|
| SKU-1001 | iPhone 14 | Smartphone | 899 | "Apple smartphone" |
| SKU-1002 | Galaxy S23 | Smartphone | 799 | "Samsung flagship phone" |
| SKU-1003 | MacBook Air | Laptop | 1299 | "Lightweight laptop" |

After `create_indexes` runs, `list_indexes` reports:

```text
Indexes:
  - _id_: SON([('_id', 1)])
  - ix_category_single: SON([('category', 1)])
  - ix_category_price_compound: SON([('category', 1), ('price', -1)])
  - uq_sku: SON([('sku', 1)])
  - ix_description_text: SON([('_fts', 'text'), ('_ftsx', 1)])
  - ix_expires_at_ttl: SON([('expires_at', 1)])
  - ix_sku_hashed: SON([('sku', 'hashed')])
```

The two demo queries return:

```text
category='Smartphone' -> [{'name': 'iPhone 14', 'price': 899}, {'name': 'Galaxy S23', 'price': 799}]
$text search 'smartphone' -> [{'name': 'iPhone 14'}]
```

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | The workload that motivates this index. |
| **What you'll learn** | The async call and the kwargs. |
| **Collection in play** | Fields participating. |
| **Task** | The `create_index` to issue. |
| **Expected result** | Real `list_indexes()` / `explain()` JSON. |
| **Hint** | The Motor function signature. |
| **Solution** | Motor (Python) and `mongosh` versions. |
| **Step-by-step explanation** | Async-specific gotchas and the usual mistakes. |

---

## Exercise 1 — Single-field index (`ix_category_single`)

### Context

The storefront filters by `category` on every page load. Without an index this is a full collection scan; with one it becomes an index lookup.

### What you'll learn

- `await coll.create_index([...])` — the Motor signature is the same as PyMongo's.
- Reading the `IXSCAN` stage in the async explain output.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `category` | string | Filter key. |

### Task

Create an ascending index on `category` named `ix_category_single` and confirm `find({"category": "Smartphone"})` uses it.

### Expected result

```text
- ix_category_single: SON([('category', 1)])

category='Smartphone' -> [{'name': 'iPhone 14', 'price': 899}, {'name': 'Galaxy S23', 'price': 799}]
```

A live `explain` (captured against the same data) showed `IXSCAN` with `keysExamined == 2` and `nReturned == 2` — textbook indexed read:

```text
"stage": "IXSCAN",
"indexName": "ix_category_price_compound",   // see Exercise 2 for why
"isMultiKey": false,
"direction": "forward",
"indexBounds": { "category": ["[\"Smartphone\", \"Smartphone\"]"], "price": ["[MaxKey, MinKey]"] },
"keysExamined": 2,
"seeks": 1,
"dupsTested": 0,
"dupsDropped": 0
```

(The planner happens to pick the compound index from Exercise 2 because both prefix the same `category` field — see the explanation below.)

### Hint

`await coll.create_index([("category", ASCENDING)], name="ix_category_single")`.

### Solution

```python
from pymongo import ASCENDING
await coll.create_index([("category", ASCENDING)], name="ix_category_single")
```

```javascript
use("edu_academy_seed");
db.odm_motor_indexes_products.createIndex({ category: 1 }, { name: "ix_category_single" });
db.odm_motor_indexes_products.find({ category: "Smartphone" }).explain("executionStats");
```

### Step-by-step explanation

1. **`create_index` is awaitable.** Forgetting `await` returns a `Future`; the index isn't created and your next line uses stale state.
2. **Idempotent.** Calling it again with the same spec is a no-op.
3. **Planner can choose a different index than you expected.** With both `ix_category_single` *and* the compound `ix_category_price_compound`, MongoDB may prefer the compound — both can serve a `category` equality, but the compound also satisfies any `price` sort that comes later.
4. **One index ≠ one query.** A single-field index can serve any query that uses that field as a leading equality/range predicate.

---

## Exercise 2 — Compound index (`ix_category_price_compound`)

### Context

The "products in this category, most expensive first" widget. The compound `(category ASC, price DESC)` index lets MongoDB return the rows already sorted.

### What you'll learn

- Field order in a compound index dictates which queries it can serve.
- Why the explain bounds for the unused trailing field show `[MaxKey, MinKey]`.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `category` | string | First key. |
| `price` | int | Second key, descending. |

### Task

Create `ix_category_price_compound` and confirm `find({"category": "Smartphone"})` benefits from it (which it does because `category` is the index prefix).

### Expected result

```text
- ix_category_price_compound: SON([('category', 1), ('price', -1)])
```

Real `explain('executionStats')` captured live against this data:

```text
"stage": "IXSCAN",
"indexName": "ix_category_price_compound",
"isMultiKey": false,
"direction": "forward",
"indexBounds": {
  "category": ["[\"Smartphone\", \"Smartphone\"]"],
  "price":    ["[MaxKey, MinKey]"]
},
"keysExamined": 2,
"seeks": 1
```

`price: [MaxKey, MinKey]` means "the full range" — the query didn't constrain it, but the index still scans both keys per matching `category`.

### Hint

`await coll.create_index([("category", ASCENDING), ("price", DESCENDING)], name="ix_category_price_compound")`.

### Solution

```python
from pymongo import ASCENDING, DESCENDING
await coll.create_index(
    [("category", ASCENDING), ("price", DESCENDING)],
    name="ix_category_price_compound",
)
```

```javascript
db.odm_motor_indexes_products.createIndex(
  { category: 1, price: -1 },
  { name: "ix_category_price_compound" }
);
```

### Step-by-step explanation

1. **`(category, price)` can serve queries on `category` alone** (index prefix rule), so the single-field `ix_category_single` is technically redundant if you always include the compound — keep it only if you have queries that *sort* on `category` and would suffer from the compound's `price: -1` direction.
2. **ESR (Equality, Sort, Range).** Here `category` is equality, `price` is sort. Putting `price` first would have made the `category` filter slower.
3. **`isMultiKey: false`** confirms neither field is an array. With arrays, MongoDB indexes every element — fine but accounted for differently.

---

## Exercise 3 — Unique index (`uq_sku`)

### Context

`sku` is the SKU printed on every barcode — it has to be globally unique. A unique index makes the database refuse duplicates.

### What you'll learn

- The `unique=True` kwarg.
- The `DuplicateKeyError` you'll see on a conflicting insert.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `sku` | string | Must be unique. |

### Task

Create `uq_sku` on `sku` with `unique=True`. Verify a duplicate insert is rejected.

### Expected result

```text
- uq_sku: SON([('sku', 1)])
```

Trying to insert a second `SKU-1001` document raises:

```text
pymongo.errors.DuplicateKeyError: E11000 duplicate key error collection:
edu_academy_seed.odm_motor_indexes_products index: uq_sku dup key: { sku: "SKU-1001" }
```

### Hint

`await coll.create_index([("sku", ASCENDING)], unique=True, name="uq_sku")`.

### Solution

```python
from pymongo.errors import DuplicateKeyError

await coll.create_index([("sku", ASCENDING)], unique=True, name="uq_sku")

try:
    await coll.insert_one({"sku": "SKU-1001", "name": "Duplicate"})
except DuplicateKeyError as e:
    print("rejected:", e.details.get("errmsg"))
```

```javascript
db.odm_motor_indexes_products.createIndex(
  { sku: 1 },
  { unique: true, name: "uq_sku" }
);
```

### Step-by-step explanation

1. **Async error handling is identical to sync** — `try / except` around the `await`.
2. **Existing duplicates block creation.** `createIndex` fails with `E11000` if the collection already contains conflicting `sku` values.
3. **Unique vs hashed.** A hashed index (Exercise 6) on the same field cannot also be unique — that's why we have *both* in this lesson: `uq_sku` for the constraint, `ix_sku_hashed` for hypothetical sharding.

---

## Exercise 4 — Text index (`ix_description_text`)

### Context

The catalogue's keyword search runs against the product `description`. A text index turns "smartphone" / "phone" / "headphones" into a tokenised lookup.

### What you'll learn

- Async creation of a text index (`("description", "text")`).
- The same `$text` / `$search` query as in lesson `09_indexes`.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `description` | string | Tokenised. |

### Task

Create `ix_description_text`, then search for `"smartphone"`.

### Expected result

```text
- ix_description_text: SON([('_fts', 'text'), ('_ftsx', 1)])

$text search 'smartphone' -> [{'name': 'iPhone 14'}]
```

Only `iPhone 14` has the literal token `smartphone` in its description — Galaxy S23's description is "Samsung flagship phone".

### Hint

`await coll.create_index([("description", "text")], name="ix_description_text")`.

### Solution

```python
await coll.create_index([("description", "text")], name="ix_description_text")

cursor = coll.find(
    {"$text": {"$search": "smartphone"}},
    {"_id": 0, "name": 1},
)
docs = await cursor.to_list(length=10)
```

```javascript
db.odm_motor_indexes_products.createIndex({ description: "text" }, { name: "ix_description_text" });
db.odm_motor_indexes_products.find({ $text: { $search: "smartphone" } }, { _id: 0, name: 1 });
```

### Step-by-step explanation

1. **One text index per collection** — but it can span multiple string fields with weights.
2. **Stop words and stemming** are language-aware (`default_language: "english"` by default). `"phones"` and `"phone"` both match.
3. **You query with `$text`, not by writing `description: "smartphone"`** — a plain equality is a literal-string match.

---

## Exercise 5 — TTL index (`ix_expires_at_ttl`)

### Context

Cached price-comparison rows are tagged with an `expires_at` timestamp; once that timestamp passes, they should disappear automatically.

### What you'll learn

- The `expireAfterSeconds=0` option.
- That TTL deletions happen on a ~60-second tick by the TTL monitor.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `expires_at` | date | Must be a real BSON `Date`. |

### Task

Create `ix_expires_at_ttl` with `expireAfterSeconds=0`.

### Expected result

```text
- ix_expires_at_ttl: SON([('expires_at', 1)])
```

If the seeded `expires_at` were in the past, the corresponding row would be removed within ~60 seconds.

### Hint

`await coll.create_index([("expires_at", ASCENDING)], expireAfterSeconds=0, name="ix_expires_at_ttl")`.

### Solution

```python
await coll.create_index(
    [("expires_at", ASCENDING)],
    expireAfterSeconds=0,
    name="ix_expires_at_ttl",
)
```

```javascript
db.odm_motor_indexes_products.createIndex(
  { expires_at: 1 },
  { expireAfterSeconds: 0, name: "ix_expires_at_ttl" }
);
```

### Step-by-step explanation

1. **Field must be a `datetime`** in Python (becomes BSON `Date` over the wire). A string won't trigger TTL.
2. **`expireAfterSeconds` is added to the date.** `0` means "expired immediately when the timestamp is in the past"; `3600` would give a 1-hour grace period.
3. **The TTL monitor runs ~once per minute.** So an expired record can survive up to ~60 s post-expiry.
4. **`expireAfterSeconds` lives on the index, not the document.** You can have one TTL rule per index/collection — multiple lifetimes need multiple collections (or per-document expiry via partial filter expressions).

---

## Exercise 6 — Hashed index (`ix_sku_hashed`)

### Context

If this collection were sharded across many nodes, hashing `sku` would keep inserts evenly distributed even though `sku` values come in monotonically (`SKU-1001`, `SKU-1002`, …).

### What you'll learn

- The `[("sku", "hashed")]` form.
- Why you can have both a unique and a hashed index on the same field.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `sku` | string | Hashed for distribution. |

### Task

Create `ix_sku_hashed`.

### Expected result

```text
- ix_sku_hashed: SON([('sku', 'hashed')])
```

### Hint

`await coll.create_index([("sku", "hashed")], name="ix_sku_hashed")`.

### Solution

```python
await coll.create_index([("sku", "hashed")], name="ix_sku_hashed")
```

```javascript
db.odm_motor_indexes_products.createIndex({ sku: "hashed" }, { name: "ix_sku_hashed" });
```

### Step-by-step explanation

1. **Hashed indexes are equality-only.** `find({sku: "SKU-1001"})` uses the index; `find({sku: {$gt: "SKU-1001"}})` does not.
2. **Two indexes on one field are fine.** `uq_sku` (B-tree, unique) and `ix_sku_hashed` (hashed) coexist — each serves a different query shape.
3. **Useful primarily for sharding.** On a single-server deployment a hashed index buys you nothing extra over the unique B-tree.

---

## Exercise 7 — Listing and dropping indexes

### Context

After an experiment, the script cleans up the indexes it created so the next run starts fresh — like a test fixture.

### What you'll learn

- The async pattern for `list_indexes()` (`async for idx in coll.list_indexes()`).
- The list of names returned by `create_index` — you can re-use it to drop them.

### Collection in play

| All | — | — |
|---|---|---|

### Task

1. Print every index in the collection.
2. Drop only the indexes the script created (not `_id_`).

### Expected result

```text
Indexes:
  - _id_: SON([('_id', 1)])
  - ix_category_single: SON([('category', 1)])
  - ix_category_price_compound: SON([('category', 1), ('price', -1)])
  - uq_sku: SON([('sku', 1)])
  - ix_description_text: SON([('_fts', 'text'), ('_ftsx', 1)])
  - ix_expires_at_ttl: SON([('expires_at', 1)])
  - ix_sku_hashed: SON([('sku', 'hashed')])

Dropped index: ix_category_single
Dropped index: ix_category_price_compound
Dropped index: uq_sku
Dropped index: ix_description_text
Dropped index: ix_expires_at_ttl
Dropped index: ix_sku_hashed
```

### Hint

Iterate `async for idx in coll.list_indexes(): ...`; collect the names returned by `create_index` for later `await coll.drop_index(name)`.

### Solution

```python
async def print_indexes(coll):
    print("Indexes:")
    async for idx in coll.list_indexes():
        print(f"  - {idx.get('name')}: {idx.get('key')}")

async def drop_created_indexes(coll, names):
    for name in names:
        await coll.drop_index(name)
        print(f"Dropped index: {name}")
```

```javascript
db.odm_motor_indexes_products.getIndexes().forEach(i => printjson(i));
db.odm_motor_indexes_products.dropIndex("ix_category_single");
db.odm_motor_indexes_products.dropIndexes(); // careful — drops ALL except _id_
```

### Step-by-step explanation

1. **`list_indexes()` returns an async cursor.** Don't `await` it directly — iterate with `async for`.
2. **`_id_` cannot be dropped.** `dropIndexes()` skips it; `drop_index("_id_")` raises.
3. **Dropping a non-existent index** raises `OperationFailure`. Guard with `try / except` if you don't want it to crash the cleanup.

---

## Quick reference

| Goal | Spec | Options |
|---|---|---|
| Single field | `[("category", 1)]` | — |
| Compound | `[("category", 1), ("price", -1)]` | — |
| Unique | `[("sku", 1)]` | `unique=True` |
| Text | `[("description", "text")]` | — |
| TTL | `[("expires_at", 1)]` | `expireAfterSeconds=0` |
| Hashed | `[("sku", "hashed")]` | — |

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `RuntimeWarning: coroutine '...' was never awaited` | You called `coll.create_index(...)` without `await`. The index isn't created. |
| `IndexOptionsConflict` | Same name, different spec. Drop, then recreate. |
| `DuplicateKeyError` on `createIndex` | Existing duplicates. Clean them first. |
| Text search returns nothing | Stop words, stemming, or wrong language. Check the seeded text. |
| TTL row doesn't disappear | Field must be BSON `Date`; monitor runs ~once a minute. |
| Query still does `COLLSCAN` | Use `db.command("explain", ...)` to see why — wrong type, wrong direction, etc. |
