# Subqueries — `car_service_db`

Examples use **`car_service_db`** from **`database/car_service_db.sql.gz`**. The runnable script is **`06_subqueries/car_service_subqueries_examples.sql`**.

```bash
gunzip -c database/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 06_subqueries/car_service_subqueries_examples.sql
```

**Performance:** predicates use **`BETWEEN`** on `id` columns where helpful so large tables stay tractable.

---

## Ideas (easy → hard)

| Level | Pattern | What to learn |
|-------|---------|----------------|
| **Easy** | `IN (SELECT …)` | Subquery returns a column list; outer row matches any value. |
| **Easy** | Scalar compare: `> (SELECT AVG(…) …)` | Subquery returns exactly one value. |
| **Easy** | `FROM (SELECT …) AS alias` | Derived table: treat a `SELECT` as a table in `FROM`. |
| **Easy** | `EXISTS (SELECT 1 …)` | True if the subquery returns any row (often `SELECT 1`). |
| **Hard** | **Correlated** subquery | Inner `SELECT` references a column from the outer query (e.g. `wo.vehicle_id`). |
| **Hard** | `NOT EXISTS` | Rows for which no matching row exists in the subquery. |
| **Hard** | Nested `IN` / multi-step filters | Inner queries feed outer ones; mind `NULL` with `NOT IN`. |
| **Hard** | Subquery in `HAVING` | Compare an aggregate to a value computed by another `SELECT`. |

---

## Schema touchpoints

- **`work_orders`** — `vehicle_id`, `mechanic_id`, `status`, `total_cost`
- **`vehicles`** — `id`, `customer_id`
- **`customers`**, **`feedback`**, **`appointments`**, **`employees`**, **`roles`**, **`part_prices`**, **`parts`**

Pair each numbered block in the `.sql` file with the matching exercise below.

---

## Easy exercises

1. **`IN` (non-correlated)** — Work orders whose `vehicle_id` appears in a bounded slice of **`vehicles`**.
2. **Scalar subquery** — Work orders with `total_cost` **above** the average cost in a slice.
3. **Derived table** — `FROM (SELECT … GROUP BY …) AS alias` counting vehicles per customer.
4. **`EXISTS`** — Customers who have at least one **`feedback`** row (bounded range).

## Hard exercises

5. **Correlated comparison** — Work orders that cost **more than the average** `total_cost` **for the same mechanic** (`mechanic_id`).
6. **`NOT EXISTS`** — Customers in a range who have **no** **`feedback`** row.
7. **Nested `IN`** — Mechanics (`employees`) whose `role_id` is in **`roles`** where `title` matches e.g. **`%Mechanic%`**.
8. **Subquery in `HAVING`** — Mechanic ids with **more** work orders than the overall average count per mechanic (in a slice).
9. **Correlated `EXISTS`** — Customers with at least one **`confirmed`** appointment (through **`vehicles`**).

If a result is empty, widen the `id` ranges slightly.
