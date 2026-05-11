# Triggers — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/12_triggers/triggers_car_service_db.md)

These exercises install **InnoDB triggers** on small lab tables **`tri_lab_account`** and **`tri_lab_audit`** inside **`car_service_db`** and demonstrate the full trigger lifecycle: **`BEFORE INSERT`** (validation with **`SIGNAL`**), **`AFTER INSERT`**, **`BEFORE UPDATE`**, **`AFTER UPDATE`**, and **`AFTER DELETE`**. Working with isolated lab tables keeps the production tables untouched and makes the audit trail easy to read.

> **Folder name:** this module is **`12_triggers`** (triggers come before stored functions in this repo's numbering).

Runnable companion file: [`12_triggers/car_service_triggers_examples.sql`](car_service_triggers_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/12_triggers/car_service_triggers_examples.sql
```

Use the **`mysql`** client (or compatible); **`DELIMITER`** is processed by the client when you `SOURCE` / redirect the file. **Re-running** the script is safe — it begins with `DROP TABLE IF EXISTS …` and drops the triggers together with the tables.

---

## Quick reference

| Trigger timing × event | Typical use |
|---|---|
| **`BEFORE INSERT`** | Validate / normalize **`NEW.*`**; reject invalid rows with **`SIGNAL`**. |
| **`AFTER  INSERT`** | Write audit rows, increment counters (use **`NEW`**). |
| **`BEFORE UPDATE`** | Validate the new column values; can also **modify `NEW.*`**. |
| **`AFTER  UPDATE`** | Audit the change with both **`OLD`** and **`NEW`**. |
| **`BEFORE DELETE`** | Last chance to veto the delete (rare). |
| **`AFTER  DELETE`** | Audit / cascade with **`OLD`**. |

| Pseudo-row | Available in |
|---|---|
| **`NEW.column`** | All `INSERT` and `UPDATE` triggers — the row about to land / the post-update values. |
| **`OLD.column`** | All `UPDATE` and `DELETE` triggers — the row as it was. |

- **`SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '…';`** is the standard way to reject the operation from inside a trigger. SQLSTATE class `45000` is reserved for user-defined exceptions.
- Triggers are **not** a substitute for constraints when a `CHECK`, `FOREIGN KEY` or `NOT NULL` suffices. Reach for them when the logic crosses rows, needs auditing, or has to fire even when DML goes around the app.
- Dropping a table drops its triggers; **`DROP TRIGGER name`** removes a single trigger if you need to keep the table.

---

## Lab schema (created by the script)

| Table | Columns |
|---|---|
| `tri_lab_account` | `id` (PK, AUTO_INCREMENT), `label VARCHAR(80)`, `balance DECIMAL(12,2)` |
| `tri_lab_audit`   | `id` (PK), `event VARCHAR(20)`, `account_id INT`, `old_val`, `new_val`, `msg`, `ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP` |

---

## Exercise T1 — Create the lab tables

### Context

Triggers don't make sense without a victim and an audit trail. We need a small "accounts" table to mutate and an "audit" table that the triggers will write into. Putting both inside `car_service_db` keeps them next to the rest of our examples but separated by their `tri_lab_` prefix.

### What you'll learn

- Defining the **lab pair** (`tri_lab_account` + `tri_lab_audit`).
- Using `DROP TABLE IF EXISTS` to make the script **idempotent** (re-runnable).
- Why dropping tables in the right order matters when foreign keys point at them.

### Tables in play

| Table | Columns |
|---|---|
| `tri_lab_account` | `id`, `label`, `balance` |
| `tri_lab_audit` | `id`, `event`, `account_id`, `old_val`, `new_val`, `msg`, `ts` |

### Task

Drop both tables if they exist, then create them with InnoDB / `utf8mb4_0900_ai_ci`. `tri_lab_account.balance` defaults to `0.00`; `tri_lab_audit.ts` defaults to `CURRENT_TIMESTAMP`.

### Expected result

```text
Query OK, 0 rows affected
Query OK, 0 rows affected
```

(no result table — DDL only).

### Hint

`DROP TABLE IF EXISTS tri_lab_audit;` **before** `tri_lab_account` — child first if any FK were declared. Then two `CREATE TABLE` statements.

### Solution

```sql
USE car_service_db;

DROP TABLE IF EXISTS tri_lab_audit;
DROP TABLE IF EXISTS tri_lab_account;

CREATE TABLE tri_lab_account (
  id       INT NOT NULL AUTO_INCREMENT,
  label    VARCHAR(80) NOT NULL,
  balance  DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE tri_lab_audit (
  id         INT NOT NULL AUTO_INCREMENT,
  event      VARCHAR(20) NOT NULL,
  account_id INT DEFAULT NULL,
  old_val    VARCHAR(200) DEFAULT NULL,
  new_val    VARCHAR(200) DEFAULT NULL,
  msg        VARCHAR(300) DEFAULT NULL,
  ts         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Step-by-step explanation

1. **`USE car_service_db`** keeps the lab tables side-by-side with the rest of the course. They are clearly named with the `tri_lab_` prefix so you can grep them out at clean-up time.
2. **`DROP TABLE IF EXISTS`** at the top makes the script **safe to re-run** during practice. Dropping a table also drops its triggers — no leftover trigger from a previous attempt.
3. **`DECIMAL(12,2)` for money** is the right type — `FLOAT/DOUBLE` would introduce rounding noise.
4. **`tri_lab_audit.ts` default** is `CURRENT_TIMESTAMP`, so we don't need to pass the timestamp from inside the trigger — InnoDB stamps it.
5. **InnoDB** is required for proper transactional semantics: if a trigger raises `SIGNAL`, the original statement rolls back inside the transaction.

---

## Exercise T2 — `BEFORE INSERT`: reject negative balances with `SIGNAL`

### Context

Business rule: an account's balance can never be negative on creation. We want **the database itself** to enforce that — even if a careless developer bypasses the app layer.

### What you'll learn

- The `CREATE TRIGGER … BEFORE INSERT … FOR EACH ROW` syntax.
- Reading the candidate row via **`NEW.column`**.
- Aborting the statement with **`SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT`**.
- Why the **delimiter dance** (`DELIMITER $$ … $$`) is required for multi-statement bodies.

### Tables in play

| Table | Columns |
|---|---|
| `tri_lab_account` | `balance` (in `NEW`) |

### Task

Define `tri_lab_account_bi_check`: a `BEFORE INSERT` trigger on `tri_lab_account` that raises SQLSTATE `45000` with the message `'tri_lab_account: balance cannot be negative'` when `NEW.balance < 0`.

### Expected result

(no rows — DDL). Verify later by attempting `INSERT … (balance = -10.00)` — see Exercise T8.

### Hint

Wrap the body in `DELIMITER $$ … END$$ DELIMITER ;` so the parser doesn't trip on the `;` inside.

### Solution

```sql
DELIMITER $$

CREATE TRIGGER tri_lab_account_bi_check
BEFORE INSERT ON tri_lab_account
FOR EACH ROW
BEGIN
  IF NEW.balance < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'tri_lab_account: balance cannot be negative';
  END IF;
END$$

DELIMITER ;
```

### Step-by-step explanation

1. **`BEFORE INSERT`** fires *before* the row hits the table. You can read `NEW.*` and optionally **modify** it (e.g. `SET NEW.balance = 0;`).
2. **`FOR EACH ROW`** is mandatory in MySQL — the trigger runs once per affected row. A bulk `INSERT … SELECT` of 1000 rows runs the body 1000 times.
3. **`NEW.balance`** is the candidate value. The row does not exist in storage yet, so there is no `OLD` here.
4. **`SIGNAL SQLSTATE '45000'`** aborts the statement. Class `45000` is the SQL standard's "user-defined unhandled exception". The session receives `ERROR 1644 (45000)` with our `MESSAGE_TEXT`.
5. **`DELIMITER $$`** temporarily switches the client's statement separator. Without it, the first `;` after `IF NEW.balance < 0 THEN` would terminate the `CREATE TRIGGER` and the parser would explode.

---

## Exercise T3 — `AFTER INSERT`: write an audit row

### Context

When a new account is created, the auditing system should record who, what, when. With an **`AFTER INSERT`** trigger we can write to `tri_lab_audit` automatically — the application can't "forget".

### What you'll learn

- The `AFTER INSERT` timing — fires once the row is safely in the table.
- Reading the now-final `NEW.*` to build the audit record.
- `CAST(… AS CHAR)` to fit numbers into a `VARCHAR` audit column.

### Tables in play

| Table | Columns |
|---|---|
| `tri_lab_account` (source `NEW.*`) | `id`, `label`, `balance` |
| `tri_lab_audit` (destination) | `event`, `account_id`, `new_val`, `msg` |

### Task

Define `tri_lab_account_ai_log`: an `AFTER INSERT` trigger that writes one row to `tri_lab_audit` with `event = 'INSERT'`, `account_id = NEW.id`, `new_val = NEW.balance` (cast to `CHAR`), and `msg = 'created: ' || NEW.label`.

### Expected result

(no rows from the DDL). After the demo `INSERT`s in T7, `tri_lab_audit` will show two new rows of `event = 'INSERT'`.

### Hint

`CONCAT('created: ', NEW.label)` for the message; `CAST(NEW.balance AS CHAR)` for `new_val`.

### Solution

```sql
DELIMITER $$

CREATE TRIGGER tri_lab_account_ai_log
AFTER INSERT ON tri_lab_account
FOR EACH ROW
BEGIN
  INSERT INTO tri_lab_audit (event, account_id, new_val, msg)
  VALUES ('INSERT', NEW.id, CAST(NEW.balance AS CHAR), CONCAT('created: ', NEW.label));
END$$

DELIMITER ;
```

### Step-by-step explanation

1. **Why `AFTER INSERT`?** At this point `NEW.id` has its final auto-incremented value. In a `BEFORE INSERT` trigger, `NEW.id` would still be `0` (or the literal you gave).
2. **`event = 'INSERT'`** is a free-form label; we keep `INSERT`, `UPDATE`, `DELETE` consistent so dashboards can `GROUP BY event`.
3. **`CAST(NEW.balance AS CHAR)`** turns `DECIMAL(12,2)` into a string so it fits the `VARCHAR(200)` audit column. `CONVERT(NEW.balance, CHAR)` is equivalent.
4. **No `OLD` available** here — the row didn't exist before. Putting `OLD.balance` would be a syntax error.
5. **Trigger inside a transaction:** the audit `INSERT` is part of the same transaction as the original `INSERT`. If the outer transaction rolls back, the audit row vanishes too.

---

## Exercise T4 — `BEFORE UPDATE`: reject negative balance on update

### Context

The same rule applies on updates — the audit team caught a junior dev who pushed a "fix" that decremented balances below zero. We need a trigger that mirrors the `BEFORE INSERT` validation for `UPDATE` statements.

### What you'll learn

- The `BEFORE UPDATE` timing — fires before the row is rewritten.
- `NEW.column` is the **post-update** value; `OLD.column` is the value being replaced.
- Sharing the same rule across two triggers without copy-pasting (cf. stored procedures).

### Tables in play

| Table | Columns |
|---|---|
| `tri_lab_account` | `balance` (`OLD` and `NEW`) |

### Task

Define `tri_lab_account_bu_check`: a `BEFORE UPDATE` trigger that raises `SQLSTATE '45000'` with message `'tri_lab_account: balance cannot be negative after update'` when the new balance is negative.

### Expected result

(no rows — DDL). Verify later by `UPDATE tri_lab_account SET balance = -1 WHERE id = 1` → `ERROR 1644`.

### Hint

Same body as T2 but on `BEFORE UPDATE` and a slightly different message.

### Solution

```sql
DELIMITER $$

CREATE TRIGGER tri_lab_account_bu_check
BEFORE UPDATE ON tri_lab_account
FOR EACH ROW
BEGIN
  IF NEW.balance < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'tri_lab_account: balance cannot be negative after update';
  END IF;
END$$

DELIMITER ;
```

### Step-by-step explanation

1. **`BEFORE UPDATE`** lets us **veto** the change. Comparing `NEW.balance` against `0` is enough; the `OLD.balance` doesn't matter for this rule.
2. **You could also rewrite `NEW.*` here** (`SET NEW.balance = 0;`) to silently clamp the value. The script chooses the strict path: raise `SIGNAL`.
3. **Why not a `CHECK` constraint?** MySQL 8.0.16+ supports `CHECK (balance >= 0)`. The trigger version is more flexible (custom message, dynamic logic, audit log on the rejection), but a simple `CHECK` is the lighter weight option when the rule is purely declarative.
4. **Two near-identical triggers (T2 + T4)** are typical — a refactor would put the rule into a stored procedure called from both. We keep them separate here for clarity.

---

## Exercise T5 — `AFTER UPDATE`: audit `OLD` vs `NEW`

### Context

After a successful update, we want to record **what changed** — both `OLD.balance` and `NEW.balance`, plus the previous and new `label`. This is the typical "diff" audit row.

### What you'll learn

- Reading both `OLD` and `NEW` in an `UPDATE` trigger.
- Composing a human-readable `msg` that explains the change.
- Why audit rows are usually `VARCHAR`-typed for max flexibility.

### Tables in play

| Table | Columns |
|---|---|
| `tri_lab_account` | `id`, `label`, `balance` (both `OLD` and `NEW`) |
| `tri_lab_audit` | (destination) |

### Task

Define `tri_lab_account_au_log`: an `AFTER UPDATE` trigger that inserts an audit row with `event = 'UPDATE'`, `account_id = NEW.id`, `old_val` and `new_val` carrying the cast `balance` values, and `msg` of the form `'label was: <OLD.label> -> <NEW.label>'`.

### Expected result

After the sample `UPDATE` in T7:

```text
| 3 | UPDATE |          1 | 250.00  | 200.00  | label was: Parts petty cash -> Parts petty cash (adjusted) | 2026-05-11 16:55:04 |
```

### Hint

`CONCAT('label was: ', OLD.label, ' -> ', NEW.label)` for `msg`.

### Solution

```sql
DELIMITER $$

CREATE TRIGGER tri_lab_account_au_log
AFTER UPDATE ON tri_lab_account
FOR EACH ROW
BEGIN
  INSERT INTO tri_lab_audit (event, account_id, old_val, new_val, msg)
  VALUES (
    'UPDATE',
    NEW.id,
    CAST(OLD.balance AS CHAR),
    CAST(NEW.balance AS CHAR),
    CONCAT('label was: ', OLD.label, ' -> ', NEW.label)
  );
END$$

DELIMITER ;
```

### Step-by-step explanation

1. **`OLD.balance` vs `NEW.balance`** — same column, two values. The `OLD` is what was in storage; `NEW` is what's now in storage (we're in `AFTER UPDATE`).
2. **`CAST(... AS CHAR)`** keeps every audit row a string so we can stash any column type without changing the schema. A more "queryable" design would use typed columns (`old_balance DECIMAL`, `new_balance DECIMAL`).
3. **`account_id = NEW.id`** — yes, `OLD.id` and `NEW.id` are the same unless you change the primary key (which you usually don't). Using `NEW.id` makes the intent ("the current id") clear.
4. **No diff filter:** the trigger fires even if `UPDATE` didn't actually change any value (e.g. setting `balance = balance`). To audit only real changes, wrap the body in `IF NEW.balance <> OLD.balance OR NEW.label <> OLD.label THEN … END IF;`.

---

## Exercise T6 — `AFTER DELETE`: audit removal with `OLD`

### Context

When an account is deleted we want a tombstone in the audit log so we know what's gone. `AFTER DELETE` triggers see **only `OLD.*`** — `NEW` doesn't exist because the row is gone.

### What you'll learn

- `AFTER DELETE` timing and the `OLD`-only context.
- Using a `'DELETE'` event tag in the audit log.
- Why audit rows survive a row's deletion (separate table, separate lifetime).

### Tables in play

| Table | Columns |
|---|---|
| `tri_lab_account` (source `OLD.*`) | `id`, `label`, `balance` |
| `tri_lab_audit` (destination) | `event`, `account_id`, `old_val`, `msg` |

### Task

Define `tri_lab_account_ad_log`: an `AFTER DELETE` trigger that writes `event = 'DELETE'`, `account_id = OLD.id`, `old_val = OLD.balance`, `msg = 'removed: ' || OLD.label`.

### Expected result

After the sample `DELETE` in T7:

```text
| 4 | DELETE |          2 | 1200.50 | NULL    | removed: Tooling budget                                    | 2026-05-11 16:55:04 |
```

### Hint

Only `OLD.*` is available — referring to `NEW.id` here would be a syntax error.

### Solution

```sql
DELIMITER $$

CREATE TRIGGER tri_lab_account_ad_log
AFTER DELETE ON tri_lab_account
FOR EACH ROW
BEGIN
  INSERT INTO tri_lab_audit (event, account_id, old_val, msg)
  VALUES ('DELETE', OLD.id, CAST(OLD.balance AS CHAR), CONCAT('removed: ', OLD.label));
END$$

DELIMITER ;
```

### Step-by-step explanation

1. **`AFTER DELETE`** fires after the row is gone. We still have `OLD.*` (the deleted snapshot) available — that's how we can record the lost data.
2. **`new_val` is left as `NULL`** in the audit row. A `DELETE` has no "after" — making this column `NULL` is the convention.
3. **The audit table is not cascade-deleted.** When `tri_lab_account` row #2 disappears, the audit row that mentions `account_id = 2` lives on. That's the whole point — the audit table tracks history.
4. **What if the parent table is later truncated?** `TRUNCATE` does **not** fire row-level triggers (it drops and recreates the table). Use `DELETE FROM table` if you need triggers to run.

---

## Exercise T7 — Exercise the lab and inspect the audit trail

### Context

Now that the triggers are installed, run the demo data: two `INSERT`s, one `UPDATE`, one `DELETE`, then `SELECT` the audit table. This is the moment where all the trigger plumbing pays off — every DML produces an audit row.

### What you'll learn

- That triggers fire **automatically** — the application code never mentions `tri_lab_audit`.
- Reading the audit trail end-to-end: insertion, mutation, removal.
- Confirming the `OLD`/`NEW` semantics one row at a time.

### Tables in play

| Table | Columns |
|---|---|
| `tri_lab_account` (mutated) | `label`, `balance` |
| `tri_lab_audit` (read) | `id`, `event`, `account_id`, `old_val`, `new_val`, `msg`, `ts` |

### Task

Insert two accounts (`Parts petty cash` 250.00 and `Tooling budget` 1200.50). Update account `id = 1` to set `balance = balance − 50.00` and relabel to `Parts petty cash (adjusted)`. Delete account `id = 2`. Then `SELECT … FROM tri_lab_audit ORDER BY id`.

### Expected result

```text
+----+--------+------------+---------+---------+------------------------------------------------------------+---------------------+
| id | event  | account_id | old_val | new_val | msg                                                        | ts                  |
+----+--------+------------+---------+---------+------------------------------------------------------------+---------------------+
|  1 | INSERT |          1 | NULL    | 250.00  | created: Parts petty cash                                  | 2026-05-11 16:55:04 |
|  2 | INSERT |          2 | NULL    | 1200.50 | created: Tooling budget                                    | 2026-05-11 16:55:04 |
|  3 | UPDATE |          1 | 250.00  | 200.00  | label was: Parts petty cash -> Parts petty cash (adjusted) | 2026-05-11 16:55:04 |
|  4 | DELETE |          2 | 1200.50 | NULL    | removed: Tooling budget                                    | 2026-05-11 16:55:04 |
+----+--------+------------+---------+---------+------------------------------------------------------------+---------------------+
```

### Hint

Run the DML, then `SELECT id, event, account_id, old_val, new_val, msg, ts FROM tri_lab_audit ORDER BY id;`.

### Solution

```sql
INSERT INTO tri_lab_account (label, balance) VALUES
  ('Parts petty cash', 250.00),
  ('Tooling budget', 1200.50);

UPDATE tri_lab_account
SET balance = balance - 50.00,
    label = 'Parts petty cash (adjusted)'
WHERE id = 1;

DELETE FROM tri_lab_account WHERE id = 2;

SELECT id, event, account_id, old_val, new_val, msg, ts
FROM tri_lab_audit
ORDER BY id;
```

### Step-by-step explanation

1. **Two `INSERT`s** → two `INSERT` audit rows. `NEW.id` was `1` and `2` (auto-increment); `new_val` carries the cast balance; `old_val` is `NULL` because no row existed.
2. **One `UPDATE`** → one `UPDATE` audit row. `old_val` is `250.00`, `new_val` is `200.00` (we subtracted `50.00`). `msg` records the label change.
3. **One `DELETE`** → one `DELETE` audit row. `old_val` shows the final balance before removal. `new_val` is `NULL` — nothing remains.
4. **`ts`** is set by the `tri_lab_audit.ts DEFAULT CURRENT_TIMESTAMP` — not by the trigger. All four rows share the same second because the script runs quickly.
5. **Auto-increment of `tri_lab_audit.id`** gives the trail a natural order (`1, 2, 3, 4`). The `ORDER BY id` makes the print order deterministic.

---

## Exercise T8 — Verify the `SIGNAL` (negative-balance INSERT must fail)

### Context

We installed the validation triggers — but the audit team will only believe they work if we **prove** they reject an offending row. The script keeps this test as a commented-out `INSERT` so the demo run remains clean; uncomment it to see the error.

### What you'll learn

- How `SIGNAL` surfaces in the client (`ERROR 1644 (45000)`).
- That the trigger fires **before** the row is written — nothing changes in `tri_lab_account` after the failure.
- A practical confirmation that **`BEFORE INSERT`** prevents bad data.

### Tables in play

| Table | Columns |
|---|---|
| `tri_lab_account` | `label`, `balance` |

### Task

Attempt `INSERT INTO tri_lab_account (label, balance) VALUES ('Bad row', -10.00);` and observe the error. (Optional: confirm with `SELECT COUNT(*) FROM tri_lab_account` that nothing changed.)

### Expected result

```text
ERROR 1644 (45000) at line 1: tri_lab_account: balance cannot be negative
```

### Hint

The error code (`1644`) and SQLSTATE (`45000`) match the trigger's `SIGNAL`. The text matches the `MESSAGE_TEXT` we set.

### Solution

```sql
-- This INSERT must FAIL with SIGNAL (kept commented out in the script):
INSERT INTO tri_lab_account (label, balance) VALUES ('Bad row', -10.00);
```

### Step-by-step explanation

1. **MySQL returns `1644`** — the engine's error number for `SIGNAL`. `45000` is the standard SQLSTATE class for user-defined exceptions.
2. **The `INSERT` does not happen.** `BEFORE INSERT` runs before the storage engine writes anything. Run `SELECT COUNT(*) FROM tri_lab_account` to confirm.
3. **No audit row either.** The `AFTER INSERT` trigger never fires because the operation failed — the rejected insert produces no trace in `tri_lab_audit`. If you want a "rejection" audit, you'd log it explicitly **before** raising `SIGNAL` (and accept that the audit row will be rolled back if you're inside a transaction).
4. **Catching errors in application code:** drivers expose this as a `SQLException` (Java), `OperationalError` (Python), etc. The `MESSAGE_TEXT` is human-readable on purpose.
5. **Clean-up:** to remove the lab tables and triggers in one shot, uncomment the bottom block of the script: `DROP TABLE IF EXISTS tri_lab_audit; DROP TABLE IF EXISTS tri_lab_account;`. To remove just a trigger, use `DROP TRIGGER IF EXISTS tri_lab_account_bi_check;` (names must match exactly).

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `You have an error in your SQL syntax …` near `BEGIN`/`END` | Missing `DELIMITER $$` switch — the parser ate the `;` inside the trigger body. |
| `Trigger already exists` | A previous run left a trigger. Re-run the script (it `DROP`s tables, which drops their triggers), or `DROP TRIGGER IF EXISTS name;` first. |
| Audit table stays empty | An earlier trigger raised `SIGNAL` → whole statement rolled back, including audit `INSERT`. Check for `ERROR 1644`. |
| `ts` is the wrong time-zone | `CURRENT_TIMESTAMP` follows `@@session.time_zone`. `SET time_zone = '+00:00';` for UTC. |
| `TRUNCATE` didn't fire triggers | `TRUNCATE` bypasses row-level triggers — use `DELETE FROM table` when you need them. |

If you want to run **all** examples at once: `mysql -t -u root car_service_db < 03_mysql/12_triggers/car_service_triggers_examples.sql`.
