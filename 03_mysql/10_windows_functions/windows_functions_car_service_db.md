# Window functions — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/10_windows_functions/windows_functions_car_service_db.md)

These exercises walk through **window (analytic) functions** on the real database loaded from **`01_database_mysql/car_service_db.sql.gz`** (database name: **`car_service_db`**). A window function computes a value for **each input row** while looking at a "window" of peer rows — unlike `GROUP BY`, the rows are **not collapsed**.

Runnable companion file: [`10_windows_functions/car_service_windows_functions_examples.sql`](car_service_windows_functions_examples.sql).

**Requirement:** MySQL **8.0+** (window functions are not available in MySQL 5.7).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/10_windows_functions/car_service_windows_functions_examples.sql
```

**Performance:** the dump is large (~100k rows per main table). The script uses **`WHERE id BETWEEN …`** to keep each query fast during class.

---

## Anatomy of a window function

```text
function(...) OVER ( [PARTITION BY ...] [ORDER BY ...] [frame] )
              ^^^^^   ^^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^   ^^^^^
              the    "buckets" that      ordering used  which peer rows
              keyword keep rows visible   by ranking /  feed the function
                                          offset funcs  (ROWS / RANGE)
```

| Clause | Role |
|---|---|
| **`OVER ( )`** | Turns an aggregate or ranking function into a window function (row stays visible). |
| **`PARTITION BY`** | Separate windows per group (like `GROUP BY` but without collapsing rows). |
| **`ORDER BY` inside `OVER`** | Order rows **inside** each partition (required for ranking, `LAG`/`LEAD`, running totals). |
| **`ROWS` / `RANGE` frame** | Which peer rows feed the function (used by `LAST_VALUE`, moving aggregates, etc.). |
| **`WINDOW name AS (…)`** | Reuse the same window definition across several functions. |

### `LAST_VALUE` note

With the **default frame** (`RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`), **`LAST_VALUE()`** returns the **current** row's value — not the last row of the partition. To get "last in the partition", use an explicit `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` frame, as in Exercise W7.

---

## Schema touchpoints (from the dump)

- **`work_orders`** — `id`, `vehicle_id`, `assigned_mechanic_id`, `status`, `total_cost`
- Sample **`work_orders.status`** domain: `new`, `in_progress`, `waiting_parts`, `completed`, `cancelled`.

---

## Exercise W1 — `ROW_NUMBER()` (unique sequence per partition)

### Context

The dispatcher wants to print the "top-5 most expensive open jobs" for each pipeline status (one section per status). To pick exactly the top 5 within each bucket, every row needs a **dense, unique sequence number within its status** — that's what `ROW_NUMBER()` gives us.

### What you'll learn

- How `ROW_NUMBER() OVER (PARTITION BY … ORDER BY …)` numbers rows **within** each partition.
- Why a window function lets you keep individual rows visible (versus `GROUP BY`, which collapses them).
- That `ORDER BY` **inside** `OVER` is independent of the outer `ORDER BY` on the result set.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 5000`, compute a per-status sequence `rn_in_status`. Sort each status partition by `total_cost DESC`, then by `id` to break ties. Limit output to 40 rows.

### Expected result

```text
+------+-----------+------------+--------------+
| id   | status    | total_cost | rn_in_status |
+------+-----------+------------+--------------+
| 5000 | cancelled |    1000.00 |            1 |
| 4995 | cancelled |     999.50 |            2 |
| 4990 | cancelled |     999.00 |            3 |
| 4985 | cancelled |     998.50 |            4 |
| 4980 | cancelled |     998.00 |            5 |
| 4975 | cancelled |     997.50 |            6 |
| 4970 | cancelled |     997.00 |            7 |
| 4965 | cancelled |     996.50 |            8 |
| 4960 | cancelled |     996.00 |            9 |
| 4955 | cancelled |     995.50 |           10 |
| 4950 | cancelled |     995.00 |           11 |
| 4945 | cancelled |     994.50 |           12 |
+------+-----------+------------+--------------+
```

