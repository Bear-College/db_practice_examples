-- Window functions — MySQL 8.0+ on car_service_db
-- Load: gunzip -c database/car_service_db.sql.gz | mysql ... car_service_db
-- Run:  mysql ... car_service_db < 10_windows_functions/car_service_windows_functions_examples.sql

USE car_service_db;

-- =============================================================================
-- W1 — ROW_NUMBER: unique sequence within each work_orders.status (slice)
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
-- W2 — RANK vs DENSE_RANK (ties get same rank; DENSE_RANK leaves no gaps)
-- =============================================================================
SELECT id,
       mechanic_id,
       total_cost,
       RANK() OVER (
         PARTITION BY mechanic_id
         ORDER BY total_cost DESC
       ) AS rnk,
       DENSE_RANK() OVER (
         PARTITION BY mechanic_id
         ORDER BY total_cost DESC
       ) AS dense_rnk
FROM work_orders
WHERE id BETWEEN 1 AND 8000
  AND mechanic_id IS NOT NULL
LIMIT 35;

-- =============================================================================
-- W3 — SUM / AVG as window aggregates over a partition (rows not collapsed)
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
-- W4 — “Running” sum within partition (ORDER BY in OVER)
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
-- W5 — LAG / LEAD: previous & next order cost for same mechanic (by id order)
-- =============================================================================
SELECT id,
       mechanic_id,
       total_cost,
       LAG(total_cost, 1) OVER (
         PARTITION BY mechanic_id
         ORDER BY id
       ) AS prev_cost,
       LEAD(total_cost, 1) OVER (
         PARTITION BY mechanic_id
         ORDER BY id
       ) AS next_cost
FROM work_orders
WHERE id BETWEEN 1 AND 12000
  AND mechanic_id IS NOT NULL
LIMIT 35;

-- =============================================================================
-- W6 — NTILE: split each status group into 4 buckets (within slice)
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
-- W7 — FIRST_VALUE / LAST_VALUE (explicit frame so LAST_VALUE = last row of partition)
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
-- W8 — Named WINDOW clause: reuse partition/order for several functions
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
