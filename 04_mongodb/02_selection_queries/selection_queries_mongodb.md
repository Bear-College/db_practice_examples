# Selection Queries in MongoDB (`02_selection_queries`)

> Translation / Переклад: [Українська](../../i18n/uk/04_mongodb/02_selection_queries/selection_queries_mongodb.md)

These exercises walk through the **comparison and list-membership operators** (`$eq`, `$ne`, `$gt`, `$lt`, `$gte`, `$lte`, `$in`, `$nin`) and add three **nested-document** examples using dot-notation paths (`profile.city`, `profile.experience`, `profile.role`).

All examples run against the practice database `edu_academy_seed` and collection **`selection_queries_people`**.

Runnable companion file: [`02_selection_queries/example.py`](example.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/02_selection_queries/example.py
```

Default settings:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

The script resets the collection at the start of each run, so the **`count`** and **`docs`** lines in every Expected result below are deterministic.

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real CRM / HR app would run this query. |
| **What you'll learn** | The PyMongo/mongosh constructs trained here. |
| **Collection in play** | Documents and fields actually queried. |
| **Task** | Concrete filter requirement. |
| **Expected result** | Real `count` and `docs` lines from a live run. |
| **Hint** | A single nudge toward the operator. |
| **Solution** | Working Python (PyMongo) **and** equivalent mongosh JavaScript. |
| **Step-by-step explanation** | Operator semantics and BSON / type-coercion gotchas. |

---

## Map: comparison and list operators

| Operator | Meaning | SQL analogue |
|---|---|---|
| `$eq` | Equals | `=` |
| `$ne` | Not equals | `<>` |
| `$gt` | Greater than | `>` |
| `$lt` | Less than | `<` |
| `$gte` | Greater than or equal | `>=` |
| `$lte` | Less than or equal | `<=` |
| `$in` | Value in list | `IN (…)` |
| `$nin` | Value not in list | `NOT IN (…)` |

For nested documents, **dot-notation** (`profile.city`) addresses fields inside sub-documents — the operators stay the same.

## Collection schema

The `selection_queries_people` collection holds 7 documents with a flat top level and a nested `profile`:

```json
{
  "name": "Anna",
  "age": 17,
  "city": "Chicago",
  "profile": { "city": "Chicago", "experience": 1, "role": "intern" }
}
```

| Field | BSON type | Sample values |
|---|---|---|
| `name` | `string` | Anna, Bohdan, Chris, Daria, Emma, Farid, Hanna |
| `age` | `int` | 17, 18, 25, 30, 45, 60, 61 |
| `city` | `string` | Chicago, New York, Los Angeles, Kyiv, Berlin, Warsaw |
| `profile.city` | `string` | Same set, mirrored under `profile` |
| `profile.experience` | `int` | 1, 2, 4, 7, 15, 20, 21 |
| `profile.role` | `string` | intern, junior, developer, lead, architect, principal, advisor |

---

## Exercise 1 — `$eq` (equals)

### Context

The HR dashboard wants to highlight every employee whose age **is exactly** 25 — the office is celebrating quarter-century birthdays.

### What you'll learn

- The explicit form `{ field: { $eq: value } }`.
- Why the implicit short form `{ field: value }` is equivalent.

### Collection in play

| Field | Type | Filter value |
|---|---|---|
| `age` | `int` | `25` |

### Task

Find every person with `age == 25` and sort the result by `name` ascending.

### Expected result

```text
$eq  (equals)
  query={'age': {'$eq': 25}}
  count=1
  docs=[Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4)]