### Hint

Use `ROW_NUMBER() OVER (PARTITION BY status ORDER BY total_cost DESC, id)` and project that as `rn_in_status`.

### Solution

```sql
SELECT id,
       status,
       total_cost,
       ROW_NUMBER() OVER (
         PARTITION BY status
         ORDER BY total_cost DESC, id
       ) AS rn_in_status
FROM work_orders
WHERE id BETWEEN 1 AND 5000
LIMIT 40;
```

### Step-by-step explanation

1. **`PARTITION BY status`** opens a fresh window for every distinct `status`. Each window restarts the row counter at `1`.
2. **`ORDER BY total_cost DESC, id`** inside `OVER` defines the **sequence order** within the window — the most expensive order in each status gets `rn_in_status = 1`. The `id` tiebreaker makes the order deterministic.
3. **`ROW_NUMBER()`** is a ranking function: it **never** ties, even on equal `total_cost`. Use `RANK` / `DENSE_RANK` (Exercise W2) when you want ties to share a rank.
4. **The outer `LIMIT 40` is independent of the window.** The window is computed for the full filtered set first; `LIMIT` then takes the first 40 rows in whatever physical order the optimizer chooses. Add a top-level `ORDER BY` if you need a specific section to appear first.

---

## Exercise W2 — `RANK()` vs `DENSE_RANK()`

### Context

Inside each mechanic's history of jobs, the lead foreman wants to call out the highest-cost work the mechanic has done. When two jobs cost the same, both should share the rank — but should `RANK = 1, 1, 3` or `1, 1, 2`? `RANK` does the former, `DENSE_RANK` the latter.

### What you'll learn

- How `RANK()` handles ties (same rank, then a gap).
- How `DENSE_RANK()` handles ties (same rank, no gap).
- That, despite identical syntax to `ROW_NUMBER()`, the semantics around ties are very different.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `assigned_mechanic_id`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 8000` and `assigned_mechanic_id IS NOT NULL`, return both `RANK()` and `DENSE_RANK()` over `total_cost DESC`, partitioned by `assigned_mechanic_id`. Limit 35 rows.

### Expected result

```text
+----+----------------------+------------+-----+-----------+
| id | assigned_mechanic_id | total_cost | rnk | dense_rnk |
+----+----------------------+------------+-----+-----------+
|  1 |                    1 |     500.10 |   1 |         1 |
|  2 |                    2 |     500.20 |   1 |         1 |
|  3 |                    3 |     500.30 |   1 |         1 |
|  4 |                    4 |     500.40 |   1 |         1 |
|  5 |                    5 |     500.50 |   1 |         1 |
|  6 |                    6 |     500.60 |   1 |         1 |
|  7 |                    7 |     500.70 |   1 |         1 |
|  8 |                    8 |     500.80 |   1 |         1 |
|  9 |                    9 |     500.90 |   1 |         1 |
| 10 |                   10 |     501.00 |   1 |         1 |
| 11 |                   11 |     501.10 |   1 |         1 |
| 12 |                   12 |     501.20 |   1 |         1 |
+----+----------------------+------------+-----+-----------+
```

### Hint

Two window functions with the **same** `OVER (PARTITION BY assigned_mechanic_id ORDER BY total_cost DESC)`; alias them `rnk` and `dense_rnk`.

### Solution

```sql
SELECT id,
       assigned_mechanic_id,
       total_cost,
       RANK() OVER (
         PARTITION BY assigned_mechanic_id
         ORDER BY total_cost DESC
       ) AS rnk,
       DENSE_RANK() OVER (
         PARTITION BY assigned_mechanic_id
         ORDER BY total_cost DESC
       ) AS dense_rnk
FROM work_orders
WHERE id BETWEEN 1 AND 8000
  AND assigned_mechanic_id IS NOT NULL
