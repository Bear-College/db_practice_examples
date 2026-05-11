-- DQL — теми: SELECT, FROM, WHERE, NULL, AND/OR/IN/LIKE/IS/NOT,
--   агрегати (COUNT, SUM, AVG, MIN, MAX), GROUP BY, HAVING,
--   ORDER BY, DISTINCT, LIMIT, LIMIT … OFFSET …
-- База даних: завантажити з 01_database_mysql/car_service_db.sql.gz у `car_service_db`
-- Використання (з кореня репозиторію):
--   gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u... -p... car_service_db
--   mysql -u... -p... car_service_db < 04_dql/car_service_dql_examples.sql
-- Великі таблиці: предикати використовують обмежені діапазони id там, де це доречно.

USE car_service_db;

-- =============================================================================
-- Теми (a–d): SELECT, FROM, WHERE, GROUP BY — базові «цеглинки»
-- =============================================================================

-- 1 — SELECT … FROM … (обрати стовпці з однієї таблиці)
SELECT id,
       first_name,
       last_name,
       email
FROM customers
WHERE id BETWEEN 1 AND 200
LIMIT 20;

-- 2 — NULL: стовпці, які можуть бути відсутні; IS NULL / IS NOT NULL; COALESCE
SELECT id,
       first_name,
       last_name,
       phone,
       COALESCE(phone, 'no phone') AS phone_display
FROM customers
WHERE id BETWEEN 1 AND 300
  AND phone IS NOT NULL
LIMIT 15;

-- 3 — WHERE: простий предикат на одну таблицю
SELECT id,
       vehicle_id,
       status,
       total_cost
FROM work_orders
WHERE status = 'completed'
  AND id BETWEEN 1 AND 5000
LIMIT 25;

-- 4 — WHERE: AND, OR, IN, LIKE, IS, NOT
SELECT id,
       first_name,
       last_name,
       email
FROM customers
WHERE id BETWEEN 1 AND 2000
  AND (
        (first_name LIKE 'Name_1%' OR first_name LIKE 'Name_2%')
    OR last_name LIKE 'Surname_1%'
  )
LIMIT 20;

SELECT id,
       vehicle_id,
       status,
       total_cost
FROM work_orders
WHERE id BETWEEN 1 AND 10000
  AND status IN ('new', 'in_progress', 'waiting_parts')
LIMIT 25;

SELECT id,
       assigned_mechanic_id,
       status
FROM work_orders
WHERE id BETWEEN 1 AND 5000
  AND assigned_mechanic_id IS NOT NULL
  AND NOT (status = 'cancelled')
LIMIT 25;

-- 5 — Агрегатні функції: COUNT, SUM, AVG, MIN, MAX (один зріз work_orders)
SELECT status,
       COUNT(*) AS row_count,
       SUM(total_cost) AS sum_cost,
       AVG(total_cost) AS avg_cost,
       MIN(total_cost) AS min_cost,
       MAX(total_cost) AS max_cost
FROM work_orders
WHERE id BETWEEN 1 AND 50000
GROUP BY status
ORDER BY status;

-- 6 — GROUP BY (з COUNT; групи = статуси замовлень)
SELECT status,
       COUNT(*) AS how_many
FROM work_orders
WHERE id BETWEEN 1 AND 50000
GROUP BY status
ORDER BY status;

-- 7 — HAVING: фільтр груп після GROUP BY (не те саме, що WHERE на «сирих» рядках)
SELECT status,
       COUNT(*) AS how_many,
       AVG(total_cost) AS avg_cost
FROM work_orders
WHERE id BETWEEN 1 AND 100000
GROUP BY status
HAVING COUNT(*) >= 100
   AND AVG(total_cost) > 400
ORDER BY avg_cost DESC;

-- 8 — ORDER BY: відсортувати результат (ASC за замовчуванням; DESC — явно)
SELECT id,
       total_cost,
       status
FROM work_orders
WHERE id BETWEEN 1 AND 2000
ORDER BY total_cost DESC, id ASC
LIMIT 30;

-- 9 — DISTINCT: унікальні значення стовпця (у зрізі)
SELECT DISTINCT status
FROM work_orders
WHERE id BETWEEN 1 AND 20000;

SELECT DISTINCT brand
FROM parts
WHERE id BETWEEN 1 AND 5000
  AND brand IS NOT NULL;

-- 10 — LIMIT: обмежити кількість повернених рядків
SELECT id,
       sku,
       name
FROM parts
WHERE id BETWEEN 1 AND 10000
ORDER BY id
LIMIT 12;

-- 11 — LIMIT … OFFSET …: пропустити перші N рядків, потім узяти M (пагінація)
SELECT id,
       first_name,
       last_name
FROM customers
WHERE id BETWEEN 1 AND 500
ORDER BY id
LIMIT 10 OFFSET 20;

-- =============================================================================
-- Доповнення: поєднання таблиць (SELECT … FROM … JOIN …) — типове після основ
-- =============================================================================

-- S1 — INNER JOIN: авто + назва бренду
SELECT v.id AS vehicle_id,
       v.plate,
       b.name AS brand_name
FROM vehicles AS v
INNER JOIN car_brands AS b ON b.id = v.brand_id
WHERE v.id BETWEEN 1 AND 150
LIMIT 25;

-- S2 — Звіт з кількох таблиць: робоче замовлення, клієнт, авто
SELECT wo.id AS work_order_id,
       c.last_name,
       v.plate,
       wo.total_cost
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
WHERE wo.id BETWEEN 1 AND 200
LIMIT 20;
