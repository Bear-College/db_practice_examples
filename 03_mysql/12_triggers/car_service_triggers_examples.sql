-- Triggers — lab tables tri_lab_account, tri_lab_audit in car_service_db
-- MySQL 5.7+ / 8.x. Run with mysql client (DELIMITER is client-side).
--   mysql ... car_service_db < 12_triggers/car_service_triggers_examples.sql

USE car_service_db;

-- Dropping the table removes its triggers (no separate DROP TRIGGER needed on first run)
DROP TABLE IF EXISTS tri_lab_audit;
DROP TABLE IF EXISTS tri_lab_account;

CREATE TABLE tri_lab_account (
  id       INT NOT NULL AUTO_INCREMENT,
  label    VARCHAR(80) NOT NULL,
  balance  DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE tri_lab_audit (
  id         INT NOT NULL AUTO_INCREMENT,
  event      VARCHAR(20) NOT NULL,
  account_id INT DEFAULT NULL,
  old_val    VARCHAR(200) DEFAULT NULL,
  new_val    VARCHAR(200) DEFAULT NULL,
  msg        VARCHAR(300) DEFAULT NULL,
  ts         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DELIMITER $$

-- BEFORE INSERT: reject negative balance
CREATE TRIGGER tri_lab_account_bi_check
BEFORE INSERT ON tri_lab_account
FOR EACH ROW
BEGIN
  IF NEW.balance < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'tri_lab_account: balance cannot be negative';
  END IF;
END$$

-- AFTER INSERT: audit row
CREATE TRIGGER tri_lab_account_ai_log
AFTER INSERT ON tri_lab_account
FOR EACH ROW
BEGIN
  INSERT INTO tri_lab_audit (event, account_id, new_val, msg)
  VALUES ('INSERT', NEW.id, CAST(NEW.balance AS CHAR), CONCAT('created: ', NEW.label));
END$$

-- BEFORE UPDATE: reject negative new balance
CREATE TRIGGER tri_lab_account_bu_check
BEFORE UPDATE ON tri_lab_account
FOR EACH ROW
BEGIN
  IF NEW.balance < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'tri_lab_account: balance cannot be negative after update';
  END IF;
END$$

-- AFTER UPDATE: audit OLD vs NEW balance
CREATE TRIGGER tri_lab_account_au_log
AFTER UPDATE ON tri_lab_account
FOR EACH ROW
BEGIN
  INSERT INTO tri_lab_audit (event, account_id, old_val, new_val, msg)
  VALUES (
    'UPDATE',
    NEW.id,
    CAST(OLD.balance AS CHAR),
    CAST(NEW.balance AS CHAR),
    CONCAT('label was: ', OLD.label, ' -> ', NEW.label)
  );
END$$

-- AFTER DELETE: audit removal
CREATE TRIGGER tri_lab_account_ad_log
AFTER DELETE ON tri_lab_account
FOR EACH ROW
BEGIN
  INSERT INTO tri_lab_audit (event, account_id, old_val, msg)
  VALUES ('DELETE', OLD.id, CAST(OLD.balance AS CHAR), CONCAT('removed: ', OLD.label));
END$$

DELIMITER ;

-- -----------------------------------------------------------------------------
-- Exercise data: INSERT / UPDATE / DELETE (triggers fire)
-- -----------------------------------------------------------------------------
INSERT INTO tri_lab_account (label, balance) VALUES
  ('Parts petty cash', 250.00),
  ('Tooling budget', 1200.50);

UPDATE tri_lab_account
SET balance = balance - 50.00,
    label = 'Parts petty cash (adjusted)'
WHERE id = 1;

DELETE FROM tri_lab_account WHERE id = 2;

SELECT id, event, account_id, old_val, new_val, msg, ts
FROM tri_lab_audit
ORDER BY id;

-- -----------------------------------------------------------------------------
-- Optional: this INSERT must FAIL with SIGNAL (uncomment to test)
-- -----------------------------------------------------------------------------
-- INSERT INTO tri_lab_account (label, balance) VALUES ('Bad row', -10.00);

-- -----------------------------------------------------------------------------
-- Optional cleanup — drops triggers with tables
-- -----------------------------------------------------------------------------
-- DROP TABLE IF EXISTS tri_lab_audit;
-- DROP TABLE IF EXISTS tri_lab_account;
