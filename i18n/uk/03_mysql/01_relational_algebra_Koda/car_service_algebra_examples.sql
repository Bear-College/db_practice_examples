-- Реляційна алгебра (Algebra Koda) — виконувані приклади для `car_service_db`
-- Джерело схеми: ../../01_database_mysql/car_service_db.sql.gz (з кореня репозиторію: database/…)
-- Використання: mysql -u... -p... car_service_db < car_service_algebra_examples.sql
-- Або вставляйте окремі блоки після: USE car_service_db;

USE car_service_db;

-- Вправа 1 — σ_{status='completed'}(Work_orders)
SELECT id, vehicle_id, assigned_mechanic_id, status, total_cost
FROM work_orders
WHERE status = 'completed';

-- Вправа 2 — π_{sku,brand}(Parts)
SELECT sku, brand
FROM parts;

-- Вправа 3 — π_{email}(σ_{phone IS NOT NULL}(Customers))
SELECT email
FROM customers
WHERE phone IS NOT NULL;

-- Вправа 4 — з'єднати Work_orders і Vehicles, обрати дорогі замовлення
SELECT wo.id, v.plate, wo.total_cost
FROM work_orders AS wo
INNER JOIN vehicles AS v ON wo.vehicle_id = v.id
WHERE wo.total_cost > 1000;

-- Вправа 5 — з'єднання трьох таблиць: робоче замовлення → авто → ім'я клієнта
SELECT wo.id AS work_order_id,
       c.first_name,
       c.last_name
FROM work_orders AS wo
INNER JOIN vehicles AS v ON wo.vehicle_id = v.id
INNER JOIN customers AS c ON v.customer_id = c.id;

-- Вправа 6 — об'єднання проєкцій (унікальні customer_id)
SELECT customer_id FROM blacklist
UNION
SELECT customer_id FROM loyalty_cards WHERE points > 0;

-- Вправа 7 — різниця множин customer_id (NOT EXISTS уникає пасток NULL у NOT IN)
SELECT DISTINCT v.customer_id
FROM vehicles AS v
WHERE v.customer_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM blacklist AS b WHERE b.customer_id = v.customer_id AND b.id <= 10
  );

-- Вправа 8 — перетин множин customer_id
-- MySQL 8.0.31+ / 9.x: доступний INTERSECT; альтернатива — INNER JOIN з DISTINCT нижче.
SELECT DISTINCT f.customer_id
FROM feedback AS f
INNER JOIN marketing_consents AS m ON f.customer_id = m.customer_id;

-- Вправа 8 (альтернатива, якщо ваш сервер підтримує INTERSECT)
-- SELECT customer_id FROM feedback
-- INTERSECT
-- SELECT customer_id FROM marketing_consents;

-- Вправа 9 — перейменування через AS
SELECT id AS cust_id, email
FROM customers;

-- Вправа 10 — розширена RA: групування / COUNT
SELECT assigned_mechanic_id,
       COUNT(*) AS wo_count
FROM work_orders
WHERE assigned_mechanic_id IS NOT NULL
GROUP BY assigned_mechanic_id;

-- Вправа 11 — order_jobs ⋈ job_types для одного робочого замовлення
SELECT jt.name AS job_type_name,
       oj.price
FROM order_jobs AS oj
INNER JOIN job_types AS jt ON oj.job_type_id = jt.id
WHERE oj.work_order_id BETWEEN 1 AND 5;

-- Вправа 12 — низький запас: inventory зі складом і деталлю
SELECT w.name AS warehouse_name,
       p.sku,
       inv.quantity
FROM inventory AS inv
INNER JOIN warehouses AS w ON inv.warehouse_id = w.id
INNER JOIN parts AS p ON inv.part_id = p.id
WHERE inv.quantity < 5;

-- Вправа 13 — клієнти з принаймні одним підтвердженим прийомом (напівз'єднання через DISTINCT)
SELECT DISTINCT c.id,
                c.first_name,
                c.last_name
FROM customers AS c
INNER JOIN vehicles AS v ON v.customer_id = c.id
INNER JOIN appointments AS a ON a.vehicle_id = v.id
WHERE a.status = 'confirmed';

-- Вправа 13 (стиль EXISTS — відповідає семантиці «напівз'єднання»)
SELECT c.id, c.first_name, c.last_name
FROM customers AS c
WHERE EXISTS (
  SELECT 1
  FROM vehicles AS v
  INNER JOIN appointments AS a ON a.vehicle_id = v.id
  WHERE v.customer_id = c.id
    AND a.status = 'confirmed'
);

-- Вправа 14 — θ-з'єднання як σ на декартовому добутку (для ілюстрації; уникайте повних cross-добутків на великих таблицях)
SELECT e.id AS employee_id,
       r.id AS role_id
FROM employees AS e
CROSS JOIN roles AS r
WHERE e.role_id = r.id;

-- Вправа 15 — еквіваленти: два аліаси на parts
SELECT p1.sku AS sku_1,
       p2.sku AS sku_2
FROM equivalents AS e
INNER JOIN parts AS p1 ON e.part_id_1 = p1.id
INNER JOIN parts AS p2 ON e.part_id_2 = p2.id;
