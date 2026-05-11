# Приклади практики з баз даних

> Translation / Переклад: [English](../../README.md)

Цей репозиторій містить три навчальні напрямки:

| Напрямок | Каталог | Стек | README модуля |
|---|---|---|---|
| **Реляційна БД (MySQL)** | [`03_mysql/`](../../03_mysql/) | SQL-скрипти для `car_service_db` + приклади SQLAlchemy | [`03_mysql/README.md`](../../03_mysql/README.md) |
| **Документна БД (MongoDB)** | [`04_mongodb/`](../../04_mongodb/) | Python + PyMongo, уроки на локальній MongoDB | [`04_mongodb/README.md`](../../04_mongodb/README.md) |
| **Хмара (AWS + Terraform)** | [`05_aws_terraform/`](../../05_aws_terraform/) | Terraform-процес створення та віддаленого підключення до AWS RDS MySQL | [`05_aws_terraform/README.md`](../../05_aws_terraform/README.md) |
| **Хмара (MongoDB Atlas + Terraform)** | [`06_mongo_terraform/`](../../06_mongo_terraform/) | Terraform-процес створення MongoDB Atlas M0 та віддаленого підключення | [`06_mongo_terraform/README.md`](../../06_mongo_terraform/README.md) |

---

## Швидкий старт MySQL

Завантажити дамп бази даних:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p car_service_db < 01_database_mysql/car_service_db.sql
```

---

## Швидкий старт MongoDB

Відновити вбудований дамп Mongo в базу `edu_academy_seed`:

```bash
mongorestore --uri="mongodb://localhost:27017" --db=edu_academy_seed ./edu_academy_seed
```
