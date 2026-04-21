# Relational algebra (Algebra Koda) — `car_service_db`

These exercises use **real table and column names** from the MySQL dump `01_database_mysql/car_service_db.sql.gz` (database name: `car_service_db`). Pair each algebra expression with the matching query in `car_service_algebra_examples.sql`.

## Notation

| Symbol | Meaning |
|--------|--------|
| σ<sub>c</sub>(R) | Selection: rows of R where condition c holds |
| π<sub>A</sub>(R) | Projection: keep only attributes (columns) in list A |
| R ⋈<sub>c</sub> S | Theta-join: combine rows with condition c (natural join is the special case where c is equality on all common names) |
| R × S | Cartesian product |
| R ∪ S, R − S, R ∩ S | Union, difference, intersection (operands must be **union-compatible**: same arity and compatible types) |
| ρ<sub>R(a₁→b₁,…)</sub>(S) | Rename (relation and/or attributes) |

**Extended (SQL mapping):** grouping and aggregates (COUNT, SUM, …) are written in SQL as `GROUP BY`; pure “book” relational algebra often extends the model with **generalized projection** or **aggregation**; here we label those as **extended RA → SQL**.

## Schema subset (from the dump)

- **customers** (`id`, `first_name`, `last_name`, `phone`, `email`)
- **vehicles** (`id`, `customer_id`, `vin`, `plate`, `car`, `car_brands_id`) — FK `car_brands_id` → **car_brands**(`id`)
- **car_brands** (`id`, `name`)
- **work_orders** (`id`, `vehicle_id`, `mechanic_id`, `status`, `total_cost`)
- **employees** (`id`, `first_name`, `last_name`, `role_id`)
- **appointments** (`id`, `vehicle_id`, `scheduled_at`, `status`)
- **order_jobs** (`id`, `work_order_id`, `job_type_id`, `price`)
- **job_types** (`id`, `name`, `standard_hours`)
- **parts** (`id`, `sku`, `name`, `brand`)
- **inventory** (`id`, `part_id`, `warehouse_id`, `quantity`)
- **warehouses** (`id`, `name`, `location`)
- **blacklist** (`id`, `customer_id`, `reason`)
- **loyalty_cards** (`id`, `customer_id`, `points`)
- **feedback** (`id`, `customer_id`, `rating`, `comment`)
- **marketing_consents** (`id`, `customer_id`, `email_ok`)

Sample **work_orders.status** values in the data include: `new`, `in_progress`, `waiting_parts`, `completed`, `cancelled`.
Sample **appointments.status** values include: `planned`, `confirmed`, `done`, `missed`.

---

## Exercise 1 — Selection

**Task:** All work orders that are completed.

**Algebra:**
σ<sub>status = 'completed'</sub>(Work_orders)

**SQL idea:** filter `work_orders` on `status`.

---

## Exercise 2 — Projection

**Task:** List each part’s SKU and brand (no other columns).

**Algebra:**
π<sub>sku, brand</sub>(Parts)

---

## Exercise 3 — Selection then projection

**Task:** Email addresses for customers who have a phone number on file (`phone` not null).

**Algebra:**
π<sub>email</sub>(σ<sub>phone IS NOT NULL</sub>(Customers))

---

## Exercise 4 — Theta-join (two relations)

**Task:** For each work order, show the vehicle’s license plate and the work order total, but only if `total_cost > 1000`.

**Algebra (theta-join on vehicle key):**
π<sub>wo.id, v.plate, wo.total_cost</sub>
 σ<sub>wo.total_cost > 1000</sub>( ρ<sub>wo</sub>(Work_orders) ⋈<sub>wo.vehicle_id = v.id</sub> ρ<sub>v</sub>(Vehicles) )

(ρ renames to disambiguate `id`; in SQL you use aliases `wo` and `v`.)

---

## Exercise 5 — Join chain (three relations)

**Task:** For each work order id, show the customer’s first and last name (vehicle links customer to work order).

**Algebra:**
π<sub>wo.id, c.first_name, c.last_name</sub>(
 Work_orders ⋈<sub>wo.vehicle_id = v.id</sub> Vehicles ⋈<sub>v.customer_id = c.id</sub> Customers
)
(with aliases `wo`, `v`, `c` in SQL).

---

## Exercise 6 — Union (union-compatible projections)

