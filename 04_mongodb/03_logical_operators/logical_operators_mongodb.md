# Logical Operators in MongoDB (`03_logical_operators`)

> Translation / Переклад: [Українська](../../i18n/uk/04_mongodb/03_logical_operators/logical_operators_mongodb.md)

These exercises cover the **four logical operators** of the MongoDB query language: `$and`, `$or`, `$not`, `$nor`. They combine simpler predicates (`$gte`, `$lt`, …) into compound filters.

All examples run against database `edu_academy_seed` and collection **`logical_operators_people`**.

Runnable companion file: [`03_logical_operators/example.py`](example.py). The script demonstrates `$and`, `$or`, `$not`; the `$nor` exercise below was captured separately via `mongosh` against the same seeded collection.

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/03_logical_operators/example.py
```

Default settings:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real CRM / HR rule needs the operator. |
| **What you'll learn** | The PyMongo/mongosh syntax for the operator. |
| **Collection in play** | Fields read by the filter. |
| **Task** | Concrete compound predicate. |
| **Expected result** | Real `count` and `docs` lines from a live run. |
| **Hint** | A single nudge toward the structure. |
| **Solution** | Working Python (PyMongo) **and** equivalent mongosh JavaScript. |
| **Step-by-step explanation** | Operator semantics, short-circuiting, and the implicit-AND trap. |

---

## Map: logical operators

| Operator | Meaning | Shape |
|---|---|---|
| `$and` | All predicates true | `{ "$and": [ {…}, {…} ] }` |
| `$or` | At least one predicate true | `{ "$or": [ {…}, {…} ] }` |
| `$not` | Predicate is false (or field missing) | `{ field: { "$not": { … } } }` |
| `$nor` | None of the predicates is true | `{ "$nor": [ {…}, {…} ] }` |

Important detail: a comma-separated query like `{"age": {"$gte": 18}, "city": "New York"}` is an **implicit `$and`** — you only need the explicit `$and` when two predicates touch the **same field**, or when you want to be explicit for readability.

## Collection schema

```json
{ "name": "Anna", "age": 17, "city": "Chicago" }
```

| Field | BSON type | Sample values |
|---|---|---|
| `name` | `string` | Anna, Bohdan, Chris, Daria, Emma, Farid, Hanna |
| `age` | `int` | 17, 18, 25, 30, 45, 60, 61 |
| `city` | `string` | Chicago, New York, Los Angeles, Kyiv, Berlin, Warsaw |

The seed inserts 7 documents.

---

## Exercise 1 — `$and` (logical AND)

### Context

The New York office runs an adults-only after-work mixer. The HR system needs every employee who **lives in New York** **AND** **is ≥ 18**.

### What you'll learn

- The explicit `$and` form for combining multiple predicates.
- When implicit AND is enough and when `$and` is mandatory.

### Collection in play

| Field | Predicate |
|---|---|
| `age` | `>= 18` |
| `city` | `== "New York"` |

### Task

Find people with `age >= 18` **and** `city == "New York"`, sorted by `name`.

### Expected result

```text
$and (logical AND)
  query={'$and': [{'age': {'$gte': 18}}, {'city': 'New York'}]}
  count=2
  docs=[Bohdan (age=18, city=New York), Emma (age=45, city=New York)]
