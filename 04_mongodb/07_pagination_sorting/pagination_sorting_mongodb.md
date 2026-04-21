# Pagination and Sorting in MongoDB (`07_pagination_sorting`)

This lesson demonstrates practical paging and ordering with **PyMongo**:

- `sort(...)` for ordering
- `skip(...)` + `limit(...)` for pagination

Default connection settings in `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## What the script shows

1. Sort by `price` ascending.
2. Sort by `rating` descending, then `price` ascending.
3. Fetch pages with deterministic sort:
   - page 1 (`skip=0`, `limit=3`)
   - page 2 (`skip=3`, `limit=3`)
   - page 3 (`skip=6`, `limit=3`)

## Run

From repository root:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/07_pagination_sorting/example.py
```

The script creates/refreshes collection `pagination_sorting_products` and prints sorted lists plus paginated pages.
