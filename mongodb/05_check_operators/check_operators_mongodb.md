# Check Operators in MongoDB (`05_check_operators`)

This lesson demonstrates operators from the table:

- `$exists` (checks whether a field exists)
- `$type` (checks a field data type)

Default connection settings in `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Query patterns used

- `$exists`:
  - `{ "phone": { "$exists": true } }`
- `$type`:
  - `{ "age": { "$type": "int" } }`

## Run

From repository root:

```bash
pip install -r mongodb/requirements.txt
python mongodb/05_check_operators/example.py
```

The script creates/refreshes collection `check_operators_people`, inserts sample docs with mixed field presence/types, then runs `$exists` and `$type` queries.
