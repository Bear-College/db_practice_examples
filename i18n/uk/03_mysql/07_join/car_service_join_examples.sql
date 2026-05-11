-- Приклади JOIN (прості та складні) — car_service_db
-- Завантаження: gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql ... car_service_db
-- Запуск: mysql ... car_service_db < 07_join/car_service_join_examples.sql

USE car_service_db;

-- =============================================================================
-- ПРОСТО
-- =============================================================================

-- E1 — INNER JOIN: авто + назва бренду
SELECT v.id AS vehicle_id,
       v.plate,
       v.car,
       b.name AS brand_name
FROM vehicles AS v
INNER JOIN car_brands AS b ON b.id = v.brand_id
WHERE v.id BETWEEN 1 AND 200
LIMIT 30;

-- E2 — INNER JOIN: робоче замовлення + номерний знак
SELECT wo.id AS work_order_id,
       wo.status,
       wo.total_cost,
       v.plate,
       v.id AS vehicle_id
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
WHERE wo.id BETWEEN 1 AND 500
LIMIT 25;

-- E3 — Ланцюжок INNER JOIN: work_order → vehicle → customer
SELECT wo.id AS work_order_id,
       wo.total_cost,
       v.plate,
       c.id AS customer_id,
       c.first_name,
       c.last_name
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
WHERE wo.id BETWEEN 1 AND 300
LIMIT 25;

-- E4 — LEFT JOIN: зберегти кожного клієнта в діапазоні; feedback може бути NULL
SELECT c.id AS customer_id,
       c.email,
       f.rating,
       f.comment
FROM customers AS c
LEFT JOIN feedback AS f ON f.customer_id = c.id
WHERE c.id BETWEEN 1 AND 80
LIMIT 40;

-- E5 — INNER JOIN: деталь + роздрібна ціна
SELECT p.id AS part_id,
       p.sku,
       p.name,
       pp.retail_price
FROM parts AS p
INNER JOIN part_prices AS pp ON pp.part_id = p.id
WHERE p.id BETWEEN 1 AND 500
LIMIT 25;

-- E6 — INNER JOIN: працівник + назва посади (бонусний простий приклад)
SELECT e.id AS employee_id,
       e.first_name,
       e.last_name,
       r.title AS role_title
FROM employees AS e
INNER JOIN roles AS r ON r.id = e.role_id
WHERE e.id BETWEEN 1 AND 150
LIMIT 25;

-- =============================================================================
-- СКЛАДНО
-- =============================================================================

-- H1 — Anti-join: клієнти БЕЗ авто (LEFT JOIN + IS NULL)
SELECT c.id,
       c.first_name,
       c.last_name
FROM customers AS c
WHERE c.id BETWEEN 1 AND 5000
  AND EXISTS (
    SELECT 1 FROM vehicles AS v WHERE v.customer_id = c.id
  )
LIMIT 25;

-- H2 — Multi LEFT JOIN: один опціональний feedback + одне опціональне авто на клієнта (через підзапити-ключі)
SELECT c.id AS customer_id,
       c.last_name,
       f.rating,
       v.plate,
       v.id AS vehicle_id
FROM customers AS c
LEFT JOIN (
            SELECT customer_id,
                   MIN(id) AS first_feedback_id
            FROM feedback
            WHERE id BETWEEN 1 AND 300000
            GROUP BY customer_id
          ) AS fk ON fk.customer_id = c.id
LEFT JOIN feedback AS f ON f.id = fk.first_feedback_id
LEFT JOIN (
            SELECT customer_id,
                   MIN(id) AS first_vehicle_id
            FROM vehicles
            WHERE id BETWEEN 1 AND 20000
            GROUP BY customer_id
          ) AS vk ON vk.customer_id = c.id
LEFT JOIN vehicles AS v ON v.id = vk.first_vehicle_id
WHERE c.id BETWEEN 1 AND 50
LIMIT 60;

-- H3 — Таблиця-міст + само-з'єднання на parts (еквівалентні SKU)
SELECT p1.sku AS sku_a,
       p2.sku AS sku_b,
       p1.brand AS brand_a,
       p2.brand AS brand_b
FROM equivalents AS e
INNER JOIN parts AS p1 ON p1.id = e.part_id_1
INNER JOIN parts AS p2 ON p2.id = e.part_id_2
WHERE e.id BETWEEN 1 AND 500
LIMIT 25;

-- H4 — INNER JOIN до похідної таблиці: клієнти з кількістю авто, потім фільтр
SELECT c.id,
       c.last_name,
       vc.n_vehicles
