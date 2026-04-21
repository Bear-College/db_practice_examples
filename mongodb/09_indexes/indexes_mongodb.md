# Indexes in MongoDB (`09_indexes`)

This lesson demonstrates index types with **PyMongo** on database **`edu_academy_seed`**:

- Single field index
- Compound index
- Unique index
- Text index
- TTL index
- Hashed index

## Important: add/remove indexes in code

In `example.py`, you can directly control index creation/removal:

- `RUN_CREATE_INDEXES = True|False`
- `RUN_DROP_INDEXES = True|False`
- `INDEXES_TO_CREATE = {...}` (set of index names to create)
- `INDEXES_TO_DROP = [...]` (list of index names to drop)

So you can add/remove indexes by editing these variables.

## Default connection

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Collection: `indexes_people`

## Run

From repository root:

```bash
pip install -r mongodb/requirements.txt
python mongodb/09_indexes/example.py
```

The script:

1. Seeds demo data
2. Prints current indexes
3. Creates selected indexes
4. Optionally drops configured indexes
5. Runs small demo queries (`city` filter and `$text` search)
