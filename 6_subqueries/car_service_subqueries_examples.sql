-- Subqueries — easy and hard examples for car_service_db
-- Load: gunzip -c database/car_service_db.sql.gz | mysql ... car_service_db
-- Run:  mysql ... car_service_db < 6_subqueries/car_service_subqueries_examples.sql

USE car_service_db;

-- =============================================================================
-- EASY — non-correlated subqueries (inner query does not use outer columns)
-- =============================================================================

-- E1 — WHERE … IN (SELECT …): work orders for vehicles in a bounded id list
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

-- E2 — Scalar subquery: rows above the average total_cost (same slice)
SELECT wo.id,
       wo.total_cost,
       (SELECT AVG(w2.total_cost)
        FROM work_orders AS w2
        WHERE w2.id BETWEEN 1 AND 80000) AS slice_avg_cost
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 80000
  AND wo.total_cost > (
        SELECT AVG(w3.total_cost)
        FROM work_orders AS w3
        WHERE w3.id BETWEEN 1 AND 80000
      )
ORDER BY wo.total_cost DESC
LIMIT 20;

-- E3 — Derived table in FROM: customers with vehicle counts (inline view)
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

-- E4 — EXISTS (semi-join style): customers who have feedback
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

-- =============================================================================
-- HARD — correlated subqueries, NOT EXISTS, nesting, HAVING + subquery
-- =============================================================================

-- H1 — Correlated: work orders costing more than *this mechanic's* average (same mechanic_id)
SELECT wo.id,
       wo.mechanic_id,
       wo.total_cost,
       (SELECT AVG(wb.total_cost)
        FROM work_orders AS wb
        WHERE wb.mechanic_id = wo.mechanic_id
          AND wb.id BETWEEN 1 AND 200000
          AND wb.mechanic_id IS NOT NULL) AS avg_for_mechanic
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 8000
  AND wo.mechanic_id IS NOT NULL
  AND wo.total_cost > (
        SELECT AVG(wi.total_cost)
        FROM work_orders AS wi
        WHERE wi.mechanic_id = wo.mechanic_id
          AND wi.id BETWEEN 1 AND 200000
      )
ORDER BY wo.mechanic_id, wo.total_cost DESC
LIMIT 25;

-- H2 — NOT EXISTS: customers (in range) with no feedback at all
SELECT c.id,
       c.first_name,
       c.last_name
FROM customers AS c
WHERE c.id BETWEEN 1 AND 300
  AND NOT EXISTS (
    SELECT 1
    FROM feedback AS f
    WHERE f.customer_id = c.id
  )
LIMIT 30;

-- H3 — Nested IN: mechanics whose role title matches a pattern (roles filtered in inner query)
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

-- H4 — Subquery in HAVING: mechanics with more work orders than the “average per mechanic”
--     (computed in a slice of work_orders)
SELECT wo.mechanic_id,
       COUNT(*) AS wo_cnt
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 100000
  AND wo.mechanic_id IS NOT NULL
GROUP BY wo.mechanic_id
HAVING COUNT(*) > (
  SELECT AVG(cnt)
  FROM (
         SELECT COUNT(*) AS cnt
         FROM work_orders AS w2
         WHERE w2.id BETWEEN 1 AND 100000
           AND w2.mechanic_id IS NOT NULL
         GROUP BY w2.mechanic_id
       ) AS per_mechanic
)
ORDER BY wo_cnt DESC
LIMIT 15;

-- H5 — Correlated EXISTS: customers with at least one confirmed appointment
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
