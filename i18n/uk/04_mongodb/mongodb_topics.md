# MongoDB — приклади документної бази даних (`04_mongodb/`)

> Translation / Переклад: [English](../../../04_mongodb/mongodb_topics.md)

Робочі приклади на **Python + PyMongo** для практики з MongoDB, плюс **паралельна програма на C# (.NET)** у каталозі **`csharp/`** кожного уроку (**MongoDB.Driver**). Приклади розраховані на **MongoDB 6+** і сервер за адресою **`mongodb://localhost:27017`** (за потреби налаштовується через змінні середовища).

## Налаштування

```bash
cd 04_mongodb
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Запустити будь-який модуль:

```bash
python 01_crud/example.py
```

Або запустити все (потребує живий сервер):

```bash
./verify_mongodb_examples.sh
```

Запустити C#-порт будь-якого уроку:

```bash
cd 04_mongodb/01_crud/csharp
dotnet run
```

(`MONGODB_URI` / `MONGODB_DB` працюють так само, як у Python.)

## Теми

| Каталог | Тема |
|---------|------|
| [`01_crud`](01_crud/) | Основні CRUD-операції в PyMongo: `insert_one`, `insert_many`, `update_one`, `update_many`, `delete_one`, `delete_many`, очищення колекції та `drop()` |
| [`02_selection_queries`](02_selection_queries/) | Оператори відбору у фільтрах: `$eq`, `$ne`, `$gt`, `$lt`, `$gte`, `$lte`, `$in`, `$nin` |
| [`03_logical_operators`](03_logical_operators/) | Логічні фільтри: `$and`, `$or`, `$not` |
| [`04_string_operators`](04_string_operators/) | Рядково-орієнтовані фільтри: `$regex` та повнотекстовий пошук `$text` |
| [`05_check_operators`](05_check_operators/) | Перевірки полів: `$exists` та `$type` |
| [`06_array_operators`](06_array_operators/) | Фільтри масивів: `$all`, `$size`, `$elemMatch` |
| [`07_pagination_sorting`](07_pagination_sorting/) | Упорядкування і пагінація результатів: `sort`, `skip`, `limit` |
| [`08_filtering`](08_filtering/) | Комбінований урок з фільтрації: `find`, `find_one`, порівняння, логіка, вкладеність, масиви, regex, `$exists` |
| [`09_indexes`](09_indexes/) | Керування індексами: одинарні, складені, унікальні, текстові, TTL, хешовані; конфігуроване створення/видалення |
| [`10_odm`](10_odm/) | Object Document Mapper з MongoEngine: визначення моделі та CRUD |

Дані пишуться у колекції уроків (`products`, `selection_queries_people`, `logical_operators_people`, `string_operators_people`, `check_operators_people`, `array_operators_people`, `pagination_sorting_products`, `filtering_people`, `indexes_people`, `odm_products`) у базі **`edu_academy_seed`** за замовчуванням (можна перевизначити через `MONGODB_DB`). Скрипти скидають стан колекції, тож запуски залишаються повторюваними.

---

## Великий набір для практики (`02_database_mongo/` у корені репо)

Увесь код і CSV для **`car_workshop_mongo`** (**100 взаємопов'язаних колекцій**; **200k рядків** у чотирьох фактових таблицях; **~264k рядків** загалом разом із вимірами) знаходяться у **[`02_database_mongo/`](../../../02_database_mongo/README.md)** — `generate_csv.py`, `seed_mongo.py`, `mongoimport_all.sh`, `dataset.py`.
