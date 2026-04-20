# DML (Data Manipulation Language) — `car_service_db` theme

These examples use the **same domain** as the MySQL dump `database/car_service_db.sql.gz` (`customers`, `work_orders`, points/loyalty style fields). The **runnable script** is `car_service_dml_examples.sql` and uses a sandbox database **`dml_practice`** with `dml_demo_*` tables so you **do not change** data inside `car_service_db`.

Pair each exercise below with the matching block in that `.sql` file.

## DML command map (MySQL 8 / 9)

| Statement | Role |
|-----------|------|
| `INSERT` | Add new rows (single-row, multi-row, `INSERT … SELECT`) |
| `UPDATE` | Change existing rows (always constrain with `WHERE` in real use) |
| `DELETE` | Remove rows (`WHERE`; avoid accidental full-table delete) |
| `REPLACE` | MySQL-specific delete+insert on primary/unique key conflicts |
| `INSERT … ON DUPLICATE KEY UPDATE` | “Upsert”: insert or update on duplicate unique key |

**Transactions (with DML):** `START TRANSACTION` / `BEGIN`, `COMMIT`, `ROLLBACK` — group DML so all succeed or none apply.

**Usually not DML:** `SELECT` is sometimes classified as DQL; `TRUNCATE` is often grouped with DDL.

---

## Schema touchpoints (from the real dump)

Ideas mirrored in the demo tables:

- **`customers`:** names, `email`, phone-style uniqueness in courses often uses `email`
- **`work_orders`:** `status` (`new`, `in_progress`, `completed`, …), `total_cost` as `DECIMAL(12,2)`
- **`loyalty_cards`:** `points` — we fold a simple `points` column into demo customers for `UPDATE` / upsert labs

---

## Exercise 1 — Sandbox setup

**Task:** Create database `dml_practice` and small `dml_demo_*` tables (minimal DDL only to host DML).

**DML focus:** after setup, all exercises only **insert / update / delete** rows.

---

## Exercise 2 — `INSERT` single row

**Task:** Add one customer row with explicit column list (mirrors loading **`customers`**).

**DML idea:** `INSERT INTO … (cols…) VALUES (…);`

---

## Exercise 3 — `INSERT` multiple rows

**Task:** Add several customers in one statement.

**DML idea:** `INSERT INTO … VALUES (…), (…), (…);`

---

## Exercise 4 — `UPDATE` with `WHERE`

**Task:** Increase loyalty `points` for one identifiable row (e.g. by `email`).

**DML idea:** `UPDATE … SET … WHERE …;` — without `WHERE`, you update **every** row.

---

## Exercise 5 — `UPDATE` several columns

**Task:** Change `status` and `total_cost` on a **`work_orders`‑style** row.

**DML idea:** `SET col1 = …, col2 = …`.

---

## Exercise 6 — `DELETE` with `WHERE`

**Task:** Remove rows matching a condition (e.g. cancelled work orders).

**DML idea:** `DELETE FROM … WHERE …;`

---

## Exercise 7 — `INSERT … SELECT`

**Task:** Copy a subset of rows into a staging table (reporting / ETL pattern).

**DML idea:** `INSERT INTO target (cols) SELECT … FROM source WHERE …;`

---

## Exercise 8 — `INSERT … ON DUPLICATE KEY UPDATE` (upsert)

**Task:** Insert a customer by `email`; if that email already exists, bump `points` instead.

**DML idea:** requires a `UNIQUE` key (here: `email`); MySQL merges insert and update on conflict.

---

## Exercise 9 — `REPLACE INTO`

**Task:** Replace a row identified by primary key (MySQL deletes old row, inserts new).

**DML idea:** `REPLACE INTO …` — understand difference from `UPDATE` and from upsert.

---

## Exercise 10 — Transaction + `ROLLBACK`

**Task:** Show a change that is undone (`ROLLBACK`) so the database returns to the prior state.

**DML idea:** `START TRANSACTION; …; ROLLBACK;`

---

## Exercise 11 — Transaction + `COMMIT`

**Task:** Apply a change permanently with `COMMIT`.

**DML idea:** same session, `COMMIT` persists DML.

---

## Exercise 12 — `DELETE` with join pattern

**Task:** Delete rows using a join condition (MySQL multi-table `DELETE` syntax).

**DML idea:** `DELETE t FROM t JOIN s ON … WHERE …;`

---

## Exercise 13 — `UPDATE` with join pattern

**Task:** Update rows in one table based on related rows in another.

**DML idea:** `UPDATE t JOIN s ON … SET t.col = … WHERE …;`

---

## Exercise 14 — Conditional multi-row `UPDATE` (`CASE`)

**Task:** Set different `total_cost` adjustments by `status` in one statement.

**DML idea:** `SET col = CASE … END`.

---

### How to run the SQL

1. `mysql -u… -p… < car_service_dml_examples.sql`  
   or `SOURCE …/car_service_dml_examples.sql` in the client.

2. Re-running the script **drops and recreates** demo tables so exercises stay repeatable.

3. To practice on **live** `car_service_db`, wrap changes in `START TRANSACTION` … `ROLLBACK` and never run unbounded `UPDATE`/`DELETE` without `WHERE`.
