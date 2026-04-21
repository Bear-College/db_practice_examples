# Array Operators in MongoDB (`06_array_operators`)

This lesson demonstrates array operators from the table:

- `$all` (all listed values must exist in the array)
- `$size` (checks array length)
- `$elemMatch` (checks if array contains at least one matching element/object)

Default connection settings in `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Query patterns used

- `$all`:
  - `{ "skills": { "$all": ["Python", "JavaScript"] } }`
- `$size`:
  - `{ "skills": { "$size": 3 } }`
- `$elemMatch`:
  - `{ "grades": { "$elemMatch": { "score": { "$gt": 90 } } } }`

## Run

From repository root:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/06_array_operators/example.py
```

The script creates/refreshes collection `array_operators_people`, inserts sample docs with arrays, then runs `$all`, `$size`, and `$elemMatch` queries.