FROM customers AS c
INNER JOIN (
             SELECT customer_id,
                    COUNT(*) AS n_vehicles
             FROM vehicles
             WHERE id BETWEEN 1 AND 15000
               AND customer_id IS NOT NULL
             GROUP BY customer_id
             HAVING COUNT(*) >= 1
           ) AS vc ON vc.customer_id = c.id
WHERE c.id BETWEEN 1 AND 20000
ORDER BY vc.n_vehicles DESC, c.id
LIMIT 20;

-- H5 — Шаблон FULL OUTER JOIN (MySQL): рядки без пари зліва ∪ без пари справа (малі зрізи id)
--      Частина A: склади у зрізі без рядка inventory (у зрізі inventory)
SELECT w.id AS side_id,
       w.name AS label,
       'warehouse_without_inventory_in_slice' AS match_kind
FROM warehouses AS w
LEFT JOIN inventory AS inv
  ON inv.warehouse_id = w.id
 AND inv.id BETWEEN 1 AND 50000
WHERE w.id BETWEEN 1 AND 30
  AND inv.id IS NULL
UNION ALL
-- Частина B: рядки inventory у зрізі, що посилаються на склади поза лівим зрізом (FK цілий; демо «outer»)
SELECT inv.id AS side_id,
       CAST(CONCAT('inv_wh_', inv.warehouse_id) AS CHAR(100)) AS label,
       'inventory_row_outside_left_slice' AS match_kind
FROM inventory AS inv
WHERE inv.id BETWEEN 1 AND 5000
  AND inv.warehouse_id NOT IN (SELECT w2.id FROM warehouses AS w2 WHERE w2.id BETWEEN 1 AND 30)
LIMIT 25;

-- =============================================================================
-- RIGHT JOIN, CROSS JOIN, шаблон FULL OUTER, багато таблиць в одному запиті
-- =============================================================================

-- R1 — RIGHT JOIN (дзеркало LEFT JOIN: «зберегти всі рядки таблиці ПРАВОРУЧ»)
--      Тут: всі авто зі зрізу присутні; стовпці бренду зліва (NULL, якщо немає збігу — рідко при FK).
SELECT b.id AS brand_id,
       b.name AS brand_name,
       v.id AS vehicle_id,
       v.plate
FROM car_brands AS b
RIGHT JOIN vehicles AS v ON v.brand_id = b.id
WHERE v.id BETWEEN 1 AND 40
LIMIT 40;

-- R2 — CROSS JOIN: декартів добуток — ОБОВ'ЯЗКОВО обмежуйте обидві сторони (малі зрізи), інакше кількість рядків лавиноподібно зросте
--      Демо: перші N брендів × перші M типів пального (каталогова «сітка»; не FK-шлях)
SELECT b.id AS brand_id,
       b.name AS brand_name,
       ft.id AS fuel_type_id,
       ft.name AS fuel_name
FROM (SELECT id, name FROM car_brands WHERE id BETWEEN 1 AND 3) AS b
CROSS JOIN (SELECT id, name FROM fuel_types WHERE id BETWEEN 1 AND 4) AS ft;

-- R3 — Шаблон FULL OUTER JOIN у MySQL (нативного FULL OUTER немає): LEFT ∪ «лише справа»
--      Частина 1 — кожен склад у зрізі, з рядками inventory або без
--      Частина 2 — рядки inventory без відповідного складу (порожньо при цілих FK)
SELECT w.id AS warehouse_id,
       w.name AS warehouse_name,
       inv.id AS inventory_id,
       inv.quantity,
       'from_left' AS part
FROM warehouses AS w
LEFT JOIN inventory AS inv
  ON inv.warehouse_id = w.id
 AND inv.id BETWEEN 1 AND 5000
WHERE w.id BETWEEN 1 AND 12
UNION ALL
SELECT w.id,
       w.name,
       inv.id,
       inv.quantity,
       'right_only_no_warehouse_match'
FROM inventory AS inv
LEFT JOIN warehouses AS w ON w.id = inv.warehouse_id
WHERE inv.id BETWEEN 1 AND 5000
  AND w.id IS NULL
LIMIT 40;

-- MJ1 — Багато з'єднань в ОДНОМУ запиті: work order → vehicle → customer → brand + опціональна позиція + тип робіт
SELECT wo.id AS work_order_id,
       wo.status,
       wo.total_cost,
       c.first_name,
       c.last_name,
       v.plate,
       b.name AS brand_name,
       oj.price AS line_price,
       jt.name AS job_type_name
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
INNER JOIN car_brands AS b ON b.id = v.brand_id
LEFT JOIN order_jobs AS oj ON oj.work_order_id = wo.id AND oj.id BETWEEN 1 AND 400000
LEFT JOIN job_types AS jt ON jt.id = oj.job_type_id
WHERE wo.id BETWEEN 1 AND 150
LIMIT 30;
