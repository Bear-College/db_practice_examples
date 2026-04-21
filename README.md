# Database practice examples

This repository has three learning tracks:

| Track | Folder | Stack | Module README |
|---|---|---|---|
| **Relational (MySQL)** | [`mysql/`](mysql/) | SQL scripts for `car_service_db` + SQLAlchemy examples | [`mysql/README.md`](mysql/README.md) |
| **Document (MongoDB)** | [`mongodb/`](mongodb/) | Python + PyMongo lessons on local MongoDB | [`mongodb/README.md`](mongodb/README.md) |
| **Cloud (AWS + Terraform)** | [`aws-terraform/`](aws-terraform/) | Terraform workflow for provisioning and remotely connecting to AWS RDS MySQL | [`aws-terraform/README.md`](aws-terraform/README.md) |
| **Cloud (MongoDB Atlas + Terraform)** | [`mongo-terraform/`](mongo-terraform/) | Terraform workflow for creating MongoDB Atlas M0 and remote connectivity | [`mongo-terraform/README.md`](mongo-terraform/README.md) |

---

## MySQL quick start

Prerequisites:

- MySQL server
- `mysql` client in your `PATH`

Load the database dump:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p car_service_db < database_mysql/car_service_db.sql
```

ORM sample (optional):

ORM docs: [`mysql/16_orm/orm_sqlalchemy.md`](mysql/16_orm/orm_sqlalchemy.md)

```bash
pip install -r mysql/16_orm/requirements.txt
python mysql/16_orm/01_data_types/example.py
```

---

## MongoDB quick start

Module docs:

- [`mongodb/README.md`](mongodb/README.md)
- [`mongodb/mongodb_topics.md`](mongodb/mongodb_topics.md)

Install dependencies and run a lesson:

```bash
pip install -r mongodb/requirements.txt
python mongodb/01_crud/example.py
```

Restore bundled Mongo dump into `edu_academy_seed`:

```bash
mongorestore --uri="mongodb://localhost:27017" --db=edu_academy_seed ./edu_academy_seed
```

Or seed synthetic data from schema:

```bash
python database_mongo/dump/mongo.py --schema database_mongo/dump/schema.json --mongo-uri "mongodb://127.0.0.1:27017" --db edu_academy_seed --drop-db
```

Run all Mongo lessons:

```bash
chmod +x mongodb/verify_mongodb_examples.sh
./mongodb/verify_mongodb_examples.sh
```

