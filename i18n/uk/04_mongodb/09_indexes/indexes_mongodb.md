# Індекси в MongoDB (`09_indexes`)

> Translation / Переклад: [English](../../../../04_mongodb/09_indexes/indexes_mongodb.md)

Цей урок демонструє типи індексів за допомогою **PyMongo** у базі **`edu_academy_seed`**:

- Індекс по одному полю
- Складений (compound) індекс
- Унікальний індекс
- Текстовий індекс
- TTL-індекс
- Хешований (hashed) індекс

## Важливо: додавання/видалення індексів у коді

У `example.py` можна керувати створенням/видаленням індексів напряму:

- `RUN_CREATE_INDEXES = True|False`
- `RUN_DROP_INDEXES = True|False`
- `INDEXES_TO_CREATE = {...}` (множина імен індексів для створення)
- `INDEXES_TO_DROP = [...]` (список імен індексів для видалення)

Так можна додавати/видаляти індекси, редагуючи ці змінні.

## З'єднання за замовчуванням

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Колекція: `indexes_people`

## Запуск

З кореня репозиторію:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/09_indexes/example.py
```

Скрипт:

1. Заповнює демо-дані
2. Виводить поточні індекси
3. Створює вибрані індекси
4. За потреби видаляє налаштовані індекси
5. Виконує невеликі демо-запити (фільтр за `city` та пошук `$text`)
