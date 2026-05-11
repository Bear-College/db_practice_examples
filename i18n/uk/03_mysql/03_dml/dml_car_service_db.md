# DML (Data Manipulation Language) — тема `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/03_dml/dml_car_service_db.md)

Ці вправи тренують усі команди формування рядків — `INSERT`, `UPDATE`, `DELETE`, `REPLACE`, upsert і транзакції — у **безпечній пісочниці** `dml_practice`. Демо-таблиці (`dml_demo_*`) повторюють форму реальних `customers`, `work_orders` та `loyalty_cards` з `01_database_mysql/car_service_db.sql.gz`, але живуть в окремій базі — production-дамп **не змінюється**.

Скрипт-компаньйон: [`03_dml/car_service_dml_examples.sql`](../../../../03_mysql/03_dml/car_service_dml_examples.sql).

```bash
mysql -u root < 03_mysql/03_dml/car_service_dml_examples.sql
```

Скрипт **ідемпотентний**: повторний запуск видаляє і знову створює демо-таблиці, заносить seed-дані і проходить усі вправи з чистого стану.

---

## Карта DML-команд (MySQL 8 / 9)

| Інструкція | Роль |
|---|---|
| `INSERT` | Додати нові рядки (одно-, багаторядкове, `INSERT … SELECT`) |
| `UPDATE` | Змінити наявні рядки (у реальному коді — завжди з `WHERE`) |
| `DELETE` | Видалити рядки (`WHERE`; уникайте випадкового видалення всієї таблиці) |
| `REPLACE` | MySQL-специфічне «видалити+вставити» при конфлікті PK/UNIQUE |
| `INSERT … ON DUPLICATE KEY UPDATE` | «Upsert»: вставити або оновити при дублюванні унікального ключа |
| `START TRANSACTION` / `COMMIT` / `ROLLBACK` | Групує DML так, що або всі застосовуються, або жодна |

**Зазвичай не DML:** `SELECT` іноді відносять до DQL; `TRUNCATE` часто групують із DDL, бо потребує право `DROP`.

---

## Точки дотику зі схемою (з реального дампу)

Ідеї, відображені в демо-таблицях:

- **`customers`** — імена, `email`, унікальність на e-mail.
- **`work_orders`** — `status` (`new`, `in_progress`, `completed`, `waiting_parts`, `cancelled`), `total_cost` як `DECIMAL(12,2)`.
- **`loyalty_cards`** — `points`. Для `UPDATE`/upsert додано стовпець `points` у демо-customers.

Після виконання Вправи 1 пісочниця має такий вигляд — далі кожна вправа її змінює:

```text
+----+------------+-----------+-------------------------+--------+
| id | first_name | last_name | email                   | points |
+----+------------+-----------+-------------------------+--------+
|  1 | Ada        | Morgan    | ada.morgan@example.com  |    100 |
|  2 | Ben        | Ortega    | ben.ortega@example.com  |     50 |
|  3 | Cara       | Nguyen    | cara.nguyen@example.com |      0 |
+----+------------+-----------+-------------------------+--------+

+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | new           |     120.00 |
|  2 |           1 | completed     |     450.75 |
|  3 |           2 | in_progress   |     200.00 |
|  4 |           2 | cancelled     |       0.00 |
|  5 |           3 | waiting_parts |     300.25 |
+----+-------------+---------------+------------+
```

---

## Вправа 1 — Налаштування пісочниці

### Контекст

Перш ніж практикувати DML, потрібен ізольований майданчик, який не зіпсує реальний `car_service_db`. Будуємо невеличку модель з трьох таблиць і засіюємо її рядками, які наступні вправи мутуватимуть.

### Чого ви навчитеся

- Розділення між **мінімальним DDL** (для хостингу лабораторії) і власне **DML**, який ви відпрацьовуєте.
- `UNIQUE KEY uk_dml_demo_customers_email (email)` — обмеження, що уможливлює upsert у Вправі 8.
- Foreign key з `ON DELETE RESTRICT`, що захищає від «висячих» замовлень.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_customers` | `id`, `first_name`, `last_name`, `email` (`UNIQUE`), `points` |
| `dml_demo_work_orders` | `id`, `customer_id` (FK), `status`, `total_cost` |
| `dml_demo_customer_staging` | `id`, `first_name`, `last_name`, `email`, `points`, `snapshot_at` |

### Завдання

Створити пісочницю-БД, три демо-таблиці, засіяти клієнтів 1–3 і замовлення 1–5.

### Очікуваний результат (після seed-у)

```text
+----+------------+-----------+-------------------------+--------+
| id | first_name | last_name | email                   | points |
+----+------------+-----------+-------------------------+--------+
|  1 | Ada        | Morgan    | ada.morgan@example.com  |    100 |
|  2 | Ben        | Ortega    | ben.ortega@example.com  |     50 |
|  3 | Cara       | Nguyen    | cara.nguyen@example.com |      0 |
+----+------------+-----------+-------------------------+--------+
```

### Підказка

`CREATE DATABASE … utf8mb4`, потім `CREATE TABLE … UNIQUE KEY … (email)`, потім кілька `INSERT … VALUES …`.

### Розв'язання

```sql
CREATE DATABASE IF NOT EXISTS dml_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE dml_practice;

