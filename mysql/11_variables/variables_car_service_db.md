# Variables — `car_service_db`

Examples show **MySQL session user variables** (`@name`), **assignment** from `SET` / `SELECT`, use in **`WHERE`** / **`LIMIT`**, **`PREPARE` / `EXECUTE`**, and a few **server/session system variables** (`@@…`). The script targets **`car_service_db`** (from **`database/car_service_db.sql.gz`**).

**Script:** `11_variables/car_service_variables_examples.sql`

```bash
gunzip -c database/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 11_variables/car_service_variables_examples.sql
```

Run the file **in one client session** so `@` variables persist between statements.

---

## User variables (`@user_var`)

| Topic | Notes |
|-------|--------|
| **Scope** | Session-wide; lost when the connection closes. |
| **`SET @x = expr`**, **`SET @a = 1, @b = 2`** | Initialize or update. |
| **`:=` in `SELECT`** | Can assign and read in one query (order of evaluation matters). |
| **`SELECT @x := col FROM …`** | Store a value from a query (e.g. aggregate). |
| **Use in statements** | `WHERE id BETWEEN @lo AND @hi`, `LIMIT @offset, @count`, etc. |
| **Clear** | `SET @x := NULL` or reconnect. |

User variables are **not** the same as **local variables** inside stored programs (`DECLARE` — not covered here).

---

## System variables (`@@session` / `@@global`)

Read with **`SELECT @@session.variable_name`**, **`SHOW VARIABLES LIKE '…'`**. Some session settings can be changed with **`SET SESSION …`**; many globals require privileges. The script only touches safe session examples where noted.

---

## Blocks in the `.sql` file

1. `SET` range bounds → `SELECT` from **`work_orders`**.  
2. Assign aggregate to **`@avg_cost`**.  
3. **`LIMIT`** using **`@offset`** / **`@page_size`**.  
4. Row counter pattern with **`@rownum`** (historical; window functions are usually clearer).  
5. **`PREPARE` / `EXECUTE`** with placeholders bound from user variables.  
6. Read **`@@version`**, **`@@session.transaction_isolation`** (and optional **`sql_select_limit`** demo, commented).  
