-- Віконні функції — MySQL 8.0+ на car_service_db
-- Завантаження: gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql ... car_service_db
-- Запуск: mysql ... car_service_db < 10_windows_functions/car_service_windows_functions_examples.sql

USE car_service_db;

-- =============================================================================
-- W1 — ROW_NUMBER: унікальна послідовність у межах кожного work_orders.status (зріз)
-- =============================================================================
SELECT id,
       status,
       total_cost,
       ROW_NUMBER() OVER (
         PARTITION BY status
         ORDER BY total_cost DESC, id
       ) AS rn_in_status
FROM work_orders
WHERE id BETWEEN 1 AND 5000
LIMIT 40;

-- =============================================================================
-- W2 — RANK vs DENSE_RANK (нічиї отримують той самий ранг; DENSE_RANK не залишає пропусків)
-- =============================================================================
SELECT id,
       assigned_mechanic_id,
       total_cost,
       RANK() OVER (
         PARTITION BY assigned_mechanic_id
         ORDER BY total_cost DESC
       ) AS rnk,
       DENSE_RANK() OVER (
         PARTITION BY assigned_mechanic_id
         ORDER BY total_cost DESC
       ) AS dense_rnk
FROM work_orders
WHERE id BETWEEN 1 AND 8000
  AND assigned_mechanic_id IS NOT NULL
LIMIT 35;

-- =============================================================================
-- W3 — SUM / AVG як віконні агрегати по партиції (рядки не згортаються)
-- =============================================================================
SELECT id,
       status,
       total_cost,
       SUM(total_cost) OVER (PARTITION BY status) AS sum_cost_in_status,
       AVG(total_cost) OVER (PARTITION BY status) AS avg_cost_in_status
FROM work_orders
WHERE id BETWEEN 1 AND 10000
LIMIT 30;

-- =============================================================================
-- W4 — «Накопичувальна» сума всередині партиції (ORDER BY в OVER)
-- =============================================================================
SELECT id,
       status,
       total_cost,
       SUM(total_cost) OVER (
         PARTITION BY status
         ORDER BY id
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_sum_same_status
FROM work_orders
WHERE id BETWEEN 1 AND 2000
LIMIT 25;

-- =============================================================================
-- W5 — LAG / LEAD: попередня й наступна вартість замовлення для того самого механіка (за порядком id)
-- =============================================================================
SELECT id,
       assigned_mechanic_id,
       total_cost,
       LAG(total_cost, 1) OVER (
         PARTITION BY assigned_mechanic_id
         ORDER BY id
       ) AS prev_cost,
       LEAD(total_cost, 1) OVER (
         PARTITION BY assigned_mechanic_id
         ORDER BY id
       ) AS next_cost
FROM work_orders
WHERE id BETWEEN 1 AND 12000
  AND assigned_mechanic_id IS NOT NULL
LIMIT 35;

-- =============================================================================
-- W6 — NTILE: розбити кожну групу статусу на 4 кошики (у межах зрізу)
-- =============================================================================
SELECT id,
       status,
       total_cost,
       NTILE(4) OVER (
         PARTITION BY status
         ORDER BY total_cost DESC, id
       ) AS quartile_bucket
FROM work_orders
WHERE id BETWEEN 1 AND 8000
LIMIT 32;

-- =============================================================================
-- W7 — FIRST_VALUE / LAST_VALUE (явний кадр, щоб LAST_VALUE = останній рядок партиції)
-- =============================================================================
SELECT id,
       vehicle_id,
       total_cost,
       FIRST_VALUE(total_cost) OVER (
         PARTITION BY vehicle_id
         ORDER BY id
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS first_wo_cost_for_vehicle,
       LAST_VALUE(total_cost) OVER (
         PARTITION BY vehicle_id
         ORDER BY id
         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
       ) AS last_wo_cost_for_vehicle
FROM work_orders
WHERE id BETWEEN 1 AND 6000
LIMIT 30;

-- =============================================================================
-- W8 — Іменована секція WINDOW: повторно використати партицію/порядок для кількох функцій
-- =============================================================================
SELECT id,
       status,
       total_cost,
       ROW_NUMBER() OVER w,
       PERCENT_RANK() OVER w
FROM work_orders
WHERE id BETWEEN 1 AND 4000
WINDOW w AS (PARTITION BY status ORDER BY total_cost DESC, id)
LIMIT 30;
