# ODM з MongoEngine (`10_odm`)

> Translation / Переклад: [English](../../../../04_mongodb/10_odm/odm_mongoengine.md)

Цей модуль показує, як використовувати ODM (Object Document Mapper) з MongoDB через **MongoEngine**.

## Що розглядається

- Підключення до MongoDB
- Визначення класу-моделі `Document`
- Створення об'єктів і збереження у MongoDB
- Запити записів через API моделі
- Оновлення та видалення записів

Значення за замовчуванням у `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Запуск

З кореня репозиторію:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/example.py
```

Дані пишуться у колекцію `odm_products`.

## Підмодулі

- [`01_selection_operators/`](01_selection_operators/) — оператори вибору ODM (`$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$nin`, `$and`, `$or`, `$not`, `$exists`, `$regex`)
- [`02_search_sorting_pagination/`](02_search_sorting_pagination/) — приклад Motor + FastAPI + Pydantic для пошуку, сортування та пагінації
- [`03_indexes/`](03_indexes/) — приклади Motor + Python для створення, використання та видалення індексів MongoDB
- [`04_agregation_functions/`](04_agregation_functions/) — конвеєри агрегації Motor з `$group`, `$sum`, `$avg`, `$count`, `$max/$min`, `$match`, `$sort`, `$project`
