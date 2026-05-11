# Check Operators in MongoDB (`05_check_operators`)

> Translation / Переклад: [Українська](../../i18n/uk/04_mongodb/05_check_operators/check_operators_mongodb.md)

These exercises cover the **field-shape / type-check operators** of MongoDB: `$exists`, `$type`, `$mod`, and the general-purpose `$expr` for aggregation-style expressions inside a query.

All examples run against database `edu_academy_seed` and collection **`check_operators_people`**.

Runnable companion file: [`05_check_operators/example.py`](example.py). It demonstrates `$exists` and `$type`. The `$mod` and `$expr` exercises below were captured separately via `mongosh` on the same seed data.

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/05_check_operators/example.py
```

Default settings:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

The seed deliberately mixes BSON types in the `age` field (`int`, `double`, `string`) so you can see how `$type` distinguishes them.

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real data-quality job needs the operator. |
| **What you'll learn** | The PyMongo/mongosh syntax for the operator. |
| **Collection in play** | Documents and fields actually queried. |
| **Task** | Concrete predicate to run. |
| **Expected result** | Real `count` and `docs` lines from a live run. |
| **Hint** | A single nudge toward the operator. |
| **Solution** | Working Python (PyMongo) **and** equivalent mongosh JavaScript. |
| **Step-by-step explanation** | BSON-type semantics, aggregation-expression syntax, and common gotchas. |

---

## Map: check / shape operators

| Operator | Purpose | Example |
|---|---|---|
| `$exists` | Does the field exist on the document? | `{ phone: { "$exists": true } }` |
| `$type` | Is the field of this BSON type? | `{ age: { "$type": "int" } }` |
| `$mod` | Is `field % divisor == remainder`? | `{ age: { "$mod": [2, 1] } }` |
| `$expr` | Allow aggregation-expression syntax (computed fields, `$gt` between fields) | `{ "$expr": { "$gt": [ { "$strLenCP": "$phone" }, 15 ] } }` |

## BSON type aliases used by `$type`

| Alias | BSON type | Python literal |
|---|---|---|
| `"int"` | `Int32` | small `int` |
| `"long"` | `Int64` | large `int` (or `bson.Int64`) |
| `"double"` | `Double` | `float` |
| `"decimal"` | `Decimal128` | `bson.Decimal128` |
| `"string"` | `String` | `str` |
| `"bool"` | `Boolean` | `bool` |
| `"date"` | `Date` | `datetime.datetime` |
| `"objectId"` | `ObjectId` | `bson.ObjectId` |
| `"array"` | `Array` | `list` |
| `"object"` | embedded document | `dict` |

## Collection schema

The seed inserts 5 documents with intentionally mixed types and an optional `phone`:

```json
[
  { "name": "Anna",   "age": 17,   "phone": "+1-202-555-0101" },
  { "name": "Bohdan", "age": 18 },
  { "name": "Chris",  "age": 25,   "phone": "+1-202-555-0102" },
  { "name": "Daria",  "age": 30.5, "phone": "+380-44-555-0103" },
  { "name": "Emma",   "age": "45", "phone": "+1-202-555-0104" }
]
```

| Field | Mix of BSON types in the seed |
|---|---|
| `age` | `Int32` (Anna, Bohdan, Chris), `Double` (Daria), `String` (Emma) |
| `phone` | present for everyone **except** Bohdan |

---

## Exercise 1 — `$exists` (field presence)

### Context

Marketing wants to call back every customer with a phone on file. Documents missing the `phone` field must be skipped.

### What you'll learn

- The `$exists` operator with `true` / `false`.
- The difference between "field absent" and "field present with `null`".

### Collection in play

| Field | Predicate |
|---|---|
| `phone` | exists (present on the document) |

### Task

Find every person whose document **has** a `phone` field, sorted by `name`.

### Expected result

```text
$exists (field exists)
  query={'phone': {'$exists': True}}
  count=4
  docs=[Anna (age=17, phone=+1-202-555-0101, age_type=int), Chris (age=25, phone=+1-202-555-0102, age_type=int), Daria (age=30.5, phone=+380-44-555-0103, age_type=float), Emma (age=45, phone=+1-202-555-0104, age_type=str)]
