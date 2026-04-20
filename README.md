# Database practice examples

Two tracks live at the repository root:

| Track | Folder | Stack |
|-------|--------|--------|
| **Relational (MySQL)** | [`mysql/`](mysql/) | `.sql` scripts for **`car_service_db`**, plus [`mysql/16_orm/`](mysql/16_orm/) (Python + SQLAlchemy / SQLite) |
| **Document (MongoDB)** | [`mongodb/`](mongodb/) | Python + **PyMongo** against a local **`mongod`** |

---

## Relational — `mysql/`

Numbered topic folders under **`mysql/`** contain **runnable SQL** and companion **`.md`** notes (relational algebra, DDL, DML, DQL, joins, indexes, transactions, windows, variables, triggers, functions, procedures, cycles). Module **`mysql/16_orm`** adds **SQLAlchemy ORM** samples in themed subfolders.

### Layout (MySQL)

| Folder | Topic (module notes) |
|--------|----------------------|
| `mysql/01_relational_algebra_Koda` | [Relational algebra](mysql/01_relational_algebra_Koda/algebra_Koda_car_service_db.md) |
| `mysql/02_ddl` | [DDL](mysql/02_ddl/ddl_car_service_db.md) |
| `mysql/03_dml` | [DML](mysql/03_dml/dml_car_service_db.md) |
| `mysql/04_dql` | [DQL](mysql/04_dql/dql_car_service_db.md) |
| `mysql/05_order_commands` | [SQL clause order](mysql/05_order_commands/order_commands_car_service_db.md) |
| `mysql/06_subqueries` | [Subqueries](mysql/06_subqueries/subqueries_car_service_db.md) |
| `mysql/07_join` | [JOINs](mysql/07_join/joins_car_service_db.md) |
| `mysql/08_indexes` | [Indexes](mysql/08_indexes/indexes_car_service_db.md) |
| `mysql/09_transactions` | [Transactions](mysql/09_transactions/transactions_car_service_db.md) |
| `mysql/10_windows_functions` | [Window functions](mysql/10_windows_functions/windows_functions_car_service_db.md) |
| `mysql/11_variables` | [Variables](mysql/11_variables/variables_car_service_db.md) |
| `mysql/12_triggers` | [Triggers](mysql/12_triggers/triggers_car_service_db.md) |
| `mysql/13_functions` | [Built-in / SQL functions](mysql/13_functions/functions_car_service_db.md) |
| `mysql/14_procedures` | [Stored procedures](mysql/14_procedures/procedures_car_service_db.md) |
| `mysql/15_cycles` | [Loops and recursive CTEs](mysql/15_cycles/cycles_car_service_db.md) |
| `mysql/16_orm` | [SQLAlchemy ORM topics](mysql/16_orm/orm_sqlalchemy.md) |

Folders **`mysql/01`**–**`mysql/09`** are zero-padded so the file browser sorts them **1 … 16**.

Each SQL module usually pairs:

- `car_service_*_examples.sql` — run with the **mysql** client  
- `*_car_service_db.md` — notes and commands

Place the **`car_service_db`** dump under **`database_mysql/`** (see `.gitignore`) and load it before topics that need schema and data.

### Prerequisites (MySQL)

- **MySQL** server  
- **`mysql` client** on your `PATH`

### Load `car_service_db`

```bash
gunzip -c database_mysql/car_service_db.sql.gz | mysql -u YOUR_USER -p car_service_db
```

Or import the plain SQL dump directly:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p car_service_db < database_mysql/car_service_db.sql
```

### Run all MySQL `.sql` examples

From the **repository root** (wrapper keeps old paths working):

```bash
chmod +x verify_sql_examples.sh
./verify_sql_examples.sh
```

Or run the script inside **`mysql/`** directly: `./mysql/verify_sql_examples.sh`

Optional: `MYSQL_USER`, `MYSQL_ARGS`.

### MySQL version

Many examples assume **MySQL 8.0+**.

### Python / SQLAlchemy (`mysql/16_orm`)

```bash
pip install -r mysql/16_orm/requirements.txt
python mysql/16_orm/01_data_types/example.py
```

SQLite lab files (`*.db`) are gitignored under `mysql/16_orm/`.

---

## Document — `mongodb/`

[Topic index and setup](mongodb/mongodb_topics.md)

```bash
pip install -r mongodb/requirements.txt
python mongodb/01_connection_basics/example.py
```

Run all Mongo examples (needs **`mongod`** on `localhost:27017` or set **`MONGODB_URI`**):

```bash
chmod +x mongodb/verify_mongodb_examples.sh
./mongodb/verify_mongodb_examples.sh
```

**Large Mongo practice DB** — [`database_mongo/README.md`](database_mongo/README.md): **100 linked collections**, **200k** documents in fact tables, CSV + `mongoimport` + optional `seed_mongo.py` (all under **`database_mongo/`**).

---

## Repository layout (top level)

```
database/                 # optional MySQL dump (see .gitignore)
database_mongo/           # MongoDB CSV export (car_workshop_mongo) + mongoimport script
mysql/                    # relational SQL + ORM
mongodb/                  # PyMongo examples + practice_db (seed / export / dump scripts)
verify_sql_examples.sh    # delegates to mysql/verify_sql_examples.sh
```
