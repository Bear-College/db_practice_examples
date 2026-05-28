-- OLTP vs OLAP — contrasting query patterns on car_service_db
-- Load dump first: gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
-- Run: mysql -u root car_service_db < 03_mysql/17_oltp_olap/car_service_oltp_olap_examples.sql

USE car_service_db;

-- =============================================================================
-- 1) OLTP — point lookup by primary key (single row, low latency)
-- =============================================================================
SELECT wo.id,
       wo.status,
       wo.total_cost,
       v.plate,
       c.last_name
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
WHERE wo.id = 42;

-- =============================================================================
-- 2) OLTP — narrow write (update one row, transactional shape)
-- =============================================================================
-- Read current state (typical app flow: SELECT then UPDATE in one transaction)
SELECT id, status, total_cost
FROM work_orders
WHERE id BETWEEN 1 AND 5;

-- Simulated status change (run inside START TRANSACTION … COMMIT in production)
UPDATE work_orders
SET status = 'in_progress'
WHERE id = 2
  AND status = 'new';

SELECT id, status
FROM work_orders
WHERE id = 2;

-- Restore demo row for repeatability
UPDATE work_orders
SET status = 'new'
WHERE id = 2;

-- =============================================================================
-- 3) OLAP-style — heavy aggregation over many rows (read-mostly, scan + group)
-- =============================================================================
SELECT wo.status,
       COUNT(*) AS order_count,
       ROUND(SUM(wo.total_cost), 2) AS revenue,
       ROUND(AVG(wo.total_cost), 2) AS avg_ticket
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 50000
GROUP BY wo.status
ORDER BY revenue DESC;

-- =============================================================================
-- 4) OLAP-style — dimensional slice (GROUP BY + multiple JOINs, dashboard grain)
-- =============================================================================
SELECT b.name AS brand_name,
       wo.status,
       COUNT(*) AS orders,
       ROUND(SUM(wo.total_cost), 2) AS total_revenue
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN car_brands AS b ON b.id = v.brand_id
WHERE wo.id BETWEEN 1 AND 20000
GROUP BY b.name, wo.status
HAVING COUNT(*) >= 100
ORDER BY total_revenue DESC
LIMIT 10;
