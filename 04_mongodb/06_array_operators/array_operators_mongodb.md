# Array Operators in MongoDB (`06_array_operators`)

> Translation / Переклад: [Українська](../../i18n/uk/04_mongodb/06_array_operators/array_operators_mongodb.md)

These exercises walk through the **core array operators** in MongoDB: three **query** operators that match documents by what's already inside an array (`$all`, `$size`, `$elemMatch`) and three **update** operators that change the array in place (`$push`, `$addToSet`, `$pull`).

Runnable companion file: [`06_array_operators/example.py`](example.py). The script reseeds collection `array_operators_people` so output is deterministic. The `$push` / `$addToSet` / `$pull` exercises below show what happens when you run them in `mongosh` against the same data — they are not in `example.py` because the script is read-only by design.

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/06_array_operators/example.py
```

Default connection (override with env vars):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Collection: `array_operators_people`

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real team would run this query (1-2 sentences). |
| **What you'll learn** | The exact operator(s) trained here. |
| **Collection in play** | Only the fields you actually use. |
| **Task** | Concrete requirement (filter, projection, sort). |
| **Expected result** | Real output captured from `python example.py` or `mongosh`. |
| **Hint** | A single nudge toward the right operator. |
| **Solution** | PyMongo and `mongosh` versions side-by-side. |
| **Step-by-step explanation** | What each piece does and the usual gotchas. |

---

## Collection: `array_operators_people`

Every document has a `name`, a `skills` array of strings, and a `grades` array of embedded sub-documents:

```json
{
  "name": "Anna",
  "skills": ["Python", "JavaScript", "SQL"],
  "grades": [
    { "subject": "math",    "score": 95 },
    { "subject": "history", "score": 88 }
  ]
}
```

The seed inserts four students:

| `name` | `skills` | `grades` |
|---|---|---|
| Anna | `[Python, JavaScript, SQL]` | math 95, history 88 |
| Bohdan | `[Python, Go]` | math 89, physics 91 |
| Chris | `[JavaScript, TypeScript, Node.js]` | math 78, biology 84 |
| Daria | `[Python, JavaScript]` | math 92, chemistry 94 |

---

## Exercise 1 — `$all` (array contains every listed value)

### Context

The HR portal needs to find candidates whose skill list **includes both** Python **and** JavaScript — order of the values inside the array doesn't matter, and extra skills are allowed.

### What you'll learn

- The `$all` array query operator.
- Why `$all` is not the same as equality on an array (`skills: [...]`).
- Reading the result as "set inclusion" instead of "exact match".

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `name` | string | Sorted output uses this. |
| `skills` | array of strings | The array we filter on. |

### Task

Return all people whose `skills` array contains **both** `"Python"` and `"JavaScript"`. Sort by `name` ascending and project only the fields you need.

### Expected result

```text
$all (array contains all values)
  query={'skills': {'$all': ['Python', 'JavaScript']}}
  count=2
  docs=[Anna (skills=['Python', 'JavaScript', 'SQL'], grades=[{'subject': 'math', 'score': 95}, {'subject': 'history', 'score': 88}]), Daria (skills=['Python', 'JavaScript'], grades=[{'subject': 'math', 'score': 92}, {'subject': 'chemistry', 'score': 94}])]
```

So **Anna** and **Daria** match — Bohdan is dropped (no JavaScript), Chris is dropped (no Python).

### Hint

Use `{ skills: { $all: [...] } }`. The values inside the bracket are an unordered set requirement.

### Solution

```python
from pymongo import MongoClient

coll = MongoClient("mongodb://localhost:27017")["edu_academy_seed"]["array_operators_people"]

cursor = coll.find(
    {"skills": {"$all": ["Python", "JavaScript"]}},
    {"_id": 0},
).sort("name", 1)
for doc in cursor:
    print(doc)
```

```javascript
use("edu_academy_seed");
db.array_operators_people
  .find(
    { skills: { $all: ["Python", "JavaScript"] } },
    { _id: 0 }
  )
  .sort({ name: 1 });
