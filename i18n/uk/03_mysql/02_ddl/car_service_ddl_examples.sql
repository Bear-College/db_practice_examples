-- DDL — тема car_service_db, пісочниця `ddl_practice`
-- Джерело предметної області: ../../01_database_mysql/car_service_db.sql.gz (з кореня репозиторію: database/…)
-- Використання: mysql -u... -p... < car_service_ddl_examples.sql
-- Рекомендовано MySQL 8.0.16+ (для CHECK-обмежень). MySQL 9.x — OK.

-- Вправа 1 — створити навчальну базу даних
CREATE DATABASE IF NOT EXISTS ddl_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE ddl_practice;

-- Прибрати попередні демо-об'єкти (дочірні — спершу)
SET foreign_key_checks = 0;
DROP VIEW IF EXISTS v_demo_supplier_orders;
DROP TABLE IF EXISTS demo_po_lines;
DROP TABLE IF EXISTS demo_purchase_orders;
DROP TABLE IF EXISTS demo_catalog_parts;
DROP TABLE IF EXISTS demo_parts;
DROP TABLE IF EXISTS demo_scratch_log;
DROP TABLE IF EXISTS demo_suppliers;
SET foreign_key_checks = 1;

-- Вправа 2 — CREATE TABLE + сурогатний ключ (на зразок suppliers)
CREATE TABLE demo_suppliers (
  id            INT NOT NULL AUTO_INCREMENT,
  name          VARCHAR(100) NOT NULL,
  phone         VARCHAR(20) DEFAULT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Вправа 3 — дочірня таблиця + FK (на зразок purchase_orders -> suppliers)
CREATE TABLE demo_purchase_orders (
  id            INT NOT NULL AUTO_INCREMENT,
  supplier_id   INT NOT NULL,
  order_date    DATE NOT NULL,
  PRIMARY KEY (id),
  KEY idx_demo_po_supplier (supplier_id),
  KEY idx_demo_po_order_date (order_date),
  CONSTRAINT fk_demo_po_supplier
    FOREIGN KEY (supplier_id) REFERENCES demo_suppliers (id)
      ON UPDATE CASCADE
      ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Вправа 4 — UNIQUE sku (на зразок parts.sku)
CREATE TABLE demo_parts (
  id            INT NOT NULL AUTO_INCREMENT,
  sku           VARCHAR(50) NOT NULL,
  name          VARCHAR(200) NOT NULL,
  brand         VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_demo_parts_sku (sku)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Вправа 5 — DEFAULT / NOT NULL (прапорці та мітки часу)
CREATE TABLE demo_po_lines (
  id            INT NOT NULL AUTO_INCREMENT,
  po_id         INT NOT NULL,
  part_id       INT NOT NULL,
  quantity      INT NOT NULL,
  unit_price    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  is_taxable    TINYINT(1) NOT NULL DEFAULT 1,
  inserted_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_demo_po_lines_po (po_id),
  KEY idx_demo_po_lines_part (part_id),
  CONSTRAINT fk_demo_line_po
    FOREIGN KEY (po_id) REFERENCES demo_purchase_orders (id)
      ON UPDATE CASCADE
      ON DELETE CASCADE,
  CONSTRAINT fk_demo_line_part
    FOREIGN KEY (part_id) REFERENCES demo_parts (id)
      ON UPDATE CASCADE
      ON DELETE RESTRICT,
  -- Вправа 6 — CHECK (MySQL 8.0.16+)
  CONSTRAINT chk_demo_po_lines_qty CHECK (quantity > 0),
  CONSTRAINT chk_demo_po_lines_price CHECK (unit_price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Засіяти мінімальні рядки, щоб FK і подання мали що показати (необов'язкова ілюстрація)
INSERT INTO demo_suppliers (name, phone) VALUES ('Demo Parts Wholesale', '555-0100');
INSERT INTO demo_purchase_orders (supplier_id, order_date) VALUES (1, '2026-01-15');
INSERT INTO demo_parts (sku, name, brand) VALUES ('DEMO-OIL-5W30', 'Synthetic 5W-30', 'DemoLub');
INSERT INTO demo_po_lines (po_id, part_id, quantity, unit_price) VALUES (1, 1, 12, 9.99);

-- Вправа 7 — вторинний індекс через ALTER (префіксний індекс на VARCHAR; доповнює індекс на order_date зі стадії створення)
ALTER TABLE demo_suppliers ADD INDEX idx_demo_supplier_name (name(20));

-- Вправа 8 — ADD COLUMN
ALTER TABLE demo_suppliers
  ADD COLUMN notes TEXT NULL AFTER phone;

-- Вправа 9 — MODIFY COLUMN
ALTER TABLE demo_suppliers
  MODIFY COLUMN phone VARCHAR(32) NULL;

-- Вправа 10 — DROP COLUMN (видалити notes, доданий у вправі 8)
ALTER TABLE demo_suppliers
  DROP COLUMN notes;

-- Вправа 11 — RENAME TABLE (перейменувати demo_parts -> demo_catalog_parts)
RENAME TABLE demo_parts TO demo_catalog_parts;

-- Виправлення FK з demo_po_lines: він посилався на demo_parts — InnoDB перейменовує таблицю; імена обмежень залишаються валідними.
-- Перевірка: SHOW CREATE TABLE demo_po_lines\G

-- Вправа 13 — CREATE VIEW (шаблон з'єднання, як для звіту по постачальниках + PO)
CREATE OR REPLACE VIEW v_demo_supplier_orders AS
SELECT s.id   AS supplier_id,
       s.name AS supplier_name,
       po.id  AS purchase_order_id,
       po.order_date
FROM demo_suppliers AS s
LEFT JOIN demo_purchase_orders AS po ON po.supplier_id = s.id;

-- Вправа 14 — TRUNCATE: безпечно лише за відсутності зовнішніх посилань або після видалення дочірніх.
-- Тут очищуємо допоміжну таблицю без залежних:
CREATE TABLE IF NOT EXISTS demo_scratch_log (
  id INT NOT NULL AUTO_INCREMENT,
  message VARCHAR(200) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO demo_scratch_log (message) VALUES ('before truncate');
TRUNCATE TABLE demo_scratch_log;

-- Вправа 12 — DROP у безпечному порядку (увімкніть як навчальний блок: розкоментуйте, щоб стерти demo)
-- SET foreign_key_checks = 0;
-- DROP TABLE IF EXISTS demo_po_lines;
-- DROP TABLE IF EXISTS demo_purchase_orders;
-- DROP VIEW IF EXISTS v_demo_supplier_orders;
-- DROP TABLE IF EXISTS demo_catalog_parts;
-- DROP TABLE IF EXISTS demo_scratch_log;
-- DROP TABLE IF EXISTS demo_suppliers;
-- SET foreign_key_checks = 1;
-- DROP DATABASE IF EXISTS ddl_practice;
