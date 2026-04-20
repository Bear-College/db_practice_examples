# Built-in functions — `car_service_db`

Examples use **`car_service_db`** (from **`database_mysql/car_service_db.sql.gz`**) and focus on common **MySQL built-in functions**: strings, numbers, dates, conditionals, and a few utilities. They are **not** stored routines (`CREATE FUNCTION`); those are a separate topic.

**Script:** `13_functions/car_service_functions_examples.sql`

```bash
gunzip -c database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 13_functions/car_service_functions_examples.sql
```

**Performance:** large tables are filtered with **`WHERE id BETWEEN …`** / **`LIMIT`**.

---

## Map (by section in the `.sql` file)

| Section | Functions (idea) |
|---------|------------------|
| **F1** | Strings: **`CONCAT`**, **`UPPER`**, **`LOWER`** on names / email |
| **F2** | **`LENGTH`**, **`LEFT`**, **`RIGHT`**, **`SUBSTRING`** on **`parts.sku`** |
| **F3** | **`TRIM`**, **`REPLACE`** |
| **F4** | Numeric: **`ROUND`**, **`CEIL`**, **`FLOOR`**, **`ABS`**, **`MOD`** on **`work_orders.total_cost`** |
| **F5** | Date/time: **`DATE_FORMAT`**, **`YEAR`**, **`TIMESTAMPDIFF`**, **`CURDATE()`** on **`appointments.scheduled_at`** |
| **F6** | Conditionals: **`IF`**, **`IFNULL`**, **`NULLIF`**, **`COALESCE`** |
| **F7** | **`GREATEST`**, **`LEAST`** |
| **F8** | **`FORMAT`** (locale-style number formatting) |
| **F9** | Pattern: **`REGEXP`** / **`RLIKE`** (simple) |
| **F10** | Aggregate helper: **`GROUP_CONCAT`** (with **`GROUP BY`**) |

---

## Notes

- **`NOW()`**, **`CURDATE()`** — results change with wall clock; fine for demos.  
- **`REGEXP`** behavior can depend on collation / version.  
- For production, prefer **parameterized** queries over building strings with **`CONCAT`** where injection is a risk (not shown here).
