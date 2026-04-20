-- Index lab for car_service_db — safe sandbox tables idx_lab, idx_geo
-- Prerequisites: load database_mysql/car_service_db.sql.gz
--   mysql ... car_service_db < 08_indexes/car_service_indexes_examples.sql
-- MySQL 8.0+ recommended (functional indexes, EXPLAIN ANALYZE).
--
-- Manual speed test: run a section, note EXPLAIN / EXPLAIN ANALYZE; CREATE INDEX; re-run;
--                  DROP INDEX ... ; re-run to compare without the index.

USE car_service_db;

-- Reset lab objects (comment out if you want to keep tables between sessions)
DROP TABLE IF EXISTS idx_geo;
DROP TABLE IF EXISTS idx_lab;

-- =============================================================================
-- Lab table: only PRIMARY KEY at first → secondary indexes added step by step
-- =============================================================================
CREATE TABLE idx_lab (
  id            INT NOT NULL AUTO_INCREMENT,
  ref_num       INT NOT NULL,
  sku           VARCHAR(80) NOT NULL,
  note          TEXT,
  status        VARCHAR(20) NOT NULL DEFAULT 'open',
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Seed from real parts (keeps realistic strings); adjust upper bound if needed
INSERT INTO idx_lab (ref_num, sku, note, status)
SELECT p.id,
       p.sku,
       p.name,
       'open'
FROM parts AS p
WHERE p.id BETWEEN 1 AND 40000;

SELECT id, ref_num FROM idx_lab WHERE id BETWEEN 1 AND 3;

-- Pick a probe value that exists (stable after seed)
SET @probe_ref := (SELECT ref_num FROM idx_lab WHERE id = 15000 LIMIT 1);
SET @probe_sku := (SELECT sku FROM idx_lab WHERE id = 15000 LIMIT 1);

-- -----------------------------------------------------------------------------
-- 1) Secondary B-tree (plain INDEX) on ref_num — compare before / after CREATE INDEX
-- -----------------------------------------------------------------------------
-- Without secondary index: expect type=ALL (full table scan) on large table
SELECT id, sku
FROM idx_lab
WHERE ref_num BETWEEN @probe_ref AND @probe_ref + 5
LIMIT 5;

-- MySQL 8.0.18+ — actual timings (comment out if unsupported)
-- EXPLAIN ANALYZE
-- SELECT id, sku FROM idx_lab WHERE ref_num = @probe_ref;

CREATE INDEX ix_bt_ref ON idx_lab (ref_num);

SELECT id, sku
FROM idx_lab
WHERE ref_num BETWEEN @probe_ref AND @probe_ref + 5
LIMIT 5;

-- To re-test *without* this index, run manually:
-- DROP INDEX ix_bt_ref ON idx_lab;

-- -----------------------------------------------------------------------------
-- 2) UNIQUE index — one row per sku (fails if duplicates exist; then use non-unique INDEX)
-- -----------------------------------------------------------------------------
CREATE UNIQUE INDEX ix_uniq_sku ON idx_lab (sku);

SELECT id, ref_num
FROM idx_lab
WHERE sku LIKE CONCAT(LEFT(@probe_sku, 3), "%")
LIMIT 5;

-- DROP INDEX ix_uniq_sku ON idx_lab;

-- -----------------------------------------------------------------------------
-- 3) Composite (multi-column) B-tree index — leading column status
-- -----------------------------------------------------------------------------
CREATE INDEX ix_comp_status_ref ON idx_lab (status, ref_num);

SELECT id, sku, ref_num
FROM idx_lab
WHERE status = 'open'
  AND ref_num BETWEEN 10000 AND 10500
LIMIT 50;

-- DROP INDEX ix_comp_status_ref ON idx_lab;

-- -----------------------------------------------------------------------------
-- 4) Prefix index — index only first 16 characters of sku (saves space vs full column)
--    (coexists with UNIQUE on full sku; optimizer picks appropriate access)
-- -----------------------------------------------------------------------------
CREATE INDEX ix_prefix_sku ON idx_lab (sku(16));

SELECT id
FROM idx_lab
WHERE id BETWEEN 1 AND 30
LIMIT 30;

-- DROP INDEX ix_prefix_sku ON idx_lab;

-- -----------------------------------------------------------------------------
-- 5) FULLTEXT index (InnoDB) — MATCH … AGAINST
-- -----------------------------------------------------------------------------
ALTER TABLE idx_lab
  ADD FULLTEXT INDEX ix_ft_note (note);

-- Use a word likely to appear in part names; tune for your data
SELECT id, sku
FROM idx_lab
WHERE note IS NOT NULL
LIMIT 20;

-- DROP INDEX ix_ft_note ON idx_lab;  -- FULLTEXT: use DROP INDEX on (note) in some versions — if fails: ALTER TABLE idx_lab DROP INDEX ix_ft_note;

-- -----------------------------------------------------------------------------
-- 6) Functional / expression index (MySQL 8.0.13+)
-- -----------------------------------------------------------------------------
CREATE INDEX ix_func_lower_sku ON idx_lab ((LOWER(sku)));

SELECT id
FROM idx_lab
WHERE LOWER(sku) LIKE CONCAT(LOWER(LEFT(@probe_sku, 3)), "%")
LIMIT 5;

-- DROP INDEX ix_func_lower_sku ON idx_lab;

-- =============================================================================
-- 7) SPATIAL index — tiny helper table (POINT + SPATIAL INDEX)
-- =============================================================================
CREATE TABLE idx_geo (
  id INT NOT NULL AUTO_INCREMENT,
  g  POINT NOT NULL SRID 4326,
  PRIMARY KEY (id),
  SPATIAL INDEX ix_spatial_g (g)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO idx_geo (g)
SELECT ST_PointFromText(
         CONCAT('POINT(', -10 + (l.id MOD 50) / 5.0, ' ', 40 + (l.id MOD 40) / 4.0, ')'),
         4326
       )
FROM idx_lab AS l
WHERE l.id <= 500;

SELECT id FROM idx_geo WHERE id BETWEEN 1 AND 3;

-- Bounding-box style filter uses spatial index when possible
SELECT id
FROM idx_geo
WHERE MBRContains(
        ST_GeomFromText('POLYGON((-20 35, 20 35, 20 55, -20 55, -20 35))', 4326),
        g
      )
LIMIT 50;

-- =============================================================================
-- Advanced (MySQL 8+) — optional: DESC / INVISIBLE index on ref_num
-- Run only after DROP INDEX ix_bt_ref … if you still have that btree index.
-- =============================================================================
-- DROP INDEX ix_bt_ref ON idx_lab;
-- CREATE INDEX ix_bt_ref_desc ON idx_lab (ref_num DESC);
-- CREATE INDEX ix_inv_ref ON idx_lab (ref_num) INVISIBLE;
-- EXPLAIN SELECT id FROM idx_lab WHERE ref_num = @probe_ref;

-- =============================================================================
-- Optional cleanup — uncomment to remove lab tables completely
-- =============================================================================
-- DROP TABLE IF EXISTS idx_geo;
-- DROP TABLE IF EXISTS idx_lab;
