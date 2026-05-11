# Stored procedures — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/14_procedures/procedures_car_service_db.md)

These exercises walk through **MySQL stored procedures** — named server-side blocks of SQL with **`IN`**, **`OUT`**, and **`INOUT`** parameters, local **`DECLARE`** variables, conditional **`IF`**, and how to invoke them via **`CALL`**. They run on the real database loaded from **`01_database_mysql/car_service_db.sql.gz`** (database name: **`car_service_db`**).

Runnable companion file: [`14_procedures/car_service_procedures_examples.sql`](car_service_procedures_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/14_procedures/car_service_procedures_examples.sql
```

Always use the **`mysql`** client (not a GUI) when loading procedure files: only the client honours **`DELIMITER $$`**, which is needed so MySQL can tell the inner `;` (statement terminators inside `BEGIN … END`) from the outer end-of-statement.

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real shop would write this procedure (1-2 sentences). |
| **What you'll learn** | Procedure constructs trained in this exact exercise. |
| **Tables in play** | Only the columns the procedure actually touches. |
| **Task** | Concrete requirements (signature, body, how to call). |
| **Expected result** | Real output from a live `CALL` (copied from a live run). |
| **Hint** | A single nudge toward the right keyword/clause. |
| **Solution** | Working SQL you can paste into `mysql`. |
| **Step-by-step explanation** | What each line does and the typical mistakes. |

---

## Map: procedure constructs (matches the course sheet)

| Theme | SQL ideas |
|--------|-----------|
| **`CREATE PROCEDURE name(...)`** | Define a named, reusable block of SQL stored in the server. |
| **`DELIMITER $$`** | Temporarily change the statement terminator so `;` can appear inside the body. |
| **`IN` parameter** | Read-only input (default if direction is omitted). |
| **`OUT` parameter** | Write-only output the caller reads from a `@user_var`. |
| **`INOUT` parameter** | Read **and** write the same `@user_var`. |
| **`DECLARE var TYPE DEFAULT …`** | Local variable scoped to `BEGIN … END`. |
| **`SET var := expr`** | Assign to a local variable or `@user_var`. |
| **`SELECT … INTO var`** | Read a single-row scalar into a variable. |
| **`IF … THEN … ELSE … END IF`** | Branch on a condition inside the body. |
| **`CALL proc(...)`** | Execute the procedure; pass `@vars` for `OUT` / `INOUT`. |
| **`DROP PROCEDURE IF EXISTS name`** | Idempotent re-create during development. |

**Security:** in production prefer **`DEFINER`** / **`SQL SECURITY INVOKER`** and least privilege. These labs use defaults for teaching.

---

## Schema touchpoints (from the dump)

- **`customers`** — `id`, `first_name`, `last_name`, `phone`, `email`
- **`work_orders`** — `id`, `vehicle_id`, `assigned_mechanic_id`, `status`, `total_cost`

Sample **`work_orders.status`** domain: `new`, `in_progress`, `waiting_parts`, `completed`, `cancelled`.

---

## Exercise 1 — `IN` parameters returning a result set

### Context

The dispatcher wants a parameterised "show me the first *N* orders in status *X*" report — same query, different filters every hour. Wrapping it in a stored procedure lets every UI button and cron job share one definition.

### What you'll learn

- Declaring a procedure with two **`IN`** parameters.
- Returning a **result set** by ending the body with a plain `SELECT`.
- Using **`DELIMITER $$`** so `;` inside `BEGIN … END` does not end the `CREATE PROCEDURE`.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `assigned_mechanic_id`, `status`, `total_cost` |

### Task

1. Define `sp_work_orders_by_status(IN p_status VARCHAR(20), IN p_limit INT)`.
2. The body returns `id, vehicle_id, assigned_mechanic_id, status, total_cost` for rows where `status = p_status` and `id BETWEEN 1 AND 100000`, ordered by `id`, limited to `p_limit`.
3. Call it with `('completed', 8)` and check the eight rows it returns.

### Expected result (real rows from `CALL sp_work_orders_by_status('completed', 8)`)

```text
+----+------------+----------------------+-----------+------------+
| id | vehicle_id | assigned_mechanic_id | status    | total_cost |
+----+------------+----------------------+-----------+------------+
|  4 |          4 |                    4 | completed |     500.40 |
|  9 |          9 |                    9 | completed |     500.90 |
| 14 |         14 |                   14 | completed |     501.40 |
| 19 |         19 |                   19 | completed |     501.90 |
| 24 |         24 |                   24 | completed |     502.40 |
| 29 |         29 |                   29 | completed |     502.90 |
| 34 |         34 |                   34 | completed |     503.40 |
| 39 |         39 |                   39 | completed |     503.90 |
+----+------------+----------------------+-----------+------------+
```

### Hint

Wrap a regular `SELECT … WHERE status = p_status … LIMIT p_limit` in `BEGIN … END` and change the delimiter to `$$` first.

### Solution

```sql
DROP PROCEDURE IF EXISTS sp_work_orders_by_status;

DELIMITER $$

CREATE PROCEDURE sp_work_orders_by_status(
  IN p_status VARCHAR(20),
  IN p_limit  INT
)
BEGIN
  SELECT id,
         vehicle_id,
         assigned_mechanic_id,
         status,
         total_cost
  FROM work_orders
  WHERE status = p_status
    AND id BETWEEN 1 AND 100000
  ORDER BY id
  LIMIT p_limit;
END$$

DELIMITER ;

CALL sp_work_orders_by_status('completed', 8);
```

### Step-by-step explanation

1. **`DROP PROCEDURE IF EXISTS`** makes the script re-runnable: without it, the second run errors with *"PROCEDURE already exists"*.
2. **`DELIMITER $$`** tells the `mysql` client to treat `$$` (not `;`) as the end of a statement, so the inner `;` inside `BEGIN … END` belongs to the procedure body.
3. **`IN p_status VARCHAR(20)`** is the default parameter direction. The caller passes a string; the body can only read it. Trying to write to an `IN` parameter does not propagate back to the caller.
4. **`BEGIN … END`** is the compound statement that becomes the procedure body. Any number of SQL or control statements can live between them.
5. **The trailing `SELECT`** without an `INTO` clause returns a **result set** to whoever called the procedure — exactly like a top-level query.
6. **`DELIMITER ;`** restores the normal terminator so subsequent statements parse normally.
7. **`CALL sp_work_orders_by_status('completed', 8)`** executes the procedure and prints the result set. Arguments bind positionally; named arguments do not exist in MySQL procedures.

---

## Exercise 2 — `OUT` parameter (aggregate into a user variable)

### Context

A monitoring dashboard polls the server every minute for "total revenue of the first 50 000 work orders" to feed a Grafana panel. Wrapping the aggregate in a procedure with an **`OUT`** parameter lets the poller call one well-named entry point instead of pasting the same `SUM` everywhere.

### What you'll learn

- Declaring an **`OUT`** parameter and writing to it.
- **`SELECT … INTO p_var`** to fold a scalar aggregate into a parameter.
- Using **`COALESCE(SUM(...), 0)`** to avoid returning `NULL` for an empty range.
- Reading the result via a session **`@user_variable`**.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Task

1. Define `sp_sum_cost_slice(OUT p_sum DECIMAL(14,2))`.
2. Body: assign `COALESCE(SUM(total_cost), 0)` over `work_orders` with `id BETWEEN 1 AND 50000` into `p_sum`.
3. Call it as `CALL sp_sum_cost_slice(@cost_sum)` and read `@cost_sum`.

### Expected result (real rows)

```text
+----------------------+
| sum_total_cost_slice |
+----------------------+
|         149997500.00 |
+----------------------+
```

### Hint

`SELECT COALESCE(SUM(col), 0) INTO p_sum FROM …` — exactly one scalar row, exactly one target variable.

### Solution

```sql
DROP PROCEDURE IF EXISTS sp_sum_cost_slice;

DELIMITER $$

CREATE PROCEDURE sp_sum_cost_slice(
  OUT p_sum DECIMAL(14,2)
)
BEGIN
  SELECT COALESCE(SUM(total_cost), 0)
  INTO p_sum
  FROM work_orders
  WHERE id BETWEEN 1 AND 50000;
END$$

DELIMITER ;

CALL sp_sum_cost_slice(@cost_sum);
SELECT @cost_sum AS sum_total_cost_slice;
```

### Step-by-step explanation

1. **`OUT p_sum DECIMAL(14,2)`** — the caller must pass a **session user variable** (`@cost_sum`) here, not a literal. After `CALL`, that variable holds the value the body wrote.
2. **`SELECT … INTO p_sum`** is the procedural form of an assignment: the query must return exactly one row and one column; otherwise MySQL raises an error.
3. **`COALESCE(SUM(total_cost), 0)`** guards against the empty-range case. `SUM` over zero rows returns `NULL`, which would silently confuse the dashboard.
4. **`CALL sp_sum_cost_slice(@cost_sum)`** — at the call site `@cost_sum` is auto-created in the session if it did not exist. `OUT` semantics mean its previous value is **ignored** by the body.
5. **`SELECT @cost_sum`** reads the variable back. `@vars` live for the whole connection, so the next `CALL` in the same session can keep using it.

---

## Exercise 3 — `IN` + `OUT` + `DECLARE` + `IF`

### Context

A customer-segmentation job asks "how many customers fall into a given id range?" It also has to be defensive: if the caller passes a malformed range (max < min), the procedure should return `0` instead of running an expensive query.

### What you'll learn

- Combining **`IN`** and **`OUT`** parameters.
- **`DECLARE v_var INT DEFAULT …`** for a local variable inside the body.
- **`IF condition THEN … ELSE … END IF`** for guarded branches.
- Why local variables (`v_span`) and parameters (`p_min_id`) live in different namespaces.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id` |

### Task

1. Define `sp_customer_count(IN p_min_id INT, IN p_max_id INT, OUT p_cnt INT)`.
2. Declare a local `v_span` = `p_max_id - p_min_id`.
3. If `v_span < 0`, assign `p_cnt := 0` and stop. Otherwise `SELECT COUNT(*) INTO p_cnt FROM customers WHERE id BETWEEN p_min_id AND p_max_id`.
4. Call twice: once with a valid range `(1, 500)` and once with a reversed range `(900, 100)`.

### Expected result (real rows)

```text
+--------------------+
| customers_in_range |
+--------------------+
|                500 |
+--------------------+
+------------------+
| bad_range_result |
+------------------+
|                0 |
+------------------+
```

### Hint

`DECLARE v_span INT DEFAULT 0;` must appear **before** any `SET` or `SELECT` in the body — all declarations come first inside a `BEGIN … END` block.

### Solution

```sql
DROP PROCEDURE IF EXISTS sp_customer_count;

DELIMITER $$

CREATE PROCEDURE sp_customer_count(
  IN  p_min_id INT,
  IN  p_max_id INT,
  OUT p_cnt    INT
)
BEGIN
  DECLARE v_span INT DEFAULT 0;
  SET v_span := p_max_id - p_min_id;
  IF v_span < 0 THEN
    SET p_cnt := 0;
  ELSE
    SELECT COUNT(*)
    INTO p_cnt
    FROM customers
    WHERE id BETWEEN p_min_id AND p_max_id;
  END IF;
END$$

DELIMITER ;

CALL sp_customer_count(1, 500, @cust_n);
SELECT @cust_n AS customers_in_range;

CALL sp_customer_count(900, 100, @bad);
SELECT @bad AS bad_range_result;
```

### Step-by-step explanation

1. **`DECLARE v_span INT DEFAULT 0`** introduces a local variable. Declarations must precede every executable statement in the block — putting them after a `SET` is a syntax error in MySQL.
2. **`SET v_span := p_max_id - p_min_id`** uses **`:=`** (assignment) — equivalent to `=` in this position, but `:=` is unambiguous and works the same inside `SELECT`.
3. **`IF v_span < 0 THEN … ELSE … END IF`** is the only branching construct. There is also `ELSEIF` for chained tests; do **not** confuse it with the `IF()` function (which is an expression).
4. **Guarded branch** sets `p_cnt := 0` — important because the alternative `SELECT … INTO p_cnt` would otherwise either return `NULL` (no rows) or, with reversed ranges, scan more rows than expected.
5. **Two calls** prove both branches: `(1, 500)` hits the `ELSE` path and returns 500; `(900, 100)` hits the `IF` guard and returns 0 without scanning the table.

---

## Exercise 4 — `INOUT` parameter (mutate a session variable)

### Context

A logging utility lets the caller pass in an existing message tag and have the procedure **append** a status token (` | proc_ok`) before passing it along to the next step. The same variable is read and written, which is exactly what `INOUT` is for.

### What you'll learn

- Declaring an **`INOUT`** parameter.
- Reading the current value of an `INOUT` and overwriting it with a new value.
- Using **`IFNULL(col, default)`** to make string concatenation `NULL`-safe.
- Persisting state across multiple `CALL`s in the same session.

### Tables in play

No tables — pure parameter manipulation.

### Task

1. Define `sp_append_tag(INOUT p_text VARCHAR(200))`.
2. Inside the body, assign `p_text := CONCAT(IFNULL(p_text, ''), ' | proc_ok')`.
3. Set `@tag := 'lab'`, then `CALL sp_append_tag(@tag)`, then call again to show that the tag grows each time.

### Expected result (real rows)

```text
+-----------------+
| tag_after_inout |
+-----------------+
| lab | proc_ok   |
+-----------------+
+-------------------------+
| tag_after_second_inout  |
+-------------------------+
| lab | proc_ok | proc_ok |
+-------------------------+
```

### Hint

`CONCAT(IFNULL(p_text, ''), ' | proc_ok')` — `IFNULL` swaps `NULL` for the empty string so the first character of the result is always defined.

### Solution

```sql
DROP PROCEDURE IF EXISTS sp_append_tag;

DELIMITER $$

CREATE PROCEDURE sp_append_tag(
  INOUT p_text VARCHAR(200)
)
BEGIN
  SET p_text := CONCAT(IFNULL(p_text, ''), ' | proc_ok');
END$$

DELIMITER ;

SET @tag := 'lab';
CALL sp_append_tag(@tag);
SELECT @tag AS tag_after_inout;

CALL sp_append_tag(@tag);
SELECT @tag AS tag_after_second_inout;
```

### Step-by-step explanation

1. **`INOUT`** is "pass by reference": the caller must supply a `@user_variable` (literals are rejected), the body sees its current value **and** can overwrite it.
2. **`CONCAT(IFNULL(p_text, ''), ' | proc_ok')`** — without `IFNULL`, a `NULL` input would propagate through `CONCAT` and the whole result would become `NULL`. Always normalise nullable strings before concatenation.
3. **`SET @tag := 'lab'`** initialises the session variable. After the first `CALL`, the variable becomes `'lab | proc_ok'`; the second `CALL` reads that new value and appends again — producing `'lab | proc_ok | proc_ok'`. This is what "in **and** out" really means.
4. **Common mistake:** passing a literal — `CALL sp_append_tag('lab')` errors with *"OUT or INOUT argument is not a variable"*. Stored procedures cannot write back to an immutable literal.

---

## Troubleshooting: my procedure won't load

| Symptom | Likely fix |
|---|---|
| Syntax error on the first `;` inside `BEGIN … END` | You forgot **`DELIMITER $$`** before `CREATE PROCEDURE`. |
| `PROCEDURE … already exists` on re-run | Add **`DROP PROCEDURE IF EXISTS name;`** before the `CREATE`. |
| `OUT or INOUT argument is not a variable` | Pass a `@user_var` (e.g. `@sum`), not a literal. |
| `@var` is `NULL` after `CALL` | Procedure raised an error before writing — check `SHOW WARNINGS;`. |
| `Variable 'foo' must be declared` inside `BEGIN…END` | Declarations must come **before** any executable statement in the block. |
| Loading via GUI tool fails on `DELIMITER` | Some GUIs ignore `DELIMITER` — load via the `mysql` CLI. |

If you want to run **all** examples at once: `mysql -t -u root car_service_db < 03_mysql/14_procedures/car_service_procedures_examples.sql`.
