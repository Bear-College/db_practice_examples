-- Stored procedures — car_service_db (MySQL 5.7+ / 8.x)
-- mysql ... car_service_db < 14_procedures/car_service_procedures_examples.sql

USE car_service_db;

DROP PROCEDURE IF EXISTS sp_append_tag;
DROP PROCEDURE IF EXISTS sp_customer_count;
DROP PROCEDURE IF EXISTS sp_sum_cost_slice;
DROP PROCEDURE IF EXISTS sp_work_orders_by_status;

DELIMITER $$

-- P1 — IN parameters: return a result set (bounded)
CREATE PROCEDURE sp_work_orders_by_status(
  IN p_status VARCHAR(20),
  IN p_limit INT
)
BEGIN
  SELECT id,
         vehicle_id,
         mechanic_id,
         status,
         total_cost
  FROM work_orders
  WHERE status = p_status
    AND id BETWEEN 1 AND 100000
  ORDER BY id
  LIMIT p_limit;
END$$

-- P2 — OUT parameter: aggregate into a user variable
CREATE PROCEDURE sp_sum_cost_slice(
  OUT p_sum DECIMAL(14,2)
)
BEGIN
  SELECT COALESCE(SUM(total_cost), 0)
  INTO p_sum
  FROM work_orders
  WHERE id BETWEEN 1 AND 50000;
END$$

-- P3 — IN + OUT + DECLARE / IF
CREATE PROCEDURE sp_customer_count(
  IN p_min_id INT,
  IN p_max_id INT,
  OUT p_cnt INT
)
BEGIN
  DECLARE v_span INT DEFAULT 0;
  SET v_span := p_max_id - p_min_id;
  IF v_span < 0 THEN
    SET p_cnt := 0;
  ELSE
    SELECT COUNT(*)
    INTO p_cnt
    FROM customers
    WHERE id BETWEEN p_min_id AND p_max_id;
  END IF;
END$$

-- P4 — INOUT: mutate a session user variable passed from CALL
CREATE PROCEDURE sp_append_tag(
  INOUT p_text VARCHAR(200)
)
BEGIN
  SET p_text := CONCAT(IFNULL(p_text, ''), ' | proc_ok');
END$$

DELIMITER ;

-- -----------------------------------------------------------------------------
-- Calls (same session so @ variables work)
-- -----------------------------------------------------------------------------
CALL sp_work_orders_by_status('completed', 8);

CALL sp_sum_cost_slice(@cost_sum);
SELECT @cost_sum AS sum_total_cost_slice;

CALL sp_customer_count(1, 500, @cust_n);
SELECT @cust_n AS customers_in_range;

SET @tag := 'lab';
CALL sp_append_tag(@tag);
SELECT @tag AS tag_after_inout;

-- -----------------------------------------------------------------------------
-- Optional: drop procedures when finished
-- -----------------------------------------------------------------------------
-- DROP PROCEDURE IF EXISTS sp_work_orders_by_status;
-- DROP PROCEDURE IF EXISTS sp_sum_cost_slice;
-- DROP PROCEDURE IF EXISTS sp_customer_count;
-- DROP PROCEDURE IF EXISTS sp_append_tag;
