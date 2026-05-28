# Table partitioning in relational databases — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/20_partitioning/partitioning_car_service_db.md)

This lesson introduces **table partitioning** in MySQL: splitting one logical table into **physical partitions** so queries with partition keys can **prune** irrelevant segments. You will create a `RANGE` partitioned lab table, inspect metadata, and compare `EXPLAIN` plans for queries that hit one partition vs many.

Companion script: [`20_partitioning/car_service_partitioning_examples.sql`](car_service_partitioning_examples.sql).

```bash
mysql -u root car_service_db < 03_mysql/20_partitioning/car_service_partitioning_examples.sql
```

**Requirements:** MySQL **8.0+** (partitioning with InnoDB is standard; syntax shown uses `RANGE` on `id`).

---

## Partitioning concepts

| Term | Meaning |
|------|---------|
| **Partition** | Sub-table storing a subset of rows (`p_low`, `p_mid`, …) |
| **Partition key** | Column in `PARTITION BY` expression (`id` here) |
| **Pruning** | Optimizer skips partitions that cannot contain matching rows |
| **RANGE** | Each partition holds rows where key `<` boundary |
| **MAXVALUE** | Catch-all partition for keys above the last bound |

Partitioning is **not** a substitute for indexes — it complements them for very large tables and archival patterns (`DROP PARTITION` old data).

---

## Exercise 1 — Create a RANGE-partitioned table

### Context

Archive-friendly design: work-order history split by `id` bands so reports on recent ids touch fewer partitions.

### What you'll learn

- `PARTITION BY RANGE (id) (PARTITION … VALUES LESS THAN (…), …)`
- Composite primary key including partition key when required by MySQL

### Tables in play

| Table | Columns |
|---|---|
| `part_wo_lab` | `id`, `status`, `total_cost` |

### Task

Create `part_wo_lab` with four RANGE partitions on `id` and load rows from `work_orders` where `id BETWEEN 1 AND 25000`. Show total row count.

### Expected result (real rows from the dump)

```text
+------------+
| total_rows |
+------------+
|      25000 |
+------------+
```

### Hint

Boundaries: `< 10001`, `< 20001`, `< 30001`, `MAXVALUE`.

### Solution

```sql
CREATE TABLE part_wo_lab (
  id         INT NOT NULL,
  status     VARCHAR(20) NOT NULL,
  total_cost DECIMAL(10, 2) NOT NULL,
  PRIMARY KEY (id, status)
) ENGINE=InnoDB
PARTITION BY RANGE (id) (
  PARTITION p_low    VALUES LESS THAN (10001),
  PARTITION p_mid    VALUES LESS THAN (20001),
  PARTITION p_high   VALUES LESS THAN (30001),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

INSERT INTO part_wo_lab (id, status, total_cost)
SELECT wo.id, wo.status, wo.total_cost
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 25000;

SELECT COUNT(*) AS total_rows FROM part_wo_lab;
```

### Step-by-step explanation

1. **`PARTITION BY RANGE (id)`** places each row in exactly one partition based on `id`.
2. **Primary key must include** the partition key (`id`) in MySQL for this definition.
3. Inserts route automatically — application SQL usually does not name partitions.

---

## Exercise 2 — Partition pruning in EXPLAIN

### Context

A report for orders `id BETWEEN 15000 AND 15010` should read only the `p_mid` partition, not the whole table.

### What you'll learn

- Using `EXPLAIN` to see **partition pruning** (MySQL 8 tree format shows range on PK).
- Contrasting a query in `p_low` vs `p_mid` id ranges.

### Tables in play

| Table | Columns |
|---|---|
| `part_wo_lab` | `id`, `status`, `total_cost` |

### Task

Run `EXPLAIN` for `id BETWEEN 15000 AND 15010` and for `id BETWEEN 500 AND 510`.

### Expected result (real `EXPLAIN` excerpts)

```text
-- ids 15000–15010:
-> Index range scan on part_wo_lab using PRIMARY over (15000 <= id <= 15010)

-- ids 500–510:
-> Index range scan on part_wo_lab using PRIMARY over (500 <= id <= 510)
```

### Hint

Pruning works best when `WHERE` compares the **partition key** with literals or parameters.

