-- Рівні ізоляції транзакцій — InnoDB на car_service_db
-- Лабораторна таблиця: iso_lab (видаляється і створюється заново при кожному запуску)
--
-- Частина A запускається в ОДНІЙ сесії mysql: mysql ... car_service_db < 09_transactions/car_service_isolation_levels_examples.sql
-- Частина B закоментована: дотримуйтесь нумерації кроків у двох терміналах, щоб побачити ефекти, які потребують конкуренції.
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
-- Частина A — Перевірити значення за замовчуванням; задати кожен рівень; безпечні демо в одній сесії
-- =============================================================================

-- За замовчуванням MySQL 8 InnoDB для нових сесій — зазвичай REPEATABLE READ.
SELECT
  @@global.transaction_isolation  AS global_isolation,
  @@session.transaction_isolation AS session_isolation;

-- -----------------------------------------------------------------------------
-- REPEATABLE READ (за замовчуванням у InnoDB): узгоджені читання використовують
-- знімок, зроблений під час першого доступу в транзакції. Інший рядок може змінитися;
-- рядок, який ви вже «бачили», лишається узгодженим для звичайного SELECT у тій самій транзакції.
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
-- READ COMMITTED: кожна інструкція бачить лише дані, зафіксовані до її завершення.
-- (Відмінності з RR проявляються, коли інша сесія фіксує зміни між вашими SELECT —
-- див. Частину B нижче.)
-- -----------------------------------------------------------------------------
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

START TRANSACTION;

SELECT 'RC: read in txn' AS phase, id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

COMMIT;

-- -----------------------------------------------------------------------------
-- READ UNCOMMITTED: SELECT може бачити незафіксовані зміни інших сесій
-- («брудні читання»). InnoDB усе одно на практиці уникає брудних читань для звичайного
-- SELECT у багатьох випадках. Демо у двох сесіях нижче показує явну поведінку. Віддавайте перевагу RC+.
-- -----------------------------------------------------------------------------
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

START TRANSACTION;

SELECT 'RU: read (level set; use Part B for dirty-read experiment)' AS phase,
       id, part_code, stock_qty FROM iso_lab ORDER BY id;

COMMIT;

-- -----------------------------------------------------------------------------
-- SERIALIZABLE: InnoDB трактує звичайний SELECT як LOCK IN SHARE MODE щодо блокувань,
-- і додає gap-блокування, тому фантоми блокуються (на відміну від нижчих рівнів).
-- Вища конкуренція за блокування; використовуйте, коли потрібна строга серіалізовність.
-- -----------------------------------------------------------------------------
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;

START TRANSACTION;

SELECT 'SER: locked consistent read' AS phase, id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

COMMIT;

-- Відновити типове значення сесії для всього, що виконуєте далі.
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- =============================================================================
-- Частина B — Два клієнти mysql (дві сесії). Виконуйте інструкції по порядку.
-- НЕ запускайте цей блок як один файл у Частині B; відкрийте два термінали.
-- =============================================================================
--
-- --- B1) READ UNCOMMITTED (підручниковий «брудний» приклад — нюанс InnoDB)
--         InnoDB уникає незафіксованих версій рядків для звичайного SELECT навіть тоді,
--         коли сесія в READ UNCOMMITTED, тож часто ВИ НЕ побачите брудне читання.
--         Рівень все одно впливає на поведінку блокувань для locking-читань.
--         Для чітких, відтворюваних відмінностей на MySQL/InnoDB використовуйте B2–B4.
--
-- Термінал 1                          Термінал 2
-- SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- START TRANSACTION;                 SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- UPDATE iso_lab                     START TRANSACTION;
-- SET stock_qty = 999                SELECT stock_qty FROM iso_lab WHERE id = 1;
-- WHERE id = 1;                      -- Часто все одно стара зафіксована величина (InnoDB).
-- ROLLBACK;
--                                     ROLLBACK;
--
-- --- B2) Неповторне читання (READ COMMITTED)
--
-- Термінал 1                          Термінал 2
-- SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- START TRANSACTION;                 UPDATE iso_lab SET stock_qty = stock_qty - 1 WHERE id = 1;
-- SELECT stock_qty FROM iso_lab      COMMIT;
-- WHERE id = 1;  -- зафіксувати значення
-- -- той самий запит ще раз:
-- SELECT stock_qty FROM iso_lab
-- WHERE id = 1;  -- може змінитися після того, як T2 зафіксувалася (неповторне).
-- COMMIT;
--
-- --- B3) Повторне читання того самого рядка (REPEATABLE READ)
--
-- Термінал 1                          Термінал 2
-- SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- START TRANSACTION;                 UPDATE iso_lab SET stock_qty = stock_qty - 5 WHERE id = 1;
-- SELECT stock_qty FROM iso_lab      COMMIT;
-- WHERE id = 1;
-- SELECT stock_qty FROM iso_lab
-- WHERE id = 1;  -- те саме, що при першому читанні, поки транзакція T1 відкрита (знімок).
-- COMMIT;
--
-- --- B4) Фантомне читання у діапазоні (порівняйте RC і RR з другим INSERT)
--
-- За потреби засійте повторно, потім:
--
-- Термінал 1 (READ COMMITTED)         Термінал 2
-- SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- START TRANSACTION;                 INSERT INTO iso_lab (part_code, stock_qty)
-- SELECT COUNT(*) FROM iso_lab       VALUES ('NEW-PART', 1);
-- WHERE part_code LIKE 'OIL%';       COMMIT;
-- -- виконати COUNT ще раз:
-- SELECT COUNT(*) FROM iso_lab
-- WHERE part_code LIKE 'OIL%';      -- кількість може зрости (фантом / новий рядок видно).
-- COMMIT;
--
-- Термінал 1 (REPEATABLE READ)        Термінал 2
-- SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- START TRANSACTION;                 INSERT INTO iso_lab (part_code, stock_qty)
-- SELECT COUNT(*) FROM iso_lab       VALUES ('NEW-PART-2', 2);
-- WHERE part_code LIKE 'BRK%';        COMMIT;
-- SELECT COUNT(*) FROM iso_lab
-- WHERE part_code LIKE 'BRK%';       -- те саме, що в першому знімку цієї транзакції (новий рядок не видно).
-- COMMIT;
--
-- =============================================================================
-- Прибирання — розкоментуйте, щоб видалити лабораторну таблицю
-- =============================================================================
-- DROP TABLE IF EXISTS iso_lab;
