# DQL (Data Query Language) — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/04_dql/dql_car_service_db.md)

These exercises walk through the **core `SELECT` themes** (basic clauses, `NULL`, rich `WHERE`, aggregates, `GROUP BY`, `HAVING`, `ORDER BY`, `DISTINCT`, `LIMIT` / `OFFSET`, and a first taste of `JOIN`). They run on the real database loaded from **`01_database_mysql/car_service_db.sql.gz`** (database name: **`car_service_db`**).

Runnable companion file: [`04_dql/car_service_dql_examples.sql`](car_service_dql_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/04_dql/car_service_dql_examples.sql
```

**Performance:** the dump is large (each main table has ~100k rows). The script uses **`WHERE id BETWEEN …`** to keep each query fast during class.

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real shop would run this query (1-2 sentences). |
| **What you'll learn** | SQL constructs trained in this exact exercise. |
| **Tables in play** | Only the columns you actually need. |
| **Task** | Concrete requirements (filter, sort, limit). |
| **Expected result** | Real rows from the dump (copied from a live run). |
| **Hint** | A single nudge toward the right operator/clause. |
| **Solution** | Working SQL you can paste into `mysql`. |
| **Step-by-step explanation** | What each clause does and the typical mistakes. |

---

## Map: clauses and operators (matches the course sheet)

| Theme | SQL ideas |
|--------|-----------|
| **(a) `SELECT`** | Choose columns or expressions; rename with `AS`. |
| **(b) `FROM`** | Which table(s) supply rows (`FROM customers`, later `JOIN`). |
| **(c) `WHERE`** | Filter rows **before** grouping. |
| **(d) `GROUP BY`** | One result row per group; use with aggregates. |
| **`NULL`** | Unknown / missing; test with `IS NULL`, `IS NOT NULL`; optional `COALESCE(col, default)`. |
| **`WHERE` + `AND`, `OR`, `IN`, `LIKE`, `IS`, `NOT`** | Combine predicates; patterns with `LIKE 'A%'`; sets with `IN (...)`; negation with `NOT` or `<>`. |
| **Aggregates** | `COUNT`, `SUM`, `AVG`, `MIN`, `MAX` — summary over many rows. |
| **`GROUP BY`** | Define groups (e.g. by `status`); aggregates apply per group. |
| **`HAVING`** | Filter **groups** (after `GROUP BY`); uses aggregate conditions. |
| **`ORDER BY`** | Sort (`ASC` / `DESC`). |
| **`DISTINCT`** | Drop duplicate values for listed expressions. |
| **`LIMIT`** | Return at most *N* rows. |
| **`LIMIT … OFFSET …`** | Skip *OFFSET* rows, then take *LIMIT* (pagination). |

---

## Schema touchpoints (from the dump)

- **`customers`** — `id`, `first_name`, `last_name`, `phone`, `email`
- **`vehicles`** — `id`, `customer_id`, `plate`, `brand_id`, …
- **`car_brands`** — `id`, `name`
- **`work_orders`** — `id`, `vehicle_id`, `assigned_mechanic_id`, `status`, `total_cost`
- **`parts`** — `id`, `sku`, `name`, `brand`

Sample **`work_orders.status`** domain: `new`, `in_progress`, `waiting_parts`, `completed`, `cancelled`.

---

## Exercise 1 — `SELECT … FROM …`

### Context

The CRM front-end loads a customer mini-list to suggest matches as the cashier types. We need a thin, ordered slice — only the columns the UI actually shows.

### What you'll learn

- Picking specific columns instead of `SELECT *`.
- Bounding a scan with `WHERE id BETWEEN …`.
- Capping result size with `LIMIT`.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `first_name`, `last_name`, `email` |

### Task

Return `id`, `first_name`, `last_name`, `email` for customers with `id` between 1 and 200. Cap output at 20 rows.

### Expected result (real rows from the dump)

```text
+----+------------+------------+------------------------+
| id | first_name | last_name  | email                  |
+----+------------+------------+------------------------+
|  1 | Name_1     | Surname_1  | customer1@example.com  |
|  2 | Name_2     | Surname_2  | customer2@example.com  |
| ...|            |            |                        |
| 20 | Name_20    | Surname_20 | customer20@example.com |
+----+------------+------------+------------------------+
```

### Hint

You only need a `SELECT` over `customers` with a `BETWEEN` filter and `LIMIT`.

### Solution

```sql
SELECT id,
       first_name,
       last_name,
       email
FROM customers
WHERE id BETWEEN 1 AND 200
LIMIT 20;
```

### Step-by-step explanation

1. **`SELECT id, first_name, ...`** lists the columns we want — never use `SELECT *` in production queries: it ships unused data over the wire.
2. **`FROM customers`** picks the table.
3. **`WHERE id BETWEEN 1 AND 200`** is inclusive (`1 <= id <= 200`). Without it, MySQL would scan all 100 000 customers.
4. **`LIMIT 20`** caps the network output. It does not order the rows — if you need a stable top-N, add `ORDER BY` (see Exercise 8).

---

## Exercise 2 — `NULL` and `COALESCE`

### Context

The admin wants to print envelope labels for clients who **do have a phone number** (we'll call them about the appointment) and show a placeholder `'no phone'` in the SMS report for everyone else. Both use cases need a `NULL`-safe expression.

### What you'll learn

- The difference between `IS NULL` / `IS NOT NULL` and `= NULL` (which never matches!).
- `COALESCE(col, default)` to substitute a fallback.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `first_name`, `last_name`, `phone` |

### Task

List the first 15 customers (`id BETWEEN 1 AND 300`) whose `phone IS NOT NULL`. Show both the raw `phone` and a `phone_display` column that uses `COALESCE` to substitute `'no phone'` for missing values.

### Expected result (real rows from the dump)

```text
+----+------------+------------+---------------+---------------+
| id | first_name | last_name  | phone         | phone_display |
+----+------------+------------+---------------+---------------+
|  1 | Name_1     | Surname_1  | +380500000001 | +380500000001 |
|  2 | Name_2     | Surname_2  | +380500000002 | +380500000002 |
| ...|            |            |               |               |
| 15 | Name_15    | Surname_15 | +380500000015 | +380500000015 |
+----+------------+------------+---------------+---------------+
```

### Hint

`phone IS NOT NULL` for the filter; `COALESCE(phone, 'no phone')` for the display.

### Solution

```sql
SELECT id,
       first_name,
       last_name,
       phone,
       COALESCE(phone, 'no phone') AS phone_display
FROM customers
WHERE id BETWEEN 1 AND 300
  AND phone IS NOT NULL
LIMIT 15;
```

### Step-by-step explanation

1. **`COALESCE(phone, 'no phone')`** returns the first non-`NULL` argument. Use it whenever you want to keep the row but mask a missing value.
2. **`WHERE … AND phone IS NOT NULL`** filters with the dedicated `NULL`-test operator. `phone = NULL` never matches anything because `NULL = NULL` is itself `NULL` (i.e. "unknown"), not `TRUE`.
3. Common bug: `WHERE phone <> NULL` — same trap, the predicate is `NULL`, the row is dropped. Always use `IS NULL` / `IS NOT NULL`.

---

## Exercise 3 — `WHERE` (single predicate)

### Context

The service manager wants a quick list of **closed (completed)** work orders to validate today's invoices.

### What you'll learn

- Filtering with one equality predicate.
- Combining the filter with an id range for performance.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `status`, `total_cost` |

### Task

Return `id`, `vehicle_id`, `status`, `total_cost` for work orders with `status = 'completed'` and `id BETWEEN 1 AND 5000`. Cap at 25 rows.

### Expected result (real rows from the dump)

```text
+-----+------------+-----------+------------+
| id  | vehicle_id | status    | total_cost |
+-----+------------+-----------+------------+
|   4 |          4 | completed |     500.40 |
|   9 |          9 | completed |     500.90 |
|  14 |         14 | completed |     501.40 |
| ... |            |           |            |
| 124 |        124 | completed |     512.40 |
+-----+------------+-----------+------------+
```

### Hint

A single `=` predicate on `status` plus the id range.

### Solution

```sql
SELECT id,
       vehicle_id,
       status,
       total_cost
FROM work_orders
WHERE status = 'completed'
  AND id BETWEEN 1 AND 5000
LIMIT 25;
```

### Step-by-step explanation

1. **`status = 'completed'`** is a plain equality. Strings live in quotes; MySQL is case-insensitive by default for `varchar` with `utf8mb4_0900_ai_ci`, so `'COMPLETED'` would also match — but stick to the canonical form.
2. **`AND id BETWEEN …`** narrows the scan; without it MySQL would touch all 100 000 work orders.
3. **No `ORDER BY`** — rows come back in the storage engine's order; not a problem here, but never rely on it for production reports.

---

## Exercise 4 — `WHERE` with `AND`, `OR`, `IN`, `LIKE`, `IS`, `NOT`

### Context

Three small reports the front desk produces every morning:

- (a) Find customers whose first or last name matches a fuzzy pattern.
- (b) Pull work orders that are **not yet closed** (still `new`, `in_progress`, or `waiting_parts`).
- (c) Find work orders **that have an assigned mechanic** but are not cancelled.

### What you'll learn

- Combining predicates with `AND` / `OR`.
- Sets with `IN (...)`.
- Patterns with `LIKE`.
- `IS NOT NULL` and `NOT` for boolean filters.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `first_name`, `last_name`, `email` |
| `work_orders` | `id`, `vehicle_id`, `assigned_mechanic_id`, `status`, `total_cost` |

### Task

Write three independent queries:

1. Customers `id BETWEEN 1 AND 2000` whose `first_name LIKE 'Name_1%' OR 'Name_2%'`, or `last_name LIKE 'Surname_1%'`. Limit 20.
2. Work orders `id BETWEEN 1 AND 10000` with `status IN ('new','in_progress','waiting_parts')`. Limit 25.
3. Work orders `id BETWEEN 1 AND 5000` with `assigned_mechanic_id IS NOT NULL AND NOT (status = 'cancelled')`. Limit 25.

### Expected result (real rows from the dump — query 2)

```text
+----+------------+---------------+------------+
| id | vehicle_id | status        | total_cost |
+----+------------+---------------+------------+
|  1 |          1 | new           |     500.10 |
|  2 |          2 | in_progress   |     500.20 |
|  3 |          3 | waiting_parts |     500.30 |
|  6 |          6 | new           |     500.60 |
| ...|            |               |            |
+----+------------+---------------+------------+
```

### Hint

- `IN (...)` instead of `status = 'a' OR status = 'b' OR ...`.
- `LIKE 'Name_1%'` matches `Name_1`, `Name_10`, …, `Name_19`, `Name_100`, ….
- `NOT (status = 'cancelled')` is identical to `status <> 'cancelled'`; both are fine.

### Solution

```sql
-- (1) Pattern match on names
SELECT id, first_name, last_name, email
FROM customers
WHERE id BETWEEN 1 AND 2000
  AND (
        (first_name LIKE 'Name_1%' OR first_name LIKE 'Name_2%')
     OR last_name  LIKE 'Surname_1%'
  )
LIMIT 20;

-- (2) Set membership with IN
SELECT id, vehicle_id, status, total_cost
FROM work_orders
WHERE id BETWEEN 1 AND 10000
  AND status IN ('new', 'in_progress', 'waiting_parts')
LIMIT 25;

-- (3) IS NOT NULL combined with NOT
SELECT id, assigned_mechanic_id, status
FROM work_orders
WHERE id BETWEEN 1 AND 5000
  AND assigned_mechanic_id IS NOT NULL
  AND NOT (status = 'cancelled')
LIMIT 25;
```

### Step-by-step explanation

1. **Parentheses matter.** In query (1), without the inner `()`, `AND` binds tighter than `OR` and the predicate changes meaning silently — a classic source of bugs.
2. **`IN (...)`** is shorthand for an `OR`-chain on the same column. Prefer it for readability and because MySQL can optimise it to an index lookup.
3. **`LIKE 'A%'`** uses `%` as multi-character wildcard and `_` as single-character. Escape literal `%` with `\%`.
4. **`IS NOT NULL` not `<> NULL`.** See Exercise 2 — `<> NULL` returns `NULL`, which filters out the row.

---

## Exercise 5 — Aggregates (`COUNT`, `SUM`, `AVG`, `MIN`, `MAX`)

### Context

The owner wants a one-shot summary of work order economics by status: how many orders, how much money in total, average ticket size, cheapest and most expensive.

### What you'll learn

- Five core aggregates in one query.
- Why aggregates require either `GROUP BY` or "no grouping" (single result row).

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `status`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 50000`, return per `status`: count, sum, avg, min, max of `total_cost`. Sort by `status`.

### Expected result (real rows from the dump)

```text
+---------------+-----------+-------------+-------------+----------+----------+
| status        | row_count | sum_cost    | avg_cost    | min_cost | max_cost |
+---------------+-----------+-------------+-------------+----------+----------+
| cancelled     |     10000 | 29997500.00 | 2999.750000 |   500.00 |  5499.50 |
| completed     |     10000 | 30001500.00 | 3000.150000 |   500.40 |  5499.90 |
| in_progress   |     10000 | 29999500.00 | 2999.950000 |   500.20 |  5499.70 |
| new           |     10000 | 29998500.00 | 2999.850000 |   500.10 |  5499.60 |
| waiting_parts |     10000 | 30000500.00 | 3000.050000 |   500.30 |  5499.80 |
+---------------+-----------+-------------+-------------+----------+----------+
```

### Hint

`COUNT(*)`, `SUM(total_cost)`, `AVG(total_cost)`, `MIN(total_cost)`, `MAX(total_cost)`, grouped by `status`.

### Solution

```sql
SELECT status,
       COUNT(*)         AS row_count,
       SUM(total_cost)  AS sum_cost,
       AVG(total_cost)  AS avg_cost,
       MIN(total_cost)  AS min_cost,
       MAX(total_cost)  AS max_cost
FROM work_orders
WHERE id BETWEEN 1 AND 50000
GROUP BY status
ORDER BY status;
```

### Step-by-step explanation

1. **`COUNT(*)`** counts rows (including those with `NULL` in any column). **`COUNT(col)`** counts non-`NULL` values of `col` — use the right one for the question you're asking.
2. **`SUM`/`AVG`** ignore `NULL`. If every value in the group is `NULL`, both return `NULL` (not `0`).
3. **`GROUP BY status`** must list every non-aggregate column in `SELECT`. MySQL with `ONLY_FULL_GROUP_BY` enforces this.
4. **`ORDER BY status`** sorts groups alphabetically. Without it, group order is undefined.

---

## Exercise 6 — `GROUP BY` (counts per category)

### Context

Dashboard widget: "Order pipeline" — how many work orders sit in each status right now.

### What you'll learn

- Simplest `GROUP BY` with a single `COUNT(*)`.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `status` |

### Task

Count rows per `status` for `id BETWEEN 1 AND 50000`. Sort by `status`.

### Expected result (real rows from the dump)

```text
+---------------+----------+
| status        | how_many |
+---------------+----------+
| cancelled     |    10000 |
| completed     |    10000 |
| in_progress   |    10000 |
| new           |    10000 |
| waiting_parts |    10000 |
+---------------+----------+
```

### Hint

`SELECT status, COUNT(*) FROM ... GROUP BY status`.

### Solution

```sql
SELECT status,
       COUNT(*) AS how_many
FROM work_orders
WHERE id BETWEEN 1 AND 50000
GROUP BY status
ORDER BY status;
```

### Step-by-step explanation

1. **`GROUP BY status`** collapses all rows with the same `status` into one bucket.
2. **`COUNT(*)`** counts rows in each bucket. **The grouped column is the only non-aggregate allowed in `SELECT`.**
3. **`ORDER BY status`** is **not** automatic — without it MySQL may return buckets in any order.

---

## Exercise 7 — `HAVING` (filter on groups)

### Context

Manager wants to see only status buckets that are both **big enough** (more than 100 orders) **and well-priced** (average over 400) — discard noise.

### What you'll learn

- The difference between `WHERE` (filters rows) and `HAVING` (filters groups).
- Multiple aggregate conditions in `HAVING`.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `status`, `total_cost` |

### Task

For `id BETWEEN 1 AND 100000`, group by `status`, keep only groups with `COUNT(*) >= 100 AND AVG(total_cost) > 400`. Order by `avg_cost` descending.

### Expected result (real rows from the dump)

```text
+---------------+----------+-------------+
| status        | how_many | avg_cost    |
+---------------+----------+-------------+
| completed     |    20000 | 3000.150000 |
| waiting_parts |    20000 | 3000.050000 |
| in_progress   |    20000 | 2999.950000 |
| new           |    20000 | 2999.850000 |
| cancelled     |    20000 | 2999.750000 |
+---------------+----------+-------------+
```

### Hint

`HAVING` can mention aggregates by name (`COUNT(*)`, `AVG(total_cost)`).

### Solution

```sql
SELECT status,
       COUNT(*)        AS how_many,
       AVG(total_cost) AS avg_cost
FROM work_orders
WHERE id BETWEEN 1 AND 100000
GROUP BY status
HAVING COUNT(*) >= 100
   AND AVG(total_cost) > 400
ORDER BY avg_cost DESC;
```

### Step-by-step explanation

1. **`WHERE` runs before `GROUP BY`** — so it cannot mention aggregates.
2. **`HAVING` runs after `GROUP BY`** — it filters groups by their aggregate values.
3. **Logical execution order:** `FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT`.
4. Common mistake: writing `WHERE COUNT(*) >= 100` — this is a syntax error in MySQL.

---

## Exercise 8 — `ORDER BY` (sorting)

### Context

The "high-ticket" widget on the manager dashboard: 30 most expensive recent work orders, descending by cost.

### What you'll learn

- `ORDER BY col DESC, col2 ASC` for stable, multi-key sorts.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `total_cost`, `status` |

### Task

For `id BETWEEN 1 AND 2000`, sort by `total_cost DESC` then `id ASC`. Limit 30.

### Expected result (real rows from the dump)

```text
+------+------------+---------------+
| id   | total_cost | status        |
+------+------------+---------------+
| 2000 |     700.00 | cancelled     |
| 1999 |     699.90 | completed     |
| 1998 |     699.80 | waiting_parts |
| 1997 |     699.70 | in_progress   |
| 1996 |     699.60 | new           |
| ...  |            |               |
+------+------------+---------------+
```

### Hint

Two-key `ORDER BY`. The second key breaks ties for a deterministic order.

### Solution

```sql
SELECT id,
       total_cost,
       status
FROM work_orders
WHERE id BETWEEN 1 AND 2000
ORDER BY total_cost DESC, id ASC
LIMIT 30;
```

### Step-by-step explanation

1. **`ORDER BY total_cost DESC`** sorts descending.
2. **`, id ASC`** is the **tiebreaker**: when two rows have the same cost, the lower `id` wins. Without it, the order between ties is implementation-defined and can change between runs.
3. **`LIMIT 30`** applies after sorting — this is how "top-N" queries work.

---

## Exercise 9 — `DISTINCT`

### Context

Two enum-like dropdowns in the admin UI: a list of order statuses currently in use, and a list of part brands currently stocked.

### What you'll learn

- `DISTINCT` removes duplicates across the selected expression(s).

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `status` |
| `parts` | `id`, `brand` |

### Task

Two independent queries:

1. Unique `status` values from `work_orders` (`id BETWEEN 1 AND 20000`).
2. Unique `brand` values from `parts` (`id BETWEEN 1 AND 5000`, `brand IS NOT NULL`).

### Expected result (real rows from the dump — query 1)

```text
+---------------+
| status        |
+---------------+
| cancelled     |
| completed     |
| in_progress   |
| new           |
| waiting_parts |
+---------------+
```

### Hint

`SELECT DISTINCT col FROM ...`. No aggregate, no `GROUP BY`.

### Solution

```sql
SELECT DISTINCT status
FROM work_orders
WHERE id BETWEEN 1 AND 20000;

SELECT DISTINCT brand
FROM parts
WHERE id BETWEEN 1 AND 5000
  AND brand IS NOT NULL;
```

### Step-by-step explanation

1. **`DISTINCT`** deduplicates on the **whole tuple of selected columns**, not per column individually.
2. For a single column it's equivalent to `GROUP BY` without aggregates — but `DISTINCT` is more idiomatic for "give me the unique values" intent.
3. **`brand IS NOT NULL`** in the second query: otherwise `NULL` appears as one of the "values".

---

## Exercise 10 — `LIMIT`

### Context

Show a quick preview list of 12 parts on the inventory landing page.

### What you'll learn

- `LIMIT n` to cap output size.
- Combining `ORDER BY` with `LIMIT` for predictable previews.

### Tables in play

| Table | Columns |
|---|---|
| `parts` | `id`, `sku`, `name` |

### Task

First 12 rows from `parts` with `id BETWEEN 1 AND 10000`, sorted by `id` ascending.

### Expected result (real rows from the dump)

```text
+----+--------------+---------+
| id | sku          | name    |
+----+--------------+---------+
|  1 | SKU-00000001 | Part_1  |
|  2 | SKU-00000002 | Part_2  |
| ...|              |         |
| 12 | SKU-00000012 | Part_12 |
+----+--------------+---------+
```

### Hint

`ORDER BY id` to make "first 12" meaningful, then `LIMIT 12`.

### Solution

```sql
SELECT id,
       sku,
       name
FROM parts
WHERE id BETWEEN 1 AND 10000
ORDER BY id
LIMIT 12;
```

### Step-by-step explanation

1. **`LIMIT 12`** always runs after `ORDER BY`. Without an `ORDER BY` "first 12" has no meaning — MySQL can return any 12.
2. **Negative `LIMIT`** is a syntax error. To "skip" rows, use `OFFSET` (Exercise 11).

---

## Exercise 11 — `LIMIT … OFFSET …` (pagination)

### Context

Page 3 of a customer search (10 per page, so rows 21-30).

### What you'll learn

- `LIMIT n OFFSET m` for stateless pagination.
- Why `ORDER BY` becomes mandatory once you paginate.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `first_name`, `last_name` |

### Task

Return rows 21-30 of customers (`id BETWEEN 1 AND 500`), sorted by `id` ascending.

### Expected result (real rows from the dump)

```text
+----+------------+------------+
| id | first_name | last_name  |
+----+------------+------------+
| 21 | Name_21    | Surname_21 |
| 22 | Name_22    | Surname_22 |
| ...|            |            |
| 30 | Name_30    | Surname_30 |
+----+------------+------------+
```

### Hint

`OFFSET 20` skips the first 20 rows; `LIMIT 10` then takes the next 10.

### Solution

```sql
SELECT id,
       first_name,
       last_name
FROM customers
WHERE id BETWEEN 1 AND 500
ORDER BY id
LIMIT 10 OFFSET 20;
```

### Step-by-step explanation

1. **`OFFSET m`** counts rows from the start of the sorted result; **the first row is offset 0**.
2. **`ORDER BY` is mandatory** for pagination. Without it, you can see duplicates or skip rows between pages.
3. **Performance:** `OFFSET 1000000` is slow — MySQL has to discard a million rows. Use keyset pagination (`WHERE id > last_seen_id`) for very deep pages.

---

## Exercise S1 — `INNER JOIN` (vehicles + brand name)

### Context

The garage check-in form shows the brand name next to the plate — but `vehicles` only stores `brand_id`. We need to join with `car_brands` for the human-readable label.

### What you'll learn

- Simplest `INNER JOIN` on a foreign key.
- Table aliases for readability.

### Tables in play

| Table | Columns |
|---|---|
| `vehicles` | `id`, `plate`, `brand_id` |
| `car_brands` | `id`, `name` |

### Task

Return `vehicle_id`, `plate`, `brand_name` for `v.id BETWEEN 1 AND 150`. Limit 25.

### Expected result (real rows from the dump)

```text
+------------+----------+------------+
| vehicle_id | plate    | brand_name |
+------------+----------+------------+
|          1 | AA0001BB | Brand_001  |
|          2 | AA0002BB | Brand_002  |
| ...        |          |            |
|         25 | AA0025BB | Brand_025  |
+------------+----------+------------+
```

### Hint

`INNER JOIN car_brands b ON b.id = v.brand_id`.

### Solution

```sql
SELECT v.id    AS vehicle_id,
       v.plate,
       b.name  AS brand_name
FROM vehicles  AS v
INNER JOIN car_brands AS b ON b.id = v.brand_id
WHERE v.id BETWEEN 1 AND 150
LIMIT 25;
```

### Step-by-step explanation

1. **`INNER JOIN`** returns only rows that have a match in **both** tables. If `vehicles.brand_id` were `NULL`, that row would be excluded — use `LEFT JOIN` instead when you want to keep the left side.
2. **`ON b.id = v.brand_id`** is the join condition. With `USING (brand_id)` you can shorten it if both columns share the same name.
3. **Aliases `v` / `b`** keep the query readable. Without them every column would need the full table name.

---

## Exercise S2 — Multi-table `JOIN` (work order + vehicle + customer)

### Context

Receipt header: order id, customer's last name, vehicle plate, total amount — that's the minimum the cashier prints.

### What you'll learn

- Chaining two `INNER JOIN`s.
- Why the order of joined tables doesn't change semantics for `INNER JOIN`.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `total_cost` |
| `vehicles` | `id`, `customer_id`, `plate` |
| `customers` | `id`, `last_name` |

### Task

Return `work_order_id`, `customers.last_name`, `vehicles.plate`, `work_orders.total_cost` for `wo.id BETWEEN 1 AND 200`. Limit 20.

### Expected result (real rows from the dump)

```text
+---------------+-----------+----------+------------+
| work_order_id | last_name | plate    | total_cost |
+---------------+-----------+----------+------------+
|             1 | Surname_1 | AA0001BB |     500.10 |
|             2 | Surname_2 | AA0002BB |     500.20 |
| ...           |           |          |            |
|            20 | Surname_20| AA0020BB |     502.00 |
+---------------+-----------+----------+------------+
```

### Hint

Chain: `work_orders → vehicles (on vehicle_id) → customers (on customer_id)`.

### Solution

```sql
SELECT wo.id      AS work_order_id,
       c.last_name,
       v.plate,
       wo.total_cost
FROM work_orders AS wo
INNER JOIN vehicles  AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
WHERE wo.id BETWEEN 1 AND 200
LIMIT 20;
```

### Step-by-step explanation

1. **Chain joins by foreign keys.** The chain `work_orders → vehicles → customers` mirrors the real-world hierarchy.
2. **Each `ON` clause connects the next pair.** Forgetting one creates a Cartesian product (every row of `work_orders` × every row of `vehicles`), which can be millions of rows.
3. **`INNER JOIN` drops rows without a match.** If `vehicle.customer_id` were `NULL` for some vehicles, those work orders would not appear — use `LEFT JOIN` in such cases.

---

## Troubleshooting: my query returned 0 rows

| Symptom | Likely fix |
|---|---|
| Empty result on a `WHERE id BETWEEN x AND y` filter | Widen the range; tables have ~100k rows. |
| Empty result after `HAVING` | Lower the `COUNT` / `AVG` thresholds. |
| `LIKE 'pattern%'` doesn't match | Check case sensitivity; remember `_` is a wildcard. |
| `IS NOT NULL` returns nothing | Verify the column actually has non-`NULL` values: `SELECT COUNT(*) FROM t WHERE col IS NULL`. |
| Pagination drops/duplicates rows | Add a stable `ORDER BY` (use `id` as last key). |

If you want to run **all** examples at once: `mysql -t -u root car_service_db < 03_mysql/04_dql/car_service_dql_examples.sql`.
