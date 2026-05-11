-- Тригери — лабораторні таблиці tri_lab_account, tri_lab_audit у car_service_db
-- MySQL 5.7+ / 8.x. Запускайте через клієнт mysql (DELIMITER — клієнтська директива).
--   mysql ... car_service_db < 12_triggers/car_service_triggers_examples.sql

USE car_service_db;

-- Видалення таблиці прибирає її тригери (окремий DROP TRIGGER при першому запуску не потрібен)
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

-- BEFORE INSERT: відкинути від'ємний баланс
CREATE TRIGGER tri_lab_account_bi_check
BEFORE INSERT ON tri_lab_account
FOR EACH ROW
BEGIN
  IF NEW.balance < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'tri_lab_account: balance cannot be negative';
  END IF;
END$$

-- AFTER INSERT: рядок аудиту
CREATE TRIGGER tri_lab_account_ai_log
AFTER INSERT ON tri_lab_account
FOR EACH ROW
BEGIN
  INSERT INTO tri_lab_audit (event, account_id, new_val, msg)
  VALUES ('INSERT', NEW.id, CAST(NEW.balance AS CHAR), CONCAT('created: ', NEW.label));
END$$

-- BEFORE UPDATE: відкинути від'ємний новий баланс
CREATE TRIGGER tri_lab_account_bu_check
BEFORE UPDATE ON tri_lab_account
FOR EACH ROW
BEGIN
  IF NEW.balance < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'tri_lab_account: balance cannot be negative after update';
  END IF;
END$$

-- AFTER UPDATE: аудит OLD проти NEW балансу
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

-- AFTER DELETE: аудит видалення
CREATE TRIGGER tri_lab_account_ad_log
AFTER DELETE ON tri_lab_account
FOR EACH ROW
BEGIN
  INSERT INTO tri_lab_audit (event, account_id, old_val, msg)
  VALUES ('DELETE', OLD.id, CAST(OLD.balance AS CHAR), CONCAT('removed: ', OLD.label));
END$$

DELIMITER ;

-- -----------------------------------------------------------------------------
-- Демо-дані: INSERT / UPDATE / DELETE (тригери спрацьовують)
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
-- Опціонально: цей INSERT має ВПАСТИ із SIGNAL (розкоментуйте для тесту)
-- -----------------------------------------------------------------------------
-- INSERT INTO tri_lab_account (label, balance) VALUES ('Bad row', -10.00);

-- -----------------------------------------------------------------------------
-- Опціональне прибирання — видаляє тригери разом з таблицями
-- -----------------------------------------------------------------------------
-- DROP TABLE IF EXISTS tri_lab_audit;
-- DROP TABLE IF EXISTS tri_lab_account;
