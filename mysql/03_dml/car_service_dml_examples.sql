-- DML — car_service_db theme, sandbox database `dml_practice`
-- Source domain: ../../database/car_service_db.sql.gz (from repo root: database/…)
-- Usage: mysql -u... -p... < car_service_dml_examples.sql
-- MySQL 8 / 9 OK. Re-run safe: drops and recreates demo objects.

-- Exercise 1 — sandbox + minimal tables (DDL only to support DML labs)
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

-- Seed baseline rows (ids 1..3 customers, work orders attached)
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

-- Exercise 2 — INSERT single row
INSERT INTO dml_demo_customers (first_name, last_name, email, points)
VALUES ('Dmitri', 'Volkov', 'dmitri.volkov@example.com', 25);

-- Exercise 3 — INSERT multiple rows
INSERT INTO dml_demo_customers (first_name, last_name, email, points) VALUES
  ('Elena', 'Park', 'elena.park@example.com', 10),
  ('Felix', 'Brown', 'felix.brown@example.com', 10);

INSERT INTO dml_demo_work_orders (customer_id, status, total_cost)
SELECT id, 'new', 40.00
FROM dml_demo_customers
WHERE email = 'elena.park@example.com'
LIMIT 1;

-- Exercise 4 — UPDATE with WHERE (loyalty points — loyalty_cards theme)
UPDATE dml_demo_customers
SET points = points + 50
WHERE email = 'cara.nguyen@example.com';

-- Exercise 5 — UPDATE several columns (work_orders theme)
UPDATE dml_demo_work_orders
SET status = 'completed',
    total_cost = 199.99
WHERE id = 3 AND customer_id = 2;

-- Exercise 6 — DELETE with WHERE
DELETE FROM dml_demo_work_orders
WHERE status = 'cancelled';

-- Exercise 7 — INSERT ... SELECT (staging / ETL)
INSERT INTO dml_demo_customer_staging (first_name, last_name, email, points)
SELECT first_name, last_name, email, points
FROM dml_demo_customers
WHERE points >= 50;

-- Exercise 8 — INSERT ... ON DUPLICATE KEY UPDATE (upsert on unique email)
INSERT INTO dml_demo_customers (first_name, last_name, email, points)
VALUES ('Ada', 'Morgan-Smith', 'ada.morgan@example.com', 999)
ON DUPLICATE KEY UPDATE
  points = points + 25,
  last_name = VALUES(last_name);

-- Exercise 9 — REPLACE INTO (full row replace by primary key — new PK via NULL auto-increment avoided; replace by unique email needs delete+insert semantics on unique)
-- Replace work order id 1 entirely (same PK):
REPLACE INTO dml_demo_work_orders (id, customer_id, status, total_cost)
VALUES (1, 1, 'in_progress', 130.50);

-- Exercise 10 — transaction + ROLLBACK
START TRANSACTION;
UPDATE dml_demo_customers SET points = points - 1000 WHERE email = 'ben.ortega@example.com';
-- Intentionally bad change; undo
ROLLBACK;

-- Exercise 11 — transaction + COMMIT
START TRANSACTION;
UPDATE dml_demo_customers SET points = points + 5 WHERE email = 'felix.brown@example.com';
COMMIT;

-- Exercise 12 — DELETE with join pattern (remove work orders for customers below points threshold)
DELETE wo
FROM dml_demo_work_orders AS wo
INNER JOIN dml_demo_customers AS c ON c.id = wo.customer_id
WHERE c.points < 15
  AND wo.status IN ('new', 'waiting_parts');

-- Exercise 13 — UPDATE with join pattern (apply discount to cost for high-point customers)
UPDATE dml_demo_work_orders AS wo
INNER JOIN dml_demo_customers AS c ON c.id = wo.customer_id
SET wo.total_cost = ROUND(wo.total_cost * 0.95, 2)
WHERE c.points >= 100
  AND wo.status NOT IN ('cancelled');

-- Exercise 14 — UPDATE with CASE (adjust costs by status bucket)
UPDATE dml_demo_work_orders
SET total_cost = CASE status
  WHEN 'new' THEN ROUND(total_cost + 25, 2)
  WHEN 'in_progress' THEN ROUND(total_cost + 15, 2)
  WHEN 'completed' THEN total_cost
  WHEN 'waiting_parts' THEN ROUND(total_cost + 10, 2)
  ELSE total_cost
END
WHERE status IS NOT NULL;

-- Inspect results (DQL — for manual verification)
-- SELECT 'customers' AS tbl, COUNT(*) AS n FROM dml_demo_customers
-- UNION ALL SELECT 'work_orders', COUNT(*) FROM dml_demo_work_orders
-- UNION ALL SELECT 'staging', COUNT(*) FROM dml_demo_customer_staging;
