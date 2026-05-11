-- Транзакції — явні BEGIN / COMMIT / ROLLBACK / SAVEPOINT на car_service_db
-- Лише лабораторна таблиця: tx_lab (видаляється і створюється заново при кожному запуску)
-- Запускайте весь файл в ОДНІЙ сесії mysql: mysql ... car_service_db < 09_transactions/car_service_transactions_examples.sql

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
-- Autocommit (за замовчуванням УВІМКНЕНО: кожна окрема інструкція автоматично фіксується по завершенні)
-- -----------------------------------------------------------------------------
SELECT "autocommit" AS metric, @@session.autocommit AS value
UNION ALL
SELECT "tx_lab_rows" AS metric, COUNT(*) AS value FROM tx_lab;

-- -----------------------------------------------------------------------------
-- 1) Додати явну транзакцію, а потім СКАСУВАТИ її через ROLLBACK (відкинути зміни)
-- -----------------------------------------------------------------------------
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 200.00 WHERE id = 1;
UPDATE tx_lab SET balance = balance + 200.00 WHERE id = 2;

SELECT 'inside transaction before rollback' AS phase, id, name, balance FROM tx_lab ORDER BY id;

ROLLBACK;

SELECT 'after ROLLBACK (back to seed balances)' AS phase, id, name, balance FROM tx_lab ORDER BY id;

-- -----------------------------------------------------------------------------
-- 2) Додати транзакцію, потім завершити її через COMMIT (зберегти зміни)
-- -----------------------------------------------------------------------------
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 150.00 WHERE id = 1;
UPDATE tx_lab SET balance = balance + 150.00 WHERE id = 2;

COMMIT;

SELECT 'after COMMIT (transfer persisted)' AS phase, id, name, balance FROM tx_lab ORDER BY id;

-- -----------------------------------------------------------------------------
-- 3) SAVEPOINT — скасувати лише частину роботи, потім зафіксувати решту через COMMIT
-- -----------------------------------------------------------------------------
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 50.00 WHERE id = 1;

SAVEPOINT after_debit;

UPDATE tx_lab SET balance = balance + 50.00 WHERE id = 2;

-- Скасувати лише зарахування майстерні 2; списання з майстерні 1 поки що залишається
ROLLBACK TO SAVEPOINT after_debit;

SELECT 'after ROLLBACK TO SAVEPOINT (workshop2 credit undone)' AS phase, id, name, balance FROM tx_lab ORDER BY id;

-- Повторити зарахування і завершити
UPDATE tx_lab SET balance = balance + 50.00 WHERE id = 2;

RELEASE SAVEPOINT after_debit;

COMMIT;

SELECT 'after COMMIT following savepoint demo' AS phase, id, name, balance FROM tx_lab ORDER BY id;

-- -----------------------------------------------------------------------------
-- 4) Опціонально: вимкнути autocommit — кілька інструкцій = одна транзакція до COMMIT
--    (Розкоментуйте лише якщо розумієте вплив на цілу сесію.)
-- -----------------------------------------------------------------------------
-- SET SESSION autocommit = 0;
-- UPDATE tx_lab SET balance = balance - 10 WHERE id = 1;
-- UPDATE tx_lab SET balance = balance + 10 WHERE id = 2;
-- COMMIT;
-- SET SESSION autocommit = 1;

-- -----------------------------------------------------------------------------
-- Прибирання — розкоментуйте, щоб видалити лабораторну таблицю
-- -----------------------------------------------------------------------------
-- DROP TABLE IF EXISTS tx_lab;
