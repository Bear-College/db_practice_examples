# Cycles (loops) — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/15_cycles/cycles_car_service_db.md)

"Cycles" here means **repeated execution** in MySQL in two complementary ways:

1. **Procedural loops** inside `CREATE PROCEDURE` — `WHILE`, `REPEAT … UNTIL`, and labelled `LOOP … LEAVE` (MySQL stored programs).
2. **Recursive CTE** — `WITH RECURSIVE` (MySQL **8.0+**) for set-oriented "iteration" (number series, trees) that runs as one declarative query, not as a loop.

The exercises also cover a **cursor loop**, which is the canonical way a procedure walks through a result set row-by-row.

Runnable companion file: [`15_cycles/car_service_cycles_examples.sql`](car_service_cycles_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/15_cycles/car_service_cycles_examples.sql
```

Use the **`mysql`** client (not a GUI) so **`DELIMITER $$`** works when the file is `SOURCE`d.

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real shop would write this procedure (1-2 sentences). |
| **What you'll learn** | Loop constructs trained in this exact exercise. |
| **Tables in play** | Only the columns the procedure actually touches. |
| **Task** | Concrete requirements (signature, body, how to call). |
| **Expected result** | Real output from a live `CALL` (copied from a live run). |
| **Hint** | A single nudge toward the right keyword/clause. |
| **Solution** | Working SQL you can paste into `mysql`. |
| **Step-by-step explanation** | What each line does and the typical mistakes. |

---

## Map: loop constructs (matches the course sheet)

| Construct | When it stops | Notes |
|-----------|---------------|-------|
| **`WHILE cond DO … END WHILE`** | Condition checked **at the top**. May execute zero times. | Classic pre-test loop. |
| **`REPEAT … UNTIL cond END REPEAT`** | Condition checked **at the bottom**. Body always runs at least once. | Post-test loop. |
| **`label: LOOP … END LOOP label`** | Only by **`LEAVE label`** (break) — otherwise infinite. **`ITERATE label`** restarts from the top. | Most flexible; requires an explicit exit. |
| **`DECLARE cur CURSOR FOR …` + `FETCH` + `LEAVE`** | When the cursor signals `NOT FOUND` via a continue handler. | The way procedural code walks rows. |
| **`WITH RECURSIVE name AS (anchor UNION ALL rec)`** | When the recursive part returns zero new rows. | Declarative; **MySQL 8.0+** only. |

Prefer **set-based** SQL when possible; loops are for procedural logic, small batches, or teaching.

The session variable **`cte_max_recursion_depth`** caps recursive CTE iterations (default 1000). Raise it explicitly when you genuinely need more.

---

## The shared lab table

All four procedural exercises write to a tiny audit table created by the script:

```sql
CREATE TABLE cyc_log (
  id        INT NOT NULL AUTO_INCREMENT,
  kind      VARCHAR(20) NOT NULL,
  iteration INT NOT NULL,
  detail    VARCHAR(120) DEFAULT NULL,
  ts        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);
```

`TRUNCATE TABLE cyc_log;` before each demo resets the `AUTO_INCREMENT` so the captured outputs start at `id = 1`.

---

## Exercise 1 — `WHILE … END WHILE` (pre-test loop)

### Context

A nightly job needs to insert exactly *N* placeholder audit rows ("step 1", "step 2", …) before the real maintenance script runs. A `WHILE` loop is the natural fit: zero-or-more iterations, controlled by a parameter passed from the scheduler.

### What you'll learn

- The shape of a **pre-test loop**: `WHILE condition DO … END WHILE`.
- Combining `DECLARE` + `SET` + `INSERT` inside a procedure body.
- Why a `WHILE` may execute **zero** times (condition false on first check).

### Tables in play

| Table | Columns |
|---|---|
| `cyc_log` | `id`, `kind`, `iteration`, `detail` |

### Task

1. Define `sp_cyc_while_demo(IN p_times INT)`.
2. Declare a local counter `i` initialised to `0`.
3. While `i < p_times`, increment `i` and `INSERT INTO cyc_log (kind, iteration, detail) VALUES ('WHILE', i, CONCAT('step ', i))`.
4. Call it with `p_times = 4` and verify 4 rows landed in `cyc_log`.

### Expected result (`TRUNCATE cyc_log; CALL sp_cyc_while_demo(4);` then `SELECT * FROM cyc_log`)

```text
+----+-------+-----------+--------+
| id | kind  | iteration | detail |
+----+-------+-----------+--------+
|  1 | WHILE |         1 | step 1 |
|  2 | WHILE |         2 | step 2 |
|  3 | WHILE |         3 | step 3 |
|  4 | WHILE |         4 | step 4 |
+----+-------+-----------+--------+
```

### Hint

`WHILE i < p_times DO ... END WHILE;` — increment **inside** the body, otherwise it loops forever.

### Solution

```sql
DROP PROCEDURE IF EXISTS sp_cyc_while_demo;

DELIMITER $$

CREATE PROCEDURE sp_cyc_while_demo(IN p_times INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  WHILE i < p_times DO
    SET i = i + 1;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('WHILE', i, CONCAT('step ', i));
  END WHILE;
END$$

DELIMITER ;

TRUNCATE TABLE cyc_log;
CALL sp_cyc_while_demo(4);
SELECT id, kind, iteration, detail FROM cyc_log ORDER BY id;
```

### Step-by-step explanation

1. **`DECLARE i INT DEFAULT 0`** introduces the loop counter. All declarations must come at the top of `BEGIN … END`.
2. **`WHILE i < p_times DO`** evaluates the condition **before** every iteration. If `p_times = 0`, the body never runs.
3. **`SET i = i + 1`** is the indispensable increment — forgetting it is the #1 way to lock the connection up. Put the increment **first** when your `id`/iteration is `1`-based, **last** when it's `0`-based.
4. **`INSERT … VALUES ('WHILE', i, …)`** writes one audit row per iteration. The same connection can read those rows immediately afterwards.
5. **`END WHILE`** closes the loop. There is no `BREAK` keyword inside `WHILE`; if you need an early exit, wrap the loop in a labelled `LOOP` and use `LEAVE` (Exercise 3).

---

## Exercise 2 — `REPEAT … UNTIL` (post-test loop)

### Context

A maintenance job has to perform an action at least once and **then** decide whether to keep going. `REPEAT … UNTIL` matches that exactly: the body runs first, the exit condition is evaluated after.

### What you'll learn

- The shape of a **post-test loop**: `REPEAT … UNTIL cond END REPEAT`.
- Why the body of `REPEAT` always runs at least once.
- The inverted semantics of `UNTIL` versus `WHILE` (stops when condition is **true**).

### Tables in play

| Table | Columns |
|---|---|
| `cyc_log` | `id`, `kind`, `iteration`, `detail` |

### Task

1. Define `sp_cyc_repeat_demo()` (no parameters).
2. Declare counter `j` initialised to `0`.
3. In a `REPEAT` loop: increment `j`, insert a row `('REPEAT', j, 'repeat step j')`. Exit when `j >= 3`.
4. Verify three rows are inserted.

### Expected result (`TRUNCATE cyc_log; CALL sp_cyc_repeat_demo();`)

```text
+----+--------+-----------+---------------+
| id | kind   | iteration | detail        |
+----+--------+-----------+---------------+
|  1 | REPEAT |         1 | repeat step 1 |
|  2 | REPEAT |         2 | repeat step 2 |
|  3 | REPEAT |         3 | repeat step 3 |
+----+--------+-----------+---------------+
```

### Hint

`UNTIL j >= 3` — the loop **stops** when the condition is true, the opposite of `WHILE`.

### Solution

```sql
DROP PROCEDURE IF EXISTS sp_cyc_repeat_demo;

DELIMITER $$

CREATE PROCEDURE sp_cyc_repeat_demo()
BEGIN
  DECLARE j INT DEFAULT 0;
  REPEAT
    SET j = j + 1;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('REPEAT', j, CONCAT('repeat step ', j));
  UNTIL j >= 3
  END REPEAT;
END$$

DELIMITER ;

TRUNCATE TABLE cyc_log;
CALL sp_cyc_repeat_demo();
SELECT id, kind, iteration, detail FROM cyc_log ORDER BY id;
```

### Step-by-step explanation

1. **`REPEAT … UNTIL … END REPEAT`** is the dual of `WHILE`. The body executes, **then** `UNTIL` is checked. If `UNTIL` is `TRUE`, the loop exits.
2. **At-least-once guarantee.** Even if the exit condition is already satisfied (e.g. counter starts at `99`), the body runs **once** before the check. Useful when you must run an action and then decide whether to repeat.
3. **`UNTIL j >= 3`** has no semicolon between `UNTIL` and `END REPEAT` — this is a frequent typo. The grammar is exactly `UNTIL cond END REPEAT`.
4. **Three rows** end up in `cyc_log` because the body ran at `j = 1, 2, 3`; at `j = 3` the post-check fires and the loop ends.
5. **Watch out:** if you forget `SET j = j + 1`, `UNTIL j >= 3` never becomes true and the loop runs forever. The same hygiene as for `WHILE` applies.

---

## Exercise 3 — `LOOP` + `LEAVE` (labelled break)

### Context

Sometimes the exit condition is not a clean "while" or "until" check at the top or bottom — it lives in the middle of the body. The combination **labelled `LOOP` + `LEAVE label`** gives you a structured `break`: the loop is unconditional, an explicit `LEAVE` is the only way out.

### What you'll learn

- **Labelled** `LOOP … END LOOP label` syntax.
- Using **`LEAVE label`** as a structured `break`.
- (Optionally) **`ITERATE label`** to restart the loop body (skip-to-next).

### Tables in play

| Table | Columns |
|---|---|
| `cyc_log` | `id`, `kind`, `iteration`, `detail` |

### Task

1. Define `sp_cyc_loop_leave_demo()`.
2. Declare counter `k` initialised to `0`.
3. Inside `cyc_loop: LOOP`, increment `k`. If `k > 4`, `LEAVE cyc_loop`. Otherwise insert `('LOOP', k, 'loop step k')`.
4. Verify four `LOOP` rows landed in `cyc_log`.

### Expected result (`TRUNCATE cyc_log; CALL sp_cyc_loop_leave_demo();`)

```text
+----+------+-----------+-------------+
| id | kind | iteration | detail      |
+----+------+-----------+-------------+
|  1 | LOOP |         1 | loop step 1 |
|  2 | LOOP |         2 | loop step 2 |
|  3 | LOOP |         3 | loop step 3 |
|  4 | LOOP |         4 | loop step 4 |
+----+------+-----------+-------------+
```

### Hint

Increment first, exit-test second, insert last — so `k = 5` never reaches the `INSERT`.

### Solution

```sql
DROP PROCEDURE IF EXISTS sp_cyc_loop_leave_demo;

DELIMITER $$

CREATE PROCEDURE sp_cyc_loop_leave_demo()
BEGIN
  DECLARE k INT DEFAULT 0;
  cyc_loop: LOOP
    SET k = k + 1;
    IF k > 4 THEN
      LEAVE cyc_loop;
    END IF;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('LOOP', k, CONCAT('loop step ', k));
  END LOOP cyc_loop;
END$$

DELIMITER ;

TRUNCATE TABLE cyc_log;
CALL sp_cyc_loop_leave_demo();
SELECT id, kind, iteration, detail FROM cyc_log ORDER BY id;
```

### Step-by-step explanation

1. **`cyc_loop:`** is a label. Names follow identifier rules; `cyc_loop` and `END LOOP cyc_loop` must match exactly (case-sensitive depending on the collation, but matching them keeps you safe).
2. **`LOOP … END LOOP`** is the only one of the three constructs that has **no built-in exit condition.** You must use `LEAVE` (or raise an error) — otherwise the loop runs forever.
3. **`IF k > 4 THEN LEAVE cyc_loop; END IF;`** is the structured break. Without the label argument, `LEAVE` would not know which loop to exit (you can nest loops).
4. **`ITERATE cyc_loop`** (not used here but worth knowing) jumps back to the top of the labelled loop, skipping the rest of the current iteration — that's `continue` in C-like languages.
5. **Insertion order matters.** The increment happens before the test, the test before the insert — so only iterations `k = 1..4` are persisted; iteration `k = 5` is the exit iteration.

---

## Exercise 4 — Cursor loop over a result set

### Context

The most common procedural pattern in MySQL: a stored procedure must walk through a result set row-by-row (to call a function, log each row, or push data into another table). MySQL implements this with **`DECLARE CURSOR`**, **`OPEN` / `FETCH` / `CLOSE`**, and a **`CONTINUE HANDLER FOR NOT FOUND`** that flips a flag when the cursor runs out of rows.

### What you'll learn

- Declaring a cursor over a bounded query.
- The mandatory **`CONTINUE HANDLER FOR NOT FOUND SET done = 1;`** pattern.
- `OPEN cur → FETCH cur INTO … → LEAVE` skeleton.
- Why declaration order matters: variables → cursor → handler.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `total_cost` |
| `cyc_log` | `id`, `kind`, `iteration`, `detail` |

### Task

1. Define `sp_cyc_cursor_wo()` (no parameters).
2. Declare locals `done INT DEFAULT 0`, `v_id INT`, `v_cost DECIMAL(12,2)`.
3. Declare a cursor `cur` over `SELECT id, total_cost FROM work_orders WHERE id BETWEEN 1 AND 30 ORDER BY id LIMIT 5`.
4. Declare a `CONTINUE HANDLER FOR NOT FOUND SET done = 1;`.
5. `OPEN cur`, then in a labelled loop `FETCH cur INTO v_id, v_cost`. If `done = 1`, `LEAVE`. Otherwise insert `('CURSOR', v_id, CONCAT('total_cost=', v_cost))`. Close the cursor.

### Expected result (`TRUNCATE cyc_log; CALL sp_cyc_cursor_wo();`)

```text
+----+--------+-----------+-------------------+
| id | kind   | iteration | detail            |
+----+--------+-----------+-------------------+
|  1 | CURSOR |         1 | total_cost=500.10 |
|  2 | CURSOR |         2 | total_cost=500.20 |
|  3 | CURSOR |         3 | total_cost=500.30 |
|  4 | CURSOR |         4 | total_cost=500.40 |
|  5 | CURSOR |         5 | total_cost=500.50 |
+----+--------+-----------+-------------------+
```

### Hint

Declare in this exact order: variables → cursor → handler. Reverse the order and MySQL rejects the procedure.

### Solution

```sql
DROP PROCEDURE IF EXISTS sp_cyc_cursor_wo;

DELIMITER $$

CREATE PROCEDURE sp_cyc_cursor_wo()
BEGIN
  DECLARE done   INT DEFAULT 0;
  DECLARE v_id   INT;
  DECLARE v_cost DECIMAL(12,2);
  DECLARE cur CURSOR FOR
    SELECT id, total_cost
    FROM work_orders
    WHERE id BETWEEN 1 AND 30
    ORDER BY id
    LIMIT 5;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  read_rows: LOOP
    FETCH cur INTO v_id, v_cost;
    IF done = 1 THEN
      LEAVE read_rows;
    END IF;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('CURSOR', v_id, CONCAT('total_cost=', v_cost));
  END LOOP read_rows;
  CLOSE cur;
END$$

DELIMITER ;

TRUNCATE TABLE cyc_log;
CALL sp_cyc_cursor_wo();
SELECT id, kind, iteration, detail FROM cyc_log ORDER BY id;
```

### Step-by-step explanation

1. **Declaration order is fixed by the grammar:** local variables first, then cursors, then handlers, then any executable statement. Swap them and you get *"Variable declaration must precede cursor declaration"*.
2. **`DECLARE cur CURSOR FOR <SELECT …>`** binds the cursor to a specific query; the query is not executed until `OPEN cur`.
3. **`DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;`** is the magic line. When a `FETCH` runs out of rows, MySQL raises the `NOT FOUND` condition; the handler intercepts it, sets `done = 1`, and lets execution continue (instead of aborting the procedure).
4. **`OPEN cur` / `FETCH cur INTO v_id, v_cost`** — `FETCH` copies the next row into the named variables. If there is no next row, the handler fires and `done` becomes `1`.
5. **`IF done = 1 THEN LEAVE read_rows; END IF;`** — note: check the flag **immediately after** `FETCH`, before doing any work on the values. Otherwise the last iteration uses stale variable contents.
6. **`CLOSE cur`** releases the cursor. Strictly speaking, MySQL closes it automatically when the procedure ends, but explicit `CLOSE` is good hygiene.

---

## Exercise 5 — `WITH RECURSIVE` (CTE, MySQL 8.0+)

### Context

You need a number series `1..N` to drive a chart, generate test data, or join against another table for "fill-gaps" semantics. Instead of looping in a procedure, MySQL 8.0 lets you express the iteration **declaratively** with a recursive CTE — a single query the planner can optimise.

### What you'll learn

- The shape of a recursive CTE: **anchor `UNION ALL` recursive part**.
- Why the recursive part must reference the CTE name to "recurse".
- The role of `cte_max_recursion_depth` as a safety brake.

### Tables in play

None — this CTE generates rows out of nothing.

### Task

Write a single statement (no procedure needed) that produces `n = 1..12`. Use a recursive CTE named `seq(n)`.

### Expected result

```text
+------+
| n    |
+------+
|    1 |
|    2 |
|    3 |
|    4 |
|    5 |
|    6 |
|    7 |
|    8 |
|    9 |
|   10 |
|   11 |
|   12 |
+------+
```

### Hint

`WITH RECURSIVE seq(n) AS ( SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 12 ) SELECT n FROM seq;`

### Solution

```sql
WITH RECURSIVE seq(n) AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 12
)
SELECT n FROM seq;
```

### Step-by-step explanation

1. **`WITH RECURSIVE name(col_list) AS ( … )`** introduces a named, possibly self-referential subquery. Without the `RECURSIVE` keyword, MySQL would reject the self-reference.
2. **Anchor:** `SELECT 1 AS n` produces the first row. The anchor must terminate (no recursive reference) — it is the base case.
3. **Recursive part:** `SELECT n + 1 FROM seq WHERE n < 12` reads from `seq` (so far) and emits the next row. The `WHERE n < 12` is the **termination condition**: when it returns zero rows, recursion stops.
4. **`UNION ALL` is required.** `UNION` (which de-duplicates) is forbidden in recursive CTEs in MySQL.
5. **Safety net:** the session variable `cte_max_recursion_depth` (default 1000) caps how many recursion steps MySQL will allow. If you need more, raise it explicitly with `SET SESSION cte_max_recursion_depth = 10000;`.
6. **Why prefer this over a procedural loop?** It's a single SQL statement: the optimiser sees the whole thing, no client round-trips per row, no `cyc_log` side-table — and it composes inside any other query.

---

## Troubleshooting: my loop never finishes (or never runs)

| Symptom | Likely fix |
|---|---|
| Connection hangs after `CALL` | Forgot the counter increment inside `WHILE` / `REPEAT` / `LOOP`. Kill the session and add `SET i = i + 1;`. |
| `WHILE` body never executes | Initial condition is already false (e.g. `p_times = 0`). Use `REPEAT` if you need at-least-once. |
| `Variable declaration must precede cursor declaration` | Reorder declarations: variables → cursor → handler. |
| Last row processed twice (cursor) | You're checking `done` **before** `FETCH` instead of immediately after. |
| `Cursor is not open` on `FETCH` | Missing `OPEN cur;` before the `FETCH`, or the handler swallowed an error during `OPEN`. |
| `Recursive CTE: max recursion …` | Hit `cte_max_recursion_depth`. Tighten the termination condition or `SET SESSION cte_max_recursion_depth = N;`. |
| `UNION` is forbidden in recursive CTE | Replace with `UNION ALL`. |

If you want to run **all** examples at once: `mysql -t -u root car_service_db < 03_mysql/15_cycles/car_service_cycles_examples.sql`.
