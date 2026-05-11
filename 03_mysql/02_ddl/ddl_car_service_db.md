# DDL (Data Definition Language) — `car_service_db` theme

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/02_ddl/ddl_car_service_db.md)

These exercises rehearse every **schema-shaping** command (`CREATE`, `ALTER`, `RENAME`, `DROP`, `TRUNCATE`, `CREATE VIEW`) on a **safe sandbox database** called `ddl_practice`. The domain mirrors what you see inside the real `01_database_mysql/car_service_db.sql.gz` dump (`suppliers`, `purchase_orders`, `parts`), but the demo tables are prefixed `demo_*` / `rel_*` so you **never touch** the real `car_service_db` while practising.

Two companion scripts back this lesson:

- [`02_ddl/car_service_ddl_examples.sql`](car_service_ddl_examples.sql) — broad DDL operations (Exercises 1–14)
- [`02_ddl/car_service_relationships_examples.sql`](car_service_relationships_examples.sql) — relationship-focused DDL (1:N, N:M, self-reference, FK actions)

```bash
mysql -u root < 03_mysql/02_ddl/car_service_ddl_examples.sql
mysql -u root < 03_mysql/02_ddl/car_service_relationships_examples.sql
```

Each script is **idempotent** — it drops every previous demo object before recreating it, so you can re-run them any number of times.

---

## DDL command map (MySQL 8 / 9)

| Statement | Role |
|---|---|
| `CREATE DATABASE` / `CREATE SCHEMA` | Define a namespace for objects |
| `CREATE TABLE` | Define a base relation: columns, keys, constraints, indexes |
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

### Context

The trainer wants every student to have a clean, isolated namespace for DDL labs — so we never collide with the real `car_service_db` or with somebody else's experiments.

### What you'll learn

- The difference (none, in MySQL) between `CREATE DATABASE` and `CREATE SCHEMA`.
- Setting `CHARACTER SET` and `COLLATE` at database level so every table inherits them.
- The `IF NOT EXISTS` guard for idempotent scripts.

### Tables in play

| Target | Role |
|---|---|
| (new database) `ddl_practice` | Sandbox namespace for every other DDL exercise |

### Task

Create a database named `ddl_practice` with `utf8mb4` / `utf8mb4_0900_ai_ci` settings. Skip silently if it already exists.

### Expected result (from `SHOW DATABASES LIKE 'ddl_practice'`)

```text
+----------------------------+
| Database (ddl_practice)    |
+----------------------------+
| ddl_practice               |
+----------------------------+
```

### Hint

Use `CREATE DATABASE IF NOT EXISTS …` followed by `USE …;` so subsequent statements default to the new database.

### Solution

```sql
CREATE DATABASE IF NOT EXISTS ddl_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE ddl_practice;
```

### Step-by-step explanation

1. **`CREATE DATABASE` ≡ `CREATE SCHEMA`** in MySQL — pick one and use it consistently. PostgreSQL distinguishes the two; MySQL does not.
2. **`utf8mb4_0900_ai_ci`** is the modern default: full UTF-8 (incl. emoji and most scripts), accent-insensitive, case-insensitive comparisons.
3. **`IF NOT EXISTS`** prevents the script from blowing up on the second run — a must-have when a script is re-run in class.
4. **`USE ddl_practice;`** changes the *current* schema for the session, so later `CREATE TABLE` statements live inside it without a fully-qualified name.

---

## Exercise 2 — `CREATE TABLE` with primary key and `AUTO_INCREMENT`

### Context

The first thing every shop-management system needs is a **suppliers** table — a place to track wholesalers that sell parts to the garage. The shop wants a surrogate integer id that grows automatically, just like `suppliers.id` in the production dump.

### What you'll learn

- Defining a surrogate `INT AUTO_INCREMENT PRIMARY KEY`.
- Picking sensible `VARCHAR` widths.
- The `TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP` audit column pattern.

### Tables in play

| Target | Columns |
|---|---|
| `demo_suppliers` (new) | `id`, `name`, `phone`, `created_at` |

### Task

Create `demo_suppliers` with an auto-increment integer primary key, a mandatory `name`, an optional `phone`, and an audit `created_at` defaulting to the row's insertion time.

