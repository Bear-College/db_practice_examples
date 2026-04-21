# Selection Queries in MongoDB (`02_selection_queries`)

This lesson demonstrates comparison and list-selection operators from the table:

- `$eq` (equals)
- `$ne` (not equals)
- `$gt` (greater than)
- `$lt` (less than)
- `$gte` (greater than or equals)
- `$lte` (less than or equals)
- `$in` (value in list)
- `$nin` (value not in list)

It also includes extra examples on **nested documents** using dot-notation paths like:

- `profile.city`
- `profile.experience`
- `profile.role`

Default connection settings in `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Run

From repository root:

```bash
pip install -r mongodb/requirements.txt
python mongodb/02_selection_queries/example.py
```

The script creates/refreshes a small lesson collection:

- DB: `edu_academy_seed`
- Collection: `selection_queries_people`

and prints query + result count + matched docs for each operator example.

## Nested document examples included

- `{ "profile.city": { "$eq": "New York" } }`
- `{ "profile.experience": { "$gte": 10 } }`
- `{ "profile.role": { "$in": ["developer", "architect"] } }`
