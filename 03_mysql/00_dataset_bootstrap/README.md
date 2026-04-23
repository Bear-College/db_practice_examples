# 00 Dataset Bootstrap

Load the training dataset into MySQL and verify it is ready for lessons.

## Goal

Import `car_service_db` from `01_database_mysql/` and confirm the database can be queried.

## Input files

- `01_database_mysql/car_service_db.sql.zip`
- `01_database_mysql/car_service_schema.sql`

## Steps

1. Unzip dump (from repository root):

```bash
unzip -o 01_database_mysql/car_service_db.sql.zip -d 01_database_mysql
```

2. Import dump into local MySQL:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p car_service_db < 01_database_mysql/car_service_db.sql
```

3. Smoke test:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p -D car_service_db -e "SHOW TABLES;"
```

4. Optional schema check:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p -D car_service_db -e "SOURCE 01_database_mysql/car_service_schema.sql;"
```

## Checklist

- [ ] Dump extracted successfully
- [ ] Import command completed without errors
- [ ] Tables are visible in `car_service_db`
- [ ] You can run a basic `SELECT`

## Output of this stage

`car_service_db` is available for all modules in `03_mysql/`.