```

### Hint

`{"age": {"$eq": 25}}` and `{"age": 25}` mean the same thing.

### Solution

```python
docs = list(coll.find({"age": {"$eq": 25}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $eq: 25 } }, { _id: 0 }).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$eq` matches by both value *and* BSON type.** `{"age": {"$eq": 25}}` will not match a document with `"age": "25"` (string). MongoDB does not implicitly coerce numeric strings.
2. The **implicit form** `{"age": 25}` is identical: when the value is not a `$`-prefixed dict, the driver wraps it in `$eq`.
3. **Projection `{"_id": 0}`** strips the `ObjectId` from each result row — the example uses it for readable output.
4. **`.sort("name", 1)`** asks the server to sort ascending by `name`. Without sort, the order is the storage order and is not stable.

---

## Exercise 2 — `$ne` (not equals)

### Context

The 25-year-olds get one promo, everyone else gets the standard newsletter — list everyone whose age is **not** 25.

### What you'll learn

- `$ne` semantics for missing fields.
- Why `$ne` rarely uses an index (the planner has to scan everything not equal to the value).

### Collection in play

| Field | Type | Filter value |
|---|---|---|
| `age` | `int` | not `25` |

### Task

Return everyone with `age != 25`, sorted by `name`.

### Expected result

```text
$ne  (not equals)
  query={'age': {'$ne': 25}}
  count=6
  docs=[Anna (age=17, city=Chicago, profile.city=Chicago, profile.experience=1), Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Daria (age=30, city=Kyiv, profile.city=Kyiv, profile.experience=7), Emma (age=45, city=New York, profile.city=New York, profile.experience=15), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20), Hanna (age=61, city=Warsaw, profile.city=Warsaw, profile.experience=21)]
```

### Hint

`{"age": {"$ne": 25}}`.

### Solution

```python
docs = list(coll.find({"age": {"$ne": 25}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $ne: 25 } }, { _id: 0 }).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$ne` includes documents where the field is missing.** A document with no `age` field is considered "not equal to 25" and would appear in the result. Use `$ne` together with `$exists: true` (see lesson `05_check_operators`) if you want to exclude such docs.
2. **`$ne` is not index-friendly.** Where `$eq` can do a point lookup, `$ne` must scan most of the index range. For large collections, prefer rewriting the predicate (`$gt` + `$lt` ranges) when possible.
3. Like `$eq`, **`$ne` is type-strict**: `{"age": {"$ne": "25"}}` would match every doc, because `25` (int) is not equal to the string `"25"`.

---

## Exercise 3 — `$gt` (greater than)

### Context

Marketing wants a "senior" segment — anyone strictly older than 25.

### What you'll learn

- The strict comparator `$gt` (no equality at the boundary).
- BSON ordering rules across numeric types.

### Collection in play

| Field | Type | Filter value |
|---|---|---|
| `age` | `int` | `> 25` |

### Task

Find every person with `age > 25`, sorted by `name`.

### Expected result

```text
$gt  (greater than)
  query={'age': {'$gt': 25}}
  count=4
  docs=[Daria (age=30, city=Kyiv, profile.city=Kyiv, profile.experience=7), Emma (age=45, city=New York, profile.city=New York, profile.experience=15), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20), Hanna (age=61, city=Warsaw, profile.city=Warsaw, profile.experience=21)]
```

### Hint

`$gt` is strict — `age = 25` is **not** in the result.

### Solution

```python
docs = list(coll.find({"age": {"$gt": 25}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $gt: 25 } }, { _id: 0 }).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$gt`** excludes the boundary value. If you need inclusive comparison, use `$gte` (Exercise 5).
2. **Numeric comparisons across `Int32`, `Int64`, `Double`, `Decimal128`** work — Mongo orders the numeric type bracket as if they were one set. But comparing `int` against `string` would return nothing because BSON types form a strict total order: numbers < strings.
3. **Index alignment:** `{age: 1}` index can serve `$gt` as a range scan from `25` exclusive. Add a sort on the same key (`.sort("age", 1)`) to get a pure index scan with no in-memory sort.

---

## Exercise 4 — `$lt` (less than)

### Context

Show a "youth" cohort for the apprenticeship programme — anyone strictly younger than 30.

### What you'll learn

- The strict `<` comparator.
- Mirror image of `$gt`.

### Collection in play

| Field | Type | Filter value |
|---|---|---|
| `age` | `int` | `< 30` |

### Task

Find every person with `age < 30`, sorted by `name`.

### Expected result

```text
$lt  (less than)
  query={'age': {'$lt': 30}}
  count=3
  docs=[Anna (age=17, city=Chicago, profile.city=Chicago, profile.experience=1), Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4)]
