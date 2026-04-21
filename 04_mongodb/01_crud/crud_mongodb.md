# CRUD in MongoDB (`01_crud`)

This lesson uses **PyMongo** and runs against the MongoDB practice database from `02_database_mongo/`.

Default connection settings in `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

If your database name is different from `edu_academy_seed`, run:

```bash
MONGODB_DB=your_database_name python 04_mongodb/01_crud/example.py
```

## Operations mapping (from lesson table)

| Operation | SQL style | MongoDB / PyMongo |
|---|---|---|
| Add one record | `INSERT INTO products VALUES (...);` | `insert_one({...})` |
| Add many records | `INSERT INTO products VALUES (...), (...);` | `insert_many([{...}, {...}])` |
| Update one record | `UPDATE products SET ... WHERE ...;` | `update_one({...}, {"$set": {...}})` |
| Update all matching records | `UPDATE products SET ... WHERE ...;` | `update_many({...}, {"$set": {...}})` |
| Delete one record | `DELETE FROM products WHERE ... LIMIT 1;` | `delete_one({...})` |
| Delete all matching records | `DELETE FROM products WHERE ...;` | `delete_many({...})` |
| Clear table/collection | `DELETE FROM products;` | `delete_many({})` |
| Drop table/collection | `DROP TABLE products;` | `drop()` |

## Run

From repository root:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/01_crud/example.py
```

The script runs all CRUD operations in sequence on collection `products`, prints results, then clears and drops the collection.