### Solution

```sql
EXPLAIN
SELECT id, status, total_cost
FROM part_wo_lab
WHERE id BETWEEN 15000 AND 15010;

EXPLAIN
SELECT id, status, total_cost
FROM part_wo_lab
WHERE id BETWEEN 500 AND 510;
```

### Step-by-step explanation

1. Without pruning, every partition would be scanned — same cost as no partitioning.
2. **`WHERE id BETWEEN …`** aligns with `RANGE (id)` → optimizer eliminates `p_high` and `p_future` for low ids.
3. For `EXPLAIN PARTITIONS` (legacy tabular), the `partitions` column lists names touched.

---

## Exercise 3 — Inspect partition metadata

### Context

DBA verifies row distribution across partitions before adding a new monthly partition.

### What you'll learn

- `information_schema.partitions` columns: `partition_name`, `table_rows`, `partition_description`

### Tables in play

| Table | Columns |
|---|---|
| `information_schema.partitions` | metadata for `part_wo_lab` |

### Task

List all partitions of `part_wo_lab` with estimated row counts and upper bounds.

### Expected result (real rows from the dump)

```text
+----------------+------------+-----------------------+
| PARTITION_NAME | TABLE_ROWS | PARTITION_DESCRIPTION |
+----------------+------------+-----------------------+
| p_low          |      10000 | 10001                 |
| p_mid          |      10000 | 20001                 |
| p_high         |       5000 | 30001                 |
| p_future       |          0 | MAXVALUE              |
+----------------+------------+-----------------------+
```

### Hint

Filter `partition_name IS NOT NULL` — the table-level row has `NULL` partition name.

### Solution

```sql
SELECT partition_name,
       table_rows,
       partition_description
FROM information_schema.partitions
WHERE table_schema = 'car_service_db'
  AND table_name = 'part_wo_lab'
  AND partition_name IS NOT NULL
ORDER BY partition_ordinal_position;
```

### Step-by-step explanation

1. **`table_rows`** is approximate (InnoDB statistics), not exact.
2. **`partition_description`** shows the upper bound for RANGE partitions.
3. **`ALTER TABLE … ADD PARTITION`** extends RANGE layouts; `REORGANIZE` merges or splits.

---

## Exercise 4 — Aggregate within one partition band

### Context

Finance wants revenue by status **only for orders in the 10k–20k id band** — pruning keeps the aggregation on `p_mid`.

### What you'll learn

- Combining `GROUP BY` with a predicate that enables pruning.
- Same SQL idioms as OLAP, different physical layout.

### Tables in play

| Table | Columns |
|---|---|
| `part_wo_lab` | `id`, `status`, `total_cost` |

### Task

For `id BETWEEN 10000 AND 19999`, compute `COUNT(*)` and `SUM(total_cost)` per `status`, ordered by revenue.

### Expected result (real rows from the dump)

```text
+---------------+------+------------+
| status        | cnt  | revenue    |
+---------------+------+------------+
| completed     | 2000 | 4000300.00 |
| waiting_parts | 2000 | 4000100.00 |
| in_progress   | 2000 | 3999900.00 |
| new           | 2000 | 3999700.00 |
| cancelled     | 2000 | 3999500.00 |
+---------------+------+------------+
```

### Hint

Align the `WHERE` range with partition boundaries for best pruning.

### Solution

```sql
SELECT status,
       COUNT(*) AS cnt,
       ROUND(SUM(total_cost), 2) AS revenue
FROM part_wo_lab
WHERE id BETWEEN 10000 AND 19999
GROUP BY status
ORDER BY revenue DESC;
```

### Step-by-step explanation

1. **Partitioning + index**: primary key still supports range scans inside each partition.
2. **Wrong tool?** If most queries lack `id` in `WHERE`, pruning fails — consider indexes or warehouse instead.
3. **Lifecycle**: `DROP PARTITION p_low` removes old data faster than `DELETE` millions of rows.

---

## Related lessons

- [`08_indexes/`](../08_indexes/) — indexes inside each partition.
- [`19_indexing/`](../19_indexing/) — when to index vs partition.
- [`18_data_warehouse/`](../18_data_warehouse/) — another way to manage large historical data.
