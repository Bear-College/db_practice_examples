# Indexes in MongoDB (`09_indexes`)

> Translation / Переклад: [Українська](../../i18n/uk/04_mongodb/09_indexes/indexes_mongodb.md)

These exercises walk through the **six core index types** in MongoDB — single-field, compound, unique, text, TTL, and hashed — using PyMongo. Each section shows the `create_index` call, the resulting metadata in `db.collection.getIndexes()`, and (where it matters) the `explain('executionStats')` plan that proves the new index is being used.

Runnable companion file: [`09_indexes/example.py`](example.py). The script seeds four people, ensures the listed indexes exist, prints them, and runs two demo queries (a `city` filter and a `$text` search). You control which indexes get created via two variables at the top of the script:

```python
RUN_CREATE_INDEXES = True        # toggle creation
RUN_DROP_INDEXES   = False       # toggle dropping
INDEXES_TO_CREATE  = {"ix_city_single", "ix_city_age_compound", ...}
INDEXES_TO_DROP    = []
```

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/09_indexes/example.py
```

Default connection (override with env vars):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Collection: `indexes_people`

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | The query workload that motivates this index. |
| **What you'll learn** | The specific index type. |
| **Collection in play** | Fields participating in the index. |
| **Task** | The exact `create_index` to make. |
| **Expected result** | Real captured `getIndexes()` / `explain()` JSON. |
| **Hint** | The PyMongo function and the right `kwargs`. |
| **Solution** | PyMongo and `mongosh` versions side-by-side. |
| **Step-by-step explanation** | What the index buys you and the gotchas. |

---

## Collection: `indexes_people`

The seed inserts 4 users with the fields each index targets:

```json
{
  "user_id": "u1001",
  "name": "Anna",
  "email": "anna@example.com",
  "city": "New York",
  "age": 22,
  "bio": "Python developer and backend engineer",
  "expires_at": ISODate("...")
}
```

| `name` | `city` | `age` | `email` | `bio` | `expires_at` |
|---|---|---|---|---|---|
| Anna | New York | 22 | anna@example.com | "Python developer and backend engineer" | +5 days |
| Bohdan | Chicago | 28 | bohdan@example.com | "JavaScript developer and frontend specialist" | +3 days |
| Chris | New York | 35 | chris@example.com | "Data engineer and SQL expert" | +10 days |
| Daria | Kyiv | 30 | daria@example.com | "Engineering manager and mentor" | **-1 day** (already expired) |

Daria's `expires_at` is in the past — the TTL monitor will clean her up within ~60 seconds when the TTL index is active.

After the script's first run the `getIndexes()` output is:

```text
Indexes in indexes_people:
  - _id_: keys=[('_id', 1)], options={}
  - ix_city_single: keys=[('city', 1)], options={}
  - ix_city_age_compound: keys=[('city', 1), ('age', -1)], options={}
  - uq_email_unique: keys=[('email', 1)], options={'unique': True}
  - ix_bio_text: keys=[('_fts', 'text'), ('_ftsx', 1)], options={'weights': SON([('bio', 1)]), 'default_language': 'english', 'language_override': 'language', 'textIndexVersion': 3}
  - ix_expires_at_ttl: keys=[('expires_at', 1)], options={'expireAfterSeconds': 0}
  - ix_user_id_hashed: keys=[('user_id', 'hashed')], options={}
```

---

## Exercise 1 — Single-field index

### Context

The "Customers by city" report runs `find({city: "..."})` thousands of times per day. Without an index that's a full collection scan; with one it becomes an indexed lookup.

### What you'll learn

- The simplest `create_index` call: one field, ascending direction.
- Reading the `IXSCAN` stage in the explain plan.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `city` | string | The query predicate. |

### Task

Create an ascending index on `city`, name it `ix_city_single`, then run `find({"city": "New York"})` and verify the planner uses it.

### Expected result

```text
Created index: ix_city_single (Single field index on city)
```

`explain('executionStats')` of `find({"city": "New York"})` reports `IXSCAN` on `ix_city_single`:

```text
--- Winning plan (find city=New York) ---
{
  "stage": "FETCH",
  "inputStage": {
    "stage": "IXSCAN",
    "keyPattern": { "city": 1 },
    "indexName": "ix_city_single",
    "isMultiKey": false,
    "direction": "forward",
    "indexBounds": { "city": ["[\"New York\", \"New York\"]"] }
  }
}

