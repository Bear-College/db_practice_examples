# Subqueries — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/06_subqueries/subqueries_car_service_db.md)

These exercises walk through **subquery patterns** that appear in everyday SQL: a query inside another query in `WHERE`, in `FROM`, in `HAVING`, or alongside `EXISTS` / `NOT EXISTS`. They run on the real database loaded from **`01_database_mysql/car_service_db.sql.gz`** (database name: **`car_service_db`**).

Runnable companion file: [`06_subqueries/car_service_subqueries_examples.sql`](car_service_subqueries_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/06_subqueries/car_service_subqueries_examples.sql
```

**Performance:** the dump is large (each main table has ~100k rows). Every exercise uses **`WHERE id BETWEEN …`** to keep the subquery and its outer query fast during class.

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real shop would run this query (1-2 sentences). |
| **What you'll learn** | Subquery pattern trained in this exact exercise. |
| **Tables in play** | Only the columns you actually need. |
| **Task** | Concrete requirements (filter, sort, limit). |
| **Expected result** | Real rows from the dump (copied from a live run). |
| **Hint** | A single nudge toward the right subquery shape. |
| **Solution** | Working SQL you can paste into `mysql`. |
| **Step-by-step explanation** | What each clause does and the typical mistakes. |

---

## Map: subquery patterns (easy → hard)

| Level | Pattern | What to learn |
|-------|---------|----------------|
| **Easy** | `IN (SELECT …)` | Subquery returns a column of values; outer row matches any of them. |
| **Easy** | Scalar `> (SELECT AVG(…))` | Subquery returns exactly one value used in a comparison. |
| **Easy** | `FROM (SELECT …) AS alias` | Derived table: treat a `SELECT` as a table inside `FROM`. |
| **Easy** | `EXISTS (SELECT 1 …)` | True if the subquery returns any row at all. |
| **Hard** | **Correlated** subquery | Inner `SELECT` references a column from the outer row. |
| **Hard** | `NOT EXISTS` | Rows for which **no** matching row exists in the subquery. |
| **Hard** | Nested `IN` | Inner queries feed outer ones; mind `NULL` with `NOT IN`. |
| **Hard** | Subquery in `HAVING` | Compare an aggregate to a value computed by another `SELECT`. |
| **Hard** | Correlated `EXISTS` with `JOIN` | Subquery joins through a bridge to test a condition on the outer row. |

---

## Schema touchpoints (from the dump)

- **`work_orders`** — `id`, `vehicle_id`, `assigned_mechanic_id`, `status`, `total_cost`
- **`vehicles`** — `id`, `customer_id`
- **`customers`** — `id`, `first_name`, `last_name`
- **`feedback`** — `id`, `customer_id`, `rating`
- **`appointments`** — `id`, `vehicle_id`, `status`
- **`employees`** — `id`, `first_name`, `last_name`, `role_id`
- **`roles`** — `id`, `title`

---

## Exercise E1 — `WHERE … IN (SELECT …)` (non-correlated)

### Context

The dispatcher needs every work order tied to the **first 150 vehicles** the shop ever registered — say, to audit historical turnaround on long-standing customers. `work_orders` has no direct `vehicle.first_seen` column, so we look up the matching `vehicle.id` values in a subquery.

### What you'll learn

- A non-correlated subquery returning a **list** of values.
- Using `IN (SELECT …)` to express semantically "this column is one of those".
- Keeping both queries fast by bounding each with a `BETWEEN` filter.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `status`, `total_cost` |
| `vehicles` | `id` |

### Task

Return `id`, `vehicle_id`, `status`, `total_cost` from `work_orders` where `vehicle_id` is in the slice `vehicles.id BETWEEN 1 AND 150` and the outer `work_orders.id BETWEEN 1 AND 5000`. Cap at 25 rows.

### Expected result (real rows from the dump)

```text
+----+------------+---------------+------------+
| id | vehicle_id | status        | total_cost |
+----+------------+---------------+------------+
|  1 |          1 | new           |     500.10 |
|  2 |          2 | in_progress   |     500.20 |
|  3 |          3 | waiting_parts |     500.30 |
|  4 |          4 | completed     |     500.40 |
|  5 |          5 | cancelled     |     500.50 |
| ...|            |               |            |
| 25 |         25 | cancelled     |     502.50 |
+----+------------+---------------+------------+
```

### Hint

The subquery returns one column of `vehicle.id` values; wrap it in `IN (...)`.

### Solution

```sql
SELECT wo.id,
       wo.vehicle_id,
       wo.status,
       wo.total_cost
FROM work_orders AS wo
WHERE wo.vehicle_id IN (
  SELECT v.id
  FROM vehicles AS v
  WHERE v.id BETWEEN 1 AND 150
)
  AND wo.id BETWEEN 1 AND 5000
LIMIT 25;
```

### Step-by-step explanation

1. **Inner query** `SELECT v.id FROM vehicles WHERE v.id BETWEEN 1 AND 150` returns up to 150 `vehicle.id` values. It is **non-correlated** — it doesn't reference the outer `wo` row, so MySQL can run it once and reuse the result.
2. **`wo.vehicle_id IN (…)`** keeps only work orders whose `vehicle_id` matches one of those ids — a semi-join.
3. **`AND wo.id BETWEEN 1 AND 5000`** bounds the outer scan so we don't touch all 100 000 work orders.
4. **Gotcha — `NULL`:** if the inner list contained any `NULL` and you used `NOT IN`, the whole predicate becomes `NULL` (no rows match). Always filter `IS NOT NULL` in the inner query before using `NOT IN`.

---

## Exercise E2 — Scalar subquery (`SELECT AVG(…)`) used in comparison

### Context

The accountant wants the **above-average tickets** in the most recent 80 000 work orders to investigate why they're so expensive. "Above average" must compare to the average computed **from the same slice**, not from the whole table.

### What you'll learn

- A subquery that returns exactly one value (a **scalar**).
- Using a scalar subquery both in the `SELECT` list (to expose the threshold) and in `WHERE` (to filter).
- Why MySQL is happy to evaluate the inner average only once.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Task

For `work_orders.id BETWEEN 1 AND 80000`, return `id`, `total_cost`, and `slice_avg_cost` (the average over the same slice). Keep only rows with `total_cost >= slice_avg_cost`. Sort by `total_cost` descending. Limit 20.

### Expected result (real rows from the dump)

```text
+-------+------------+----------------+
| id    | total_cost | slice_avg_cost |
+-------+------------+----------------+
| 49999 |    5499.90 |    2624.987500 |
| 49998 |    5499.80 |    2624.987500 |
| 49997 |    5499.70 |    2624.987500 |
| 49996 |    5499.60 |    2624.987500 |
| 49995 |    5499.50 |    2624.987500 |
| ...   |            |                |
| 49980 |    5498.00 |    2624.987500 |
+-------+------------+----------------+
```

### Hint

The subquery `(SELECT AVG(total_cost) FROM work_orders WHERE id BETWEEN 1 AND 80000)` returns one number. Use it twice: once as a column in `SELECT`, once as the right side of `>=`.

### Solution

```sql
SELECT wo.id,
       wo.total_cost,
       (SELECT AVG(w2.total_cost)
        FROM work_orders AS w2
        WHERE w2.id BETWEEN 1 AND 80000) AS slice_avg_cost
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 80000
  AND wo.total_cost >= (
        SELECT AVG(w3.total_cost)
        FROM work_orders AS w3
        WHERE w3.id BETWEEN 1 AND 80000
      )
ORDER BY wo.total_cost DESC
LIMIT 20;
```

### Step-by-step explanation

1. **Scalar subquery in `SELECT`** — `(SELECT AVG(…) FROM …)` must return exactly **one row, one column**. If it returns more, MySQL raises `Subquery returns more than 1 row`.
2. **Same subquery in `WHERE`** — written twice for readability; MySQL can optimise the duplicate into a single evaluation. If you preferred, you could move the scalar into a derived table and `JOIN` to it instead.
3. **`ORDER BY total_cost DESC`** is what makes "top of the above-average band" meaningful.
4. **Pitfall — single-pass vs nested aggregates:** you cannot write `WHERE total_cost >= AVG(total_cost)` directly. `WHERE` runs before grouping, so the aggregate has no group to operate on. The subquery is the standard way around it.

---

## Exercise E3 — Derived table in `FROM (SELECT … GROUP BY …) AS alias`

### Context

The CRM dashboard wants a "customers and their fleet size" widget: how many vehicles are registered to each customer. A derived table groups the vehicles first, then we join back to `customers` for human-readable names.

### What you'll learn

- Treating a `SELECT` as a virtual table inside `FROM`.
- Pre-aggregating in the subquery, then joining to the original table for labels.
- Why this is the idiomatic alternative to a window function on older MySQL.

### Tables in play

| Table | Columns |
|---|---|
| `vehicles` | `id`, `customer_id` |
| `customers` | `id`, `last_name` |

### Task

In a derived table named `vc`, group `vehicles` (`id BETWEEN 1 AND 10000`, `customer_id IS NOT NULL`) by `customer_id` and count rows as `vehicle_n`. Join to `customers` and return `customer_id`, `last_name`, `vehicle_n`. Sort by `vehicle_n DESC, customer_id`. Limit 20.

### Expected result (real rows from the dump)

```text
+-------------+------------+-----------+
| customer_id | last_name  | vehicle_n |
+-------------+------------+-----------+
|           1 | Surname_1  |         1 |
|           2 | Surname_2  |         1 |
|           3 | Surname_3  |         1 |
|           4 | Surname_4  |         1 |
|           5 | Surname_5  |         1 |
| ...         |            |           |
|          20 | Surname_20 |         1 |
+-------------+------------+-----------+
```

### Hint

Wrap a `GROUP BY` in `FROM (…) AS vc`, then `INNER JOIN customers AS c ON c.id = vc.customer_id`.

### Solution

```sql
SELECT vc.customer_id,
       c.last_name,
       vc.vehicle_n
FROM (
       SELECT customer_id,
              COUNT(*) AS vehicle_n
       FROM vehicles
       WHERE id BETWEEN 1 AND 10000
         AND customer_id IS NOT NULL
       GROUP BY customer_id
     ) AS vc
INNER JOIN customers AS c ON c.id = vc.customer_id
WHERE vc.vehicle_n >= 1
ORDER BY vc.vehicle_n DESC, vc.customer_id
LIMIT 20;
```

### Step-by-step explanation

1. **The derived table** `vc` is built first: for each `customer_id` in the slice, count the vehicles. The result is treated like a regular table for the rest of the query.
2. **`INNER JOIN customers`** brings in the `last_name`. Without it we would only have the foreign key.
3. **`AS vc` is mandatory** — every derived table needs an alias in MySQL; otherwise you get a syntax error.
4. **Two-key `ORDER BY`** breaks ties deterministically. Without `customer_id` as the second key, rows with the same `vehicle_n` could appear in any order.
5. **Why not a window function?** `COUNT(*) OVER (PARTITION BY customer_id)` would also work in MySQL 8+, but the derived table is portable to older engines and easier to read for beginners.

---

## Exercise E4 — `EXISTS (SELECT 1 …)`

### Context

Marketing wants to send a "thank-you" coupon to every customer in the early-id batch (`1..500`) who has **ever left feedback**. We don't care what the feedback said — just whether at least one row exists.

### What you'll learn

- `EXISTS` is a boolean test: "does the inner query return any row at all?"
- Writing `SELECT 1` inside `EXISTS` — the column list doesn't matter, only the row count.
- Why `EXISTS` is often faster than `IN (SELECT …)` when the inner query is large.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `first_name`, `last_name` |
| `feedback` | `id`, `customer_id` |

### Task

Return `id`, `first_name`, `last_name` for customers with `id BETWEEN 1 AND 500` for whom there is at least one row in `feedback` (also bounded by `f.id BETWEEN 1 AND 200000`). Limit 30.

### Expected result (real rows from the dump)

```text
+----+------------+------------+
| id | first_name | last_name  |
+----+------------+------------+
|  1 | Name_1     | Surname_1  |
|  2 | Name_2     | Surname_2  |
|  3 | Name_3     | Surname_3  |
|  4 | Name_4     | Surname_4  |
|  5 | Name_5     | Surname_5  |
| ...|            |            |
| 30 | Name_30    | Surname_30 |
+----+------------+------------+
```

### Hint

`EXISTS (SELECT 1 FROM feedback WHERE customer_id = c.id …)`. The inner `WHERE` references `c.id` from the outer query — that is what makes the test "for this customer".

### Solution

```sql
SELECT c.id,
       c.first_name,
       c.last_name
FROM customers AS c
WHERE c.id BETWEEN 1 AND 500
  AND EXISTS (
    SELECT 1
    FROM feedback AS f
    WHERE f.customer_id = c.id
      AND f.id BETWEEN 1 AND 200000
  )
LIMIT 30;
```

### Step-by-step explanation

1. **`EXISTS (…)`** stops scanning the inner query as soon as it finds one matching row, so it's cheap when the relation is one-to-many.
2. **`SELECT 1`** is idiomatic — `SELECT *`, `SELECT f.id`, or `SELECT NULL` all work the same. Only the existence of a row matters.
3. **Inner `f.customer_id = c.id`** is the correlation: every time the outer cursor moves to a new customer, the inner query effectively re-runs for that `c.id`.
4. **Compare with `IN`:** `c.id IN (SELECT customer_id FROM feedback …)` would also work. Pick `EXISTS` when the inner table is huge — it short-circuits at the first match.

---

## Exercise H1 — Correlated subquery exposing the global average

### Context

Same "above average" idea as E2 but bigger: the operations lead wants to see the **most expensive 25 work orders in the first 8 000** alongside the **global average** computed across a much larger slice. They will eyeball the gap.

### What you'll learn

- A scalar subquery that references a wider slice than the outer query.
- The difference between a **correlated** and **non-correlated** scalar subquery. (This one is non-correlated, but introduces the shape.)
- Sorting on the outer column while a constant computed by the subquery rides along.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `assigned_mechanic_id`, `total_cost` |

### Task

For `wo.id BETWEEN 1 AND 8000` with `total_cost IS NOT NULL`, return `id`, `assigned_mechanic_id`, `total_cost`, and a `global_avg_cost` column from a scalar subquery over `work_orders.id BETWEEN 1 AND 200000`. Sort by `total_cost` descending. Limit 25.

### Expected result (real rows from the dump)

```text
+------+----------------------+------------+-----------------+
| id   | assigned_mechanic_id | total_cost | global_avg_cost |
+------+----------------------+------------+-----------------+
| 8000 |                 8000 |    1300.00 |     2999.950000 |
| 7999 |                 7999 |    1299.90 |     2999.950000 |
| 7998 |                 7998 |    1299.80 |     2999.950000 |
| 7997 |                 7997 |    1299.70 |     2999.950000 |
| 7996 |                 7996 |    1299.60 |     2999.950000 |
| ...  |                      |            |                 |
| 7976 |                 7976 |    1297.60 |     2999.950000 |
+------+----------------------+------------+-----------------+
```

### Hint

The scalar `(SELECT AVG(...) FROM work_orders WHERE id BETWEEN 1 AND 200000)` returns the same number for every row — it's evaluated once.

### Solution

```sql
SELECT wo.id,
       wo.assigned_mechanic_id,
       wo.total_cost,
       (SELECT AVG(wb.total_cost)
        FROM work_orders AS wb
        WHERE wb.id BETWEEN 1 AND 200000) AS global_avg_cost
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 8000
  AND wo.total_cost IS NOT NULL
ORDER BY wo.total_cost DESC
LIMIT 25;
```

### Step-by-step explanation

1. **Scalar subquery in `SELECT`** projects the same `global_avg_cost` onto every returned row — handy for dashboards that want each row to know its baseline.
2. **Non-correlated**: the inner query has no reference to `wo` and is evaluated once. To make it **correlated**, you would replace the outer `BETWEEN` with something like `WHERE wb.assigned_mechanic_id = wo.assigned_mechanic_id` — see exercise H4 for that pattern.
3. **`total_cost IS NOT NULL`** guards against missing values that would otherwise distort sort order and ranking.
4. **Performance:** without indexes on `id` the slice scan is unavoidable. With the existing PRIMARY KEY on `id`, MySQL uses a range scan.

---

## Exercise H2 — `NOT EXISTS`

### Context

Quality-control flag: list customers who have **no** "sentinel" feedback row (rating `999`, used internally as a tombstone). In this dataset no row ever has rating `999`, so the query effectively returns "every customer in the range" — a useful baseline to teach the shape without surprises.

### What you'll learn

- `NOT EXISTS` for anti-semi-joins.
- Why `NOT EXISTS` is safer than `NOT IN` when the inner column can be `NULL`.
- A predictable degenerate case: an inner predicate that never matches.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `first_name`, `last_name` |
| `feedback` | `customer_id`, `rating` |

### Task

Return `id`, `first_name`, `last_name` for customers with `id BETWEEN 1 AND 300` who have **no** feedback row with `rating = 999`. Limit 30.

### Expected result (real rows from the dump)

```text
+----+------------+------------+
| id | first_name | last_name  |
+----+------------+------------+
|  1 | Name_1     | Surname_1  |
|  2 | Name_2     | Surname_2  |
|  3 | Name_3     | Surname_3  |
|  4 | Name_4     | Surname_4  |
|  5 | Name_5     | Surname_5  |
| ...|            |            |
| 30 | Name_30    | Surname_30 |
+----+------------+------------+
```

### Hint

`NOT EXISTS` mirrors `EXISTS`: flip the outer predicate, keep the same correlated inner query.

### Solution

```sql
SELECT c.id,
       c.first_name,
       c.last_name
FROM customers AS c
WHERE c.id BETWEEN 1 AND 300
  AND NOT EXISTS (
    SELECT 1
    FROM feedback AS f
    WHERE f.customer_id = c.id
      AND f.rating = 999
  )
LIMIT 30;
```

### Step-by-step explanation

1. **`NOT EXISTS`** is true when the inner query returns **zero rows**. In real datasets you would replace `f.rating = 999` with a meaningful predicate, e.g. `f.rating IS NULL` or `f.created_at < '2020-01-01'`.
2. **`f.rating = 999`** never matches in this dump (ratings are `1..5`), so every customer in the range passes the filter — useful for showing the **shape** without distractions.
3. **Why prefer `NOT EXISTS` over `NOT IN`?** When the inner `SELECT` can return `NULL`, `NOT IN (NULL, …)` evaluates to `NULL` and drops rows silently. `NOT EXISTS` is `NULL`-safe by construction.
4. **Common bug:** forgetting the `f.customer_id = c.id` correlation. Without it the inner query asks "is there *any* feedback row with rating 999 *anywhere*?" — semantically very different.

---

## Exercise H3 — Nested `IN` over a lookup table

### Context

HR needs the contact list of every mechanic in the early-id batch (`employees.id BETWEEN 1 AND 2000`). "Mechanic" isn't a column on `employees` — it lives in the `roles` lookup as a `title` string. We push the title filter into a subquery on `roles` and pass the matching role ids to the outer query.

### What you'll learn

- Looking up surrogate keys through a side table.
- Using `LIKE '%Mechanic%'` for "fuzzy job title" matching.
- Why this pattern is preferred over a `JOIN` when you don't need any columns from the lookup.

### Tables in play

| Table | Columns |
|---|---|
| `employees` | `id`, `first_name`, `last_name`, `role_id` |
| `roles` | `id`, `title` |

### Task

Return `id`, `first_name`, `last_name`, `role_id` from `employees` with `id BETWEEN 1 AND 2000` whose `role_id` matches any role whose `title LIKE '%Mechanic%'`. Limit 25.

### Expected result (real rows from the dump)

```text
+-----+-------------+----------------+---------+
| id  | first_name  | last_name      | role_id |
+-----+-------------+----------------+---------+
|   1 | EmpName_1   | EmpSurname_1   |       1 |
|  11 | EmpName_11  | EmpSurname_11  |       1 |
|  21 | EmpName_21  | EmpSurname_21  |       1 |
|  31 | EmpName_31  | EmpSurname_31  |       1 |
|  41 | EmpName_41  | EmpSurname_41  |       1 |
| ... |             |                |         |
| 241 | EmpName_241 | EmpSurname_241 |       1 |
+-----+-------------+----------------+---------+
```

### Hint

The inner query is `SELECT r.id FROM roles WHERE r.title LIKE '%Mechanic%'`. Plug that into `e.role_id IN (...)`.

### Solution

```sql
SELECT e.id,
       e.first_name,
       e.last_name,
       e.role_id
FROM employees AS e
WHERE e.id BETWEEN 1 AND 2000
  AND e.role_id IN (
    SELECT r.id
    FROM roles AS r
    WHERE r.title LIKE '%Mechanic%'
  )
LIMIT 25;
```

### Step-by-step explanation

1. **Inner query** returns the small set of `role.id` values whose title contains `Mechanic`. Because `roles` has only a handful of rows, MySQL can hash the result and probe `e.role_id` against it efficiently.
2. **`LIKE '%Mechanic%'`** uses leading `%`, which **cannot** use a regular B-tree index. That's fine here because `roles` is tiny — but the same pattern on a 100-million-row table is slow.
3. **Equivalent `JOIN`:** `INNER JOIN roles r ON r.id = e.role_id WHERE r.title LIKE '%Mechanic%'`. Use the join if you also want columns from `roles`; use `IN` when you don't.
4. **Why not `EXISTS`?** Both work. `IN` reads more naturally here because the inner result is a small fixed set.

---

## Exercise H4 — Subquery in `HAVING` (aggregate compared to derived constant)

### Context

The shop wants the **busy mechanics** — those whose total workload over a slice of work orders is at least as big as the **average workload per mechanic** in that same slice. The "average workload" itself is an aggregate over an aggregate, so we compute it in a derived subquery and compare in `HAVING`.

### What you'll learn

- Aggregating, then comparing the aggregate to another aggregate.
- Nesting `SELECT COUNT(*) … GROUP BY …` inside `SELECT AVG(cnt)`.
- Using `HAVING` to filter groups by a computed threshold.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `assigned_mechanic_id` |

### Task

For `work_orders.id BETWEEN 1 AND 100000` with `assigned_mechanic_id IS NOT NULL`, group by `assigned_mechanic_id` and count rows. Keep only mechanics whose count is `>=` the average count per mechanic in the same slice. Sort by `wo_cnt DESC`. Limit 15.

### Expected result (real rows from the dump)

```text
+----------------------+--------+
| assigned_mechanic_id | wo_cnt |
+----------------------+--------+
|                94898 |      1 |
|                94899 |      1 |
|                94900 |      1 |
|                94901 |      1 |
|                94902 |      1 |
| ...                  |        |
|                94912 |      1 |
+----------------------+--------+
```

### Hint

Wrap the per-mechanic count in another `SELECT AVG(cnt)`, and compare in `HAVING COUNT(*) >= (…)`.

### Solution

```sql
SELECT wo.assigned_mechanic_id,
       COUNT(*) AS wo_cnt
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 100000
  AND wo.assigned_mechanic_id IS NOT NULL
GROUP BY wo.assigned_mechanic_id
HAVING COUNT(*) >= (
  SELECT AVG(cnt)
  FROM (
         SELECT COUNT(*) AS cnt
         FROM work_orders AS w2
         WHERE w2.id BETWEEN 1 AND 100000
           AND w2.assigned_mechanic_id IS NOT NULL
         GROUP BY w2.assigned_mechanic_id
       ) AS per_mechanic
)
ORDER BY wo_cnt DESC
LIMIT 15;
```

### Step-by-step explanation

1. **Inner derived table** `per_mechanic` returns one row per mechanic with their count. `SELECT AVG(cnt) FROM per_mechanic` collapses that to a single number — the average workload.
2. **`HAVING COUNT(*) >= (…)`** filters **groups** after `GROUP BY`. `WHERE COUNT(*) >= …` is a syntax error.
3. **In this dump** every mechanic has roughly the same count (close to 1), so the average is ~1 and most mechanics pass — the result demonstrates the **shape** rather than a dramatic cut.
4. **Common mistake:** forgetting the derived table alias `AS per_mechanic` — MySQL requires every subquery in `FROM` to be named.

---

## Exercise H5 — Correlated `EXISTS` with a `JOIN` inside

### Context

The reception desk wants the list of customers who have **at least one confirmed upcoming appointment**. There's no direct link from `customers` to `appointments`; it goes through `vehicles`. The cleanest way is `EXISTS` with a small inner `JOIN`.

### What you'll learn

- Combining `EXISTS` with a multi-table join inside the subquery.
- Correlating two levels deep: outer `customers.id` ↔ inner `vehicles.customer_id`.
- Using `EXISTS` instead of `INNER JOIN … GROUP BY` to avoid row multiplication.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `first_name`, `last_name` |
| `vehicles` | `id`, `customer_id` |
| `appointments` | `id`, `vehicle_id`, `status` |

### Task

Return `id`, `first_name`, `last_name` of customers with `id BETWEEN 1 AND 400` for whom there is at least one row in `vehicles JOIN appointments` where the vehicle belongs to the customer, the appointment is `confirmed`, and `appointments.id BETWEEN 1 AND 200000`. Limit 25.

### Expected result (real rows from the dump)

```text
+----+------------+------------+
| id | first_name | last_name  |
+----+------------+------------+
|  2 | Name_2     | Surname_2  |
|  6 | Name_6     | Surname_6  |
| 10 | Name_10    | Surname_10 |
| 14 | Name_14    | Surname_14 |
| 18 | Name_18    | Surname_18 |
| ...|            |            |
| 98 | Name_98    | Surname_98 |
+----+------------+------------+
```

### Hint

Inside the `EXISTS`, `INNER JOIN vehicles … appointments` and correlate on `v.customer_id = c.id`.

### Solution

```sql
SELECT c.id,
       c.first_name,
       c.last_name
FROM customers AS c
WHERE c.id BETWEEN 1 AND 400
  AND EXISTS (
    SELECT 1
    FROM vehicles AS v
    INNER JOIN appointments AS a ON a.vehicle_id = v.id
    WHERE v.customer_id = c.id
      AND a.status = 'confirmed'
      AND a.id BETWEEN 1 AND 200000
  )
LIMIT 25;
```

### Step-by-step explanation

1. **Two-level correlation:** the inner `WHERE v.customer_id = c.id` ties the subquery to the outer customer. For each candidate `c`, MySQL probes the join.
2. **`INNER JOIN` inside `EXISTS`** is perfectly fine — only the row count of the inner result matters. The result of the join is never returned to the caller.
3. **`a.status = 'confirmed'`** is a string equality on a small enum-like domain.
4. **Why not `SELECT DISTINCT c.id … JOIN …`?** It also works but ships an intermediate result that you then have to deduplicate. `EXISTS` is the more **honest** way to express "at least one match".
5. **Notice the result** — only every 4th customer (`id MOD 4 = 2` here) has a confirmed appointment in the first 200 000, which is exactly how the dump was generated.

---

## Troubleshooting: my subquery is slow or empty

| Symptom | Likely fix |
|---|---|
| `Subquery returns more than 1 row` | Your scalar subquery returns >1 row. Add `LIMIT 1` (rarely correct) or rewrite as `IN` / `JOIN`. |
| `NOT IN` with `NULL` returns nothing | Inner subquery returned a `NULL`. Add `WHERE col IS NOT NULL` to the inner query, or use `NOT EXISTS`. |
| Outer query slow with correlated subquery | Add an index on the correlated column, or rewrite as a `JOIN` / window function. |
| `EXISTS` always true | The inner query has no correlation predicate (`f.customer_id = c.id` missing). |
| Derived table missing alias | MySQL requires `FROM (…) AS alias`. Don't omit the `AS name`. |

If you want to run **all** examples at once: `mysql -t -u root car_service_db < 03_mysql/06_subqueries/car_service_subqueries_examples.sql`.
