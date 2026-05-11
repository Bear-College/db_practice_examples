# Запити вибірки в MongoDB (`02_selection_queries`)

> Translation / Переклад: [English](../../../../04_mongodb/02_selection_queries/selection_queries_mongodb.md)

Цей урок демонструє оператори порівняння та вибору зі списку з таблиці:

- `$eq` (дорівнює)
- `$ne` (не дорівнює)
- `$gt` (більше)
- `$lt` (менше)
- `$gte` (більше або дорівнює)
- `$lte` (менше або дорівнює)
- `$in` (значення у списку)
- `$nin` (значення не у списку)

Також додано приклади з **вкладеними документами** через крапкову нотацію, як-от:

- `profile.city`
- `profile.experience`
- `profile.role`

Налаштування з'єднання за замовчуванням у `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Запуск

З кореня репозиторію:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/02_selection_queries/example.py
```

Скрипт створює/оновлює невелику колекцію уроку:

- БД: `edu_academy_seed`
- Колекція: `selection_queries_people`

і виводить запит + кількість результатів + знайдені документи для кожного прикладу оператора.

## Приклади з вкладеними документами

- `{ "profile.city": { "$eq": "New York" } }`
- `{ "profile.experience": { "$gte": 10 } }`
- `{ "profile.role": { "$in": ["developer", "architect"] } }`
