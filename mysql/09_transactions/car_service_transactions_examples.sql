-- Transactions — explicit BEGIN / COMMIT / ROLLBACK / SAVEPOINT on car_service_db
-- Lab table only: tx_lab (dropped and recreated each run)
-- Run entire file in ONE mysql session: mysql ... car_service_db < 09_transactions/car_service_transactions_examples.sql

USE car_service_db;

DROP TABLE IF EXISTS tx_lab;

CREATE TABLE tx_lab (
  id       INT NOT NULL AUTO_INCREMENT,
  name     VARCHAR(80) NOT NULL,
  balance  DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO tx_lab (name, balance) VALUES
  ('North Bay Workshop', 1000.00),
  ('South Bay Workshop',  500.00);

-- -----------------------------------------------------------------------------
-- Autocommit (default ON: each standalone statement auto-commits when it ends)
-- -----------------------------------------------------------------------------
SELECT "autocommit" AS metric, @@session.autocommit AS value
UNION ALL
SELECT "tx_lab_rows" AS metric, COUNT(*) AS value FROM tx_lab;

-- -----------------------------------------------------------------------------
-- 1) Add an explicit transaction, then REMOVE it with ROLLBACK (discard changes)
-- -----------------------------------------------------------------------------
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 200.00 WHERE id = 1;
UPDATE tx_lab SET balance = balance + 200.00 WHERE id = 2;

SELECT 'inside transaction before rollback' AS phase, id, name, balance FROM tx_lab ORDER BY id;

ROLLBACK;

SELECT 'after ROLLBACK (back to seed balances)' AS phase, id, name, balance FROM tx_lab ORDER BY id;

-- -----------------------------------------------------------------------------
-- 2) Add a transaction, then end it with COMMIT (keep changes)
-- -----------------------------------------------------------------------------
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 150.00 WHERE id = 1;
UPDATE tx_lab SET balance = balance + 150.00 WHERE id = 2;

COMMIT;

SELECT 'after COMMIT (transfer persisted)' AS phase, id, name, balance FROM tx_lab ORDER BY id;

-- -----------------------------------------------------------------------------
-- 3) SAVEPOINT — roll back only part of the work, then COMMIT the rest
-- -----------------------------------------------------------------------------
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 50.00 WHERE id = 1;

SAVEPOINT after_debit;

UPDATE tx_lab SET balance = balance + 50.00 WHERE id = 2;

-- Undo only the credit to workshop 2; debit to workshop 1 stays for now
ROLLBACK TO SAVEPOINT after_debit;

SELECT 'after ROLLBACK TO SAVEPOINT (workshop2 credit undone)' AS phase, id, name, balance FROM tx_lab ORDER BY id;

-- Re-apply credit and finish
UPDATE tx_lab SET balance = balance + 50.00 WHERE id = 2;

RELEASE SAVEPOINT after_debit;

COMMIT;

SELECT 'after COMMIT following savepoint demo' AS phase, id, name, balance FROM tx_lab ORDER BY id;

-- -----------------------------------------------------------------------------
-- 4) Optional: turn autocommit OFF — multiple statements = one transaction until COMMIT
--    (Uncomment only if you understand session-wide effects.)
-- -----------------------------------------------------------------------------
-- SET SESSION autocommit = 0;
-- UPDATE tx_lab SET balance = balance - 10 WHERE id = 1;
-- UPDATE tx_lab SET balance = balance + 10 WHERE id = 2;
-- COMMIT;
-- SET SESSION autocommit = 1;

-- -----------------------------------------------------------------------------
-- Cleanup — uncomment to remove lab table
-- -----------------------------------------------------------------------------
-- DROP TABLE IF EXISTS tx_lab;