```

### Hint

`$lt` is strict — `age = 30` is **not** included.

### Solution

```python
docs = list(coll.find({"age": {"$lt": 30}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $lt: 30 } }, { _id: 0 }).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$lt` is strict.** Daria (age = 30) is excluded; she will appear when the bound is `$lte: 30` instead.
2. **Combine `$gt` + `$lt`** in the same query to form a range filter: `{"age": {"$gt": 17, "$lt": 30}}` is the BSON form of `17 < age < 30`.
3. **Date and ObjectId comparisons** use the same `$lt` operator — dates compare lexicographically because BSON dates are 64-bit unix-epoch milliseconds.

---

## Exercise 5 — `$gte` (greater than or equal)

### Context

The "adults" filter: include everyone aged 18 and above, boundary included.

### What you'll learn

- The inclusive boundary form.
- When to choose `$gte` over `$gt + offset`.

### Collection in play

| Field | Type | Filter value |
|---|---|---|
| `age` | `int` | `>= 18` |

### Task

Find every person with `age >= 18`, sorted by `name`.

### Expected result

```text
$gte (greater or equals)
  query={'age': {'$gte': 18}}
  count=6
  docs=[Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4), Daria (age=30, city=Kyiv, profile.city=Kyiv, profile.experience=7), Emma (age=45, city=New York, profile.city=New York, profile.experience=15), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20), Hanna (age=61, city=Warsaw, profile.city=Warsaw, profile.experience=21)]
```

### Hint

`{"age": {"$gte": 18}}` — note the boundary (Bohdan, age 18) is included.

### Solution

```python
docs = list(coll.find({"age": {"$gte": 18}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $gte: 18 } }, { _id: 0 }).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$gte` includes the boundary.** Compare Exercise 3 (4 hits) vs this exercise (6 hits): adding Bohdan (age 18) **and** Chris (age 25, who passed `$gte: 18`).
2. **Prefer `$gte` over arithmetic tricks** like `$gt: 17`. With integers they're equivalent, but with floats `$gt: 17.0` will exclude `17.000000001` while `$gte: 18.0` is unambiguous.
3. **Off-by-one bugs** in pagination and "minimum age" filters almost always come from the wrong `$gt` vs `$gte` choice — write the boundary explicitly.

---

## Exercise 6 — `$lte` (less than or equal)

### Context

Pre-retirement segmentation: keep everyone aged up to and including 60.

### What you'll learn

- The inclusive form of `<`.
- How `$lte` interacts with the absent-field case.

### Collection in play

| Field | Type | Filter value |
|---|---|---|
| `age` | `int` | `<= 60` |

### Task

Find every person with `age <= 60`, sorted by `name`.

### Expected result

```text
$lte (less or equals)
  query={'age': {'$lte': 60}}
  count=6
  docs=[Anna (age=17, city=Chicago, profile.city=Chicago, profile.experience=1), Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4), Daria (age=30, city=Kyiv, profile.city=Kyiv, profile.experience=7), Emma (age=45, city=New York, profile.city=New York, profile.experience=15), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20)]
```

### Hint

`{"age": {"$lte": 60}}` — Farid (60) is in, Hanna (61) is out.

### Solution

```python
docs = list(coll.find({"age": {"$lte": 60}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $lte: 60 } }, { _id: 0 }).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$lte` includes the boundary.** Compare with `$lt: 60` which would drop Farid.
2. **Missing-field semantics:** unlike `$ne`, `$lte` does **not** match documents missing the field. Mongo can only compare a value that exists; absent fields are silently excluded from range filters.
3. **Index range:** a `{age: 1}` index can serve `$lte: 60` by walking the index from the smallest value up to and including `60`. Combine with `.sort("age", 1)` to skip the in-memory sort.

---

## Exercise 7 — `$in` (value in list)

### Context

A regional report wants every employee living in the **New York or Los Angeles** offices — two cities, one query.

### What you'll learn

- Set-membership filtering with `$in`.
- Why `$in` is preferable to chained `$or` of `$eq`s.

### Collection in play

| Field | Type | Filter values |
|---|---|---|
| `city` | `string` | `["New York", "Los Angeles"]` |

### Task

Find people whose `city` is in the set `["New York", "Los Angeles"]`, sorted by `name`.

### Expected result

```text
$in  (in list)
  query={'city': {'$in': ['New York', 'Los Angeles']}}
  count=3
  docs=[Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4), Emma (age=45, city=New York, profile.city=New York, profile.experience=15)]
