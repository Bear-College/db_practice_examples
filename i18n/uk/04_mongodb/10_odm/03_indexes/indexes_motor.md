# Індекси з Motor (`10_odm/03_indexes`)

> Translation / Переклад: [English](../../../../../04_mongodb/10_odm/03_indexes/indexes_motor.md)

Цей модуль демонструє операції з індексами в MongoDB через **Motor** (асинхронний драйвер Python).

## Включені приклади індексів

- Індекс по одному полю
- Складений (compound) індекс
- Унікальний індекс
- Текстовий індекс
- TTL-індекс
- Хешований (hashed) індекс

Скрипт:

1. Заповнює тестові дані
2. Створює індекси
3. Виводить поточні індекси
4. Виконує приклади запитів (фільтр за `category` та пошук `$text`)
5. Видаляє створені індекси

Значення за замовчуванням:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

Колекція:

- `odm_motor_indexes_products`

## Запуск

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/03_indexes/main.py
```