```

### Step-by-step explanation

1. **`$all` matches subsets.** It demands every listed value to be present in the array; extra values are allowed. Anna's `["Python", "JavaScript", "SQL"]` matches because the first two are present.
2. **Order is irrelevant** inside the array. `$all: ["Python", "JavaScript"]` and `$all: ["JavaScript", "Python"]` are equivalent.
3. **`$all` vs equality.** `{skills: ["Python", "JavaScript"]}` requires the *exact* array — same length, same order. That would drop Anna (has 3 skills). `$all` is the "contains every" operator.
4. **Projection `{"_id": 0}`** strips the noisy `ObjectId` from the output. Pass it as the second positional argument to `find()`.

---

## Exercise 2 — `$size` (array length equals N)

### Context

The training team wants to flag "well-rounded" students — exactly **three** declared skills. Anyone with more or fewer is filtered out.

### What you'll learn

- The `$size` operator for *exact* array length.
- Why `$size` does **not** support range comparisons.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `skills` | array of strings | Length-tested here. |

### Task

Return everyone whose `skills` array has **exactly three** entries.

### Expected result

```text
$size (array length equals 3)
  query={'skills': {'$size': 3}}
  count=2
  docs=[Anna (skills=['Python', 'JavaScript', 'SQL'], grades=[...]), Chris (skills=['JavaScript', 'TypeScript', 'Node.js'], grades=[...])]
```

Two matches: **Anna** (`Python, JavaScript, SQL`) and **Chris** (`JavaScript, TypeScript, Node.js`). Daria has 2, Bohdan has 2 — both dropped.

### Hint

`{ field: { $size: <int> } }`. The right-hand side **must** be an integer literal.

### Solution

```python
docs = list(
    coll.find({"skills": {"$size": 3}}, {"_id": 0}).sort("name", 1)
)
for d in docs:
    print(d["name"], "->", d["skills"])
```

```javascript
db.array_operators_people
  .find({ skills: { $size: 3 } }, { _id: 0, name: 1, skills: 1 })
  .sort({ name: 1 });
```

### Step-by-step explanation

1. **`$size` checks the length only.** It is a single integer; you cannot write `$size: { $gt: 2 }`.
2. **No range query.** If you need "more than N items", use the aggregation pipeline with `$expr` and `$size` as an aggregation expression, e.g. `{$expr: {$gt: [{$size: "$skills"}, 2]}}`.
3. **No index help out of the box.** Plain `$size` cannot use a standard index. For very large collections, precompute a `skills_count` field and index that.

---

## Exercise 3 — `$elemMatch` (an embedded sub-document matches)

### Context

The exam board needs every student who has **at least one** subject with a grade above 90 — but the match must be on the **same** sub-document (so `subject="math"` and `score>90` would have to come from the same `grades[i]`, not a mix of two different ones).

### What you'll learn

- `$elemMatch` for arrays of embedded documents.
- The difference between `$elemMatch` and a plain `grades.score: {$gt: 90}` filter.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `grades` | array of sub-documents | Each has `subject` and `score`. |

### Task

Return everyone who has **at least one** entry in `grades` whose `score` is strictly greater than 90.

### Expected result

```text
$elemMatch (array has element matching condition)
  query={'grades': {'$elemMatch': {'score': {'$gt': 90}}}}
  count=3
  docs=[Anna (...grades=[{'subject': 'math', 'score': 95}, ...]), Bohdan (...grades=[..., {'subject': 'physics', 'score': 91}]), Daria (...grades=[{'subject': 'math', 'score': 92}, {'subject': 'chemistry', 'score': 94}])]
```

Three matches: **Anna** (math 95), **Bohdan** (physics 91), **Daria** (math 92 / chemistry 94). Chris (max 84) is dropped.

### Hint

Use `$elemMatch` whenever **multiple conditions on the same element** of an array of sub-documents are required.

### Solution

```python
docs = list(
    coll.find(
        {"grades": {"$elemMatch": {"score": {"$gt": 90}}}},
        {"_id": 0, "name": 1, "grades": 1},
    ).sort("name", 1)
)
for d in docs:
    print(d)
```

```javascript
db.array_operators_people
  .find(
    { grades: { $elemMatch: { score: { $gt: 90 } } } },
    { _id: 0, name: 1, grades: 1 }
  )
  .sort({ name: 1 });
