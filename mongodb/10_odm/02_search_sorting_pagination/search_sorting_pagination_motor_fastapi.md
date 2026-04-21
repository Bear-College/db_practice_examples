# Search, Sorting, Pagination (`10_odm/02_search_sorting_pagination`)

This module demonstrates:

- Search (text-like filtering via regex)
- Sorting (`name`, `price`, `rating`)
- Pagination (`page`, `page_size`)

Tech stack:

- **FastAPI**
- **Motor** (async MongoDB driver)
- **Pydantic**

Defaults:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

Collection:

- `odm_search_sort_pagination_products`

## Install

```bash
pip install -r mongodb/requirements.txt
```

## Run API

From repository root:

```bash
uvicorn mongodb.10_odm.02_search_sorting_pagination.main:app --reload
```

Open:

- Swagger UI: `http://127.0.0.1:8000/docs`
- Endpoint: `GET /products`

## Example requests

```bash
# default listing
curl "http://127.0.0.1:8000/products"

# search
curl "http://127.0.0.1:8000/products?q=phone"

# sort by price descending
curl "http://127.0.0.1:8000/products?sort_by=price&sort_dir=desc"

# page 2, page size 3
curl "http://127.0.0.1:8000/products?page=2&page_size=3"
```
