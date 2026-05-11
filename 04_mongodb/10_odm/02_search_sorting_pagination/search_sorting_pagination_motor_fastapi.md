# Search, Sorting, Pagination — Motor + FastAPI (`10_odm/02_search_sorting_pagination`)

> Translation / Переклад: [Українська](../../../i18n/uk/04_mongodb/10_odm/02_search_sorting_pagination/search_sorting_pagination_motor_fastapi.md)

These exercises walk through a small but **complete** read-side API that combines three orthogonal concerns: full-text-ish **search** (via regex `$or`), multi-field **sorting**, and offset **pagination** — all served asynchronously by **FastAPI + Motor + Pydantic**.

Runnable companion file: [`10_odm/02_search_sorting_pagination/main.py`](main.py).

```bash
pip install -r 04_mongodb/10_odm/02_search_sorting_pagination/requirements.txt
uvicorn main:app --reload --app-dir 04_mongodb/10_odm/02_search_sorting_pagination
```

Then open `http://127.0.0.1:8000/docs` for the Swagger UI, or `curl` the endpoint directly.

Default connection (override with env vars):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Collection: `odm_search_sort_pagination_products`

---

## What's in the script

```python
class ProductsPage(BaseModel):
    total: int
    page: int
    page_size: int
    sort_by: str
    sort_dir: Literal["asc", "desc"]
    q: str | None
    items: List[ProductOut]


@app.get("/products", response_model=ProductsPage)
async def list_products(
    q: str | None = Query(default=None),
    sort_by: Literal["name", "price", "rating"] = Query(default="name"),
    sort_dir: Literal["asc", "desc"]            = Query(default="asc"),
    page: int      = Query(default=1, ge=1),
    page_size: int = Query(default=5, ge=1, le=50),
) -> ProductsPage:
    query = {}
    if q:
        query = {"$or": [
            {"name":        {"$regex": q, "$options": "i"}},
            {"category":    {"$regex": q, "$options": "i"}},
            {"description": {"$regex": q, "$options": "i"}},
        ]}
    sort_order = 1 if sort_dir == "asc" else -1
    skip_n = (page - 1) * page_size
    total  = await coll.count_documents(query)
    cursor = coll.find(query).sort(sort_by, sort_order).skip(skip_n).limit(page_size)
    docs   = await cursor.to_list(length=page_size)
    ...
```

The collection is seeded with 10 products (same data as `07_pagination_sorting`, plus a `description` field for the search):

| `name` | `category` | `description` | `price` | `rating` |
|---|---|---|---|---|
| iPhone 14 | Smartphone | "Apple smartphone" | 899 | 4.8 |
| Galaxy S23 | Smartphone | "Samsung flagship phone" | 799 | 4.7 |
| Pixel 8 | Smartphone | "Google Android phone" | 699 | 4.6 |
| MacBook Air | Laptop | "Apple ultrabook laptop" | 1299 | 4.9 |
| ThinkPad X1 | Laptop | "Business laptop" | 1399 | 4.8 |
| iPad Pro | Tablet | "Apple tablet device" | 999 | 4.7 |
| Kindle Paperwhite | Tablet | "E-reader tablet" | 159 | 4.5 |
| Sony WH-1000XM5 | Audio | "Noise canceling headphones" | 399 | 4.8 |
| AirPods Pro | Audio | "Wireless earbuds" | 249 | 4.6 |
| Logitech MX Master 3S | Accessories | "Premium wireless mouse" | 99 | 4.9 |

