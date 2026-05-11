# CRUD у MongoDB (`01_crud`)

> Translation / Переклад: [English](../../../../04_mongodb/01_crud/crud_mongodb.md)

Цей урок використовує **PyMongo** і працює з практичною базою MongoDB з `02_database_mongo/`.

Налаштування з'єднання за замовчуванням у `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

Якщо ім'я вашої бази відрізняється від `edu_academy_seed`, запустіть:

```bash
MONGODB_DB=your_database_name python 04_mongodb/01_crud/example.py
```

## Відповідність операцій (з таблиці уроку)

| Операція | Стиль SQL | MongoDB / PyMongo |
|---|---|---|
| Додати один запис | `INSERT INTO products VALUES (...);` | `insert_one({...})` |
| Додати багато записів | `INSERT INTO products VALUES (...), (...);` | `insert_many([{...}, {...}])` |
| Оновити один запис | `UPDATE products SET ... WHERE ...;` | `update_one({...}, {"$set": {...}})` |
| Оновити всі відповідні записи | `UPDATE products SET ... WHERE ...;` | `update_many({...}, {"$set": {...}})` |
| Видалити один запис | `DELETE FROM products WHERE ... LIMIT 1;` | `delete_one({...})` |
| Видалити всі відповідні записи | `DELETE FROM products WHERE ...;` | `delete_many({...})` |
| Очистити таблицю/колекцію | `DELETE FROM products;` | `delete_many({})` |
| Видалити таблицю/колекцію | `DROP TABLE products;` | `drop()` |

## Запуск

З кореня репозиторію:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/01_crud/example.py
```

Скрипт виконує всі CRUD-операції послідовно на колекції `products`, виводить результати, потім очищає та видаляє колекцію.
