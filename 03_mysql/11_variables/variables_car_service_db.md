# Variables — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/11_variables/variables_car_service_db.md)

These exercises walk through **MySQL session user variables** (`@name`), **system variables** (`@@…`), and the **`PREPARE` / `EXECUTE`** protocol that consumes them. They run on the real database from **`01_database_mysql/car_service_db.sql.gz`** (database name: **`car_service_db`**).

Runnable companion file: [`11_variables/car_service_variables_examples.sql`](car_service_variables_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/11_variables/car_service_variables_examples.sql
```

**Run the script in one client session** so the `@` variables persist between statements. Each new `mysql` connection starts with an empty variable table.

---

## Quick reference

| Concept | Notes |
|---|---|
| **`SET @x = expr`**, **`SET @x := expr`** | Both work in `SET`. `=` and `:=` are equivalent here. |
| **`SET @a = 1, @b = 2`** | Multiple assignments in one statement. |
| **`SELECT @x := col FROM …`** | Assignment **inside** a query; the value can be read and written in the same row scan. |
| **Type** | Untyped — `@x` adapts to whatever you store (`INT`, `DECIMAL`, string, `NULL`). |
| **Scope** | Session-wide; lost when the connection closes (or on `SET @x := NULL`). |
| **System variables** | `@@version`, `@@session.x`, `@@global.x`. Read with `SELECT @@…` or `SHOW VARIABLES LIKE 'x'`. |
| **Not the same as `DECLARE`** | Local variables inside stored programs (`DECLARE name TYPE`) are a different scope, not covered here. |

A common surprise: **user variables and prepared statements share the session**. You can put `?` placeholders in `PREPARE` and bind them with `EXECUTE … USING @var, @var, …` (Exercises V3 and V6).

---

## Schema touchpoints (from the dump)

- **`work_orders`** — `id`, `status`, `total_cost`, `assigned_mechanic_id`
- **`customers`** — `id`, `first_name`, `last_name`

---

## Exercise V1 — `SET` a range, then use it in `WHERE`

### Context

A nightly job pulls a slice of recent work orders into a reporting CSV. Today's slice is `id` 1 to 800. If tomorrow we need a different range, we'd rather change the bounds in **one place** at the top of the script than search-and-replace through the query body.

### What you'll learn

- Declaring user variables with `SET @name := value`.
- Reading them in any subsequent statement of the same session.
- Why putting the magic numbers at the top of the script makes it self-documenting.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Task

Set two user variables `@wo_lo := 1` and `@wo_hi := 800`. Then return `id`, `status`, `total_cost` for `work_orders` with `id BETWEEN @wo_lo AND @wo_hi`, ordered by `id`, limited to 15.

### Expected result

```text
+----+---------------+------------+
| id | status        | total_cost |
+----+---------------+------------+
|  1 | new           |     500.10 |
|  2 | in_progress   |     500.20 |
|  3 | waiting_parts |     500.30 |
|  4 | completed     |     500.40 |
|  5 | cancelled     |     500.50 |
|  6 | new           |     500.60 |
|  7 | in_progress   |     500.70 |
|  8 | waiting_parts |     500.80 |
|  9 | completed     |     500.90 |
| 10 | cancelled     |     501.00 |
| 11 | new           |     501.10 |
| 12 | in_progress   |     501.20 |
| 13 | waiting_parts |     501.30 |
| 14 | completed     |     501.40 |
| 15 | cancelled     |     501.50 |
+----+---------------+------------+
```

### Hint

`SET @wo_lo := 1; SET @wo_hi := 800;` — then use the names inside `BETWEEN`.

### Solution

```sql
SET @wo_lo := 1;
SET @wo_hi := 800;

SELECT id,
       status,
       total_cost
FROM work_orders
WHERE id BETWEEN @wo_lo AND @wo_hi
ORDER BY id
LIMIT 15;
```

### Step-by-step explanation

1. **`SET @wo_lo := 1`** creates the variable `@wo_lo` (if it didn't exist) and assigns the integer `1`. The leading `@` distinguishes it from a column or alias.
2. **Variables are session-scoped.** The next statement in the same session sees them. A second mysql client window won't.
3. **`BETWEEN @wo_lo AND @wo_hi`** is interpreted at execution time; MySQL substitutes the current values. Change them once at the top — the whole script follows.
4. **Type coercion:** `@wo_lo` is "the value you last stored". Compared with the `id INT` column, MySQL casts as needed. Store the same type to keep the optimizer happy.

---

## Exercise V2 — Assign an aggregate to a variable

### Context

A reporting query computes "average ticket size" once, then needs to reuse that number in two follow-up steps (a percentage difference, a "high-cost" flag, …). Recomputing the average each time is wasteful and risks drift. Stash it in a user variable and read it everywhere.

### What you'll learn

- Using `:=` **inside** a `SELECT` to capture an aggregate while it's being produced.
- Reading the captured value in subsequent statements.
- The lifetime of an `@`-variable across statements in the same session.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Task

Run a `SELECT … UNION ALL …` that:

1. Computes `AVG(total_cost)` for `id BETWEEN 1 AND 50000` and stores it in `@avg_cost`, returning the value with metric label `'avg_total_cost'`.
2. Also returns the row count for the same slice as `'rows_in_slice'`.

Then a second query reads `@avg_cost` back twice (to prove it was retained).

### Expected result

```text
+----------------+--------------+
| metric         | value        |
+----------------+--------------+
| avg_total_cost |  2999.950000 |
| rows_in_slice  | 50000.000000 |
+----------------+--------------+
+----------------------------+-------------------------------------+
| metric                     | value                               |
+----------------------------+-------------------------------------+
| stored_avg_total_cost      | 2999.950000000000000000000000000000 |
| stored_avg_total_cost_copy | 2999.950000000000000000000000000000 |
+----------------------------+-------------------------------------+
```

### Hint

`@avg_cost := AVG(total_cost)` inside a `SELECT` will both compute **and** store. The second statement just reads `@avg_cost`.

### Solution

```sql
SELECT 'avg_total_cost' AS metric, @avg_cost := AVG(total_cost) AS value
FROM work_orders
WHERE id BETWEEN 1 AND 50000
UNION ALL
SELECT 'rows_in_slice' AS metric, COUNT(*) AS value
FROM work_orders
WHERE id BETWEEN 1 AND 50000;

SELECT 'stored_avg_total_cost'      AS metric, @avg_cost AS value
UNION ALL
SELECT 'stored_avg_total_cost_copy' AS metric, @avg_cost AS value;
```

### Step-by-step explanation

1. **`@avg_cost := AVG(total_cost)`** does double duty: returns the average as a result column **and** writes it to the session variable.
2. **Two output blocks** — the script issues two separate queries, so the mysql client prints two boxes. The second one proves the variable survived.
3. **Watch the precision.** Inside the aggregate, `value` is a `DECIMAL` and the printed width is short. After storage, `@avg_cost` is held with extra scale (`2999.95000…0000`) — MySQL stores user variables as **wide-precision** types. Cast with `ROUND(@avg_cost, 2)` if you want a tidy display.
4. **Order of evaluation:** in a single `SELECT`, MySQL does not guarantee left-to-right evaluation of expressions. Don't rely on `@a := x, @b := @a + 1` — use separate statements or `LEAST/GREATEST` tricks.

---

## Exercise V3 — Pagination via variables and `PREPARE` / `EXECUTE`

### Context

The web app has a paginated list of work orders (12 per page). The page number comes from the URL. The script should compute the offset from `page * page_size` and pass both to `LIMIT` — but **`LIMIT` does not accept user variables directly**. The portable workaround is **prepared statements**.

### What you'll learn

- Why `LIMIT @offset, @count` is illegal in plain SQL.
- How `PREPARE … FROM @sql` compiles a parametric query.
- How `EXECUTE stmt USING @v1, @v2` binds values into `?` placeholders.
- Cleaning up with `DEALLOCATE PREPARE`.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `assigned_mechanic_id`, `total_cost` |

### Task

Page 2 of size 12: compute `@offset_rows = (@page − 1) × @page_size`, then run a prepared `SELECT` with two `?` placeholders for `LIMIT ?, ?` and bind them via `EXECUTE … USING @offset_rows, @page_size`. Filter to `id BETWEEN 1 AND 3000`, sort by `id`.

### Expected result

```text
+----+----------------------+------------+
| id | assigned_mechanic_id | total_cost |
+----+----------------------+------------+
| 13 |                   13 |     501.30 |
| 14 |                   14 |     501.40 |
| 15 |                   15 |     501.50 |
| 16 |                   16 |     501.60 |
| 17 |                   17 |     501.70 |
| 18 |                   18 |     501.80 |
| 19 |                   19 |     501.90 |
| 20 |                   20 |     502.00 |
| 21 |                   21 |     502.10 |
| 22 |                   22 |     502.20 |
| 23 |                   23 |     502.30 |
| 24 |                   24 |     502.40 |
+----+----------------------+------------+
```

### Hint

Store the whole `SELECT` text (with `?` placeholders) in `@sql_page`, then `PREPARE stmt_page FROM @sql_page` and `EXECUTE stmt_page USING @offset_rows, @page_size`.

### Solution

```sql
SET @page_size   := 12;
SET @page        := 2;
SET @offset_rows := (@page - 1) * @page_size;

SET @sql_page := 'SELECT id, assigned_mechanic_id, total_cost
                  FROM work_orders
                  WHERE id BETWEEN 1 AND 3000
                  ORDER BY id
                  LIMIT ?, ?';

PREPARE stmt_page FROM @sql_page;
EXECUTE stmt_page USING @offset_rows, @page_size;
DEALLOCATE PREPARE stmt_page;
```

### Step-by-step explanation

1. **The illegal direct form** would be `LIMIT @offset_rows, @page_size`. MySQL parses `LIMIT` arguments at compile time and (until very recent versions) refuses user variables there.
2. **Build the SQL text** in `@sql_page`. The two `?` placeholders are positional and must appear in the order you'll bind them: offset first, count second.
3. **`PREPARE … FROM @sql_page`** parses and plans the statement once. **`EXECUTE … USING …`** supplies the values.
4. **Always `DEALLOCATE PREPARE`** at the end — every connection has a small cache of named prepared statements, and abandoned ones waste it.
5. **Pagination math:** page numbers usually start at `1`, so `offset = (page − 1) * page_size`. Forgetting the `− 1` is the classic off-by-one bug.

---

## Exercise V4 — Row counter pattern with `:=` (pre-window-functions trick)

### Context

Before MySQL 8 introduced `ROW_NUMBER()`, you assigned a counter into a user variable and incremented it row by row. The pattern is still useful in MySQL 5.7 environments and is a vivid example of "assignment inside `SELECT`".

### What you'll learn

- Initializing a counter with a `CROSS JOIN (SELECT @rn := 0) AS init`.
- Incrementing it inside the projection: `@rn := @rn + 1 AS row_seq`.
- Why this pattern requires a specific evaluation order — and the gotchas.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 500`, ordered by `id`, return `id`, `total_cost`, and a sequence `row_seq` starting at `1`. Limit 20.

### Expected result

```text
+----+------------+---------+
| id | total_cost | row_seq |
+----+------------+---------+
|  1 |     500.10 |       1 |
|  2 |     500.20 |       2 |
|  3 |     500.30 |       3 |
|  4 |     500.40 |       4 |
|  5 |     500.50 |       5 |
|  6 |     500.60 |       6 |
|  7 |     500.70 |       7 |
|  8 |     500.80 |       8 |
|  9 |     500.90 |       9 |
| 10 |     501.00 |      10 |
| 11 |     501.10 |      11 |
| 12 |     501.20 |      12 |
| 13 |     501.30 |      13 |
| 14 |     501.40 |      14 |
| 15 |     501.50 |      15 |
| 16 |     501.60 |      16 |
| 17 |     501.70 |      17 |
| 18 |     501.80 |      18 |
| 19 |     501.90 |      19 |
| 20 |     502.00 |      20 |
+----+------------+---------+
```

### Hint

`CROSS JOIN (SELECT @rn := 0) AS init` resets the variable to `0` once, **before** the main scan starts; then `@rn := @rn + 1` increments per row.

### Solution

```sql
SELECT id,
       total_cost,
       @rn := @rn + 1 AS row_seq
FROM work_orders
CROSS JOIN (SELECT @rn := 0) AS init
WHERE id BETWEEN 1 AND 500
ORDER BY id
LIMIT 20;
```

### Step-by-step explanation

1. **Initialization in a derived table.** `(SELECT @rn := 0) AS init` runs once, producing one row that resets `@rn`. The `CROSS JOIN` attaches it to the main query without affecting cardinality.
2. **Increment inside `SELECT`.** Each row evaluates `@rn := @rn + 1` and emits the new value as `row_seq`.
3. **Order matters.** The `ORDER BY id` is needed for the counter to follow `id`. Without it, MySQL might evaluate the rows in storage order and your sequence would mix.
4. **Modern alternative:** `ROW_NUMBER() OVER (ORDER BY id)` (see `10_windows_functions`). It is clearer, doesn't depend on evaluation order, and works after a `GROUP BY`. Use the variable trick only when stuck on MySQL 5.7.
5. **Deprecation warning:** since MySQL 8.0, using `:=` inside `SELECT` to read **and** write the same variable in non-trivial expressions emits a deprecation note. Plan to migrate to window functions.

---

## Exercise V5 — Multiple assignments in one `SET`, reused in a query

### Context

It is common to define **paired bounds** (low/high, min/max) in one place. MySQL's `SET` accepts a comma-separated list, so you don't need two statements for `@lo` and `@hi`.

### What you'll learn

- Comma-separated `SET` for related variables.
- Calling user-set bounds from a `GROUP BY` query.
- Using `MOD(id, 2)` to bucket parity (even / odd).

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id` |

### Task

Set `@cust_lo := 1, @cust_hi := 200` in **one** `SET`. Then count customers with `id BETWEEN @cust_lo AND @cust_hi`, grouped by `MOD(id, 2)` (parity bucket).

### Expected result

```text
+---------------+----------------------+
| parity_bucket | n_customers_in_range |
+---------------+----------------------+
|             1 |                  100 |
|             0 |                  100 |
+---------------+----------------------+
```

### Hint

`SET @cust_lo := 1, @cust_hi := 200;` — comma between the assignments, **not** a semicolon.

### Solution

```sql
SET @cust_lo := 1, @cust_hi := 200;

SELECT MOD(id, 2) AS parity_bucket,
       COUNT(*)   AS n_customers_in_range
FROM customers
WHERE id BETWEEN @cust_lo AND @cust_hi
GROUP BY MOD(id, 2);
```

### Step-by-step explanation

1. **One `SET` with two assignments.** Equivalent to two separate `SET` statements, but groups the bounds for readability.
2. **`MOD(id, 2)`** yields `0` for even `id`, `1` for odd. Useful for parity, sharding demos, and quick "balanced split" sanity checks.
3. **`GROUP BY MOD(id, 2)`** collapses each parity bucket; the `COUNT(*)` returns the bucket size. For `id BETWEEN 1 AND 200` we expect exactly 100 even and 100 odd `id`s.
4. **Why no `ORDER BY`?** Two rows; not worth ordering. For dashboards always add an explicit `ORDER BY parity_bucket` so the report layout is stable.

---

## Exercise V6 — General `PREPARE` / `EXECUTE` with three placeholders

### Context

The same prepared-statement protocol from V3, but now with three placeholders — for a `BETWEEN` range and a `LIMIT`. This is the everyday shape for "parametric report" handlers.

### What you'll learn

- Multi-placeholder `PREPARE`.
- The order of values in `EXECUTE … USING` matches the positional `?`s in the SQL text.
- That you can `EXECUTE` the same prepared statement many times with different bindings — without re-parsing.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Task

Prepare `'SELECT id, status, total_cost FROM work_orders WHERE id BETWEEN ? AND ? ORDER BY id LIMIT ?'`. Bind `@p_lo := 100`, `@p_hi := 400`, `@p_lim := 8` and execute.

### Expected result

```text
+-----+---------------+------------+
| id  | status        | total_cost |
+-----+---------------+------------+
| 100 | cancelled     |     510.00 |
| 101 | new           |     510.10 |
| 102 | in_progress   |     510.20 |
| 103 | waiting_parts |     510.30 |
| 104 | completed     |     510.40 |
| 105 | cancelled     |     510.50 |
| 106 | new           |     510.60 |
| 107 | in_progress   |     510.70 |
+-----+---------------+------------+
```

### Hint

`EXECUTE stmt USING @p_lo, @p_hi, @p_lim` — the order **must** match the `?`s in `WHERE id BETWEEN ? AND ?` and `LIMIT ?`.

### Solution

```sql
SET @sql := 'SELECT id, status, total_cost
             FROM work_orders
             WHERE id BETWEEN ? AND ?
             ORDER BY id
             LIMIT ?';

SET @p_lo  := 100;
SET @p_hi  := 400;
SET @p_lim := 8;

PREPARE stmt FROM @sql;
EXECUTE stmt USING @p_lo, @p_hi, @p_lim;
DEALLOCATE PREPARE stmt;
```

### Step-by-step explanation

1. **Build the SQL** in `@sql`. The three `?` are positional.
2. **`EXECUTE … USING @p_lo, @p_hi, @p_lim`** binds **in order**. Swapping `@p_lo` and `@p_hi` gives an empty result (no rows satisfy `BETWEEN 400 AND 100`).
3. **Re-execute with new values without re-preparing:** set `@p_lo := 200; @p_hi := 250; EXECUTE stmt USING …;` — same plan, different values.
4. **`DEALLOCATE PREPARE stmt`** frees the named statement. Forgetting it is mostly harmless in a short script, but it accumulates in long-lived connections.
5. **Security note:** prepared statements with `?` placeholders are the standard **SQL-injection defence** when the application drives parameters. Don't `CONCAT` user input into `@sql`.

---

## Exercise V7 — System variables (`@@version`, `@@session.transaction_isolation`)

### Context

The DBA wants to confirm what server version your client is talking to and which transaction-isolation level the session is using before running a sensitive migration.

### What you'll learn

- `@@x` reads a **system** variable (not a user variable).
- `@@session.x` is the per-connection value; `@@global.x` is the server-wide default.
- A handful of common variables: `@@version`, `@@session.transaction_isolation`.

### Tables in play

(no business tables — system metadata only)

### Task

Return a `metric` / `value` table with the MySQL version and the session transaction isolation, using `UNION ALL`.

### Expected result

```text
+---------------+-----------------+
| k             | v               |
+---------------+-----------------+
| mysql_version | 9.6.0           |
| tx_isolation  | REPEATABLE-READ |
+---------------+-----------------+
```

### Hint

`SELECT @@version` and `SELECT @@session.transaction_isolation`.

### Solution

```sql
SELECT 'mysql_version' AS k, @@version AS v
UNION ALL
SELECT 'tx_isolation'  AS k, @@session.transaction_isolation AS v;
```

### Step-by-step explanation

1. **`@@version`** is short for `@@global.version`; the version is server-wide.
2. **`@@session.transaction_isolation`** is the **per-connection** isolation level. Change it for the current session with `SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED`.
3. **`UNION ALL`** stacks the two single-row queries into one tidy result table. Use `UNION` instead if you want duplicates removed (not needed here, both rows are distinct).
4. **Read-only in normal labs:** changing `@@global.*` requires `SUPER` (or `SYSTEM_VARIABLES_ADMIN`) privilege. The script only **reads** these values.
5. **Variants you may meet:** `SHOW VARIABLES LIKE 'version'` returns the same value as `@@version` but as a row, not a scalar.

---

## Exercise V8 — Clearing a user variable

### Context

The script set `@avg_cost` earlier and you'd like to be explicit that it's no longer valid (e.g. moving to a new logical step of the script). Setting it to `NULL` is the conventional reset.

### What you'll learn

- A `NULL` assignment marks the variable as "cleared" but leaves the name in the session.
- Reading `@x IS NULL` returns `1` (true) when cleared.
- That closing the connection clears everything automatically.

### Tables in play

(no business tables — session state only)

### Task

`SET @avg_cost := NULL`, then verify with `@avg_cost IS NULL` and a stable `1` to confirm the session is still healthy.

### Expected result

```text
+------------------+-------+
| metric           | value |
+------------------+-------+
| avg_cost_cleared |     1 |
| session_ok       |     1 |
+------------------+-------+
```

### Hint

`@avg_cost IS NULL` returns `1` when the variable was cleared.

### Solution

```sql
SET @avg_cost := NULL;

SELECT 'avg_cost_cleared' AS metric, @avg_cost IS NULL AS value
UNION ALL
SELECT 'session_ok'       AS metric, 1                 AS value;
```

### Step-by-step explanation

1. **`@avg_cost := NULL`** doesn't delete the variable name from the session — it merely sets the value to `NULL`. Equivalent to "forget the cached value".
2. **`@avg_cost IS NULL`** evaluates to `1` (true). `IS NULL` is the only way to test for `NULL` (`= NULL` would itself return `NULL`).
3. **Full reset:** `DISCONNECT` and reconnect, or restart the client. There is no `UNSET @x` in MySQL.
4. **Final `1`** acts as a sentinel — useful in scripts so the final row prints something visible and the runner knows execution reached the bottom.

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `@x` is `NULL` after the script | Variables live per connection — you reopened the client. Re-run the `SET`. |
| `LIMIT @offset, @count` errors | `LIMIT` does not accept variables in plain SQL. Wrap in `PREPARE` / `EXECUTE` (V3, V6). |
| `EXECUTE stmt USING @a, @b` complains | Number of bindings must match number of `?`. Count them carefully. |
| `@avg_cost` shows extra zeros | User variables hold higher-precision decimals than the column. Wrap reads with `ROUND(@avg_cost, 2)`. |
| Row counter `@rn := @rn + 1` skips numbers | The `(SELECT @rn := 0)` init was missing — variables initialize lazily and a stale value from a previous run leaks in. |

If you want to run **all** examples at once: `mysql -t -u root car_service_db < 03_mysql/11_variables/car_service_variables_examples.sql`.
