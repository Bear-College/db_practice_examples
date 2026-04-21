# ODM with MongoEngine (`10_odm`)

This module shows how to use an ODM (Object Document Mapper) with MongoDB using **MongoEngine**.

## What is covered

- Connect to MongoDB
- Define a `Document` model class
- Create objects and save to MongoDB
- Query records via model API
- Update and delete records

Defaults in `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Run

From repository root:

```bash
pip install -r mongodb/requirements.txt
python mongodb/10_odm/example.py
```

Data is written to collection `odm_products`.

## Submodules

- [`01_selection_operators/`](01_selection_operators/) — ODM selection operators (`$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$nin`, `$and`, `$or`, `$not`, `$exists`, `$regex`)
- [`02_search_sorting_pagination/`](02_search_sorting_pagination/) — Motor + FastAPI + Pydantic example for search, sorting, and pagination
- [`03_indexes/`](03_indexes/) — Motor + Python examples for creating, using, and dropping MongoDB indexes
- [`04_agregation_functions/`](04_agregation_functions/) — Motor aggregation pipelines with `$group`, `$sum`, `$avg`, `$count`, `$max/$min`, `$match`, `$sort`, `$project`
