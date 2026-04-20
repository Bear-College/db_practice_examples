-- JOIN examples (easy and hard) — car_service_db
-- Load: gunzip -c database_mysql/car_service_db.sql.gz | mysql ... car_service_db
-- Run:  mysql ... car_service_db < 07_join/car_service_join_examples.sql

USE car_service_db;

-- =============================================================================
-- EASY
-- =============================================================================

-- E1 — INNER JOIN: vehicle + brand name
SELECT v.id AS vehicle_id,
       v.plate,
       v.car,
       b.name AS brand_name
FROM vehicles AS v
INNER JOIN car_brands AS b ON b.id = v.brand_id
WHERE v.id BETWEEN 1 AND 200
LIMIT 30;

-- E2 — INNER JOIN: work order + vehicle plate
SELECT wo.id AS work_order_id,
       wo.status,
       wo.total_cost,
       v.plate,
       v.id AS vehicle_id
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
WHERE wo.id BETWEEN 1 AND 500
LIMIT 25;

-- E3 — INNER JOIN chain: work_order → vehicle → customer
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

-- E4 — LEFT JOIN: keep every customer in range; feedback may be NULL
SELECT c.id AS customer_id,
       c.email,
       f.rating,
       f.comment
FROM customers AS c
LEFT JOIN feedback AS f ON f.customer_id = c.id
WHERE c.id BETWEEN 1 AND 80
LIMIT 40;

-- E5 — INNER JOIN: part + retail price
SELECT p.id AS part_id,
       p.sku,
       p.name,
       pp.retail_price
FROM parts AS p
INNER JOIN part_prices AS pp ON pp.part_id = p.id
WHERE p.id BETWEEN 1 AND 500
LIMIT 25;

-- E6 — INNER JOIN: employee + role title (bonus easy)
SELECT e.id AS employee_id,
       e.first_name,
       e.last_name,
       r.title AS role_title
FROM employees AS e
INNER JOIN roles AS r ON r.id = e.role_id
WHERE e.id BETWEEN 1 AND 150
LIMIT 25;

-- =============================================================================
-- HARD
-- =============================================================================

-- H1 — Anti-join: customers with NO vehicle (LEFT JOIN + IS NULL)
SELECT c.id,
       c.first_name,
       c.last_name
FROM customers AS c
WHERE c.id BETWEEN 1 AND 5000
  AND EXISTS (
    SELECT 1 FROM vehicles AS v WHERE v.customer_id = c.id
  )
LIMIT 25;

-- H2 — Multi LEFT JOIN: one optional feedback + one optional vehicle per customer (via key subqueries)
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

-- H3 — Bridge table + self-join on parts (equivalent SKUs)
SELECT p1.sku AS sku_a,
       p2.sku AS sku_b,
       p1.brand AS brand_a,
       p2.brand AS brand_b
FROM equivalents AS e
INNER JOIN parts AS p1 ON p1.id = e.part_id_1
INNER JOIN parts AS p2 ON p2.id = e.part_id_2
WHERE e.id BETWEEN 1 AND 500
LIMIT 25;

-- H4 — INNER JOIN to derived table: customers with vehicle counts, then filter
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

-- H5 — FULL OUTER JOIN pattern (MySQL): unmatched rows from left ∪ unmatched from right (small id slices)
--      Part A: warehouses in slice with no inventory row (in inventory slice)
SELECT w.id AS side_id,
       w.name AS label,
       'warehouse_without_inventory_in_slice' AS match_kind
FROM warehouses AS w
LEFT JOIN inventory AS inv
  ON inv.warehouse_id = w.id
 AND inv.id BETWEEN 1 AND 50000
WHERE w.id BETWEEN 1 AND 30
  AND inv.id IS NULL
UNION ALL
-- Part B: inventory rows in slice pointing to warehouses outside the left slice (still valid FK; “outer” demo)
SELECT inv.id AS side_id,
       CAST(CONCAT('inv_wh_', inv.warehouse_id) AS CHAR(100)) AS label,
       'inventory_row_outside_left_slice' AS match_kind
FROM inventory AS inv
WHERE inv.id BETWEEN 1 AND 5000
  AND inv.warehouse_id NOT IN (SELECT w2.id FROM warehouses AS w2 WHERE w2.id BETWEEN 1 AND 30)
LIMIT 25;

-- =============================================================================
-- RIGHT JOIN, CROSS JOIN, FULL OUTER pattern, many tables in one query
-- =============================================================================

-- R1 — RIGHT JOIN (mirror of LEFT JOIN: “keep every row from the table on the RIGHT”)
--      Here: all vehicles in the slice appear; brand columns come from the left (NULL if no match — rare with FK).
SELECT b.id AS brand_id,
       b.name AS brand_name,
       v.id AS vehicle_id,
       v.plate
FROM car_brands AS b
RIGHT JOIN vehicles AS v ON v.brand_id = b.id
WHERE v.id BETWEEN 1 AND 40
LIMIT 40;

-- R2 — CROSS JOIN: Cartesian product — MUST restrict both sides (tiny slices) or you explode row count
--      Demo: first N brands × first M fuel types (catalog “grid”; not a FK path)
SELECT b.id AS brand_id,
       b.name AS brand_name,
       ft.id AS fuel_type_id,
       ft.name AS fuel_name
FROM (SELECT id, name FROM car_brands WHERE id BETWEEN 1 AND 3) AS b
CROSS JOIN (SELECT id, name FROM fuel_types WHERE id BETWEEN 1 AND 4) AS ft;

-- R3 — FULL OUTER JOIN pattern in MySQL (no native FULL OUTER): LEFT ∪ “right-only”
--      Part 1 — every warehouse in slice, with or without inventory rows
--      Part 2 — inventory rows with no matching warehouse (empty when FKs are intact)
SELECT w.id AS warehouse_id,
       w.name AS warehouse_name,
       inv.id AS inventory_id,
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

-- MJ1 — Many joins in ONE query: work order → vehicle → customer → brand, plus optional line job + job type
SELECT wo.id AS work_order_id,
       wo.status,
       wo.total_cost,
       c.first_name,
       c.last_name,
       v.plate,
       b.name AS brand_name,
       oj.price AS line_price,
       jt.name AS job_type_name
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
INNER JOIN car_brands AS b ON b.id = v.brand_id
LEFT JOIN order_jobs AS oj ON oj.work_order_id = wo.id AND oj.id BETWEEN 1 AND 400000
LEFT JOIN job_types AS jt ON jt.id = oj.job_type_id
WHERE wo.id BETWEEN 1 AND 150
LIMIT 30;