```

### Step-by-step explanation

1. **`$elemMatch` binds conditions to one element.** With a single condition (as here) it is equivalent to the dot-notation form `grades.score: {$gt: 90}`. The difference appears with **two** conditions: `{grades: {$elemMatch: {subject: "math", score: {$gt: 90}}}}` requires a *single* grade entry that is **both** math **and** scoring >90.
2. **Beware the dot-notation trap.** `{ "grades.subject": "math", "grades.score": {$gt: 90} }` matches if **any** grade is math **and** **any** grade scores >90 — they may be different elements. Switch to `$elemMatch` when that distinction matters.
3. **Sub-document `_id`s.** Embedded documents inside an array do **not** get an automatic `_id`. If you need to address one specific element later (e.g. for `$pull`), give them a stable field of your own.

---

## Exercise 4 — `$push` (append to the array)

### Context

A student just finished a Rust course. The CRM appends `"Rust"` to Anna's existing skill list without rewriting the whole array.

### What you'll learn

- `$push` as the canonical "append one value" update operator.
- How `updateOne` reports `matchedCount` vs `modifiedCount`.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `skills` | array of strings | We append to this array. |

### Task

Find Anna and append `"Rust"` to her `skills`. Print the updated document.

### Expected result (captured live in `mongosh`)

```text
BEFORE:
{ name: 'Anna', skills: [ 'Python', 'JavaScript', 'SQL' ] }

--- $push: add Rust to Anna.skills ---
{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 1, "upsertedCount": 0 }
{ name: 'Anna', skills: [ 'Python', 'JavaScript', 'SQL', 'Rust' ] }
```

### Hint

`{ $push: { <array_field>: <value> } }`. The value is **always appended**, even if already present.

### Solution

```python
result = coll.update_one(
    {"name": "Anna"},
    {"$push": {"skills": "Rust"}},
)
print("matched =", result.matched_count, "modified =", result.modified_count)
print(coll.find_one({"name": "Anna"}, {"_id": 0, "name": 1, "skills": 1}))
```

```javascript
db.array_operators_people.updateOne(
  { name: "Anna" },
  { $push: { skills: "Rust" } }
);
db.array_operators_people.findOne(
  { name: "Anna" },
  { _id: 0, name: 1, skills: 1 }
);
```

### Step-by-step explanation

1. **`$push` always appends.** Running it twice with the same value produces a duplicate (`["Python", "Rust", "Rust"]`). Use `$addToSet` (Exercise 5) for "insert only if absent".
2. **Push many at once with `$each`.** `{$push: {skills: {$each: ["Rust", "Elixir"]}}}` appends both values in one call.
3. **`matched_count` vs `modified_count`.** `matched_count == 1` means the filter found Anna. `modified_count == 1` confirms the array changed. If the value were unique to MongoDB (e.g. a no-op for `$addToSet`), `modified_count` could still be `0`.
4. **Atomic update.** The whole array swap is atomic at the document level — no other writer can wedge in between read and write.

---

## Exercise 5 — `$addToSet` (append only if not present)

### Context

The same CRM screen has a "tag this student" button. Pressing it twice with the same tag must **not** duplicate it.

### What you'll learn

- `$addToSet` as the set-union alternative to `$push`.
- How MongoDB reports a no-op update (`modifiedCount: 0`).

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `skills` | array of strings | Treated as a set here. |

### Task

1. Try to add `"Python"` to Anna's `skills`. It's already there — confirm no duplicate is created.
2. Then add `"Elixir"`, which is **new**. Confirm it is appended.

### Expected result (captured live in `mongosh`)

```text
--- $addToSet: try to add Python (duplicate) to Anna.skills ---
{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 0, "upsertedCount": 0 }
{ name: 'Anna', skills: [ 'Python', 'JavaScript', 'SQL', 'Rust' ] }

--- $addToSet: add Elixir (new) to Anna.skills ---
{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 1, "upsertedCount": 0 }
{ name: 'Anna', skills: [ 'Python', 'JavaScript', 'SQL', 'Rust', 'Elixir' ] }
```

(Anna's array has `Rust` because Exercise 4 ran before this one.)

### Hint

`{ $addToSet: { <array_field>: <value> } }` — like `$push`, but a no-op when the value already exists.

### Solution

```python
r1 = coll.update_one({"name": "Anna"}, {"$addToSet": {"skills": "Python"}})
print("Python  -> matched =", r1.matched_count, "modified =", r1.modified_count)

