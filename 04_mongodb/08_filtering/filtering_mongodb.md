# Filtering in MongoDB (`08_filtering`)

> Translation / Переклад: [Українська](../../i18n/uk/04_mongodb/08_filtering/filtering_mongodb.md)

These exercises compile every common **filter** technique into one PyMongo workflow: simple `find` / `find_one`, comparison operators, list membership, logical composition, nested-field access via dot-notation, array filters, regex, and field-existence checks. Together they replicate the filtering surface area of a SQL `WHERE` clause and then some.

Runnable companion file: [`08_filtering/example.py`](example.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/08_filtering/example.py
```

Default connection (override with env vars):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Collection: `filtering_people`

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real screen would need the filter. |
| **What you'll learn** | The operator(s) and concept(s) trained here. |
| **Collection in play** | The fields you actually touch. |
| **Task** | Concrete predicate or set of predicates. |
| **Expected result** | Real output captured from `python example.py`. |
| **Hint** | A single nudge. |
| **Solution** | PyMongo and `mongosh` versions of the same query. |
| **Step-by-step explanation** | What each operator does and the standard mistakes. |

---

## Collection: `filtering_people`

The seed inserts five documents. The shape is intentionally rich (scalars, an embedded `profile`, an array of strings, an array of sub-documents) so a single collection can showcase every operator group:

```json
{
  "name": "Anna",
  "age": 17,
  "city": "Chicago",
  "email": "anna@gmail.com",
  "phone": "+1-202-555-0101",
  "profile": { "city": "Chicago", "experience": 1 },
  "skills":  ["Python", "JavaScript", "SQL"],
  "grades":  [{"subject": "math", "score": 95}, {"subject": "history", "score": 88}]
}
```

Sample summary (after reseed):

| `name` | `age` | `city` | `email` | `phone` | `profile.experience` |
|---|---|---|---|---|---|
| Anna | 17 | Chicago | anna@gmail.com | yes | 1 |
| Bohdan | 18 | New York | bohdan@outlook.com | **missing** | 2 |
| Chris | 25 | Los Angeles | chris@gmail.com | yes | 4 |
| Daria | 30 | Kyiv | daria@yahoo.com | yes | 7 |
| Emma | 45 | New York | emma@gmail.com | yes | 15 |

Common helper used by the script:

```python
def run_query(coll, title, query):
    docs = list(coll.find(query, {"_id": 0, "name": 1}).sort("name", 1))
    names = [d.get("name") for d in docs]
    print(f"{title}\n  query={query}\n  count={len(docs)}\n  names={names}\n")
```

---

## Exercise 1 — `find()` (select all) + projection

### Context

The admin UI shows a sidebar with the **names** of every person in the system. Sending back the entire document over the wire would be wasteful; the screen only needs `name`.

### What you'll learn

- `find({})` to scan a collection.
- Projection `{ "_id": 0, "name": 1 }` to trim the payload.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `name` | string | The only field returned. |

### Task

Return every document, project only `name`, drop `_id`, sort alphabetically.

### Expected result

```text
find() all documents
  count=5
  names=[Anna, Bohdan, Chris, Daria, Emma]
```

### Hint

Empty filter `{}` matches everything. The second argument to `find()` is the projection.

### Solution

```python
docs = list(coll.find({}, {"_id": 0, "name": 1}).sort("name", 1))
for d in docs:
    print(d)
```

```javascript
db.filtering_people.find({}, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Step-by-step explanation

1. **`find({})` returns a cursor**, not a list. Iterating consumes it; you can wrap it in `list(...)` to materialise.
2. **`_id` is always returned by default.** You must opt out with `{"_id": 0}` if you want a clean payload.
3. **Inclusion / exclusion cannot be mixed**, except for `_id`. `{"name": 1, "email": 0}` is an error; `{"_id": 0, "name": 1}` is the canonical idiom.

---

## Exercise 2 — `find_one()` (single document)

### Context

The profile page shows the full record of one user — clicking "Anna" must return exactly her document and nothing else.

### What you'll learn

- `find_one()` for "I want one row".
- The difference between `find_one` returning `None` and `find` returning an empty cursor.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| All | — | Full document returned. |

### Task

Look up the user named `"Anna"` and return the entire document (minus `_id`).

### Expected result

```text
find_one() by name=Anna
  doc={'name': 'Anna', 'age': 17, 'city': 'Chicago', 'email': 'anna@gmail.com', 'phone': '+1-202-555-0101', 'profile': {'city': 'Chicago', 'experience': 1}, 'skills': ['Python', 'JavaScript', 'SQL'], 'grades': [{'subject': 'math', 'score': 95}, {'subject': 'history', 'score': 88}]}
```

### Hint

`coll.find_one(filter, projection)` returns a `dict` or `None`.

### Solution

```python
one = coll.find_one({"name": "Anna"}, {"_id": 0})
print(one)
```

```javascript
db.filtering_people.findOne({ name: "Anna" }, { _id: 0 });
```

### Step-by-step explanation

1. **`find_one` returns the first match.** If multiple rows match, the rest are silently dropped — combine with a unique field or add a sort to make the "first" deterministic.
2. **`None` means "no match".** Always check before accessing `one["age"]` to avoid `TypeError: 'NoneType' object is not subscriptable`.
3. **Same projection rules as `find`.** Use `{"_id": 0}` to drop the ObjectId.

---

## Exercise 3 — Comparison operators (`$gt`, `$lte`)

### Context

Two analytical filters: (a) "users older than the legal alcohol age" (`age > 25` in this dataset for a wider tail), and (b) "users 30 and under" for an age-band report.

### What you'll learn

- The five core comparison operators: `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`.
- That comparisons against `null` follow special rules (see Exercise 9).

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `age` | int | The numeric column we compare. |

### Task

1. List names of people with `age > 25`.
2. List names of people with `age <= 30`.

### Expected result

```text
Comparison: age > 25
  query={'age': {'$gt': 25}}
  count=2
  names=[Daria, Emma]

Comparison: age <= 30
  query={'age': {'$lte': 30}}
  count=4
  names=[Anna, Bohdan, Chris, Daria]
```

### Hint

`{ field: { $gt: value } }`. Substitute `$gt` for `$gte`, `$lt`, `$lte`, `$ne`, `$eq`.

### Solution

```python
older = list(coll.find({"age": {"$gt": 25}}, {"_id": 0, "name": 1}).sort("name", 1))
under = list(coll.find({"age": {"$lte": 30}}, {"_id": 0, "name": 1}).sort("name", 1))
print("older:", [d["name"] for d in older])
print("under:", [d["name"] for d in under])
```

```javascript
db.filtering_people.find({ age: { $gt: 25 } }, { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ age: { $lte: 30 } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Step-by-step explanation

1. **`$gt` is strictly greater than.** Use `$gte` when the boundary value should be included.
2. **Comparisons are type-aware.** `{age: {$gt: "10"}}` will *not* match a numeric `age: 17` — MongoDB compares within the same BSON type bracket.
3. **`{age: 17}` is shorthand for `{age: {$eq: 17}}`.** Both forms are equivalent.

---

## Exercise 4 — `$in` / `$nin` (set membership)

### Context

The dashboard has a "US offices" toggle: include only people in New York or Los Angeles, or invert the toggle to exclude them.

### What you'll learn

- `$in` for "value is one of …".
- `$nin` for "value is none of …".
- That `$nin` also matches documents where the field is *missing*.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `city` | string | The categorical column. |

### Task

1. `$in`: cities in `["New York", "Los Angeles"]`.
2. `$nin`: cities NOT in `["New York", "Los Angeles"]`.

### Expected result

```text
$in: city in [New York, Los Angeles]
  query={'city': {'$in': ['New York', 'Los Angeles']}}
  count=3
  names=[Bohdan, Chris, Emma]

$nin: city not in [New York, Los Angeles]
  query={'city': {'$nin': ['New York', 'Los Angeles']}}
  count=2
  names=[Anna, Daria]
```

### Hint

`{ city: { $in: [...] } }`. Reverse with `$nin`.

### Solution

```python
in_us  = list(coll.find({"city": {"$in":  ["New York", "Los Angeles"]}}, {"_id": 0, "name": 1}).sort("name", 1))
out_us = list(coll.find({"city": {"$nin": ["New York", "Los Angeles"]}}, {"_id": 0, "name": 1}).sort("name", 1))
print("inside :", [d["name"] for d in in_us])
print("outside:", [d["name"] for d in out_us])
```

```javascript
db.filtering_people.find({ city: { $in:  ["New York", "Los Angeles"] } }, { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ city: { $nin: ["New York", "Los Angeles"] } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Step-by-step explanation

1. **`$in` is the readable form of an `$or` chain.** `{city: {$in: ["A", "B"]}}` ≡ `{$or: [{city: "A"}, {city: "B"}]}`.
2. **`$nin` matches missing fields.** If a row has no `city` at all, `$nin` still returns it (the value is "not in the list" because the value is *nothing*). Combine with `$exists: true` if you want to require the field.
3. **`$in` works with arrays too.** `{skills: {$in: ["Python", "Go"]}}` matches docs whose `skills` array contains *either* value — not both.

---

## Exercise 5 — Logical operators (`$and`, `$or`, `$not`)

### Context

Three composite filters that come up in audit reports:

- (a) Adults in New York (`age >= 18 AND city = "New York"`).
- (b) Edge ages (`age < 18 OR age > 40`).
- (c) Minors (`NOT (age >= 18)`) — re-expressed via `$not` for the exercise.

### What you'll learn

- Explicit `$and` (and when it is mandatory).
- `$or` for disjunction.
- `$not` as field-scoped negation of an expression.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `age` | int | Used in all three queries. |
| `city` | string | Used in (a). |

### Task

Write three queries:

1. `$and`: `age >= 18` AND `city = "New York"`.
2. `$or`: `age < 18` OR `age > 40`.
3. `$not`: `age` is NOT `>= 18`.

### Expected result

```text
$and: age >= 18 AND city=New York
  query={'$and': [{'age': {'$gte': 18}}, {'city': 'New York'}]}
  count=2
  names=[Bohdan, Emma]

$or: age < 18 OR age > 40
  query={'$or': [{'age': {'$lt': 18}}, {'age': {'$gt': 40}}]}
  count=2
  names=[Anna, Emma]

$not: age NOT >= 18
  query={'age': {'$not': {'$gte': 18}}}
  count=1
  names=[Anna]
```

### Hint

- Implicit `$and`: `{age: {$gte: 18}, city: "New York"}` — usually fine.
- Explicit `$and`: required when the **same field** has two different sub-conditions (e.g. `{$and: [{age: {$gte: 18}}, {age: {$lt: 65}}]}`).
- `$not` wraps an **operator expression**, not a value.

### Solution

```python
adults_ny = list(coll.find(
    {"$and": [{"age": {"$gte": 18}}, {"city": "New York"}]},
    {"_id": 0, "name": 1},
).sort("name", 1))

extremes = list(coll.find(
    {"$or": [{"age": {"$lt": 18}}, {"age": {"$gt": 40}}]},
    {"_id": 0, "name": 1},
).sort("name", 1))

minors = list(coll.find(
    {"age": {"$not": {"$gte": 18}}},
    {"_id": 0, "name": 1},
).sort("name", 1))

for label, rows in (("adults_ny", adults_ny), ("extremes", extremes), ("minors", minors)):
    print(label, [d["name"] for d in rows])
```

```javascript
db.filtering_people.find(
  { $and: [ { age: { $gte: 18 } }, { city: "New York" } ] },
  { _id: 0, name: 1 }
).sort({ name: 1 });

db.filtering_people.find(
  { $or: [ { age: { $lt: 18 } }, { age: { $gt: 40 } } ] },
  { _id: 0, name: 1 }
).sort({ name: 1 });

db.filtering_people.find(
  { age: { $not: { $gte: 18 } } },
  { _id: 0, name: 1 }
).sort({ name: 1 });
```

### Step-by-step explanation

1. **Implicit `$and` between fields.** Multiple top-level keys in the query document are combined with logical AND. `$and` is only required when expressing the AND over the **same** field.
2. **`$or` short-circuits on each document.** MongoDB stops at the first branch that matches per document — branch order matters for performance.
3. **`$not` vs `$ne`.** `$ne` is a field-equality negation (`age $ne 17`). `$not` is an *expression* negation (`age $not $gte 18`). Use `$not` when the right-hand side is an operator.
4. **`$nor` exists too.** It's "none of these matches" — useful but rare; `$and` of `$not`s is clearer.

---

## Exercise 6 — Nested documents (dot notation)

### Context

The `profile` sub-document mirrors a few denormalised stats. Two reports drill into it: who lives in NY (by `profile.city`), and who is a "senior" with 10+ years of experience.

### What you'll learn

- Reaching nested fields with dot-notation (`profile.city`).
- That dot-notation works the same for arrays of sub-documents (with the trap from `06_array_operators`).

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `profile.city` | string | Nested categorical. |
| `profile.experience` | int | Nested numeric. |

### Task

1. `profile.city = "New York"`.
2. `profile.experience >= 10`.

### Expected result

```text
Nested: profile.city = New York
  query={'profile.city': 'New York'}
  count=2
  names=[Bohdan, Emma]

Nested: profile.experience >= 10
  query={'profile.experience': {'$gte': 10}}
  count=1
  names=[Emma]
```

### Hint

Wrap the path in quotes: `"profile.city"` — Python doesn't allow a dot in a dict-literal key without quoting.

### Solution

```python
ny  = list(coll.find({"profile.city": "New York"},        {"_id": 0, "name": 1}).sort("name", 1))
sen = list(coll.find({"profile.experience": {"$gte": 10}}, {"_id": 0, "name": 1}).sort("name", 1))
print("NY  :", [d["name"] for d in ny])
print("Sen :", [d["name"] for d in sen])
```

```javascript
db.filtering_people.find({ "profile.city": "New York" },          { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ "profile.experience": { $gte: 10 } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Step-by-step explanation

1. **Quote the dotted key.** In Python `{"profile.city": ...}`; in JS `{ "profile.city": ... }`. Without quotes you'd get a parse error or a literal field named `city` on a non-existent parent.
2. **No automatic indexing on nested fields.** If the workload is heavy, create `{"profile.city": 1}` explicitly.
3. **For arrays of sub-documents**, `grades.score` would match if **any** element has that score — see Exercise 7 in `06_array_operators` for the `$elemMatch` form that binds two conditions to the same element.

---

## Exercise 7 — Array filters (`$all`, `$size`, `$elemMatch`)

### Context

The same three array-query operators from `06_array_operators`, applied to the richer `filtering_people` documents. They show that array operators compose with the rest of the query DSL exactly like scalar operators.

### What you'll learn

- Reusing `$all`, `$size`, `$elemMatch` inside a mixed query.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `skills` | array of strings | `$all` and `$size` targets. |
| `grades` | array of sub-docs | `$elemMatch` target. |

### Task

1. `$all`: `skills` contains both `Python` and `JavaScript`.
2. `$size`: `skills` length is exactly 3.
3. `$elemMatch`: at least one grade with `score > 90`.

### Expected result

```text
Array $all: skills has Python + JavaScript
  query={'skills': {'$all': ['Python', 'JavaScript']}}
  count=2
  names=[Anna, Daria]

Array $size: skills length = 3
  query={'skills': {'$size': 3}}
  count=3
  names=[Anna, Chris, Emma]

Array $elemMatch: grades.score > 90
  query={'grades': {'$elemMatch': {'score': {'$gt': 90}}}}
  count=4
  names=[Anna, Bohdan, Daria, Emma]
```

### Hint

See the dedicated lesson `06_array_operators`. The syntax is identical.

### Solution

```python
run_query(coll, "$all",       {"skills": {"$all": ["Python", "JavaScript"]}})
run_query(coll, "$size",      {"skills": {"$size": 3}})
run_query(coll, "$elemMatch", {"grades": {"$elemMatch": {"score": {"$gt": 90}}}})
```

```javascript
db.filtering_people.find({ skills: { $all: ["Python", "JavaScript"] } }, { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ skills: { $size: 3 } },                       { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ grades: { $elemMatch: { score: { $gt: 90 } } } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Step-by-step explanation

1. **The same operator works on arrays of any element type.** `$all` over strings, ints, or sub-documents.
2. **`$size` only takes an integer literal.** No range; see lesson `06_array_operators` for the workaround via `$expr`.
3. **`$elemMatch` is the only way** to bind *two* conditions to the *same* element of an array of sub-documents. The dotted form `grades.score > 90` matches **any** element.

---

## Exercise 8 — Regex (`$regex`)

### Context

The marketing team wants to mail out a campaign only to users on Gmail. Their email column ends with `@gmail.com`.

### What you'll learn

- `$regex` for substring / pattern search.
- Case-insensitive search via `$options: "i"`.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `email` | string | Pattern-matched. |

### Task

List names of users whose `email` ends with `@gmail.com`.

### Expected result

```text
Regex: email ends with @gmail.com
  query={'email': {'$regex': '@gmail.com$'}}
  count=3
  names=[Anna, Chris, Emma]
```

### Hint

Anchor the pattern with `$` to mean "end of string". Use `^` for "starts with".

### Solution

```python
gmail = list(coll.find({"email": {"$regex": "@gmail.com$"}}, {"_id": 0, "name": 1}).sort("name", 1))
print([d["name"] for d in gmail])
```

```javascript
db.filtering_people.find({ email: { $regex: "@gmail.com$" } }, { _id: 0, name: 1 }).sort({ name: 1 });
// Or the JS-literal regex form:
db.filtering_people.find({ email: /@gmail\.com$/ }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Step-by-step explanation

1. **`$regex` accepts a PCRE-like string** (no surrounding `/.../` needed). `^` anchors to the start, `$` to the end.
2. **`.` is a wildcard, not a literal dot.** `@gmail.com$` happens to work here because the literal `.` lies between `gmail` and `com` and only `gmail.com` triggers a real match — but the pedantic regex is `@gmail\.com$`.
3. **Case-insensitive search.** Add `{$regex: "@GMAIL", $options: "i"}` or use a JS `/.../i` literal in mongosh.
4. **Index usability.** A prefix-anchored regex (`^anna`) **can** use an index. A free-floating or end-anchored pattern (`gmail.com$`) cannot, so it's a full collection scan — fine for 5 docs, painful for millions.

---

## Exercise 9 — `$exists` (field present or missing)

### Context

The contact-cleanup report needs two slices: customers we **have a phone for** (we can SMS them), and those whose phone is **missing** (they need a follow-up email asking for one).

### What you'll learn

- `$exists: true` vs. `$exists: false`.
- The distinction between *missing field* and *field with value `null`*.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `phone` | string \| missing | Bohdan has no `phone` field at all. |

### Task

1. `$exists: true` — return users with a `phone` field present.
2. `$exists: false` — return users with no `phone` field.

### Expected result

```text
$exists: has phone field
  query={'phone': {'$exists': True}}
  count=4
  names=[Anna, Chris, Daria, Emma]

$exists: phone field is missing
  query={'phone': {'$exists': False}}
  count=1
  names=[Bohdan]
```

### Hint

`{ phone: { $exists: true } }` — note the boolean, not a string.

### Solution

```python
have   = list(coll.find({"phone": {"$exists": True}},  {"_id": 0, "name": 1}).sort("name", 1))
missing = list(coll.find({"phone": {"$exists": False}}, {"_id": 0, "name": 1}).sort("name", 1))
print("have   :", [d["name"] for d in have])
print("missing:", [d["name"] for d in missing])
```

```javascript
db.filtering_people.find({ phone: { $exists: true  } }, { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ phone: { $exists: false } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Step-by-step explanation

1. **`$exists` only tests presence, not value.** A document with `phone: null` would still match `$exists: true`.
2. **To filter "has a non-null value"**, combine: `{phone: {$exists: true, $ne: None}}`.
3. **`$exists` is the closest MongoDB has to SQL `IS NULL`.** SQL has a defined "no value" concept; MongoDB has two — *missing field* and *explicit `null`*. Be deliberate about which one you mean.
4. **Index help.** `$exists: true` can use an existing index. `$exists: false` typically cannot (you'd need a sparse index).

---

## Quick reference

| Goal | Operator | Example |
|---|---|---|
| Select all | `find({})` | `coll.find({})` |
| One row | `find_one({...})` | `coll.find_one({"name": "Anna"})` |
| Strict comparison | `$gt`, `$gte`, `$lt`, `$lte`, `$ne` | `{age: {$gt: 25}}` |
| Set membership | `$in`, `$nin` | `{city: {$in: ["NY", "LA"]}}` |
| AND / OR / NOT | `$and`, `$or`, `$not` | `{$or: [{age: {$lt: 18}}, {age: {$gt: 40}}]}` |
| Nested key | dot notation | `{"profile.city": "Kyiv"}` |
| Array (whole) | `$all`, `$size`, `$elemMatch` | (see Exercise 7) |
| Pattern | `$regex` | `{email: {$regex: "@gmail.com$"}}` |
| Field exists | `$exists` | `{phone: {$exists: true}}` |

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `$and` with same field returns wrong rows | You wrote `{age: A, age: B}` — the second key overrides the first. Wrap with `$and`. |
| `$nin` returns docs without the field | Expected — `$nin` matches missing fields. Add `$exists: true`. |
| Regex slow | Anchor with `^` to enable index usage, or precompute a lowercase normalised field. |
| Comparison on string returns nothing | Type mismatch — `{age: {$gt: "10"}}` won't compare against numeric ages. |
| Dot-notation matches across elements | Use `$elemMatch` to bind the conditions to the same array element. |
