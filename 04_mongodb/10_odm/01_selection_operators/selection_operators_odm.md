# ODM Selection Operators (`10_odm/01_selection_operators`)

MongoEngine examples for operators from the lesson table:

- `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`
- `$in`, `$nin`
- `$and`, `$or`, `$not` (via `Q`)
- `$exists`
- `$regex`

Defaults:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Run

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/01_selection_operators/example.py
```

Collection used: `odm_selection_operators_people`.