LIMIT 35;
```

### Step-by-step explanation

1. **`RANK()`** assigns the same rank to ties, then **skips** ranks so the next non-tie rank reflects the row position: `100, 100, 80` → `1, 1, 3`.
2. **`DENSE_RANK()`** also gives ties the same rank but **does not skip**: `100, 100, 80` → `1, 1, 2`. Use this when you want a compact rank label (e.g. "tier 1, tier 2, tier 3").
3. **Sanity check on this dump:** in `car_service_db`, each `assigned_mechanic_id` happens to appear exactly once in `work_orders`, so every partition has a single row and both functions return `1` for every row. In a real shop, where one mechanic owns dozens of orders, the two functions would diverge as soon as two orders share the same `total_cost`.
4. **Both require `ORDER BY` inside `OVER`.** Without it, the database has no notion of "first vs second" inside the partition and rejects the query.

---

## Exercise W3 — `SUM` / `AVG` as window aggregates

### Context

For each work order, the manager wants to show the cost **and** the totals for the status bucket it belongs to (e.g. "this order is 500.10 out of 1 999 500.00 total for `new`"). Adding the totals as new columns — without losing the row-by-row detail — is exactly what window aggregates do.

### What you'll learn

- Aggregates (`SUM`, `AVG`, `MIN`, `MAX`, `COUNT`) become **window functions** when followed by `OVER (...)`.
- They compute over the partition but keep every input row visible (unlike `GROUP BY`).
- Without `ORDER BY` inside `OVER`, the window is the **entire partition** (no running computation).

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 10000`, return `id`, `status`, `total_cost`, the **sum** and **average** of `total_cost` across the entire status bucket. Limit 30.

### Expected result

```text
+-------+-----------+------------+--------------------+--------------------+
| id    | status    | total_cost | sum_cost_in_status | avg_cost_in_status |
+-------+-----------+------------+--------------------+--------------------+
|  9485 | cancelled |    1448.50 |         2000500.00 |        1000.250000 |
| 10000 | cancelled |    1500.00 |         2000500.00 |        1000.250000 |
|  9995 | cancelled |    1499.50 |         2000500.00 |        1000.250000 |
|  9990 | cancelled |    1499.00 |         2000500.00 |        1000.250000 |
|  9985 | cancelled |    1498.50 |         2000500.00 |        1000.250000 |
|  8715 | cancelled |    1371.50 |         2000500.00 |        1000.250000 |
|  9980 | cancelled |    1498.00 |         2000500.00 |        1000.250000 |
|  9975 | cancelled |    1497.50 |         2000500.00 |        1000.250000 |
|  9970 | cancelled |    1497.00 |         2000500.00 |        1000.250000 |
|  9965 | cancelled |    1496.50 |         2000500.00 |        1000.250000 |
+-------+-----------+------------+--------------------+--------------------+
```

### Hint

`SUM(total_cost) OVER (PARTITION BY status)` and `AVG(total_cost) OVER (PARTITION BY status)`.

### Solution

```sql
SELECT id,
       status,
       total_cost,
       SUM(total_cost) OVER (PARTITION BY status) AS sum_cost_in_status,
       AVG(total_cost) OVER (PARTITION BY status) AS avg_cost_in_status
FROM work_orders
WHERE id BETWEEN 1 AND 10000
LIMIT 30;
```

### Step-by-step explanation

1. **Every row keeps its detail.** `id`, `status`, `total_cost` are unchanged; the window columns are *appended*.
2. **`PARTITION BY status` without `ORDER BY`** means the window is the **whole bucket**, so `sum_cost_in_status` and `avg_cost_in_status` are constant within the partition.
3. **Compare with `GROUP BY status`:** that version would collapse all rows of a status into a single row and lose `id` / `total_cost`. Window aggregates and `GROUP BY` aggregates answer different questions.
4. **Performance:** the database materialises the partition once, then projects the aggregate onto each row. It is roughly the same cost as a self-join — but much easier to read.

---

## Exercise W4 — Running total (`SUM` with `ORDER BY` and `ROWS` frame)

