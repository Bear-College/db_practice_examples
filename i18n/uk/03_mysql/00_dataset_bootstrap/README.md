# 00 Завантаження тренувального набору даних

> Translation / Переклад: [English](../../../../03_mysql/00_dataset_bootstrap/README.md)

Завантажте навчальний набір даних у MySQL і переконайтеся, що він готовий до уроків.

## Мета

Імпортувати `car_service_db` з каталогу `01_database_mysql/` і пересвідчитися, що базу даних можна опитувати.

## Вхідні файли

- `01_database_mysql/car_service_db.sql.zip`
- `01_database_mysql/car_service_schema.sql`

## Кроки

1. Розпакуйте дамп (з кореня репозиторію):

```bash
unzip -o 01_database_mysql/car_service_db.sql.zip -d 01_database_mysql
```

2. Імпортуйте дамп у локальний MySQL:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p car_service_db < 01_database_mysql/car_service_db.sql
```

3. Швидка перевірка:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p -D car_service_db -e "SHOW TABLES;"
```

4. Необов'язкова перевірка схеми:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p -D car_service_db -e "SOURCE 01_database_mysql/car_service_schema.sql;"
```

## Чек-ліст

- [ ] Дамп успішно розпаковано
- [ ] Команда імпорту завершилася без помилок
- [ ] Таблиці видно в `car_service_db`
- [ ] Можна виконати базовий `SELECT`

## Результат цього етапу

База `car_service_db` доступна для всіх модулів у `03_mysql/`.