### Expected result (from `SHOW CREATE TABLE demo_suppliers` after Exercise 7's index has been added)

```text
CREATE TABLE `demo_suppliers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `phone` varchar(32) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_demo_supplier_name` (`name`(20))
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

### Hint

`INT NOT NULL AUTO_INCREMENT`, `PRIMARY KEY (id)`, and the audit timestamp goes at the end.

### Solution

```sql
CREATE TABLE demo_suppliers (
  id            INT NOT NULL AUTO_INCREMENT,
  name          VARCHAR(100) NOT NULL,
  phone         VARCHAR(20) DEFAULT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Step-by-step explanation

1. **`AUTO_INCREMENT` is column-level**, but the column it lives on must be indexed. The `PRIMARY KEY` constraint provides that index automatically.
2. **`VARCHAR(100)`** is generous for supplier names but cheaper than `TEXT` — MySQL stores only the bytes actually written, so the upper bound is just a constraint, not a fixed footprint.
3. **`DEFAULT NULL`** explicitly states the column is optional; together with the absence of `NOT NULL` it documents intent. (Without `NOT NULL`, the default is `NULL` anyway.)
4. **`ENGINE=InnoDB`** enables transactions and foreign keys — the only correct choice for production tables.

---

## Exercise 3 — Child table with foreign key

### Context

Suppliers don't live in a vacuum: every wholesaler sends us **purchase orders**. The new `demo_purchase_orders` table must point back to `demo_suppliers` so we can enforce "every PO has a real supplier".

### What you'll learn

- Declaring a `FOREIGN KEY` constraint at table-create time.
- Choosing `ON UPDATE` / `ON DELETE` actions.
- Why the parent must be created first.

### Tables in play

| Target | Columns |
|---|---|
| `demo_suppliers` (parent, from Ex. 2) | `id` |
| `demo_purchase_orders` (new child) | `id`, `supplier_id`, `order_date` |

### Task

Create `demo_purchase_orders` referencing `demo_suppliers(id)`. Cascade updates to the foreign key, but **restrict** deletes — a supplier must not vanish while orders still reference it.

### Expected result (from `SHOW CREATE TABLE demo_purchase_orders`)

```text
CREATE TABLE `demo_purchase_orders` (
  `id` int NOT NULL AUTO_INCREMENT,
  `supplier_id` int NOT NULL,
  `order_date` date NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_demo_po_supplier` (`supplier_id`),
  KEY `idx_demo_po_order_date` (`order_date`),
  CONSTRAINT `fk_demo_po_supplier` FOREIGN KEY (`supplier_id`)
    REFERENCES `demo_suppliers` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB ...
```

### Hint

`CONSTRAINT name FOREIGN KEY (col) REFERENCES parent(col) ON UPDATE … ON DELETE …`.

### Solution

```sql
CREATE TABLE demo_purchase_orders (
  id            INT NOT NULL AUTO_INCREMENT,
  supplier_id   INT NOT NULL,
  order_date    DATE NOT NULL,
  PRIMARY KEY (id),
  KEY idx_demo_po_supplier (supplier_id),
  KEY idx_demo_po_order_date (order_date),
  CONSTRAINT fk_demo_po_supplier
    FOREIGN KEY (supplier_id) REFERENCES demo_suppliers (id)
      ON UPDATE CASCADE
      ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Step-by-step explanation

1. **The parent must exist first.** If `demo_suppliers` is not yet created, the `CONSTRAINT` fails with `errno: 150`.
2. **`KEY idx_demo_po_supplier (supplier_id)`** is explicit, but InnoDB would create one anyway — every FK column needs an index. Naming it yourself makes diagnostics easier.
3. **`ON UPDATE CASCADE`**: if a supplier's id ever changes, child rows follow. **`ON DELETE RESTRICT`** refuses the delete if children still exist — the safer default.
4. **Name your constraints.** Without `CONSTRAINT fk_…`, MySQL generates `demo_purchase_orders_ibfk_1`, which is meaningless in error messages.

---

## Exercise 4 — `UNIQUE` business key

### Context

A `parts` catalog uses **SKUs** as the business identifier — they go on stickers, invoices, and supplier orders. Two parts must never share a SKU.

### What you'll learn

- The difference between a surrogate `PRIMARY KEY` and a `UNIQUE` business key.
- Two syntaxes: column-level `UNIQUE` vs. table-level `UNIQUE KEY name (col)`.

### Tables in play

| Target | Columns |
|---|---|
| `demo_parts` (new) | `id`, `sku`, `name`, `brand` |

### Task

Create `demo_parts`. Make `sku` unique and named (`uk_demo_parts_sku`).

### Expected result (from `SHOW CREATE TABLE demo_catalog_parts` — same table, renamed in Ex. 11)

```text
CREATE TABLE `demo_catalog_parts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `sku` varchar(50) NOT NULL,
  `name` varchar(200) NOT NULL,
  `brand` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_demo_parts_sku` (`sku`)
) ENGINE=InnoDB ...
```

### Hint

Either `sku VARCHAR(50) NOT NULL UNIQUE` or, table-level, `UNIQUE KEY uk_demo_parts_sku (sku)`.

### Solution

```sql
CREATE TABLE demo_parts (
  id            INT NOT NULL AUTO_INCREMENT,
  sku           VARCHAR(50) NOT NULL,
  name          VARCHAR(200) NOT NULL,
  brand         VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_demo_parts_sku (sku)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Step-by-step explanation

1. **`PRIMARY KEY` ⊂ `UNIQUE`.** Every primary key is a unique key; the converse isn't true (`UNIQUE` columns can be `NULL`, primary keys can't).
2. **Table-level form is preferred when you want to name the constraint** — error messages then read `Duplicate entry 'X' for key 'uk_demo_parts_sku'`, which immediately points to the right line in the schema.
3. **`UNIQUE` columns auto-index**, so lookups by `sku` are O(log n) without any extra `CREATE INDEX`.

---

## Exercise 5 — `DEFAULT` and `NOT NULL`

### Context

Every line of a purchase order should be **inserted with sensible defaults**: tax flag on, price 0 if not provided, audit timestamp filled by the server. This keeps the application code simple and prevents `NULL`-related bugs.

### What you'll learn

- `DEFAULT` literal values for booleans, numbers, dates.
- `DEFAULT CURRENT_TIMESTAMP` for `DATETIME` / `TIMESTAMP`.
- Why `NOT NULL` + `DEFAULT` is the safer pair than nullable columns.

### Tables in play

| Target | Columns |
|---|---|
| `demo_po_lines` (new) | `id`, `po_id`, `part_id`, `quantity`, `unit_price`, `is_taxable`, `inserted_at` |

### Task

Create `demo_po_lines` linked to both `demo_purchase_orders` (parent) and `demo_parts` (catalog). `unit_price` defaults to `0.00`, `is_taxable` to `1`, `inserted_at` to "now".

### Expected result (from `SHOW CREATE TABLE demo_po_lines`)

```text
CREATE TABLE `demo_po_lines` (
  `id` int NOT NULL AUTO_INCREMENT,
  `po_id` int NOT NULL,
  `part_id` int NOT NULL,
  `quantity` int NOT NULL,
  `unit_price` decimal(10,2) NOT NULL DEFAULT '0.00',
  `is_taxable` tinyint(1) NOT NULL DEFAULT '1',
  `inserted_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  ...
  CONSTRAINT `chk_demo_po_lines_price` CHECK ((`unit_price` >= 0)),
  CONSTRAINT `chk_demo_po_lines_qty` CHECK ((`quantity` > 0))
) ENGINE=InnoDB ...
```

### Hint

`unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.00`, `inserted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`.

### Solution

```sql
CREATE TABLE demo_po_lines (
  id            INT NOT NULL AUTO_INCREMENT,
  po_id         INT NOT NULL,
  part_id       INT NOT NULL,
  quantity      INT NOT NULL,
  unit_price    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  is_taxable    TINYINT(1) NOT NULL DEFAULT 1,
  inserted_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_demo_po_lines_po (po_id),
  KEY idx_demo_po_lines_part (part_id),
  CONSTRAINT fk_demo_line_po
    FOREIGN KEY (po_id) REFERENCES demo_purchase_orders (id)
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_demo_line_part
    FOREIGN KEY (part_id) REFERENCES demo_parts (id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_demo_po_lines_qty CHECK (quantity > 0),
  CONSTRAINT chk_demo_po_lines_price CHECK (unit_price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Step-by-step explanation

1. **`DECIMAL(10,2)`** stores monetary amounts exactly (no binary-float rounding). Up to 8 digits before the decimal point, 2 after.
2. **`TINYINT(1)`** is MySQL's traditional spelling of a "boolean" — the `(1)` is purely a display hint; storage is one byte regardless.
3. **`DEFAULT CURRENT_TIMESTAMP`** evaluates at insert time, so the value is the server's clock when the row was created. Add `ON UPDATE CURRENT_TIMESTAMP` if you want a "last modified" timestamp instead.
4. **`NOT NULL DEFAULT 0.00`** is safer than nullable: queries don't need `COALESCE`; reports never accidentally treat missing prices as `NULL` and lose them in `SUM`.

---

## Exercise 6 — `CHECK` constraint (MySQL 8.0.16+)

### Context

A purchase-order line with `quantity = 0` or `unit_price < 0` is meaningless — and likely a UI bug or a fraud attempt. We want the database itself to refuse such rows, regardless of whose application sent them.

### What you'll learn

- `CHECK (predicate)` declared inline with the table.
- That MySQL only enforces `CHECK` from version 8.0.16 onward (older versions parse it and silently ignore it).

### Tables in play

| Target | Columns |
|---|---|
| `demo_po_lines` | `quantity`, `unit_price` |

### Task

Add two `CHECK` constraints to `demo_po_lines`: `quantity > 0` and `unit_price >= 0`.

### Expected result (relevant lines of `SHOW CREATE TABLE demo_po_lines`)

```text
CONSTRAINT `chk_demo_po_lines_price` CHECK ((`unit_price` >= 0)),
CONSTRAINT `chk_demo_po_lines_qty`   CHECK ((`quantity` > 0))
```

### Hint

Add `CONSTRAINT name CHECK (predicate)` either inside `CREATE TABLE` or via `ALTER TABLE … ADD CONSTRAINT …`.

### Solution

```sql
-- inline (used in the script):
CONSTRAINT chk_demo_po_lines_qty   CHECK (quantity > 0),
CONSTRAINT chk_demo_po_lines_price CHECK (unit_price >= 0)
```

### Step-by-step explanation

1. **Always name the constraint.** Otherwise a violation reads `Check constraint 'demo_po_lines_chk_1' is violated`, which forces you back to the schema to figure out what it meant.
2. **A `CHECK` predicate can reference only the row it sits on.** Cross-row or cross-table invariants need a `TRIGGER` or application logic.
3. **MySQL 8.0.16+** enforces `CHECK`. Earlier 8.0 and all 5.x versions accept the syntax silently — a long-standing gotcha to verify with `SHOW WARNINGS`.

---

## Exercise 7 — Secondary index for lookups

### Context

A weekly report scans `demo_suppliers` by company name (or its prefix). To keep that lookup fast even as the table grows, we add a **non-unique secondary index** on the first 20 characters of `name`.

### What you'll learn

- `ALTER TABLE … ADD INDEX`.
- The **prefix index** form `(col(20))` for long `VARCHAR` columns.

### Tables in play

| Target | Columns |
|---|---|
| `demo_suppliers` | `name` |

### Task

Add a non-unique index named `idx_demo_supplier_name` on the first 20 characters of `demo_suppliers.name`.

### Expected result (relevant line of `SHOW CREATE TABLE demo_suppliers`)

```text
KEY `idx_demo_supplier_name` (`name`(20))
```

### Hint

`ALTER TABLE demo_suppliers ADD INDEX idx_demo_supplier_name (name(20));`

### Solution

```sql
ALTER TABLE demo_suppliers ADD INDEX idx_demo_supplier_name (name(20));
```

### Step-by-step explanation

1. **`ADD INDEX` vs `CREATE INDEX`** do the same thing; `ALTER TABLE … ADD INDEX …` is the canonical form because you can add several things in one statement.
2. **Prefix indexes** (`name(20)`) make the index smaller (and so faster) while still serving `WHERE name LIKE 'Demo%'` lookups. They cannot serve `ORDER BY name`.
3. **Don't index every column.** Every index slows down `INSERT`/`UPDATE` and consumes disk; pick those that match real query patterns.

---

## Exercise 8 — `ALTER TABLE` — add a column

### Context

Customer support needs a free-form `notes` field on suppliers — a place for "talk to Petro about consolidated invoices" type reminders. The table already has data, so we use `ALTER`.

### What you'll learn

- `ALTER TABLE … ADD COLUMN` syntax.
- The `AFTER col` positional hint.
- That MySQL 8 uses **instant** `ADD COLUMN` for trailing columns — adding the column does not rewrite the table.

### Tables in play

| Target | Columns |
|---|---|
| `demo_suppliers` | (adds) `notes` |

### Task

Add an optional `notes TEXT` column to `demo_suppliers` right after `phone`.

### Expected result (`DESC demo_suppliers` after Exercise 8 — and *before* Exercise 10 drops it)

```text
+------------+--------------+------+-----+-------------------+-------------------+
| Field      | Type         | Null | Key | Default           | Extra             |
+------------+--------------+------+-----+-------------------+-------------------+
| id         | int          | NO   | PRI | NULL              | auto_increment    |
| name       | varchar(100) | NO   | MUL | NULL              |                   |
| phone      | varchar(20)  | YES  |     | NULL              |                   |
| notes      | text         | YES  |     | NULL              |                   |
| created_at | timestamp    | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
+------------+--------------+------+-----+-------------------+-------------------+
```

### Hint

`ALTER TABLE demo_suppliers ADD COLUMN notes TEXT NULL AFTER phone;`

### Solution

```sql
ALTER TABLE demo_suppliers
  ADD COLUMN notes TEXT NULL AFTER phone;
```

### Step-by-step explanation

1. **`AFTER phone`** positions the column visually in `DESC` output; functionally MySQL stores columns in declaration order, so this affects `SELECT *` ordering and exports.
2. **`TEXT NULL`**: `TEXT` is variable-length, capable of storing up to 64 KB. Allow `NULL` because most existing supplier rows have no note.
3. **Instant `ADD COLUMN`** (MySQL 8.0.12+) means this `ALTER` is metadata-only — no table rewrite, no minutes-long lock. Adding non-trailing columns or `NOT NULL` columns without a default may still rebuild the table.

---

## Exercise 9 — `ALTER TABLE` — change column type or nullability

### Context

International suppliers have long phone numbers (`+44 (0)20 7946 0xxx`); the original `VARCHAR(20)` is too narrow. We widen it without losing data.

### What you'll learn

- `MODIFY COLUMN` (changes the type) vs. `CHANGE COLUMN` (renames *and* retypes).
- Widening is always safe; narrowing can truncate.

### Tables in play

| Target | Columns |
|---|---|
| `demo_suppliers` | `phone` |

### Task

Widen `demo_suppliers.phone` from `VARCHAR(20)` to `VARCHAR(32)`, keeping it nullable.

### Expected result (`DESC demo_suppliers` after the widening)

```text
+------------+--------------+------+-----+-------------------+-------------------+
| Field      | Type         | Null | Key | Default           | Extra             |
+------------+--------------+------+-----+-------------------+-------------------+
| id         | int          | NO   | PRI | NULL              | auto_increment    |
| name       | varchar(100) | NO   | MUL | NULL              |                   |
| phone      | varchar(32)  | YES  |     | NULL              |                   |
| created_at | timestamp    | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
+------------+--------------+------+-----+-------------------+-------------------+
```

### Hint

`ALTER TABLE demo_suppliers MODIFY COLUMN phone VARCHAR(32) NULL;`

### Solution

```sql
ALTER TABLE demo_suppliers
  MODIFY COLUMN phone VARCHAR(32) NULL;
```

### Step-by-step explanation

1. **`MODIFY COLUMN`** keeps the column's name and changes its data type / nullability / default.
2. **Use `CHANGE COLUMN`** to rename *and* retype: `ALTER TABLE t CHANGE COLUMN old_name new_name VARCHAR(50)`.
3. **Narrowing is risky.** Going from `VARCHAR(50)` to `VARCHAR(10)` truncates every existing value; MySQL warns but doesn't refuse unless you set `sql_mode = STRICT_*`.

---

## Exercise 10 — `ALTER TABLE` — drop a column

### Context

After a process review the shop decides notes belong in a CRM, not in the suppliers table. Remove the column to keep the schema lean.

### What you'll learn

- `DROP COLUMN` syntax.
- Why dropping a column is destructive and irreversible.

### Tables in play

| Target | Columns |
|---|---|
| `demo_suppliers` | (removes) `notes` |

### Task

Drop the `notes` column added in Exercise 8.

### Expected result (`DESC demo_suppliers` after the drop — final shape used in the script)

```text
+------------+--------------+------+-----+-------------------+-------------------+
| Field      | Type         | Null | Key | Default           | Extra             |
+------------+--------------+------+-----+-------------------+-------------------+
| id         | int          | NO   | PRI | NULL              | auto_increment    |
| name       | varchar(100) | NO   | MUL | NULL              |                   |
| phone      | varchar(32)  | YES  |     | NULL              |                   |
| created_at | timestamp    | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
+------------+--------------+------+-----+-------------------+-------------------+
```

### Hint

`ALTER TABLE demo_suppliers DROP COLUMN notes;`

### Solution

```sql
ALTER TABLE demo_suppliers
  DROP COLUMN notes;
```

### Step-by-step explanation

1. **Data is permanently lost.** Always export or back up before dropping a column.
2. **Indexes that referenced the column are dropped too** — MySQL takes care of the cleanup.
3. **A column can't be dropped while it's still part of a foreign-key constraint.** Drop or alter the constraint first.

---

## Exercise 11 — `RENAME TABLE`

### Context

The team feels `demo_parts` is too generic; they want `demo_catalog_parts` to make the table's role obvious. Renaming should be cheap — no data copy.

### What you'll learn

- `RENAME TABLE old TO new` is a near-instant metadata operation.
- That foreign keys pointing **to** the renamed table keep working — InnoDB tracks tables by id, not by name.

### Tables in play

| Target | New name |
|---|---|
| `demo_parts` | `demo_catalog_parts` |

### Task

Rename `demo_parts` to `demo_catalog_parts`. Verify the foreign key from `demo_po_lines` still works.

### Expected result (`SHOW TABLES` after the rename)

```text
+------------------------+
| Tables_in_ddl_practice |
+------------------------+
| demo_catalog_parts     |
| demo_po_lines          |
| demo_purchase_orders   |
| demo_scratch_log       |
| demo_suppliers         |
| v_demo_supplier_orders |
+------------------------+
```

### Hint

`RENAME TABLE demo_parts TO demo_catalog_parts;`

### Solution

```sql
RENAME TABLE demo_parts TO demo_catalog_parts;

-- Verify the child FK was updated automatically:
SHOW CREATE TABLE demo_po_lines\G
```

### Step-by-step explanation

1. **`RENAME` is atomic and fast.** Internally it changes the table's directory entry; no data is touched.
2. **Foreign keys are updated transparently.** Running `SHOW CREATE TABLE demo_po_lines` after the rename shows the FK now references `demo_catalog_parts`.
3. **You can rename several tables in one statement** (`RENAME TABLE a TO b, b TO a, ...` — handy for atomic swaps).

---

## Exercise 12 — `DROP TABLE` order and cleanup

### Context

After a teaching session you want to leave a clean sandbox so the next student starts fresh. Children must go first; otherwise the foreign keys refuse the parent drop.

### What you'll learn

- The dependency order: child → parent.
- `SET foreign_key_checks = 0` as a deliberate override (with `= 1` to restore).

### Tables in play

| Target | Dropped |
|---|---|
| (multiple) | `demo_po_lines`, `demo_purchase_orders`, `demo_catalog_parts`, `demo_scratch_log`, `demo_suppliers` |

### Task

Provide a clean teardown sequence (commented out at the bottom of the script so it doesn't run by default).

### Expected result

After running the teardown block, `SHOW TABLES;` returns only `rel_*` tables (from the relationships lab) or no tables at all.

### Hint

Drop in reverse order, or temporarily set `foreign_key_checks = 0`.

### Solution

```sql
SET foreign_key_checks = 0;
DROP TABLE IF EXISTS demo_po_lines;
DROP TABLE IF EXISTS demo_purchase_orders;
DROP VIEW  IF EXISTS v_demo_supplier_orders;
DROP TABLE IF EXISTS demo_catalog_parts;
DROP TABLE IF EXISTS demo_scratch_log;
DROP TABLE IF EXISTS demo_suppliers;
SET foreign_key_checks = 1;
-- Optional full reset:
-- DROP DATABASE IF EXISTS ddl_practice;
```

### Step-by-step explanation

1. **`IF EXISTS`** stops MySQL from raising an error when a table is already gone — vital for re-runnable scripts.
2. **`SET foreign_key_checks = 0`** is a session-scoped switch; turn it back on right after the bulk drop so subsequent statements get full referential integrity.
3. **`DROP DATABASE`** removes *everything* in one shot — fast and dangerous. Use only on disposable sandboxes.

---

## Exercise 13 — `CREATE VIEW` (named definition)

### Context

Reporting wants a simple "supplier ↔ purchase order" join that BI tools can query without knowing the underlying schema. A view freezes the join behind a stable name.

### What you'll learn

- `CREATE OR REPLACE VIEW … AS SELECT …` for idempotent definitions.
- That `LEFT JOIN` keeps suppliers with no purchase orders visible in the view.

### Tables in play

| Target | Source tables |
|---|---|
| `v_demo_supplier_orders` (view) | `demo_suppliers`, `demo_purchase_orders` |

### Task

Create or replace a view that returns supplier id, name, and (per matching row) purchase order id and date.

### Expected result (`SELECT * FROM v_demo_supplier_orders;` after seed data)

```text
+-------------+----------------------+-------------------+------------+
| supplier_id | supplier_name        | purchase_order_id | order_date |
+-------------+----------------------+-------------------+------------+
|           1 | Demo Parts Wholesale |                 1 | 2026-01-15 |
+-------------+----------------------+-------------------+------------+
```

### Hint

`CREATE OR REPLACE VIEW v_demo_supplier_orders AS SELECT … FROM … LEFT JOIN … ON … ;`

### Solution

```sql
CREATE OR REPLACE VIEW v_demo_supplier_orders AS
SELECT s.id   AS supplier_id,
       s.name AS supplier_name,
       po.id  AS purchase_order_id,
       po.order_date
FROM demo_suppliers AS s
LEFT JOIN demo_purchase_orders AS po ON po.supplier_id = s.id;
```

### Step-by-step explanation

1. **`OR REPLACE`** lets the script re-run; without it the second run fails with "view already exists".
2. **`LEFT JOIN`** keeps suppliers with zero purchase orders. Switch to `INNER JOIN` if you only want "active" suppliers.
3. **Views are not stored as materialised tables** in MySQL — every query against them is rewritten into the underlying join. Materialised views require periodic `CREATE TABLE AS SELECT` refreshes.

---

## Exercise 14 — `TRUNCATE` (optional lab)

### Context

A `demo_scratch_log` table accumulates throwaway diagnostic messages during practice. We want to wipe it instantly — `DELETE` would scan every row.

### What you'll learn

- `TRUNCATE TABLE` is a DDL-flavoured fast wipe (it requires the `DROP` privilege).
- It **resets** `AUTO_INCREMENT` to the seed; `DELETE` does not.
- It cannot run if other tables reference it via FK.

### Tables in play

| Target | Columns |
|---|---|
| `demo_scratch_log` | (all rows removed) |

### Task

Insert a "before truncate" message into `demo_scratch_log`, then truncate it. Verify the table is empty.

### Expected result (`SELECT * FROM demo_scratch_log;` after truncate)

```text
Empty set (0.00 sec)
```

### Hint

`TRUNCATE TABLE demo_scratch_log;`

### Solution

```sql
INSERT INTO demo_scratch_log (message) VALUES ('before truncate');
TRUNCATE TABLE demo_scratch_log;
```

### Step-by-step explanation

1. **`TRUNCATE` ≈ `DROP + CREATE`** internally — that's why it requires the `DROP` privilege and resets auto-increment.
2. **`TRUNCATE` is not transactional.** Even inside `START TRANSACTION` / `ROLLBACK` it can't be undone.
3. **FK guard.** If any other table has a `FOREIGN KEY` pointing **to** this one, `TRUNCATE` is refused; fall back to `DELETE` (which can leave dangling FKs alone) or drop the FK temporarily.

---

## Relationship lab — `car_service_relationships_examples.sql`

### Context

The relationships script builds, in one pass, every classic FK shape you meet in real schemas: parent → child, self-reference, many-to-many. It's the perfect drill for thinking about **what the data model implies**.

### What you'll learn

- `1:N` parent ↔ child (`rel_customers` → `rel_work_orders`).
- Self-reference for hierarchies (`rel_technicians.manager_id`).
- `N:M` via a bridge table with a composite PK (`rel_order_parts`).
- The three FK actions — `RESTRICT`, `SET NULL`, `CASCADE` — and which to pick when.

### Tables in play

| Table | Role |
|---|---|
| `rel_customers` | Parent (customers) |
| `rel_technicians` | Self-referencing (each tech may have a manager who is also a tech) |
| `rel_work_orders` | Child of `rel_customers`, optional child of `rel_technicians` |
| `rel_parts` | Reference table (parts catalog) |
| `rel_order_parts` | N:M bridge between `rel_work_orders` and `rel_parts` |

### Task

Run the script; verify the join over all five tables.

### Expected result (final verification query from the script)

```text
+---------------+------------------+-------------------+-------------+------------------------+-----+
| work_order_id | customer         | technician        | sku         | part_name              | qty |
+---------------+------------------+-------------------+-------------+------------------------+-----+
|             1 | Olena Kovalenko  | Iryna Lead Tech   | BRK-PAD-01  | Front brake pad set    |   1 |
|             1 | Olena Kovalenko  | Iryna Lead Tech   | OIL-5W30-4L | Synthetic oil 5W-30 4L |   1 |
|             2 | Maksym Danylchuk | Taras Junior Tech | OIL-5W30-4L | Synthetic oil 5W-30 4L |   1 |
+---------------+------------------+-------------------+-------------+------------------------+-----+
```

### Hint

The five tables join in a chain: `rel_work_orders → rel_customers`, `rel_work_orders → rel_technicians` (left, optional), `rel_work_orders → rel_order_parts → rel_parts`.

### Solution

```sql
SELECT wo.id          AS work_order_id,
       c.full_name    AS customer,
       t.tech_name    AS technician,
       p.sku,
       p.part_name,
       op.qty
FROM rel_work_orders AS wo
JOIN rel_customers     AS c  ON c.id  = wo.customer_id
LEFT JOIN rel_technicians AS t  ON t.id  = wo.technician_id
JOIN rel_order_parts   AS op ON op.work_order_id = wo.id
JOIN rel_parts         AS p  ON p.id  = op.part_id
ORDER BY wo.id, p.id;
```

### Step-by-step explanation

1. **`LEFT JOIN rel_technicians`** keeps work orders that are not yet assigned to a technician. The FK action for `technician_id` is `ON DELETE SET NULL`, matching this semantics.
2. **Composite PK `(work_order_id, part_id)`** on `rel_order_parts` makes the same (order, part) combo impossible twice — change quantity instead of inserting again.
3. **FK action choice cheat-sheet:**
   - **`CASCADE`** — child rows go away with the parent (typical for owned line items: `demo_po_lines` ↔ `demo_purchase_orders`).
   - **`RESTRICT`** — refuse to delete the parent while children exist (safer default for catalog rows).
   - **`SET NULL`** — child stays but loses the link (useful for optional links like a technician on a work order).

---

## Troubleshooting: my DDL failed

| Symptom | Likely fix |
|---|---|
| `Cannot add foreign key constraint` (`errno: 150`) | The parent table doesn't exist, or the column types differ (e.g. `INT` vs `BIGINT`). |
| `Cannot delete or update a parent row` | A child still references this row. Drop / update children first, or switch FK action. |
| `Duplicate entry … for key 'PRIMARY'` | You tried to insert a row whose PK already exists. Use `INSERT IGNORE` or `ON DUPLICATE KEY UPDATE`. |
| `Specified key was too long` | The `VARCHAR` is too big for an indexed column under `utf8mb4`. Use a prefix index: `KEY (col(191))`. |
| `Check constraint … is violated` | A row violates a `CHECK`. Adjust the row or drop the constraint. |

To run **both** scripts end-to-end: `mysql -u root < 03_mysql/02_ddl/car_service_ddl_examples.sql && mysql -u root < 03_mysql/02_ddl/car_service_relationships_examples.sql`.
