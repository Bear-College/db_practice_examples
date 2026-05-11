# String Operators in MongoDB (`04_string_operators`)

> Translation / Переклад: [Українська](../../i18n/uk/04_mongodb/04_string_operators/string_operators_mongodb.md)

These exercises cover the **three string-search operators** of MongoDB query language: `$regex`, the companion modifier `$options`, and the full-text `$text` operator.

All examples run against database `edu_academy_seed` and collection **`string_operators_people`**.

Runnable companion file: [`04_string_operators/example.py`](example.py). It demonstrates `$regex` (anchored) and `$text` (full-text); the `$regex` + `$options` exercise below was captured separately via `mongosh` on the same seed data.

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/04_string_operators/example.py
```

Default settings:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

The script drops & re-creates the collection on every run and creates a **text index** on `bio` (`db.string_operators_people.createIndex({ bio: "text" }, { name: "ix_bio_text" })`), which is mandatory for `$text` to work.

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real catalog / directory app needs the operator. |
| **What you'll learn** | The PyMongo/mongosh syntax for the operator. |
| **Collection in play** | Fields read by the filter. |
| **Task** | Concrete string search to perform. |
| **Expected result** | Real `count` and `docs` lines from a live run. |
| **Hint** | A single nudge toward the operator or regex anchor. |
| **Solution** | Working Python (PyMongo) **and** equivalent mongosh JavaScript. |
| **Step-by-step explanation** | Regex anchors, options flags, and `$text` indexing rules. |

---

## Map: string-search operators

| Operator | Purpose | SQL analogue |
|---|---|---|
| `$regex` | Pattern match (PCRE-compatible) | `LIKE '…%'`, `REGEXP '…'` |
| `$options` | Modifiers for `$regex`: `i` case-insensitive, `m` multiline, `s` dot-matches-all, `x` extended | (driver-specific in SQL) |
| `$text` | Indexed full-text search with stemming and scoring | `MATCH(col) AGAINST('…')` |

## Collection schema

```json
{ "name": "Anna", "email": "anna@gmail.com", "bio": "Frontend developer and UI engineer" }
```

| Field | BSON type | Notes |
|---|---|---|
| `name` | `string` | Person name. |
| `email` | `string` | Used for the `$regex` example. |
| `bio` | `string` | Used for `$regex+$options` and `$text` examples. Backed by a **text index**. |

The seed inserts 4 documents (Anna, Bohdan, Chris, Daria).

---

## Exercise 1 — `$regex` (anchored pattern)

### Context

Marketing wants the email list for the Gmail-only newsletter. We need every user whose `email` **ends with** `@gmail.com`.

### What you'll learn

- The `$regex` operator with a pattern string.
- Using anchors (`$` for end-of-string, `^` for start-of-string).
- Why anchoring is important for performance and correctness.

### Collection in play

| Field | Pattern |
|---|---|
| `email` | `@gmail.com$` (ends with `@gmail.com`) |

### Task

Find every person whose `email` ends with the literal `@gmail.com`, sorted by `name`.

### Expected result

```text
$regex (similar to SQL LIKE)
  query={'email': {'$regex': '@gmail.com$'}}
  count=2
  docs=[Anna <anna@gmail.com>, Chris <chris@gmail.com>]
