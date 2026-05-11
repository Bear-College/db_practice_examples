# Relational algebra (Algebra Koda) — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/01_relational_algebra_Koda/algebra_Koda_car_service_db.md)

These exercises pair **textbook relational-algebra notation** (Algebra Koda) with the **MySQL** that implements it. Every exercise uses the real database loaded from **`01_database_mysql/car_service_db.sql.gz`** (database name: **`car_service_db`**) and every "Solution" comes verbatim from the runnable companion file [`01_relational_algebra_Koda/car_service_algebra_examples.sql`](car_service_algebra_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/01_relational_algebra_Koda/car_service_algebra_examples.sql
```

**Performance note:** every main table holds ~100 000 rows. To keep "Expected result" short the captures below are truncated with `LIMIT` or `WHERE id BETWEEN …`; the companion `.sql` file shows the algebraic form first and is intentionally unbounded so you can see the unfiltered shape.

---

## Notation cheat sheet

| Symbol | Meaning |
|--------|--------|
| σ<sub>c</sub>(R) | **Selection** — rows of R where condition c holds. SQL: `WHERE c`. |
| π<sub>A</sub>(R) | **Projection** — keep only attributes in list A. SQL: `SELECT A`. |
| R ⋈<sub>c</sub> S | **Theta-join** — rows from R × S where c holds. SQL: `INNER JOIN ... ON c`. |
| R × S | **Cartesian product**. SQL: `CROSS JOIN` or unqualified comma. |
| R ∪ S, R − S, R ∩ S | **Union, difference, intersection** — operands must be union-compatible (same arity, compatible types). |
| ρ<sub>R(a₁→b₁,…)</sub>(S) | **Rename** the relation and/or its attributes. SQL: `AS`. |
| γ<sub>g; f→c</sub>(R) | **Grouping / aggregation** (extended RA). SQL: `GROUP BY g` with aggregate `f` aliased to `c`. |
| R ⋉ S | **Semi-join** — rows of R that have a match in S. SQL: `EXISTS` or `IN`. |

---

## Schema touchpoints (from the dump)

- **`customers`** — `id`, `first_name`, `last_name`, `phone`, `email`
- **`vehicles`** — `id`, `customer_id`, `vin`, `plate`, `brand_id`, …
- **`car_brands`** — `id`, `name`
- **`work_orders`** — `id`, `vehicle_id`, `assigned_mechanic_id`, `status`, `total_cost`
- **`employees`** — `id`, `first_name`, `last_name`, `role_id`
- **`roles`** — `id`, `title`
- **`appointments`** — `id`, `vehicle_id`, `scheduled_at`, `status`
- **`order_jobs`** — `id`, `work_order_id`, `job_type_id`, `price`
- **`job_types`** — `id`, `name`, `standard_hours`
- **`parts`** — `id`, `sku`, `name`, `brand`
- **`inventory`** — `id`, `part_id`, `warehouse_id`, `quantity`
- **`warehouses`** — `id`, `name`, `location`
- **`blacklist`** — `id`, `customer_id`, `reason`
- **`loyalty_cards`** — `id`, `customer_id`, `points`
- **`feedback`** — `id`, `customer_id`, `rating`, `comment`
- **`marketing_consents`** — `id`, `customer_id`, `email_ok`
- **`equivalents`** — `id`, `part_id_1`, `part_id_2`

Sample **`work_orders.status`** values: `new`, `in_progress`, `waiting_parts`, `completed`, `cancelled`.
Sample **`appointments.status`** values: `planned`, `confirmed`, `done`, `missed`.

---

## Exercise 1 — Selection (σ)

### Context

The accounting clerk wants only **closed** work orders today — completed jobs are the rows that produce invoices.

### What you'll learn

- Reading a **selection** σ<sub>c</sub>(R) and translating it to `WHERE`.
- That selection keeps **all** columns of `R` and only filters rows.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `assigned_mechanic_id`, `status`, `total_cost` |

### Task

Return every work order whose `status = 'completed'`.

**Algebra:** σ<sub>status = 'completed'</sub>(Work_orders)

### Expected result (real rows from the dump — first 8 of 20 000)

```text
+----+------------+----------------------+-----------+------------+
| id | vehicle_id | assigned_mechanic_id | status    | total_cost |
+----+------------+----------------------+-----------+------------+
|  4 |          4 |                    4 | completed |     500.40 |
|  9 |          9 |                    9 | completed |     500.90 |
| 14 |         14 |                   14 | completed |     501.40 |
| 19 |         19 |                   19 | completed |     501.90 |
| 24 |         24 |                   24 | completed |     502.40 |
| 29 |         29 |                   29 | completed |     502.90 |
| 34 |         34 |                   34 | completed |     503.40 |
| 39 |         39 |                   39 | completed |     503.90 |
| ...|            |                      |           |            |
+----+------------+----------------------+-----------+------------+
```

### Hint

Selection σ<sub>c</sub> = `WHERE` clause. No projection, so `SELECT` lists the full attribute set.

### Solution

```sql
SELECT id, vehicle_id, assigned_mechanic_id, status, total_cost
FROM work_orders
WHERE status = 'completed';
```

### Step-by-step explanation

1. **σ ↔ `WHERE`.** Selection only filters rows; it does not change the schema. Hence the `SELECT` list contains all attributes the algebra keeps.
2. **String equality** uses single quotes (`'completed'`). MySQL's default collation `utf8mb4_0900_ai_ci` is case-insensitive, but stick to the canonical lower-case status to stay portable.
3. **Unbounded scan.** The query has no id filter, so on the dump it returns 20 000 rows — fine for a script, but in a UI add `WHERE id BETWEEN … AND …` or `LIMIT` to avoid ferrying the whole result over the wire.

---

## Exercise 2 — Projection (π)

### Context

The catalog admin needs a "SKU → brand" mapping export — only those two columns, nothing else, so the file is light enough to drop into Excel.

### What you'll learn

- **Projection** π<sub>A</sub>(R) is exactly the `SELECT` column list.
- Pure-set RA would deduplicate after projection; SQL keeps duplicates unless you add `DISTINCT`.

### Tables in play

| Table | Columns |
|---|---|
| `parts` | `sku`, `brand` |

### Task

Return the SKU and brand of every part.

**Algebra:** π<sub>sku, brand</sub>(Parts)

### Expected result (real rows from the dump — first 10 of 100 000)

```text
+--------------+--------------+
| sku          | brand        |
+--------------+--------------+
| SKU-00000001 | PartBrand_1  |
| SKU-00000002 | PartBrand_2  |
| SKU-00000003 | PartBrand_3  |
| SKU-00000004 | PartBrand_4  |
| SKU-00000005 | PartBrand_5  |
| SKU-00000006 | PartBrand_6  |
| SKU-00000007 | PartBrand_7  |
| SKU-00000008 | PartBrand_8  |
| SKU-00000009 | PartBrand_9  |
| SKU-00000010 | PartBrand_10 |
| ...          |              |
+--------------+--------------+
```

### Hint

π<sub>A</sub> = the `SELECT` column list. Nothing else in the algebra → no `WHERE`, no `JOIN`.

### Solution

```sql
SELECT sku, brand
FROM parts;
```

### Step-by-step explanation

1. **π ↔ column list in `SELECT`.** The shape of the result has exactly the attributes mentioned in π.
2. **Bag vs set semantics.** Pure relational algebra works on **sets** (no duplicates). SQL works on **multisets**; if the textbook expects deduplication, write `SELECT DISTINCT sku, brand FROM parts`.
3. **Why `sku` is safe to project alone too.** It is `UNIQUE` in `parts`, so π<sub>sku</sub> by itself would already be duplicate-free.

---

## Exercise 3 — Selection then projection

### Context

Marketing wants to send a follow-up email **only** to customers we can also reach by phone — i.e. those whose `phone` is not `NULL`. The export should be a flat list of e-mails.

### What you'll learn

- Composition: π is applied **after** σ.
- Why you must use `IS NOT NULL`, never `<> NULL`.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `email`, `phone` |

### Task

Return the e-mail of every customer with a phone number on file.

**Algebra:** π<sub>email</sub>(σ<sub>phone IS NOT NULL</sub>(Customers))

### Expected result (real rows from the dump — first 10 of ~100 000)

```text
+------------------------+
| email                  |
+------------------------+
| customer1@example.com  |
| customer2@example.com  |
| customer3@example.com  |
| customer4@example.com  |
| customer5@example.com  |
| customer6@example.com  |
| customer7@example.com  |
| customer8@example.com  |
| customer9@example.com  |
| customer10@example.com |
| ...                    |
+------------------------+
```

### Hint

Two operations, one query: `WHERE phone IS NOT NULL` does σ, `SELECT email` does π.

### Solution

```sql
SELECT email
FROM customers
WHERE phone IS NOT NULL;
```

### Step-by-step explanation

1. **Composition reads inside-out.** σ runs first (filters rows), then π (keeps the `email` column).
2. **`IS NOT NULL`, never `<> NULL`.** `phone <> NULL` evaluates to the truth value `UNKNOWN`, which `WHERE` treats as "drop the row" — so every row would be filtered out.
3. **The result is a bag of e-mails.** Because `email` has a `UNIQUE` constraint in this dump there are no duplicates, but in general after a projection you may want `SELECT DISTINCT`.

---

## Exercise 4 — Theta-join (two relations)

### Context

The owner wants a quick view of "expensive jobs" with the plate of the car attached — so a mechanic looking at the list immediately sees which vehicle each high-ticket order belongs to.

### What you'll learn

- **Theta-join** R ⋈<sub>c</sub> S as `INNER JOIN ... ON c`.
- Why **aliases** (`ρ`) are essential to disambiguate the `id` column that appears in both tables.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `total_cost` |
| `vehicles` | `id`, `plate` |

### Task

For every work order with `total_cost > 1000`, show the work order id, the vehicle's plate, and the cost.

**Algebra:** π<sub>wo.id, v.plate, wo.total_cost</sub>( σ<sub>wo.total_cost > 1000</sub>( ρ<sub>wo</sub>(Work_orders) ⋈<sub>wo.vehicle_id = v.id</sub> ρ<sub>v</sub>(Vehicles) ) )

### Expected result (real rows from the dump — first 8)

```text
+------+----------+------------+
| id   | plate    | total_cost |
+------+----------+------------+
| 5001 | AA5001BB |    1000.10 |
| 5002 | AA5002BB |    1000.20 |
| 5003 | AA5003BB |    1000.30 |
| 5004 | AA5004BB |    1000.40 |
| 5005 | AA5005BB |    1000.50 |
| 5006 | AA5006BB |    1000.60 |
| 5007 | AA5007BB |    1000.70 |
| 5008 | AA5008BB |    1000.80 |
| ...  |          |            |
+------+----------+------------+
```

### Hint

Pick two aliases (`wo`, `v`), match on the foreign key, then filter on cost.

### Solution

```sql
SELECT wo.id, v.plate, wo.total_cost
FROM work_orders AS wo
INNER JOIN vehicles AS v ON wo.vehicle_id = v.id
WHERE wo.total_cost > 1000;
```

### Step-by-step explanation

1. **`INNER JOIN ... ON c`** is the SQL form of R ⋈<sub>c</sub> S. The `ON` clause is the join predicate from the algebra.
2. **Aliases stand in for ρ.** Both tables expose `id`; without `AS wo`/`AS v` MySQL cannot tell `id` apart in `SELECT` / `ORDER BY`.
3. **The σ predicate** (`wo.total_cost > 1000`) is in `WHERE`, not in `ON`. For `INNER JOIN` both produce the same result, but pushing non-join filters into `WHERE` keeps the join's `ON` clean and avoids subtle bugs once you switch to `LEFT JOIN`.

---

## Exercise 5 — Join chain (three relations)

### Context

The front desk wants to print, for every order, **"order #X — owner Jane Doe"**. There is no direct customer↔order link; the relationship goes through `vehicles`.

### What you'll learn

- Chaining two joins through a bridge table.
- That for inner joins, **join order doesn't change the semantics** (it can change the plan, though).

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id` |
| `vehicles` | `id`, `customer_id` |
| `customers` | `id`, `first_name`, `last_name` |

### Task

For each work order, return its id together with the owning customer's first and last name.

**Algebra:** π<sub>wo.id, c.first_name, c.last_name</sub>( Work_orders ⋈<sub>wo.vehicle_id = v.id</sub> Vehicles ⋈<sub>v.customer_id = c.id</sub> Customers )

### Expected result (real rows from the dump — first 8 of 100 000)

```text
+---------------+------------+-----------+
| work_order_id | first_name | last_name |
+---------------+------------+-----------+
|             1 | Name_1     | Surname_1 |
|             2 | Name_2     | Surname_2 |
|             3 | Name_3     | Surname_3 |
|             4 | Name_4     | Surname_4 |
|             5 | Name_5     | Surname_5 |
|             6 | Name_6     | Surname_6 |
|             7 | Name_7     | Surname_7 |
|             8 | Name_8     | Surname_8 |
| ...           |            |           |
+---------------+------------+-----------+
```

### Hint

Two `INNER JOIN`s in a row. Mind the `ON` for each step: `wo.vehicle_id = v.id`, then `v.customer_id = c.id`.

### Solution

```sql
SELECT wo.id AS work_order_id,
       c.first_name,
       c.last_name
FROM work_orders AS wo
INNER JOIN vehicles AS v ON wo.vehicle_id = v.id
INNER JOIN customers AS c ON v.customer_id = c.id;
```

### Step-by-step explanation

1. **Each `JOIN` adds one relation** with its own `ON` predicate. Forgetting the `ON` collapses the join into a Cartesian product (here that would be ~10¹⁵ rows!).
2. **`wo.id AS work_order_id`** renames the projection so the result has no ambiguous `id`. The renamed alias is then convenient in downstream views and joins.
3. **Inner-join associativity.** `(A ⋈ B) ⋈ C ≡ A ⋈ (B ⋈ C)`; MySQL's optimiser may reorder them based on indexes and row counts.

---

## Exercise 6 — Union (∪)

### Context

Compliance wants the union of two "interesting customer" segments: people on the **blacklist** and people who actively use the **loyalty program** (`points > 0`). One set ID per row.

### What you'll learn

- `UNION` in SQL implements ∪; **operands must be union-compatible** (same number of columns, compatible types).
- `UNION` is duplicate-eliminating; `UNION ALL` is the multiset version.

### Tables in play

| Table | Columns |
|---|---|
| `blacklist` | `customer_id` |
| `loyalty_cards` | `customer_id`, `points` |

### Task

Return every customer id that appears either on the blacklist **or** on a loyalty card with strictly positive points.

**Algebra:** π<sub>customer_id</sub>(Blacklist) ∪ π<sub>customer_id</sub>(σ<sub>points > 0</sub>(Loyalty_cards))

### Expected result (real rows from the dump — first 12)

```text
+-------------+
| customer_id |
+-------------+
|           1 |
|           2 |
|           3 |
|           4 |
|           5 |
|           6 |
|           7 |
|           8 |
|           9 |
|          10 |
|          11 |
|          12 |
| ...         |
+-------------+
```

### Hint

Two `SELECT customer_id` blocks joined with `UNION`. Apply the σ on the loyalty side only.

### Solution

```sql
SELECT customer_id FROM blacklist
UNION
SELECT customer_id FROM loyalty_cards WHERE points > 0;
```

### Step-by-step explanation

1. **Union-compatibility check.** Both `SELECT` lists must have the same arity (here: 1) and compatible types (both `INT`).
2. **`UNION` deduplicates.** This mirrors the **set** semantics of ∪. If you need every occurrence kept, use `UNION ALL` — it's also faster because MySQL skips the sort/hash step.
3. **σ is pushed inside.** Putting `WHERE points > 0` on the loyalty branch only is the literal translation of σ inside the second projection.

---

## Exercise 7 — Set difference (−)

### Context

Sales want to call **every customer with a registered car who is *not* on the blacklist**. Set difference is the natural operator.

### What you'll learn

- Implementing R − S in SQL with `NOT EXISTS` (preferred) — it sidesteps the `NULL` trap of `NOT IN`.
- Why `SELECT DISTINCT` is needed: a customer can own several vehicles.

### Tables in play

| Table | Columns |
|---|---|
| `vehicles` | `customer_id` |
| `blacklist` | `customer_id` |

### Task

Return distinct customer ids that appear in `vehicles` but **not** in the (sample) blacklist (`b.id <= 10`).

**Algebra:** π<sub>customer_id</sub>(Vehicles) − π<sub>customer_id</sub>(Blacklist)

### Expected result (real rows from the dump — sample over `v.id BETWEEN 1 AND 50`)

```text
+-------------+
| customer_id |
+-------------+
|          11 |
|          12 |
|          13 |
|          14 |
|          15 |
|          16 |
|          17 |
|          18 |
|          19 |
|          20 |
| ...         |
+-------------+
```

### Hint

`NOT EXISTS` returns the rows of the left side whose key is missing from the right side. Wrap `SELECT customer_id` in `DISTINCT` because vehicles can share an owner.

### Solution

```sql
SELECT DISTINCT v.customer_id
FROM vehicles AS v
WHERE v.customer_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM blacklist AS b WHERE b.customer_id = v.customer_id AND b.id <= 10
  );
```

### Step-by-step explanation

1. **`NOT EXISTS` ≡ −.** The correlated subquery says "there is no matching row on the right" — exactly the predicate of set difference.
2. **Beware `NOT IN`.** `WHERE col NOT IN (SELECT x FROM s)` returns `UNKNOWN` if any `x` is `NULL`, which means **no** rows come out. `NOT EXISTS` is `NULL`-safe.
3. **`DISTINCT` keeps set semantics.** Pure RA is set-based; SQL is bag-based, so we deduplicate manually.

---

## Exercise 8 — Intersection (∩)

### Context

A campaign needs customers who **both** left feedback **and** opted in to marketing — they are warm leads who are happy to be contacted.

### What you'll learn

- ∩ in SQL with `INNER JOIN ... USING(customer_id)` + `DISTINCT`, or `INTERSECT` on MySQL 8.0.31+.
- Why `DISTINCT` matters when one side has multiple matches per key.

### Tables in play

| Table | Columns |
|---|---|
| `feedback` | `customer_id` |
| `marketing_consents` | `customer_id` |

### Task

Return distinct customer ids that appear in **both** tables.

**Algebra:** π<sub>customer_id</sub>(Feedback) ∩ π<sub>customer_id</sub>(Marketing_consents)

### Expected result (real rows from the dump — first 10 of ~100 000)

```text
+-------------+
| customer_id |
+-------------+
|           1 |
|           2 |
|           3 |
|           4 |
|           5 |
|           6 |
|           7 |
|           8 |
|           9 |
|          10 |
| ...         |
+-------------+
```

### Hint

`INNER JOIN` on the shared column + `DISTINCT` does the job; `INTERSECT` is the cleaner one-liner on modern MySQL.

### Solution

```sql
SELECT DISTINCT f.customer_id
FROM feedback AS f
INNER JOIN marketing_consents AS m ON f.customer_id = m.customer_id;

-- Alternative (MySQL 8.0.31+ / 9.x):
-- SELECT customer_id FROM feedback
-- INTERSECT
-- SELECT customer_id FROM marketing_consents;
```

### Step-by-step explanation

1. **Inner join keeps matched rows from both sides** — exactly what ∩ asks for.
2. **`DISTINCT` is critical.** Without it, a customer with three feedback rows would appear three times even though the intersection treats them as a single value.
3. **`INTERSECT` is the textbook operator.** MySQL added it in 8.0.31; before that, the `INNER JOIN` pattern was idiomatic.

---

## Exercise 9 — Rename (ρ)

### Context

A view exposed to the BI tool needs the customer id to be called `cust_id` — that's the column the BI team has hard-coded in their dashboards.

### What you'll learn

- The SQL alias `AS` is the bread-and-butter implementation of the algebra's ρ.
- Renames apply to columns **and** entire tables.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `email` |

### Task

Project `id` and `email`, renaming `id` to `cust_id`.

**Algebra:** ρ<sub>CustLite(cust_id ← id, email ← email)</sub>( π<sub>id, email</sub>(Customers) )

### Expected result (real rows from the dump — first 10)

```text
+---------+------------------------+
| cust_id | email                  |
+---------+------------------------+
|       1 | customer1@example.com  |
|       2 | customer2@example.com  |
|       3 | customer3@example.com  |
|       4 | customer4@example.com  |
|       5 | customer5@example.com  |
|       6 | customer6@example.com  |
|       7 | customer7@example.com  |
|       8 | customer8@example.com  |
|       9 | customer9@example.com  |
|      10 | customer10@example.com |
| ...     |                        |
+---------+------------------------+
```

### Hint

`column AS alias` for column rename; `FROM table AS t` for table rename.

### Solution

```sql
SELECT id AS cust_id, email
FROM customers;
```

### Step-by-step explanation

1. **`AS` is optional in MySQL** (`id cust_id` works), but writing it out makes intent obvious to anyone reading the query later.
2. **The rename is at the result level**, not at the storage level — the underlying column is still called `id` in the table.
3. **Renames matter most with self-joins** (Exercise 15). Without them, MySQL cannot tell two references to the same physical table apart.

---

## Exercise 10 — Group + aggregate (extended RA → SQL)

### Context

The shop manager wants a per-mechanic workload count to balance assignments.

### What you'll learn

- The aggregation operator γ as MySQL `GROUP BY` + aggregate function.
- Filtering away rows whose grouping key is `NULL` (mechanic not yet assigned).

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `assigned_mechanic_id` |

### Task

For each mechanic with at least one assigned order, count how many work orders they have.

**Algebra (extended):** γ<sub>assigned_mechanic_id; COUNT(*) → wo_count</sub>(σ<sub>assigned_mechanic_id IS NOT NULL</sub>(Work_orders))

### Expected result (real rows from the dump — sample over first 500 orders)

```text
+----------------------+----------+
| assigned_mechanic_id | wo_count |
+----------------------+----------+
|                    1 |        1 |
|                    2 |        1 |
|                    3 |        1 |
|                    4 |        1 |
|                    5 |        1 |
|                    6 |        1 |
|                    7 |        1 |
|                    8 |        1 |
|                    9 |        1 |
|                   10 |        1 |
| ...                  |          |
+----------------------+----------+
```

### Hint

Pattern: `SELECT g, COUNT(*) AS c FROM t WHERE g IS NOT NULL GROUP BY g`.

### Solution

```sql
SELECT assigned_mechanic_id,
       COUNT(*) AS wo_count
FROM work_orders
WHERE assigned_mechanic_id IS NOT NULL
GROUP BY assigned_mechanic_id;
```

### Step-by-step explanation

1. **`GROUP BY` collapses rows** with the same `assigned_mechanic_id` into one bucket; the aggregate (`COUNT(*)`) summarises each bucket.
2. **`WHERE` runs *before* `GROUP BY`.** That's why the `IS NOT NULL` filter is in `WHERE`, not `HAVING`.
3. **`ONLY_FULL_GROUP_BY` (default in MySQL 8+)** requires every non-aggregate column in `SELECT` to appear in `GROUP BY`. Forgetting one is a common error.

---

## Exercise 11 — Many-to-many through a bridge

### Context

Printing the work-order detail page: every line shows the job-type name and its price for that order.

### What you'll learn

- The classical N:M pattern: `order_jobs` is the bridge between `work_orders` and `job_types`.
- Projecting columns that come from two different sides of the join.

### Tables in play

| Table | Columns |
|---|---|
| `order_jobs` | `id`, `work_order_id`, `job_type_id`, `price` |
| `job_types` | `id`, `name`, `standard_hours` |

### Task

Show job type name and price for every line of work orders 1 to 5.

**Algebra:** π<sub>jt.name, oj.price</sub>( σ<sub>oj.work_order_id BETWEEN 1 AND 5</sub>( ρ<sub>oj</sub>(Order_jobs) ⋈<sub>oj.job_type_id = jt.id</sub> ρ<sub>jt</sub>(Job_types) ) )

### Expected result (real rows from the dump)

```text
+---------------+--------+---------------+
| job_type_name | price  | work_order_id |
+---------------+--------+---------------+
| JobType_0001  | 300.13 |             1 |
| JobType_0002  | 300.25 |             2 |
| JobType_0003  | 300.38 |             3 |
| JobType_0004  | 300.50 |             4 |
| JobType_0005  | 300.63 |             5 |
+---------------+--------+---------------+
```

### Hint

`INNER JOIN job_types AS jt ON oj.job_type_id = jt.id`; filter on `oj.work_order_id`.

### Solution

```sql
SELECT jt.name AS job_type_name,
       oj.price
FROM order_jobs AS oj
INNER JOIN job_types AS jt ON oj.job_type_id = jt.id
WHERE oj.work_order_id BETWEEN 1 AND 5;
```

### Step-by-step explanation

1. **The bridge table is the source.** `order_jobs` carries both foreign keys, so it sits on the left of the `JOIN`.
2. **σ filters the order id** (`BETWEEN 1 AND 5`); this happens after the join in textbook RA but the optimiser usually pushes it to the table scan.
3. **The projection** picks one column from each side. In wider variants, you would project the `work_order_id` itself to know which order each line belongs to.

---

## Exercise 12 — Inventory + warehouse + part

### Context

The warehouse manager wants a short list of **low-stock items** (less than five on the shelf) — and for each row, which warehouse and which SKU is short.

### What you'll learn

- A three-way join with **two** different foreign keys from the same fact-style table.
- Using table aliases so the query stays readable.

### Tables in play

| Table | Columns |
|---|---|
| `inventory` | `id`, `part_id`, `warehouse_id`, `quantity` |
| `parts` | `id`, `sku` |
| `warehouses` | `id`, `name` |

### Task

Show `warehouse_name`, `sku`, `quantity` for stock rows with `quantity < 5`.

**Algebra:** π<sub>w.name, p.sku, inv.quantity</sub>( σ<sub>inv.quantity < 5</sub>( Inventory ⋈<sub>inv.part_id=p.id</sub> Parts ⋈<sub>inv.warehouse_id=w.id</sub> Warehouses ) )

### Expected result (real rows from the dump — first 8 of 1 600)

```text
+----------------+--------------+----------+
| warehouse_name | sku          | quantity |
+----------------+--------------+----------+
| Warehouse_001  | SKU-00000001 |        2 |
| Warehouse_002  | SKU-00000002 |        3 |
| Warehouse_003  | SKU-00000003 |        4 |
| Warehouse_050  | SKU-00000250 |        1 |
| Warehouse_051  | SKU-00000251 |        2 |
| Warehouse_052  | SKU-00000252 |        3 |
| Warehouse_053  | SKU-00000253 |        4 |
| Warehouse_100  | SKU-00000500 |        1 |
| ...            |              |          |
+----------------+--------------+----------+
```

### Hint

Inventory is the centre of the star; join out to `parts` and `warehouses`, then filter on `quantity`.

### Solution

```sql
SELECT w.name AS warehouse_name,
       p.sku,
       inv.quantity
FROM inventory AS inv
INNER JOIN warehouses AS w ON inv.warehouse_id = w.id
INNER JOIN parts AS p ON inv.part_id = p.id
WHERE inv.quantity < 5;
```

### Step-by-step explanation

1. **Two foreign keys, two joins.** `inventory` references both `parts` and `warehouses`, so we need a `JOIN` per dimension.
2. **`WHERE quantity < 5`** can equivalently be moved into the `ON` clause for `inner join`; we keep it in `WHERE` for clarity (it's a row-level filter, not a join predicate).
3. **`quantity` belongs to `inv`** — there is no ambiguity because no other joined table has a `quantity` column, but writing the alias anyway documents intent.

---

## Exercise 13 — Semi-join (⋉)

### Context

The marketing team wants the **list of customers** who have at least one **confirmed** appointment — just the customers, no duplicates and no appointment fields.

### What you'll learn

- The semi-join ⋉ keeps **only the left side**, projected and deduplicated.
- Two equivalent SQL forms: `INNER JOIN ... DISTINCT` and `EXISTS`.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `first_name`, `last_name` |
| `vehicles` | `id`, `customer_id` |
| `appointments` | `vehicle_id`, `status` |

### Task

Return distinct customers (id, first name, last name) who have at least one appointment with `status = 'confirmed'`.

**Algebra:** π<sub>c.id, c.first_name, c.last_name</sub>( Customers ⋉ ( Vehicles ⋈ σ<sub>status = 'confirmed'</sub>(Appointments) ) )

### Expected result (real rows from the dump — first 10)

```text
+----+------------+------------+
| id | first_name | last_name  |
+----+------------+------------+
|  2 | Name_2     | Surname_2  |
|  6 | Name_6     | Surname_6  |
| 10 | Name_10    | Surname_10 |
| 14 | Name_14    | Surname_14 |
| 18 | Name_18    | Surname_18 |
| 22 | Name_22    | Surname_22 |
| 26 | Name_26    | Surname_26 |
| 30 | Name_30    | Surname_30 |
| 34 | Name_34    | Surname_34 |
| 38 | Name_38    | Surname_38 |
| ...|            |            |
+----+------------+------------+
```

### Hint

Two equivalent flavours: `INNER JOIN + DISTINCT` or `EXISTS`. Both are in the companion `.sql`.

### Solution

```sql
-- Join + DISTINCT
SELECT DISTINCT c.id,
                c.first_name,
                c.last_name
FROM customers AS c
INNER JOIN vehicles AS v ON v.customer_id = c.id
INNER JOIN appointments AS a ON a.vehicle_id = v.id
WHERE a.status = 'confirmed';

-- EXISTS (cleaner for "semi-join" intent)
SELECT c.id, c.first_name, c.last_name
FROM customers AS c
WHERE EXISTS (
  SELECT 1
  FROM vehicles AS v
  INNER JOIN appointments AS a ON a.vehicle_id = v.id
  WHERE v.customer_id = c.id
    AND a.status = 'confirmed'
);
```

### Step-by-step explanation

1. **Semi-join keeps only the left table's columns.** That's why neither vehicle nor appointment data appears in `SELECT`.
2. **`INNER JOIN + DISTINCT` works** but it materialises every match before deduplicating; `EXISTS` short-circuits as soon as it finds one matching row.
3. **The σ on appointments** (`a.status = 'confirmed'`) is pushed inside the right-hand side of the semi-join — the algebra notation `Vehicles ⋈ σ(Appointments)` mirrors that exactly.

---

## Exercise 14 — Cartesian product (with a restriction)

### Context

A teaching example showing that θ-join ≡ σ(R × S). On real data you would never `CROSS JOIN` two large tables; here it's a deliberate, restricted version.

### What you'll learn

- `CROSS JOIN` is the SQL form of ×.
- A `WHERE` predicate on top of `CROSS JOIN` recreates a theta-join — useful for understanding **why** joins were added to the language.

### Tables in play

| Table | Columns |
|---|---|
| `employees` | `id`, `role_id` |
| `roles` | `id` |

### Task

Return pairs `(employees.id, roles.id)` from the Cartesian product **restricted** to those where `e.role_id = r.id`.

**Algebra:** σ<sub>e.role_id = r.id</sub>( Employees × ρ<sub>r</sub>(Roles) )

### Expected result (real rows from the dump — first 10 of 100 000)

```text
+-------------+---------+
| employee_id | role_id |
+-------------+---------+
|           1 |       1 |
|           2 |       2 |
|           3 |       3 |
|           4 |       4 |
|           5 |       5 |
|           6 |       6 |
|           7 |       7 |
|           8 |       8 |
|           9 |       9 |
|          10 |      10 |
| ...         |         |
+-------------+---------+
```

### Hint

`CROSS JOIN` between the two tables, then a `WHERE` predicate that picks only the matching rows.

### Solution

```sql
SELECT e.id AS employee_id,
       r.id AS role_id
FROM employees AS e
CROSS JOIN roles AS r
WHERE e.role_id = r.id;
```

### Step-by-step explanation

1. **× ↔ `CROSS JOIN`.** Without a filter, this would produce |Employees| × |Roles| = 100 000 × 10 = 1 000 000 rows.
2. **σ on top is exactly a theta-join.** The optimiser actually rewrites this query into the equivalent `INNER JOIN` form, so don't worry about a performance penalty here.
3. **Why we still keep `INNER JOIN` in practice.** It documents the intent ("connect these two relations") and is harder to misread than a stray `WHERE` clause that might silently become a real cross product if you delete a predicate.

---

## Exercise 15 — Self-join via `equivalents`

### Context

The catalog has an `equivalents` table that pairs SKUs that can substitute for each other (think OEM ↔ aftermarket part). To print the substitution, you need both SKUs — but they both live in the same `parts` table.

### What you'll learn

- A **self-join** with two different aliases on the same physical table.
- Why ρ is conceptually necessary in pure RA: without a rename you can't talk about the "left" or "right" part separately.

### Tables in play

| Table | Columns |
|---|---|
| `equivalents` | `id`, `part_id_1`, `part_id_2` |
| `parts` | `id`, `sku` |

### Task

For every pair in `equivalents`, return the two SKUs.

**Algebra:** π<sub>p1.sku, p2.sku</sub>( Equivalents ⋈<sub>part_id_1 = p1.id</sub> ρ<sub>p1</sub>(Parts) ⋈<sub>part_id_2 = p2.id</sub> ρ<sub>p2</sub>(Parts) )

### Expected result (real rows from the dump — first 8)

```text
+--------------+--------------+
| sku_1        | sku_2        |
+--------------+--------------+
| SKU-00000001 | SKU-00000002 |
| SKU-00000002 | SKU-00000003 |
| SKU-00000003 | SKU-00000004 |
| SKU-00000004 | SKU-00000005 |
| SKU-00000005 | SKU-00000006 |
| SKU-00000006 | SKU-00000007 |
| SKU-00000007 | SKU-00000008 |
| SKU-00000008 | SKU-00000009 |
| ...          |              |
+--------------+--------------+
```

### Hint

Join `parts` twice with two different aliases (`p1`, `p2`); each alias matches one side of the pair.

### Solution

```sql
SELECT p1.sku AS sku_1,
       p2.sku AS sku_2
FROM equivalents AS e
INNER JOIN parts AS p1 ON e.part_id_1 = p1.id
INNER JOIN parts AS p2 ON e.part_id_2 = p2.id;
```

### Step-by-step explanation

1. **Two aliases, same table.** MySQL treats `p1` and `p2` as two independent row sources; without the aliases the query would be ambiguous and rejected.
2. **Each `JOIN` resolves one side** of the pair (`part_id_1`, then `part_id_2`). The bridge table `equivalents` lives on the left.
3. **Symmetry is not enforced** — if `(A,B)` is stored but `(B,A)` is not, the query will only show one direction. To get both, add `UNION` with the swapped projection.

---

## Troubleshooting: my algebra translation returned 0 rows

| Symptom | Likely fix |
|---|---|
| Empty result on σ<sub>total_cost > 1000</sub> | The first thousand rows in the dump are below 1 000; raise the upper bound of any id filter or pick a higher threshold. |
| `LEFT JOIN` returns the same as `INNER` | The right-hand FK has no `NULL`s in the sample — try `WHERE rhs.id IS NULL` to see the difference. |
| `NOT IN` with a sub-query returns nothing | Right side contains `NULL`; rewrite with `NOT EXISTS`. |
| `INTERSECT` raises a syntax error | Pre-8.0.31 MySQL: use the `INNER JOIN ... DISTINCT` pattern instead. |
| Three-way join blows up | Missing `ON`. The optimiser may not warn — it will simply Cartesian-product the relations. |

To run **all** examples at once: `mysql -t -u root car_service_db < 03_mysql/01_relational_algebra_Koda/car_service_algebra_examples.sql`.
