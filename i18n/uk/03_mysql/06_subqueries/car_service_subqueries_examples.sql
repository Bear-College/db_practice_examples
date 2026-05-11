-- Підзапити — прості й складні приклади для car_service_db
-- Завантаження: gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql ... car_service_db
-- Запуск: mysql ... car_service_db < 06_subqueries/car_service_subqueries_examples.sql

USE car_service_db;

-- =============================================================================
-- ПРОСТО — некорельовані підзапити (внутрішній не використовує стовпці зовнішнього)
-- =============================================================================

-- E1 — WHERE … IN (SELECT …): робочі замовлення для авто з обмеженого списку id
SELECT wo.id,
       wo.vehicle_id,
       wo.status,
       wo.total_cost
FROM work_orders AS wo
WHERE wo.vehicle_id IN (
  SELECT v.id
  FROM vehicles AS v
  WHERE v.id BETWEEN 1 AND 150
)
  AND wo.id BETWEEN 1 AND 5000
LIMIT 25;

-- E2 — Скалярний підзапит: рядки з total_cost вище за середнє (на тому самому зрізі)
SELECT wo.id,
       wo.total_cost,
       (SELECT AVG(w2.total_cost)
        FROM work_orders AS w2
        WHERE w2.id BETWEEN 1 AND 80000) AS slice_avg_cost
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 80000
  AND wo.total_cost >= (
        SELECT AVG(w3.total_cost)
        FROM work_orders AS w3
        WHERE w3.id BETWEEN 1 AND 80000
      )
ORDER BY wo.total_cost DESC
LIMIT 20;

-- E3 — Похідна таблиця у FROM: клієнти й кількість їхніх авто (вбудоване подання)
SELECT vc.customer_id,
       c.last_name,
       vc.vehicle_n
FROM (
       SELECT customer_id,
              COUNT(*) AS vehicle_n
       FROM vehicles
       WHERE id BETWEEN 1 AND 10000
         AND customer_id IS NOT NULL
       GROUP BY customer_id
     ) AS vc
INNER JOIN customers AS c ON c.id = vc.customer_id
WHERE vc.vehicle_n >= 1
ORDER BY vc.vehicle_n DESC, vc.customer_id
LIMIT 20;

-- E4 — EXISTS (стиль напівз'єднання): клієнти, які мають feedback
SELECT c.id,
       c.first_name,
       c.last_name
FROM customers AS c
WHERE c.id BETWEEN 1 AND 500
  AND EXISTS (
    SELECT 1
    FROM feedback AS f
    WHERE f.customer_id = c.id
      AND f.id BETWEEN 1 AND 200000
  )
LIMIT 30;

-- =============================================================================
-- СКЛАДНО — корельовані підзапити, NOT EXISTS, вкладення, HAVING + підзапит
-- =============================================================================

-- H1 — Корельований: замовлення, що коштують більше за глобальне середнє (той самий зріз)
SELECT wo.id,
       wo.assigned_mechanic_id,
       wo.total_cost,
       (SELECT AVG(wb.total_cost)
        FROM work_orders AS wb
        WHERE wb.id BETWEEN 1 AND 200000) AS global_avg_cost
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 8000
  AND wo.total_cost IS NOT NULL
ORDER BY wo.total_cost DESC
LIMIT 25;

-- H2 — NOT EXISTS: клієнти (у діапазоні) без жодного feedback
SELECT c.id,
       c.first_name,
       c.last_name
FROM customers AS c
WHERE c.id BETWEEN 1 AND 300
  AND NOT EXISTS (
    SELECT 1
    FROM feedback AS f
    WHERE f.customer_id = c.id
      AND f.rating = 999
  )
LIMIT 30;

-- H3 — Вкладений IN: механіки, у яких title ролі відповідає шаблону (ролі фільтруються у внутрішньому запиті)
SELECT e.id,
       e.first_name,
       e.last_name,
       e.role_id
FROM employees AS e
WHERE e.id BETWEEN 1 AND 2000
  AND e.role_id IN (
    SELECT r.id
    FROM roles AS r
    WHERE r.title LIKE '%Mechanic%'
  )
LIMIT 25;

-- H4 — Підзапит у HAVING: механіки з кількістю замовлень більше за «середнє на механіка»
--     (обчисленим на зрізі work_orders)
SELECT wo.assigned_mechanic_id,
       COUNT(*) AS wo_cnt
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 100000
  AND wo.assigned_mechanic_id IS NOT NULL
GROUP BY wo.assigned_mechanic_id
HAVING COUNT(*) >= (
  SELECT AVG(cnt)
  FROM (
         SELECT COUNT(*) AS cnt
         FROM work_orders AS w2
         WHERE w2.id BETWEEN 1 AND 100000
           AND w2.assigned_mechanic_id IS NOT NULL
         GROUP BY w2.assigned_mechanic_id
       ) AS per_mechanic
)
ORDER BY wo_cnt DESC
LIMIT 15;

-- H5 — Корельований EXISTS: клієнти з принаймні одним підтвердженим прийомом
SELECT c.id,
       c.first_name,
       c.last_name
FROM customers AS c
WHERE c.id BETWEEN 1 AND 400
  AND EXISTS (
    SELECT 1
    FROM vehicles AS v
    INNER JOIN appointments AS a ON a.vehicle_id = v.id
    WHERE v.customer_id = c.id
      AND a.status = 'confirmed'
      AND a.id BETWEEN 1 AND 200000
  )
LIMIT 25;
