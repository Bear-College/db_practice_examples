# DML (Data Manipulation Language) — `car_service_db` theme

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/03_dml/dml_car_service_db.md)

These exercises rehearse every row-shaping command — `INSERT`, `UPDATE`, `DELETE`, `REPLACE`, upserts, and transactions — on a **safe sandbox** called `dml_practice`. The demo tables (`dml_demo_*`) mirror the shape of the real `customers`, `work_orders` and `loyalty_cards` from `01_database_mysql/car_service_db.sql.gz`, but live in a separate database so you **never modify** the production dump.

Companion script: [`03_dml/car_service_dml_examples.sql`](car_service_dml_examples.sql).

```bash
mysql -u root < 03_mysql/03_dml/car_service_dml_examples.sql
```

The script is **idempotent**: re-running it drops and recreates the demo tables, reseeds them, and walks through every exercise from a fresh state.

---

## DML command map (MySQL 8 / 9)

| Statement | Role |
|---|---|
| `INSERT` | Add new rows (single, multi-row, `INSERT … SELECT`) |
| `UPDATE` | Change existing rows (always constrain with `WHERE` in real use) |
| `DELETE` | Remove rows (`WHERE`; avoid accidental full-table delete) |
| `REPLACE` | MySQL-specific delete+insert on primary/unique key conflict |
| `INSERT … ON DUPLICATE KEY UPDATE` | "Upsert": insert or update on duplicate unique key |
| `START TRANSACTION` / `COMMIT` / `ROLLBACK` | Group DML so all succeed or none apply |

**Usually not DML:** `SELECT` is sometimes classified as DQL; `TRUNCATE` is often grouped with DDL because it requires the `DROP` privilege.

---

## Schema touchpoints (from the real dump)

Ideas mirrored in the demo tables:

- **`customers`** — names, `email`, phone-style uniqueness (here: `email` carries the `UNIQUE`).
- **`work_orders`** — `status` (`new`, `in_progress`, `completed`, `waiting_parts`, `cancelled`), `total_cost` as `DECIMAL(12,2)`.
- **`loyalty_cards`** — `points`. We fold a simple `points` column into demo customers for `UPDATE` and upsert labs.

After exercise 1 runs, the seeded sandbox looks like this — every later exercise mutates it:

```text
+----+------------+-----------+-------------------------+--------+
| id | first_name | last_name | email                   | points |
+----+------------+-----------+-------------------------+--------+
|  1 | Ada        | Morgan    | ada.morgan@example.com  |    100 |
|  2 | Ben        | Ortega    | ben.ortega@example.com  |     50 |
|  3 | Cara       | Nguyen    | cara.nguyen@example.com |      0 |
+----+------------+-----------+-------------------------+--------+

+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | new           |     120.00 |
|  2 |           1 | completed     |     450.75 |
|  3 |           2 | in_progress   |     200.00 |
|  4 |           2 | cancelled     |       0.00 |
|  5 |           3 | waiting_parts |     300.25 |
+----+-------------+---------------+------------+
```

---

## Exercise 1 — Sandbox setup

### Context

Before practising any DML you need an isolated playground that won't ruin the real `car_service_db`. We build a tiny three-table model and seed it with rows that subsequent exercises will mutate.

### What you'll learn

- The split between **minimal DDL** (to host the lab) and the **DML** you actually practise.
- `UNIQUE KEY uk_dml_demo_customers_email (email)` — the unique constraint that makes upsert in Exercise 8 possible.
- A foreign key with `ON DELETE RESTRICT` to prevent dangling work orders.

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_customers` | `id`, `first_name`, `last_name`, `email` (`UNIQUE`), `points` |
| `dml_demo_work_orders` | `id`, `customer_id` (FK), `status`, `total_cost` |
| `dml_demo_customer_staging` | `id`, `first_name`, `last_name`, `email`, `points`, `snapshot_at` |

### Task

Create the sandbox database, the three demo tables, and seed customers 1–3 plus work orders 1–5.

### Expected result (after the seed)

```text
+----+------------+-----------+-------------------------+--------+
| id | first_name | last_name | email                   | points |
+----+------------+-----------+-------------------------+--------+
|  1 | Ada        | Morgan    | ada.morgan@example.com  |    100 |
|  2 | Ben        | Ortega    | ben.ortega@example.com  |     50 |
|  3 | Cara       | Nguyen    | cara.nguyen@example.com |      0 |
+----+------------+-----------+-------------------------+--------+
```

### Hint

`CREATE DATABASE … utf8mb4`, then `CREATE TABLE … UNIQUE KEY … (email)`, then a few `INSERT … VALUES …`.

### Solution

```sql
CREATE DATABASE IF NOT EXISTS dml_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE dml_practice;

