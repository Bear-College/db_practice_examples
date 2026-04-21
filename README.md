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

Load the database dump:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p car_service_db < 01_database_mysql/car_service_db.sql
```

---

## MongoDB quick start

Restore bundled Mongo dump into `edu_academy_seed`:

```bash
mongorestore --uri="mongodb://localhost:27017" --db=edu_academy_seed ./edu_academy_seed
```

