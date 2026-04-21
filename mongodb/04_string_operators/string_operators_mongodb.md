# String Operators in MongoDB (`04_string_operators`)

This lesson demonstrates operators from the table:

- `$regex` (regular expression search; similar to SQL `LIKE`)
- `$text` (full-text search)

Default connection settings in `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Query patterns used

- `$regex`:
  - `{ "email": { "$regex": "@gmail.com$" } }`
- `$text`:
  - `{ "$text": { "$search": "developer" } }`

## Important note

`$text` requires a text index. The script creates one:

- `coll.create_index([("bio", "text")], name="ix_bio_text")`

## Run

From repository root:

```bash
pip install -r mongodb/requirements.txt
python mongodb/04_string_operators/example.py
```

The script creates/refreshes collection `string_operators_people`, inserts sample documents, then runs `$regex` and `$text` queries.