The exercises below capture **real responses** from `curl` against the running server on port 8765 (so the listings don't collide with anything else you might run on 8000).

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real listing screen needs this query knob. |
| **What you'll learn** | The Motor / Pydantic / FastAPI pieces in play. |
| **Endpoint in play** | The `/products` query parameters used. |
| **Task** | Concrete `curl` request. |
| **Expected result** | The actual JSON body returned by the server. |
| **Hint** | The single Motor cursor method that does the work. |
| **Solution** | Python (Motor) and `mongosh` versions of the underlying query. |
| **Step-by-step explanation** | How FastAPI / Pydantic / Motor cooperate and the standard mistakes. |

---

## Exercise 1 — Default listing (no filter, sort by `name` ASC)

### Context

The catalogue's "All products" tab loads with no filter, sorted alphabetically, 5 per page. The total count drives the "Page 1 of 2" footer.

### What you'll learn

- How FastAPI's `Query(default=...)` injects defaults.
- The plain Motor pipeline: `coll.find(query).sort(...).skip(...).limit(...)`.
- Pydantic's `ProductsPage` envelope for `(total, page, page_size, items)`.

### Endpoint in play

```text
GET /products
```

(No query parameters.)

### Task

Hit the default endpoint and inspect the page envelope.

### Expected result

```json
{
  "total": 10,
  "page": 1,
  "page_size": 5,
  "sort_by": "name",
  "sort_dir": "asc",
  "q": null,
  "items": [
    {"_id": "...", "name": "AirPods Pro",        "category": "Audio",       "price": 249,  "rating": 4.6},
    {"_id": "...", "name": "Galaxy S23",         "category": "Smartphone",  "price": 799,  "rating": 4.7},
    {"_id": "...", "name": "Kindle Paperwhite",  "category": "Tablet",      "price": 159,  "rating": 4.5},
    {"_id": "...", "name": "Logitech MX Master 3S", "category": "Accessories", "price": 99, "rating": 4.9},
    {"_id": "...", "name": "MacBook Air",        "category": "Laptop",      "price": 1299, "rating": 4.9}
  ]
}
```

The 5 highest-alphabetical names (`A`-`M`) come back; `Pixel 8` onwards are on page 2.

### Hint

The endpoint already does everything. Just call `curl "http://127.0.0.1:8765/products"`.

### Solution

```python
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

async def main():
    coll = AsyncIOMotorClient("mongodb://localhost:27017")["edu_academy_seed"]["odm_search_sort_pagination_products"]
    total = await coll.count_documents({})
    cursor = coll.find({}).sort("name", 1).skip(0).limit(5)
    docs = await cursor.to_list(length=5)
    print({"total": total, "items": [d["name"] for d in docs]})

asyncio.run(main())
```

```javascript
db.odm_search_sort_pagination_products
  .find({})
  .sort({ name: 1 })
  .skip(0)
  .limit(5);

db.odm_search_sort_pagination_products.countDocuments({});
```

### Step-by-step explanation

1. **FastAPI parses the query string** into typed kwargs (`sort_by: Literal["name", "price", "rating"]`). Bad values yield a 422.
2. **`count_documents(query)` is awaited separately.** Motor doesn't expose an "aggregate-style" pipeline; you do two awaits — one for the count, one for the page — and accept the small extra round trip.
3. **`to_list(length=page_size)` is the canonical drain.** `async for doc in cursor` works too, but `to_list` is shorter when you already know the cap.
4. **`_id` becomes a string in the response.** The handler converts the `ObjectId` to `str(d["_id"])`; Pydantic v2's `populate_by_name` + `alias="_id"` does the rest.

---

## Exercise 2 — Search (`q=phone`)

### Context

The store's search box matches against three fields — `name`, `category`, and `description`. Typing `"phone"` should surface everything in the "smartphone" / "headphones" / etc. ballpark.

### What you'll learn

- Wrapping multiple regex predicates with `$or`.
- Case-insensitive search via `$options: "i"`.
- Why `count_documents(query)` is computed **on the filtered set**, not the whole collection.

### Endpoint in play

```text
GET /products?q=phone
```

### Task

Search for `"phone"` and read both the total and the items array.

### Expected result

```json
{
  "total": 4,
  "page": 1,
  "page_size": 5,
  "sort_by": "name",
  "sort_dir": "asc",
  "q": "phone",
  "items": [
    {"name": "Galaxy S23",      "category": "Smartphone", "price": 799, "rating": 4.7},
    {"name": "Pixel 8",         "category": "Smartphone", "price": 699, "rating": 4.6},
    {"name": "Sony WH-1000XM5", "category": "Audio",      "price": 399, "rating": 4.8},
    {"name": "iPhone 14",       "category": "Smartphone", "price": 899, "rating": 4.8}
  ]
}
```

Four matches: three of the four `category: "Smartphone"` rows (Pixel 8 by category, iPhone 14 and Galaxy S23 by either category or description — *"phone"* is case-insensitively a substring) **plus** Sony WH-1000XM5 (the description says "headphones").

### Hint

`{"$or": [{"name": {"$regex": q, "$options": "i"}}, {"category": ...}, {"description": ...}]}`.

### Solution

```python
q = "phone"
query = {"$or": [
    {"name":        {"$regex": q, "$options": "i"}},
    {"category":    {"$regex": q, "$options": "i"}},
    {"description": {"$regex": q, "$options": "i"}},
]}
total  = await coll.count_documents(query)
docs   = await coll.find(query).sort("name", 1).limit(5).to_list(length=5)
```

```javascript
const q = "phone";
db.odm_search_sort_pagination_products.find({
  $or: [
    { name:        { $regex: q, $options: "i" } },
    { category:    { $regex: q, $options: "i" } },
    { description: { $regex: q, $options: "i" } }
  ]
}).sort({ name: 1 }).limit(5);
```

### Step-by-step explanation

1. **Regex on three fields = `$or`.** Without `$or` MongoDB would AND them, requiring "phone" in *all three* fields.
2. **`$options: "i"` makes it case-insensitive.** `"phone"` then matches "Smartphone", "headphones", etc.
3. **Search is unindexed by default.** For larger datasets, build a *text* index (`{name: "text", description: "text"}`) and switch the handler to `$text` — see lesson `09_indexes`.
4. **Bear in mind the count cost.** `count_documents` re-runs the same filter; for very large filtered sets, an *estimated* count via `estimated_document_count` (whole-collection) and a per-page check is sometimes a better trade-off.

---

## Exercise 3 — Sort by `price` descending

### Context

The "Most expensive first" toggle on the storefront. Same dataset, no filter — just a different `sort_by` / `sort_dir`.

### What you'll learn

- How `sort_dir = "asc" | "desc"` becomes `+1 / -1`.
- That `sort_by` is type-restricted by Pydantic at the boundary.

### Endpoint in play

```text
GET /products?sort_by=price&sort_dir=desc
```

### Task

Fetch the first page sorted by price, highest first.

### Expected result

```json
{
  "total": 10,
  "page": 1,
  "page_size": 5,
  "sort_by": "price",
  "sort_dir": "desc",
  "q": null,
  "items": [
    {"name": "ThinkPad X1",  "category": "Laptop",     "price": 1399, "rating": 4.8},
    {"name": "MacBook Air",  "category": "Laptop",     "price": 1299, "rating": 4.9},
    {"name": "iPad Pro",     "category": "Tablet",     "price": 999,  "rating": 4.7},
    {"name": "iPhone 14",    "category": "Smartphone", "price": 899,  "rating": 4.8},
    {"name": "Galaxy S23",   "category": "Smartphone", "price": 799,  "rating": 4.7}
  ]
}
```

### Hint

Pass `sort_by=price` and `sort_dir=desc` in the query string.

### Solution

```python
sort_order = 1 if sort_dir == "asc" else -1
docs = await coll.find({}).sort("price", sort_order).limit(5).to_list(length=5)
```

```javascript
db.odm_search_sort_pagination_products
  .find({})
  .sort({ price: -1 })
  .limit(5);
```

### Step-by-step explanation

1. **`Literal["asc", "desc"]` catches typos at parse time.** A request with `sort_dir=descending` returns a 422 before the handler runs.
2. **`sort_by` is also a `Literal`.** Restricting it to fields you've planned for prevents users from triggering full collection scans on arbitrary fields.
3. **No tiebreaker here.** Two products at the same price would come back in undefined order. For a "stable" sort, change the call to `.sort([(sort_by, sort_order), ("_id", 1)])`.

---

## Exercise 4 — Pagination (`page=2`, `page_size=3`)

### Context

A grid with 3 products per page. The user clicks "Next" — that's `page=2, page_size=3`.

### What you'll learn

- The `(page - 1) * page_size` math behind `skip`.
- Why `page_size` has a hard `le=50` upper bound.

### Endpoint in play

```text
GET /products?page=2&page_size=3
```

### Task

Fetch page 2 with `page_size=3` and read the resulting slice.

### Expected result

```json
{
  "total": 10,
  "page": 2,
  "page_size": 3,
  "sort_by": "name",
  "sort_dir": "asc",
  "q": null,
  "items": [
    {"name": "Logitech MX Master 3S", "category": "Accessories", "price": 99,   "rating": 4.9},
    {"name": "MacBook Air",           "category": "Laptop",      "price": 1299, "rating": 4.9},
    {"name": "Pixel 8",               "category": "Smartphone",  "price": 699,  "rating": 4.6}
  ]
}
```

Items 4-6 of the alphabetical order: `Logitech` → `MacBook Air` → `Pixel 8`.

### Hint

`skip_n = (page - 1) * page_size`. `cursor.skip(skip_n).limit(page_size)`.

### Solution

```python
skip_n = (page - 1) * page_size
docs = await (
    coll.find(query).sort(sort_by, sort_order).skip(skip_n).limit(page_size).to_list(length=page_size)
)
```

```javascript
const pageSize = 3;
const page = 2;
const skipN = (page - 1) * pageSize;
db.odm_search_sort_pagination_products
  .find({})
  .sort({ name: 1 })
  .skip(skipN)
  .limit(pageSize);
```

### Step-by-step explanation

1. **`Query(ge=1, le=50)` enforces the bounds at the FastAPI boundary.** `page_size=1000` gets a 422 — protecting the server from "fetch everything" attacks.
2. **`skip` is O(N) on the skipped count.** Fine for 10 documents; for "page 10 000" in a million-document collection, switch to keyset pagination (`_id > last_id`).
3. **Total comes from the *filtered* count.** Don't replace it with `estimated_document_count()` unless you really mean "total in the collection".

---

## Exercise 5 — Sort by `rating` descending, page size 3

### Context

The "Top rated" preview widget — three best-rated items, regardless of category or price.

### What you'll learn

- How combining `sort_by=rating` and `page_size=3` gives a deterministic "top-N" snippet.
- Why ties on `rating` can swap order between calls (and how to fix it).

### Endpoint in play

```text
GET /products?sort_by=rating&sort_dir=desc&page_size=3
```

### Task

Fetch the first 3 products by `rating` descending.

### Expected result

```json
{
  "total": 10,
  "page": 1,
  "page_size": 3,
  "sort_by": "rating",
  "sort_dir": "desc",
  "q": null,
  "items": [
    {"name": "Logitech MX Master 3S", "category": "Accessories", "price": 99,   "rating": 4.9},
    {"name": "MacBook Air",           "category": "Laptop",      "price": 1299, "rating": 4.9},
    {"name": "ThinkPad X1",           "category": "Laptop",      "price": 1399, "rating": 4.8}
  ]
}
```

Both 4.9 items come first; `ThinkPad X1` (one of the three 4.8s) wins the third slot in *this* run — the order between the three 4.8s is undefined without a tiebreaker.

### Hint

For deterministic order between equal ratings, the handler would need a secondary sort key — change `cursor.sort(sort_by, sort_order)` to `cursor.sort([(sort_by, sort_order), ("_id", 1)])`.

### Solution

```python
sort_order = -1
docs = await coll.find({}).sort([("rating", sort_order), ("_id", 1)]).limit(3).to_list(length=3)
```

```javascript
db.odm_search_sort_pagination_products
  .find({})
  .sort({ rating: -1, _id: 1 })
  .limit(3);
```

### Step-by-step explanation

1. **One-key sort is good enough for `4.9 > 4.8 > 4.7`** but not for distinguishing two 4.8s.
2. **`_id` as the universal tiebreaker.** It is unique by construction, monotonic by insertion time, and almost always cheap.
3. **Pydantic doesn't validate the database state.** If two documents had the same product `name` and you sorted by `name` only, you'd see the same instability.

---

## Quick reference

| Goal | Query string | Underlying call |
|---|---|---|
| All, sort name ASC, 5/page | (defaults) | `find({}).sort("name", 1).skip(0).limit(5)` |
| Search anywhere for "phone" | `?q=phone` | `find({"$or":[{...regex...}]})` |
| Highest price first | `?sort_by=price&sort_dir=desc` | `find({}).sort("price", -1)` |
| Page 2 of 3 | `?page=2&page_size=3` | `find({}).skip(3).limit(3)` |
| Top 3 by rating | `?sort_by=rating&sort_dir=desc&page_size=3` | `find({}).sort("rating", -1).limit(3)` |

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| 422 on `sort_by=foo` | `sort_by` is `Literal["name", "price", "rating"]`. Use one of those. |
| Search is slow | Regex is unindexed. Add a `text` index and use `$text`/`$search`. |
| Total disagrees with `len(items)` | Expected — `total` is the filtered count, `items` is the page slice. |
| `_id` printed as `ObjectId(...)` | You forgot `str(d["_id"])` before validating into the `ProductOut` model. |
| Pagination repeats rows | Sort key isn't unique. Add `_id` as the tiebreaker. |
| Server logs `Sort exceeded memory limit` | Add an index on the sort key or pre-filter with a tighter `query`. |