```

(Bohdan is excluded — he has no `phone` field.)

### Hint

`{"phone": {"$exists": True}}` for "present", `False` for "absent".

### Solution

```python
docs = list(coll.find({"phone": {"$exists": True}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.check_operators_people.find({ phone: { $exists: true } }, { _id: 0 }).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$exists` only checks whether the key is in the document.** A field with `"phone": null` is **present** — `$exists: true` returns it. To check for "non-null and present" use `{phone: {$ne: null}}`, which combines absence and null.
2. **`$exists: false`** returns documents where the key is missing. Useful for backfilling: "find every row that hasn't been migrated yet".
3. **Index usage:** `$exists: true` can sometimes use a sparse or partial index efficiently; `$exists: false` rarely can. For data-quality scans on huge collections, build a partial index for the field you care about.
4. **The `age_type` column in the expected output** is computed in Python (`type(d["age"]).__name__`) — it shows that `$exists` ignores BSON type entirely, whereas `$type` (next exercise) is type-specific.

---

## Exercise 2 — `$type` (BSON type check)

### Context

Data-quality audit: the analyst expected `age` to be a clean integer everywhere, but suspects mixed types. Show only the documents where `age` is actually a BSON `Int32`.

### What you'll learn

- Filtering by BSON type with the `$type` operator.
- Why type checks are necessary when data arrives from messy upstream sources.

### Collection in play

| Field | Predicate |
|---|---|
| `age` | BSON type is `Int32` (alias `"int"`) |

### Task

Find every person whose `age` is a BSON `int`, sorted by `name`.

### Expected result

```text
$type (field type is int)
  query={'age': {'$type': 'int'}}
  count=3
  docs=[Anna (age=17, phone=+1-202-555-0101, age_type=int), Bohdan (age=18, phone=N/A, age_type=int), Chris (age=25, phone=+1-202-555-0102, age_type=int)]
```

(Daria's `30.5` is `Double`; Emma's `"45"` is `String` — both excluded.)

### Hint

`{"age": {"$type": "int"}}` — the alias is a quoted string, not a number.

### Solution

```python
docs = list(coll.find({"age": {"$type": "int"}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.check_operators_people.find({ age: { $type: "int" } }, { _id: 0 }).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$type` accepts string aliases or numeric type codes.** Strings (`"int"`, `"double"`, `"string"`, …) are much more readable; numeric codes (1=Double, 2=String, 16=Int32, 18=Int64) come from the BSON specification.
2. **Pass an array to allow multiple types:** `{"age": {"$type": ["int", "long"]}}` matches both `Int32` and `Int64`. Useful when migrations have left numeric fields in two sizes.
3. **`"number"` is a convenience alias** that matches any of `Int32`, `Int64`, `Double`, `Decimal128`. Use it when you don't care which numeric width.
4. **Python ↔ BSON mapping**: a Python `int` fitting in 32 bits ⇒ `Int32` (alias `"int"`). A larger Python `int` ⇒ `Int64` (alias `"long"`). A Python `float` ⇒ `Double`. PyMongo never silently coerces a string to a number — that's why Emma's age stays as `"string"`.

---

## Exercise 3 — `$mod` (modulo arithmetic)

### Context

A simple admin filter: find everyone whose **age is odd**. We use `age % 2 == 1` — and `$mod` packages the divisor and remainder in one operator.

### What you'll learn

- The `$mod` operator and its `[divisor, remainder]` array.
- Why `$mod` quietly skips non-numeric values.

### Collection in play

| Field | Predicate |
|---|---|
| `age` | `age % 2 == 1` (odd numbers) |

### Task

Find every person whose `age` modulo `2` equals `1` (i.e. odd-aged people), sorted by `name`.

### Expected result (captured live via `mongosh`)

```text
$mod count=2
[
  { name: 'Anna',  age: 17, phone: '+1-202-555-0101' },
  { name: 'Chris', age: 25, phone: '+1-202-555-0102' }
]
```

(Anna 17 and Chris 25 are the odd-aged numeric documents. Bohdan 18 is even. Daria's 30.5 is `Double` and not an integer — `$mod` skips it. Emma's `"45"` is a string — `$mod` cannot compare and skips it.)

### Hint

`{"age": {"$mod": [2, 1]}}` — two-element array: `[divisor, remainder]`.

### Solution

```python
docs = list(coll.find({"age": {"$mod": [2, 1]}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.check_operators_people.find({ age: { $mod: [2, 1] } }, { _id: 0 }).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$mod` takes a two-element array.** Anything else throws a `BadValue`. The first element is the divisor, the second is the remainder you want.
2. **Non-numeric values are silently skipped.** Emma's string age does **not** raise an error — Mongo simply returns "no match" for that document. That's why a data audit should pair `$mod` with `$type` to know how many documents the filter ignored.
3. **Floating-point gotcha:** `{"age": {"$mod": [2, 0]}}` on a `Double` such as `30.5` returns false (`30.5 % 2 == 0.5`). `$mod` honours floating-point arithmetic — for "integers only" first restrict with `{"age": {"$type": "int"}}`.
4. **Indexes:** `$mod` is not index-friendly. The planner has to read each value and compute the remainder. Use as a secondary predicate, not the primary filter.

---

## Exercise 4 — `$expr` (computed-field comparison)

### Context

We're auditing phone numbers and want every document where the **stored phone is longer than 15 characters** (suggests it includes a country code or extension). A simple `$eq`/`$gt` on the field value won't work — we need to compare the **length** of the field, not its value.

### What you'll learn

- The `$expr` operator, which lifts aggregation-expression syntax into the query language.
- Computing on field values with `$strLenCP`, `$ifNull`, and friends.
- Using `$` field references (`"$phone"`) inside `$expr`.

### Collection in play

| Field | Predicate |
|---|---|
| `phone` | `strLenCP(phone) > 15` |

### Task

Find every person whose `phone` string is **longer than 15 characters**, sorted by `name`.

### Expected result (captured live via `mongosh`)

```text
$expr strLen > 15 count=1
[
  { name: 'Daria', age: 30.5, phone: '+380-44-555-0103' }
]
```

(All four phones in the seed have lengths 15 (`+1-202-555-0101`-style) or 16 (Daria's UA-style). Only Daria's 16-character number passes the strict `> 15` check.)

### Hint

`{"$expr": {"$gt": [{"$strLenCP": {"$ifNull": ["$phone", ""]}}, 15]}}` — `$expr` allows you to write an expression that references the field with a `$` prefix.

### Solution

```python
docs = list(coll.find(
    {
        "$expr": {
            "$gt": [
                {"$strLenCP": {"$ifNull": ["$phone", ""]}},
                15,
            ]
        }
    },
    {"_id": 0},
).sort("name", 1))
```

```javascript
db.check_operators_people.find(
  {
    $expr: {
      $gt: [
        { $strLenCP: { $ifNull: ["$phone", ""] } },
        15
      ]
    }
  },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$expr` switches the parser to aggregation-expression mode.** Inside it, `$gt` becomes the *aggregation* `$gt` (a function that takes an array `[a, b]`), not the *query* `$gt` (a single operand to a field).
2. **Field references with `"$phone"`.** The leading `$` means "the value of the `phone` field for this document". Without the `$`, you'd be comparing against the literal string `"phone"`.
3. **`$ifNull: ["$phone", ""]`** protects against documents missing the field (Bohdan). Without it, `$strLenCP` on a missing field would fail or return null. The fallback `""` ensures Bohdan's "length" is 0 — well below 15, so he is correctly excluded.
4. **`$strLenCP`** counts Unicode code points (right for most languages). `$strLenBytes` counts UTF-8 bytes — different number for non-ASCII strings.
5. **When to choose `$expr` over plain query operators:**
   - You need to compare **two fields of the same document** (`$expr: { $gt: ["$created_at", "$updated_at"] }`).
   - You need to **compute** something from the field (length, year of a date, sum of an array).
   - You need aggregation operators (`$cond`, `$switch`, `$concat`, …) inside a `find()`.
   - Plain query operators do the job for `field <op> constant` comparisons — keep them simple when you can; `$expr` has more parsing overhead.

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `$exists: true` returns docs with `null` values | That's by design — `null` is "present". Combine with `$ne: null` if you want non-null only. |
| `$type: "int"` misses values that look like integers | They are likely `Double` (`30.0`) or `String` (`"30"`). Use `$type: ["int", "long", "double"]` or `$type: "number"`. |
| `$mod` returns nothing on an obviously matching doc | The field is stored as a string or has a fractional part — restrict with `$type: "int"` first. |
| `$expr` complains about `"$"` field name | You forgot the dollar sign — without it Mongo treats the value as a literal. |
| `$expr` ignored my predicate | Inside `$expr` use aggregation `$gt`/`$lt` with arrays, **not** the query-style `{ $gt: 5 }` form. |

Run the included examples: `python 04_mongodb/05_check_operators/example.py` (covers `$exists` and `$type`). The `$mod` and `$expr` queries can be reproduced verbatim in `mongosh` once the seed is in place.
