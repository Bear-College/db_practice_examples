-- DDL: лабораторія зв'язків — батько/нащадок, багато-до-багатьох, само-посилання
-- Використання: mysql -u... -p... < car_service_relationships_examples.sql
-- Виконується в пісочниці БД: ddl_practice

CREATE DATABASE IF NOT EXISTS ddl_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE ddl_practice;

-- Скинути лише демо-об'єкти зв'язків.
SET foreign_key_checks = 0;
DROP TABLE IF EXISTS rel_order_parts;
DROP TABLE IF EXISTS rel_work_orders;
DROP TABLE IF EXISTS rel_parts;
DROP TABLE IF EXISTS rel_technicians;
DROP TABLE IF EXISTS rel_customers;
SET foreign_key_checks = 1;

-- 1) Батьківська таблиця
CREATE TABLE rel_customers (
  id            INT NOT NULL AUTO_INCREMENT,
  full_name     VARCHAR(120) NOT NULL,
  phone         VARCHAR(32) DEFAULT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 2) Само-посилання (працівник -> керівник)
CREATE TABLE rel_technicians (
  id            INT NOT NULL AUTO_INCREMENT,
  tech_name     VARCHAR(120) NOT NULL,
  manager_id    INT DEFAULT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_rel_tech_manager
    FOREIGN KEY (manager_id) REFERENCES rel_technicians (id)
      ON UPDATE CASCADE
      ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 3) Один-до-багатьох (клієнт -> робочі замовлення)
CREATE TABLE rel_work_orders (
  id            INT NOT NULL AUTO_INCREMENT,
  customer_id   INT NOT NULL,
  technician_id INT DEFAULT NULL,
  opened_at     DATETIME NOT NULL,
  status        ENUM('new','in_progress','done','cancelled') NOT NULL DEFAULT 'new',
  PRIMARY KEY (id),
  CONSTRAINT fk_rel_wo_customer
    FOREIGN KEY (customer_id) REFERENCES rel_customers (id)
      ON UPDATE CASCADE
      ON DELETE RESTRICT,
  CONSTRAINT fk_rel_wo_technician
    FOREIGN KEY (technician_id) REFERENCES rel_technicians (id)
      ON UPDATE CASCADE
      ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 4) Довідкова таблиця (каталог деталей)
CREATE TABLE rel_parts (
  id            INT NOT NULL AUTO_INCREMENT,
  sku           VARCHAR(50) NOT NULL,
  part_name     VARCHAR(200) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_rel_parts_sku (sku)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 5) Міст «багато-до-багатьох» (робоче замовлення <-> деталь)
CREATE TABLE rel_order_parts (
  work_order_id INT NOT NULL,
  part_id       INT NOT NULL,
  qty           INT NOT NULL DEFAULT 1,
  PRIMARY KEY (work_order_id, part_id),
  CONSTRAINT fk_rel_op_work_order
    FOREIGN KEY (work_order_id) REFERENCES rel_work_orders (id)
      ON UPDATE CASCADE
      ON DELETE CASCADE,
  CONSTRAINT fk_rel_op_part
    FOREIGN KEY (part_id) REFERENCES rel_parts (id)
      ON UPDATE CASCADE
      ON DELETE RESTRICT,
  CONSTRAINT chk_rel_op_qty CHECK (qty > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Засіяти мінімальний граф
INSERT INTO rel_customers (full_name, phone) VALUES
  ('Olena Kovalenko', '+380501112233'),
  ('Maksym Danylchuk', '+380671234567');

INSERT INTO rel_technicians (tech_name, manager_id) VALUES
  ('Iryna Lead Tech', NULL),
  ('Taras Junior Tech', 1);

INSERT INTO rel_work_orders (customer_id, technician_id, opened_at, status) VALUES
  (1, 1, '2026-04-01 09:00:00', 'in_progress'),
  (2, 2, '2026-04-01 11:30:00', 'new');

INSERT INTO rel_parts (sku, part_name) VALUES
  ('BRK-PAD-01', 'Front brake pad set'),
  ('OIL-5W30-4L', 'Synthetic oil 5W-30 4L');

INSERT INTO rel_order_parts (work_order_id, part_id, qty) VALUES
  (1, 1, 1),
  (1, 2, 1),
  (2, 2, 1);

-- Швидкий перевірочний запит (з'єднання через 1:N і N:M)
SELECT wo.id AS work_order_id,
       c.full_name AS customer,
       t.tech_name AS technician,
       p.sku,
       p.part_name,
       op.qty
FROM rel_work_orders AS wo
JOIN rel_customers AS c ON c.id = wo.customer_id
LEFT JOIN rel_technicians AS t ON t.id = wo.technician_id
JOIN rel_order_parts AS op ON op.work_order_id = wo.id
JOIN rel_parts AS p ON p.id = op.part_id
ORDER BY wo.id, p.id;

-- Опціональне прибирання:
-- SET foreign_key_checks = 0;
-- DROP TABLE IF EXISTS rel_order_parts;
-- DROP TABLE IF EXISTS rel_work_orders;
-- DROP TABLE IF EXISTS rel_parts;
-- DROP TABLE IF EXISTS rel_technicians;
-- DROP TABLE IF EXISTS rel_customers;
-- SET foreign_key_checks = 1;
