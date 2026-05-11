# Оператори вибору в ODM (`10_odm/01_selection_operators`)

> Translation / Переклад: [English](../../../../../04_mongodb/10_odm/01_selection_operators/selection_operators_odm.md)

Приклади MongoEngine для операторів з таблиці уроку:

- `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`
- `$in`, `$nin`
- `$and`, `$or`, `$not` (через `Q`)
- `$exists`
- `$regex`

Значення за замовчуванням:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Запуск

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/01_selection_operators/example.py
```

Використовувана колекція: `odm_selection_operators_people`.
