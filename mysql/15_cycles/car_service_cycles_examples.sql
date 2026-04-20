-- Cycles: procedural loops (WHILE / REPEAT / LOOP) + recursive CTE — car_service_db
-- MySQL 5.7+ (procedures), 8.0+ (WITH RECURSIVE). mysql client for DELIMITER.
--   mysql ... car_service_db < 15_cycles/car_service_cycles_examples.sql

USE car_service_db;

DROP PROCEDURE IF EXISTS sp_cyc_cursor_wo;
DROP PROCEDURE IF EXISTS sp_cyc_loop_leave_demo;
DROP PROCEDURE IF EXISTS sp_cyc_repeat_demo;
DROP PROCEDURE IF EXISTS sp_cyc_while_demo;

DROP TABLE IF EXISTS cyc_log;

CREATE TABLE cyc_log (
  id         INT NOT NULL AUTO_INCREMENT,
  kind       VARCHAR(20) NOT NULL,
  iteration  INT NOT NULL,
  detail     VARCHAR(120) DEFAULT NULL,
  ts         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

DELIMITER $$

-- C1 — WHILE … END WHILE
CREATE PROCEDURE sp_cyc_while_demo(IN p_times INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  WHILE i < p_times DO
    SET i = i + 1;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('WHILE', i, CONCAT('step ', i));
  END WHILE;
END$$

-- C2 — REPEAT … UNTIL (condition checked after each iteration)
CREATE PROCEDURE sp_cyc_repeat_demo()
BEGIN
  DECLARE j INT DEFAULT 0;
  REPEAT
    SET j = j + 1;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('REPEAT', j, CONCAT('repeat step ', j));
  UNTIL j >= 3
  END REPEAT;
END$$

-- C3 — LOOP with LEAVE (named label)
CREATE PROCEDURE sp_cyc_loop_leave_demo()
BEGIN
  DECLARE k INT DEFAULT 0;
  cyc_loop: LOOP
    SET k = k + 1;
    IF k > 4 THEN
      LEAVE cyc_loop;
    END IF;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('LOOP', k, CONCAT('loop step ', k));
  END LOOP cyc_loop;
END$$

-- C4 — Cursor loop over a few work_orders (ids bounded)
CREATE PROCEDURE sp_cyc_cursor_wo()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE v_id INT;
  DECLARE v_cost DECIMAL(12,2);
  DECLARE cur CURSOR FOR
    SELECT id, total_cost
    FROM work_orders
    WHERE id BETWEEN 1 AND 30
    ORDER BY id
    LIMIT 5;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  read_rows: LOOP
    FETCH cur INTO v_id, v_cost;
    IF done = 1 THEN
      LEAVE read_rows;
    END IF;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('CURSOR', v_id, CONCAT('total_cost=', v_cost));
  END LOOP read_rows;
  CLOSE cur;
END$$

DELIMITER ;

CALL sp_cyc_while_demo(4);
CALL sp_cyc_repeat_demo();
CALL sp_cyc_loop_leave_demo();
CALL sp_cyc_cursor_wo();

SELECT id, kind, iteration, detail, ts
FROM cyc_log
ORDER BY id;

-- =============================================================================
-- C5 — Recursive CTE (MySQL 8.0+): generate 1..N without a procedural loop
-- =============================================================================
WITH RECURSIVE seq(n) AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 12
)
SELECT n FROM seq;

-- =============================================================================
-- Optional: drop procedures / table when finished
-- =============================================================================
-- DROP PROCEDURE IF EXISTS sp_cyc_while_demo;
-- DROP PROCEDURE IF EXISTS sp_cyc_repeat_demo;
-- DROP PROCEDURE IF EXISTS sp_cyc_loop_leave_demo;
-- DROP PROCEDURE IF EXISTS sp_cyc_cursor_wo;
-- DROP TABLE IF EXISTS cyc_log;
