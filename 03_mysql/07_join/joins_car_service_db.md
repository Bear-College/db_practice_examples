# JOINs — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/07_join/joins_car_service_db.md)

These exercises walk through the **family of joins** in real day-to-day work: `INNER`, `LEFT`, multi-table chains, `RIGHT`, `CROSS`, bridge/self-joins, joins to derived tables, and MySQL's "no native `FULL OUTER`" workaround. They run on the real database loaded from **`01_database_mysql/car_service_db.sql.gz`** (database name: **`car_service_db`**).

Runnable companion file: [`07_join/car_service_join_examples.sql`](car_service_join_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/07_join/car_service_join_examples.sql
```

**Performance:** every exercise uses **`WHERE id BETWEEN …`** and **`LIMIT`** to keep large tables manageable during class.

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why a real shop would run this query (1-2 sentences). |
| **What you'll learn** | Join shape trained in this exact exercise. |
| **Tables in play** | Only the columns you actually need. |
| **Task** | Concrete requirements (filter, sort, limit). |
| **Expected result** | Real rows from the dump (copied from a live run). |
| **Hint** | A single nudge toward the right join shape. |
| **Solution** | Working SQL you can paste into `mysql`. |
| **Step-by-step explanation** | What each clause does and the typical mistakes. |

---

## Map: join shapes (easy → hard)

| Level | Topic |
|-------|--------|
| **Easy** | `INNER JOIN` of two tables; chain three tables on foreign keys. |
| **Easy** | `LEFT JOIN`: keep all rows from the left table; right side may be `NULL`. |
| **Easy** | `INNER JOIN` over a lookup table (`employees` ↔ `roles`). |
| **Hard** | Semi-join with `EXISTS` (kept here as the "do they have any?" pattern). |
| **Hard** | Multi-`LEFT JOIN` with a "first id" key trick to keep one row per parent. |
| **Hard** | Bridge + self-join (`equivalents` joined to `parts` twice). |
| **Hard** | Join to a **derived** table (`FROM (SELECT … GROUP BY …) AS t`). |
| **Hard** | `FULL OUTER` **pattern** in MySQL: `LEFT JOIN … UNION ALL … LEFT JOIN … WHERE … IS NULL`. |
| **Extra** | `RIGHT JOIN` (mirror of `LEFT JOIN`). |
| **Extra** | `CROSS JOIN` on **tiny** slices for a catalog grid. |
| **Extra** | Many joins in one statement (`work_order → vehicle → customer → brand → order_jobs → job_types`). |

---

## Schema touchpoints

- **`vehicles.brand_id`** → **`car_brands.id`**
- **`work_orders.vehicle_id`** → **`vehicles.id`**
- **`vehicles.customer_id`** → **`customers.id`**
- **`feedback.customer_id`** → **`customers.id`**
- **`employees.role_id`** → **`roles.id`**
- **`equivalents.part_id_1` / `part_id_2`** → **`parts.id`**
- **`part_prices.part_id`** → **`parts.id`**
- **`inventory.warehouse_id`** → **`warehouses.id`**
- **`order_jobs.work_order_id`** → **`work_orders.id`**, **`order_jobs.job_type_id`** → **`job_types.id`**
- **`fuel_types`** — small lookup (`id`, `name`) for safe **`CROSS JOIN`** demos

---

## Exercise E1 — `INNER JOIN`: vehicle + brand name

### Context

The check-in form needs to show the human-readable brand next to every plate, but `vehicles` only stores `brand_id`. Join to `car_brands` to materialise the label.

### What you'll learn

- The simplest two-table `INNER JOIN` on a foreign key.
- Aliases (`v`, `b`) for readable queries.
- Why `INNER` drops rows when there is no matching brand.

### Tables in play

| Table | Columns |
|---|---|
| `vehicles` | `id`, `plate`, `car`, `brand_id` |
| `car_brands` | `id`, `name` |

### Task

Return `vehicle_id`, `plate`, `car`, `brand_name` for `vehicles.id BETWEEN 1 AND 200`. Limit 30.

### Expected result (real rows from the dump)

```text
+------------+----------+--------+------------+
| vehicle_id | plate    | car    | brand_name |
+------------+----------+--------+------------+
|          1 | AA0001BB | Car_1  | Brand_001  |
|          2 | AA0002BB | Car_2  | Brand_002  |
|          3 | AA0003BB | Car_3  | Brand_003  |
|          4 | AA0004BB | Car_4  | Brand_004  |
|          5 | AA0005BB | Car_5  | Brand_005  |
| ...        |          |        |            |
|         30 | AA0030BB | Car_30 | Brand_030  |
+------------+----------+--------+------------+
```

### Hint

`INNER JOIN car_brands AS b ON b.id = v.brand_id`.

### Solution

```sql
SELECT v.id AS vehicle_id,
       v.plate,
       v.car,
       b.name AS brand_name
FROM vehicles AS v
INNER JOIN car_brands AS b ON b.id = v.brand_id
WHERE v.id BETWEEN 1 AND 200
LIMIT 30;
```

### Step-by-step explanation

1. **`INNER JOIN`** keeps a row only if the `ON` predicate is satisfied on **both** sides. A vehicle with `brand_id` pointing to a missing brand would be excluded — use `LEFT JOIN` if you want to keep the left side.
2. **`ON b.id = v.brand_id`** is the foreign-key match. With `USING (brand_id)` you could shorten it when both columns are named identically.
3. **Aliases** `v` and `b` keep the query short. Without them you'd write `vehicles.id`, `vehicles.plate`, `car_brands.name`, etc.

---

## Exercise E2 — `INNER JOIN`: work order + vehicle plate

### Context

The technician's worksheet must show the **plate** for every active work order — without it the bay can't identify the car. `work_orders` stores only `vehicle_id`; join to `vehicles` for the readable plate.

### What you'll learn

- Joining a transactional table (`work_orders`) to its master (`vehicles`).
- Reading columns from both sides of the join.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `status`, `total_cost` |
| `vehicles` | `id`, `plate` |

### Task

Return `work_order_id`, `status`, `total_cost`, `plate`, `vehicle_id` for `work_orders.id BETWEEN 1 AND 500`. Limit 25.

### Expected result (real rows from the dump)

```text
+---------------+---------------+------------+----------+------------+
| work_order_id | status        | total_cost | plate    | vehicle_id |
+---------------+---------------+------------+----------+------------+
|             1 | new           |     500.10 | AA0001BB |          1 |
|             2 | in_progress   |     500.20 | AA0002BB |          2 |
|             3 | waiting_parts |     500.30 | AA0003BB |          3 |
|             4 | completed     |     500.40 | AA0004BB |          4 |
|             5 | cancelled     |     500.50 | AA0005BB |          5 |
| ...           |               |            |          |            |
|            25 | cancelled     |     502.50 | AA0025BB |         25 |
+---------------+---------------+------------+----------+------------+
```

### Hint

`ON v.id = wo.vehicle_id`.

### Solution

```sql
SELECT wo.id AS work_order_id,
       wo.status,
       wo.total_cost,
       v.plate,
       v.id AS vehicle_id
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
WHERE wo.id BETWEEN 1 AND 500
LIMIT 25;
```

### Step-by-step explanation

1. **`wo.vehicle_id`** is the foreign key; **`v.id`** is the primary key. The arrow always points from child to parent.
2. **Order of tables in `FROM` doesn't matter** for `INNER JOIN` semantics: `vehicles INNER JOIN work_orders ON v.id = wo.vehicle_id` returns the same rows.
3. **Without `WHERE wo.id BETWEEN …`** MySQL would join across all 100 000 work orders — slow on class machines.

---

## Exercise E3 — Three-table chain: work_order → vehicle → customer

### Context

The cashier prints a receipt header that needs the **order id**, the **customer's name**, and the **plate**. Three tables, two foreign keys, one query.

### What you'll learn

- Chaining two `INNER JOIN`s in one statement.
- Reading the dependency tree: `work_order` → `vehicle` → `customer`.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `total_cost` |
| `vehicles` | `id`, `customer_id`, `plate` |
| `customers` | `id`, `first_name`, `last_name` |

### Task

Return `work_order_id`, `total_cost`, `plate`, `customer_id`, `first_name`, `last_name` for `wo.id BETWEEN 1 AND 300`. Limit 25.

### Expected result (real rows from the dump)

```text
+---------------+------------+----------+-------------+------------+------------+
| work_order_id | total_cost | plate    | customer_id | first_name | last_name  |
+---------------+------------+----------+-------------+------------+------------+
|             1 |     500.10 | AA0001BB |           1 | Name_1     | Surname_1  |
|             2 |     500.20 | AA0002BB |           2 | Name_2     | Surname_2  |
|             3 |     500.30 | AA0003BB |           3 | Name_3     | Surname_3  |
|             4 |     500.40 | AA0004BB |           4 | Name_4     | Surname_4  |
|             5 |     500.50 | AA0005BB |           5 | Name_5     | Surname_5  |
| ...           |            |          |             |            |            |
|            25 |     502.50 | AA0025BB |          25 | Name_25    | Surname_25 |
+---------------+------------+----------+-------------+------------+------------+
```

### Hint

Two `INNER JOIN` clauses in a row: first to `vehicles`, then to `customers`.

### Solution

```sql
SELECT wo.id AS work_order_id,
       wo.total_cost,
       v.plate,
       c.id AS customer_id,
       c.first_name,
       c.last_name
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
WHERE wo.id BETWEEN 1 AND 300
LIMIT 25;
```

### Step-by-step explanation

1. **Each `ON` clause connects the next pair.** Forgetting one accidentally creates a Cartesian product, which can be millions of rows.
2. **`INNER JOIN` drops rows without a match** at every step. If a vehicle's `customer_id` is `NULL`, the whole `work_order` row disappears — use `LEFT JOIN` to keep it.
3. **Read the chain in business terms:** "this order is for that car, which belongs to that customer."

---

## Exercise E4 — `LEFT JOIN`: customers + feedback

### Context

The admin dashboard lists every customer in a range; if a customer has feedback rows, show them, but **never hide customers** who haven't left feedback yet.

### What you'll learn

- `LEFT JOIN` semantics: keep every row from the left table; right side becomes `NULL` if no match.
- Why `WHERE` on a column from the right table secretly turns a `LEFT JOIN` into an `INNER JOIN`.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `email` |
| `feedback` | `customer_id`, `rating`, `comment` |

### Task

Return `customer_id`, `email`, `rating`, `comment` for `customers.id BETWEEN 1 AND 80`, joining to `feedback` with `LEFT JOIN`. Limit 40.

### Expected result (real rows from the dump)

```text
+-------------+------------------------+--------+----------------------+
| customer_id | email                  | rating | comment              |
+-------------+------------------------+--------+----------------------+
|           1 | customer1@example.com  |      1 | Feedback comment #1  |
|           2 | customer2@example.com  |      2 | Feedback comment #2  |
|           3 | customer3@example.com  |      3 | Feedback comment #3  |
|           4 | customer4@example.com  |      4 | Feedback comment #4  |
|           5 | customer5@example.com  |      5 | Feedback comment #5  |
| ...         |                        |        |                      |
|          40 | customer40@example.com |      5 | Feedback comment #40 |
+-------------+------------------------+--------+----------------------+
```

### Hint

`LEFT JOIN feedback AS f ON f.customer_id = c.id` — no `WHERE` on `f.*`.

### Solution

```sql
SELECT c.id AS customer_id,
       c.email,
       f.rating,
       f.comment
FROM customers AS c
LEFT JOIN feedback AS f ON f.customer_id = c.id
WHERE c.id BETWEEN 1 AND 80
LIMIT 40;
```

### Step-by-step explanation

1. **`LEFT JOIN`** preserves every row on the left. If a customer has no feedback, the right-side columns are `NULL`.
2. **In this dump every customer has feedback**, so the output looks identical to an `INNER JOIN`. To see the difference, point the join at a less-populated child table.
3. **Watch out:** if you filter `WHERE f.rating = 5` you remove `NULL` rows along with mismatches — your `LEFT JOIN` silently becomes an `INNER JOIN`. Move the predicate into the `ON` clause to keep the outer rows.
4. **Multiple matches** would multiply the row count: every customer with three feedback rows yields three result rows.

---

## Exercise E5 — `INNER JOIN`: parts + retail price

### Context

The price list view needs each part's SKU, name, and current retail price. The price lives in `part_prices` keyed by `part_id`.

### What you'll learn

- Joining a master (`parts`) to a one-to-one or one-to-many child (`part_prices`).
- Choosing columns from both tables.

### Tables in play

| Table | Columns |
|---|---|
| `parts` | `id`, `sku`, `name` |
| `part_prices` | `part_id`, `retail_price` |

### Task

Return `part_id`, `sku`, `name`, `retail_price` for `parts.id BETWEEN 1 AND 500`. Limit 25.

### Expected result (real rows from the dump)

```text
+---------+--------------+---------+--------------+
| part_id | sku          | name    | retail_price |
+---------+--------------+---------+--------------+
|       1 | SKU-00000001 | Part_1  |        50.14 |
|       2 | SKU-00000002 | Part_2  |        50.29 |
|       3 | SKU-00000003 | Part_3  |        50.43 |
|       4 | SKU-00000004 | Part_4  |        50.57 |
|       5 | SKU-00000005 | Part_5  |        50.71 |
| ...     |              |         |              |
|      25 | SKU-00000025 | Part_25 |        53.57 |
+---------+--------------+---------+--------------+
```

### Hint

`ON pp.part_id = p.id`.

### Solution

```sql
SELECT p.id AS part_id,
       p.sku,
       p.name,
       pp.retail_price
FROM parts AS p
INNER JOIN part_prices AS pp ON pp.part_id = p.id
WHERE p.id BETWEEN 1 AND 500
LIMIT 25;
```

### Step-by-step explanation

1. **One-to-many possibility:** if `part_prices` has historical price rows per part, this query multiplies them. Add `WHERE pp.is_current = 1` or an `ORDER BY pp.valid_from DESC LIMIT 1` per part if you only need the latest.
2. **`INNER JOIN` drops parts without a price row.** Use `LEFT JOIN` if the SKU should still appear (with `NULL` price).

---

## Exercise E6 — `INNER JOIN`: employees + role title

### Context

HR wants a roster: each employee's name and the readable job title (`'Mechanic'`, `'Cashier'`, …). The title lives in `roles`, keyed by `role_id`.

### What you'll learn

- Looking up a small reference table.
- Reading the role catalog the dump uses.

### Tables in play

| Table | Columns |
|---|---|
| `employees` | `id`, `first_name`, `last_name`, `role_id` |
| `roles` | `id`, `title` |

### Task

Return `employee_id`, `first_name`, `last_name`, `role_title` for `employees.id BETWEEN 1 AND 150`. Limit 25.

### Expected result (real rows from the dump)

```text
+-------------+------------+---------------+-----------------+
| employee_id | first_name | last_name     | role_title      |
+-------------+------------+---------------+-----------------+
|           1 | EmpName_1  | EmpSurname_1  | Mechanic        |
|           2 | EmpName_2  | EmpSurname_2  | Senior Mechanic |
|           3 | EmpName_3  | EmpSurname_3  | Electrician     |
|           4 | EmpName_4  | EmpSurname_4  | Painter         |
|           5 | EmpName_5  | EmpSurname_5  | Manager         |
| ...         |            |               |                 |
|          25 | EmpName_25 | EmpSurname_25 | Manager         |
+-------------+------------+---------------+-----------------+
```

### Hint

Small lookup join: `roles AS r ON r.id = e.role_id`.

### Solution

```sql
SELECT e.id AS employee_id,
       e.first_name,
       e.last_name,
       r.title AS role_title
FROM employees AS e
INNER JOIN roles AS r ON r.id = e.role_id
WHERE e.id BETWEEN 1 AND 150
LIMIT 25;
```

### Step-by-step explanation

1. **`roles` is a tiny table.** MySQL probably reads it once and caches the lookup — joining to small reference tables is essentially free.
2. **Notice the cycle of role ids 1..10** in the seed data — `Mechanic`, `Senior Mechanic`, `Electrician`, `Painter`, `Manager`, `Cashier`, `Warehouse`, `HR`, `Administrator`, `Director`.

---

## Exercise H1 — Semi-join via `EXISTS` (customers who **do** have a vehicle)

### Context

Marketing wants the list of customers in the early-id batch (`1..5000`) who have at least one vehicle registered. We don't need any column from `vehicles` — just the existence test.

### What you'll learn

- `EXISTS` as a **semi-join** (rows from the left when there is a match on the right, but **no row duplication**).
- Why `EXISTS` is often the right call when a `JOIN + DISTINCT` is tempting.
- (The script's comment calls this "anti-join" — actually it's a positive semi-join; an anti-join would be `NOT EXISTS`.)

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `first_name`, `last_name` |
| `vehicles` | `customer_id` |

### Task

Return `id`, `first_name`, `last_name` for customers with `id BETWEEN 1 AND 5000` who **own at least one vehicle**. Limit 25.

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
| 25 | Name_25    | Surname_25 |
+----+------------+------------+
```

### Hint

`WHERE EXISTS (SELECT 1 FROM vehicles WHERE customer_id = c.id)`.

### Solution

```sql
SELECT c.id,
       c.first_name,
       c.last_name
FROM customers AS c
WHERE c.id BETWEEN 1 AND 5000
  AND EXISTS (
    SELECT 1 FROM vehicles AS v WHERE v.customer_id = c.id
  )
LIMIT 25;
```

### Step-by-step explanation

1. **`EXISTS` short-circuits** on the first matching row — much cheaper than `INNER JOIN` if a customer has many vehicles and you only care about the existence.
2. **No `DISTINCT` needed** — `EXISTS` doesn't multiply the left side. Compare to `SELECT DISTINCT c.id FROM customers c INNER JOIN vehicles v ON v.customer_id = c.id` which does the same thing more verbosely.
3. **For the true anti-join** ("customers with **no** vehicle"), swap to `NOT EXISTS` or `LEFT JOIN vehicles v ON v.customer_id = c.id WHERE v.customer_id IS NULL`.

---

## Exercise H2 — Multi-`LEFT JOIN` with "first id" keys

### Context

Customer profile page wants **one optional vehicle** and **one optional feedback** per customer. A naive `LEFT JOIN customers JOIN vehicles JOIN feedback` would multiply rows by both counts. The fix: pre-aggregate each child to the minimum id per customer, then join the real row back.

### What you'll learn

- Avoiding row explosion when joining a parent to several one-to-many children.
- Pre-aggregating in derived tables to pick a single representative row per parent.
- Chaining four `LEFT JOIN`s safely.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `last_name` |
| `feedback` | `id`, `customer_id`, `rating` |
| `vehicles` | `id`, `customer_id`, `plate` |

### Task

Return `customer_id`, `last_name`, `rating`, `plate`, `vehicle_id` for `customers.id BETWEEN 1 AND 50` with one feedback row (smallest `feedback.id`) and one vehicle row (smallest `vehicle.id`). Limit 60.

### Expected result (real rows from the dump)

```text
+-------------+------------+--------+----------+------------+
| customer_id | last_name  | rating | plate    | vehicle_id |
+-------------+------------+--------+----------+------------+
|           1 | Surname_1  |      1 | AA0001BB |          1 |
|           2 | Surname_2  |      2 | AA0002BB |          2 |
|           3 | Surname_3  |      3 | AA0003BB |          3 |
|           4 | Surname_4  |      4 | AA0004BB |          4 |
|           5 | Surname_5  |      5 | AA0005BB |          5 |
| ...         |            |        |          |            |
|          50 | Surname_50 |      5 | AA0050BB |         50 |
+-------------+------------+--------+----------+------------+
```

### Hint

Two derived tables: one for `MIN(feedback.id)`, one for `MIN(vehicle.id)`. Then `LEFT JOIN` to the real `feedback` and `vehicles` on those minimum ids.

### Solution

```sql
SELECT c.id AS customer_id,
       c.last_name,
       f.rating,
       v.plate,
       v.id AS vehicle_id
FROM customers AS c
LEFT JOIN (
            SELECT customer_id,
                   MIN(id) AS first_feedback_id
            FROM feedback
            WHERE id BETWEEN 1 AND 300000
            GROUP BY customer_id
          ) AS fk ON fk.customer_id = c.id
LEFT JOIN feedback AS f ON f.id = fk.first_feedback_id
LEFT JOIN (
            SELECT customer_id,
                   MIN(id) AS first_vehicle_id
            FROM vehicles
            WHERE id BETWEEN 1 AND 20000
            GROUP BY customer_id
          ) AS vk ON vk.customer_id = c.id
LEFT JOIN vehicles AS v ON v.id = vk.first_vehicle_id
WHERE c.id BETWEEN 1 AND 50
LIMIT 60;
```

### Step-by-step explanation

1. **The trick** — `MIN(id)` per parent is one number per parent. Joining the real child table on that number returns at most one row.
2. **Two `LEFT JOIN`s per child** — first to the aggregated "key" subquery, then to the actual row. The first one is the safety net (every customer gets a row even with no children); the second materialises the columns.
3. **Why not `ORDER BY … LIMIT 1` per row?** That would require a correlated subquery per parent — usually slower than the aggregated join.
4. **Notice the result is a single row per customer** even when feedback or vehicles is a one-to-many relation.

---

## Exercise H3 — Bridge table + self-join on `parts`

### Context

`equivalents` is a bridge table that pairs interchangeable part SKUs (e.g. brand-A's brake pad equals brand-B's). To produce a "SKU A ↔ SKU B" report, we join `parts` to itself **twice**, once for each side of the pair.

### What you'll learn

- Joining the same table twice with two aliases.
- Reading a many-to-many bridge.
- Choosing readable aliases (`p1`, `p2`) to avoid column-name clashes.

### Tables in play

| Table | Columns |
|---|---|
| `equivalents` | `id`, `part_id_1`, `part_id_2` |
| `parts` | `id`, `sku`, `brand` |

### Task

Return `sku_a`, `sku_b`, `brand_a`, `brand_b` for `equivalents.id BETWEEN 1 AND 500`. Limit 25.

### Expected result (real rows from the dump)

```text
+--------------+--------------+--------------+--------------+
| sku_a        | sku_b        | brand_a      | brand_b      |
+--------------+--------------+--------------+--------------+
| SKU-00000001 | SKU-00000002 | PartBrand_1  | PartBrand_2  |
| SKU-00000002 | SKU-00000003 | PartBrand_2  | PartBrand_3  |
| SKU-00000003 | SKU-00000004 | PartBrand_3  | PartBrand_4  |
| SKU-00000004 | SKU-00000005 | PartBrand_4  | PartBrand_5  |
| SKU-00000005 | SKU-00000006 | PartBrand_5  | PartBrand_6  |
| ...          |              |              |              |
| SKU-00000025 | SKU-00000026 | PartBrand_25 | PartBrand_26 |
+--------------+--------------+--------------+--------------+
```

### Hint

`INNER JOIN parts AS p1 ON p1.id = e.part_id_1` and `INNER JOIN parts AS p2 ON p2.id = e.part_id_2`.

### Solution

```sql
SELECT p1.sku   AS sku_a,
       p2.sku   AS sku_b,
       p1.brand AS brand_a,
       p2.brand AS brand_b
FROM equivalents AS e
INNER JOIN parts AS p1 ON p1.id = e.part_id_1
INNER JOIN parts AS p2 ON p2.id = e.part_id_2
WHERE e.id BETWEEN 1 AND 500
LIMIT 25;
```

### Step-by-step explanation

1. **Two aliases `p1` and `p2`** point at the same physical table but contribute different columns. MySQL treats them as independent.
2. **Each pair appears once** in this dump (no `(B, A)` mirror after `(A, B)`). If the relation should be symmetric, either insert both directions on write, or `UNION` both join orders on read.
3. **Bridge tables** are how SQL models many-to-many relations: two foreign keys, no extra payload (unless you store metadata like "verified by", "since when", etc.).

---

## Exercise H4 — `INNER JOIN` to a derived table

### Context

Sales wants the **top customers by fleet size** — sort customers by how many vehicles they own. Pre-aggregate vehicle counts in a subquery, then join back to `customers` for names.

### What you'll learn

- A derived table that returns one row per group.
- Joining the derived table back to the master.
- Why this is the canonical alternative to a window function for older MySQL.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `last_name` |
| `vehicles` | `customer_id` |

### Task

Build a derived table `vc(customer_id, n_vehicles)` by grouping `vehicles` (`id BETWEEN 1 AND 15000`, `customer_id IS NOT NULL`) with `HAVING COUNT(*) >= 1`. Join `customers` (`id BETWEEN 1 AND 20000`) to it. Sort by `n_vehicles DESC, c.id`. Limit 20.

### Expected result (real rows from the dump)

```text
+----+------------+------------+
| id | last_name  | n_vehicles |
+----+------------+------------+
|  1 | Surname_1  |          1 |
|  2 | Surname_2  |          1 |
|  3 | Surname_3  |          1 |
|  4 | Surname_4  |          1 |
|  5 | Surname_5  |          1 |
| ...|            |            |
| 20 | Surname_20 |          1 |
+----+------------+------------+
```

### Hint

`FROM customers c INNER JOIN (SELECT customer_id, COUNT(*) … GROUP BY customer_id) AS vc ON vc.customer_id = c.id`.

### Solution

```sql
SELECT c.id,
       c.last_name,
       vc.n_vehicles
FROM customers AS c
INNER JOIN (
             SELECT customer_id,
                    COUNT(*) AS n_vehicles
             FROM vehicles
             WHERE id BETWEEN 1 AND 15000
               AND customer_id IS NOT NULL
             GROUP BY customer_id
             HAVING COUNT(*) >= 1
           ) AS vc ON vc.customer_id = c.id
WHERE c.id BETWEEN 1 AND 20000
ORDER BY vc.n_vehicles DESC, c.id
LIMIT 20;
```

### Step-by-step explanation

1. **Derived table is computed first**, then treated as a regular table for the rest of the query.
2. **`HAVING COUNT(*) >= 1`** is redundant here (any group has at least one row) but shows the shape — replace with `>= 2` to keep only customers with multiple vehicles.
3. **Two-key `ORDER BY`** keeps ties stable.
4. **Modern alternative:** `SELECT c.id, c.last_name, COUNT(v.id) OVER (PARTITION BY c.id) AS n_vehicles FROM customers c LEFT JOIN vehicles v ON …`. Both work; the derived table is more portable.

---

## Exercise H5 — `FULL OUTER JOIN` pattern (MySQL)

### Context

MySQL has no `FULL OUTER JOIN` keyword. To list **every warehouse with any inventory rows** **plus** **every inventory row without a matching warehouse in our slice**, we emit two queries and glue them with `UNION ALL`.

### What you'll learn

- The "left-only ∪ right-only" decomposition of a full outer join.
- Combining different result shapes with `UNION ALL` and a discriminator column.
- Why the right-only side is often empty when foreign keys are intact.

### Tables in play

| Table | Columns |
|---|---|
| `warehouses` | `id`, `name` |
| `inventory` | `id`, `warehouse_id` |

### Task

Two parts UNIONed:

1. Warehouses with `id BETWEEN 1 AND 30` and **no** inventory row in `inventory.id BETWEEN 1 AND 50000`. Label `'warehouse_without_inventory_in_slice'`.
2. Inventory rows with `id BETWEEN 1 AND 5000` whose `warehouse_id` is **not** in `warehouses.id BETWEEN 1 AND 30`. Label `'inventory_row_outside_left_slice'`.

Limit 25.

### Expected result (real rows from the dump)

```text
+---------+-----------+----------------------------------+
| side_id | label     | match_kind                       |
+---------+-----------+----------------------------------+
|      31 | inv_wh_31 | inventory_row_outside_left_slice |
|      32 | inv_wh_32 | inventory_row_outside_left_slice |
|      33 | inv_wh_33 | inventory_row_outside_left_slice |
|      34 | inv_wh_34 | inventory_row_outside_left_slice |
|      35 | inv_wh_35 | inventory_row_outside_left_slice |
| ...     |           |                                  |
|      55 | inv_wh_55 | inventory_row_outside_left_slice |
+---------+-----------+----------------------------------+
```

### Hint

Part A is a `LEFT JOIN … WHERE … IS NULL`. Part B is a separate query filtered by `NOT IN (left-slice ids)`. `UNION ALL` glues them.

### Solution

```sql
SELECT w.id   AS side_id,
       w.name AS label,
       'warehouse_without_inventory_in_slice' AS match_kind
FROM warehouses AS w
LEFT JOIN inventory AS inv
  ON inv.warehouse_id = w.id
 AND inv.id BETWEEN 1 AND 50000
WHERE w.id BETWEEN 1 AND 30
  AND inv.id IS NULL
UNION ALL
SELECT inv.id AS side_id,
       CAST(CONCAT('inv_wh_', inv.warehouse_id) AS CHAR(100)) AS label,
       'inventory_row_outside_left_slice' AS match_kind
FROM inventory AS inv
WHERE inv.id BETWEEN 1 AND 5000
  AND inv.warehouse_id NOT IN (
        SELECT w2.id FROM warehouses AS w2 WHERE w2.id BETWEEN 1 AND 30
      )
LIMIT 25;
```

### Step-by-step explanation

1. **Part A: left-only.** `LEFT JOIN inventory ON … WHERE inv.id IS NULL` is the textbook anti-join pattern — warehouses in the slice that have **no** matching inventory.
2. **Part B: right-only.** Inventory rows whose `warehouse_id` is not in the chosen left slice. With intact foreign keys these still link to some warehouse — just outside the slice.
3. **`UNION ALL` requires matching column counts and compatible types.** The `CAST(...)` aligns Part A's `varchar` `name` with Part B's synthesised label.
4. **`NOT IN` `NULL` trap:** if `warehouses.id` could be `NULL`, the `NOT IN` predicate would evaluate to `NULL` for everyone. Add `WHERE w2.id IS NOT NULL` to the inner query to be safe.
5. **Result in this dump:** Part A is empty (every warehouse `1..30` has inventory rows below 50 000); only Part B shows up.

---

## Exercise R1 — `RIGHT JOIN` (mirror of `LEFT JOIN`)

### Context

Same data as E1 but expressed from the **vehicle side** — useful when the natural reading is "for every vehicle, attach its brand if we have one."

### What you'll learn

- `RIGHT JOIN` keeps every row from the table on the **right** of the join keyword.
- `RIGHT JOIN A ON …` ≡ `LEFT JOIN A` with the two tables swapped.
- Why most teams prefer `LEFT JOIN` for consistency.

### Tables in play

| Table | Columns |
|---|---|
| `car_brands` | `id`, `name` |
| `vehicles` | `id`, `plate`, `brand_id` |

### Task

Return `brand_id`, `brand_name`, `vehicle_id`, `plate` for vehicles with `v.id BETWEEN 1 AND 40`, joining `car_brands RIGHT JOIN vehicles`. Limit 40.

### Expected result (real rows from the dump)

```text
+----------+------------+------------+----------+
| brand_id | brand_name | vehicle_id | plate    |
+----------+------------+------------+----------+
|        1 | Brand_001  |          1 | AA0001BB |
|        2 | Brand_002  |          2 | AA0002BB |
|        3 | Brand_003  |          3 | AA0003BB |
|        4 | Brand_004  |          4 | AA0004BB |
|        5 | Brand_005  |          5 | AA0005BB |
| ...      |            |            |          |
|       40 | Brand_040  |         40 | AA0040BB |
+----------+------------+------------+----------+
```

### Hint

`FROM car_brands b RIGHT JOIN vehicles v ON v.brand_id = b.id`.

### Solution

```sql
SELECT b.id    AS brand_id,
       b.name  AS brand_name,
       v.id    AS vehicle_id,
       v.plate
FROM car_brands AS b
RIGHT JOIN vehicles AS v ON v.brand_id = b.id
WHERE v.id BETWEEN 1 AND 40
LIMIT 40;
```

### Step-by-step explanation

1. **`RIGHT JOIN`** keeps every row from `vehicles` (the table after `RIGHT JOIN`). If a vehicle's `brand_id` doesn't match a brand, the brand columns come back as `NULL`.
2. **Equivalent rewrite:** swap the tables: `FROM vehicles v LEFT JOIN car_brands b ON b.id = v.brand_id`. Same result, much more conventional.
3. **`WHERE v.id BETWEEN …`** is safe because we filter on the preserved (right) side. Filtering on `b.*` would silently turn it back into an inner join — same trap as `LEFT JOIN`.

---

## Exercise R2 — `CROSS JOIN` on tiny slices

### Context

Marketing wants a small "brand × fuel type" matrix to seed catalog cards for the website (e.g. "Brand_001 Petrol", "Brand_001 Diesel", …). 3 brands times 4 fuel types is a friendly 12-row grid.

### What you'll learn

- `CROSS JOIN` is the **Cartesian product**: every left row paired with every right row.
- Why both inputs must be tiny — joining 100k × 100k blows up.
- Wrapping each side in a `SELECT … LIMIT` to stay safe.

### Tables in play

| Table | Columns |
|---|---|
| `car_brands` | `id`, `name` |
| `fuel_types` | `id`, `name` |

### Task

`CROSS JOIN` the first 3 `car_brands` with the first 4 `fuel_types`. Return `brand_id`, `brand_name`, `fuel_type_id`, `fuel_name`.

### Expected result (real rows from the dump)

```text
+----------+------------+--------------+-----------+
| brand_id | brand_name | fuel_type_id | fuel_name |
+----------+------------+--------------+-----------+
|        3 | Brand_003  |            1 | Petrol    |
|        2 | Brand_002  |            1 | Petrol    |
|        1 | Brand_001  |            1 | Petrol    |
|        3 | Brand_003  |            2 | Diesel    |
|        2 | Brand_002  |            2 | Diesel    |
|        1 | Brand_001  |            2 | Diesel    |
|        3 | Brand_003  |            3 | Hybrid    |
|        2 | Brand_002  |            3 | Hybrid    |
|        1 | Brand_001  |            3 | Hybrid    |
|        3 | Brand_003  |            4 | Electric  |
|        2 | Brand_002  |            4 | Electric  |
|        1 | Brand_001  |            4 | Electric  |
+----------+------------+--------------+-----------+
```

### Hint

`CROSS JOIN` with no `ON` clause. Restrict both sides to a handful of rows.

### Solution

```sql
SELECT b.id   AS brand_id,
       b.name AS brand_name,
       ft.id  AS fuel_type_id,
       ft.name AS fuel_name
FROM (SELECT id, name FROM car_brands WHERE id BETWEEN 1 AND 3) AS b
CROSS JOIN (SELECT id, name FROM fuel_types WHERE id BETWEEN 1 AND 4) AS ft;
```

### Step-by-step explanation

1. **`CROSS JOIN` has no `ON` clause** — every left row pairs with every right row. The output size is `left_count × right_count`.
2. **3 × 4 = 12 rows** is fine; **100 000 × 100 000 = 10 000 000 000 rows** would crash the session. Always restrict.
3. **`INNER JOIN … ON 1=1`** is a synonym for `CROSS JOIN` — pick whichever you prefer.
4. **Result order**: not deterministic — MySQL is free to choose; the rows shown happen to come back with the brand id descending. Add `ORDER BY brand_id, fuel_type_id` for a stable layout.

---

## Exercise R3 — `FULL OUTER` via `LEFT JOIN` + `UNION ALL` (with two parts)

### Context

Same FULL OUTER idea as H5 but with the second part already filtered to "inventory rows whose warehouse is missing entirely". When the foreign key is enforced, Part B is empty — a healthy sign.

### What you'll learn

- The "left + right-only" decomposition with `UNION ALL`.
- A discriminator column (`part`) to label which side a row came from.
- That a healthy schema makes the right-only side empty.

### Tables in play

| Table | Columns |
|---|---|
| `warehouses` | `id`, `name` |
| `inventory` | `id`, `warehouse_id`, `quantity` |

### Task

Part 1: every warehouse with `id BETWEEN 1 AND 12`, `LEFT JOIN` to `inventory` (`inv.id BETWEEN 1 AND 5000`). Part 2: inventory rows in the same slice with **no** matching warehouse (will be empty if FKs hold). `UNION ALL`. Limit 40.

### Expected result (real rows from the dump)

```text
+--------------+----------------+--------------+----------+-----------+
| warehouse_id | warehouse_name | inventory_id | quantity | part      |
+--------------+----------------+--------------+----------+-----------+
|            1 | Warehouse_001  |            1 |        2 | from_left |
|            1 | Warehouse_001  |          101 |      102 | from_left |
|            1 | Warehouse_001  |          201 |      202 | from_left |
|            1 | Warehouse_001  |          301 |       52 | from_left |
|            1 | Warehouse_001  |          401 |      152 | from_left |
| ...          |                |              |          |           |
|            1 | Warehouse_001  |         3901 |      152 | from_left |
+--------------+----------------+--------------+----------+-----------+
```

### Hint

Use a literal label column (`'from_left'`, `'right_only_no_warehouse_match'`) so you can tell the two halves apart.

### Solution

```sql
SELECT w.id    AS warehouse_id,
       w.name  AS warehouse_name,
       inv.id  AS inventory_id,
       inv.quantity,
       'from_left' AS part
FROM warehouses AS w
LEFT JOIN inventory AS inv
  ON inv.warehouse_id = w.id
 AND inv.id BETWEEN 1 AND 5000
WHERE w.id BETWEEN 1 AND 12
UNION ALL
SELECT w.id,
       w.name,
       inv.id,
       inv.quantity,
       'right_only_no_warehouse_match'
FROM inventory AS inv
LEFT JOIN warehouses AS w ON w.id = inv.warehouse_id
WHERE inv.id BETWEEN 1 AND 5000
  AND w.id IS NULL
LIMIT 40;
```

### Step-by-step explanation

1. **`AND inv.id BETWEEN …` in `ON`** restricts which inventory rows participate. Putting that in `WHERE` instead would turn `LEFT JOIN` into an inner join. With it in the `ON`, warehouses still appear even if no inventory matches.
2. **Part 2 returns 0 rows** in this dump because every inventory's `warehouse_id` points to a real warehouse — a sign the FK is intact.
3. **`UNION ALL`** preserves duplicates (cheaper). Use `UNION` (without `ALL`) only when you must deduplicate.
4. **Result shape:** rows from Part 1 dominate; the `part` column tells you the source.

---

## Exercise MJ1 — Many joins in one statement

### Context

The big "service ticket" view: order id, status, total, customer name, plate, brand, plus the **first line item** and **its job type**. Six relations, single `SELECT`.

### What you'll learn

- Combining `INNER` and `LEFT` joins in the same query.
- When to attach a per-row filter inside `ON` vs `WHERE`.
- How to keep a deep query readable with consistent aliases.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `status`, `total_cost` |
| `vehicles` | `id`, `customer_id`, `brand_id`, `plate` |
| `customers` | `id`, `first_name`, `last_name` |
| `car_brands` | `id`, `name` |
| `order_jobs` | `id`, `work_order_id`, `job_type_id`, `price` |
| `job_types` | `id`, `name` |

### Task

For `wo.id BETWEEN 1 AND 150`, return `work_order_id`, `status`, `total_cost`, `first_name`, `last_name`, `plate`, `brand_name`, `line_price`, `job_type_name`. `INNER JOIN` for the mandatory chain (`vehicles`, `customers`, `car_brands`), `LEFT JOIN` for optional (`order_jobs`, `job_types`). Limit 30.

### Expected result (real rows from the dump)

```text
+---------------+---------------+------------+------------+------------+----------+------------+------------+---------------+
| work_order_id | status        | total_cost | first_name | last_name  | plate    | brand_name | line_price | job_type_name |
+---------------+---------------+------------+------------+------------+----------+------------+------------+---------------+
|             1 | new           |     500.10 | Name_1     | Surname_1  | AA0001BB | Brand_001  |     300.13 | JobType_0001  |
|             2 | in_progress   |     500.20 | Name_2     | Surname_2  | AA0002BB | Brand_002  |     300.25 | JobType_0002  |
|             3 | waiting_parts |     500.30 | Name_3     | Surname_3  | AA0003BB | Brand_003  |     300.38 | JobType_0003  |
|             4 | completed     |     500.40 | Name_4     | Surname_4  | AA0004BB | Brand_004  |     300.50 | JobType_0004  |
|             5 | cancelled     |     500.50 | Name_5     | Surname_5  | AA0005BB | Brand_005  |     300.63 | JobType_0005  |
| ...           |               |            |            |            |          |            |            |               |
|            30 | cancelled     |     503.00 | Name_30    | Surname_30 | AA0030BB | Brand_030  |     303.75 | JobType_0030  |
+---------------+---------------+------------+------------+------------+----------+------------+------------+---------------+
```

### Hint

Five joins. Three are `INNER` (the mandatory chain), two are `LEFT` (line items might be missing).

### Solution

```sql
SELECT wo.id        AS work_order_id,
       wo.status,
       wo.total_cost,
       c.first_name,
       c.last_name,
       v.plate,
       b.name       AS brand_name,
       oj.price     AS line_price,
       jt.name      AS job_type_name
FROM work_orders AS wo
INNER JOIN vehicles   AS v  ON v.id  = wo.vehicle_id
INNER JOIN customers  AS c  ON c.id  = v.customer_id
INNER JOIN car_brands AS b  ON b.id  = v.brand_id
LEFT JOIN  order_jobs AS oj ON oj.work_order_id = wo.id
                           AND oj.id BETWEEN 1 AND 400000
LEFT JOIN  job_types  AS jt ON jt.id = oj.job_type_id
WHERE wo.id BETWEEN 1 AND 150
LIMIT 30;
```

### Step-by-step explanation

1. **`INNER JOIN` for the mandatory spine** (work order → vehicle → customer → brand). Drop any of these and the row makes no business sense.
2. **`LEFT JOIN order_jobs`** — a work order without line items should still appear. The extra `AND oj.id BETWEEN …` lives in `ON`, not `WHERE`, so unmatched orders survive.
3. **`LEFT JOIN job_types`** — if `oj` is missing, `oj.job_type_id` is `NULL`, and the join to `job_types` adds another row of `NULL`s. That's why the order matters: a `LEFT JOIN` after another `LEFT JOIN` cascades.
4. **Row multiplication:** if a work order has 3 line items, you get 3 rows for that order. To collapse to one row per order, aggregate (`MIN(oj.price)`, `GROUP_CONCAT(jt.name)`) or use a derived table — see H2.

---

## Troubleshooting: my join is too big, too small, or wrong

| Symptom | Likely fix |
|---|---|
| Empty result with `INNER JOIN` | The `ON` foreign-key column has `NULL`s. Use `LEFT JOIN` or filter `IS NOT NULL`. |
| Row count exploded | Missing `ON` clause — accidental Cartesian product. Every `JOIN` needs an `ON`. |
| `LEFT JOIN` behaves like `INNER` | You filtered `WHERE rhs.col = …`. Move the predicate into the `ON`. |
| `RIGHT JOIN` is confusing | Swap the tables and use `LEFT JOIN` — same result, easier to read. |
| `CROSS JOIN` is slow | One or both sides are too big. Wrap them in `(SELECT … LIMIT N)`. |
| `UNION ALL` complains about types | Cast columns to the same type on both sides (`CAST(x AS CHAR(100))`). |

If you want to run **all** examples at once: `mysql -t -u root car_service_db < 03_mysql/07_join/car_service_join_examples.sql`.
