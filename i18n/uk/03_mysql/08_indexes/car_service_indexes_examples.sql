-- Лабораторія індексів для car_service_db — безпечні пісочниці idx_lab, idx_geo
-- Передумова: завантажити 01_database_mysql/car_service_db.sql.gz
--   mysql ... car_service_db < 08_indexes/car_service_indexes_examples.sql
-- Рекомендовано MySQL 8.0+ (функціональні індекси, EXPLAIN ANALYZE).
--
-- Ручний тест швидкості: запустіть розділ, зверніть увагу на EXPLAIN / EXPLAIN ANALYZE;
--                     виконайте CREATE INDEX; повторіть запит; виконайте DROP INDEX … та повторіть знов, щоб порівняти без індексу.

USE car_service_db;

-- Скинути об'єкти лабораторії (закоментуйте, якщо хочете зберегти таблиці між сесіями)
DROP TABLE IF EXISTS idx_geo;
DROP TABLE IF EXISTS idx_lab;

-- =============================================================================
-- Лабораторна таблиця: спочатку лише PRIMARY KEY → вторинні індекси додаються покроково
-- =============================================================================
CREATE TABLE idx_lab (
  id            INT NOT NULL AUTO_INCREMENT,
  ref_num       INT NOT NULL,
  sku           VARCHAR(80) NOT NULL,
  note          TEXT,
  status        VARCHAR(20) NOT NULL DEFAULT 'open',
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Засіяти з реальних parts (реалістичні рядки); за потреби скоригуйте верхню межу
INSERT INTO idx_lab (ref_num, sku, note, status)
SELECT p.id,
       p.sku,
       p.name,
       'open'
FROM parts AS p
WHERE p.id BETWEEN 1 AND 40000;

SELECT id, ref_num FROM idx_lab WHERE id BETWEEN 1 AND 3;

-- Підібрати тестове значення, яке точно існує (стабільне після засіву)
SET @probe_ref := (SELECT ref_num FROM idx_lab WHERE id = 15000 LIMIT 1);
SET @probe_sku := (SELECT sku FROM idx_lab WHERE id = 15000 LIMIT 1);

-- -----------------------------------------------------------------------------
-- 1) Вторинний B-tree (звичайний INDEX) на ref_num — порівняйте до / після CREATE INDEX
-- -----------------------------------------------------------------------------
-- Без вторинного індексу: очікуйте type=ALL (повний скан) на великій таблиці
SELECT id, sku
FROM idx_lab
WHERE ref_num BETWEEN @probe_ref AND @probe_ref + 5
LIMIT 5;

-- MySQL 8.0.18+ — фактичні часи (закоментуйте, якщо не підтримується)
-- EXPLAIN ANALYZE
-- SELECT id, sku FROM idx_lab WHERE ref_num = @probe_ref;

CREATE INDEX ix_bt_ref ON idx_lab (ref_num);

SELECT id, sku
FROM idx_lab
WHERE ref_num BETWEEN @probe_ref AND @probe_ref + 5
LIMIT 5;

-- Щоб знову протестувати *без* цього індексу, виконайте вручну:
-- DROP INDEX ix_bt_ref ON idx_lab;

-- -----------------------------------------------------------------------------
-- 2) UNIQUE-індекс — один рядок на sku (падає, якщо є дублікати; тоді використайте звичайний INDEX)
-- -----------------------------------------------------------------------------
CREATE UNIQUE INDEX ix_uniq_sku ON idx_lab (sku);

SELECT id, ref_num
FROM idx_lab
WHERE sku LIKE CONCAT(LEFT(@probe_sku, 3), "%")
LIMIT 5;

-- DROP INDEX ix_uniq_sku ON idx_lab;

-- -----------------------------------------------------------------------------
-- 3) Складений (багатостовпцевий) B-tree індекс — провідний стовпець status
-- -----------------------------------------------------------------------------
CREATE INDEX ix_comp_status_ref ON idx_lab (status, ref_num);

