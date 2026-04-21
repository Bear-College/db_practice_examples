# Database practice examples

This repository has three learning tracks:

| Track | Folder | Stack | Module README |
|---|---|---|---|
| **Relational (MySQL)** | [`03_mysql/`](03_mysql/) | SQL scripts for `car_service_db` + SQLAlchemy examples | [`03_mysql/README.md`](03_mysql/README.md) |
| **Document (MongoDB)** | [`04_mongodb/`](04_mongodb/) | Python + PyMongo lessons on local MongoDB | [`04_mongodb/README.md`](04_mongodb/README.md) |
| **Cloud (AWS + Terraform)** | [`05_aws_terraform/`](05_aws_terraform/) | Terraform workflow for provisioning and remotely connecting to AWS RDS MySQL | [`05_aws_terraform/README.md`](05_aws_terraform/README.md) |
| **Cloud (MongoDB Atlas + Terraform)** | [`06_mongo_terraform/`](06_mongo_terraform/) | Terraform workflow for creating MongoDB Atlas M0 and remote connectivity | [`06_mongo_terraform/README.md`](06_mongo_terraform/README.md) |

---

## MySQL quick start

Prerequisites:

- MySQL server
- `mysql` client in your `PATH`

Load the database dump:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p car_service_db < 01_database_mysql/car_service_db.sql
```

ORM sample (optional):

ORM docs: [`03_mysql/16_orm/orm_sqlalchemy.md`](03_mysql/16_orm/orm_sqlalchemy.md)

```bash
pip install -r 03_mysql/16_orm/requirements.txt
python 03_mysql/16_orm/01_data_types/example.py
```

---

## MongoDB quick start

Module docs:

- [`04_mongodb/README.md`](04_mongodb/README.md)
- [`04_mongodb/mongodb_topics.md`](04_mongodb/mongodb_topics.md)

Install dependencies and run a lesson:

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/01_crud/example.py
```

Restore bundled Mongo dump into `edu_academy_seed`:

```bash
mongorestore --uri="mongodb://localhost:27017" --db=edu_academy_seed ./edu_academy_seed
```

Or seed synthetic data from schema:

```bash
python 02_database_mongo/dump/mongo.py --schema 02_database_mongo/dump/schema.json --mongo-uri "mongodb://127.0.0.1:27017" --db edu_academy_seed --drop-db
```

Run all Mongo lessons:

```bash
chmod +x 04_mongodb/verify_mongodb_examples.sh
./04_mongodb/verify_mongodb_examples.sh
```

