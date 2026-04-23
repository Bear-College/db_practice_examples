# 00 Environment Setup

Prepare a local MySQL environment for all lessons in `03_mysql/`.

## Goal

Have a working MySQL server and client tooling so you can run SQL scripts from this repository without setup blockers.

## Required tools

- MySQL Server 8.x (or compatible)
- MySQL CLI client (`mysql`)
- Optional: MySQL Workbench

## Steps

1. Verify MySQL server is running.
2. Verify CLI is available:

```bash
mysql --version
```

3. Test connection:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p -e "SELECT VERSION();"
```

4. Confirm UTF-8 settings:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p -e "SHOW VARIABLES LIKE 'character_set_server';"
mysql -h 127.0.0.1 -P 3306 -u root -p -e "SHOW VARIABLES LIKE 'collation_server';"
```

## Checklist

- [ ] MySQL server is running
- [ ] `mysql` command works in terminal
- [ ] Connection to local server succeeds
- [ ] Server charset/collation are verified

## Output of this stage

You are ready to import `car_service_db` and start SQL lessons.
