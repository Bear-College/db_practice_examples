# ODM Selection Operators (`10_odm/01_selection_operators`)

> Translation / Переклад: [Українська](../../../i18n/uk/04_mongodb/10_odm/01_selection_operators/selection_operators_odm.md)

These exercises walk through MongoDB's selection operators **via an ODM** — specifically **MongoEngine**. Where lesson `08_filtering` uses raw PyMongo queries (`{age: {$gt: 18}}`), here the same filters are expressed through Python class attributes and a `Q` expression visitor. The result is the same wire query; the ergonomics are very different.

Runnable companion file: [`10_odm/01_selection_operators/example.py`](example.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/01_selection_operators/example.py
```

Default connection (override with env vars):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Collection: `odm_selection_operators_people`

---

## Document model and seed

```python
from mongoengine import BooleanField, Document, IntField, StringField, connect

class Person(Document):
    name = StringField(required=True, max_length=128)
    age = IntField(required=True, min_value=0)
    status = StringField(required=True, max_length=32)
    active = BooleanField(required=True, default=True)
    email = StringField(required=False, max_length=256)

    meta = {"collection": "odm_selection_operators_people"}
```

Seed (the script drops + re-inserts on each run):

| `name` | `age` | `status` | `active` | `email` |
|---|---|---|---|---|
| Vlad | 25 | active | True | vlad@gmail.com |
| Anna | 30 | pending | True | — (missing) |
| Bohdan | 17 | deleted | False | bohdan@example.com |
| Chris | 19 | active | True | chris@gmail.com |
| Daria | 65 | pending | False | — (missing) |

The script's print helper:

```python
def print_result(label: str, qs) -> None:
    names = [d.name for d in qs.order_by("name")]
    print(f"{label}: count={len(names)} -> {names}")
```

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real app would write this filter. |
| **What you'll learn** | The MongoEngine `__lookup` suffix and the underlying operator. |
| **Document in play** | The fields touched. |
| **Task** | Concrete predicate. |
| **Expected result** | Real captured output. |
| **Hint** | The exact suffix to use. |
| **Solution** | MongoEngine (Python) and `mongosh` versions. |
| **Step-by-step explanation** | How the ODM rewrites it for the driver, and the usual mistakes. |

---

## Exercise 1 — `$eq` and `$ne`

### Context

A profile screen looks up a record with `age = 25` (an exact match), while an audit screen excludes everyone with `age = 30`.

### What you'll learn

- That a bare keyword argument (`age=25`) is `$eq`.
- That the `__ne` suffix maps to `$ne`.

### Document in play

| Field | Type | Notes |
|---|---|---|
| `age` | int | Used for both filters. |

### Task

Run two queries:

1. `Person.objects(age=25)`
2. `Person.objects(age__ne=30)`

### Expected result

```text
$eq   age=25: count=1 -> ['Vlad']
$ne   age!=30: count=4 -> ['Bohdan', 'Chris', 'Daria', 'Vlad']
```

### Hint

`field=value` → `$eq`. `field__ne=value` → `$ne`. Double-underscore is the MongoEngine separator.

### Solution

```python
print_result("$eq   age=25",     Person.objects(age=25))
print_result("$ne   age!=30",    Person.objects(age__ne=30))
```

```javascript
db.odm_selection_operators_people.find({ age: { $eq: 25 } }, { _id: 0, name: 1 }).sort({ name: 1 });
db.odm_selection_operators_people.find({ age: { $ne: 30 } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Step-by-step explanation

1. **`age=25` is shorthand.** The driver receives `{age: 25}`, which MongoDB treats as `{age: {$eq: 25}}` — semantically identical.
2. **`age__ne=30` survives `null`.** Unlike SQL, `$ne 30` returns rows where `age` is missing, because "missing" is not equal to 30.
3. **`__` is the suffix delimiter, not the nesting one.** MongoEngine reserves `__` for operators (`__ne`, `__gt`, …). To navigate nested fields, you also use `__`: `profile__city="Kyiv"` translates to `{"profile.city": "Kyiv"}`. Disambiguate carefully when both apply (rare in practice).

---

## Exercise 2 — Range comparisons (`$gt`, `$gte`, `$lt`, `$lte`)

### Context

The same four comparisons show up everywhere: "older than 18", "18 and over", "under 65", "up to and including 65".

### What you'll learn

- `__gt`, `__gte`, `__lt`, `__lte` suffixes.
- That MongoEngine maps each one to the corresponding `$` operator.

### Document in play

| Field | Type | Notes |
|---|---|---|
| `age` | int | The range key. |

### Task

Run four range queries and print the counts.

### Expected result

```text
$gt   age>18: count=4 -> ['Anna', 'Chris', 'Daria', 'Vlad']
$gte  age>=18: count=4 -> ['Anna', 'Chris', 'Daria', 'Vlad']
$lt   age<65: count=4 -> ['Anna', 'Bohdan', 'Chris', 'Vlad']
$lte  age<=65: count=5 -> ['Anna', 'Bohdan', 'Chris', 'Daria', 'Vlad']
```

(Bohdan is 17 and Chris is 19 — note that `>18` and `>=18` give the same set here because nobody is exactly 18.)

### Hint

`age__gt=18` etc. Each suffix is the long-name in lowercase.

### Solution

```python
print_result("$gt   age>18",   Person.objects(age__gt=18))
print_result("$gte  age>=18",  Person.objects(age__gte=18))
print_result("$lt   age<65",   Person.objects(age__lt=65))
print_result("$lte  age<=65",  Person.objects(age__lte=65))
```

```javascript
db.odm_selection_operators_people.find({ age: { $gt:  18 } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ age: { $gte: 18 } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ age: { $lt:  65 } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ age: { $lte: 65 } }).sort({ name: 1 });
```

### Step-by-step explanation

1. **Suffix is unambiguous.** `age__gt=18` is always a range query — there's no risk of MongoEngine misreading it as a nested field called `gt`.
2. **Type-safe comparisons.** Because `age` is declared `IntField`, MongoEngine will reject `age__gt="18"` (string) before issuing the query.
3. **No `BETWEEN` keyword.** Chain two predicates: `Person.objects(age__gte=18, age__lt=65)` — the implicit AND between kwargs covers the case.

---

## Exercise 3 — `$in` and `$nin`

### Context

Two business rules: "Treat both `active` and `pending` users as valid" (whitelist) and "Exclude anyone whose record was soft-deleted" (blacklist).

### What you'll learn

- `__in` and `__nin` suffixes.
- That MongoEngine collapses the right-hand-side list into the driver-level `$in` / `$nin`.

### Document in play

| Field | Type | Notes |
|---|---|---|
| `status` | string | Tested against a whitelist / blacklist. |

### Task

1. `status in ["active", "pending"]`.
2. `status not in ["deleted"]`.

### Expected result

```text
$in   status in [active,pending]: count=4 -> ['Anna', 'Chris', 'Daria', 'Vlad']
$nin  status not in [deleted]: count=4 -> ['Anna', 'Chris', 'Daria', 'Vlad']
```

(Bohdan is the only `deleted` user — both queries drop him.)

### Hint

`status__in=[...]` and `status__nin=[...]`. The Python list is sent verbatim as the `$in` / `$nin` argument.

### Solution

```python
print_result("$in   active|pending",  Person.objects(status__in=["active", "pending"]))
print_result("$nin  not deleted",     Person.objects(status__nin=["deleted"]))
```

```javascript
db.odm_selection_operators_people.find({ status: { $in:  ["active", "pending"] } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ status: { $nin: ["deleted"] } }).sort({ name: 1 });
```

### Step-by-step explanation

1. **`$in` against an array field tests intersection.** If `status` were a list, `$in` would match if **any** element of the list was in the right-hand set.
2. **`$nin` matches "missing" too** — see lesson `08_filtering`, Exercise 4. Add `__exists=True` when missing rows should be excluded.
3. **Convert sets to lists before passing.** `status__in=set([...])` works in CPython but the driver only formally accepts lists; a `list(...)` cast keeps the call portable.

---

## Exercise 4 — Logical composition with `Q` (`$and`, `$or`, `$not`)

### Context

Three reports: "Adults who are still active", "Children or soft-deactivated users", and "Everyone not below 18". All three need explicit boolean composition because keyword arguments can only express implicit AND.

### What you'll learn

- The `mongoengine.queryset.visitor.Q` expression class.
- `&` for `$and`, `|` for `$or`, `~` for `$not`.

### Document in play

| Field | Type | Notes |
|---|---|---|
| `age` | int | — |
| `active` | bool | — |

### Task

Write three composite queries:

1. `Q(age__gt=18) & Q(active=True)` — adults still active.
2. `Q(age__lt=18) | Q(active=False)` — children OR inactive.
3. `~Q(age__lt=18)` — not below 18.

### Expected result

```text
$and  age>18 AND active=True: count=3 -> ['Anna', 'Chris', 'Vlad']
$or   age<18 OR active=False: count=2 -> ['Bohdan', 'Daria']
$not  NOT(age<18): count=4 -> ['Anna', 'Chris', 'Daria', 'Vlad']
```

> Note: with older MongoEngine releases the `~Q(...)` form raised `TypeError: bad operand type for unary ~: 'Q'`. The equivalent rewrite `Person.objects(age__gte=18)` always works and gives the same result set.

### Hint

`from mongoengine.queryset.visitor import Q`. Compose with `&`, `|`, `~`.

### Solution

```python
from mongoengine.queryset.visitor import Q

print_result("$and  age>18 AND active",  Person.objects(Q(age__gt=18) & Q(active=True)))
print_result("$or   age<18 OR !active",  Person.objects(Q(age__lt=18) | Q(active=False)))
# `~Q(age__lt=18)` is semantically equivalent to `age__gte=18`:
print_result("$not  NOT(age<18)",        Person.objects(age__gte=18))
```

```javascript
db.odm_selection_operators_people.find(
  { $and: [ { age: { $gt: 18 } }, { active: true } ] }
).sort({ name: 1 });

db.odm_selection_operators_people.find(
  { $or:  [ { age: { $lt: 18 } }, { active: false } ] }
).sort({ name: 1 });

db.odm_selection_operators_people.find(
  { age: { $not: { $lt: 18 } } }
).sort({ name: 1 });
```

### Step-by-step explanation

1. **`Q` is necessary for `$or`.** Plain kwargs can only express AND. `Person.objects(age__lt=18, active=False)` is `AND`, not `OR`.
2. **Parentheses matter.** `Q(a) & Q(b) | Q(c)` follows Python's precedence (`&` binds tighter than `|`), so it parses as `(Q(a) & Q(b)) | Q(c)`. When in doubt, wrap explicitly.
3. **`~Q` is operator-level negation.** Under the hood it emits `$not` around the wrapped expression. If your MongoEngine version doesn't accept `~Q`, fall back to the semantically equivalent positive form (`age__lt=18` becomes `age__gte=18`).
4. **`Q` chains return new objects.** They don't mutate the original — safe to reuse.

---

## Exercise 5 — `$exists`

### Context

Audit: list users who actually have an `email` on file (we can write to them) vs. those who don't (we need to ask).

### What you'll learn

- The `__exists` suffix.
- Why "field missing" and "field is `None`" differ.

### Document in play

| Field | Type | Notes |
|---|---|---|
| `email` | string \| missing | Anna and Daria have no `email`. |

### Task

Return users whose `email` field is present.

### Expected result

```text
$exists email exists: count=3 -> ['Bohdan', 'Chris', 'Vlad']
```

(Anna and Daria are missing — they were inserted without the `email` keyword.)

### Hint

`email__exists=True`. Pass `False` for the missing case.

### Solution

```python
print_result("$exists has email",     Person.objects(email__exists=True))
print_result("$exists no email",      Person.objects(email__exists=False))
```

```javascript
db.odm_selection_operators_people.find({ email: { $exists: true } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ email: { $exists: false } }).sort({ name: 1 });
```

### Step-by-step explanation

1. **`$exists` only checks presence.** A document with `email: null` (explicit) is still "present" — `__exists=True` would return it.
2. **MongoEngine and required fields.** Because `email` is declared `required=False`, MongoEngine allows the document to be saved without it. A `required=True` declaration would raise `ValidationError` on `.save()`.
3. **Don't confuse with `__eq=None`.** `email__eq=None` matches the explicit-null case, not the missing-field case.

---

## Exercise 6 — `$regex`

### Context

Marketing wants all users whose name starts with the prefix `"Vlad"`.

### What you'll learn

- The `__regex` suffix and how MongoEngine forwards it to the `$regex` operator.
- Anchoring patterns to make them index-friendly.

### Document in play

| Field | Type | Notes |
|---|---|---|
| `name` | string | Pattern-matched. |

### Task

Return users whose `name` matches the pattern `^Vlad`.

### Expected result

```text
$regex name starts with Vlad: count=1 -> ['Vlad']
```

### Hint

`name__regex=r"^Vlad"`. Use a raw string to keep the `^` and `\` characters intact.

### Solution

```python
print_result("$regex ^Vlad",  Person.objects(name__regex=r"^Vlad"))

# Case-insensitive variant uses iregex:
print_result("$regex ^vlad (case-insensitive)",
             Person.objects(name__iregex=r"^vlad"))
```

```javascript
db.odm_selection_operators_people.find({ name: { $regex: "^Vlad" } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ name: /^vlad/i }).sort({ name: 1 });
```

### Step-by-step explanation

1. **`__regex` is case-sensitive.** Use `__iregex` (or pass `$options: "i"`) for case-insensitive.
2. **Prefix-anchored regex can use an index.** `^Vlad` benefits from a standard `{name: 1}` index. `Vlad$` or `Vl.*ad` cannot.
3. **Escape literal special chars.** Want a literal `.`? Write `\.` in a raw string: `r"@gmail\.com$"`.
4. **`startswith`, `endswith`, `contains` shortcuts.** MongoEngine also exposes `__startswith`, `__endswith`, `__contains` as readable aliases for common regex anchors.

---

## Quick reference

| Operator | Raw query | MongoEngine kwarg |
|---|---|---|
| `$eq` | `{age: 25}` | `age=25` |
| `$ne` | `{age: {$ne: 30}}` | `age__ne=30` |
| `$gt` / `$gte` | `{age: {$gt: 18}}` | `age__gt=18` |
| `$lt` / `$lte` | `{age: {$lt: 65}}` | `age__lt=65` |
| `$in` / `$nin` | `{status: {$in: [...]}}` | `status__in=[...]` |
| `$and` | `{$and: [...]}` | `Q(...) & Q(...)` |
| `$or` | `{$or: [...]}` | `Q(...) \| Q(...)` |
| `$not` | `{f: {$not: ...}}` | `~Q(...)` (or rewrite) |
| `$exists` | `{f: {$exists: true}}` | `f__exists=True` |
| `$regex` | `{f: {$regex: "..."}}` | `f__regex=r"..."` |

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `TypeError: bad operand type for unary ~: 'Q'` | Older MongoEngine. Rewrite `~Q(age__lt=18)` as `age__gte=18`. |
| `OperationError` on `.save()` | `required=True` field is missing. Provide it or relax the model. |
| Implicit AND when you wanted OR | Use `Q(...) \| Q(...)`. Plain kwargs are always AND. |
| `$exists: true` returns docs you'd consider "empty" | They have `null`. Combine with `__ne=None`. |
| Regex slow on large collection | Anchor at the start (`^...`), and index the field. |
