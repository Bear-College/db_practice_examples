# DQL (Data Query Language) — `car_service_db`

These examples follow the **core `SELECT` themes** (basic clauses, `NULL`, rich `WHERE`, aggregates, `GROUP BY`, `HAVING`, `ORDER BY`, `DISTINCT`, `LIMIT` / `OFFSET`). They run on the real database loaded from **`database/car_service_db.sql.gz`** (database name: **`car_service_db`**).

Runnable queries: **`4_dql/car_service_dql_examples.sql`** (from the repository root).

```bash
mysql -u ... -p ... -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c database/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 4_dql/car_service_dql_examples.sql
```

**Performance:** the dump is large; the script uses **`WHERE id BETWEEN …`** (and similar) so queries stay quick in class.

---

## Map: clauses and operators (matches course sheet)

| Theme | SQL ideas |
|--------|-----------|
| **(a) `SELECT`** | Choose columns or expressions; can rename with `AS`. |
| **(b) `FROM`** | Which table(s) supply rows (`FROM customers`, later `JOIN`). |
| **(c) `WHERE`** | Filter rows **before** grouping. |
| **(d) `GROUP BY`** | One result row per group; use with aggregates. |
| **`SELECT … FROM …`** | Minimal query shape: list columns, list table. |
| **`NULL`** | Unknown / missing; test with `IS NULL`, `IS NOT NULL`; optional `COALESCE(col, default)`. |
| **`WHERE` (simple)** | One condition, e.g. `status = 'completed'`. |
| **`WHERE` + `AND`, `OR`, `IN`, `LIKE`, `IS`, `NOT`** | Combine predicates; patterns with `LIKE 'A%'`; sets with `IN (...)`; negation with `NOT` or `<>`. |
| **Aggregates** | `COUNT`, `SUM`, `AVG`, `MIN`, `MAX` — summary over many rows. |
| **`GROUP BY`** | Define groups (e.g. by `status`), then aggregates apply per group. |
| **`HAVING`** | Filter **groups** (after `GROUP BY`); uses aggregate conditions. |
| **`ORDER BY`** | Sort (`ASC` / `DESC`). |
| **`DISTINCT`** | Drop duplicate values for listed expressions. |
| **`LIMIT`** | Return at most *N* rows. |
| **`LIMIT` … `OFFSET` …** | Skip *OFFSET* rows, then take *LIMIT* (pagination). |

---

## Schema touchpoints (from the dump)

- **`customers`** — `id`, `first_name`, `last_name`, `phone`, `email`
- **`vehicles`** — `id`, `customer_id`, `plate`, `car_brands_id`, …
- **`car_brands`** — `id`, `name`
- **`work_orders`** — `id`, `vehicle_id`, `mechanic_id`, `status`, `total_cost`
- **`parts`** — `id`, `sku`, `name`, `brand`

Sample **`work_orders.status`:** `new`, `in_progress`, `waiting_parts`, `completed`, `cancelled`.

---

## Exercises (paired with `car_service_dql_examples.sql`)

### 1 — `SELECT … `FROM` …

**Task:** Pick specific columns from **`customers`** (bounded id range).

### 2 — `NULL`

**Task:** Rows with **no** `phone`; show `COALESCE` for display.

### 3 — `WHERE` (simple)

**Task:** **`work_orders`** with `status = 'completed'`.

### 4 — `WHERE` with `AND`, `OR`, `IN`, `LIKE`, `IS`, `NOT`

**Task:** Several examples: name patterns with **`LIKE`**; status sets with **`IN`**; **`IS NOT NULL`** on `mechanic_id`; **`NOT`** on status.

### 5 — Aggregates: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`

**Task:** One **`SELECT`** over a slice of **`work_orders`** returning all five aggregates.

### 6 — `GROUP BY`

**Task:** Count rows per **`status`**.

### 7 — `HAVING`

**Task:** Keep only groups with enough rows and minimum average cost (with **`GROUP BY status`**).

### 8 — `ORDER BY`

**Task:** Sort **`work_orders`** by **`total_cost`** descending.

### 9 — `DISTINCT`

**Task:** Unique **`status`** values; unique **`parts.brand`** values (non-null).

### 10 — `LIMIT`

**Task:** Cap result size from **`parts`**.

### 11 — `LIMIT` … `OFFSET` …

**Task:** Page through **`customers`** (e.g. rows 21–30 when `LIMIT 10 OFFSET 20`).

### Supplement S1–S2 — `JOIN` (after single-table basics)

**Task:** **`vehicles`** + **`car_brands`**; then **`work_orders`** + **`vehicles`** + **`customers`**.

---

### If a query returns no rows

Widen **`BETWEEN`** bounds slightly. **`HAVING`** filters can drop all groups if thresholds are too strict—lower **`COUNT`** or **`AVG`** cutoffs for testing.
