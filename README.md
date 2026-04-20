# Database practice examples (MySQL)

Numbered topic folders contain **runnable SQL examples** and short companion **`.md`** notes for a workshop-style **`car_service_db`** curriculum (DDL, DML, queries, joins, indexes, transactions, window functions, variables, functions, triggers, procedures, loops, and more).

## Layout

| Folder | Topic (module notes) |
|--------|----------------------|
| `1_relational_algebra_Koda` | [Relational algebra](1_relational_algebra_Koda/algebra_Koda_car_service_db.md) |
| `2_ddl` | [DDL](2_ddl/ddl_car_service_db.md) |
| `3_dml` | [DML](3_dml/dml_car_service_db.md) |
| `4_dql` | [DQL](4_dql/dql_car_service_db.md) |
| `5_order_commands` | [SQL clause order](5_order_commands/order_commands_car_service_db.md) |
| `6_subqueries` | [Subqueries](6_subqueries/subqueries_car_service_db.md) |
| `7_join` | [JOINs](7_join/joins_car_service_db.md) |
| `8_indexes` | [Indexes](8_indexes/indexes_car_service_db.md) |
| `9_transactions` | [Transactions](9_transactions/transactions_car_service_db.md) |
| `10_windows_functions` | [Window functions](10_windows_functions/windows_functions_car_service_db.md) |
| `11_variables` | [Variables](11_variables/variables_car_service_db.md) |
| `12_triggers` | [Triggers](12_triggers/triggers_car_service_db.md) |
| `13_functions` | [Built-in / SQL functions](13_functions/functions_car_service_db.md) |
| `14_procedures` | [Stored procedures](14_procedures/procedures_car_service_db.md) |
| `15_cycles` | [Loops and recursive CTEs](15_cycles/cycles_car_service_db.md) |

Each module usually pairs:

- `car_service_*_examples.sql` — examples to run with the **mysql** client  
- `*_car_service_db.md` — context and how to run (paths may vary by topic)

Place your **`car_service_db`** dump under `database/` (see `.gitignore` for expected artifacts) and load it before topics that assume existing schema and data.

## Prerequisites

- **MySQL** server reachable from your machine  
- **`mysql` client** on your `PATH` (credentials via `~/.my.cnf` or flags)

## Load the sample database

Example (adjust user, host, and path to match your dump):

```bash
gunzip -c database/car_service_db.sql.gz | mysql -u YOUR_USER -p car_service_db
```

If you only have an uncompressed `.sql` file, pipe or redirect that file instead.

## Run all example scripts

From the repository root:

```bash
chmod +x verify_sql_examples.sh
./verify_sql_examples.sh
```

Optional environment variables:

- `MYSQL_USER` — defaults to `root`  
- `MYSQL_ARGS` — extra arguments for the mysql client (for example `'-h127.0.0.1 -psecret'`)

The script runs every listed `.sql` file in order. If **`car_service_db`** is not present, it stops after the scripts that do not require it and prints instructions to load the database first.

## MySQL version

Several examples target **MySQL 8.0+** (for example window functions, functional indexes, `EXPLAIN ANALYZE`). Use 8.0 or newer when possible.
