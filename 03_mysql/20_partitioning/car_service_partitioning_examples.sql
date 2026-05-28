-- Table partitioning in MySQL — RANGE lab on car_service_db
-- MySQL 8.0+ recommended. Run:
--   mysql -u root car_service_db < 03_mysql/20_partitioning/car_service_partitioning_examples.sql

USE car_service_db;

DROP TABLE IF EXISTS part_wo_lab;

-- =============================================================================
-- 1) RANGE partitioning by work_order id bands (partition pruning demo)
-- =============================================================================
CREATE TABLE part_wo_lab (
  id         INT NOT NULL,
  status     VARCHAR(20) NOT NULL,
  total_cost DECIMAL(10, 2) NOT NULL,
  PRIMARY KEY (id, status)
) ENGINE=InnoDB
PARTITION BY RANGE (id) (
  PARTITION p_low    VALUES LESS THAN (10001),
  PARTITION p_mid    VALUES LESS THAN (20001),
  PARTITION p_high   VALUES LESS THAN (30001),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

INSERT INTO part_wo_lab (id, status, total_cost)
SELECT wo.id, wo.status, wo.total_cost
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 25000;

SELECT COUNT(*) AS total_rows FROM part_wo_lab;

-- =============================================================================
-- 2) List partitions touched — EXPLAIN shows partitions (pruning)
-- =============================================================================
EXPLAIN
SELECT id, status, total_cost
FROM part_wo_lab
WHERE id BETWEEN 15000 AND 15010;

EXPLAIN
SELECT id, status, total_cost
FROM part_wo_lab
WHERE id BETWEEN 500 AND 510;

-- =============================================================================
-- 3) Inspect partition metadata
-- =============================================================================
SELECT partition_name,
       table_rows,
       partition_description
FROM information_schema.partitions
WHERE table_schema = 'car_service_db'
  AND table_name = 'part_wo_lab'
  AND partition_name IS NOT NULL
ORDER BY partition_ordinal_position;

-- =============================================================================
-- 4) Aggregate within one partition only (pruned scan)
-- =============================================================================
SELECT status,
       COUNT(*) AS cnt,
       ROUND(SUM(total_cost), 2) AS revenue
FROM part_wo_lab
WHERE id BETWEEN 10000 AND 19999
GROUP BY status
ORDER BY revenue DESC;
