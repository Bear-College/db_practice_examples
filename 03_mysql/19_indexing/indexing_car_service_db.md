# Indexing in relational databases — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/19_indexing/indexing_car_service_db.md)

This lesson covers **indexing strategy** in relational databases: cardinality, composite **left-prefix** rules, **covering** indexes, and when the optimizer prefers a full scan. For hands-on creation of B-tree, UNIQUE, FULLTEXT, and SPATIAL indexes, see [`08_indexes/`](../08_indexes/) first.

Companion script: [`19_indexing/car_service_indexing_examples.sql`](car_service_indexing_examples.sql).

```bash
mysql -u root car_service_db < 03_mysql/19_indexing/car_service_indexing_examples.sql
```

---

## Indexing concepts

| Concept | Meaning |
|---------|---------|
| **Selectivity** | Fraction of rows matched; high selectivity → index more useful |
| **Cardinality** | Distinct values in a column (`SHOW INDEX`, `information_schema`) |
| **Left-prefix rule** | Composite index `(a, b, c)` supports `WHERE a` and `WHERE a AND b`, not `WHERE b` alone |
| **Covering index** | Index contains all columns in `SELECT` → `Using index` in `EXPLAIN` |
| **Maintenance** | `ANALYZE TABLE` refreshes statistics after large loads |

---

## Exercise 1 — Inspect indexes and cardinality

### Context

Before adding another index, the DBA checks what already exists and whether statistics are stale.

### What you'll learn

- `SHOW INDEX FROM tbl`
- Querying `information_schema.statistics` for `cardinality`

### Tables in play

| Table | Columns |
|---|---|
| `idx_design_lab` | `id`, `status`, `ref_num`, `sku`, `total_cost` |

### Task

After creating and seeding `idx_design_lab` (see companion script), list indexes and their cardinality from `information_schema`.

### Expected result (real output)

```text
+------------+-------------+-------------+--------------+
| INDEX_NAME | COLUMN_NAME | CARDINALITY | SEQ_IN_INDEX |
+------------+-------------+-------------+--------------+
| ix_ref     | ref_num     |           1 |            1 |
| ix_status  | status      |           1 |            1 |
| PRIMARY    | id          |           1 |            1 |
+------------+-------------+-------------+--------------+
```

(Cardinality rises after `ANALYZE TABLE` on larger datasets.)

### Hint

Filter `table_schema = 'car_service_db' AND table_name = 'idx_design_lab'`.

### Solution

```sql
SHOW INDEX FROM idx_design_lab;

SELECT index_name,
       column_name,
       cardinality,
       seq_in_index
FROM information_schema.statistics
WHERE table_schema = 'car_service_db'
  AND table_name = 'idx_design_lab'
ORDER BY index_name, seq_in_index;
```

### Step-by-step explanation

1. **`Cardinality`** is an estimate of distinct values — the optimizer uses it to choose index vs scan.
2. Right after a bulk insert, cardinality can be **low until `ANALYZE TABLE`**.
3. Do not create redundant indexes on the same leading column without a reason.

---

## Exercise 2 — Composite index and left-prefix rule

### Context

Filters often use `status = 'open' AND ref_num BETWEEN …`. A composite index `(status, ref_num, total_cost)` supports that pattern.

### What you'll learn

- `CREATE INDEX ix_status_ref_cost ON … (status, ref_num, total_cost)`
- Reading tree-style `EXPLAIN` (MySQL 8+)

### Tables in play

| Table | Columns |
|---|---|
| `idx_design_lab` | `status`, `ref_num`, `total_cost` |

### Task

Create the composite index and `EXPLAIN` a query filtering on both `status` and `ref_num`.

### Expected result (real `EXPLAIN` excerpt)

```text
-> Covering index range scan on idx_design_lab using ix_status_ref_cost
   over (status = 'open' AND 5000 <= ref_num <= 5010)
```

