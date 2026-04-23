# 00 Debugging Basics

Build a simple workflow for debugging SQL errors quickly and safely.

## Goal

Understand what failed, isolate the cause, and validate a fix with minimal risk.

## Common error categories

- Syntax errors (`1064`)
- Missing table/column errors (`1146`, `1054`)
- Constraint violations (duplicate key, FK failures)
- Permission errors

## Debug workflow

1. Reproduce the error with the smallest query possible.
2. Read the full error message and error code.
3. Check schema objects involved (`SHOW TABLES`, `DESCRIBE <table>`).
4. Test assumptions with focused `SELECT` statements.
5. Apply a small fix and re-run only the affected part.

## Useful commands

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p -D car_service_db -e "SHOW TABLES;"
mysql -h 127.0.0.1 -P 3306 -u root -p -D car_service_db -e "DESCRIBE customers;"
```

## Safe practice

- Use a transaction while testing writes:

```sql
START TRANSACTION;
-- test UPDATE/DELETE/INSERT here
ROLLBACK;
```

## Checklist

- [ ] You can identify error type from code/message
- [ ] You can isolate failing SQL
- [ ] You can validate a fix before applying broadly

## Output of this stage

A repeatable debugging habit for all SQL modules.