--- executionStats (find city=New York) ---
{
  "executionSuccess": true,
  "nReturned": 2,
  "executionTimeMillis": 1,
  "totalKeysExamined": 2,
  "totalDocsExamined": 2
}
```

`totalKeysExamined == nReturned == 2` is the textbook "perfect" indexed read: one key lookup per returned doc, no wasted work.

### Hint

`coll.create_index([("city", ASCENDING)], name="ix_city_single")`.

### Solution

```python
from pymongo import ASCENDING, MongoClient

coll = MongoClient("mongodb://localhost:27017")["edu_academy_seed"]["indexes_people"]
coll.create_index([("city", ASCENDING)], name="ix_city_single")

plan = coll.database.command(
    "explain",
    {"find": coll.name, "filter": {"city": "New York"}},
    verbosity="executionStats",
)
print(plan["queryPlanner"]["winningPlan"])
```

```javascript
use("edu_academy_seed");
db.indexes_people.createIndex({ city: 1 }, { name: "ix_city_single" });
db.indexes_people.find({ city: "New York" }).explain("executionStats");
```

### Step-by-step explanation

1. **`createIndex` is idempotent.** Calling it again with the same spec is a no-op. Calling it with a *different* spec but the same name fails.
2. **Direction (`1` / `-1`) matters for compound indexes**, not single-field. A `find` with `sort({city: -1})` still uses an ascending index — MongoDB just walks it in reverse.
3. **Index size cost.** Each B-tree leaf carries the key + the document's `_id`. Plan for 5-15% of collection size per index.
4. **`IXSCAN` then `FETCH`.** First the index returns the matching `_id`s; then a separate stage fetches the full documents. With a *covering* projection (only indexed fields), the `FETCH` is skipped.

---

## Exercise 2 — Compound index

### Context

The same dashboard also wants "Customers in this city, oldest first". One index that knows about both `city` and `age` makes the query and the sort a single indexed pass.

### What you'll learn

- Field order in a compound index matters.
- Mixed ascending / descending directions.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `city` | string | Primary key of the index. |
| `age` | int | Secondary key, descending. |

### Task

Create a compound index `(city ASC, age DESC)` named `ix_city_age_compound`. Confirm it appears in the metadata.

### Expected result

```text
Created index: ix_city_age_compound (Compound index on city + age)

Indexes in indexes_people:
  ...
  - ix_city_age_compound: keys=[('city', 1), ('age', -1)], options={}
  ...
