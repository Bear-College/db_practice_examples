# JOINs — `car_service_db`

Examples use **`car_service_db`** from **`database/car_service_db.sql.gz`**. The runnable script is **`07_join/car_service_join_examples.sql`**.

```bash
gunzip -c database/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 07_join/car_service_join_examples.sql
```

**Performance:** `WHERE … id BETWEEN …` and **`LIMIT`** keep large tables manageable in class.

---

## Easy vs hard

| Level | Topic |
|-------|--------|
| **Easy** | `INNER JOIN` two tables; chain **three** tables on foreign keys. |
| **Easy** | **`LEFT JOIN`**: keep all rows from the left table; right side may be `NULL`. |
| **Easy** | **`INNER JOIN` + `WHERE`** to filter after the join. |
| **Hard** | **Anti-join** with `LEFT JOIN … WHERE … IS NULL` (rows with *no* match on the right). |
| **Hard** | **Multi-`LEFT JOIN`** (one driving row, several optional related tables). |
| **Hard** | **Self-join** through a bridge (`equivalents` + two aliases on `parts`). |
| **Hard** | **`INNER JOIN` to a derived table** (`FROM (SELECT … GROUP BY …) AS t`). |
| **Hard** | **`FULL OUTER JOIN` style** in MySQL: `UNION` of left-only and right-only rows (pattern). |
| **Extra** | **`RIGHT JOIN`** — same as `LEFT JOIN` with the two tables swapped (all rows from the **right** table). |
| **Extra** | **`CROSS JOIN`** — Cartesian product; **always** restrict both sides (or use tiny subqueries). |
| **Extra** | **`FULL OUTER` pattern** — `LEFT JOIN … UNION ALL … LEFT JOIN … WHERE opposite side IS NULL` (MySQL has no `FULL OUTER JOIN` keyword). |
| **Extra** | **Many joins** — one `FROM` with several `INNER` / `LEFT` joins (e.g. order → vehicle → customer → brand → order line → job type). |

---

## Schema touchpoints

- **`vehicles.car_brands_id`** → **`car_brands.id`**
- **`work_orders.vehicle_id`** → **`vehicles.id`**
- **`vehicles.customer_id`** → **`customers.id`**
- **`feedback.customer_id`** → **`customers.id`**
- **`employees.role_id`** → **`roles.id`**
- **`equivalents.part_id_1` / `part_id_2`** → **`parts.id`**
- **`part_prices.part_id`** → **`parts.id`**
- **`fuel_types`** — small lookup (`id`, `name`) for safe **`CROSS JOIN`** demos

Match each numbered block in the `.sql` file with the exercises below.

---

## Easy exercises

1. **`INNER JOIN`** — `vehicles` + `car_brands` (brand name for each vehicle).
2. **`INNER JOIN`** — `work_orders` + `vehicles` (plate for each order).
3. **Three-way `INNER JOIN`** — `work_orders` → `vehicles` → `customers`.
4. **`LEFT JOIN`** — `customers` + `feedback` (rating may be `NULL`).
5. **`INNER JOIN`** — `parts` + `part_prices` (SKU + retail price).

6. **`INNER JOIN`** — `employees` + `roles` (mechanic/staff + job title).

## Hard exercises

6. **Anti-join** — Customers in a range who have **no** vehicle (`LEFT JOIN` + `vehicles.id IS NULL`).
7. **Multi-`LEFT JOIN`** — Customer with at most **one** feedback row and **one** vehicle per customer (via aggregated “first id” keys, then join to real rows).
8. **Bridge + self-join** — `equivalents` + `parts` twice (`p1`, `p2`) for SKU pairs.
9. **Join to derived table** — Customers joined to pre-aggregated vehicle counts.
10. **`FULL OUTER` pattern** — `UNION` of unmatched-from-left and unmatched-from-right for two small slices (e.g. `warehouses` ↔ `inventory`).

## Extra join types (same `.sql` file, blocks **R1–R3**, **MJ1**)

11. **`RIGHT JOIN`** — `car_brands` `RIGHT JOIN` `vehicles` (every vehicle in slice; brand on the left).

12. **`CROSS JOIN`** — Tiny slices of **`car_brands`** × **`fuel_types`** (12-row grid); never `CROSS JOIN` huge base tables without filters.

13. **`FULL OUTER` pattern** — `warehouses` `LEFT JOIN` `inventory` **union all** “inventory orphans” (`inventory` `LEFT JOIN` `warehouses` … `WHERE w.id IS NULL`); second part is often empty when FKs hold.

14. **Multiple joins** — **`work_orders` → `vehicles` → `customers` → `car_brands` → `order_jobs` → `job_types`** (six relations in one statement).

If a result is empty, widen `BETWEEN` bounds.
