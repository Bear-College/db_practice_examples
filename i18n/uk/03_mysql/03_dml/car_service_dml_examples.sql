-- DML — тема car_service_db, пісочниця `dml_practice`
-- Джерело предметної області: ../../01_database_mysql/car_service_db.sql.gz
-- Використання: mysql -u... -p... < car_service_dml_examples.sql
-- MySQL 8 / 9 — OK. Повторний запуск безпечний: видаляє і створює демо-об'єкти заново.

-- Вправа 1 — пісочниця + мінімальні таблиці (DDL лише для підтримки DML-практики)
CREATE DATABASE IF NOT EXISTS dml_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE dml_practice;

SET foreign_key_checks = 0;
DROP TABLE IF EXISTS dml_demo_work_orders;
DROP TABLE IF EXISTS dml_demo_customer_staging;
DROP TABLE IF EXISTS dml_demo_customers;
SET foreign_key_checks = 1;

CREATE TABLE dml_demo_customers (
  id            INT NOT NULL AUTO_INCREMENT,
  first_name    VARCHAR(50) NOT NULL,
  last_name     VARCHAR(50) NOT NULL,
  email         VARCHAR(100) NOT NULL,
  points        INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_dml_demo_customers_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE dml_demo_work_orders (
  id            INT NOT NULL AUTO_INCREMENT,
  customer_id   INT NOT NULL,
  status        VARCHAR(20) NOT NULL,
  total_cost    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (id),
  KEY idx_dml_wo_customer (customer_id),
  CONSTRAINT fk_dml_wo_customer
    FOREIGN KEY (customer_id) REFERENCES dml_demo_customers (id)
      ON UPDATE CASCADE
      ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE dml_demo_customer_staging (
  id            INT NOT NULL AUTO_INCREMENT,
  first_name    VARCHAR(50) NOT NULL,
  last_name     VARCHAR(50) NOT NULL,
  email         VARCHAR(100) NOT NULL,
  points        INT NOT NULL DEFAULT 0,
  snapshot_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Засіяти базові рядки (id 1..3 у customers, прив'язані замовлення)
INSERT INTO dml_demo_customers (first_name, last_name, email, points) VALUES
  ('Ada', 'Morgan', 'ada.morgan@example.com', 100),
  ('Ben', 'Ortega', 'ben.ortega@example.com', 50),
  ('Cara', 'Nguyen', 'cara.nguyen@example.com', 0);

INSERT INTO dml_demo_work_orders (customer_id, status, total_cost) VALUES
  (1, 'new', 120.00),
  (1, 'completed', 450.75),
  (2, 'in_progress', 200.00),
  (2, 'cancelled', 0.00),
  (3, 'waiting_parts', 300.25);

-- Вправа 2 — INSERT одного рядка
INSERT INTO dml_demo_customers (first_name, last_name, email, points)
VALUES ('Dmitri', 'Volkov', 'dmitri.volkov@example.com', 25);

-- Вправа 3 — INSERT кількох рядків
INSERT INTO dml_demo_customers (first_name, last_name, email, points) VALUES
  ('Elena', 'Park', 'elena.park@example.com', 10),
  ('Felix', 'Brown', 'felix.brown@example.com', 10);

INSERT INTO dml_demo_work_orders (customer_id, status, total_cost)
SELECT id, 'new', 40.00
FROM dml_demo_customers
WHERE email = 'elena.park@example.com'
LIMIT 1;

-- Вправа 4 — UPDATE з WHERE (бали лояльності — тема loyalty_cards)
UPDATE dml_demo_customers
SET points = points + 50
WHERE email = 'cara.nguyen@example.com';

-- Вправа 5 — UPDATE кількох стовпців (тема work_orders)
UPDATE dml_demo_work_orders
SET status = 'completed',
    total_cost = 199.99
WHERE id = 3 AND customer_id = 2;

-- Вправа 6 — DELETE з WHERE
DELETE FROM dml_demo_work_orders
WHERE status = 'cancelled';

-- Вправа 7 — INSERT ... SELECT (staging / ETL)
INSERT INTO dml_demo_customer_staging (first_name, last_name, email, points)
SELECT first_name, last_name, email, points
FROM dml_demo_customers
WHERE points >= 50;

-- Вправа 8 — INSERT ... ON DUPLICATE KEY UPDATE (upsert за унікальним email)
INSERT INTO dml_demo_customers (first_name, last_name, email, points)
VALUES ('Ada', 'Morgan-Smith', 'ada.morgan@example.com', 999)
ON DUPLICATE KEY UPDATE
  points = points + 25,
  last_name = VALUES(last_name);

-- Вправа 9 — REPLACE INTO (повна заміна рядка за PK — нового PK через NULL/auto-increment уникаємо; заміна за унікальним email має семантику delete+insert на унікальному ключі)
-- Повністю замінити work order з id = 1 (той самий PK):
REPLACE INTO dml_demo_work_orders (id, customer_id, status, total_cost)
VALUES (1, 1, 'in_progress', 130.50);

-- Вправа 10 — транзакція + ROLLBACK
START TRANSACTION;
UPDATE dml_demo_customers SET points = points - 1000 WHERE email = 'ben.ortega@example.com';
-- Свідомо помилкова зміна; скасовуємо
ROLLBACK;

-- Вправа 11 — транзакція + COMMIT
START TRANSACTION;
UPDATE dml_demo_customers SET points = points + 5 WHERE email = 'felix.brown@example.com';
COMMIT;

-- Вправа 12 — DELETE зі з'єднанням (видалити замовлення для клієнтів із низьким балом)
DELETE wo
FROM dml_demo_work_orders AS wo
INNER JOIN dml_demo_customers AS c ON c.id = wo.customer_id
WHERE c.points < 15
  AND wo.status IN ('new', 'waiting_parts');

-- Вправа 13 — UPDATE зі з'єднанням (застосувати знижку для клієнтів з високими балами)
UPDATE dml_demo_work_orders AS wo
INNER JOIN dml_demo_customers AS c ON c.id = wo.customer_id
SET wo.total_cost = ROUND(wo.total_cost * 0.95, 2)
WHERE c.points >= 100
  AND wo.status NOT IN ('cancelled');

-- Вправа 14 — UPDATE з CASE (корекція сум за «корзинами» статусів)
UPDATE dml_demo_work_orders
SET total_cost = CASE status
  WHEN 'new' THEN ROUND(total_cost + 25, 2)
  WHEN 'in_progress' THEN ROUND(total_cost + 15, 2)
  WHEN 'completed' THEN total_cost
  WHEN 'waiting_parts' THEN ROUND(total_cost + 10, 2)
  ELSE total_cost
END
WHERE status IS NOT NULL;

-- Перегляд результатів (DQL — для ручної перевірки)
-- SELECT 'customers' AS tbl, COUNT(*) AS n FROM dml_demo_customers
-- UNION ALL SELECT 'work_orders', COUNT(*) FROM dml_demo_work_orders
-- UNION ALL SELECT 'staging', COUNT(*) FROM dml_demo_customer_staging;
