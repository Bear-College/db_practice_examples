-- DDL — car_service_db theme, sandbox database `ddl_practice`
-- Source domain: ../../01_database_mysql/car_service_db.sql.gz (from repo root: database/…)
-- Usage: mysql -u... -p... < car_service_ddl_examples.sql
-- MySQL 8.0.16+ recommended (CHECK constraints). MySQL 9.x OK.

-- Exercise 1 — create practice database
CREATE DATABASE IF NOT EXISTS ddl_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE ddl_practice;

-- Tear down previous demo objects (children first)
SET foreign_key_checks = 0;
DROP VIEW IF EXISTS v_demo_supplier_orders;
DROP TABLE IF EXISTS demo_po_lines;
DROP TABLE IF EXISTS demo_purchase_orders;
DROP TABLE IF EXISTS demo_catalog_parts;
DROP TABLE IF EXISTS demo_parts;
DROP TABLE IF EXISTS demo_scratch_log;
DROP TABLE IF EXISTS demo_suppliers;
SET foreign_key_checks = 1;

-- Exercise 2 — CREATE TABLE + surrogate key (like suppliers)
CREATE TABLE demo_suppliers (
  id            INT NOT NULL AUTO_INCREMENT,
  name          VARCHAR(100) NOT NULL,
  phone         VARCHAR(20) DEFAULT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Exercise 3 — child + FK (like purchase_orders -> suppliers)
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

-- Exercise 4 — UNIQUE sku (like parts.sku)
CREATE TABLE demo_parts (
  id            INT NOT NULL AUTO_INCREMENT,
  sku           VARCHAR(50) NOT NULL,
  name          VARCHAR(200) NOT NULL,
  brand         VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_demo_parts_sku (sku)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Exercise 5 — DEFAULT / NOT NULL (flags and timestamps)
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
  -- Exercise 6 — CHECK (MySQL 8.0.16+)
  CONSTRAINT chk_demo_po_lines_qty CHECK (quantity > 0),
  CONSTRAINT chk_demo_po_lines_price CHECK (unit_price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Seed minimal rows so FKs and views have something to show (optional illustration)
INSERT INTO demo_suppliers (name, phone) VALUES ('Demo Parts Wholesale', '555-0100');
INSERT INTO demo_purchase_orders (supplier_id, order_date) VALUES (1, '2026-01-15');
INSERT INTO demo_parts (sku, name, brand) VALUES ('DEMO-OIL-5W30', 'Synthetic 5W-30', 'DemoLub');
INSERT INTO demo_po_lines (po_id, part_id, quantity, unit_price) VALUES (1, 1, 12, 9.99);

-- Exercise 7 — secondary index via ALTER (prefix index on VARCHAR; complements idx on order_date at create time)
ALTER TABLE demo_suppliers ADD INDEX idx_demo_supplier_name (name(20));

-- Exercise 8 — ADD COLUMN
ALTER TABLE demo_suppliers
  ADD COLUMN notes TEXT NULL AFTER phone;

-- Exercise 9 — MODIFY COLUMN
ALTER TABLE demo_suppliers
  MODIFY COLUMN phone VARCHAR(32) NULL;

-- Exercise 10 — DROP COLUMN (drop notes added in exercise 8)
ALTER TABLE demo_suppliers
  DROP COLUMN notes;

-- Exercise 11 — RENAME TABLE (rename demo_parts -> demo_catalog_parts)
RENAME TABLE demo_parts TO demo_catalog_parts;

-- Fix FK from demo_po_lines: it referenced demo_parts — InnoDB renames underlying table; constraint names stay valid.
-- Verify: SHOW CREATE TABLE demo_po_lines\G

-- Exercise 13 — CREATE VIEW (join pattern like reporting on suppliers + POs)
CREATE OR REPLACE VIEW v_demo_supplier_orders AS
SELECT s.id   AS supplier_id,
       s.name AS supplier_name,
       po.id  AS purchase_order_id,
       po.order_date
FROM demo_suppliers AS s
LEFT JOIN demo_purchase_orders AS po ON po.supplier_id = s.id;

-- Exercise 14 — TRUNCATE: only safe when no referencing FKs or after dropping children.
-- Here we truncate a helper table with no dependents:
CREATE TABLE IF NOT EXISTS demo_scratch_log (
  id INT NOT NULL AUTO_INCREMENT,
  message VARCHAR(200) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO demo_scratch_log (message) VALUES ('before truncate');
TRUNCATE TABLE demo_scratch_log;

-- Exercise 12 — DROP in safe order (re-enable as a teaching block: uncomment to wipe demo)
-- SET foreign_key_checks = 0;
-- DROP TABLE IF EXISTS demo_po_lines;
-- DROP TABLE IF EXISTS demo_purchase_orders;
-- DROP VIEW IF EXISTS v_demo_supplier_orders;
-- DROP TABLE IF EXISTS demo_catalog_parts;
-- DROP TABLE IF EXISTS demo_scratch_log;
-- DROP TABLE IF EXISTS demo_suppliers;
-- SET foreign_key_checks = 1;
-- DROP DATABASE IF EXISTS ddl_practice;
