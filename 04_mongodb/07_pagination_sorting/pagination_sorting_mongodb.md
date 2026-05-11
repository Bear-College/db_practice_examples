# Pagination and Sorting in MongoDB (`07_pagination_sorting`)

> Translation / Переклад: [Українська](../../i18n/uk/04_mongodb/07_pagination_sorting/pagination_sorting_mongodb.md)

These exercises walk through the three cursor methods that turn a "find everything" query into a usable storefront listing: `sort(...)` for ordering, `skip(...)` for offset pagination, and `limit(...)` for page size. The companion script seeds a small product catalogue and runs the full sort/page workflow end to end.

Runnable companion file: [`07_pagination_sorting/example.py`](example.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/07_pagination_sorting/example.py
```

Default connection (override with env vars):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Collection: `pagination_sorting_products`

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real listing UI would need this. |
| **What you'll learn** | The cursor methods trained here. |
| **Collection in play** | Fields used. |
| **Task** | Concrete sort key and page coordinates. |
| **Expected result** | Real captured output from `python example.py`. |
| **Hint** | The single API call that does the work. |
| **Solution** | PyMongo and `mongosh` side-by-side. |
| **Step-by-step explanation** | What each call does and the standard mistakes. |

---

## Collection: `pagination_sorting_products`

The seed inserts 10 products across 5 categories:

| `name` | `category` | `price` | `rating` |
|---|---|---|---|
| iPhone 14 | Smartphone | 899 | 4.8 |
| Galaxy S23 | Smartphone | 799 | 4.7 |
| Pixel 8 | Smartphone | 699 | 4.6 |
| MacBook Air | Laptop | 1299 | 4.9 |
| ThinkPad X1 | Laptop | 1399 | 4.8 |
| iPad Pro | Tablet | 999 | 4.7 |
| Kindle Paperwhite | Tablet | 159 | 4.5 |
| Sony WH-1000XM5 | Audio | 399 | 4.8 |
| AirPods Pro | Audio | 249 | 4.6 |
| Logitech MX Master 3S | Accessories | 99 | 4.9 |

Helper used in the script:

```python
from pymongo import ASCENDING, DESCENDING

def fetch_page(coll, *, page, per_page, sort_spec):
    skip_n = (page - 1) * per_page
    return list(
        coll.find({}, {"_id": 0})
        .sort(sort_spec)
        .skip(skip_n)
        .limit(per_page)
    )
```

---

## Exercise 1 — `sort(...)` (single key, ascending)

### Context

A "Cheapest first" tab on the catalogue page. Customers expect the lowest-priced item at the top, the most expensive at the bottom.

### What you'll learn

- Single-key `sort` with `ASCENDING`.
- Using `pymongo.ASCENDING` / `pymongo.DESCENDING` constants instead of magic numbers.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `price` | int | Sort key. |
| `name`, `category`, `rating` | various | Displayed only. |

### Task

Return all 10 products sorted by `price` ascending. Project everything except `_id`.

### Expected result

```text
Sorted by price ASC
  name=Logitech MX Master 3S, category=Accessories, price=99, rating=4.9
  name=Kindle Paperwhite, category=Tablet, price=159, rating=4.5
  name=AirPods Pro, category=Audio, price=249, rating=4.6
  name=Sony WH-1000XM5, category=Audio, price=399, rating=4.8
  name=Pixel 8, category=Smartphone, price=699, rating=4.6
  name=Galaxy S23, category=Smartphone, price=799, rating=4.7
  name=iPhone 14, category=Smartphone, price=899, rating=4.8
  name=iPad Pro, category=Tablet, price=999, rating=4.7
  name=MacBook Air, category=Laptop, price=1299, rating=4.9
  name=ThinkPad X1, category=Laptop, price=1399, rating=4.8
```

### Hint

`cursor.sort("price", ASCENDING)` — note the comma form. The list-of-tuples form `sort([("price", 1)])` is interchangeable.

### Solution

```python
from pymongo import ASCENDING, MongoClient

coll = MongoClient("mongodb://localhost:27017")["edu_academy_seed"]["pagination_sorting_products"]

docs = list(coll.find({}, {"_id": 0}).sort("price", ASCENDING))
for d in docs:
    print(d["name"], d["price"])
```

```javascript
use("edu_academy_seed");
db.pagination_sorting_products
  .find({}, { _id: 0 })
  .sort({ price: 1 });
```

### Step-by-step explanation

1. **`sort` is applied on the server.** PyMongo sends the sort instruction to MongoDB; no in-memory sorting in Python.
2. **`1` (or `ASCENDING`) means low-to-high.** `-1` (or `DESCENDING`) is high-to-low.
3. **Without an index on `price`, the sort blocks the cursor in memory.** For 10 docs that's free; for 10 million it would explode (`Sort exceeded memory limit`).
4. **Stable order on ties.** Two products with the same price would come back in implementation-defined order. Add a tiebreaker key (Exercise 2) when you need a deterministic listing.

---

## Exercise 2 — `sort(...)` (compound, mixed directions)

### Context

The "Recommended" tab: highest customer rating first, but **within** the same rating, show the cheapest first so the deal-of-the-day surfaces.

### What you'll learn

- Multi-key sort with mixed directions.
- Why the order of sort keys matters.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `rating` | float | Primary key, descending. |
| `price` | int | Tiebreaker, ascending. |

### Task

Return all 10 products sorted by `rating` descending, then `price` ascending. The 4.9-rated items must come first; within them, the cheaper one wins.

### Expected result

```text
Sorted by rating DESC, then price ASC
  name=Logitech MX Master 3S, category=Accessories, price=99, rating=4.9
  name=MacBook Air, category=Laptop, price=1299, rating=4.9
  name=Sony WH-1000XM5, category=Audio, price=399, rating=4.8
  name=iPhone 14, category=Smartphone, price=899, rating=4.8
  name=ThinkPad X1, category=Laptop, price=1399, rating=4.8
  name=Galaxy S23, category=Smartphone, price=799, rating=4.7
  name=iPad Pro, category=Tablet, price=999, rating=4.7
  name=AirPods Pro, category=Audio, price=249, rating=4.6
  name=Pixel 8, category=Smartphone, price=699, rating=4.6
  name=Kindle Paperwhite, category=Tablet, price=159, rating=4.5
```

Notice the 4.9 block (`MX Master 3S` cheaper than `MacBook Air`), then the 4.8 block (`Sony WH-1000XM5` → `iPhone 14` → `ThinkPad X1`), and so on.

### Hint

Pass a **list of tuples**: `.sort([("rating", DESCENDING), ("price", ASCENDING)])`. Each tuple is `(field, direction)`.

### Solution

```python
from pymongo import ASCENDING, DESCENDING

docs = list(
    coll.find({}, {"_id": 0}).sort(
        [("rating", DESCENDING), ("price", ASCENDING)]
    )
)
for d in docs:
    print(d["name"], "rating=", d["rating"], "price=", d["price"])
```

```javascript
db.pagination_sorting_products
  .find({}, { _id: 0 })
  .sort({ rating: -1, price: 1 });
```

### Step-by-step explanation

1. **Order of keys = priority.** `rating` is the primary sort; `price` only kicks in when ratings tie.
2. **Mixed directions are fine.** `{ rating: -1, price: 1 }` is a "descending then ascending" sort — MongoDB walks both indexes in step.
3. **Use a compound index on `(rating, price)` to avoid an in-memory sort.** Direction in the index should match the sort order (or its exact reverse).
4. **Dict literal trap in mongosh.** `{ rating: -1, price: 1 }` preserves order because JavaScript object literals are ordered. In Python use a list of tuples — Python dicts are also insertion-ordered now, but the explicit form is clearer.

---

## Exercise 3 — `skip(...)` + `limit(...)` (offset pagination)

### Context

The grid widget renders **3 products per page**. The shopper opens page 2 — we need rows 4-6 of an alphabetical listing.

### What you'll learn

- The relationship between `page`, `page_size`, `skip`, and `limit`.
- Why every paginated query **must** include a deterministic `sort`.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `name` | string | Sort key, used to define "page N". |

### Task

Using `page_size = 3` and a sort on `name` ascending, fetch pages 1, 2, and 3. Each call returns 3 documents; together they cover 9 of the 10 products.

### Expected result

```text
Page 1 (size=3, sort=name ASC)
  name=AirPods Pro, category=Audio, price=249, rating=4.6
  name=Galaxy S23, category=Smartphone, price=799, rating=4.7
  name=Kindle Paperwhite, category=Tablet, price=159, rating=4.5

Page 2 (size=3, sort=name ASC)
  name=Logitech MX Master 3S, category=Accessories, price=99, rating=4.9
  name=MacBook Air, category=Laptop, price=1299, rating=4.9
  name=Pixel 8, category=Smartphone, price=699, rating=4.6

Page 3 (size=3, sort=name ASC)
  name=Sony WH-1000XM5, category=Audio, price=399, rating=4.8
  name=ThinkPad X1, category=Laptop, price=1399, rating=4.8
  name=iPad Pro, category=Tablet, price=999, rating=4.7

Total documents: 10
```

The 10th product (`iPhone 14`) would be on page 4 (`skip=9`, `limit=3`).

### Hint

`skip_n = (page - 1) * per_page`. Chain `cursor.sort(...).skip(skip_n).limit(per_page)`.

### Solution

```python
from pymongo import ASCENDING

def fetch_page(coll, *, page, per_page, sort_spec):
    if page < 1:
        raise ValueError("page must be >= 1")
    skip_n = (page - 1) * per_page
    return list(
        coll.find({}, {"_id": 0})
        .sort(sort_spec)
        .skip(skip_n)
        .limit(per_page)
    )

page_size = 3
for p in (1, 2, 3):
    rows = fetch_page(coll, page=p, per_page=page_size, sort_spec=[("name", ASCENDING)])
    print(f"--- page {p} ---")
    for d in rows:
        print(d["name"])
```

```javascript
const pageSize = 3;
for (const page of [1, 2, 3]) {
  const skipN = (page - 1) * pageSize;
  const rows = db.pagination_sorting_products
    .find({}, { _id: 0 })
    .sort({ name: 1 })
    .skip(skipN)
    .limit(pageSize)
    .toArray();
  print(`--- page ${page} ---`);
  rows.forEach((d) => print(d.name));
}
```

### Step-by-step explanation

1. **MongoDB applies `sort → skip → limit` server-side, in that order.** So pages always come from the *sorted* sequence — exactly like SQL `ORDER BY ... LIMIT ... OFFSET`.
2. **`sort` is mandatory for pagination.** Without it the cursor order is undefined, so a row may appear on two pages or disappear between two.
3. **Choose a unique sort key.** `name` is unique here, but if two products shared a name, the order between them would be implementation-defined. Add `_id` as a final tiebreaker (`.sort([("name", 1), ("_id", 1)])`) for guaranteed determinism.
4. **`skip` is O(N) on the offset.** Each query rewalks the first `(page - 1) * page_size` rows. For deep pages, switch to **keyset pagination**: store the last seen `name` (or `_id`), and on the next call use `find({"name": {"$gt": last_name}}).sort("name", 1).limit(page_size)` — no `skip` needed.
5. **`count_documents({})` returns the total** (`10` here). Combined with `page_size`, you can show "Page 2 of 4" in the UI.

---

## Quick reference

| Goal | Cursor call | Mongosh equivalent |
|---|---|---|
| Sort ascending by one key | `.sort("price", 1)` | `.sort({ price: 1 })` |
| Sort with tiebreaker | `.sort([("rating", -1), ("price", 1)])` | `.sort({ rating: -1, price: 1 })` |
| Skip N rows | `.skip(N)` | `.skip(N)` |
| Take only M rows | `.limit(M)` | `.limit(M)` |
| Count for "X of Y" | `coll.count_documents({})` | `db.coll.countDocuments({})` |

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `Sort exceeded memory limit` | Add an index on the sort key(s) — or restrict the result set with a `find` filter first. |
| Page 2 repeats rows from page 1 | Sort is non-deterministic (no unique tiebreaker). Add `_id` as the last sort key. |
| `skip` is slow for page 10 000 | Switch to keyset pagination (`find({"_id": {"$gt": last_id}})`). |
| Hits a 32 MB limit on sort | Same fix as memory limit — index, or pre-filter with `find`. |
| `find().limit(0)` returns *all* rows | `limit(0)` in MongoDB means "no limit". Use a sentinel like `-1` or a real positive integer. |
