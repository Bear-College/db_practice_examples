-- Порядок команд у SQL-запитах (як у навчальному матеріалі):
--   SELECT → FROM → JOIN → WHERE → GROUP BY → HAVING → ORDER BY → LIMIT → (LIMIT OFFSET)
-- База: завантажити database/car_service_db.sql.gz у car_service_db
-- Запуск з кореня репозиторію:
--   mysql -u... -p... car_service_db < 5_order_commands/car_service_order_examples.sql

USE car_service_db;

-- =============================================================================
-- Приклад 1 — усі фрази зі списку: JOIN, WHERE, GROUP BY, HAVING, ORDER BY,
--             LIMIT з OFFSET (пагінація «друга сторінка»)
-- =============================================================================
-- Для кожного клієнта (у діапазоні id): скільки замовлень і середня вартість;
-- лишаємо лише клієнтів із достатньою кількістю замовлень і середнім чеком;
-- сортуємо за середнім; показуємо 5 рядків, пропускаючи перші 5.
SELECT c.id AS customer_id,
       c.last_name,
       COUNT(wo.id) AS work_order_count,
       ROUND(AVG(wo.total_cost), 2) AS avg_total_cost
FROM customers AS c
INNER JOIN vehicles AS v ON v.customer_id = c.id
INNER JOIN work_orders AS wo ON wo.vehicle_id = v.id
WHERE c.id BETWEEN 1 AND 20000
  AND wo.id BETWEEN 1 AND 200000
GROUP BY c.id, c.last_name
HAVING COUNT(wo.id) >= 1
   AND AVG(wo.total_cost) > 300
ORDER BY avg_total_cost DESC, c.id
LIMIT 10 OFFSET 0;

-- Той самий ланцюжок фраз, але пагінація: пропустити перші 10 груп, показати наступні 5
-- (якщо рядків менше — результат буде порожнім або коротким)
SELECT c.id AS customer_id,
       c.last_name,
       COUNT(wo.id) AS work_order_count,
       ROUND(AVG(wo.total_cost), 2) AS avg_total_cost
FROM customers AS c
INNER JOIN vehicles AS v ON v.customer_id = c.id
INNER JOIN work_orders AS wo ON wo.vehicle_id = v.id
WHERE c.id BETWEEN 1 AND 20000
  AND wo.id BETWEEN 1 AND 200000
GROUP BY c.id, c.last_name
HAVING COUNT(wo.id) >= 1
   AND AVG(wo.total_cost) > 300
ORDER BY avg_total_cost DESC, c.id
LIMIT 5 OFFSET 10;

-- =============================================================================
-- Приклад 2 — ORDER BY + LIMIT (без OFFSET): перші N рядків після сортування
-- =============================================================================
SELECT wo.id,
       wo.status,
       wo.total_cost
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 50000
ORDER BY wo.total_cost DESC, wo.id
LIMIT 12;

-- =============================================================================
-- Приклад 3 — без GROUP BY / HAVING: лише JOIN, WHERE, ORDER BY, LIMIT
-- =============================================================================
SELECT wo.id AS work_order_id,
       c.first_name,
       c.last_name,
       v.plate,
       b.name AS brand_name,
       wo.total_cost
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
LEFT JOIN car_brands AS b ON b.id = v.car_brands_id
WHERE wo.id BETWEEN 1 AND 400
ORDER BY wo.total_cost DESC
LIMIT 15;

-- =============================================================================
-- Приклад 4 — альтернативний запис LIMIT + OFFSET (еквівалент у MySQL)
-- LIMIT offset, row_count — ті самі 5 рядків після перших 10, що й LIMIT 5 OFFSET 10
-- =============================================================================
SELECT id,
       status,
       total_cost
FROM work_orders
WHERE id BETWEEN 1 AND 10000
ORDER BY total_cost ASC, id
LIMIT 10, 5;
