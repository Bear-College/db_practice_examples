# Логічні оператори в MongoDB (`03_logical_operators`)

> Translation / Переклад: [English](../../../../04_mongodb/03_logical_operators/logical_operators_mongodb.md)

Цей урок демонструє логічні оператори з таблиці:

- `$and`
- `$or`
- `$not`

Налаштування з'єднання за замовчуванням у `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Використані шаблони запитів

- `$and`:
  - `{ "$and": [ { "age": { "$gte": 18 } }, { "city": "New York" } ] }`
- `$or`:
  - `{ "$or": [ { "age": { "$lt": 18 } }, { "age": { "$gt": 60 } } ] }`
- `$not`:
  - `{ "age": { "$not": { "$gte": 18 } } }`

## Запуск

З кореня репозиторію:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/03_logical_operators/example.py
```

Скрипт створює/оновлює колекцію уроку `logical_operators_people` і виводить кожен запит зі знайденими документами.
