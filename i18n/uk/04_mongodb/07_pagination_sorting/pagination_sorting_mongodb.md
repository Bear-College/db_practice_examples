# Пагінація та сортування в MongoDB (`07_pagination_sorting`)

> Translation / Переклад: [English](../../../../04_mongodb/07_pagination_sorting/pagination_sorting_mongodb.md)

Цей урок демонструє практичну пагінацію та впорядкування за допомогою **PyMongo**:

- `sort(...)` для впорядкування
- `skip(...)` + `limit(...)` для пагінації

Налаштування з'єднання за замовчуванням у `example.py`:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

## Що показує скрипт

1. Сортування за `price` за зростанням.
2. Сортування за `rating` за спаданням, потім за `price` за зростанням.
3. Отримання сторінок з детермінованим сортуванням:
   - сторінка 1 (`skip=0`, `limit=3`)
   - сторінка 2 (`skip=3`, `limit=3`)
   - сторінка 3 (`skip=6`, `limit=3`)

## Запуск

З кореня репозиторію:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/07_pagination_sorting/example.py
```

Скрипт створює/оновлює колекцію `pagination_sorting_products` і виводить відсортовані списки та сторінки.
