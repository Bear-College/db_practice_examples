# Оператори перевірки в MongoDB (`05_check_operators`)

> Translation / Переклад: [English](../../../../04_mongodb/05_check_operators/check_operators_mongodb.md)

Цей урок демонструє оператори з таблиці:

- `$exists` (перевіряє наявність поля)
- `$type` (перевіряє тип даних поля)

Налаштування з'єднання за замовчуванням у `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Використані шаблони запитів

- `$exists`:
  - `{ "phone": { "$exists": true } }`
- `$type`:
  - `{ "age": { "$type": "int" } }`

## Запуск

З кореня репозиторію:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/05_check_operators/example.py
```

Скрипт створює/оновлює колекцію `check_operators_people`, вставляє тестові документи з різним складом полів і типів, а потім виконує запити `$exists` і `$type`.