r2 = coll.update_one({"name": "Anna"}, {"$addToSet": {"skills": "Elixir"}})
print("Elixir  -> matched =", r2.matched_count, "modified =", r2.modified_count)
```

```javascript
db.array_operators_people.updateOne(
  { name: "Anna" },
  { $addToSet: { skills: "Python" } }
);
db.array_operators_people.updateOne(
  { name: "Anna" },
  { $addToSet: { skills: "Elixir" } }
);
```

### Step-by-step explanation

1. **Set semantics, not list semantics.** `$addToSet` skips the write when the value is already present. `matched_count` stays `1` (Anna matched), but `modified_count` becomes `0`.
2. **Comparison is structural.** For primitives (strings, ints), MongoDB compares by value. For embedded documents, all fields and their order must match exactly. `{a:1,b:2}` and `{b:2,a:1}` are considered **different** for `$addToSet`.
3. **Bulk insert with `$each`.** `{$addToSet: {skills: {$each: ["A", "B"]}}}` adds both values if they are missing — without `$each`, the array would receive a single nested `["A", "B"]` element.

---

## Exercise 6 — `$pull` (remove every matching element)

### Context

A skill was removed from the catalogue. Everyone who still lists `"Rust"` needs it pulled from their `skills` array.

### What you'll learn

- `$pull` to remove values from an array.
- Pulling by predicate vs. pulling by exact value.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `skills` | array of strings | Remove a value here. |

### Task

Remove `"Rust"` from Anna's `skills`. Confirm the array shrinks by one element.

### Expected result (captured live in `mongosh`)

```text
--- $pull: remove Rust from Anna.skills ---
{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 1, "upsertedCount": 0 }
{ name: 'Anna', skills: [ 'Python', 'JavaScript', 'SQL', 'Elixir' ] }
```

### Hint

`{ $pull: { <array_field>: <value-or-condition> } }`. Pass a scalar to delete by equality; pass an object to delete by predicate.

### Solution

```python
result = coll.update_one(
    {"name": "Anna"},
    {"$pull": {"skills": "Rust"}},
)
print("matched =", result.matched_count, "modified =", result.modified_count)
print(coll.find_one({"name": "Anna"}, {"_id": 0, "name": 1, "skills": 1}))
```

```javascript
db.array_operators_people.updateOne(
  { name: "Anna" },
  { $pull: { skills: "Rust" } }
);
db.array_operators_people.findOne(
  { name: "Anna" },
  { _id: 0, name: 1, skills: 1 }
);
```

### Step-by-step explanation

1. **`$pull` removes every match in one pass.** If Anna had `["Rust", "Rust"]`, both copies would go in a single update.
2. **Predicate form for arrays of objects.** To drop the math grade only: `{$pull: {grades: {subject: "math"}}}`. The inner object is matched against each element with implicit `$and`.
3. **Pop the ends instead.** Use `$pop` (`1` for last, `-1` for first) when you simply want to trim the end or head of the array without specifying a value.
4. **Concurrency.** `$pull` operates at the document level under a write lock — safe to run against the same document from multiple clients.

---

## Quick reference

| Goal | Operator | Example |
|---|---|---|
| Array contains all listed values | `$all` | `{skills: {$all: ["Python", "JavaScript"]}}` |
| Array length is exactly N | `$size` | `{skills: {$size: 3}}` |
| At least one sub-doc matches | `$elemMatch` | `{grades: {$elemMatch: {score: {$gt: 90}}}}` |
| Append (allows duplicates) | `$push` | `{$push: {skills: "Rust"}}` |
| Append only if absent | `$addToSet` | `{$addToSet: {skills: "Elixir"}}` |
| Remove all matching elements | `$pull` | `{$pull: {skills: "Rust"}}` |

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `$size: { $gt: 2 }` errors out | `$size` only accepts an integer. Use `{$expr: {$gt: [{$size: "$skills"}, 2]}}`. |
| `$all` returns nothing | Make sure your inner values match the **types** in the array (`"1"` ≠ `1`). |
| `$elemMatch` and `dot-notation` give different counts | You wrote two conditions across two elements. Switch to `$elemMatch` to bind them to the same element. |
| `$addToSet` keeps adding duplicates of an object | Field order in embedded docs differs — normalise the shape before comparing. |
| `$pull` removed everything | The predicate matched more elements than expected; tighten the match condition. |
