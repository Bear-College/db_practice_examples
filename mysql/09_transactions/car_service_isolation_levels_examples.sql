-- Transaction isolation levels — InnoDB on car_service_db
-- Lab table: iso_lab (dropped and recreated each run)
--
-- Part A runs in ONE mysql session:  mysql ... car_service_db < 09_transactions/car_service_isolation_levels_examples.sql
-- Part B is commented: follow step numbers in two terminals to see phenomena that need concurrency.
--
USE car_service_db;

DROP TABLE IF EXISTS iso_lab;

CREATE TABLE iso_lab (
  id         INT NOT NULL AUTO_INCREMENT,
  part_code  VARCHAR(32) NOT NULL,
  stock_qty  INT NOT NULL,
  PRIMARY KEY (id),
  KEY idx_iso_lab_part (part_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO iso_lab (part_code, stock_qty) VALUES
  ('BRK-PAD-01', 40),
  ('OIL-5W30-4L', 25),
  ('FLT-AIR-88', 12);

-- =============================================================================
-- Part A — Inspect defaults; set each level; safe one-session demos
-- =============================================================================

-- MySQL 8 InnoDB default for new sessions is usually REPEATABLE READ.
SELECT
  @@global.transaction_isolation  AS global_isolation,
  @@session.transaction_isolation AS session_isolation;

-- -----------------------------------------------------------------------------
-- REPEATABLE READ (InnoDB default): consistent reads use a snapshot taken on
-- first access in the transaction. Another row can change; a row you already
-- "saw" stays consistent for plain SELECT in the same transaction.
-- -----------------------------------------------------------------------------
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

START TRANSACTION;

SELECT 'RR: first read id=1' AS phase, id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

UPDATE iso_lab SET stock_qty = stock_qty - 3 WHERE id = 2;

SELECT 'RR: second read id=1 (same snapshot as first read in this txn)' AS phase,
       id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

COMMIT;

SELECT 'RR: after COMMIT — everyone sees committed data' AS phase,
       id, part_code, stock_qty FROM iso_lab ORDER BY id;

-- -----------------------------------------------------------------------------
-- READ COMMITTED: each statement sees only data committed before that statement
-- ends. (Differences vs RR show up when another session commits between your
-- SELECTs — see Part B below.)
-- -----------------------------------------------------------------------------
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

START TRANSACTION;

SELECT 'RC: read in txn' AS phase, id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

COMMIT;

-- -----------------------------------------------------------------------------
-- READ UNCOMMITTED: SELECT may see uncommitted changes from other sessions
-- (“dirty reads”). InnoDB still avoids dirty reads for plain SELECT in practice
-- in many cases; two-session demo below uses explicit behavior. Prefer RC+.
-- -----------------------------------------------------------------------------
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

START TRANSACTION;

SELECT 'RU: read (level set; use Part B for dirty-read experiment)' AS phase,
       id, part_code, stock_qty FROM iso_lab ORDER BY id;

COMMIT;

-- -----------------------------------------------------------------------------
-- SERIALIZABLE: InnoDB treats plain SELECT like LOCK IN SHARE MODE for locking,
-- and adds gap locks so phantoms are blocked vs lower levels. Higher lock
-- contention; use when you need strict serializability semantics.
-- -----------------------------------------------------------------------------
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;

START TRANSACTION;

SELECT 'SER: locked consistent read' AS phase, id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

COMMIT;

-- Restore a typical session default for anything else you run afterward.
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- =============================================================================
-- Part B — Two mysql clients (two sessions). Run statements in order.
-- Do NOT pipe this block as one file for Part B; open two terminals.
-- =============================================================================
--
-- --- B1) READ UNCOMMITTED (textbook “dirty read” — InnoDB caveat)
--         InnoDB avoids uncommitted row versions for normal SELECT even when the
--         session is READ UNCOMMITTED, so you often will NOT see a dirty read
--         here. The level still affects locking behavior for locking reads.
--         Prefer B2–B4 for clear, reproducible differences on MySQL/InnoDB.
--
-- Terminal 1                          Terminal 2
-- SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- START TRANSACTION;                 SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- UPDATE iso_lab                     START TRANSACTION;
-- SET stock_qty = 999                SELECT stock_qty FROM iso_lab WHERE id = 1;
-- WHERE id = 1;                      -- Often still old committed value (InnoDB).
-- ROLLBACK;
--                                     ROLLBACK;
--
-- --- B2) Non-repeatable read (READ COMMITTED)
--
-- Terminal 1                          Terminal 2
-- SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- START TRANSACTION;                 UPDATE iso_lab SET stock_qty = stock_qty - 1 WHERE id = 1;
-- SELECT stock_qty FROM iso_lab      COMMIT;
-- WHERE id = 1;  -- note value
-- -- same select again:
-- SELECT stock_qty FROM iso_lab
-- WHERE id = 1;  -- can change after T2 committed (non-repeatable).
-- COMMIT;
--
-- --- B3) Repeatable read for the same row (REPEATABLE READ)
--
-- Terminal 1                          Terminal 2
-- SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- START TRANSACTION;                 UPDATE iso_lab SET stock_qty = stock_qty - 5 WHERE id = 1;
-- SELECT stock_qty FROM iso_lab      COMMIT;
-- WHERE id = 1;
-- SELECT stock_qty FROM iso_lab
-- WHERE id = 1;  -- same as first read while T1 txn open (snapshot).
-- COMMIT;
--
-- --- B4) Phantom-style range read (compare RC vs RR with a second INSERT)
--
-- Re-seed if needed, then:
--
-- Terminal 1 (READ COMMITTED)         Terminal 2
-- SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- START TRANSACTION;                 INSERT INTO iso_lab (part_code, stock_qty)
-- SELECT COUNT(*) FROM iso_lab       VALUES ('NEW-PART', 1);
-- WHERE part_code LIKE 'OIL%';       COMMIT;
-- -- run COUNT again:
-- SELECT COUNT(*) FROM iso_lab
-- WHERE part_code LIKE 'OIL%';      -- count may increase (phantom / new row visible).
-- COMMIT;
--
-- Terminal 1 (REPEATABLE READ)        Terminal 2
-- SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- START TRANSACTION;                 INSERT INTO iso_lab (part_code, stock_qty)
-- SELECT COUNT(*) FROM iso_lab       VALUES ('NEW-PART-2', 2);
-- WHERE part_code LIKE 'BRK%';        COMMIT;
-- SELECT COUNT(*) FROM iso_lab
-- WHERE part_code LIKE 'BRK%';       -- same count as first snapshot in this txn (no new row).
-- COMMIT;
--
-- =============================================================================
-- Cleanup — uncomment to remove lab table
-- =============================================================================
-- DROP TABLE IF EXISTS iso_lab;