SET foreign_key_checks = 0;
DROP TABLE IF EXISTS dml_demo_work_orders;
DROP TABLE IF EXISTS dml_demo_customer_staging;
DROP TABLE IF EXISTS dml_demo_customers;
SET foreign_key_checks = 1;

CREATE TABLE dml_demo_customers (
  id            INT NOT NULL AUTO_INCREMENT,
  first_name    VARCHAR(50) NOT NULL,
  last_name     VARCHAR(50) NOT NULL,
  email         VARCHAR(100) NOT NULL,
  points        INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_dml_demo_customers_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE dml_demo_work_orders (
  id            INT NOT NULL AUTO_INCREMENT,
  customer_id   INT NOT NULL,
  status        VARCHAR(20) NOT NULL,
  total_cost    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (id),
  KEY idx_dml_wo_customer (customer_id),
  CONSTRAINT fk_dml_wo_customer
    FOREIGN KEY (customer_id) REFERENCES dml_demo_customers (id)
      ON UPDATE CASCADE
      ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE dml_demo_customer_staging (
  id            INT NOT NULL AUTO_INCREMENT,
  first_name    VARCHAR(50) NOT NULL,
  last_name     VARCHAR(50) NOT NULL,
  email         VARCHAR(100) NOT NULL,
  points        INT NOT NULL DEFAULT 0,
  snapshot_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO dml_demo_customers (first_name, last_name, email, points) VALUES
  ('Ada', 'Morgan', 'ada.morgan@example.com', 100),
  ('Ben', 'Ortega', 'ben.ortega@example.com', 50),
  ('Cara', 'Nguyen', 'cara.nguyen@example.com', 0);

INSERT INTO dml_demo_work_orders (customer_id, status, total_cost) VALUES
  (1, 'new', 120.00),
  (1, 'completed', 450.75),
  (2, 'in_progress', 200.00),
  (2, 'cancelled', 0.00),
  (3, 'waiting_parts', 300.25);
```

### Покрокове пояснення

1. **`SET foreign_key_checks = 0`** дає змогу видаляти таблиці в будь-якому порядку. Одразу після цього поверніть `= 1`.
2. **`UNIQUE KEY (email)`** критичне: воно вмикає upsert у Вправі 8 і коректну семантику `REPLACE` у Вправі 9.
3. **`fk_dml_wo_customer ON DELETE RESTRICT`** не дає видалити клієнта, якщо за ним ще є замовлення — безпечний default для СТО.
4. **Маленький seed** (3 клієнти, 5 замовлень) — щоб кожну подальшу мутацію легко перевіряти оком.

---

## Вправа 2 — `INSERT` одного рядка

### Контекст

Застосунок приймальні створює нову картку клієнта, поки людина стоїть біля каси. Заходить рівно один рядок.

### Чого ви навчитеся

- Явна форма `INSERT INTO t (a, b, c) VALUES (…)` — безпечна для production.
- Чому пропуск списку колонок крихкий.
- Як `LAST_INSERT_ID()` повертає новий auto-increment id.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_customers` | `first_name`, `last_name`, `email`, `points` |

### Завдання

Вставити одного клієнта (Дмитро Волков, 25 балів) у `dml_demo_customers`.

### Очікуваний результат (новий рядок, `id = 4`)

```text
+----+------------+-----------+---------------------------+--------+
| id | first_name | last_name | email                     | points |
+----+------------+-----------+---------------------------+--------+
|  4 | Dmitri     | Volkov    | dmitri.volkov@example.com |     25 |
+----+------------+-----------+---------------------------+--------+
```

### Підказка

`INSERT INTO dml_demo_customers (first_name, last_name, email, points) VALUES (…);` — `id` проставить `AUTO_INCREMENT`.

### Розв'язання

```sql
INSERT INTO dml_demo_customers (first_name, last_name, email, points)
VALUES ('Dmitri', 'Volkov', 'dmitri.volkov@example.com', 25);
```

### Покрокове пояснення

1. **Перелічуйте колонки явно.** Це ізолює запит від майбутніх змін схеми — додавання nullable-колонки не зламає наявний `INSERT`.
2. **Auto-increment** прихований: `id` не передаємо, MySQL сам бере наступне значення (тут `4`) і запам'ятовує його у `LAST_INSERT_ID()`.
3. **Колонки з default** (тут немає) підхопляться автоматично — перелічувати треба лише ті, які ви задаєте.
4. **Одна-рядкова `INSERT` — це неявна транзакція.** Збій (дубль email, FK) відкочує рядок; «половини рядка» не буває.

---

## Вправа 3 — `INSERT` кількох рядків

### Контекст

Batch-імпорт CRM завантажує одразу двох нових клієнтів і відкриває одне замовлення для одного з них — типовий випадок завантаження CSV.

### Чого ви навчитеся

- Форма `VALUES (…), (…)` (один round-trip, один burst auto-increment).
- `INSERT … SELECT`, щоб витягти `customer_id` з іншого `SELECT` без хардкоду.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_customers` | (отримує 2 нових рядки) |
| `dml_demo_work_orders` | (отримує 1 рядок для Елени) |

### Завдання

Додати Елену і Фелікса в customers; потім додати нове `new`-замовлення для Елени через `INSERT … SELECT`.

### Очікуваний результат (`dml_demo_work_orders` після двох insert-ів — рядок 6 новий)

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | new           |     120.00 |
|  2 |           1 | completed     |     450.75 |
|  3 |           2 | in_progress   |     200.00 |
|  4 |           2 | cancelled     |       0.00 |
|  5 |           3 | waiting_parts |     300.25 |
|  6 |           5 | new           |      40.00 |
+----+-------------+---------------+------------+
```

### Підказка

Для customers: `INSERT INTO t (…) VALUES (…), (…);`. Для work order: `INSERT INTO t (…) SELECT … FROM customers WHERE email = '…';`.

### Розв'язання

```sql
INSERT INTO dml_demo_customers (first_name, last_name, email, points) VALUES
  ('Elena', 'Park', 'elena.park@example.com', 10),
  ('Felix', 'Brown', 'felix.brown@example.com', 10);

INSERT INTO dml_demo_work_orders (customer_id, status, total_cost)
SELECT id, 'new', 40.00
FROM dml_demo_customers
WHERE email = 'elena.park@example.com'
LIMIT 1;
```

### Покрокове пояснення

1. **Багаторядковий `VALUES`** **значно** швидший за два окремі `INSERT` — один парсинг, один round-trip, один журнал.
2. **`INSERT … SELECT`** — робочий конячок ETL. Тут ми витягуємо щойно згенерований `id` Елени, не знаючи числа — стійко до повторного запуску.
3. **`LIMIT 1`** у `SELECT` — параноя: `email` уже унікальне, тож більш як один рядок не може збігтися. Але краще явно.

---

## Вправа 4 — `UPDATE` з `WHERE`

### Контекст

Кара щойно привела подругу; програма лояльності нараховує 50 балів. Треба збільшити саме її рядок.

### Чого ви навчитеся

- `UPDATE … SET col = col + n` — відносне оновлення без попереднього читання значення.
- Чому **кожен** `UPDATE` у production має містити `WHERE`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_customers` | `points` |

### Завдання

Збільшити Карі бали на 50, ідентифікуючи за email.

### Очікуваний результат (рядок Кари до й після)

```text
+----+------------+-----------+-------------------------+--------+
| id | first_name | last_name | email                   | points |
+----+------------+-----------+-------------------------+--------+
|  3 | Cara       | Nguyen    | cara.nguyen@example.com |     50 |
+----+------------+-----------+-------------------------+--------+
```

(До: `0`; після `+50`: `50`.)

### Підказка

`UPDATE dml_demo_customers SET points = points + 50 WHERE email = '…';`

### Розв'язання

```sql
UPDATE dml_demo_customers
SET points = points + 50
WHERE email = 'cara.nguyen@example.com';
```

### Покрокове пояснення

1. **Відносна арифметика в `SET`** (`points = points + 50`) усуває гонитву даних: не доводиться спершу читати значення в програмі.
2. **`WHERE email = …`** ідентифікує один рядок, бо `email` `UNIQUE`. Без `WHERE` ви б нарахували 50 балів **кожному** клієнту.
3. **Safe-update mode** (`SET SQL_SAFE_UPDATES = 1;`) у клієнті MySQL відмовляє `UPDATE`/`DELETE` без `WHERE` по ключу. Дешева страховка.

---

## Вправа 5 — `UPDATE` кількох стовпців

### Контекст

Замовлення №3 закрите — механік ставить підсумкову суму і змінює статус із `in_progress` на `completed`. Два стовпці, один стейтмент.

### Чого ви навчитеся

- Форма `SET col1 = v1, col2 = v2`.
- Додати **захисний предикат** (`AND customer_id = 2`), щоб одруківка в id не зачепила чужого замовлення.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_work_orders` | `status`, `total_cost` |

### Завдання

Поставити `status='completed'` і `total_cost=199.99` для рядка з `id=3` та `customer_id=2`.

### Очікуваний результат

```text
+----+-------------+-----------+------------+
| id | customer_id | status    | total_cost |
+----+-------------+-----------+------------+
|  3 |           2 | completed |     199.99 |
+----+-------------+-----------+------------+
```

### Підказка

Список присвоєнь через кому; складене `WHERE id = 3 AND customer_id = 2`.

### Розв'язання

```sql
UPDATE dml_demo_work_orders
SET status = 'completed',
    total_cost = 199.99
WHERE id = 3 AND customer_id = 2;
```

### Покрокове пояснення

1. **Список `SET` через кому** обчислюється **до** запису рядка, тож праворуч можна посилатися на старі значення без сюрпризів.
2. **Захисний `AND customer_id = 2`.** Якщо ви випадково написали `id = 33`, неспівпадіння клієнта врятує — жоден рядок не оновиться.
3. **`DECIMAL`-літерали не потребують лапок.** `total_cost = '199.99'` теж спрацює, але провокує імпліцитний каст у парсера.

---

## Вправа 6 — `DELETE` з `WHERE`

### Контекст

Скасовані замовлення засмічують дашборд каси. Прибираємо їх щоночі.

### Чого ви навчитеся

- `DELETE FROM t WHERE …`.
- Чому **завжди** ставити `WHERE` (і як перевірити кількість через `SELECT COUNT(*)`).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_work_orders` | `status` |

### Завдання

Видалити кожне замовлення зі `status = 'cancelled'`.

### Очікуваний результат (після видалення — рядок `id=4` зник)

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | new           |     120.00 |
|  2 |           1 | completed     |     450.75 |
|  3 |           2 | completed     |     199.99 |
|  5 |           3 | waiting_parts |     300.25 |
|  6 |           5 | new           |      40.00 |
+----+-------------+---------------+------------+
```

### Підказка

`DELETE FROM dml_demo_work_orders WHERE status = 'cancelled';`

### Розв'язання

```sql
DELETE FROM dml_demo_work_orders
WHERE status = 'cancelled';
```

### Покрокове пояснення

1. **Спочатку перевір.** Перед `DELETE` запустіть `SELECT COUNT(*) FROM dml_demo_work_orders WHERE status = 'cancelled';`, щоб побачити, скільки рядків зникне.
2. **Auto-increment id не перевикористовуються.** `id = 4` зник; наступний `INSERT` отримає `7`, а не `4`.
3. **`DELETE` логується по-рядковому** — `TRUNCATE` швидший для «зачистити все», але не приймає `WHERE`.

---

## Вправа 7 — `INSERT … SELECT`

### Контекст

Щотижнева задача копіює «цінних» клієнтів (≥ 50 балів) у staging-таблицю, щоб аналітика їх крутила без блокування живої таблиці.

### Чого ви навчитеся

- Повний ETL-шаблон: читати з однієї таблиці, писати в іншу, з фільтром `WHERE`.
- Що цільові й вихідні колонки матчаться **позиційно**, не за іменем.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_customers` (джерело) | `first_name`, `last_name`, `email`, `points` |
| `dml_demo_customer_staging` (ціль) | `first_name`, `last_name`, `email`, `points` (+ авто `snapshot_at`) |

### Завдання

Скопіювати кожного клієнта з `points >= 50` у `dml_demo_customer_staging`.

### Очікуваний результат (staging після копіювання)

```text
+----+------------+-----------+-------------------------+--------+---------------------+
| id | first_name | last_name | email                   | points | snapshot_at         |
+----+------------+-----------+-------------------------+--------+---------------------+
|  1 | Ada        | Morgan    | ada.morgan@example.com  |    100 | 2026-05-11 16:58:03 |
|  2 | Ben        | Ortega    | ben.ortega@example.com  |     50 | 2026-05-11 16:58:03 |
|  3 | Cara       | Nguyen    | cara.nguyen@example.com |     50 | 2026-05-11 16:58:03 |
+----+------------+-----------+-------------------------+--------+---------------------+
```

### Підказка

`INSERT INTO target (cols) SELECT cols FROM source WHERE …;`. `snapshot_at` заповнить `DEFAULT CURRENT_TIMESTAMP`.

### Розв'язання

```sql
INSERT INTO dml_demo_customer_staging (first_name, last_name, email, points)
SELECT first_name, last_name, email, points
FROM dml_demo_customers
WHERE points >= 50;
```

### Покрокове пояснення

1. **Списки колонок матчаться позиційно.** `SELECT first_name, last_name, …` має дзеркалити цільове `(first_name, last_name, …)`.
2. **`snapshot_at` заповнюється автоматично** через `DEFAULT CURRENT_TIMESTAMP` — усі рядки staging отримують ту саму мить часу.
3. **Хочете лише «нові» рядки?** Додайте `LEFT JOIN target … WHERE target.id IS NULL` або обгорніть `ON DUPLICATE KEY UPDATE` (Вправа 8).

---

## Вправа 8 — `INSERT … ON DUPLICATE KEY UPDATE` (upsert)

### Контекст

Щоденна синхронізація CRM присилає рядки клієнтів. Якщо email уже в системі — не хочемо дубля; хочемо **нарахувати бали і оновити прізвище**.

### Чого ви навчитеся

- `INSERT … ON DUPLICATE KEY UPDATE …` — атомарний upsert.
- Псевдо-функція `VALUES(col)`, що повертає значення, яке *мало б* бути вставлене.
- Чому потрібен `UNIQUE` (чи PK), щоб спрацював upsert.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_customers` | `email` (`UNIQUE`), `points`, `last_name` |

### Завдання

Спробувати вставити Ada Morgan-Smith / `ada.morgan@example.com` / 999 балів. Оскільки email уже існує, **оновити**: `points += 25` і `last_name = 'Morgan-Smith'`.

### Очікуваний результат (рядок Ади після upsert-у)

```text
+----+------------+--------------+------------------------+--------+
| id | first_name | last_name    | email                  | points |
+----+------------+--------------+------------------------+--------+
|  1 | Ada        | Morgan-Smith | ada.morgan@example.com |    125 |
+----+------------+--------------+------------------------+--------+
```

Примітка: `points = 100 + 25 = 125`; `last_name` змінилося з `Morgan` на `Morgan-Smith`. Літерал `999` з `VALUES` **відкидається** через конфлікт.

### Підказка

Після `VALUES (…)` додайте `ON DUPLICATE KEY UPDATE points = points + 25, last_name = VALUES(last_name)`.

### Розв'язання

```sql
INSERT INTO dml_demo_customers (first_name, last_name, email, points)
VALUES ('Ada', 'Morgan-Smith', 'ada.morgan@example.com', 999)
ON DUPLICATE KEY UPDATE
  points = points + 25,
  last_name = VALUES(last_name);
```

### Покрокове пояснення

1. **Умова спрацювання.** MySQL виявляє конфлікт за `UNIQUE` (`email`); якби обмеження не було, вставився б ще один рядок з тим самим email.
2. **`VALUES(last_name)`** повертає значення з блоку `VALUES`, яке *мало б* бути вставлене (`'Morgan-Smith'`). MySQL 8.0.20+ рекомендує форму з аліасом `INSERT … AS new ON DUPLICATE KEY UPDATE last_name = new.last_name`, але `VALUES(col)` досі працює і подається в більшості підручників.
3. **«Згоряння» auto-increment.** Хоч новий рядок і не з'явився, наступне `AUTO_INCREMENT` може просунутися (залежить від движка). Не покладайтесь на безперервність id.

---

## Вправа 9 — `REPLACE INTO`

### Контекст

Чистка коригує замовлення №1 на свіжу канонічну версію — той самий id, нові поля. `REPLACE` — це MySQL-ідіома «видалити старий рядок, вставити новий».

### Чого ви навчитеся

- Семантика `REPLACE INTO`: **delete + insert** при конфлікті PK/UNIQUE; інакше — звичайна вставка.
- Чому `REPLACE` — це **не** `UPDATE` (тригери, FK і AUTO_INCREMENT бачать дві події).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_work_orders` | `id`, `customer_id`, `status`, `total_cost` |

### Завдання

Замінити рядок із `id = 1`, поставити `status = 'in_progress'` і `total_cost = 130.50`.

### Очікуваний результат

```text
+----+-------------+-------------+------------+
| id | customer_id | status      | total_cost |
+----+-------------+-------------+------------+
|  1 |           1 | in_progress |     130.50 |
+----+-------------+-------------+------------+
```

### Підказка

`REPLACE INTO dml_demo_work_orders (id, customer_id, status, total_cost) VALUES (1, 1, 'in_progress', 130.50);`

### Розв'язання

```sql
REPLACE INTO dml_demo_work_orders (id, customer_id, status, total_cost)
VALUES (1, 1, 'in_progress', 130.50);
```

### Покрокове пояснення

1. **Delete + insert, не update.** Тригери `BEFORE DELETE` / `AFTER INSERT` спрацьовують; рядок отримує нову фізичну позицію; каскадні FK на старий рядок активуються.
2. **Незазначені колонки скидаються до default.** Забути колонку в `REPLACE` — затерти старе значення; класичний footgun. `UPDATE` чіпає лише вказані.
3. **Замість цього використовуйте `INSERT … ON DUPLICATE KEY UPDATE`**, якщо хочете зберегти не вказані колонки. `REPLACE` рідко є правильним вибором у сучасних схемах.

---

## Вправа 10 — Транзакція + `ROLLBACK`

### Контекст

У рядок Бена ненароком потрапляє багова корекція `-1000`. Зловлюємо помилку всередині транзакції; `ROLLBACK` скасовує її, навіть не показавши зовнішнім сесіям.

### Чого ви навчитеся

- Тріо транзакції: `START TRANSACTION`, `ROLLBACK`, `COMMIT`.
- Що **autocommit** у MySQL увімкнено за замовчуванням — для можливості відкату треба явно відкрити транзакцію.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_customers` | `points` |

### Завдання

Відкрити транзакцію, відняти 1000 у Бена, перевірити значення всередині (`points = -950`), потім `ROLLBACK`.

### Очікуваний результат (після rollback — points повернулися до 50)

```text
+----+------------+-----------+------------------------+--------+
| id | first_name | last_name | email                  | points |
+----+------------+-----------+------------------------+--------+
|  2 | Ben        | Ortega    | ben.ortega@example.com |     50 |
+----+------------+-----------+------------------------+--------+
```

(Усередині транзакції `points` тимчасово дорівнював `-950`; після `ROLLBACK` повернувся до 50.)

### Підказка

`START TRANSACTION; UPDATE …; -- перевірка; ROLLBACK;`

### Розв'язання

```sql
START TRANSACTION;
UPDATE dml_demo_customers SET points = points - 1000 WHERE email = 'ben.ortega@example.com';
-- Усередині транзакції видно баг (від'ємне значення):
SELECT id, first_name, points FROM dml_demo_customers WHERE email = 'ben.ortega@example.com';
ROLLBACK;
```

### Покрокове пояснення

1. **InnoDB транзакційний**; MyISAM — ні. Якщо «`REPLACE INTO`» потрапить у MyISAM-таблицю, `ROLLBACK` не врятує.
2. **Читай свої записи.** Усередині транзакції сесія бачить свої незакомічені зміни (`points = -950`); інші сесії бачать ще старе значення.
3. **`ROLLBACK` швидкий, але не безкоштовний.** Довгі транзакції тримають undo-записи; не затягуйте їх — інакше зростає InnoDB history list.

---

## Вправа 11 — Транзакція + `COMMIT`

### Контекст

Легітимний бонус +5 балів Феліксу. Загортаємо у транзакцію, щоб перевірити і закомітити — стандартний production-шаблон навіть для одностейтментної зміни.

### Чого ви навчитеся

- `COMMIT` робить зміни довговічними й видимими для інших сесій.
- Що `START TRANSACTION` обходить випадково «застряглий» autocommit.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_customers` | `points` |

### Завдання

Усередині транзакції нарахувати Феліксу `+5` балів і закомітити.

### Очікуваний результат (після `COMMIT` — points зросло з 10 до 15)

```text
+----+------------+-----------+-------------------------+--------+
| id | first_name | last_name | email                   | points |
+----+------------+-----------+-------------------------+--------+
|  6 | Felix      | Brown     | felix.brown@example.com |     15 |
+----+------------+-----------+-------------------------+--------+
```

### Підказка

`START TRANSACTION; UPDATE …; COMMIT;`

### Розв'язання

```sql
START TRANSACTION;
UPDATE dml_demo_customers SET points = points + 5 WHERE email = 'felix.brown@example.com';
COMMIT;
```

### Покрокове пояснення

1. **`COMMIT`** пише зміну в redo-лог і розблоковує конкурентні читачі, що чекали на row-level блокування.
2. **Порожня транзакція — це no-op.** `START TRANSACTION; COMMIT;` валідне, але марне; на деяких конфігураціях коштує запис в журнал.
3. **Розрив з'єднання = неявний `ROLLBACK`.** Якщо клієнт відключиться між `START TRANSACTION` і `COMMIT`, сервер відкине незакомічене — фіча, яка рятує від випадкових півкомітів.

---

## Вправа 12 — `DELETE` зі з'єднанням

### Контекст

Річна чистка: видаляємо незавершені низькопріоритетні замовлення (`new`/`waiting_parts`) для клієнтів із менш ніж 15 балами лояльності. Умова — на `customers`, але видаляти треба в `work_orders`.

### Чого ви навчитеся

- Багатотабличний `DELETE` у MySQL: `DELETE alias FROM table1 JOIN table2 ON … WHERE …`.
- Який саме аліас після `DELETE` визначає, **з якої** таблиці видаляються рядки.

### Задіяні таблиці

| Таблиця | Роль |
|---|---|
| `dml_demo_work_orders` | (ціль `DELETE`) |
| `dml_demo_customers` | джерело умови по `points` |

### Завдання

Видалити замовлення з умовою: `c.points < 15 AND wo.status IN ('new','waiting_parts')`.

### Очікуваний результат (замовлення Елени id=6 зникає — у неї 10 балів, статус `new`)

До:

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | in_progress   |     130.50 |
|  2 |           1 | completed     |     450.75 |
|  3 |           2 | completed     |     199.99 |
|  5 |           3 | waiting_parts |     300.25 |   <- Cara 50 балів, лишається
|  6 |           5 | new           |      40.00 |   <- Elena 10 балів, видаляється
+----+-------------+---------------+------------+
```

Після:

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | in_progress   |     130.50 |
|  2 |           1 | completed     |     450.75 |
|  3 |           2 | completed     |     199.99 |
|  5 |           3 | waiting_parts |     300.25 |
+----+-------------+---------------+------------+
```

### Підказка

`DELETE wo FROM dml_demo_work_orders wo JOIN dml_demo_customers c ON c.id = wo.customer_id WHERE c.points < 15 AND wo.status IN ('new','waiting_parts');`

### Розв'язання

```sql
DELETE wo
FROM dml_demo_work_orders AS wo
INNER JOIN dml_demo_customers AS c ON c.id = wo.customer_id
WHERE c.points < 15
  AND wo.status IN ('new', 'waiting_parts');
```

### Покрокове пояснення

1. **`DELETE wo`** іменує аліас, з якого видаляємо. `DELETE c` стер би клієнтів (не те), `DELETE wo, c` видалив би з обох.
2. **`INNER JOIN`** обмежує `DELETE` лише тими рядками, у яких є відповідний клієнт. `LEFT JOIN` залишив би в кадрі також «осирочені» замовлення.
3. **Один стейтмент — атомарне видалення.** Без `DELETE … JOIN` довелося б писати два запити з ризиком часткового видалення між ними.

---

## Вправа 13 — `UPDATE` зі з'єднанням

### Контекст

Правило для VIP-лояльності: усі активні замовлення клієнта з ≥ 100 балами отримують 5 %-знижку. Розрахунок використовує `points` (з `customers`), а пише у `work_orders`.

### Чого ви навчитеся

- `UPDATE t JOIN s ON … SET t.col = … WHERE …` — багатотабличний `UPDATE`.
- Виразам у `SET` (`ROUND(wo.total_cost * 0.95, 2)`).

### Задіяні таблиці

| Таблиця | Роль |
|---|---|
| `dml_demo_work_orders` | (тут оновлюється `total_cost`) |
| `dml_demo_customers` | джерело умови по `points` |

### Завдання

Для кожного нескасованого замовлення клієнта з `points >= 100` помножити `total_cost` на `0.95` (округлити до 2 знаків).

### Очікуваний результат (в Ади 125 балів, тож wo 1 і wo 2 отримують знижку)

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | in_progress   |     123.98 |   <- було 130.50 -> 130.50*0.95
|  2 |           1 | completed     |     428.21 |   <- було 450.75 -> 450.75*0.95
|  3 |           2 | completed     |     199.99 |   (Ben 50 балів; не змінено)
|  5 |           3 | waiting_parts |     300.25 |   (Cara 50 балів; не змінено)
+----+-------------+---------------+------------+
```

### Підказка

`UPDATE wo JOIN c ON c.id = wo.customer_id SET wo.total_cost = ROUND(wo.total_cost * 0.95, 2) WHERE c.points >= 100 AND wo.status NOT IN ('cancelled');`

### Розв'язання

```sql
UPDATE dml_demo_work_orders AS wo
INNER JOIN dml_demo_customers AS c ON c.id = wo.customer_id
SET wo.total_cost = ROUND(wo.total_cost * 0.95, 2)
WHERE c.points >= 100
  AND wo.status NOT IN ('cancelled');
```

### Покрокове пояснення

1. **Без `FROM`** у багатотабличному `UPDATE` — одразу `JOIN` після `UPDATE`.
2. **`ROUND(x, 2)`** округлює half-up до двох знаків; зберігання `DECIMAL(12,2)` теж округлило б, але явне округлення робить результат детермінованим у різних версіях MySQL.
3. **`status NOT IN ('cancelled')`** еквівалентне `status <> 'cancelled'`, але форма з `IN` природно масштабується на кілька статусів.

---

## Вправа 14 — Умовний багаторядковий `UPDATE` (`CASE`)

### Контекст

Кінець дня — додаємо до кожного відкритого замовлення додатковий збір залежно від статусу. Різний статус — різний додаток, але один стейтмент.

### Чого ви навчитеся

- `SET col = CASE other_col WHEN … THEN … ELSE … END`.
- Чому один `CASE` краще за кілька умовних `UPDATE` (одне сканування, атомарність).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `dml_demo_work_orders` | `status`, `total_cost` |

### Завдання

Скоригувати `total_cost` залежно від статусу: `new +25`, `in_progress +15`, `completed без змін`, `waiting_parts +10`. Застосувати до всіх рядків з не-`NULL` статусом.

### Очікуваний результат (поверх стану після Вправи 13)

```text
+----+-------------+---------------+------------+
| id | customer_id | status        | total_cost |
+----+-------------+---------------+------------+
|  1 |           1 | in_progress   |     138.98 |   <- 123.98 + 15
|  2 |           1 | completed     |     428.21 |   <- без змін
|  3 |           2 | completed     |     199.99 |   <- без змін
|  5 |           3 | waiting_parts |     310.25 |   <- 300.25 + 10
+----+-------------+---------------+------------+
```

### Підказка

`UPDATE t SET col = CASE other_col WHEN 'a' THEN … WHEN 'b' THEN … ELSE … END WHERE …;`

### Розв'язання

```sql
UPDATE dml_demo_work_orders
SET total_cost = CASE status
  WHEN 'new'           THEN ROUND(total_cost + 25, 2)
  WHEN 'in_progress'   THEN ROUND(total_cost + 15, 2)
  WHEN 'completed'     THEN total_cost
  WHEN 'waiting_parts' THEN ROUND(total_cost + 10, 2)
  ELSE total_cost
END
WHERE status IS NOT NULL;
```

### Покрокове пояснення

1. **`CASE col WHEN x THEN …`** — «простий» `CASE`; «пошуковий» `CASE WHEN col = x THEN …` гнучкіший, але багатослівний. Обирайте, що читабельніше.
2. **`ELSE total_cost`** — захист від нового статусу, про який MySQL ще не знає; ніколи не пишіть `CASE` без `ELSE`.
3. **Один стейтмент, одне сканування.** П'ять окремих `UPDATE` робили б по повному скану таблиці; один `CASE` проходить раз і диспетчує в пам'яті.

---

## Діагностика: моя DML повелася дивно

| Симптом | Імовірне виправлення |
|---|---|
| `UPDATE` оновив 0 рядків | `WHERE` занадто строгий — спершу запустіть відповідний `SELECT`, щоб перевірити вибірку. |
| `Cannot delete or update a parent row: a foreign key constraint fails` | На рядок ще посилаються нащадки. Видаліть їх першими або змініть дію FK. |
| `INSERT IGNORE` мовчки втратив рядок | `IGNORE` ковтає реальні помилки (трункація, FK, unique). Дивіться `SHOW WARNINGS`. |
| Upsert не спрацював | На очікуваному стовпці немає `UNIQUE`. |
| Транзакція «не працює» | Таблиця не InnoDB, або autocommit увімкнено без `START TRANSACTION`. |
| `REPLACE` втратив значення колонки | `REPLACE` скидає не вказані колонки до default — переходьте на `INSERT … ON DUPLICATE KEY UPDATE`. |

Перезапустити всю лабораторію: `mysql -u root < 03_mysql/03_dml/car_service_dml_examples.sql`. Скрипт перестворює пісочницю, тож запускати його можна скільки завгодно разів.
