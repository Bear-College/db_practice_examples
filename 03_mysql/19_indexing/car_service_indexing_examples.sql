-- Indexing in relational databases — design & covering indexes (complements 08_indexes lab)
-- Run: mysql -u root car_service_db < 03_mysql/19_indexing/car_service_indexing_examples.sql

USE car_service_db;

DROP TABLE IF EXISTS idx_design_lab;

CREATE TABLE idx_design_lab (
  id         INT NOT NULL AUTO_INCREMENT,
  status     VARCHAR(20) NOT NULL,
  ref_num    INT NOT NULL,
  sku        VARCHAR(80) NOT NULL,
  total_cost DECIMAL(10, 2) NOT NULL,
  PRIMARY KEY (id),
  KEY ix_status (status),
  KEY ix_ref (ref_num)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO idx_design_lab (status, ref_num, sku, total_cost)
SELECT 'open',
       p.id,
       p.sku,
       ROUND(100 + (p.id MOD 500) * 0.5, 2)
FROM parts AS p
WHERE p.id BETWEEN 1 AND 20000;

-- =============================================================================
-- 1) Inspect cardinality and index usage (information_schema)
-- =============================================================================
SHOW INDEX FROM idx_design_lab;

SELECT index_name,
       column_name,
       cardinality,
       seq_in_index
FROM information_schema.statistics
WHERE table_schema = 'car_service_db'
  AND table_name = 'idx_design_lab'
ORDER BY index_name, seq_in_index;

-- =============================================================================
-- 2) Composite index — left-prefix rule (status alone uses composite)
-- =============================================================================
CREATE INDEX ix_status_ref_cost ON idx_design_lab (status, ref_num, total_cost);

EXPLAIN
SELECT status, ref_num, total_cost
FROM idx_design_lab
WHERE status = 'open'
  AND ref_num BETWEEN 5000 AND 5010;

-- =============================================================================
-- 3) Covering index — all selected columns in the index (Extra: Using index)
-- =============================================================================
EXPLAIN
SELECT ref_num, total_cost
FROM idx_design_lab
WHERE status = 'open'
  AND ref_num BETWEEN 5000 AND 5010;

-- =============================================================================
-- 4) When a secondary index is ignored — low selectivity on status alone
-- =============================================================================
EXPLAIN
SELECT id, sku
FROM idx_design_lab
WHERE status = 'open'
LIMIT 20;

ANALYZE TABLE idx_design_lab;

SELECT table_name,
       index_name,
       cardinality
FROM information_schema.statistics
WHERE table_schema = 'car_service_db'
  AND table_name = 'idx_design_lab'
  AND index_name = 'ix_status';