### Context

Finance wants a **running total** of `total_cost` per status, in `id` order: order N's running sum is the sum of orders 1..N within the same status. This is the classic "cumulative" calculation.

### What you'll learn

- Adding `ORDER BY` inside `OVER` changes the **default frame** to "rows so far".
- The explicit frame `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` makes the intent crystal clear.
- Running totals are written declaratively with windows — no procedural loop required.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 2000`, compute `running_sum_same_status = SUM(total_cost)` over rows in the **same status** ordered by `id`, from the first row of the partition up to and including the current row. Limit 25.

### Expected result

```text
+----+-----------+------------+-------------------------+
| id | status    | total_cost | running_sum_same_status |
+----+-----------+------------+-------------------------+
|  5 | cancelled |     500.50 |                  500.50 |
| 10 | cancelled |     501.00 |                 1001.50 |
| 15 | cancelled |     501.50 |                 1503.00 |
| 20 | cancelled |     502.00 |                 2005.00 |
| 25 | cancelled |     502.50 |                 2507.50 |
| 30 | cancelled |     503.00 |                 3010.50 |
| 35 | cancelled |     503.50 |                 3514.00 |
| 40 | cancelled |     504.00 |                 4018.00 |
| 45 | cancelled |     504.50 |                 4522.50 |
| 50 | cancelled |     505.00 |                 5027.50 |
| 55 | cancelled |     505.50 |                 5533.00 |
| 60 | cancelled |     506.00 |                 6039.00 |
+----+-----------+------------+-------------------------+
```

### Hint

`SUM(total_cost) OVER (PARTITION BY status ORDER BY id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`.

### Solution

```sql
SELECT id,
       status,
       total_cost,
       SUM(total_cost) OVER (
         PARTITION BY status
         ORDER BY id
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_sum_same_status
FROM work_orders
WHERE id BETWEEN 1 AND 2000
LIMIT 25;
```

### Step-by-step explanation

1. **`ORDER BY id` inside `OVER`** establishes the order in which rows accumulate.
2. **The frame** `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` says: "from the first row of the partition through this row". Replace `UNBOUNDED PRECEDING` with `2 PRECEDING` to get a **3-row moving sum** instead.
3. **`ROWS` vs `RANGE`:** `ROWS` counts physical rows; `RANGE` looks at logical value ranges using the `ORDER BY` key. With unique `id`s the two behave identically; with ties, `RANGE` includes all peers.
4. **Common gotcha:** adding `ORDER BY` inside `OVER` *without* an explicit frame implicitly defaults to `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` — you get a running total whether you wanted one or not. Always be explicit on frames when you care about the semantics (see Exercise W7).

---

## Exercise W5 — `LAG()` and `LEAD()` (previous and next row)

### Context

When the foreman audits a mechanic's day, it helps to see each order alongside the **previous** and **next** order's total cost — to spot anomalies (a sudden 10x jump) or just sequence patterns. `LAG` / `LEAD` look back / forward inside a window without a self-join.

### What you'll learn

- `LAG(col, n)` returns `col` from the row `n` positions **earlier** in the window.
- `LEAD(col, n)` returns `col` from the row `n` positions **later**.
- The boundary rows return `NULL` by default (or an explicit default if you pass a third argument).

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `assigned_mechanic_id`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 12000` and `assigned_mechanic_id IS NOT NULL`, return `prev_cost = LAG(total_cost, 1)` and `next_cost = LEAD(total_cost, 1)` over `id` order per mechanic. Limit 35.

### Expected result

```text
+----+----------------------+------------+-----------+-----------+
| id | assigned_mechanic_id | total_cost | prev_cost | next_cost |
+----+----------------------+------------+-----------+-----------+
|  1 |                    1 |     500.10 |      NULL |      NULL |
|  2 |                    2 |     500.20 |      NULL |      NULL |
|  3 |                    3 |     500.30 |      NULL |      NULL |
|  4 |                    4 |     500.40 |      NULL |      NULL |
|  5 |                    5 |     500.50 |      NULL |      NULL |
|  6 |                    6 |     500.60 |      NULL |      NULL |
|  7 |                    7 |     500.70 |      NULL |      NULL |
|  8 |                    8 |     500.80 |      NULL |      NULL |
|  9 |                    9 |     500.90 |      NULL |      NULL |
| 10 |                   10 |     501.00 |      NULL |      NULL |
+----+----------------------+------------+-----------+-----------+
```

### Hint

Both functions take `(column, offset)`; an optional third argument is the default when the offset falls outside the window.

### Solution

```sql
SELECT id,
       assigned_mechanic_id,
       total_cost,
       LAG(total_cost, 1) OVER (
         PARTITION BY assigned_mechanic_id
         ORDER BY id
       ) AS prev_cost,
       LEAD(total_cost, 1) OVER (
         PARTITION BY assigned_mechanic_id
         ORDER BY id
       ) AS next_cost
FROM work_orders
WHERE id BETWEEN 1 AND 12000
  AND assigned_mechanic_id IS NOT NULL
LIMIT 35;
```

### Step-by-step explanation

1. **`LAG(total_cost, 1)`** returns the previous row's `total_cost` inside the same `assigned_mechanic_id` partition. The very first row of each partition has no predecessor — hence `NULL`.
2. **`LEAD(total_cost, 1)`** is symmetric: the last row's "next" is `NULL`.
3. **About this dump:** every `assigned_mechanic_id` has only one work order, so every partition has size 1 — every row is both first and last, and `prev_cost` / `next_cost` are always `NULL`. To see lively output, partition on something with repeats (e.g. `PARTITION BY status`) or use a database where mechanics own multiple orders.
4. **Default value:** `LAG(total_cost, 1, 0)` would emit `0` instead of `NULL` for boundary rows — handy when feeding the result into arithmetic that does not tolerate `NULL`.

---

## Exercise W6 — `NTILE(n)` (bucketize within a partition)

### Context

The pricing team wants to split orders in each status into **four cost-quartile buckets** so they can study "expensive 25%" versus "cheap 25%" behaviour separately. `NTILE(4)` does this with one window function.

### What you'll learn

- `NTILE(n)` divides each partition into `n` near-equal buckets.
- Bucket numbers run from `1` to `n`; if the partition size isn't divisible by `n`, the earlier buckets get the extra rows.
- Used together with `PARTITION BY`, you get per-group quartiles in a single pass.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 8000`, partition by `status`, order each partition by `total_cost DESC, id`, and label each row with its `NTILE(4)` bucket (so bucket `1` is the most expensive quarter of each status). Limit 32.

### Expected result

```text
+------+-----------+------------+-----------------+
| id   | status    | total_cost | quartile_bucket |
+------+-----------+------------+-----------------+
| 8000 | cancelled |    1300.00 |               1 |
| 7995 | cancelled |    1299.50 |               1 |
| 7990 | cancelled |    1299.00 |               1 |
| 7985 | cancelled |    1298.50 |               1 |
| 7980 | cancelled |    1298.00 |               1 |
| 7975 | cancelled |    1297.50 |               1 |
| 7970 | cancelled |    1297.00 |               1 |
| 7965 | cancelled |    1296.50 |               1 |
| 7960 | cancelled |    1296.00 |               1 |
| 7955 | cancelled |    1295.50 |               1 |
| 7950 | cancelled |    1295.00 |               1 |
| 7945 | cancelled |    1294.50 |               1 |
+------+-----------+------------+-----------------+
```

### Hint

`NTILE(4) OVER (PARTITION BY status ORDER BY total_cost DESC, id)`.

### Solution

```sql
SELECT id,
       status,
       total_cost,
       NTILE(4) OVER (
         PARTITION BY status
         ORDER BY total_cost DESC, id
       ) AS quartile_bucket
FROM work_orders
WHERE id BETWEEN 1 AND 8000
LIMIT 32;
```

### Step-by-step explanation

1. **`NTILE(4)`** numbers rows 1..4 inside each partition. Order matters: `ORDER BY total_cost DESC` means quartile `1` is the most expensive group.
2. **Uneven splits:** a partition of size 10 split into 4 buckets gets sizes `3, 3, 2, 2` — the leftover rows go to the **lowest-numbered** buckets.
3. **Visible top slice:** the output here shows only quartile `1` because `LIMIT 32` cuts before the second-quartile rows. Drop the `LIMIT` (or sort by the bucket) to see all four.
4. **Watch out:** `NTILE` requires `ORDER BY` inside `OVER`; without it, the bucket assignment would be non-deterministic and MySQL refuses.

---

## Exercise W7 — `FIRST_VALUE` and `LAST_VALUE` (explicit frame)

### Context

For each vehicle, the service history wants to show the **first** and **last** work-order cost — useful for "how did this car evolve from its first visit to its latest?". This needs the right window **frame**, because `LAST_VALUE` with the default frame is a famous footgun.

### What you'll learn

- `FIRST_VALUE(col)` returns `col` from the first row of the window frame.
- `LAST_VALUE(col)` returns `col` from the **last** row of the window frame — which is **not** the last row of the partition by default.
- The fix: `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` makes the frame the full partition.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 6000`, for each `vehicle_id` partition return the first and last `total_cost` (in `id` order) using an **explicit `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`** frame. Limit 30.

### Expected result

```text
+----+------------+------------+---------------------------+--------------------------+
| id | vehicle_id | total_cost | first_wo_cost_for_vehicle | last_wo_cost_for_vehicle |
+----+------------+------------+---------------------------+--------------------------+
|  1 |          1 |     500.10 |                    500.10 |                   500.10 |
|  2 |          2 |     500.20 |                    500.20 |                   500.20 |
|  3 |          3 |     500.30 |                    500.30 |                   500.30 |
|  4 |          4 |     500.40 |                    500.40 |                   500.40 |
|  5 |          5 |     500.50 |                    500.50 |                   500.50 |
|  6 |          6 |     500.60 |                    500.60 |                   500.60 |
|  7 |          7 |     500.70 |                    500.70 |                   500.70 |
|  8 |          8 |     500.80 |                    500.80 |                   500.80 |
|  9 |          9 |     500.90 |                    500.90 |                   500.90 |
| 10 |         10 |     501.00 |                    501.00 |                   501.00 |
+----+------------+------------+---------------------------+--------------------------+
```

### Hint

Use the explicit `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` frame for **both** `FIRST_VALUE` and `LAST_VALUE`.

### Solution

```sql
SELECT id,
       vehicle_id,
       total_cost,
       FIRST_VALUE(total_cost) OVER (
         PARTITION BY vehicle_id
         ORDER BY id
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS first_wo_cost_for_vehicle,
       LAST_VALUE(total_cost) OVER (
         PARTITION BY vehicle_id
         ORDER BY id
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS last_wo_cost_for_vehicle
FROM work_orders
WHERE id BETWEEN 1 AND 6000
LIMIT 30;
```

### Step-by-step explanation

1. **The default frame trap.** When `ORDER BY` appears inside `OVER` and **no frame is given**, MySQL defaults to `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. `LAST_VALUE` then returns the **current** row — not the partition's last row.
2. **The fix:** widen the frame to the whole partition with `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`. Now `LAST_VALUE` truly looks at the final row.
3. **`FIRST_VALUE` is safer** (the default frame already includes the first row), but writing the same explicit frame for both keeps the code symmetric.
4. **About this dump:** every `vehicle_id` has only one work order in `id BETWEEN 1 AND 6000`, so first and last are the same row. The output illustrates the syntax — re-run on a vehicle that has multiple orders to see distinct first/last values.

---

## Exercise W8 — Named `WINDOW` clause (DRY for multiple functions)

### Context

When you need several window functions sharing the **same** partition and ordering, repeating the `OVER (...)` clause is noisy and error-prone. The `WINDOW` clause lets you name a window once and reference it everywhere — like an alias for a window definition.

### What you'll learn

- The standalone `WINDOW name AS (...)` clause (after `WHERE`/`GROUP BY`/`HAVING`, before `ORDER BY`).
- Referencing a named window with `OVER w`.
- That `PERCENT_RANK()` returns a value in `[0, 1]` indicating relative position.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 4000`, define a named window `w` = `PARTITION BY status ORDER BY total_cost DESC, id`, then compute both `ROW_NUMBER() OVER w` and `PERCENT_RANK() OVER w`. Limit 30.

### Expected result

```text
+------+-----------+------------+----+-----------------------+
| id   | status    | total_cost | rn | pr                    |
+------+-----------+------------+----+-----------------------+
| 4000 | cancelled |     900.00 |  1 |                     0 |
| 3995 | cancelled |     899.50 |  2 | 0.0012515644555694619 |
| 3990 | cancelled |     899.00 |  3 | 0.0025031289111389237 |
| 3985 | cancelled |     898.50 |  4 | 0.0037546933667083854 |
| 3980 | cancelled |     898.00 |  5 | 0.0050062578222778474 |
| 3975 | cancelled |     897.50 |  6 |  0.006257822277847309 |
| 3970 | cancelled |     897.00 |  7 |  0.007509386733416771 |
| 3965 | cancelled |     896.50 |  8 |  0.008760951188986232 |
| 3960 | cancelled |     896.00 |  9 |  0.010012515644555695 |
| 3955 | cancelled |     895.50 | 10 |  0.011264080100125156 |
| 3950 | cancelled |     895.00 | 11 |  0.012515644555694618 |
| 3945 | cancelled |     894.50 | 12 |   0.01376720901126408 |
+------+-----------+------------+----+-----------------------+
```

### Hint

Put `WINDOW w AS (PARTITION BY status ORDER BY total_cost DESC, id)` once at the query level, then write `OVER w` instead of repeating the parentheses.

### Solution

```sql
SELECT id,
       status,
       total_cost,
       ROW_NUMBER()    OVER w AS rn,
       PERCENT_RANK()  OVER w AS pr
FROM work_orders
WHERE id BETWEEN 1 AND 4000
WINDOW w AS (PARTITION BY status ORDER BY total_cost DESC, id)
LIMIT 30;
```

### Step-by-step explanation

1. **`WINDOW w AS (...)`** declares a window name `w` once. The body is exactly what would go inside `OVER (...)`.
2. **`OVER w`** references the named window. Multiple functions on the same window read consistently and stay in sync — change the window's `ORDER BY` once, and every function follows.
3. **`PERCENT_RANK()`** returns `(rank − 1) / (rows − 1)`. The first row of a partition is always `0`; the last is always `1`. The expected output shows the first row at `0` and the second row at `≈ 0.00125`, consistent with ~800 rows per status in this slice.
4. **Order of clauses matters:** `WINDOW` is placed **after** `HAVING` and **before** `ORDER BY`. Misplacing it is a parse error.

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `Window function 'ROW_NUMBER' is not allowed here` | Window functions are only allowed in `SELECT` and `ORDER BY`. Wrap the query in a subquery / CTE if you need to filter on the rank. |
| `LAST_VALUE` always equals the current row | You hit the default frame trap. Add `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` (see W7). |
| `RANK` and `DENSE_RANK` give identical output | No ties on the `ORDER BY` key — the two only diverge when ties exist. |
| `LAG` / `LEAD` return only `NULL` | Each partition has only one row, or your offset exceeds the partition size — verify with `COUNT(*)` per partition. |
| MySQL 5.7 rejects the syntax | Window functions require MySQL **8.0+**. |

If you want to run **all** examples at once: `mysql -t -u root car_service_db < 03_mysql/10_windows_functions/car_service_windows_functions_examples.sql`.
