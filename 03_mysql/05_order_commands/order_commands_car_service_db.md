# Порядок команд у SQL-запитах / SQL clause order — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/05_order_commands/order_commands_car_service_db.md)

These exercises drill the **written order of clauses** in a `SELECT` — the order MySQL expects you to *type* them in (it differs from the *execution* order). Each exercise pairs a real shop scenario with a query that mixes more of the clause chain than the last, and ends with the canonical pagination patterns.

Companion script: [`05_order_commands/car_service_order_examples.sql`](car_service_order_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/05_order_commands/car_service_order_examples.sql
```

**Performance note:** the dump's main tables hold ~100 000 rows each. Every example uses `WHERE id BETWEEN …` to keep the scan small during a class.

---

## Written order of clauses

| # | Clause | Role (short) |
|---|---|---|
| 1 | **`SELECT`** | Which columns or aggregates to show. |
| 2 | **`FROM`** | Which table supplies the rows (the base relation). |
| 3 | **`JOIN`** | Connect additional tables (`INNER` / `LEFT` etc.). |
| 4 | **`WHERE`** | Filter **rows** **before** grouping. |
| 5 | **`GROUP BY`** | Split rows into groups (for aggregates). |
| 6 | **`HAVING`** | Filter **groups** **after** aggregation. |
| 7 | **`ORDER BY`** | Sort the result. |
| 8 | **`LIMIT`** | Cap the number of rows returned. |
| 9 | **`LIMIT … OFFSET …`** | Skip the first *N* rows then take the next (pagination). |

Not every query uses every clause. The execution order MySQL **runs** the query in is **different**: `FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT / OFFSET`. Understanding both orders is the whole point of this lesson.

---

## Schema touchpoints

Exercises use **`work_orders`**, **`vehicles`**, **`customers`**, and **`car_brands`**:

- **`customers`** — `id`, `first_name`, `last_name`
- **`vehicles`** — `id`, `customer_id`, `plate`, `brand_id`
- **`car_brands`** — `id`, `name`
- **`work_orders`** — `id`, `vehicle_id`, `status`, `total_cost`

Sample **`work_orders.status`** values: `new`, `in_progress`, `waiting_parts`, `completed`, `cancelled`.

---

## Exercise 1 — Full clause chain (page 1)

### Context

The owner wants a dashboard widget: "top customers by average ticket". For each customer we count how many work orders they own and what the average cost is — then keep only those with at least one order and an average above ₴300, sort by the average descending, and show the first page of 10 results.

### What you'll learn

- Writing every clause in the right order: `SELECT → FROM → JOIN → WHERE → GROUP BY → HAVING → ORDER BY → LIMIT … OFFSET`.
- Why `WHERE` filters rows but `HAVING` filters groups.
- Adding a tiebreaker (`c.id`) to the `ORDER BY` so pagination is deterministic.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `last_name` |
| `vehicles` | `id`, `customer_id` |
| `work_orders` | `id`, `vehicle_id`, `total_cost` |

### Task

For customers with `id BETWEEN 1 AND 20000` and work orders with `id BETWEEN 1 AND 200000`, group by customer and keep only those with `COUNT(wo.id) >= 1` and `AVG(wo.total_cost) > 300`. Sort by `avg_total_cost DESC`, then `c.id ASC`. Return the first 10 rows (`LIMIT 10 OFFSET 0`).

### Expected result (real rows from the dump)

```text
+-------------+---------------+------------------+----------------+
| customer_id | last_name     | work_order_count | avg_total_cost |
+-------------+---------------+------------------+----------------+
|       20000 | Surname_20000 |                1 |        2500.00 |
|       19999 | Surname_19999 |                1 |        2499.90 |
|       19998 | Surname_19998 |                1 |        2499.80 |
|       19997 | Surname_19997 |                1 |        2499.70 |
|       19996 | Surname_19996 |                1 |        2499.60 |
|       19995 | Surname_19995 |                1 |        2499.50 |
|       19994 | Surname_19994 |                1 |        2499.40 |
|       19993 | Surname_19993 |                1 |        2499.30 |
|       19992 | Surname_19992 |                1 |        2499.20 |
|       19991 | Surname_19991 |                1 |        2499.10 |
+-------------+---------------+------------------+----------------+
```

### Hint

Two `INNER JOIN`s through `vehicles`, aggregates in `SELECT`, the **row** filter in `WHERE`, the **group** filter in `HAVING`, then `ORDER BY ... DESC, c.id` and `LIMIT 10 OFFSET 0`.

### Solution

```sql
SELECT c.id AS customer_id,
       c.last_name,
       COUNT(wo.id) AS work_order_count,
       ROUND(AVG(wo.total_cost), 2) AS avg_total_cost
FROM customers AS c
INNER JOIN vehicles AS v ON v.customer_id = c.id
INNER JOIN work_orders AS wo ON wo.vehicle_id = v.id
WHERE c.id BETWEEN 1 AND 20000
  AND wo.id BETWEEN 1 AND 200000
GROUP BY c.id, c.last_name
HAVING COUNT(wo.id) >= 1
   AND AVG(wo.total_cost) > 300
ORDER BY avg_total_cost DESC, c.id
LIMIT 10 OFFSET 0;
```

### Step-by-step explanation

1. **`SELECT` is written first but evaluated last.** Aliases (`avg_total_cost`) defined here can be reused in `ORDER BY` but **not** in `WHERE` or `GROUP BY` (those run earlier).
2. **`FROM customers AS c`** picks the driving table; the two `INNER JOIN`s walk the FK chain `customers → vehicles → work_orders`.
3. **`WHERE` filters rows.** The `id BETWEEN` predicates are row-level, so they go here, not in `HAVING`.
4. **`GROUP BY c.id, c.last_name`** must list every non-aggregate from `SELECT` (`ONLY_FULL_GROUP_BY` is on by default in MySQL 8+).
5. **`HAVING`** sees the aggregates; `WHERE` cannot. `WHERE COUNT(*) >= 1` would be a syntax error.
6. **`ORDER BY avg_total_cost DESC, c.id`** uses the `SELECT` alias for the primary key and `c.id` as a stable tiebreaker — vital for pagination.
7. **`LIMIT 10 OFFSET 0`** is "page 1, 10 per page". `OFFSET 0` is the explicit default; some teams require it for clarity.

---

## Exercise 2 — Same chain, paginated (page 3)

### Context

The same dashboard widget, but the user clicks "page 3" — show rows 11–15. Pagination means we keep the **exact** same query body and just change `OFFSET` and `LIMIT`.

### What you'll learn

- Why `ORDER BY` is mandatory the moment you paginate.
- The `LIMIT n OFFSET m` form for stateless paging.

### Tables in play

Same as Exercise 1.

### Task

Same query as Exercise 1, but return rows 11–15 (`LIMIT 5 OFFSET 10`).

### Expected result (real rows from the dump)

```text
+-------------+---------------+------------------+----------------+
| customer_id | last_name     | work_order_count | avg_total_cost |
+-------------+---------------+------------------+----------------+
|       19990 | Surname_19990 |                1 |        2499.00 |
|       19989 | Surname_19989 |                1 |        2498.90 |
|       19988 | Surname_19988 |                1 |        2498.80 |
|       19987 | Surname_19987 |                1 |        2498.70 |
|       19986 | Surname_19986 |                1 |        2498.60 |
+-------------+---------------+------------------+----------------+
```

### Hint

Identical clauses up to `ORDER BY`; change only the final `LIMIT 5 OFFSET 10`.

### Solution

```sql
SELECT c.id AS customer_id,
       c.last_name,
       COUNT(wo.id) AS work_order_count,
       ROUND(AVG(wo.total_cost), 2) AS avg_total_cost
FROM customers AS c
INNER JOIN vehicles AS v ON v.customer_id = c.id
INNER JOIN work_orders AS wo ON wo.vehicle_id = v.id
WHERE c.id BETWEEN 1 AND 20000
  AND wo.id BETWEEN 1 AND 200000
GROUP BY c.id, c.last_name
HAVING COUNT(wo.id) >= 1
   AND AVG(wo.total_cost) > 300
ORDER BY avg_total_cost DESC, c.id
LIMIT 5 OFFSET 10;
```

### Step-by-step explanation

1. **The first 10 rows are skipped** by `OFFSET 10`, then the next 5 are returned by `LIMIT 5`. Rows are still chosen *after* sorting.
2. **Pagination needs a stable `ORDER BY`.** Without the deterministic tiebreaker `c.id`, two equal `avg_total_cost` values could swap places between pages and you'd see duplicates or gaps.
3. **`OFFSET 1000000` is slow.** MySQL still has to compute and discard the first million rows. For deep pagination, switch to a **keyset** strategy: `WHERE c.id > last_seen_id ORDER BY c.id LIMIT 10`.

---

## Exercise 3 — `ORDER BY` + `LIMIT` (no `OFFSET`)

### Context

The cashier wants the 12 most expensive work orders right now to call those customers and confirm payment.

### What you'll learn

- `SELECT → FROM → WHERE → ORDER BY → LIMIT` — the minimal "top-N" pattern.
- Why a tiebreaker (`wo.id`) avoids "flicker" between identical sort keys.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Task

Return the 12 work orders with the highest `total_cost` over the range `id BETWEEN 1 AND 50000`. Break ties with the lower `id`.

### Expected result (real rows from the dump)

```text
+-------+---------------+------------+
| id    | status        | total_cost |
+-------+---------------+------------+
| 49999 | completed     |    5499.90 |
| 49998 | waiting_parts |    5499.80 |
| 49997 | in_progress   |    5499.70 |
| 49996 | new           |    5499.60 |
| 49995 | cancelled     |    5499.50 |
| 49994 | completed     |    5499.40 |
| 49993 | waiting_parts |    5499.30 |
| 49992 | in_progress   |    5499.20 |
| 49991 | new           |    5499.10 |
| 49990 | cancelled     |    5499.00 |
| 49989 | completed     |    5498.90 |
| 49988 | waiting_parts |    5498.80 |
+-------+---------------+------------+
```

### Hint

`ORDER BY total_cost DESC, id` then `LIMIT 12`.

### Solution

```sql
SELECT wo.id,
       wo.status,
       wo.total_cost
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 50000
ORDER BY wo.total_cost DESC, wo.id
LIMIT 12;
```

### Step-by-step explanation

1. **No `GROUP BY`/`HAVING`** — every row is its own result; no aggregation needed.
2. **Two-key `ORDER BY`.** The first key (`total_cost DESC`) gives top spenders; the second (`wo.id ASC`) makes the order deterministic between runs.
3. **`LIMIT` is applied after sorting.** Without `ORDER BY`, "top 12" has no meaning — MySQL is free to return any 12.

---

## Exercise 4 — No `GROUP BY` / `HAVING` (joins + `LEFT JOIN`)

### Context

The receipt printer needs, for each work order in the day's range, a tidy line: order id, customer name, plate, brand, and total. Some vehicles have no brand_id, so we use `LEFT JOIN` for the brand and the row is still printed.

### What you'll learn

- Mixing `INNER JOIN` and `LEFT JOIN` in the same query.
- Why the order of joins doesn't matter for `INNER`s but matters for `LEFT`s.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `total_cost` |
| `vehicles` | `id`, `customer_id`, `plate`, `brand_id` |
| `customers` | `id`, `first_name`, `last_name` |
| `car_brands` | `id`, `name` |

### Task

For work orders with `id BETWEEN 1 AND 400`, return `work_order_id`, `customer first_name`, `last_name`, `plate`, `brand_name`, `total_cost`. Sort by `total_cost DESC` and cap at 15.

### Expected result (real rows from the dump — first 15)

```text
+---------------+------------+-------------+----------+------------+------------+
| work_order_id | first_name | last_name   | plate    | brand_name | total_cost |
+---------------+------------+-------------+----------+------------+------------+
|           400 | Name_400   | Surname_400 | AA0400BB | Brand_100  |     540.00 |
|           399 | Name_399   | Surname_399 | AA0399BB | Brand_099  |     539.90 |
|           398 | Name_398   | Surname_398 | AA0398BB | Brand_098  |     539.80 |
|           397 | Name_397   | Surname_397 | AA0397BB | Brand_097  |     539.70 |
|           396 | Name_396   | Surname_396 | AA0396BB | Brand_096  |     539.60 |
|           395 | Name_395   | Surname_395 | AA0395BB | Brand_095  |     539.50 |
|           394 | Name_394   | Surname_394 | AA0394BB | Brand_094  |     539.40 |
|           393 | Name_393   | Surname_393 | AA0393BB | Brand_093  |     539.30 |
|           392 | Name_392   | Surname_392 | AA0392BB | Brand_092  |     539.20 |
|           391 | Name_391   | Surname_391 | AA0391BB | Brand_091  |     539.10 |
|           390 | Name_390   | Surname_390 | AA0390BB | Brand_090  |     539.00 |
|           389 | Name_389   | Surname_389 | AA0389BB | Brand_089  |     538.90 |
|           388 | Name_388   | Surname_388 | AA0388BB | Brand_088  |     538.80 |
|           387 | Name_387   | Surname_387 | AA0387BB | Brand_087  |     538.70 |
|           386 | Name_386   | Surname_386 | AA0386BB | Brand_086  |     538.60 |
+---------------+------------+-------------+----------+------------+------------+
```

### Hint

Three `INNER JOIN`s (`wo → v → c`) plus one `LEFT JOIN` (`v → b`). No `GROUP BY` needed.

### Solution

```sql
SELECT wo.id AS work_order_id,
       c.first_name,
       c.last_name,
       v.plate,
       b.name AS brand_name,
       wo.total_cost
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
LEFT JOIN car_brands AS b ON b.id = v.brand_id
WHERE wo.id BETWEEN 1 AND 400
ORDER BY wo.total_cost DESC
LIMIT 15;
```

### Step-by-step explanation

1. **Three `INNER JOIN`s in a chain** walk the FK hierarchy `work_orders → vehicles → customers` — every row that survives has matches in all three tables.
2. **`LEFT JOIN car_brands`** keeps vehicles whose `brand_id` is `NULL`; `b.name` would just be `NULL` for those. Switching this to `INNER JOIN` silently drops those work orders.
3. **`ORDER BY total_cost DESC` is enough here** — the result is small and we don't paginate, so a tiebreaker is optional (`work_order_id` would be a natural choice if we did).

---

## Exercise 5 — Alternative `LIMIT offset, row_count` syntax

### Context

Legacy code reviews and Stack Overflow snippets often use the two-argument `LIMIT m, n` form — MySQL's older spelling of pagination. It's exactly equivalent to `LIMIT n OFFSET m` and shows up in every MySQL codebase eventually.

### What you'll learn

- `LIMIT offset, row_count` ≡ `LIMIT row_count OFFSET offset`.
- Why the modern `OFFSET` form reads better.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Task

For `id BETWEEN 1 AND 10000`, sorted by `total_cost ASC, id`, skip the first 10 rows and take the next 5 (`LIMIT 10, 5`).

### Expected result (real rows from the dump)

```text
+----+---------------+------------+
| id | status        | total_cost |
+----+---------------+------------+
| 11 | new           |     501.10 |
| 12 | in_progress   |     501.20 |
| 13 | waiting_parts |     501.30 |
| 14 | completed     |     501.40 |
| 15 | cancelled     |     501.50 |
+----+---------------+------------+
```

### Hint

`LIMIT 10, 5` ≡ `LIMIT 5 OFFSET 10`.

### Solution

```sql
SELECT id,
       status,
       total_cost
FROM work_orders
WHERE id BETWEEN 1 AND 10000
ORDER BY total_cost ASC, id
LIMIT 10, 5;
```

### Step-by-step explanation

1. **Mind the argument order.** In `LIMIT a, b` the first number is the **offset**, the second is the row count. The "modern" `LIMIT b OFFSET a` reads in the same direction. Confusing the two is a common bug.
2. **PostgreSQL and SQL standard** only support `LIMIT … OFFSET …` (the long form). Stick to the long form if you might port the query.
3. **Same caveats as in Exercise 2** — `OFFSET 1000000` still scans and discards a million rows; use keyset pagination for deep pages.

---

## Quick reference — what "written order" means in practice

1. Start with the answer shape: which columns do you want? → that's your **`SELECT`** list.
2. Identify the base table → **`FROM`**.
3. List the foreign keys you need to follow → **`JOIN`** clauses, top-down.
4. Filter on **row** properties → **`WHERE`**.
5. If you summarise (`COUNT`, `SUM`, `AVG`, …) → **`GROUP BY`** every non-aggregate column from `SELECT`.
6. Filter on **group** properties (`HAVING COUNT(*) >= 5`) → **`HAVING`**.
7. Decide ordering → **`ORDER BY` col [DESC] [, …]**.
8. Cap the result → **`LIMIT n`**, possibly with **`OFFSET m`** for pagination.

The execution order (`FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT`) explains every "but why doesn't this alias work in `WHERE`?" surprise.

---

## Troubleshooting: my paginated query is weird

| Symptom | Likely fix |
|---|---|
| Duplicate rows appear on the next page | Add a stable tiebreaker (`id`) to `ORDER BY`. |
| Page 2 returns 0 rows but page 1 was full | `OFFSET` exceeds total rows; check `COUNT(*)` first. |
| `HAVING` says "Unknown column" | Aggregates use `COUNT(*) >= n` form; non-aggregate predicates belong in `WHERE`. |
| `WHERE alias = …` errors | Aliases from `SELECT` aren't visible to `WHERE`. Repeat the expression. |
| `OFFSET 1000000` is slow | Switch to keyset pagination (`WHERE id > last_seen_id`). |

To run **all** examples at once: `mysql -t -u root car_service_db < 03_mysql/05_order_commands/car_service_order_examples.sql`.