```

### Hint

`$and` takes a **list of sub-queries**: `{"$and": [ {...}, {...} ]}`.

### Solution

```python
docs = list(coll.find(
    {"$and": [{"age": {"$gte": 18}}, {"city": "New York"}]},
    {"_id": 0},
).sort("name", 1))
```

```javascript
db.logical_operators_people.find(
  { $and: [ { age: { $gte: 18 } }, { city: "New York" } ] },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **Implicit AND** would also work here: `{"age": {"$gte": 18}, "city": "New York"}` is equivalent. We chose `$and` for **readability** and to make the structure obvious to readers used to SQL `WHERE … AND …`.
2. **When you *must* use explicit `$and`:** combining two predicates on the **same field**, e.g. `{"$and": [{"age": {"$gte": 18}}, {"age": {"$lt": 65}}]}` because the second `age` key in a single dict literal would silently overwrite the first.
3. **Short-circuiting:** MongoDB evaluates predicates left-to-right and stops as soon as one fails. Put the **most selective** predicate first to skip more documents.
4. **No documents missing fields are matched** — the `$gte` and `$eq` parts both require the field to exist.

---

## Exercise 2 — `$or` (logical OR)

### Context

A wellness campaign targets two extreme age cohorts: **minors (< 18)** and **seniors (> 60)**. Send the bundled flyer to anyone in either group.

### What you'll learn

- The `$or` operator with multiple sub-queries.
- Why `$or` is implemented as a **union of index scans** when each branch is indexed.

### Collection in play

| Field | Predicates |
|---|---|
| `age` | `< 18` OR `> 60` |

### Task

Find people with `age < 18` **or** `age > 60`, sorted by `name`.

### Expected result

```text
$or (logical OR)
  query={'$or': [{'age': {'$lt': 18}}, {'age': {'$gt': 60}}]}
  count=2
  docs=[Anna (age=17, city=Chicago), Hanna (age=61, city=Warsaw)]
```

### Hint

`{"$or": [ {...}, {...} ]}` — list of sub-queries, each evaluated independently.

### Solution

```python
docs = list(coll.find(
    {"$or": [{"age": {"$lt": 18}}, {"age": {"$gt": 60}}]},
    {"_id": 0},
).sort("name", 1))
```

```javascript
db.logical_operators_people.find(
  { $or: [ { age: { $lt: 18 } }, { age: { $gt: 60 } } ] },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$or` needs an explicit operator** — unlike AND, there is no implicit form. A single dict cannot represent OR.
2. **Index usage:** Mongo can plan a **union of index scans** if each branch has its own usable index. With a single `{age: 1}` index, both branches become disjoint range scans on that one index — fast.
3. **Duplicates de-duped automatically** when the same document satisfies multiple branches; you don't need to worry about counting twice.
4. **`$or` empty list** — `{"$or": []}` — raises an error. The minimum is one sub-query.

---

## Exercise 3 — `$not` (logical NOT)

### Context

Children's after-school programme rule: print badges for everyone whose `age` is **not** in the "adult" range (`>= 18`). In our data, the only minor is Anna (17).

### What you'll learn

- The field-scoped `$not` operator (negates a single predicate).
- How `$not` treats missing fields.

### Collection in play

| Field | Predicate |
|---|---|
| `age` | NOT (`>= 18`) |

### Task

Find people whose age is **not** ≥ 18, sorted by `name`.

### Expected result

```text
$not (logical NOT)
  query={'age': {'$not': {'$gte': 18}}}
  count=1
  docs=[Anna (age=17, city=Chicago)]
```

### Hint

`{"age": {"$not": {"$gte": 18}}}` — `$not` wraps **another operator expression**, not a raw value.

### Solution

```python
docs = list(coll.find(
    {"age": {"$not": {"$gte": 18}}},
    {"_id": 0},
).sort("name", 1))
```

```javascript
db.logical_operators_people.find(
  { age: { $not: { $gte: 18 } } },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$not` is field-scoped**, not top-level. The shape is `{ field: { "$not": { <operator-expression> } } }`. The argument **must be an operator dict** like `{"$gte": 18}` — it cannot be a bare value or a regex literal in some old drivers.
2. **`$not` includes missing-field documents** — same trap as `$ne`. If you want to exclude them, AND with `{"age": {"$exists": true}}`.
3. **`$not` is **not** the same as `$nor`.** `$not` negates **one** predicate on **one** field; `$nor` negates a **list** of independent predicates (see Exercise 4).
4. **Index usage:** like `$ne`/`$nin`, `$not` typically cannot use an index for a single-field lookup — but it can still ride a compound index when combined with other selective predicates.

---

## Exercise 4 — `$nor` (logical NOR)

### Context

Marketing wants a "neither/nor" segment: people who are **neither minors** (`age < 18`) **nor based in New York** — i.e. people the New-York-teen campaign does **not** apply to.

### What you'll learn

- The `$nor` operator, which is `NOT (a OR b OR …)`.
- How `$nor` differs from chaining `$ne`/`$not`.

### Collection in play

| Field | Predicate excluded |
|---|---|
| `age` | `< 18` |
| `city` | `== "New York"` |

### Task

Find people who satisfy **none** of: `age < 18`, `city == "New York"`, sorted by `name`.

### Expected result (captured live via `mongosh`)

```text
$nor count=4
[
  { name: 'Chris',  age: 25, city: 'Los Angeles' },
  { name: 'Daria',  age: 30, city: 'Kyiv' },
  { name: 'Farid',  age: 60, city: 'Berlin' },
  { name: 'Hanna',  age: 61, city: 'Warsaw' }
]
```

(Bohdan and Emma are excluded because they live in New York. Anna is excluded because she is a minor.)

### Hint

`{"$nor": [ {...}, {...} ]}` — same shape as `$or`, but inverted: the document is kept only if **all** sub-queries fail.

### Solution

```python
docs = list(coll.find(
    {"$nor": [{"age": {"$lt": 18}}, {"city": "New York"}]},
    {"_id": 0},
).sort("name", 1))
```

```javascript
db.logical_operators_people.find(
  { $nor: [ { age: { $lt: 18 } }, { city: "New York" } ] },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$nor` is the De Morgan dual of `$or`.** `NOT (A OR B)` is equivalent to `(NOT A) AND (NOT B)`. The `$nor` form is more compact and reads more naturally for negation lists.
2. **Missing fields are not excluded.** A document without `age` doesn't satisfy `age < 18`, so `$nor` keeps it (provided it also doesn't satisfy the other predicates). This is the opposite of `$or`'s behaviour on the same data.
3. **Compared with `$not`:** `$not` negates one predicate on one field; `$nor` can mix predicates across multiple fields. Use `$nor` when you would otherwise need a chain of `$ne` / `$not` joined by `$and`.
4. **Index usage:** like other negations, `$nor` is rarely index-friendly on its own. Use it as a **secondary filter** in a query that has at least one positive, selective predicate.

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| Implicit AND silently misses a predicate | Two keys on the same field in one dict — the second overrides the first. Switch to explicit `$and`. |
| `$or` returns more rows than expected | Documents satisfying multiple branches are counted once, but a permissive branch (e.g. `$exists: true`) widens the set. |
| `$not` returns rows where the field is missing | Add `{ field: { "$exists": true } }` to exclude them. |
| `$nor` and "NOT IN" look the same | `$nor` is more general — it can negate arbitrary predicates, not just `$in`. |
| Slow `$or` query | Make sure **each branch** is independently indexable; otherwise the planner falls back to a collection scan. |

Run all examples: `python 04_mongodb/03_logical_operators/example.py` (covers `$and`, `$or`, `$not`). The `$nor` query above runs identically once the same seed data is in place.