```

### Hint

`create_index([("city", ASCENDING), ("age", DESCENDING)], name="ix_city_age_compound")`.

### Solution

```python
from pymongo import ASCENDING, DESCENDING
coll.create_index(
    [("city", ASCENDING), ("age", DESCENDING)],
    name="ix_city_age_compound",
)
```

```javascript
db.indexes_people.createIndex(
  { city: 1, age: -1 },
  { name: "ix_city_age_compound" }
);
```

### Step-by-step explanation

1. **Equality, sort, range.** The optimal compound index lists fields in **ESR** order: equality predicates first, then the sort field, then range predicates. `city` (equality) before `age` (sort/range) fits this rule.
2. **Index prefixes.** `(city, age)` can serve queries on `city` alone, but **not** on `age` alone. If you need both, create two indexes.
3. **Mixed directions.** `(city ASC, age DESC)` and `(city DESC, age ASC)` are equivalent — MongoDB can walk either direction. But `(city ASC, age DESC)` and `(city ASC, age ASC)` are **different**: a sort on `{city: 1, age: -1}` only the first will satisfy without a memory sort.
4. **Cardinality matters.** Put the more selective field first when you can; for a city-then-age workload, `city` happens to be the right choice.

---

## Exercise 3 — Unique index

### Context

`email` must be unique per user — the application currently relies on the database to reject duplicates at insert time.

### What you'll learn

- `unique=True` index option.
- The "DuplicateKey" error that protects integrity.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `email` | string | Must be unique. |

### Task

Create the unique index `uq_email_unique` on `email`. Demonstrate that a second insert with the same email is rejected.

### Expected result

```text
Created index: uq_email_unique (Unique index on email)
```

Metadata shows `'unique': True`:

```text
- uq_email_unique: keys=[('email', 1)], options={'unique': True}
```

Attempting `coll.insert_one({"email": "anna@example.com", ...})` raises `pymongo.errors.DuplicateKeyError: E11000 duplicate key error collection: edu_academy_seed.indexes_people index: uq_email_unique dup key: { email: "anna@example.com" }`.

### Hint

`coll.create_index([("email", ASCENDING)], unique=True, name="uq_email_unique")`.

### Solution

```python
from pymongo.errors import DuplicateKeyError

coll.create_index([("email", ASCENDING)], unique=True, name="uq_email_unique")

try:
    coll.insert_one({
        "user_id": "u9999",
        "name": "Anna 2",
        "email": "anna@example.com",
    })
except DuplicateKeyError as e:
    print("rejected:", e.details.get("errmsg"))
```

```javascript
db.indexes_people.createIndex(
  { email: 1 },
  { unique: true, name: "uq_email_unique" }
);
try {
  db.indexes_people.insertOne({ email: "anna@example.com" });
} catch (e) {
  print("rejected:", e.errmsg);
}
```

### Step-by-step explanation

1. **Uniqueness is on the indexed value.** Two documents may share `email == null` only if `email` is actually `null` (not missing); switch to a *sparse* index to allow many missing fields.
2. **Existing duplicates block creation.** If the collection already contains two docs with the same email, `createIndex` fails with `duplicate key`. Clean up first.
3. **Cluster-wide enforcement.** In a sharded deployment the unique key must include the shard key — otherwise MongoDB can't reliably check uniqueness across shards.
4. **Read-write trade-off.** A unique index has the same read performance as a regular one, but writes pay a small cost to check uniqueness.

---

## Exercise 4 — Text index

### Context

The internal hire-search page runs `bio` keyword searches like "Python developer". A text index turns that into a tokenised full-text lookup that is **much** cheaper than a regex scan.

### What you'll learn

- The text index type.
- The `$text` / `$search` query operator.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `bio` | string | The text-indexed column. |

### Task

Create `ix_bio_text` as a text index over `bio`, then query for the word `"developer"`.

### Expected result

```text
Created index: ix_bio_text (Text index on bio)
```

Metadata shows the internal `_fts` / `_ftsx` keys:

```text
- ix_bio_text: keys=[('_fts', 'text'), ('_ftsx', 1)],
  options={'weights': SON([('bio', 1)]), 'default_language': 'english',
           'language_override': 'language', 'textIndexVersion': 3}
```

Running the search:

```text
$text search 'developer' -> [
  {'name': 'Bohdan', 'bio': 'JavaScript developer and frontend specialist'},
  {'name': 'Anna',   'bio': 'Python developer and backend engineer'}
]
```

Chris is dropped (his bio uses "Data engineer", not "developer").

### Hint

The first argument to `create_index` is `[("bio", "text")]` — note the string `"text"` instead of `1`/`-1`.

### Solution

```python
coll.create_index([("bio", "text")], name="ix_bio_text")

hits = list(
    coll.find(
        {"$text": {"$search": "developer"}},
        {"_id": 0, "name": 1, "bio": 1},
    )
)
for d in hits:
    print(d)
