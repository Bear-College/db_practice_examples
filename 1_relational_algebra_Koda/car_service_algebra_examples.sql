-- Relational algebra (Algebra Koda) — runnable examples for `car_service_db`
-- Source schema: ../database/car_service_db.sql.gz
-- Usage: mysql -u... -p... car_service_db < car_service_algebra_examples.sql
-- Or paste individual blocks after: USE car_service_db;

USE car_service_db;

-- Exercise 1 — σ_{status='completed'}(Work_orders)
SELECT id, vehicle_id, mechanic_id, status, total_cost
FROM work_orders
WHERE status = 'completed';

-- Exercise 2 — π_{sku,brand}(Parts)
SELECT sku, brand
FROM parts;

-- Exercise 3 — π_{email}(σ_{phone IS NOT NULL}(Customers))
SELECT email
FROM customers
WHERE phone IS NOT NULL;

-- Exercise 4 — join Work_orders and Vehicles, select high-cost rows
SELECT wo.id, v.plate, wo.total_cost
FROM work_orders AS wo
INNER JOIN vehicles AS v ON wo.vehicle_id = v.id
WHERE wo.total_cost > 1000;

-- Exercise 5 — three-way join: work order → vehicle → customer names
SELECT wo.id AS work_order_id,
       c.first_name,
       c.last_name
FROM work_orders AS wo
INNER JOIN vehicles AS v ON wo.vehicle_id = v.id
INNER JOIN customers AS c ON v.customer_id = c.id;

-- Exercise 6 — union of projections (distinct customer_id)
SELECT customer_id FROM blacklist
UNION
SELECT customer_id FROM loyalty_cards WHERE points > 0;

-- Exercise 7 — set difference on customer_id sets (NOT EXISTS avoids NULL pitfalls of NOT IN)
SELECT DISTINCT v.customer_id
FROM vehicles AS v
WHERE v.customer_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM blacklist AS b WHERE b.customer_id = v.customer_id
  );

-- Exercise 8 — intersection of customer_id sets
-- MySQL 8.0.31+ / 9.x: INTERSECT is available; alternative: INNER JOIN DISTINCT pairs below.
SELECT DISTINCT f.customer_id
FROM feedback AS f
INNER JOIN marketing_consents AS m ON f.customer_id = m.customer_id;

-- Exercise 8 (alternate, if your server supports INTERSECT)
-- SELECT customer_id FROM feedback
-- INTERSECT
-- SELECT customer_id FROM marketing_consents;

-- Exercise 9 — rename via AS
SELECT id AS cust_id, email
FROM customers;

-- Exercise 10 — extended RA: grouping / COUNT
SELECT mechanic_id,
       COUNT(*) AS wo_count
FROM work_orders
WHERE mechanic_id IS NOT NULL
GROUP BY mechanic_id;

-- Exercise 11 — order_jobs ⋈ job_types for one work order
SELECT jt.name AS job_type_name,
       oj.price
FROM order_jobs AS oj
INNER JOIN job_types AS jt ON oj.job_type_id = jt.id
WHERE oj.work_order_id = 1;

-- Exercise 12 — low stock: inventory with warehouse and part
SELECT w.name AS warehouse_name,
       p.sku,
       inv.quantity
FROM inventory AS inv
INNER JOIN warehouses AS w ON inv.warehouse_id = w.id
INNER JOIN parts AS p ON inv.part_id = p.id
WHERE inv.quantity < 5;

-- Exercise 13 — customers with at least one confirmed appointment (semi-join via DISTINCT)
SELECT DISTINCT c.id,
                c.first_name,
                c.last_name
FROM customers AS c
INNER JOIN vehicles AS v ON v.customer_id = c.id
INNER JOIN appointments AS a ON a.vehicle_id = v.id
WHERE a.status = 'confirmed';

-- Exercise 13 (EXISTS style — matches "semi-join" reading)
SELECT c.id, c.first_name, c.last_name
FROM customers AS c
WHERE EXISTS (
  SELECT 1
  FROM vehicles AS v
  INNER JOIN appointments AS a ON a.vehicle_id = v.id
  WHERE v.customer_id = c.id
    AND a.status = 'confirmed'
);

-- Exercise 14 — θ-join as σ on Cartesian product (illustrative; avoid full cross products on large tables)
SELECT e.id AS employee_id,
       r.id AS role_id
FROM employees AS e
CROSS JOIN roles AS r
WHERE e.role_id = r.id;

-- Exercise 15 — equivalents: two aliases on parts
SELECT p1.sku AS sku_1,
       p2.sku AS sku_2
FROM equivalents AS e
INNER JOIN parts AS p1 ON e.part_id_1 = p1.id
INNER JOIN parts AS p2 ON e.part_id_2 = p2.id;
