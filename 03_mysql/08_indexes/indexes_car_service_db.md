# Indexes — `car_service_db` lab

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/08_indexes/indexes_car_service_db.md)

This module adds a **practice table `idx_lab`** (and a tiny `idx_geo` for `SPATIAL`) inside **`car_service_db`**. You will **`CREATE INDEX`** / **`DROP INDEX`** by hand, then compare query plans and timings **with vs without** the index. The plan-comparison loop is the whole point — that's how you learn whether MySQL actually used your index.

Runnable companion file: [`08_indexes/car_service_indexes_examples.sql`](car_service_indexes_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/08_indexes/car_service_indexes_examples.sql
```

**Requirements:** MySQL **8.0+** (needed for functional indexes, `EXPLAIN ANALYZE`, descending indexes). All EXPLAIN output below was captured on the same `idx_lab` (40 000 rows seeded from `parts`).

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | A realistic workshop scenario for this index. |
| **What you'll learn** | Index kind and the access pattern it improves. |
| **Tables in play** | The lab table (`idx_lab` or `idx_geo`) and the relevant column. |
| **Task** | The SQL you must run (`CREATE INDEX`, then the test query). |
| **Expected result** | Real `EXPLAIN` (before / after) from a live `mysql` run. |
| **Hint** | Which `EXPLAIN` column tells you the index was used. |
| **Solution** | The full SQL block: index creation, test query, optional drop. |
| **Step-by-step explanation** | Why the access type changed and the typical gotchas. |

---

## How to compare speed manually

1. Run the **baseline** `EXPLAIN` / `EXPLAIN ANALYZE` **before** creating a secondary index.
2. Run the matching **`CREATE INDEX`** (or uncomment it in the script).
3. Run the **same `SELECT`** again and compare:
   - **`EXPLAIN`** `type` should move from **`ALL`** (full scan) toward **`ref`**, **`range`**, or **`const`**.
   - **`EXPLAIN ANALYZE`** (8.0.18+) shows actual time and rows read — much more useful for "is it really faster?"
4. To re-test a cold scan, drop the index and re-run:
   ```sql
   DROP INDEX ix_bt_ref ON idx_lab;
   ```
5. Optional after bulk load or many DML changes: `ANALYZE TABLE idx_lab;`.

**Note:** `SHOW PROFILES` / `profiling` are deprecated in recent MySQL versions; prefer **`EXPLAIN ANALYZE`** where available.

---

## Index types demonstrated (MySQL / InnoDB)

| Kind | In script | Typical use |
|------|-----------|-------------|
| **Primary key** | `PRIMARY KEY (id)` | Clustered B-tree; unique row id. |
| **Secondary B-tree** | `CREATE INDEX ix_bt_ref ON idx_lab (ref_num)` | Equality and range on `ref_num`. |
| **UNIQUE** | `CREATE UNIQUE INDEX ix_uniq_sku ON idx_lab (sku)` | One row per SKU; values must stay unique. |
| **Composite** | `(status, ref_num)` | Filters on leading column plus range on next. |
| **Prefix** | `sku(16)` on long `VARCHAR` | Index only the left N characters; saves space. |
| **FULLTEXT** | `FULLTEXT (note)` | `MATCH(note) AGAINST(...)` ranked search. |
| **Functional / expression** (8.0.13+) | `(LOWER(sku))` | Equality on a computed expression. |
| **SPATIAL** | `POINT` + `SPATIAL INDEX` on `idx_geo` | `MBRContains`, `ST_Within`, etc. |

**Not included (rare in app DBs):** `HASH` (only `MEMORY` engine), descending and invisible indexes (covered in MySQL manual; optional here).

---

## Lab schema reset (run once)

```sql
DROP TABLE IF EXISTS idx_geo;
DROP TABLE IF EXISTS idx_lab;

CREATE TABLE idx_lab (
  id      INT NOT NULL AUTO_INCREMENT,
  ref_num INT NOT NULL,
  sku     VARCHAR(80) NOT NULL,
  note    TEXT,
  status  VARCHAR(20) NOT NULL DEFAULT 'open',
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO idx_lab (ref_num, sku, note, status)
SELECT p.id, p.sku, p.name, 'open'
FROM parts AS p
WHERE p.id BETWEEN 1 AND 40000;

SET @probe_ref := (SELECT ref_num FROM idx_lab WHERE id = 15000 LIMIT 1); -- 15000
SET @probe_sku := (SELECT sku     FROM idx_lab WHERE id = 15000 LIMIT 1); -- 'SKU-00015000'
```

40 000 rows, only `PRIMARY KEY` so far. Every "after" plan below is compared with this baseline.

---

## Exercise 1 — Secondary B-tree on `ref_num`

### Context

`idx_lab.ref_num` mirrors `parts.id` from the dump. A "lookup by part reference" query (`WHERE ref_num BETWEEN 15000 AND 15005`) is one of the most common shapes in a service shop UI.

### What you'll learn

- That `WHERE col BETWEEN x AND y` without an index does a **full table scan** (`type=ALL`).
- That a plain `CREATE INDEX … (col)` flips the plan to **range scan** (`type=range`).
- How to read the `key`, `key_len`, and `rows` columns of `EXPLAIN`.

### Tables in play

| Table | Column |
|---|---|
| `idx_lab` | `ref_num` |

### Task

1. Run `EXPLAIN` on the range query **before** creating any secondary index.
2. `CREATE INDEX ix_bt_ref ON idx_lab (ref_num);`.
3. Run the same `EXPLAIN` again.

### Expected result (real `EXPLAIN` output)

**Before** the index — `type=ALL`, ~40 000 rows scanned:

```text
+----+-------------+---------+------------+------+---------------+------+---------+------+-------+----------+-------------+
| id | select_type | table   | partitions | type | possible_keys | key  | key_len | ref  | rows  | filtered | Extra       |
+----+-------------+---------+------------+------+---------------+------+---------+------+-------+----------+-------------+
|  1 | SIMPLE      | idx_lab | NULL       | ALL  | NULL          | NULL | NULL    | NULL | 40000 |    11.11 | Using where |
+----+-------------+---------+------------+------+---------------+------+---------+------+-------+----------+-------------+
```

**After** `CREATE INDEX ix_bt_ref … (ref_num)` — `type=range`, 6 rows estimated:

```text
+----+-------------+---------+------------+-------+---------------+-----------+---------+------+------+----------+-----------------------+
| id | select_type | table   | partitions | type  | possible_keys | key       | key_len | ref  | rows | filtered | Extra                 |
+----+-------------+---------+------------+-------+---------------+-----------+---------+------+------+----------+-----------------------+
|  1 | SIMPLE      | idx_lab | NULL       | range | ix_bt_ref     | ix_bt_ref | 4       | NULL |    6 |   100.00 | Using index condition |
+----+-------------+---------+------------+-------+---------------+-----------+---------+------+------+----------+-----------------------+
```

Sample rows from the actual query:

```text
+-------+--------------+
| id    | sku          |
+-------+--------------+
| 15000 | SKU-00015000 |
| 15001 | SKU-00015001 |
| 15002 | SKU-00015002 |
| 15003 | SKU-00015003 |
| 15004 | SKU-00015004 |
+-------+--------------+
```

### Hint

`EXPLAIN`: look at `type`. `ALL` ⇒ table scan; `range` ⇒ index range scan; `ref` ⇒ equality lookup; `const` ⇒ primary-key/unique single-row.

### Solution

```sql
-- Baseline (no secondary index on ref_num yet)
EXPLAIN
SELECT id, sku FROM idx_lab WHERE ref_num BETWEEN 15000 AND 15005;

-- Create the index
CREATE INDEX ix_bt_ref ON idx_lab (ref_num);

-- Run the same EXPLAIN; you should now see type=range, key=ix_bt_ref
EXPLAIN
SELECT id, sku FROM idx_lab WHERE ref_num BETWEEN 15000 AND 15005;

SELECT id, sku FROM idx_lab WHERE ref_num BETWEEN 15000 AND 15005 LIMIT 5;

-- Optional: re-test the cold scan
-- DROP INDEX ix_bt_ref ON idx_lab;
```

### Step-by-step explanation

1. **`type=ALL`** means MySQL has to read every row and apply the `WHERE`. On 40 000 rows that's fast in absolute terms but slow per-row.
2. **`type=range`** is the goal for `BETWEEN` / `IN (…)` / `>=` queries — the index narrows the scan to the requested key range.
3. **`key_len=4`** matches `INT` (4 bytes). For variable-width columns you'd see something like `322` (= 80 chars × 4 bytes + 2 length bytes for `utf8mb4`).
4. **Without the index, `Extra=Using where`** means MySQL evaluates the predicate after fetching. With the index, **`Using index condition`** ("ICP") pushes the predicate into the storage engine — even fewer rows materialised.
5. **Cost trade-off:** indexes accelerate reads but slow down writes (every `INSERT` / `UPDATE` maintains the B-tree). Add indexes only for queries that actually run often.

---

## Exercise 2 — UNIQUE index on `sku`

### Context

Every SKU must be unique — that's a business rule. A `UNIQUE` index simultaneously enforces the constraint and makes equality lookups effectively `O(1)` (a B-tree probe + one row fetch).

### What you'll learn

- `UNIQUE` indexes both enforce uniqueness **and** speed up equality lookups.
- The `type=const` plan: MySQL knows the lookup returns at most one row.
- What happens if your data has duplicates (the `CREATE` fails).

### Tables in play

| Table | Column |
|---|---|
| `idx_lab` | `sku` |

### Task

1. `CREATE UNIQUE INDEX ix_uniq_sku ON idx_lab (sku);`.
2. Run `EXPLAIN` on a single-SKU lookup; check `type=const`.

### Expected result (real `EXPLAIN` output)

```text
+----+-------------+---------+------------+-------+---------------+-------------+---------+-------+------+----------+-------+
| id | select_type | table   | partitions | type  | possible_keys | key         | key_len | ref   | rows | filtered | Extra |
+----+-------------+---------+------------+-------+---------------+-------------+---------+-------+------+----------+-------+
|  1 | SIMPLE      | idx_lab | NULL       | const | ix_uniq_sku   | ix_uniq_sku | 322     | const |    1 |   100.00 | NULL  |
+----+-------------+---------+------------+-------+---------------+-------------+---------+-------+------+----------+-------+
```

The lookup returns exactly the matching row:

```text
+----+---------+
| id | ref_num |
+----+---------+
|  1 |       1 |
+----+---------+
```

### Hint

`type=const` is the best access type after `system` — it means MySQL identifies the target row by a unique key, treats it as a constant, and never needs to compare anything else.

### Solution

```sql
CREATE UNIQUE INDEX ix_uniq_sku ON idx_lab (sku);

EXPLAIN
SELECT id, ref_num FROM idx_lab WHERE sku = 'SKU-00015000';

SELECT id, ref_num FROM idx_lab WHERE sku = 'SKU-00015000';

-- Demonstrate: a duplicate insert is now rejected
-- INSERT INTO idx_lab (ref_num, sku, status) VALUES (99, 'SKU-00015000', 'open');
-- -> ERROR 1062 (23000): Duplicate entry 'SKU-00015000' for key 'idx_lab.ix_uniq_sku'

-- DROP INDEX ix_uniq_sku ON idx_lab;
```

### Step-by-step explanation

1. **`UNIQUE` is a constraint and an index at the same time.** Internally it's a B-tree with a uniqueness check at insert time.
2. **`type=const`** means MySQL treats the lookup as a one-row constant during optimisation — joins to other tables can build on this knowledge.
3. **`key_len=322`** comes from `VARCHAR(80)` with `utf8mb4` (`80 * 4 + 2` = 322 bytes max).
4. **Failure case:** if the data has duplicates, the `CREATE UNIQUE INDEX` errors with `Duplicate entry … for key …`. Clean up duplicates first, or fall back to `CREATE INDEX` (non-unique).
5. **Constraint side effect:** any future `INSERT` of a duplicate SKU is rejected automatically — uniqueness is enforced by the engine, not by the app.

---

## Exercise 3 — Composite index `(status, ref_num)`

### Context

The most common dashboard query in this dataset is "open tickets in a part-id range". A composite index whose **leading column is `status`** and whose **second column is `ref_num`** can answer both predicates from the index alone.

### What you'll learn

- Composite indexes are ordered: the **leftmost prefix** must appear in `WHERE` for the index to be useful.
- That the optimiser may pick the single-column `ix_bt_ref` if it estimates fewer rows — index choice is cost-based, not deterministic.

### Tables in play

| Table | Columns |
|---|---|
| `idx_lab` | `status`, `ref_num` |

### Task

1. `CREATE INDEX ix_comp_status_ref ON idx_lab (status, ref_num);`.
2. Run `EXPLAIN` on a query that filters on both columns.

### Expected result (real `EXPLAIN` output)

With both `ix_bt_ref` and `ix_comp_status_ref` available, MySQL picks the one it thinks is cheapest — here it goes for the range scan via the simpler `ix_bt_ref`:

```text
+----+-------------+---------+------------+-------+------------------------------+-----------+---------+------+------+----------+------------------------------------+
| id | select_type | table   | partitions | type  | possible_keys                | key       | key_len | ref  | rows | filtered | Extra                              |
+----+-------------+---------+------------+-------+------------------------------+-----------+---------+------+------+----------+------------------------------------+
|  1 | SIMPLE      | idx_lab | NULL       | range | ix_bt_ref,ix_comp_status_ref | ix_bt_ref | 4       | NULL |  501 |   100.00 | Using index condition; Using where |
+----+-------------+---------+------------+-------+------------------------------+-----------+---------+------+------+----------+------------------------------------+
```

A sample of the actual rows:

```text
+-------+--------------+---------+
| id    | sku          | ref_num |
+-------+--------------+---------+
| 10000 | SKU-00010000 |   10000 |
| 10001 | SKU-00010001 |   10001 |
| 10002 | SKU-00010002 |   10002 |
| 10003 | SKU-00010003 |   10003 |
| 10004 | SKU-00010004 |   10004 |
+-------+--------------+---------+
```

### Hint

`possible_keys` lists every candidate; `key` is the one actually used. To force the composite index, use `FORCE INDEX (ix_comp_status_ref)` (only for diagnosis).

### Solution

```sql
CREATE INDEX ix_comp_status_ref ON idx_lab (status, ref_num);

EXPLAIN
SELECT id, sku, ref_num
FROM idx_lab
WHERE status = 'open'
  AND ref_num BETWEEN 10000 AND 10500
LIMIT 50;

SELECT id, sku, ref_num
FROM idx_lab
WHERE status = 'open'
  AND ref_num BETWEEN 10000 AND 10500
LIMIT 5;

-- Diagnose: what happens if you force the composite index?
EXPLAIN
SELECT id, sku, ref_num
FROM idx_lab FORCE INDEX (ix_comp_status_ref)
WHERE status = 'open'
  AND ref_num BETWEEN 10000 AND 10500;

-- DROP INDEX ix_comp_status_ref ON idx_lab;
```

### Step-by-step explanation

1. **Leftmost-prefix rule.** A composite index on `(a, b)` accelerates queries on `a` alone or `a AND b`, but **not** on `b` alone — the B-tree is ordered by `a` first.
2. **In this lab all rows have `status='open'`.** With cardinality of 1, MySQL realises the composite index doesn't help discriminate and picks `ix_bt_ref` instead. Run `ANALYZE TABLE idx_lab;` after large data changes to refresh statistics.
3. **When does the composite shine?** When `status` is **selective** (e.g. only 5 % of rows are `cancelled`), the composite index lets MySQL skip 95 % of the table.
4. **Hint columns:** `possible_keys` shows all candidates, `key` shows the choice, `key_len` reveals how many leading columns of the composite were used (here 4 bytes means only the first int column, not both).

---

## Exercise 4 — Prefix index `sku(16)`

### Context

`sku` is `VARCHAR(80)` but the first 8-10 characters are already unique in our dataset. Indexing only the first 16 bytes saves disk space and memory while keeping lookup speed essentially the same.

### What you'll learn

- `(col(N))` syntax to index a **byte prefix** of a string column.
- The trade-off between space saved and selectivity lost.
- `Sub_part=16` in `SHOW INDEX FROM …`.

### Tables in play

| Table | Column |
|---|---|
| `idx_lab` | `sku` (first 16 chars) |

### Task

1. `CREATE INDEX ix_prefix_sku ON idx_lab (sku(16));`.
2. Inspect `SHOW INDEX FROM idx_lab` to confirm `Sub_part = 16`.

### Expected result (real `SHOW INDEX` output)

```text
+---------+------------+---------------+--------------+-------------+-----------+-------------+----------+--------+------+------------+
| Table   | Non_unique | Key_name      | Seq_in_index | Column_name | Collation | Cardinality | Sub_part | Packed | Null | Index_type |
+---------+------------+---------------+--------------+-------------+-----------+-------------+----------+--------+------+------------+
| idx_lab |          1 | ix_prefix_sku |            1 | sku         | A         |       39166 |       16 |   NULL |      | BTREE      |
+---------+------------+---------------+--------------+-------------+-----------+-------------+----------+--------+------+------------+
```

### Hint

`Sub_part` is the number of bytes indexed. `NULL` means the whole column.

### Solution

```sql
CREATE INDEX ix_prefix_sku ON idx_lab (sku(16));

SHOW INDEX FROM idx_lab WHERE Key_name = 'ix_prefix_sku';

-- Lookups still work; the index helps for equality and LIKE 'prefix%'
EXPLAIN
SELECT id FROM idx_lab WHERE sku LIKE 'SKU-000150%';

-- DROP INDEX ix_prefix_sku ON idx_lab;
```

### Step-by-step explanation

1. **`sku(16)`** indexes the first 16 bytes. With `utf8mb4` each character is up to 4 bytes — for ASCII SKUs the prefix is the literal first 16 characters.
2. **Selectivity check:** if `LEFT(sku, 16)` already collides for many rows, the prefix index is worse than no index. Compute `SELECT COUNT(DISTINCT LEFT(sku, 16)) / COUNT(*) FROM idx_lab;` and aim for a value close to 1.
3. **Coexistence:** prefix and full-column indexes can live side by side; the optimiser picks the cheaper one per query. Here we kept both `ix_uniq_sku` (full) and `ix_prefix_sku` (16 bytes).
4. **Why bother?** A full-column secondary index on `VARCHAR(80) utf8mb4` is 322 bytes per row. The prefix index is ~18 bytes per row — 18× smaller, fits more pages in memory.

---

## Exercise 5 — FULLTEXT index on `note`

### Context

The shop wants to search the `note` field (which stores part names) with ranked results — type a word, get matching rows ordered by relevance. That's what `MATCH(note) AGAINST(...)` does on top of a FULLTEXT index.

### What you'll learn

- Creating a FULLTEXT index with `ALTER TABLE … ADD FULLTEXT`.
- The `MATCH(col) AGAINST('word')` syntax (natural-language mode).
- That FULLTEXT returns a **relevance score** alongside rows.

### Tables in play

| Table | Column |
|---|---|
| `idx_lab` | `note` (`TEXT`) |

### Task

1. `ALTER TABLE idx_lab ADD FULLTEXT INDEX ix_ft_note (note);`.
2. Run `MATCH(note) AGAINST('Part_15000')` and inspect the score.

### Expected result (real query output)

```text
+-------+--------------+-------------------+
| id    | sku          | score             |
+-------+--------------+-------------------+
| 15000 | SKU-00015000 | 21.16303825378418 |
+-------+--------------+-------------------+
```

And `SHOW INDEX` confirms the index type:

```text
+---------+------------+------------+--------------+-------------+------------+
| Table   | Non_unique | Key_name   | Seq_in_index | Column_name | Index_type |
+---------+------------+------------+--------------+-------------+------------+
| idx_lab |          1 | ix_ft_note |            1 | note        | FULLTEXT   |
+---------+------------+------------+--------------+-------------+------------+
```

### Hint

Use the same expression in both `SELECT` (to expose the score) and `WHERE` (so the predicate is satisfied).

### Solution

```sql
ALTER TABLE idx_lab
  ADD FULLTEXT INDEX ix_ft_note (note);

SELECT id,
       sku,
       MATCH(note) AGAINST('Part_15000') AS score
FROM idx_lab
WHERE MATCH(note) AGAINST('Part_15000')
LIMIT 5;

-- Boolean mode: phrase, negation, prefix
-- SELECT id FROM idx_lab WHERE MATCH(note) AGAINST('+Part* -Brand' IN BOOLEAN MODE);

-- DROP the FULLTEXT index:
-- ALTER TABLE idx_lab DROP INDEX ix_ft_note;
```

### Step-by-step explanation

1. **Natural-language mode (default)** ranks rows by `score`. The number `21.16…` is the term frequency × inverse document frequency calculation — higher means better match.
2. **Stopwords and minimum token length** can hide results. InnoDB's default minimum token length is 3 characters; words shorter than that are ignored. Tune via `innodb_ft_min_token_size`.
3. **Boolean mode** (`AGAINST('+word -bad' IN BOOLEAN MODE)`) supports `+` (must), `-` (must-not), `*` (suffix wildcard), `"phrase"`.
4. **Where it doesn't shine:** exact identifier lookups like `SKU-00015000` — for that, a plain B-tree on `sku` is faster and exact.
5. **`DROP`:** older MySQL versions sometimes won't drop a FULLTEXT index with `DROP INDEX`; use `ALTER TABLE … DROP INDEX` as a safe fallback.

---

## Exercise 6 — Functional / expression index `(LOWER(sku))`

### Context

The catalog search is case-insensitive: users type `sku-00015000`, the DB stores `SKU-00015000`. Without an index on the **expression** `LOWER(sku)`, every query has to scan the table to lowercase each row. A functional index pre-computes the lowercased value.

### What you'll learn

- `CREATE INDEX … ((expr))` (note the double parentheses — required since MySQL 8.0.13).
- The optimiser matches the exact expression: `LOWER(sku)` in `WHERE` must match `(LOWER(sku))` in the index definition.

### Tables in play

| Table | Expression |
|---|---|
| `idx_lab` | `LOWER(sku)` |

### Task

1. `CREATE INDEX ix_func_lower_sku ON idx_lab ((LOWER(sku)));`.
2. `EXPLAIN` a case-insensitive equality query.

### Expected result (real `EXPLAIN` output)

```text
+----+-------------+---------+------------+------+-------------------+-------------------+---------+-------+------+----------+-------+
| id | select_type | table   | partitions | type | possible_keys     | key               | key_len | ref   | rows | filtered | Extra |
+----+-------------+---------+------------+------+-------------------+-------------------+---------+-------+------+----------+-------+
|  1 | SIMPLE      | idx_lab | NULL       | ref  | ix_func_lower_sku | ix_func_lower_sku | 323     | const |    1 |   100.00 | NULL  |
+----+-------------+---------+------------+------+-------------------+-------------------+---------+-------+------+----------+-------+
```

Sample row:

```text
+-------+--------------+
| id    | sku          |
+-------+--------------+
| 15000 | SKU-00015000 |
+-------+--------------+
```

### Hint

`type=ref` plus `key=ix_func_lower_sku` is exactly what you want. If the optimiser still does `ALL`, the expression in `WHERE` doesn't match the indexed expression character-for-character.

### Solution

```sql
CREATE INDEX ix_func_lower_sku ON idx_lab ((LOWER(sku)));

EXPLAIN
SELECT id FROM idx_lab WHERE LOWER(sku) = 'sku-00015000';

SELECT id, sku FROM idx_lab WHERE LOWER(sku) = 'sku-00015000';

-- DROP INDEX ix_func_lower_sku ON idx_lab;
```

### Step-by-step explanation

1. **Double parentheses required.** `CREATE INDEX … (LOWER(sku))` is a syntax error — MySQL parses it as a list of columns. The extra `(())` says "this is an expression".
2. **Expression match must be exact.** `WHERE LOWER(sku) = …` uses the index; `WHERE LOWER(sku || '')` does not. Even constant folding differences can throw the match off.
3. **Alternative — generated columns.** Older MySQL versions get the same behaviour by adding a `STORED` or `VIRTUAL` generated column and indexing that.
4. **Side effect:** writes are now slightly slower because MySQL must recompute and store the lowercase version into the index B-tree.

---

## Exercise 7 — SPATIAL index on `POINT`

### Context

A delivery dispatcher wants the customer locations inside a bounding box (e.g. "everything west of Lviv and north of Kyiv"). MySQL's spatial features rely on a SPATIAL index over a `POINT` column with an SRID.

### What you'll learn

- Creating a `POINT NOT NULL SRID 4326` column and a SPATIAL index on it.
- Filtering with `MBRContains(polygon, point)` for fast bounding-box checks.
- Reading the `range` plan that the spatial index produces.

### Tables in play

| Table | Column |
|---|---|
| `idx_geo` | `g POINT NOT NULL SRID 4326` |

### Task

1. Create `idx_geo` with a `SPATIAL INDEX` on `g`.
2. Seed it from `idx_lab` (`l.id <= 500`).
3. Run an `MBRContains` filter and EXPLAIN it.

### Expected result (real `EXPLAIN` output)

```text
+----+-------------+---------+------------+-------+---------------+--------------+---------+------+------+----------+-------------+
| id | select_type | table   | partitions | type  | possible_keys | key          | key_len | ref  | rows | filtered | Extra       |
+----+-------------+---------+------------+-------+---------------+--------------+---------+------+------+----------+-------------+
|  1 | SIMPLE      | idx_geo | NULL       | range | ix_spatial_g  | ix_spatial_g | 34      | NULL |  500 |   100.00 | Using where |
+----+-------------+---------+------------+-------+---------------+--------------+---------+------+------+----------+-------------+
```

Sample rows:

```text
+-----+-------------------+
| id  | point             |
+-----+-------------------+
| 399 | POINT(-0.2 49.75) |
| 199 | POINT(-0.2 49.75) |
| 439 | POINT(-2.2 49.75) |
+-----+-------------------+
```

### Hint

`SPATIAL INDEX` only works on `NOT NULL` geometry columns; specify the SRID at column-definition time.

### Solution

```sql
DROP TABLE IF EXISTS idx_geo;

CREATE TABLE idx_geo (
  id INT NOT NULL AUTO_INCREMENT,
  g  POINT NOT NULL SRID 4326,
  PRIMARY KEY (id),
  SPATIAL INDEX ix_spatial_g (g)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO idx_geo (g)
SELECT ST_PointFromText(
         CONCAT('POINT(', -10 + (l.id MOD 50) / 5.0, ' ', 40 + (l.id MOD 40) / 4.0, ')'),
         4326
       )
FROM idx_lab AS l
WHERE l.id <= 500;

EXPLAIN
SELECT id FROM idx_geo
WHERE MBRContains(
        ST_GeomFromText('POLYGON((-20 35, 20 35, 20 55, -20 55, -20 35))', 4326),
        g
      );

SELECT id, ST_AsText(g) AS point
FROM idx_geo
WHERE MBRContains(
        ST_GeomFromText('POLYGON((-20 35, 20 35, 20 55, -20 55, -20 35))', 4326),
        g
      )
LIMIT 5;
```

### Step-by-step explanation

1. **`POINT NOT NULL SRID 4326`** declares the column as WGS-84 (the standard "GPS" SRID). A SPATIAL index demands `NOT NULL`.
2. **`MBRContains(polygon, point)`** is the bounding-box ("minimum bounding rectangle") test. It uses the spatial index for the rough match, then re-checks geometry exactly.
3. **`type=range` with `key=ix_spatial_g`** confirms the spatial index participated. Spatial indexes are R-tree variants; `EXPLAIN` reuses the `range` label.
4. **SRID mismatch trap:** if the polygon and the points use different SRIDs, MySQL throws `Cannot get geometry object from data you send to the GEOMETRY field`. Always include `4326` explicitly in `ST_GeomFromText`.

---

## Cleanup

The companion script ends with optional `DROP TABLE` for the lab tables. Comment those lines if you want to keep `idx_lab` and `idx_geo` around for more experiments. All index names use the prefix `ix_` so they're easy to spot in `SHOW INDEX FROM idx_lab`.

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `CREATE UNIQUE INDEX` fails with `Duplicate entry …` | The data has duplicates; clean them up first or use non-unique `INDEX`. |
| `EXPLAIN` still shows `type=ALL` after `CREATE INDEX` | The predicate doesn't match the index (function on the column, wrong column type, leading wildcard `LIKE '%foo'`). |
| Composite index ignored | The leading column is missing from `WHERE`, or the optimiser thinks another index is cheaper. Try `FORCE INDEX (…)` for diagnosis. |
| `FULLTEXT` returns nothing | Word shorter than `innodb_ft_min_token_size`, or word is in the stopword list. Try a longer word or boolean mode. |
| `SPATIAL` errors with `Cannot get geometry…` | SRID mismatch — always include `SRID 4326` (or your chosen SRID) in both the column and the query. |
| Index seems unused yet present | Run `ANALYZE TABLE idx_lab;` to refresh cardinality statistics. |
