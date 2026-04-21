# Logical Operators in MongoDB (`03_logical_operators`)

This lesson demonstrates logical operators from the table:

- `$and`
- `$or`
- `$not`

Default connection settings in `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Query patterns used

- `$and`:
  - `{ "$and": [ { "age": { "$gte": 18 } }, { "city": "New York" } ] }`
- `$or`:
  - `{ "$or": [ { "age": { "$lt": 18 } }, { "age": { "$gt": 60 } } ] }`
- `$not`:
  - `{ "age": { "$not": { "$gte": 18 } } }`

## Run

From repository root:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/03_logical_operators/example.py
```

The script creates/refreshes lesson collection `logical_operators_people` and prints each query with matched documents.
