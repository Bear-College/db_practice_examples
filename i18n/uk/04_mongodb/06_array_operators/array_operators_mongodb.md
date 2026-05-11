# Оператори масивів у MongoDB (`06_array_operators`)

> Translation / Переклад: [English](../../../../04_mongodb/06_array_operators/array_operators_mongodb.md)

Цей урок демонструє оператори масивів з таблиці:

- `$all` (усі перелічені значення мають бути в масиві)
- `$size` (перевіряє довжину масиву)
- `$elemMatch` (перевіряє, чи містить масив хоча б один відповідний елемент/об'єкт)

Налаштування з'єднання за замовчуванням у `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Використані шаблони запитів

- `$all`:
  - `{ "skills": { "$all": ["Python", "JavaScript"] } }`
- `$size`:
  - `{ "skills": { "$size": 3 } }`
- `$elemMatch`:
  - `{ "grades": { "$elemMatch": { "score": { "$gt": 90 } } } }`

## Запуск

З кореня репозиторію:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/06_array_operators/example.py
```

Скрипт створює/оновлює колекцію `array_operators_people`, вставляє тестові документи з масивами і виконує запити `$all`, `$size` та `$elemMatch`.