### Hint

Leading column in the index must match the equality filter (`status`) before the range on `ref_num`.

### Solution

```sql
CREATE INDEX ix_status_ref_cost ON idx_design_lab (status, ref_num, total_cost);

EXPLAIN
SELECT status, ref_num, total_cost
FROM idx_design_lab
WHERE status = 'open'
  AND ref_num BETWEEN 5000 AND 5010;
```

### Step-by-step explanation

1. **`WHERE status = 'open'`** uses the first key part; **`ref_num BETWEEN`** uses the second.
2. A query with **only** `ref_num` cannot use this composite efficiently (left-prefix rule).
3. Compare with [`08_indexes`](../08_indexes/) Exercise 3 for another composite example on `idx_lab`.

---

## Exercise 3 — Covering index (index-only access)

### Context

If `SELECT` lists only columns present in the index, InnoDB may read **only the index B-tree**, not the table heap — fewer I/O operations.

### What you'll learn

- Covering index = composite index includes all selected columns.
- `EXPLAIN` plan text mentions **Covering index**.

### Tables in play

| Table | Columns |
|---|---|
| `idx_design_lab` | `ref_num`, `total_cost`, `status` |

### Task

`EXPLAIN` a query selecting only `ref_num` and `total_cost` with the same `WHERE` as Exercise 2.

### Expected result (real `EXPLAIN` excerpt)

```text
-> Covering index range scan on idx_design_lab using ix_status_ref_cost
```

### Hint

Selected columns must be a subset of indexed columns (here: `status`, `ref_num`, `total_cost`).

### Solution

```sql
EXPLAIN
SELECT ref_num, total_cost
FROM idx_design_lab
WHERE status = 'open'
  AND ref_num BETWEEN 5000 AND 5010;
```

### Step-by-step explanation

1. **Covering** avoids **random lookups** into the clustered primary key for each matching row.
2. Trade-off: wider indexes use more disk and slow down writes slightly.
3. In older `EXPLAIN` tabular format, look for `Extra: Using index`.

---

## Exercise 4 — Low selectivity and `ANALYZE TABLE`

### Context

Every row in the lab has `status = 'open'`, so an index on `status` alone is **not selective** — the optimizer may still scan many rows.

### What you'll learn

- When indexes help little (low cardinality / skewed data).
- Refreshing statistics with `ANALYZE TABLE`.

### Tables in play

| Table | Columns |
|---|---|
| `idx_design_lab` | `status`, `id`, `sku` |

### Task

`EXPLAIN SELECT id, sku FROM idx_design_lab WHERE status = 'open' LIMIT 20`, then `ANALYZE TABLE idx_design_lab` and recheck cardinality on `ix_status`.

### Expected result (real `EXPLAIN` excerpt)

```text
-> Index lookup on idx_design_lab using ix_status (status = 'open')
```

### Hint

In production, fix data skew or add a more selective predicate (e.g. `ref_num`).

### Solution

```sql
EXPLAIN
SELECT id, sku
FROM idx_design_lab
WHERE status = 'open'
LIMIT 20;

ANALYZE TABLE idx_design_lab;

SELECT table_name, index_name, cardinality
FROM information_schema.statistics
WHERE table_schema = 'car_service_db'
  AND table_name = 'idx_design_lab'
  AND index_name = 'ix_status';
```

### Step-by-step explanation

1. **Low selectivity** → optimizer may choose **full table scan** on larger real tables.
2. **`ANALYZE TABLE`** updates histograms/cardinality for better plans after bulk load.
3. Index design is iterative: measure with `EXPLAIN ANALYZE`, adjust, avoid duplicate indexes.

---

## Related lessons

- [`08_indexes/`](../08_indexes/) — create and compare B-tree, UNIQUE, FULLTEXT, SPATIAL indexes.
- [`20_partitioning/`](../20_partitioning/) — partition pruning as another physical design tool.
