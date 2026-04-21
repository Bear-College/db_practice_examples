# MongoDB — document database examples (`mongodb/`)

Runnable **Python + PyMongo** samples for MongoDB practice. Examples assume **MongoDB 6+** and a server on **`mongodb://localhost:27017`** (adjust via environment variables if needed).

## Setup

```bash
cd mongodb
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Run any module:

```bash
python 01_crud/example.py
```

Or run everything (requires a live server):

```bash
./verify_mongodb_examples.sh
```

## Topics

| Folder | Theme |
|--------|--------|
| [`01_crud`](01_crud/) | Core CRUD operations in PyMongo: `insert_one`, `insert_many`, `update_one`, `update_many`, `delete_one`, `delete_many`, collection cleanup and `drop()` |
| [`02_selection_queries`](02_selection_queries/) | Selection operators in filters: `$eq`, `$ne`, `$gt`, `$lt`, `$gte`, `$lte`, `$in`, `$nin` |
| [`03_logical_operators`](03_logical_operators/) | Logical filters: `$and`, `$or`, `$not` |
| [`04_string_operators`](04_string_operators/) | String-oriented filters: `$regex` and full-text `$text` search |
| [`05_check_operators`](05_check_operators/) | Field checks: `$exists` and `$type` |
| [`06_array_operators`](06_array_operators/) | Array filters: `$all`, `$size`, `$elemMatch` |
| [`07_pagination_sorting`](07_pagination_sorting/) | Result ordering and paging: `sort`, `skip`, `limit` |
| [`08_filtering`](08_filtering/) | Combined filtering lesson: `find`, `find_one`, comparison, logical, nested, arrays, regex, `$exists` |
| [`09_indexes`](09_indexes/) | Index management: single, compound, unique, text, TTL, hashed; configurable create/drop |
| [`10_odm`](10_odm/) | Object Document Mapper with MongoEngine: model definition and CRUD |

Data is written to lesson collections (`products`, `selection_queries_people`, `logical_operators_people`, `string_operators_people`, `check_operators_people`, `array_operators_people`, `pagination_sorting_products`, `filtering_people`, `indexes_people`, `odm_products`) in database **`edu_academy_seed`** by default (override with `MONGODB_DB`). Scripts reset collection state so runs stay repeatable.

---

## Large practice dataset (`database_mongo/` at repo root)

All code and CSVs for **`car_workshop_mongo`** (**100 interconnected collections**; **200k rows** in four fact tables; **~264k rows** total including dimensions) live in **[`database_mongo/`](../database_mongo/README.md)** — `generate_csv.py`, `seed_mongo.py`, `mongoimport_all.sh`, `dataset.py`.
