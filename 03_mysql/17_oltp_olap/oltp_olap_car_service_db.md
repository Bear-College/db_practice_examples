# OLTP vs OLAP — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/17_oltp_olap/oltp_olap_car_service_db.md)

This lesson contrasts **OLTP** (Online Transaction Processing) and **OLAP** (Online Analytical Processing) workloads using the same `car_service_db` schema. OLTP queries serve day-to-day operations (one order, one customer); OLAP queries power reports and dashboards (aggregates over thousands of rows).

Companion script: [`17_oltp_olap/car_service_oltp_olap_examples.sql`](car_service_oltp_olap_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/17_oltp_olap/car_service_oltp_olap_examples.sql
```

---

## OLTP vs OLAP at a glance

| Aspect | OLTP | OLAP |
|--------|------|------|
| **Purpose** | Run the business (bookings, payments, status changes) | Understand the business (trends, KPIs, slices) |
| **Typical SQL** | `SELECT` by PK; short `UPDATE`/`INSERT` | `GROUP BY`, `SUM`, `AVG`, many `JOIN`s |
| **Rows touched** | Few (often 1) | Many (thousands to millions) |
| **Consistency** | Strong; inside transactions | Eventual; often read replicas or warehouse |
| **Schema** | Normalized (3NF) | Denormalized (star / snowflake) |
| **Users** | Cashiers, mechanics, APIs | Analysts, managers, BI tools |

---

## Schema touchpoints

- **`work_orders`** — `id`, `vehicle_id`, `status`, `total_cost`
- **`vehicles`** — `id`, `customer_id`, `plate`, `brand_id`
- **`customers`** — `id`, `last_name`
- **`car_brands`** — `id`, `name`

---

## Exercise 1 — OLTP point lookup (single work order)

### Context

A mechanic opens work order **#42** on a tablet: one row with plate and customer name — fast, indexed by primary key.

### What you'll learn

- OLTP read pattern: filter by **primary key**, return a handful of columns.
- `INNER JOIN` only to resolve related display fields (vehicle, customer).

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost`, `vehicle_id` |
| `vehicles` | `id`, `plate`, `customer_id` |
| `customers` | `id`, `last_name` |

### Task

Return one work order with `id = 42`, including `plate` and `last_name`.

### Expected result (real rows from the dump)

```text
+----+-------------+------------+----------+------------+
| id | status      | total_cost | plate    | last_name  |
+----+-------------+------------+----------+------------+
| 42 | in_progress |     504.20 | AA0042BB | Surname_42 |
+----+-------------+------------+----------+------------+
```

### Hint

`WHERE wo.id = 42` — equality on the PK is the classic OLTP access path.

### Solution

```sql
SELECT wo.id,
       wo.status,
       wo.total_cost,
       v.plate,
       c.last_name
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
WHERE wo.id = 42;
```

### Step-by-step explanation

1. **`WHERE wo.id = 42`** limits the scan to one clustered index lookup on InnoDB's primary key.
2. **Two joins** add display data without changing the grain (still one result row).
3. In production this query runs inside a transaction when the mechanic also updates status (Exercise 2).

---

## Exercise 2 — OLTP narrow write (status change)

### Context

The shop moves order **#2** from `new` to `in_progress` when a mechanic starts work — a single-row `UPDATE`, not a bulk job.

### What you'll learn

- OLTP write pattern: touch **one row** with a precise `WHERE` clause.
- Why apps often `SELECT` then `UPDATE` in the same transaction.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status` |

### Task

1. Read rows `id BETWEEN 1 AND 5`.
2. `UPDATE` row `id = 2` to `in_progress` where `status = 'new'`.
3. Verify row 2; restore `status = 'new'` so the script stays repeatable.

### Expected result (real rows from the dump)

```text
-- After UPDATE:
+----+-------------+
| id | status      |
+----+-------------+
|  2 | in_progress |
+----+-------------+
```

### Hint

Always include `WHERE id = …` (and often the old status) so you do not update the whole table by mistake.

### Solution

```sql
SELECT id, status, total_cost
FROM work_orders
WHERE id BETWEEN 1 AND 5;

UPDATE work_orders
SET status = 'in_progress'
WHERE id = 2
  AND status = 'new';

SELECT id, status
FROM work_orders
WHERE id = 2;

UPDATE work_orders
SET status = 'new'
WHERE id = 2;
```

### Step-by-step explanation

1. **`UPDATE … WHERE id = 2 AND status = 'new'`** is idempotent-safe: re-running after the status changed updates zero rows.
2. Wrap this in `START TRANSACTION` / `COMMIT` when combined with invoice or inventory side effects.
3. OLTP systems optimize for **short locks** on few rows; long-running `UPDATE` without `WHERE` is an OLAP/ETL mistake on an operational table.

---

## Exercise 3 — OLAP aggregation by status

### Context

Management wants revenue and average ticket **per order status** across the last slice of work orders — read-heavy, no single-row focus.

### What you'll learn

- OLAP pattern: `GROUP BY` + aggregates (`COUNT`, `SUM`, `AVG`) over many rows.
- Bounded `WHERE id BETWEEN …` for classroom performance on the 100k-row table.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Task

For `id BETWEEN 1 AND 50000`, compute per `status`: order count, total revenue, average ticket. Sort by revenue descending.

### Expected result (real rows from the dump)

```text
+---------------+-------------+-------------+------------+
| status        | order_count | revenue     | avg_ticket |
+---------------+-------------+-------------+------------+
| completed     |       10000 | 30001500.00 |    3000.15 |
| waiting_parts |       10000 | 30000500.00 |    3000.05 |
| new           |       10001 | 29999000.20 |    2999.60 |
| in_progress   |        9999 | 29998999.80 |    3000.20 |
| cancelled     |       10000 | 29997500.00 |    2999.75 |
+---------------+-------------+-------------+------------+
```

### Hint

One `SELECT` with `GROUP BY status` — no join needed when dimensions are on the fact table.

### Solution

```sql
SELECT wo.status,
       COUNT(*) AS order_count,
       ROUND(SUM(wo.total_cost), 2) AS revenue,
       ROUND(AVG(wo.total_cost), 2) AS avg_ticket
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 50000
GROUP BY wo.status
ORDER BY revenue DESC;
```

### Step-by-step explanation

1. **Full segment scan** (within the id range) is acceptable in OLAP; in OLTP you would avoid scanning 50k rows on the hot path.
2. **`GROUP BY status`** collapses rows into buckets — the opposite of Exercise 1's single-row lookup.
3. Such queries often run on a **replica**, a **materialized summary table**, or a **data warehouse** (see lesson `18_data_warehouse`).

---

## Exercise 4 — OLAP dimensional slice (brand × status)

### Context

A BI dashboard shows **revenue by car brand and order status** — multiple joins and a `HAVING` filter to drop sparse groups.

### What you'll learn

- Star-style reporting on normalized OLTP tables (join dimensions at query time).
- `HAVING` to keep only groups with enough volume for the chart.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `status`, `total_cost` |
| `vehicles` | `id`, `brand_id` |
| `car_brands` | `id`, `name` |

### Task

For `wo.id BETWEEN 1 AND 20000`, group by `brand_name` and `status`. Keep groups with `COUNT(*) >= 100`. Top 10 by `total_revenue`.

### Expected result (real rows from the dump)

```text
+------------+---------------+--------+---------------+
| brand_name | status        | orders | total_revenue |
+------------+---------------+--------+---------------+
| Brand_100  | cancelled     |    200 |     301000.00 |
| Brand_099  | completed     |    200 |     300980.00 |
| Brand_098  | waiting_parts |    200 |     300960.00 |
| ...        |               |        |               |
+------------+---------------+--------+---------------+
```

### Hint

Join `work_orders → vehicles → car_brands` before grouping.

### Solution

```sql
SELECT b.name AS brand_name,
       wo.status,
       COUNT(*) AS orders,
       ROUND(SUM(wo.total_cost), 2) AS total_revenue
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN car_brands AS b ON b.id = v.brand_id
WHERE wo.id BETWEEN 1 AND 20000
GROUP BY b.name, wo.status
HAVING COUNT(*) >= 100
ORDER BY total_revenue DESC
LIMIT 10;
```

### Step-by-step explanation

1. **Three-table join** at query time is typical when OLTP schema stays normalized; warehouses pre-join into fact/dimension tables.
2. **`HAVING COUNT(*) >= 100`** filters groups after aggregation — OLAP noise reduction.
3. Running this on production OLTP during peak hours can contend with Exercise 1–2; schedule heavy OLAP or use a dedicated analytics store.

---

## Related lessons

- [`08_indexes/`](../08_indexes/) — speed up OLTP lookups and some OLAP filters.
- [`18_data_warehouse/`](../18_data_warehouse/) — star schema and ETL for analytics.
- [`09_transactions/`](../09_transactions/) — transactional guarantees for OLTP writes.
