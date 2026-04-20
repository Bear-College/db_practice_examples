# Stored procedures — `car_service_db`

Examples define **MySQL stored procedures** with **`IN`**, **`OUT`**, and **`INOUT`** parameters, **`DECLARE`** local variables, and **`CALL`**. They live in **`car_service_db`** (from **`database_mysql/car_service_db.sql.gz`**).

**Script:** `14_procedures/car_service_procedures_examples.sql`

```bash
gunzip -c database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 14_procedures/car_service_procedures_examples.sql
```

Use the **mysql** client so **`DELIMITER`** works when you redirect or `SOURCE` the file.

---

## Concepts

| Item | Role |
|------|------|
| **`CREATE PROCEDURE name …`** | Named block of SQL, stored in the server. |
| **`IN`** | Input parameter (default if omitted). |
| **`OUT`** | Output parameter; caller passes a **user variable** (e.g. `@sum`). |
| **`INOUT`** | Read and write the same parameter through a user variable. |
| **`DECLARE`** | Local variables inside `BEGIN … END`. |
| **`CALL proc(...)`** | Execute the procedure. |

**Security:** prefer **`DEFINER`** / **`SQL SECURITY INVOKER`** and least privilege in production; these labs use defaults for teaching.

---

## Procedures in the `.sql` file

1. **`sp_work_orders_by_status`** — `IN` status + limit; returns a **result set** (`SELECT`).  
2. **`sp_sum_cost_slice`** — `OUT` total `SUM(total_cost)` over an id slice.  
3. **`sp_customer_count`** — `IN` min/max id; `OUT` count; uses **`DECLARE`** + **`IF`**.  
4. **`sp_append_tag`** — `INOUT` on a user variable (string tag).  
5. Optional **`DROP PROCEDURE IF EXISTS`** at the end to remove definitions.