**Task:** All distinct `customer_id` values that appear either on the blacklist **or** on a loyalty card with strictly positive points.

**Algebra:**
π<sub>customer_id</sub>(Blacklist) ∪ π<sub>customer_id</sub>(σ<sub>points > 0</sub>(Loyalty_cards))

---

## Exercise 7 — Set difference

**Task:** Customers who own at least one vehicle (appear as `vehicles.customer_id`) but are **not** on the blacklist.

**Algebra:**
π<sub>customer_id</sub>(Vehicles) − π<sub>customer_id</sub>(Blacklist)

Use **duplicate-eliminating** projection (SQL `SELECT DISTINCT`).

---

## Exercise 8 — Intersection

**Task:** Customers who appear in **both** `feedback` and `marketing_consents` (same `customer_id` in both tables).

**Algebra:**
π<sub>customer_id</sub>(Feedback) ∩ π<sub>customer_id</sub>(Marketing_consents)

---

## Exercise 9 — Rename (for readability)

**Task:** Same relation `Customers`, but you only want attributes `id` and `email`, with `id` renamed to `cust_id` in the result.

**Algebra:**
ρ<sub>CustLite(cust_id → id, email → email)</sub>( π<sub>id, email</sub>(Customers) )
(Exact rename notation varies by textbook; in SQL: `id AS cust_id`.)

---

## Exercise 10 — Join + aggregate (extended RA → SQL)

**Task:** For each mechanic (`work_orders.mechanic_id`), how many work orders do they have?

**Extended:**
γ<sub>mechanic_id; COUNT(*) → wo_count</sub>(Work_orders)
(γ = grouping / aggregation; in SQL: `GROUP BY mechanic_id`.)

---

## Exercise 11 — Many-to-many via bridge

**Task:** List job type **name** and **price** for every line on work order `id = 1` (use `order_jobs` and `job_types`).

**Algebra:**
π<sub>jt.name, oj.price</sub>(
 σ<sub>oj.work_order_id = 1</sub>( ρ<sub>oj</sub>(Order_jobs) ⋈<sub>oj.job_type_id = jt.id</sub> ρ<sub>jt</sub>(Job_types) )
)

---

## Exercise 12 — Inventory joined to warehouse and part

**Task:** For rows where `quantity < 5`, show `warehouse` name, part `sku`, and `quantity`.

**Algebra:**
π<sub>w.name, p.sku, inv.quantity</sub>(
 σ<sub>inv.quantity < 5</sub>( Inventory ⋈ Parts ⋈ Warehouses on keys )
)
(Join `inventory.part_id = parts.id` and `inventory.warehouse_id = warehouses.id`.)

---

## Exercise 13 — Existence / semi-join pattern

**Task:** Customers who have at least one appointment with status `confirmed` (list distinct customer id and name).

**Algebra (semi-join style):**
π<sub>c.id, c.first_name, c.last_name</sub>(
 Customers ⋉ ( Vehicles ⋈ Appointments where appointments.status = 'confirmed' )
)
(“⋉” = semi-join; in SQL this is usually `EXISTS` or `INNER JOIN` with `DISTINCT`.)

---

## Exercise 14 — Cartesian product (small restriction)

**Task:** Pairs `(employee.id, role.id)` **only where** `employees.role_id = roles.id` — i.e. show that a θ-join is really σ( R × S ).

**Algebra:**
σ<sub>e.role_id = r.id</sub>( Employees × ρ<sub>r</sub>(Roles) )

---

## Exercise 15 — Equivalence pairs (self-join on “parts”)

**Task:** From `equivalents` (`part_id_1`, `part_id_2`), list SKUs for both sides of each pair.

**Algebra:**
π<sub>p1.sku, p2.sku</sub>(
 Equivalents ⋈<sub>part_id_1 = p1.id</sub> ρ<sub>p1</sub>(Parts) ⋈<sub>part_id_2 = p2.id</sub> ρ<sub>p2</sub>(Parts)
)

---

### How to run the SQL

1. Load the dump into MySQL, e.g. `mysql ... < car_service_db.sql` after `gunzip`.
2. `USE car_service_db;`
3. Run queries from `car_service_algebra_examples.sql`.

If a query returns an empty set on your machine, loosen predicates (e.g. change thresholds or remove filters) — the **structure** of the algebra ↔ SQL mapping stays the same.
