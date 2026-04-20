-- User and system variables — car_service_db (MySQL 8+ / 5.7+)
-- Run entire file in ONE mysql session so @ variables are kept between statements.
--   mysql ... car_service_db < 11_variables/car_service_variables_examples.sql

USE car_service_db;

-- =============================================================================
-- 1) User variables: SET … then use in WHERE
-- =============================================================================
SET @wo_lo := 1;
SET @wo_hi := 800;

SELECT id,
       status,
       total_cost
FROM work_orders
WHERE id BETWEEN @wo_lo AND @wo_hi
ORDER BY id
LIMIT 15;

-- =============================================================================
-- 2) Assign from a query (aggregate into @avg_cost)
-- =============================================================================
SELECT @avg_cost := AVG(total_cost)
FROM work_orders
WHERE id BETWEEN 1 AND 50000;

SELECT @avg_cost AS stored_avg_total_cost;

-- =============================================================================
-- 3) LIMIT / OFFSET via user variables (pagination parameters)
-- =============================================================================
SET @page_size := 12;
SET @page := 2;
SET @offset_rows := (@page - 1) * @page_size;

SELECT id,
       mechanic_id,
       total_cost
FROM work_orders
WHERE id BETWEEN 1 AND 3000
ORDER BY id
LIMIT @offset_rows, @page_size;

-- =============================================================================
-- 4) := in SELECT — classic row counter (before window ROW_NUMBER)
-- =============================================================================
SELECT id,
       total_cost,
       @rn := @rn + 1 AS row_seq
FROM work_orders
CROSS JOIN (SELECT @rn := 0) AS init
WHERE id BETWEEN 1 AND 500
ORDER BY id
LIMIT 20;

-- =============================================================================
-- 5) Multiple assignments in one SET + reuse
-- =============================================================================
SET @cust_lo := 1, @cust_hi := 200;

SELECT COUNT(*) AS n_customers_in_range
FROM customers
WHERE id BETWEEN @cust_lo AND @cust_hi;

-- =============================================================================
-- 6) Prepared statement: placeholders filled from user variables
-- =============================================================================
SET @sql := 'SELECT id, status, total_cost FROM work_orders WHERE id BETWEEN ? AND ? ORDER BY id LIMIT ?';

SET @p_lo := 100;
SET @p_hi := 400;
SET @p_lim := 8;

PREPARE stmt FROM @sql;
EXECUTE stmt USING @p_lo, @p_hi, @p_lim;
DEALLOCATE PREPARE stmt;

-- =============================================================================
-- 7) System / status variables (@@) — read-only in typical labs
-- =============================================================================
SELECT @@version AS mysql_version,
       @@version_comment AS build,
       @@session.transaction_isolation AS tx_isolation;

-- Optional: temporarily cap rows returned (session only); uncomment to try, then restore.
-- SET SESSION sql_select_limit = 50;
-- SELECT id FROM work_orders WHERE id BETWEEN 1 AND 1000 ORDER BY id;
-- SET SESSION sql_select_limit = DEFAULT;

-- =============================================================================
-- 8) Clear a user variable (or set to NULL)
-- =============================================================================
SET @avg_cost := NULL;

SELECT @avg_cost IS NULL AS avg_cost_cleared;
