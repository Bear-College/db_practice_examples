# Filtering in MongoDB (`08_filtering`)

This lesson combines filtering techniques in one PyMongo script.

## Includes

- Select all documents: `find()`
- Select one document: `find_one()`
- Comparison operators (`$gt`, `$lte`, etc.)
- Multi-value filters (`$in`, `$nin`)
- Logical operators (`$and`, `$or`, `$not`)
- Nested documents with dot notation (`profile.city`)
- Array filters (`$all`, `$size`, `$elemMatch`)
- Regex search (`$regex`)
- NULL-style filtering with field existence (`$exists`)

Default connection settings in `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Run

From repository root:

```bash
pip install -r mongodb/requirements.txt
python mongodb/08_filtering/example.py
```

The script creates/refreshes collection `filtering_people`, inserts sample nested+array documents, then prints results for each filter type.