```

### Hint

`{"email": {"$regex": "@gmail.com$"}}` — the `$` at the end is the regex anchor "end of string", **not** the BSON `$` prefix.

### Solution

```python
docs = list(coll.find(
    {"email": {"$regex": "@gmail.com$"}},
    {"_id": 0},
).sort("name", 1))
```

```javascript
db.string_operators_people.find(
  { email: { $regex: "@gmail.com$" } },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$regex` is PCRE-flavoured** (Perl-compatible). `^` anchors to start, `$` to end, `.` matches any character, `\\.` (in JSON) matches a literal dot.
2. **The dot is a regex meta-character**: technically `@gmail.com` could also match `@gmailXcom`. For exact literal matching, escape it: `"@gmail\\.com$"`. With only 4 sample documents we got lucky here — in production, always escape.
3. **Anchored vs unanchored:** without a `^` or `$`, the regex scans for the pattern anywhere in the field. Unanchored regex queries **cannot use a btree index efficiently** — MongoDB falls back to a collection scan. A regex of the form `^foo` (left-anchored on an indexed string field) is the only fast case.
4. **PyMongo also accepts compiled `re.Pattern`** objects directly: `{"email": re.compile("@gmail\\.com$")}` — equivalent and slightly safer because Python escapes for you.

---

## Exercise 2 — `$regex` + `$options` (case-insensitive search)

### Context

The HR search box should find people who mention **"Python"** in their bio — but a typo like `PYTHON` or `python` should still match. We need case-insensitive matching.

### What you'll learn

- The `$options` modifier alongside `$regex`.
- The `i` flag (case-insensitive), `m` (multiline), `s` (dot-matches-newline), `x` (extended/comments).
- How to combine flags.

### Collection in play

| Field | Pattern | Flags |
|---|---|---|
| `bio` | `PYTHON` | `i` (case-insensitive) |

### Task

Find every person whose `bio` contains the substring `python` (case-insensitively), sorted by `name`.

### Expected result (captured live via `mongosh`)

```text
$regex+$options count=1
[
  {
    name: 'Bohdan',
    email: 'bohdan@outlook.com',
    bio: 'Backend developer working with Python'
  }
]
```

Only Bohdan's bio mentions Python.

### Hint

Use `"$options": "i"` next to `"$regex": "..."` inside the same operator dict.

### Solution

```python
docs = list(coll.find(
    {"bio": {"$regex": "PYTHON", "$options": "i"}},
    {"_id": 0},
).sort("name", 1))
```

```javascript
db.string_operators_people.find(
  { bio: { $regex: "PYTHON", $options: "i" } },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$options` is a string of flag letters.** `i` (case-insensitive) is the most common; `m` makes `^`/`$` match per line; `s` makes `.` match newlines; `x` allows whitespace/comments in long regexes. Combine like `"im"`.
2. **`$options` only makes sense next to `$regex`.** Using it alone has no effect.
3. **In PyMongo you can also use the compiled-regex shortcut**: `re.compile("python", re.IGNORECASE)`. PyMongo translates the Python flags into `$options` under the hood, which is often more readable.
4. **Case-insensitive search is more expensive** because Mongo cannot use a normal index for it. For very large collections, store a separate lowercase copy of the field and search that with `$eq`, or build a **case-insensitive collation index** (`{ collation: { locale: "en", strength: 2 } }`).

---

## Exercise 3 — `$text` (full-text search)

### Context

The "find me developers" search bar should pull anyone whose **bio mentions** the word `developer`. The bio field is large enough that we want stemming and word-boundary handling (so `developer`, `developers`, `developing` all relate) and the operation must be fast — i.e. indexed.

### What you'll learn

- The `$text` operator and `$search` payload.
- Why `$text` **requires** a text index on the field.
- How `$text` differs from `$regex`: stemming, word-boundaries, scoring.

### Collection in play

| Field | Search term | Index |
|---|---|---|
| `bio` | `"developer"` | text index `ix_bio_text` |

### Task

Find every person whose `bio` contains the word `developer` (with stemming), sorted by `name`.

### Expected result

```text
$text (full-text search)
  query={'$text': {'$search': 'developer'}}
  count=2
  docs=[Anna <anna@gmail.com>, Bohdan <bohdan@outlook.com>]
```

(Anna's bio: "Frontend developer and UI engineer". Bohdan's: "Backend developer working with Python".)

### Hint

`{"$text": {"$search": "developer"}}` — top-level operator, not field-scoped. Requires the text index created by `coll.create_index([("bio", "text")], name="ix_bio_text")`.

### Solution

```python
coll.create_index([("bio", "text")], name="ix_bio_text")

docs = list(coll.find(
    {"$text": {"$search": "developer"}},
    {"_id": 0},
).sort("name", 1))
```

```javascript
db.string_operators_people.createIndex({ bio: "text" }, { name: "ix_bio_text" })

db.string_operators_people.find(
  { $text: { $search: "developer" } },
  { _id: 0 }
).sort({ name: 1 })
```

### Step-by-step explanation

1. **`$text` is a top-level operator.** Unlike `$regex` which sits under a specific field name, `$text` searches every field included in the text index (here, only `bio`).
2. **A text index is mandatory.** Without it, `$text` raises `text index required for $text query`. There can be **at most one text index per collection** (it can cover multiple fields with weights).
3. **`$search` tokenises the query** by whitespace, applies a language-specific stemmer, and removes stop words. Searching for `"developing"` would still match `"developer"` because both reduce to the stem `develop`.
4. **Phrase search** uses `\"…\"` inside `$search`: `{"$search": "\"backend developer\""}` matches the exact phrase. Mixing positive and negative terms: `"developer -intern"` excludes documents that contain `intern`.
5. **Score-based sort:** add `{"score": {"$meta": "textScore"}}` to the projection and sort to rank results by relevance instead of by `name`.
6. **`$text` is case-insensitive and diacritic-insensitive by default** (configurable on the index). `$regex` is case-sensitive unless you set `$options: "i"`.

---

## Choosing between `$regex` and `$text`

| Need | Use |
|---|---|
| Match a substring or pattern (`@gmail.com$`, `^A`, `\\d+`) | `$regex` |
| Search natural-language text by words (stemming, stop words, ranking) | `$text` |
| Multiple language stemming | `$text` with `default_language` index option |
| Very large collection, frequent searches | `$text` (uses an inverted index) |
| Substring search anchored to start of string | `$regex` with `^` (can use a btree index) |

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `$text` returns `text index required for $text query` | Create the text index: `db.coll.createIndex({ field: "text" })`. |
| `$regex` query is slow | Anchor with `^` and (if possible) move case-insensitive matching to a collation index. |
| `$regex` matches more than expected | Escape regex meta-characters (`.`, `*`, `+`, `?`) in literal substrings. |
| `$options: "i"` is ignored | Make sure it's inside the same dict as `$regex`, not at the top level of the query. |
| `$text` matches the wrong stem | The default index language is `english`. Set `default_language: "ukrainian"` (or your language) at index creation time. |

Run the included examples: `python 04_mongodb/04_string_operators/example.py`. The `$regex + $options` query can be reproduced with `mongosh` against the same seeded collection.
