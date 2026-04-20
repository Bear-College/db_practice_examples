-- Built-in SQL functions (MySQL) — car_service_db
-- Not: user-defined functions (CREATE FUNCTION). String / numeric / date / conditional / utility.
--   mysql ... car_service_db < 13_functions/car_service_functions_examples.sql

USE car_service_db;

-- =============================================================================
-- F1 — String: CONCAT, UPPER, LOWER
-- =============================================================================
SELECT id,
       CONCAT(first_name, ' ', last_name) AS full_name,
       LOWER(email) AS email_lower,
       UPPER(last_name) AS last_upper
FROM customers
WHERE id BETWEEN 1 AND 150
LIMIT 20;

-- =============================================================================
-- F2 — LENGTH, LEFT, RIGHT, SUBSTRING (parts.sku / name)
-- =============================================================================
SELECT id,
       sku,
       LENGTH(sku) AS sku_len,
       LEFT(sku, 5) AS sku_prefix5,
       RIGHT(sku, 4) AS sku_suffix4,
       SUBSTRING(name, 1, 40) AS name_short
FROM parts
WHERE id BETWEEN 1 AND 200
LIMIT 20;

-- =============================================================================
-- F3 — TRIM, REPLACE
-- =============================================================================
SELECT id,
       plate,
       TRIM(BOTH ' ' FROM plate) AS plate_trimmed,
       REPLACE(car, ' ', '_') AS car_no_spaces
FROM vehicles
WHERE id BETWEEN 1 AND 100
LIMIT 15;

-- =============================================================================
-- F4 — Numeric: ROUND, CEILING, FLOOR, ABS, MOD
-- =============================================================================
SELECT id,
       total_cost,
       ROUND(total_cost, 1) AS cost_1dec,
       CEILING(total_cost) AS cost_ceil,
       FLOOR(total_cost) AS cost_floor,
       ABS(total_cost - 500) AS dist_from_500,
       MOD(id, 7) AS id_mod_7
FROM work_orders
WHERE id BETWEEN 1 AND 500
LIMIT 20;

-- =============================================================================
-- F5 — Date/time: DATE_FORMAT, YEAR, TIMESTAMPDIFF, CURDATE
-- =============================================================================
SELECT id,
       scheduled_at,
       DATE_FORMAT(scheduled_at, '%Y-%m-%d %H:%i') AS sched_fmt,
       YEAR(scheduled_at) AS sched_year,
       TIMESTAMPDIFF(DAY, scheduled_at, NOW()) AS days_since_scheduled
FROM appointments
WHERE id BETWEEN 1 AND 200
LIMIT 20;

-- =============================================================================
-- F6 — Conditionals: IF, IFNULL, NULLIF, COALESCE (work_orders + customers for nullable fields)
-- =============================================================================
SELECT wo.id,
       wo.status,
       wo.total_cost,
       IFNULL(c.phone, 'no phone') AS phone_display,
       COALESCE(c.phone, c.email, 'no contact') AS contact_fallback,
       IF(wo.total_cost >= 600, 'high', 'normal') AS cost_band,
       NULLIF(wo.status, 'cancelled') AS status_unless_cancelled
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
WHERE wo.id BETWEEN 1 AND 300
LIMIT 20;

-- =============================================================================
-- F7 — GREATEST, LEAST (per-row min/max of several values)
-- =============================================================================
SELECT id,
       total_cost,
       GREATEST(total_cost, 100.0, 250.5) AS at_least_threshold,
       LEAST(total_cost, 800.0) AS capped_display
FROM work_orders
WHERE id BETWEEN 1 AND 400
LIMIT 15;

-- =============================================================================
-- F8 — FORMAT (locale-style grouping; second arg = decimals)
-- =============================================================================
SELECT id,
       total_cost,
       FORMAT(total_cost, 2) AS cost_formatted
FROM work_orders
WHERE id BETWEEN 1 AND 20
LIMIT 15;

-- =============================================================================
-- F9 — REGEXP (MySQL: REGEXP / RLIKE)
-- =============================================================================
SELECT id,
       email
FROM customers
WHERE id BETWEEN 1 AND 500
  AND email REGEXP '^[a-z]'
LIMIT 15;

-- =============================================================================
-- F10 — GROUP_CONCAT (aggregate string list per group)
-- =============================================================================
SELECT status,
       COUNT(*) AS n,
       GROUP_CONCAT(id ORDER BY id SEPARATOR ',') AS sample_ids
FROM work_orders
WHERE id BETWEEN 1 AND 5000
GROUP BY status
ORDER BY status;