```

### Hint

`{"city": {"$in": [...]}}` — note the value is a list.

### Solution

```python
docs = list(coll.find({"city": {"$in": ["New York", "Los Angeles"]}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find(
  { city: { $in: ["New York", "Los Angeles"] } },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$in` is shorthand for an `$or` of `$eq` predicates** on the same field. Mongo optimises this into a single index range scan when an index on `city` exists.
2. **List can mix BSON types** (e.g. `["NY", 5, /regex/]`) — but a mixed-type list often points to a data quality issue. Keep types homogeneous.
3. **Empty list** `{"city": {"$in": []}}` matches **nothing** (set membership against an empty set is always false). The mirror case `$nin: []` matches everything.
4. **`$in` against an array field** matches if **any element** of the document's array is in the query list — see lesson `06_array_operators` for details.

---

## Exercise 8 — `$nin` (value not in list)

### Context

"Other locations" report — everyone **not** in the New York or Los Angeles offices.

### What you'll learn

- Negation of `$in`.
- Why `$nin` shares the same index-unfriendly issues as `$ne`.

### Collection in play

| Field | Type | Filter values |
|---|---|---|
| `city` | `string` | not in `["New York", "Los Angeles"]` |

### Task

Find people whose `city` is **not** in the set `["New York", "Los Angeles"]`, sorted by `name`.

### Expected result

```text
$nin (not in list)
  query={'city': {'$nin': ['New York', 'Los Angeles']}}
  count=4
  docs=[Anna (age=17, city=Chicago, profile.city=Chicago, profile.experience=1), Daria (age=30, city=Kyiv, profile.city=Kyiv, profile.experience=7), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20), Hanna (age=61, city=Warsaw, profile.city=Warsaw, profile.experience=21)]
```

### Hint

`{"city": {"$nin": [...]}}` — opposite of `$in`.

### Solution

```python
docs = list(coll.find({"city": {"$nin": ["New York", "Los Angeles"]}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find(
  { city: { $nin: ["New York", "Los Angeles"] } },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$nin` includes documents where the field is missing**, just like `$ne`. If you want only documents that have the field, add `{"city": {"$exists": true}}` (see lesson `05_check_operators`).
2. **Index usage:** `$nin` is treated as a negation — most of the time the planner cannot use an index for it efficiently. For long block lists, materialize the complement (use `$in` on the keep list).
3. **`$nin: []`** matches every document — the opposite of `$in: []`.

---

## Exercise 9 — Nested `$eq` on `profile.city`

### Context

A second "city" field is stored inside the `profile` sub-document for legacy reasons. The CRM needs to pull employees by their **profile's** city, not the top-level one.

### What you'll learn

- Dot-notation paths into nested documents.
- That operators work identically for nested fields.

### Collection in play

| Path | Type | Filter value |
|---|---|---|
| `profile.city` | `string` | `"New York"` |

### Task

Find people whose `profile.city == "New York"`, sorted by `name`.

### Expected result

```text
Nested $eq on profile.city
  query={'profile.city': {'$eq': 'New York'}}
  count=2
  docs=[Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Emma (age=45, city=New York, profile.city=New York, profile.experience=15)]
```

### Hint

Wrap the path in **quotes** and use a dot: `"profile.city"`.

### Solution

```python
docs = list(coll.find({"profile.city": {"$eq": "New York"}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find(
  { "profile.city": { $eq: "New York" } },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **Dot-notation** is the canonical way to address fields in sub-documents. In Python the key must be a **string** (`"profile.city"`) — using `profile.city` as a Python expression doesn't make sense because there is no `profile` variable.
2. **Sub-document equality vs path equality:** `{"profile": {"city": "New York"}}` is **not** the same as `{"profile.city": "New York"}`. The first compares the *entire* sub-document by exact shape and order — it would fail if `profile` also has `experience` or `role`. Always use dot-notation unless you really want full-document equality.
3. **Indexes on nested paths** work the same way: `db.collection.createIndex({"profile.city": 1})` is a standard ascending index on the nested field.

---

## Exercise 10 — Nested `$gte` on `profile.experience`

### Context

Seniority filter for an internal hackathon — only people with **≥ 10 years** of experience qualify as mentors.

### What you'll learn

- Combining range operators with dot-notation.
- That experience filters often need a tiebreaker sort.

### Collection in play

| Path | Type | Filter value |
|---|---|---|
| `profile.experience` | `int` | `>= 10` |

### Task

Find people with `profile.experience >= 10`, sorted by `name`.

### Expected result

```text
Nested $gte on profile.experience
  query={'profile.experience': {'$gte': 10}}
  count=3
  docs=[Emma (age=45, city=New York, profile.city=New York, profile.experience=15), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20), Hanna (age=61, city=Warsaw, profile.city=Warsaw, profile.experience=21)]
```

### Hint

Same `$gte` operator — just a different (nested) field path.

### Solution

```python
docs = list(coll.find({"profile.experience": {"$gte": 10}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find(
  { "profile.experience": { $gte: 10 } },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **Operators are field-agnostic.** Once you've learned `$gte` for a top-level field, it works identically on `profile.experience`.
2. **Missing-field handling:** if some documents have no `profile.experience`, they are excluded silently (same rule as Exercise 6).
3. **Sort tie-breaking:** with 3 matches you don't see the issue, but in a larger dataset add `.sort([("profile.experience", -1), ("name", 1)])` so equal-experience rows have a stable order.

---

## Exercise 11 — Nested `$in` on `profile.role`

### Context

Promotion review: list everyone whose `profile.role` is **developer** or **architect** — these are the two roles eligible for the next career band.

### What you'll learn

- Combining set-membership with dot-notation.
- Why role-like enum fields are perfect candidates for `$in`.

### Collection in play

| Path | Type | Filter values |
|---|---|---|
| `profile.role` | `string` | `["developer", "architect"]` |

### Task

Find people with `profile.role` in `["developer", "architect"]`, sorted by `name`.

### Expected result

```text
Nested $in on profile.role
  query={'profile.role': {'$in': ['developer', 'architect']}}
  count=2
  docs=[Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4), Emma (age=45, city=New York, profile.city=New York, profile.experience=15)]
```

### Hint

Combine `"profile.role"` (the path) with `{"$in": [...]}` (the operator).

### Solution

```python
docs = list(coll.find(
    {"profile.role": {"$in": ["developer", "architect"]}},
    {"_id": 0},
).sort("name", 1))
```

```javascript
db.selection_queries_people.find(
  { "profile.role": { $in: ["developer", "architect"] } },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **Enum-style fields** (roles, statuses, categories) are the canonical use case for `$in` — much cleaner than chained `$or` of `$eq`s.
2. **Case-sensitive equality:** `$in` uses byte-for-byte string comparison by default. To match "Developer" / "DEVELOPER" too, either normalize on write or use `$regex` with `$options: "i"` (see lesson `04_string_operators`).
3. **Index choice for compound queries:** if you typically combine `profile.role` with another predicate, build a compound index like `{"profile.role": 1, "profile.experience": -1}` to satisfy both filter and sort in one pass.

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `$eq` on a numeric field returns 0 rows | Check whether the stored value is a string. Use `$type` (lesson `05_check_operators`) to inspect. |
| `$ne` returns way more than expected | It includes documents where the field is **missing**. Add `$exists: true` to exclude those. |
| Nested `$eq` returns 0 rows | You probably wrote `{"profile": {"city": "..."}}` (whole-document equality). Use the dotted path instead. |
| `$in: []` returns 0 rows | Correct: membership against an empty set is always false. |
| Sort order looks random | Add an explicit `.sort([...])` — Mongo never sorts unless asked. |

Run all examples at once: `python 04_mongodb/02_selection_queries/example.py`.
