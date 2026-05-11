# Рядкові оператори в MongoDB (`04_string_operators`)

> Translation / Переклад: [English](../../../../04_mongodb/04_string_operators/string_operators_mongodb.md)

Цей урок демонструє оператори з таблиці:

- `$regex` (пошук за регулярним виразом; подібно до SQL `LIKE`)
- `$text` (повнотекстовий пошук)

Налаштування з'єднання за замовчуванням у `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Використані шаблони запитів

- `$regex`:
  - `{ "email": { "$regex": "@gmail.com$" } }`
- `$text`:
  - `{ "$text": { "$search": "developer" } }`

## Важлива примітка

`$text` потребує текстового індексу. Скрипт створює такий:

- `coll.create_index([("bio", "text")], name="ix_bio_text")`

## Запуск

З кореня репозиторію:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/04_string_operators/example.py
```

Скрипт створює/оновлює колекцію `string_operators_people`, вставляє тестові документи й виконує запити `$regex` і `$text`.
