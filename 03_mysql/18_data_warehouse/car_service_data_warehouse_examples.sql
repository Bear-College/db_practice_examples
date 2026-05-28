-- Data warehouse intro — star schema lab inside car_service_db
-- Run: mysql -u root car_service_db < 03_mysql/18_data_warehouse/car_service_data_warehouse_examples.sql

USE car_service_db;

DROP TABLE IF EXISTS dw_fact_work_orders;
DROP TABLE IF EXISTS dw_dim_customer;
DROP TABLE IF EXISTS dw_dim_brand;

-- =============================================================================
-- 1) Dimension tables (conformed dimensions — slowly changing attributes)
-- =============================================================================
CREATE TABLE dw_dim_customer (
  customer_sk   INT NOT NULL AUTO_INCREMENT,
  customer_id   INT NOT NULL,
  last_name     VARCHAR(80) NOT NULL,
  email         VARCHAR(120),
  PRIMARY KEY (customer_sk),
  UNIQUE KEY uq_dw_dim_customer_bk (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE dw_dim_brand (
  brand_sk   INT NOT NULL AUTO_INCREMENT,
  brand_id   INT NOT NULL,
  brand_name VARCHAR(80) NOT NULL,
  PRIMARY KEY (brand_sk),
  UNIQUE KEY uq_dw_dim_brand_bk (brand_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- =============================================================================
-- 2) Fact table at grain: one row per work order (measures + dimension keys)
-- =============================================================================
CREATE TABLE dw_fact_work_orders (
  work_order_id INT NOT NULL,
  customer_sk   INT NOT NULL,
  brand_sk      INT NOT NULL,
  status        VARCHAR(20) NOT NULL,
  total_cost    DECIMAL(12, 2) NOT NULL,
  PRIMARY KEY (work_order_id),
  KEY ix_dw_fact_customer (customer_sk),
  KEY ix_dw_fact_brand (brand_sk),
  CONSTRAINT fk_dw_fact_customer FOREIGN KEY (customer_sk) REFERENCES dw_dim_customer (customer_sk),
  CONSTRAINT fk_dw_fact_brand FOREIGN KEY (brand_sk) REFERENCES dw_dim_brand (brand_sk)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- =============================================================================
-- 3) ETL-style load from operational tables (bounded slice for class speed)
-- =============================================================================
INSERT INTO dw_dim_customer (customer_id, last_name, email)
SELECT c.id, c.last_name, c.email
FROM customers AS c
WHERE c.id BETWEEN 1 AND 500;

INSERT INTO dw_dim_brand (brand_id, brand_name)
SELECT b.id, b.name
FROM car_brands AS b
WHERE b.id BETWEEN 1 AND 300;

INSERT INTO dw_fact_work_orders (work_order_id, customer_sk, brand_sk, status, total_cost)
SELECT wo.id,
       dc.customer_sk,
       db.brand_sk,
       wo.status,
       wo.total_cost
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN dw_dim_customer AS dc ON dc.customer_id = v.customer_id
INNER JOIN dw_dim_brand AS db ON db.brand_id = v.brand_id
WHERE wo.id BETWEEN 1 AND 5000;

SELECT COUNT(*) AS fact_rows FROM dw_fact_work_orders;

-- =============================================================================
-- 4) Analytical query on the star (brand × status revenue)
-- =============================================================================
SELECT db.brand_name,
       f.status,
       COUNT(*) AS orders,
       ROUND(SUM(f.total_cost), 2) AS revenue
FROM dw_fact_work_orders AS f
INNER JOIN dw_dim_brand AS db ON db.brand_sk = f.brand_sk
GROUP BY db.brand_name, f.status
ORDER BY revenue DESC
LIMIT 15;