```

```javascript
db.indexes_people.createIndex({ bio: "text" }, { name: "ix_bio_text" });
db.indexes_people.find(
  { $text: { $search: "developer" } },
  { _id: 0, name: 1, bio: 1 }
);
```

### Step-by-step explanation

1. **A collection has at most one text index** — but it can span multiple string fields: `[("title", "text"), ("body", "text")]`.
2. **`$text` is the only operator that uses it.** A plain `{bio: "developer"}` is an exact-string match, not a tokenised search.
3. **Stemming and stop words.** `default_language: "english"` enables Porter stemming and English stop-word removal. `db.indexes_people.find({$text: {$search: "develop"}})` also matches "developer".
4. **Score with `$meta`.** Add `{score: {$meta: "textScore"}}` to the projection and `sort` to rank results.

---

## Exercise 5 — TTL (time-to-live) index

### Context

Daria's row has `expires_at` set to yesterday. The auth system stores session-like records that **must** auto-expire — a TTL index removes them server-side, no cron job needed.

### What you'll learn

- The TTL index type.
- The `expireAfterSeconds` option.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `expires_at` | date | Must be a real `Date` (BSON), not a string. |

### Task

Create `ix_expires_at_ttl` as a TTL index on `expires_at` with `expireAfterSeconds=0`. After up to ~60 seconds, Daria's expired document disappears.

### Expected result

```text
Created index: ix_expires_at_ttl (TTL index on expires_at)
```

Metadata:

```text
- ix_expires_at_ttl: keys=[('expires_at', 1)], options={'expireAfterSeconds': 0}
```

After the TTL monitor runs (one tick per minute by default), Daria is gone:

```python
coll.count_documents({"name": "Daria"})  # eventually 0
```

### Hint

`create_index([("expires_at", ASCENDING)], expireAfterSeconds=0, name="ix_expires_at_ttl")`.

### Solution

```python
coll.create_index(
    [("expires_at", ASCENDING)],
    expireAfterSeconds=0,
    name="ix_expires_at_ttl",
)
```

```javascript
db.indexes_people.createIndex(
  { expires_at: 1 },
  { expireAfterSeconds: 0, name: "ix_expires_at_ttl" }
);
```

### Step-by-step explanation

1. **Field must be a BSON date.** String dates won't be picked up.
2. **`expireAfterSeconds`** is the **grace period** added to the indexed date. `0` means "delete as soon as the indexed timestamp is in the past".
3. **The TTL monitor runs ~once per minute.** So an expired record can hang around for up to ~60 seconds.
4. **Not for caching.** TTL deletes the *whole* document. Use a `$set` + a date check for partial expiration semantics.

---

## Exercise 6 — Hashed index

### Context

The `user_id` field is a high-cardinality string that the production cluster shards on. A hashed index keeps the data distribution even across shards even when `user_id` values come in lexicographically (e.g. `u1001`, `u1002`, …).

### What you'll learn

- The hashed index type.
- Why it's the canonical choice for shard keys on monotonically increasing values.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `user_id` | string | Hashed for sharding. |

### Task

Create `ix_user_id_hashed` as a hashed index on `user_id`.

### Expected result

```text
Created index: ix_user_id_hashed (Hashed index on user_id)
```

Metadata:

```text
- ix_user_id_hashed: keys=[('user_id', 'hashed')], options={}
```

### Hint

The index spec is `[("user_id", "hashed")]` — same trick as `"text"`.

### Solution

```python
coll.create_index([("user_id", "hashed")], name="ix_user_id_hashed")
```

```javascript
db.indexes_people.createIndex({ user_id: "hashed" }, { name: "ix_user_id_hashed" });
```

### Step-by-step explanation

1. **Hashed indexes support equality only.** `{user_id: "u1003"}` is fast; `{user_id: {$gt: "u1003"}}` is not (the hash function destroys ordering).
2. **Used as a shard key.** They spread inserts evenly across shards, which is the main reason to choose hashed over a regular index.
3. **No unique constraint.** A hashed index cannot be unique. To get both, create *two* indexes: one hashed for sharding, one regular `unique` for the constraint.
4. **Storage overhead.** Hashes are 64-bit ints — usually smaller than the original string keys.

---

## Exercise 7 — Verifying with `explain('executionStats')`

### Context

Indexes are useless if the planner ignores them. Every time you add or change an index, prove it gets used with a real `explain` run.

### What you'll learn

- The two `explain` verbosities you'll use 99% of the time: `queryPlanner` and `executionStats`.
- How to read `nReturned`, `totalKeysExamined`, and `totalDocsExamined`.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `city` | string | Filter used to test `ix_city_single`. |

### Task

Run `find({"city": "New York"}).explain("executionStats")` and check three things: (a) winning stage is `IXSCAN`, (b) the right `indexName`, (c) `totalKeysExamined == nReturned` (no wasted work).

### Expected result

```text
--- Winning plan (find city=New York) ---
{
  "stage": "FETCH",
  "inputStage": {
    "stage": "IXSCAN",
    "keyPattern": { "city": 1 },
    "indexName": "ix_city_single",
    "isMultiKey": false,
    "direction": "forward",
    "indexBounds": { "city": ["[\"New York\", \"New York\"]"] }
  }
}

