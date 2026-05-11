# Indexes with Motor (`10_odm/03_indexes`)

> Translation / Переклад: [Українська](../../../i18n/uk/04_mongodb/10_odm/03_indexes/indexes_motor.md)

This module demonstrates index operations in MongoDB using **Motor** (async Python driver).

## Included index examples

- Single field index
- Compound index
- Unique index
- Text index
- TTL index
- Hashed index

The script:

1. Seeds sample data
2. Creates indexes
3. Prints current indexes
4. Runs sample queries (`category` filter and `$text` search)
5. Drops created indexes

Defaults:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

Collection:

- `odm_motor_indexes_products`

## Run

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/03_indexes/main.py
```