SET foreign_key_checks = 0;
DROP TABLE IF EXISTS dml_demo_work_orders;
DROP TABLE IF EXISTS dml_demo_customer_staging;
DROP TABLE IF EXISTS dml_demo_customers;
SET foreign_key_checks = 1;

CREATE TABLE dml_demo_customers (
  id            INT NOT NULL AUTO_INCREMENT,
  first_name    VARCHAR(50) NOT NULL,
  last_name     VARCHAR(50) NOT NULL,
  email         VARCHAR(100) NOT NULL,
  points        INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_dml_demo_customers_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE dml_demo_work_orders (
  id            INT NOT NULL AUTO_INCREMENT,
  customer_id   INT NOT NULL,
  status        VARCHAR(20) NOT NULL,
  total_cost    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (id),
  KEY idx_dml_wo_customer (customer_id),
  CONSTRAINT fk_dml_wo_customer
    FOREIGN KEY (customer_id) REFERENCES dml_demo_customers (id)
      ON UPDATE CASCADE
      ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE dml_demo_customer_staging (
  id            INT NOT NULL AUTO_INCREMENT,
  first_name    VARCHAR(50) NOT NULL,
  last_name     VARCHAR(50) NOT NULL,
  email         VARCHAR(100) NOT NULL,
  points        INT NOT NULL DEFAULT 0,
  snapshot_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO dml_demo_customers (first_name, last_name, email, points) VALUES
  ('Ada', 'Morgan', 'ada.morgan@example.com', 100),
  ('Ben', 'Ortega', 'ben.ortega@example.com', 50),
  ('Cara', 'Nguyen', 'cara.nguyen@example.com', 0);

INSERT INTO dml_demo_work_orders (customer_id, status, total_cost) VALUES
  (1, 'new', 120.00),
  (1, 'completed', 450.75),
  (2, 'in_progress', 200.00),
  (2, 'cancelled', 0.00),
  (3, 'waiting_parts', 300.25);
```

### Step-by-step explanation

1. **`SET foreign_key_checks = 0`** lets the script drop child and parent in any order. Always restore it to `1` immediately after.
2. **`UNIQUE KEY (email)`** is critical: it makes Exercise 8's upsert work and Exercise 9's `REPLACE` semantics meaningful.
3. **`fk_dml_wo_customer ON DELETE RESTRICT`** means you can't delete a customer who still owns a work order — the safer default for a service shop.
4. **Seed sizes are tiny** (3 customers, 5 work orders) so every later mutation is easy to read by eye.

---

## Exercise 2 — `INSERT` single row

### Context

The front-desk app opens a new customer record while the person is standing at the counter. Exactly one row is going in.

### What you'll learn

- The explicit-column `INSERT INTO t (a, b, c) VALUES (…)` form — the safe one for production.
- Why omitting the column list is fragile.
- How `LAST_INSERT_ID()` returns the new auto-increment id.

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_customers` | `first_name`, `last_name`, `email`, `points` |

### Task

Insert a single customer (Dmitri Volkov, 25 points) into `dml_demo_customers`.

### Expected result (newly added row, `id = 4`)

```text
+----+------------+-----------+---------------------------+--------+
| id | first_name | last_name | email                     | points |
+----+------------+-----------+---------------------------+--------+
|  4 | Dmitri     | Volkov    | dmitri.volkov@example.com |     25 |
+----+------------+-----------+---------------------------+--------+
```

### Hint

`INSERT INTO dml_demo_customers (first_name, last_name, email, points) VALUES (…);` — `id` is filled by `AUTO_INCREMENT`.

### Solution

```sql
INSERT INTO dml_demo_customers (first_name, last_name, email, points)
VALUES ('Dmitri', 'Volkov', 'dmitri.volkov@example.com', 25);
```

### Step-by-step explanation

1. **List the columns explicitly.** That insulates the statement from later schema changes — adding a nullable column later won't break the existing `INSERT`.
2. **Auto-increment** is invisible: you don't pass `id`, MySQL allocates the next value (here `4`) and remembers it in `LAST_INSERT_ID()`.
3. **Default-filled columns** (none here) would be picked up automatically — you only have to enumerate the ones you set.
4. **Single-row `INSERT` is implicit transaction.** A failure (duplicate email, FK violation) rolls the row back; no half-row.

---

## Exercise 3 — `INSERT` multiple rows

### Context

A batch import script loads two new customers at once and queues an opening work order for one of them — typical of a CRM import or a CSV upload.

### What you'll learn

- The multi-row `VALUES (…), (…)` form (one round-trip, one autoincrement burst).
- `INSERT … SELECT` to derive `customer_id` from another `SELECT` without hard-coding.

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_customers` | (gets 2 new rows) |
| `dml_demo_work_orders` | (gets 1 new row for Elena) |

### Task

Add Elena and Felix to customers; then add a `new`-status work order for Elena via `INSERT … SELECT`.

### Expected result (`dml_demo_work_orders` after the two inserts — row 6 is the new one)

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | new           |     120.00 |
|  2 |           1 | completed     |     450.75 |
|  3 |           2 | in_progress   |     200.00 |
|  4 |           2 | cancelled     |       0.00 |
|  5 |           3 | waiting_parts |     300.25 |
|  6 |           5 | new           |      40.00 |
+----+-------------+---------------+------------+
```

### Hint

For the customers: `INSERT INTO t (…) VALUES (…), (…);`. For the work order: `INSERT INTO t (…) SELECT … FROM customers WHERE email = '…';`.

### Solution

```sql
INSERT INTO dml_demo_customers (first_name, last_name, email, points) VALUES
  ('Elena', 'Park', 'elena.park@example.com', 10),
  ('Felix', 'Brown', 'felix.brown@example.com', 10);

INSERT INTO dml_demo_work_orders (customer_id, status, total_cost)
SELECT id, 'new', 40.00
FROM dml_demo_customers
WHERE email = 'elena.park@example.com'
LIMIT 1;
```

### Step-by-step explanation

1. **Multi-row `VALUES`** is **much** faster than running two `INSERT`s — one parse, one network round-trip, one log entry.
2. **`INSERT … SELECT`** is the ETL workhorse. Here we pull Elena's freshly allocated `id` without ever knowing the number — robust against rerun.
3. **`LIMIT 1`** in the `SELECT` is paranoia: `email` is already unique, so at most one row would match anyway. But explicit > implicit.

---

## Exercise 4 — `UPDATE` with `WHERE`

### Context

Cara just referred a friend; the loyalty program credits 50 points. We need to bump exactly Cara's row.

### What you'll learn

- `UPDATE … SET col = col + n` — relative update without first reading the value.
- Why **every** `UPDATE` in production must have a `WHERE`.

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_customers` | `points` |

### Task

Increase Cara's points by 50, identified by email.

### Expected result (Cara's row before vs after)

```text
+----+------------+-----------+-------------------------+--------+
| id | first_name | last_name | email                   | points |
+----+------------+-----------+-------------------------+--------+
|  3 | Cara       | Nguyen    | cara.nguyen@example.com |     50 |
+----+------------+-----------+-------------------------+--------+
```

(Before: `0`; after the `+50` update: `50`.)

### Hint

`UPDATE dml_demo_customers SET points = points + 50 WHERE email = '…';`

### Solution

```sql
UPDATE dml_demo_customers
SET points = points + 50
WHERE email = 'cara.nguyen@example.com';
```

### Step-by-step explanation

1. **Relative arithmetic in `SET`** (`points = points + 50`) avoids the read-modify-write race condition that happens when the application reads the value first.
2. **`WHERE email = …`** identifies a single row because `email` is `UNIQUE`. Without `WHERE` you would have credited **every** customer 50 points.
3. **Use safe-update mode** (`SET SQL_SAFE_UPDATES = 1;`) in the MySQL client — it refuses `UPDATE`/`DELETE` without a key-based `WHERE`. Cheap insurance.

---

## Exercise 5 — `UPDATE` several columns

### Context

Work order #3 is finished — the mechanic enters the final cost and changes the status from `in_progress` to `completed`. Two columns, one statement.

### What you'll learn

- The `SET col1 = v1, col2 = v2` multi-column form.
- Adding a **safety predicate** (`AND customer_id = 2`) so a typo in the id doesn't update somebody else's order.

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_work_orders` | `status`, `total_cost` |

### Task

Set `status='completed'` and `total_cost=199.99` for the row with `id=3` and `customer_id=2`.

### Expected result

```text
+----+-------------+-----------+------------+
| id | customer_id | status    | total_cost |
+----+-------------+-----------+------------+
|  3 |           2 | completed |     199.99 |
+----+-------------+-----------+------------+
```

### Hint

Comma-separated assignment list; compound `WHERE id = 3 AND customer_id = 2`.

### Solution

```sql
UPDATE dml_demo_work_orders
SET status = 'completed',
    total_cost = 199.99
WHERE id = 3 AND customer_id = 2;
```

### Step-by-step explanation

1. **Comma-separated `SET` clauses** are evaluated **before** the row is written, so you can refer to old values on the right side of any assignment without surprise.
2. **Defensive `AND customer_id = 2`.** If you typed `id = 33` by mistake, the customer mismatch would protect you — no row updated, no harm done.
3. **`DECIMAL` literals don't need quotes.** Writing `total_cost = '199.99'` works but invites the parser to do an implicit cast.

---

## Exercise 6 — `DELETE` with `WHERE`

### Context

Cancelled work orders clutter the cashier's dashboard. We sweep them out every night.

### What you'll learn

- `DELETE FROM t WHERE …`.
- Why **always** include a `WHERE` (and how to verify the row count first with `SELECT COUNT(*)`).

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_work_orders` | `status` |

### Task

Delete every work order with `status = 'cancelled'`.

### Expected result (after delete — order with `id=4` is gone)

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | new           |     120.00 |
|  2 |           1 | completed     |     450.75 |
|  3 |           2 | completed     |     199.99 |
|  5 |           3 | waiting_parts |     300.25 |
|  6 |           5 | new           |      40.00 |
+----+-------------+---------------+------------+
```

### Hint

`DELETE FROM dml_demo_work_orders WHERE status = 'cancelled';`

### Solution

```sql
DELETE FROM dml_demo_work_orders
WHERE status = 'cancelled';
```

### Step-by-step explanation

1. **Verify first.** Before `DELETE`, run `SELECT COUNT(*) FROM dml_demo_work_orders WHERE status = 'cancelled';` to see how many rows you're about to remove.
2. **Auto-increment ids are not reused.** `id = 4` is gone; the next `INSERT` will use `7`, not `4`.
3. **`DELETE` is logged row-by-row** — `TRUNCATE` is faster for "wipe everything" but cannot be filtered.

---

## Exercise 7 — `INSERT … SELECT`

### Context

A weekly job copies "high-value" customers (≥ 50 points) into a staging table so analytics can churn over them without locking the live `customers` table.

### What you'll learn

- The full ETL pattern: read from one table, write to another, with a `WHERE` predicate.
- That target and source columns are matched **positionally**, not by name.

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_customers` (source) | `first_name`, `last_name`, `email`, `points` |
| `dml_demo_customer_staging` (target) | `first_name`, `last_name`, `email`, `points` (+ auto `snapshot_at`) |

### Task

Copy every customer with `points >= 50` into `dml_demo_customer_staging`.

### Expected result (staging after the copy)

```text
+----+------------+-----------+-------------------------+--------+---------------------+
| id | first_name | last_name | email                   | points | snapshot_at         |
+----+------------+-----------+-------------------------+--------+---------------------+
|  1 | Ada        | Morgan    | ada.morgan@example.com  |    100 | 2026-05-11 16:58:03 |
|  2 | Ben        | Ortega    | ben.ortega@example.com  |     50 | 2026-05-11 16:58:03 |
|  3 | Cara       | Nguyen    | cara.nguyen@example.com |     50 | 2026-05-11 16:58:03 |
+----+------------+-----------+-------------------------+--------+---------------------+
```

### Hint

`INSERT INTO target (cols) SELECT cols FROM source WHERE …;`. `snapshot_at` is filled by its `DEFAULT CURRENT_TIMESTAMP`.

### Solution

```sql
INSERT INTO dml_demo_customer_staging (first_name, last_name, email, points)
SELECT first_name, last_name, email, points
FROM dml_demo_customers
WHERE points >= 50;
```

### Step-by-step explanation

1. **Column lists match positionally.** `SELECT first_name, last_name, …` must mirror the target's `(first_name, last_name, …)`.
2. **`snapshot_at` is auto-filled** by `DEFAULT CURRENT_TIMESTAMP` — every staging row gets the same instant.
3. **Want only "new" rows?** Add `LEFT JOIN target … WHERE target.id IS NULL` or wrap the insert with `ON DUPLICATE KEY UPDATE` (Exercise 8).

---

## Exercise 8 — `INSERT … ON DUPLICATE KEY UPDATE` (upsert)

### Context

A daily CRM sync sends customer rows. If the email is already in our system, we don't want a duplicate — we want to **bump the points and refresh the last name** instead.

### What you'll learn

- `INSERT … ON DUPLICATE KEY UPDATE …` — atomic upsert.
- The pseudo-function `VALUES(col)` that refers to the value that **would have been** inserted.
- Why the table **must** have a `UNIQUE` (or primary) key for the upsert to fire.

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_customers` | `email` (`UNIQUE`), `points`, `last_name` |

### Task

Try to insert Ada Morgan-Smith / `ada.morgan@example.com` / 999 points. Since her email already exists, **update**: `points += 25` and `last_name = 'Morgan-Smith'`.

### Expected result (Ada's row after upsert)

```text
+----+------------+--------------+------------------------+--------+
| id | first_name | last_name    | email                  | points |
+----+------------+--------------+------------------------+--------+
|  1 | Ada        | Morgan-Smith | ada.morgan@example.com |    125 |
+----+------------+--------------+------------------------+--------+
```

Note: `points = 100 + 25 = 125`; `last_name` changed from `Morgan` to `Morgan-Smith`. The literal `999` from `VALUES` is **discarded** because of the conflict.

### Hint

After `VALUES (…)` add `ON DUPLICATE KEY UPDATE points = points + 25, last_name = VALUES(last_name)`.

### Solution

```sql
INSERT INTO dml_demo_customers (first_name, last_name, email, points)
VALUES ('Ada', 'Morgan-Smith', 'ada.morgan@example.com', 999)
ON DUPLICATE KEY UPDATE
  points = points + 25,
  last_name = VALUES(last_name);
```

### Step-by-step explanation

1. **Trigger condition.** MySQL detects the conflict on the `UNIQUE` key (`email`); if there were **no** unique constraint, this would simply insert a fresh row with the same email.
2. **`VALUES(last_name)`** returns the value from the `VALUES` clause that *would* have gone in (`'Morgan-Smith'` here). MySQL 8.0.20+ recommends the alias form `INSERT … AS new ON DUPLICATE KEY UPDATE last_name = new.last_name`, but `VALUES(col)` still works and is taught in most textbooks.
3. **Auto-increment burn.** Even though no new row was inserted, the next `AUTO_INCREMENT` value may still advance (engine-dependent). Don't rely on contiguous ids.

---

## Exercise 9 — `REPLACE INTO`

### Context

A correction sweep replaces the whole work order #1 with a fresh, canonical version — same id, new contents. `REPLACE` is the MySQL idiom for "delete the old row, insert a new one".

### What you'll learn

- `REPLACE INTO …` semantics: **delete + insert** if the unique/primary key collides; plain insert otherwise.
- Why `REPLACE` is **not** an `UPDATE` (triggers, foreign keys, auto-increment all see two events).

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_work_orders` | `id`, `customer_id`, `status`, `total_cost` |

### Task

Replace the row with `id = 1` so that `status = 'in_progress'` and `total_cost = 130.50`.

### Expected result

```text
+----+-------------+-------------+------------+
| id | customer_id | status      | total_cost |
+----+-------------+-------------+------------+
|  1 |           1 | in_progress |     130.50 |
+----+-------------+-------------+------------+
```

### Hint

`REPLACE INTO dml_demo_work_orders (id, customer_id, status, total_cost) VALUES (1, 1, 'in_progress', 130.50);`

### Solution

```sql
REPLACE INTO dml_demo_work_orders (id, customer_id, status, total_cost)
VALUES (1, 1, 'in_progress', 130.50);
```

### Step-by-step explanation

1. **Delete + insert, not update.** Any `BEFORE DELETE` / `AFTER INSERT` triggers fire; the row gets a new physical position; cascading FKs on the old row activate.
2. **Missing columns are reset to defaults.** Forgetting a column in `REPLACE` wipes the old value — a classic foot-gun. `UPDATE` only touches the columns you mention.
3. **Use `INSERT … ON DUPLICATE KEY UPDATE` instead** if you want to keep untouched columns intact. `REPLACE` is rarely the right choice in 2025 schemas.

---

## Exercise 10 — Transaction + `ROLLBACK`

### Context

Ben's row is briefly hit with a buggy `-1000` adjustment. Catch the mistake inside a transaction; `ROLLBACK` undoes it without ever exposing the bad value.

### What you'll learn

- The transaction trio: `START TRANSACTION`, `ROLLBACK`, `COMMIT`.
- That MySQL's **autocommit** is on by default — you must explicitly open a transaction to get rollback ability.

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_customers` | `points` |

### Task

Open a transaction, subtract 1000 from Ben's points, verify the value inside the transaction (`points = -950`), then `ROLLBACK`.

### Expected result (after rollback — points are back to 50)

```text
+----+------------+-----------+------------------------+--------+
| id | first_name | last_name | email                  | points |
+----+------------+-----------+------------------------+--------+
|  2 | Ben        | Ortega    | ben.ortega@example.com |     50 |
+----+------------+-----------+------------------------+--------+
```

(Inside the transaction the row temporarily read `points = -950`; after `ROLLBACK` it's back to 50.)

### Hint

`START TRANSACTION; UPDATE …; -- inspect; ROLLBACK;`

### Solution

```sql
START TRANSACTION;
UPDATE dml_demo_customers SET points = points - 1000 WHERE email = 'ben.ortega@example.com';
-- Inside the transaction (intentionally bad value visible):
SELECT id, first_name, points FROM dml_demo_customers WHERE email = 'ben.ortega@example.com';
ROLLBACK;
```

### Step-by-step explanation

1. **InnoDB is transactional**; MyISAM is not. If `REPLACE INTO` happens to a MyISAM table, `ROLLBACK` won't recover it.
2. **Read your own writes.** Inside a transaction the same session sees its uncommitted changes (`points = -950`); other sessions still see the pre-transaction value.
3. **`ROLLBACK` is fast but not free.** Long-running transactions hold undo records; keep them short or the InnoDB history list grows.

---

## Exercise 11 — Transaction + `COMMIT`

### Context

A legitimate 5-point bonus for Felix. We wrap it in a transaction so we can verify and commit — the standard production pattern even for one-statement changes.

### What you'll learn

- `COMMIT` makes changes durable and visible to other sessions.
- That `START TRANSACTION` works around a stuck autocommit accidentally.

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_customers` | `points` |

### Task

Inside a transaction, give Felix `+5` points and commit.

### Expected result (after commit — points jumps from 10 to 15)

```text
+----+------------+-----------+-------------------------+--------+
| id | first_name | last_name | email                   | points |
+----+------------+-----------+-------------------------+--------+
|  6 | Felix      | Brown     | felix.brown@example.com |     15 |
+----+------------+-----------+-------------------------+--------+
```

### Hint

`START TRANSACTION; UPDATE …; COMMIT;`

### Solution

```sql
START TRANSACTION;
UPDATE dml_demo_customers SET points = points + 5 WHERE email = 'felix.brown@example.com';
COMMIT;
```

### Step-by-step explanation

1. **`COMMIT`** writes the change to the redo log and unblocks any concurrent reader waiting on row-level locks.
2. **Empty transaction = no-op.** `START TRANSACTION; COMMIT;` is legal but useless; it costs a small log entry on some configurations.
3. **Connection drop = implicit `ROLLBACK`.** If the client disconnects between `START TRANSACTION` and `COMMIT`, the server discards the uncommitted work — a feature that saves countless accidental half-commits.

---

## Exercise 12 — `DELETE` with join pattern

### Context

Yearly cleanup: drop unfinished low-priority orders (`new` or `waiting_parts`) for customers with fewer than 15 loyalty points. The condition lives in `customers`, but the row to delete is in `work_orders`.

### What you'll learn

- MySQL's multi-table `DELETE` syntax: `DELETE alias FROM table1 JOIN table2 ON … WHERE …`.
- Which alias goes after `DELETE` decides **which** table loses rows.

### Tables in play

| Table | Role |
|---|---|
| `dml_demo_work_orders` | (target of `DELETE`) |
| `dml_demo_customers` | join source for `points` predicate |

### Task

Delete work orders that match: `c.points < 15 AND wo.status IN ('new','waiting_parts')`.

### Expected result (Elena's order id 6 is gone — she had 10 points, status `new`)

Before:

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | in_progress   |     130.50 |
|  2 |           1 | completed     |     450.75 |
|  3 |           2 | completed     |     199.99 |
|  5 |           3 | waiting_parts |     300.25 |   <- Cara has 50 pts, kept
|  6 |           5 | new           |      40.00 |   <- Elena has 10 pts, deleted
+----+-------------+---------------+------------+
```

After:

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | in_progress   |     130.50 |
|  2 |           1 | completed     |     450.75 |
|  3 |           2 | completed     |     199.99 |
|  5 |           3 | waiting_parts |     300.25 |
+----+-------------+---------------+------------+
```

### Hint

`DELETE wo FROM dml_demo_work_orders wo JOIN dml_demo_customers c ON c.id = wo.customer_id WHERE c.points < 15 AND wo.status IN ('new','waiting_parts');`

### Solution

```sql
DELETE wo
FROM dml_demo_work_orders AS wo
INNER JOIN dml_demo_customers AS c ON c.id = wo.customer_id
WHERE c.points < 15
  AND wo.status IN ('new', 'waiting_parts');
```

### Step-by-step explanation

1. **`DELETE wo`** names the alias to delete from. `DELETE c` would delete customers (not what we want), `DELETE wo, c` would delete from both tables.
2. **`INNER JOIN`** restricts the delete to rows that have a matching customer. A `LEFT JOIN` would also leave orphan work orders in scope.
3. **Single statement, atomic delete.** Without `DELETE … JOIN` you'd need two statements and risk partial deletion if something blew up between them.

---

## Exercise 13 — `UPDATE` with join pattern

### Context

VIP loyalty rule: every active work order for a customer with ≥ 100 points gets a 5 % discount. The discount calculation needs `points` (in `customers`) but writes to `work_orders`.

### What you'll learn

- `UPDATE t JOIN s ON … SET t.col = … WHERE …` — multi-table update.
- Pre-computed expressions inside `SET` (`ROUND(wo.total_cost * 0.95, 2)`).

### Tables in play

| Table | Role |
|---|---|
| `dml_demo_work_orders` | (gets `total_cost` mutated) |
| `dml_demo_customers` | join source for `points` predicate |

### Task

For every non-cancelled work order belonging to a customer with `points >= 100`, multiply `total_cost` by `0.95` (rounded to 2 d.p.).

### Expected result (Ada has 125 pts, so wo 1 and wo 2 are discounted)

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | in_progress   |     123.98 |   <- was 130.50 -> 130.50*0.95
|  2 |           1 | completed     |     428.21 |   <- was 450.75 -> 450.75*0.95
|  3 |           2 | completed     |     199.99 |   (Ben has 50 pts; unchanged)
|  5 |           3 | waiting_parts |     300.25 |   (Cara has 50 pts; unchanged)
+----+-------------+---------------+------------+
```

### Hint

`UPDATE wo JOIN c ON c.id = wo.customer_id SET wo.total_cost = ROUND(wo.total_cost * 0.95, 2) WHERE c.points >= 100 AND wo.status NOT IN ('cancelled');`

### Solution

```sql
UPDATE dml_demo_work_orders AS wo
INNER JOIN dml_demo_customers AS c ON c.id = wo.customer_id
SET wo.total_cost = ROUND(wo.total_cost * 0.95, 2)
WHERE c.points >= 100
  AND wo.status NOT IN ('cancelled');
```

### Step-by-step explanation

1. **No `FROM` keyword** in the multi-table `UPDATE` — you `JOIN` directly after `UPDATE`.
2. **`ROUND(x, 2)`** rounds half-up to two decimal places; `DECIMAL(12,2)` storage would also round, but doing it explicitly keeps the result deterministic across MySQL versions.
3. **`status NOT IN ('cancelled')`** is equivalent to `status <> 'cancelled'`, but the `IN` form scales naturally to multiple excluded statuses.

---

## Exercise 14 — Conditional multi-row `UPDATE` (`CASE`)

### Context

End-of-day pricing tweak: tack on a status-specific surcharge to every open work order. Different status, different bump — but it's still one statement.

### What you'll learn

- `SET col = CASE other_col WHEN … THEN … ELSE … END`.
- Why one `CASE` is better than several conditional `UPDATE`s (single scan, atomic).

### Tables in play

| Table | Columns |
|---|---|
| `dml_demo_work_orders` | `status`, `total_cost` |

### Task

Adjust `total_cost` per status: `new +25`, `in_progress +15`, `completed unchanged`, `waiting_parts +10`. Apply to all non-`NULL` status rows.

### Expected result (after the conditional bump, building on Exercise 13's state)

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | in_progress   |     138.98 |   <- 123.98 + 15
|  2 |           1 | completed     |     428.21 |   <- unchanged
|  3 |           2 | completed     |     199.99 |   <- unchanged
|  5 |           3 | waiting_parts |     310.25 |   <- 300.25 + 10
+----+-------------+---------------+------------+
```

### Hint

`UPDATE t SET col = CASE other_col WHEN 'a' THEN … WHEN 'b' THEN … ELSE … END WHERE …;`

### Solution

```sql
UPDATE dml_demo_work_orders
SET total_cost = CASE status
  WHEN 'new'           THEN ROUND(total_cost + 25, 2)
  WHEN 'in_progress'   THEN ROUND(total_cost + 15, 2)
  WHEN 'completed'     THEN total_cost
  WHEN 'waiting_parts' THEN ROUND(total_cost + 10, 2)
  ELSE total_cost
END
WHERE status IS NOT NULL;
```

### Step-by-step explanation

1. **`CASE col WHEN x THEN …`** is the "simple" `CASE`; the "searched" form `CASE WHEN col = x THEN …` is more flexible but verbose. Pick whichever reads better.
2. **`ELSE total_cost`** is the safety net for any future status MySQL hasn't been told about — never write `CASE` without an `ELSE`.
3. **Single statement, single scan.** Five tiny `UPDATE`s would each take a full table scan; one `CASE` traverses once and dispatches in memory.

---

## Troubleshooting: my DML did something weird

| Symptom | Likely fix |
|---|---|
| `UPDATE` matched 0 rows | The `WHERE` is too strict — try the matching `SELECT … FROM …` first to see the rows. |
| `Cannot delete or update a parent row: a foreign key constraint fails` | Children still reference this row. Delete them first or change the FK action. |
| `INSERT IGNORE` silently lost a row | `IGNORE` swallows real errors (truncation, FK, unique). Inspect `SHOW WARNINGS`. |
| Upsert didn't fire | No `UNIQUE` constraint on the column you expected to collide on. |
| Transaction "didn't work" | The table is not InnoDB, or autocommit is on without `START TRANSACTION`. |
| `REPLACE` lost a column value | `REPLACE` resets unspecified columns to defaults — switch to `INSERT … ON DUPLICATE KEY UPDATE`. |

To re-run the full lab: `mysql -u root < 03_mysql/03_dml/car_service_dml_examples.sql`. The script drops and reseeds the sandbox, so it's safe to run again and again.
