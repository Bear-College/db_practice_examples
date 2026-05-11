# Фільтрація в MongoDB (`08_filtering`)

> Translation / Переклад: [English](../../../../04_mongodb/08_filtering/filtering_mongodb.md)

Цей урок об'єднує техніки фільтрації в одному PyMongo-скрипті.

## Включає

- Вибір усіх документів: `find()`
- Вибір одного документа: `find_one()`
- Оператори порівняння (`$gt`, `$lte` тощо)
- Багатозначні фільтри (`$in`, `$nin`)
- Логічні оператори (`$and`, `$or`, `$not`)
- Вкладені документи з крапковою нотацією (`profile.city`)
- Фільтри масивів (`$all`, `$size`, `$elemMatch`)
- Пошук regex (`$regex`)
- Фільтрація у стилі NULL через перевірку наявності поля (`$exists`)

Налаштування з'єднання за замовчуванням у `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Запуск

З кореня репозиторію:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/08_filtering/example.py
```

Скрипт створює/оновлює колекцію `filtering_people`, вставляє тестові документи з вкладеністю та масивами, а потім виводить результати для кожного типу фільтра.
