# DDL (Data Definition Language) — `car_service_db` theme

These examples use the **same domain** as the MySQL dump `database/car_service_db.sql.gz` (workshops, suppliers, parts, work orders). The **runnable script** lives in `car_service_ddl_examples.sql` and builds a small sandbox database **`ddl_practice`** so you do not modify or collide with tables inside `car_service_db`.

Pair each exercise below with the matching block in that `.sql` file.

## DDL command map (MySQL 8 / 9)

| Statement | Role |
|-----------|------|
| `CREATE DATABASE` / `CREATE SCHEMA` | Define a namespace for objects |
| `CREATE TABLE` | Define base relation: columns, keys, constraints, indexes |
| `ALTER TABLE` | Add, drop, or change columns, keys, and constraints |
| `CREATE INDEX` / `CREATE UNIQUE INDEX` | Add secondary access paths (often declared inside `CREATE TABLE`) |
| `DROP TABLE` / `DROP DATABASE` | Remove objects (order matters when foreign keys exist) |
| `RENAME TABLE` | Rename one or more tables |
| `CREATE VIEW` | Named stored query (often grouped with DDL in courses) |

**Related but not pure DDL:** `TRUNCATE TABLE` (remove all rows quickly; reset auto-increment; requires `DROP` privilege). `INSERT`/`UPDATE`/`DELETE` are DML.

---

## Schema touchpoints (from the real dump)

Concepts you see in `car_service_db` that these exercises rehearse:

- **Numeric keys:** `INT` with `AUTO_INCREMENT`, `PRIMARY KEY`
- **Text:** `VARCHAR(n)`, optional `NOT NULL`
- **Money / amounts:** `DECIMAL(p,s)` (e.g. `DECIMAL(12,2)` like `work_orders.total_cost`)
- **Dates:** `DATE`, `DATETIME`, `TIMESTAMP`
- **Referential integrity:** `FOREIGN KEY` … `REFERENCES` … (`ON DELETE` / `ON UPDATE` optional)
- **Lookup / catalog tables:** e.g. `suppliers`, `purchase_orders`, `parts`, `warehouses`

---

## Exercise 1 — Create a practice database

**Task:** Create a database used only for DDL labs (skip if you already have it).

**DDL idea:** `CREATE DATABASE …` / `CREATE SCHEMA …` (synonyms in MySQL).

---

## Exercise 2 — `CREATE TABLE` with primary key and `AUTO_INCREMENT`

**Task:** Create a `demo_suppliers` table: surrogate key `id`, `name`, `phone` — mirroring **`suppliers`** in the dump.

**DDL idea:** `INT NOT NULL AUTO_INCREMENT`, `PRIMARY KEY (id)`, sensible `VARCHAR` lengths.

---

## Exercise 3 — Child table with foreign key

**Task:** Create `demo_purchase_orders` with `supplier_id` referencing `demo_suppliers(id)`, plus `order_date`.

**DDL idea:** `FOREIGN KEY (supplier_id) REFERENCES demo_suppliers(id)` — parent table must exist first.

---

## Exercise 4 — `UNIQUE` business key

**Task:** On a new `demo_parts` table, enforce that `sku` is unique (like **`parts.sku`** in the dump).

**DDL idea:** `UNIQUE KEY uk_demo_parts_sku (sku)` or column-level `UNIQUE`.

---

## Exercise 5 — `DEFAULT` and `NOT NULL`

**Task:** Columns such as `is_active` with default `1`, and `created_at` with default current timestamp.

**DDL idea:** `DEFAULT`, `NOT NULL`, `TIMESTAMP` / `DATETIME` defaults.

---

## Exercise 6 — `CHECK` constraint (MySQL 8.0.16+)

**Task:** Ensure `order_jobs`-style line `quantity` is strictly positive on a demo line table.

**DDL idea:** `CHECK (quantity > 0)` — MySQL enforces `CHECK` from 8.0.16 onward.

---

## Exercise 7 — Secondary index for lookups

**Task:** Add a non-unique index on `demo_purchase_orders(order_date)` for range scans (analogous to reporting on **`purchase_orders.order_date`**).

**DDL idea:** `CREATE INDEX … ON … (…)` or `ALTER TABLE … ADD INDEX …`.

---

## Exercise 8 — `ALTER TABLE` — add a column

**Task:** Add optional `notes` (`TEXT`) to `demo_suppliers` after the table exists.

**DDL idea:** `ALTER TABLE … ADD COLUMN …`.

---

## Exercise 9 — `ALTER TABLE` — change column type or nullability

**Task:** Widen `phone` or tighten nullability — practice `MODIFY COLUMN` / `CHANGE COLUMN`.

**DDL idea:** `ALTER TABLE … MODIFY COLUMN …`.

---

## Exercise 10 — `ALTER TABLE` — drop a column

**Task:** Remove a column that is no longer needed (run only after constraints allow it).

**DDL idea:** `ALTER TABLE … DROP COLUMN …`.

---

## Exercise 11 — `RENAME TABLE`

**Task:** Rename a demo table (e.g. `demo_parts` → `demo_catalog_parts`) without copying data.

**DDL idea:** `RENAME TABLE old TO new`.

---

## Exercise 12 — `DROP TABLE` order and cleanup

**Task:** Drop child tables before parents, or use `SET foreign_key_checks` cautiously for teardown.

**DDL idea:** `DROP TABLE IF EXISTS child, parent` in safe order; optional `DROP DATABASE` for full reset.

---

## Exercise 13 — `CREATE VIEW` (named definition)

**Task:** Define a view that joins demo suppliers and their purchase orders (read-only “schema object” for queries).

**DDL idea:** `CREATE OR REPLACE VIEW … AS SELECT …`.

---

## Exercise 14 — `TRUNCATE` (optional lab)

**Task:** Empty a demo table that has no FKs pointing **to** it (or after dropping children).

**DDL idea:** `TRUNCATE TABLE …` vs `DELETE` — locking and reset semantics differ.

---

### How to run the SQL

1. Open MySQL client.
2. Run: `SOURCE …/car_service_ddl_examples.sql` or `mysql … < car_service_ddl_examples.sql`
3. Inspect: `USE ddl_practice; SHOW TABLES; SHOW CREATE TABLE …;`

To compare with production-shaped names, load `car_service_db` from the gzipped dump and run `SHOW CREATE TABLE suppliers\G` side by side with `demo_suppliers`.
