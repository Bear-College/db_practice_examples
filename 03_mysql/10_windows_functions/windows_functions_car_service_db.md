# Window functions — `car_service_db`

Examples use **`car_service_db`** from **`01_database_mysql/car_service_db.sql.gz`**. The script is **`10_windows_functions/car_service_windows_functions_examples.sql`**.

**Requirement:** MySQL **8.0+** (window functions are not available in MySQL 5.7).

```bash
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 10_windows_functions/car_service_windows_functions_examples.sql
```

**Performance:** queries use **`WHERE id BETWEEN …`** on large tables so runs stay fast.

---

## Concepts

| Function / clause | Role |
|-------------------|------|
| **`OVER ( )`** | Turns an aggregate or ranking function into a **window** function (row stays visible). |
| **`PARTITION BY`** | Separate windows per group (like “GROUP BY” but without collapsing rows). |
| **`ORDER BY` inside `OVER`** | Order rows **inside** each partition (required for ranking / offsets). |
| **`ROWS` / `RANGE` frame** | Which peer rows feed **`LAST_VALUE`**, moving aggregates, etc. |
| **`WINDOW name AS (…)`** | Reuse the same window definition on multiple columns. |

---

## Examples in the `.sql` file

1. **`ROW_NUMBER()`** — unique rank within `work_orders.status`.  
2. **`RANK()` / `DENSE_RANK()`** — ties handled differently from `ROW_NUMBER`.  
3. **`SUM(…) OVER (PARTITION BY …)`** — partition subtotal without `GROUP BY`.  
4. **`AVG(…) OVER`** — rolling / partition average (see comments).  
5. **`LAG()` / `LEAD()`** — previous / next row by `ORDER BY` (e.g. per mechanic).  
6. **`NTILE(n)`** — split partition into *n* buckets.  
7. **`FIRST_VALUE()` / `LAST_VALUE()`** — explicit **`ROWS`** frame for **`LAST_VALUE`** (default frame can surprise).  
8. **Named `WINDOW`** — same partition/order reused for several functions.

---

## `LAST_VALUE` note

With the default frame, **`LAST_VALUE()`** often matches the **current** row. The script uses an explicit **`ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`** (or equivalent) where needed so “last” means last in the partition.