--- executionStats ---
{
  "executionSuccess": true,
  "nReturned": 2,
  "executionTimeMillis": 1,
  "totalKeysExamined": 2,
  "totalDocsExamined": 2
}
```

### Hint

In PyMongo, use `db.command("explain", {...}, verbosity="executionStats")` — it's more portable than `cursor.explain()` which differs by version.

### Solution

```python
plan = coll.database.command(
    "explain",
    {"find": coll.name, "filter": {"city": "New York"}},
    verbosity="executionStats",
)
print(plan["queryPlanner"]["winningPlan"])
stats = plan["executionStats"]
print("nReturned         =", stats["nReturned"])
print("totalKeysExamined =", stats["totalKeysExamined"])
print("totalDocsExamined =", stats["totalDocsExamined"])
```

```javascript
db.indexes_people
  .find({ city: "New York" })
  .explain("executionStats");
```

### Step-by-step explanation

1. **`COLLSCAN` is the red flag.** It means MongoDB read every document. Either the planner has no usable index, or your predicate isn't selective enough.
2. **`totalDocsExamined ≫ nReturned`?** The index isn't covering the predicate. Add the missing column to the index or extend it.
3. **`totalKeysExamined ≫ nReturned`?** The index is partly used, but bound ranges are wide. Compound index in the wrong order is the usual cause.
4. **`isCached: true`.** Means the planner reused a cached plan. Plans are cached per query shape — same filter shape, different parameters, share a plan.

---

## Quick reference

| Goal | Spec | Options |
|---|---|---|
| Single field | `[("city", 1)]` | — |
| Compound | `[("city", 1), ("age", -1)]` | — |
| Unique | `[("email", 1)]` | `unique=True` |
| Text | `[("bio", "text")]` | — |
| TTL | `[("expires_at", 1)]` | `expireAfterSeconds=0` |
| Hashed | `[("user_id", "hashed")]` | — |

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `IndexOptionsConflict` | An index with that name exists but a *different* spec. Drop it, then recreate. |
| `DuplicateKeyError` on `createIndex` (unique) | Existing duplicates. Clean them first (`aggregate` to find groups). |
| Query still does `COLLSCAN` | Predicate type doesn't match the field type, or sort direction prevents index use. `explain()` to confirm. |
| Text search returns nothing | Words may be tokenised differently (stems, stop words). Try shorter root, or check language setting. |
| TTL row doesn't disappear | Field isn't a BSON Date, or the monitor hasn't run yet (wait ~60 s). |
| Hashed index slows range query | Expected — hashed indexes are equality only. Add a regular index for ranges. |