SELECT id, sku, ref_num
FROM idx_lab
WHERE status = 'open'
  AND ref_num BETWEEN 10000 AND 10500
LIMIT 50;

-- DROP INDEX ix_comp_status_ref ON idx_lab;

-- -----------------------------------------------------------------------------
-- 4) Префіксний індекс — індекс лише з перших 16 символів sku (економія місця проти повного стовпця)
--    (співіснує з UNIQUE на повному sku; оптимізатор обирає відповідний доступ)
-- -----------------------------------------------------------------------------
CREATE INDEX ix_prefix_sku ON idx_lab (sku(16));

SELECT id
FROM idx_lab
WHERE id BETWEEN 1 AND 30
LIMIT 30;

-- DROP INDEX ix_prefix_sku ON idx_lab;

-- -----------------------------------------------------------------------------
-- 5) FULLTEXT-індекс (InnoDB) — MATCH … AGAINST
-- -----------------------------------------------------------------------------
ALTER TABLE idx_lab
  ADD FULLTEXT INDEX ix_ft_note (note);

-- Використайте слово, яке ймовірно зустрічається в назвах деталей; підлаштуйте під ваші дані
SELECT id, sku
FROM idx_lab
WHERE note IS NOT NULL
LIMIT 20;

-- DROP INDEX ix_ft_note ON idx_lab;  -- FULLTEXT: у деяких версіях DROP INDEX на (note) — якщо помилка: ALTER TABLE idx_lab DROP INDEX ix_ft_note;

-- -----------------------------------------------------------------------------
-- 6) Функціональний / за виразом індекс (MySQL 8.0.13+)
-- -----------------------------------------------------------------------------
CREATE INDEX ix_func_lower_sku ON idx_lab ((LOWER(sku)));

SELECT id
FROM idx_lab
WHERE LOWER(sku) LIKE CONCAT(LOWER(LEFT(@probe_sku, 3)), "%")
LIMIT 5;

-- DROP INDEX ix_func_lower_sku ON idx_lab;

-- =============================================================================
-- 7) SPATIAL-індекс — крихітна допоміжна таблиця (POINT + SPATIAL INDEX)
-- =============================================================================
CREATE TABLE idx_geo (
  id INT NOT NULL AUTO_INCREMENT,
  g  POINT NOT NULL SRID 4326,
  PRIMARY KEY (id),
  SPATIAL INDEX ix_spatial_g (g)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO idx_geo (g)
SELECT ST_PointFromText(
         CONCAT('POINT(', -10 + (l.id MOD 50) / 5.0, ' ', 40 + (l.id MOD 40) / 4.0, ')'),
         4326
       )
FROM idx_lab AS l
WHERE l.id <= 500;

SELECT id FROM idx_geo WHERE id BETWEEN 1 AND 3;

-- Фільтр у стилі bounding-box використовує просторовий індекс, де можливо
SELECT id
FROM idx_geo
WHERE MBRContains(
        ST_GeomFromText('POLYGON((-20 35, 20 35, 20 55, -20 55, -20 35))', 4326),
        g
      )
LIMIT 50;

-- =============================================================================
-- Розширене (MySQL 8+) — опціонально: DESC / INVISIBLE-індекс на ref_num
-- Запускайте лише після DROP INDEX ix_bt_ref …, якщо ви ще тримаєте цей btree-індекс.
-- =============================================================================
-- DROP INDEX ix_bt_ref ON idx_lab;
-- CREATE INDEX ix_bt_ref_desc ON idx_lab (ref_num DESC);
-- CREATE INDEX ix_inv_ref ON idx_lab (ref_num) INVISIBLE;
-- EXPLAIN SELECT id FROM idx_lab WHERE ref_num = @probe_ref;

-- =============================================================================
-- Опціональне прибирання — розкоментуйте, щоб повністю видалити лаб-таблиці
-- =============================================================================
-- DROP TABLE IF EXISTS idx_geo;
-- DROP TABLE IF EXISTS idx_lab;
