-- Вбудовані функції SQL (MySQL) — car_service_db
-- Не: функції користувача (CREATE FUNCTION). Рядкові / числові / дати / умовні / допоміжні.
--   mysql ... car_service_db < 13_functions/car_service_functions_examples.sql

USE car_service_db;

-- =============================================================================
-- F1 — Рядки: CONCAT, UPPER, LOWER, PROPER (CONCAT + SUBSTRING)
-- =============================================================================
SELECT id,
       CONCAT(first_name, ' ', last_name) AS full_name,
       LOWER(email) AS email_lower,
       UPPER(last_name) AS last_upper,
       CONCAT(UPPER(SUBSTRING(last_name, 1, 1)), lower(substring(last_name, 2))) AS last_proper
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
-- F4 — Числові: ROUND, CEILING, FLOOR, ABS, MOD
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
-- F5 — Дата/час: DATE_FORMAT, YEAR, TIMESTAMPDIFF, CURDATE
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
-- F6 — Умовні: IF, IFNULL, NULLIF, COALESCE (work_orders + customers для nullable-полів)
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
-- F7 — GREATEST, LEAST (мінімум/максимум кількох значень у рядку)
-- =============================================================================
SELECT id,
       total_cost,
       GREATEST(total_cost, 100.0, 250.5) AS at_least_threshold,
       LEAST(total_cost, 800.0) AS capped_display
FROM work_orders
WHERE id BETWEEN 1 AND 400
LIMIT 15;

-- =============================================================================
-- F8 — FORMAT (групування в стилі локалі; другий аргумент — знаки після коми)
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
-- F10 — GROUP_CONCAT (агрегований список рядків на групу)
-- =============================================================================
SELECT status,
       COUNT(*) AS n,
       GROUP_CONCAT(id ORDER BY id SEPARATOR ',') AS sample_ids
FROM work_orders
WHERE id BETWEEN 1 AND 5000
GROUP BY status
ORDER BY status;

-- =============================================================================
-- РОЗВ'ЯЗКИ ЗАДАЧ (середня / висока складність)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- T1 — Нормалізація контактів клієнта
-- -----------------------------------------------------------------------------
SELECT c.id AS customer_id,
       CONCAT(c.first_name, ' ',
              CONCAT(UPPER(SUBSTRING(c.last_name, 1, 1)), LOWER(SUBSTRING(c.last_name, 2)))) AS full_name,
       COALESCE(c.phone, c.email, 'NO_CONTACT') AS primary_contact,
       CASE
           WHEN c.phone IS NOT NULL THEN 'PHONE'
           WHEN c.phone IS NULL AND c.email IS NOT NULL THEN 'EMAIL'
           ELSE 'NONE'
       END AS contact_type,
       CASE
           WHEN c.email IS NULL OR c.email NOT LIKE '%@%' THEN 'NO_EMAIL'
           ELSE CONCAT(LEFT(SUBSTRING_INDEX(c.email, '@', 1), 2), '***', '@', SUBSTRING_INDEX(c.email, '@', -1))
       END AS masked_email
FROM customers AS c
WHERE c.id BETWEEN 1 AND 300
LIMIT 50;

-- -----------------------------------------------------------------------------
-- T2 — Сегментація вартості замовлень
-- -----------------------------------------------------------------------------
SELECT wo.id,
       wo.total_cost,
       ROUND(wo.total_cost, 2) AS rounded_cost,
       CASE
           WHEN wo.total_cost < 300 THEN 'LOW'
           WHEN wo.total_cost < 800 THEN 'MEDIUM'
           ELSE 'HIGH'
       END AS cost_segment,
       ABS(wo.total_cost - 500) AS distance_from_avg_500
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 800
ORDER BY wo.total_cost DESC
LIMIT 40;

-- -----------------------------------------------------------------------------
-- T3 — Оцінка терміновості записувань
-- -----------------------------------------------------------------------------
SELECT a.id,
       a.scheduled_at,
       DATE_FORMAT(a.scheduled_at, '%Y-%m-%d %H:%i') AS scheduled_fmt,
       TIMESTAMPDIFF(DAY, NOW(), a.scheduled_at) AS days_until_or_since,
       CASE
           WHEN TIMESTAMPDIFF(DAY, NOW(), a.scheduled_at) < 0 THEN 'OVERDUE'
           WHEN TIMESTAMPDIFF(DAY, NOW(), a.scheduled_at) = 0 THEN 'TODAY'
           WHEN TIMESTAMPDIFF(DAY, NOW(), a.scheduled_at) BETWEEN 1 AND 7 THEN 'SOON'
           ELSE 'PLANNED'
       END AS urgency_label
FROM appointments AS a
WHERE a.id BETWEEN 1 AND 400
ORDER BY a.scheduled_at
LIMIT 60;

-- -----------------------------------------------------------------------------
-- T4 — Перевірки якості SKU
-- -----------------------------------------------------------------------------
SELECT p.id,
       p.sku,
       LENGTH(p.sku) AS sku_len,
       CASE
           WHEN p.sku REGEXP ' ' OR LENGTH(p.sku) < 6 THEN 'BAD'
           ELSE 'GOOD'
       END AS sku_quality,
       UPPER(REPLACE(p.sku, ' ', '')) AS normalized_sku
FROM parts AS p
WHERE p.id BETWEEN 1 AND 1000
LIMIT 60;

-- -----------------------------------------------------------------------------
-- T5 — Аналітика вартості за статусами
-- -----------------------------------------------------------------------------
SELECT wo.status,
       COUNT(*) AS orders_count,
       MIN(wo.total_cost) AS min_cost,
       MAX(wo.total_cost) AS max_cost,
       ROUND(AVG(wo.total_cost), 2) AS avg_cost_2d,
       MAX(wo.total_cost) - MIN(wo.total_cost) AS cost_span,
       GROUP_CONCAT(wo.id ORDER BY wo.id SEPARATOR ',') AS sample_order_ids
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 5000
GROUP BY wo.status
ORDER BY avg_cost_2d DESC;

-- -----------------------------------------------------------------------------
-- T6 — Діагностика номерних знаків
-- -----------------------------------------------------------------------------
SELECT v.id,
       v.plate,
       UPPER(TRIM(v.plate)) AS plate_clean,
       LEFT(UPPER(TRIM(v.plate)), 2) AS prefix,
       RIGHT(UPPER(TRIM(v.plate)), 2) AS suffix,
       CASE
           WHEN v.plate IS NULL OR TRIM(v.plate) = '' THEN 'MISSING'
           WHEN LENGTH(TRIM(v.plate)) < 5 THEN 'SHORT'
           ELSE 'OK'
       END AS plate_flag
FROM vehicles AS v
WHERE v.id BETWEEN 1 AND 400
LIMIT 50;
