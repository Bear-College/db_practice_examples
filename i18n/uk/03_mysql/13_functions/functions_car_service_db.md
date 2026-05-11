# Вбудовані функції — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/13_functions/functions_car_service_db.md)

Ці вправи проходять поширені **вбудовані функції MySQL** — рядкові, числові, дати, умовні, регулярні вирази та агрегатні помічники — на справжній базі з **`01_database_mysql/car_service_db.sql.gz`** (ім'я бази: **`car_service_db`**). Це **не** збережені процедури (`CREATE FUNCTION`); це окрема тема.

Готові запити лежать у файлі-компаньйоні: [`13_functions/car_service_functions_examples.sql`](../../../../03_mysql/13_functions/car_service_functions_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/13_functions/car_service_functions_examples.sql
```

**Продуктивність:** великі таблиці фільтруються через **`WHERE id BETWEEN …`** / **`LIMIT`**, щоб запити лишалися швидкими.

---

## Швидкий довідник

| Секція | Функції |
|---|---|
| **F1** Рядки | `CONCAT`, `UPPER`, `LOWER`, `SUBSTRING` (proper-case) |
| **F2** Довжина і нарізка | `LENGTH`, `LEFT`, `RIGHT`, `SUBSTRING` |
| **F3** Очищення рядків | `TRIM`, `REPLACE` |
| **F4** Числові | `ROUND`, `CEILING`, `FLOOR`, `ABS`, `MOD` |
| **F5** Дата / час | `DATE_FORMAT`, `YEAR`, `TIMESTAMPDIFF`, `NOW()`, `CURDATE()` |
| **F6** Умовні | `IF`, `IFNULL`, `NULLIF`, `COALESCE` |
| **F7** Min / max по рядку | `GREATEST`, `LEAST` |
| **F8** Форматування чисел | `FORMAT` |
| **F9** Шаблони | `REGEXP` / `RLIKE` |
| **F10** Агрегатний помічник | `GROUP_CONCAT` (з `GROUP BY`) |
| **T1–T6** | Комплексні «сервісні» задачі, що поєднують усе вище |

### Зауваження

- `NOW()` та `CURDATE()` змінюються з годинником; очікувані результати, що залежать від дат, відрізнятимуться при повторному запуску за кілька тижнів.
- Поведінка `REGEXP` залежить від колації і версії. Дамп використовує `utf8mb4_0900_ai_ci` — за замовчуванням **нечутливу до регістру** (важливо для F9).
- `GROUP_CONCAT` обрізається до **`group_concat_max_len`** байтів (за замовчуванням `1024`). Для великих груп зробіть `SET SESSION group_concat_max_len = 16384;` перед запитом.

---

## Точки дотику зі схемою (з дампу)

- **`customers`** — `id`, `first_name`, `last_name`, `email`, `phone`
- **`parts`** — `id`, `sku`, `name`
- **`vehicles`** — `id`, `plate`, `car`
- **`work_orders`** — `id`, `status`, `total_cost`, `vehicle_id`
- **`appointments`** — `id`, `scheduled_at`

---

## Вправа F1 — Рядки: `CONCAT`, `UPPER`, `LOWER`, proper-case

### Контекст

CRM експортує списки клієнтів у трьох стилях, залежно від споживача: один `full_name`, e-mail у нижньому регістрі для дедуплікації, прізвище у верхньому для друкованих наліпок і proper-case прізвище для листів «Welcome, Surname_1». Усе вкладається в один `SELECT`.

### Чого ви навчитеся

- `CONCAT(a, b, c)` склеює рядки; якщо хоч один аргумент `NULL` — **результат `NULL`** (для «пропусти NULL» — `CONCAT_WS`).
- `UPPER(s)` і `LOWER(s)` — стандартні перетворювачі регістру.
- Ідіома proper-case: `CONCAT(UPPER(LEFT(s,1)), LOWER(SUBSTRING(s,2)))`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `customers` | `id`, `first_name`, `last_name`, `email` |

### Завдання

Для `customers` з `id BETWEEN 1 AND 150` повернути `id`, `full_name`, `email_lower`, `last_upper`, `last_proper`. Обмежити 20.

### Очікуваний результат

```text
+----+------------------+-----------------------+------------+-------------+
| id | full_name        | email_lower           | last_upper | last_proper |
+----+------------------+-----------------------+------------+-------------+
|  1 | Name_1 Surname_1 | customer1@example.com | SURNAME_1  | Surname_1   |
|  2 | Name_2 Surname_2 | customer2@example.com | SURNAME_2  | Surname_2   |
|  3 | Name_3 Surname_3 | customer3@example.com | SURNAME_3  | Surname_3   |
|  4 | Name_4 Surname_4 | customer4@example.com | SURNAME_4  | Surname_4   |
|  5 | Name_5 Surname_5 | customer5@example.com | SURNAME_5  | Surname_5   |
|  6 | Name_6 Surname_6 | customer6@example.com | SURNAME_6  | Surname_6   |
|  7 | Name_7 Surname_7 | customer7@example.com | SURNAME_7  | Surname_7   |
|  8 | Name_8 Surname_8 | customer8@example.com | SURNAME_8  | Surname_8   |
+----+------------------+-----------------------+------------+-------------+
```

### Підказка

`CONCAT(UPPER(SUBSTRING(last_name, 1, 1)), LOWER(SUBSTRING(last_name, 2)))` — рецепт proper-case.

### Розв'язання

```sql
SELECT id,
       CONCAT(first_name, ' ', last_name) AS full_name,
       LOWER(email) AS email_lower,
       UPPER(last_name) AS last_upper,
       CONCAT(UPPER(SUBSTRING(last_name, 1, 1)),
              LOWER(SUBSTRING(last_name, 2))) AS last_proper
FROM customers
WHERE id BETWEEN 1 AND 150
LIMIT 20;
```

### Покрокове пояснення

1. **`CONCAT(first_name, ' ', last_name)`** склеює через літерал пробілу. `CONCAT('a', NULL, 'c')` повертає `NULL` — якщо ім'я може бути відсутнім, краще `CONCAT_WS(' ', first_name, last_name)`.
2. **`UPPER` / `LOWER`** у MySQL 8 враховують кодування (працюють із кирилицею, латиницею з діакритикою тощо), але поведінка залежить від колації колонки.
3. **Ідіома proper-case:** `UPPER(SUBSTRING(s,1,1))` робить перший символ великим; `LOWER(SUBSTRING(s,2))` — решту малими. Деякі команди роблять обгортку UDF — `INITCAP` у MySQL немає.
4. **У цьому дампі** значення вже `Surname_N`, тому `last_upper` і `last_proper` відрізняються лише регістром. На реальних даних `JOHN DOE` побачите `john.doe@…`, `JOHN DOE` і `John Doe`.

---

## Вправа F2 — Довжина і нарізка: `LENGTH`, `LEFT`, `RIGHT`, `SUBSTRING`

### Контекст

Інтерфейс складу показує один рядок прев'ю кожного SKU і назви: перші 5 символів SKU як «префікс категорії», останні 4 — як «порядковий номер», перші 40 символів назви — як тізер. Також виводимо довжину SKU, щоб помітити битий імпорт.

### Чого ви навчитеся

- `LENGTH(s)` повертає **байти**, не символи — для мультибайтових рядків беріть `CHAR_LENGTH(s)`.
- `LEFT(s, n)` і `RIGHT(s, n)` повертають перші / останні `n` символів.
- `SUBSTRING(s, start [, length])` ріже з позиції `start` (1-індекс).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `parts` | `id`, `sku`, `name` |

### Завдання

Для `parts` з `id BETWEEN 1 AND 200` повернути `id`, `sku`, `sku_len`, `sku_prefix5`, `sku_suffix4`, `name_short` (перші 40 символів). Обмежити 20.

### Очікуваний результат

```text
+----+--------------+---------+-------------+-------------+------------+
| id | sku          | sku_len | sku_prefix5 | sku_suffix4 | name_short |
+----+--------------+---------+-------------+-------------+------------+
|  1 | SKU-00000001 |      12 | SKU-0       | 0001        | Part_1     |
|  2 | SKU-00000002 |      12 | SKU-0       | 0002        | Part_2     |
|  3 | SKU-00000003 |      12 | SKU-0       | 0003        | Part_3     |
|  4 | SKU-00000004 |      12 | SKU-0       | 0004        | Part_4     |
|  5 | SKU-00000005 |      12 | SKU-0       | 0005        | Part_5     |
|  6 | SKU-00000006 |      12 | SKU-0       | 0006        | Part_6     |
|  7 | SKU-00000007 |      12 | SKU-0       | 0007        | Part_7     |
|  8 | SKU-00000008 |      12 | SKU-0       | 0008        | Part_8     |
+----+--------------+---------+-------------+-------------+------------+
```

### Підказка

`LEFT(sku, 5)`, `RIGHT(sku, 4)`, `SUBSTRING(name, 1, 40)`.

### Розв'язання

```sql
SELECT id,
       sku,
       LENGTH(sku)              AS sku_len,
       LEFT(sku, 5)             AS sku_prefix5,
       RIGHT(sku, 4)            AS sku_suffix4,
       SUBSTRING(name, 1, 40)   AS name_short
FROM parts
WHERE id BETWEEN 1 AND 200
LIMIT 20;
```

### Покрокове пояснення

1. **`LENGTH` повертає байти.** Для ASCII це збігається з кількістю символів, але одна кирилична літера в `utf8mb4` займає 2 байти — `CHAR_LENGTH('Ні')` = `2`, а `LENGTH('Ні')` = `4`.
2. **`LEFT(sku, 5)` ≡ `SUBSTRING(sku, 1, 5)`** — обидва працюють. `RIGHT(sku, 4)` ≡ `SUBSTRING(sku, -4)`.
3. **`SUBSTRING(s, start, length)`**: позиції з 1; від'ємний `start` рахує з кінця. Без `length` бере до кінця рядка.
4. **Короткі рядки:** `LEFT('abc', 10)` повертає `'abc'` — MySQL не доповнює і не падає. Потрібен паддинг — комбінуйте з `LPAD` / `RPAD`.

---

## Вправа F3 — Очищення рядків: `TRIM` і `REPLACE`

### Контекст

Введені користувачем номери відомі провідними/кінцевими пробілами, а вільне поле `car` може містити пробіли, які при експорті в CSV/JSON хочеться замінити на підкреслення. Обидва виправлення — однорядкові з вбудованих.

### Чого ви навчитеся

- `TRIM([BOTH | LEADING | TRAILING] 'x' FROM s)` зрізає символи з країв.
- `REPLACE(s, old, new)` замінює всі входження (не regex — пряму підрядкову).
- `TRIM` ріже лише **те, що попросите** — за замовчуванням пробіли.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `vehicles` | `id`, `plate`, `car` |

### Завдання

Для `vehicles` з `id BETWEEN 1 AND 100` повернути `id`, `plate`, `plate_trimmed` (без пробілів), `car_no_spaces` (пробіли у `car` замінено на `_`). Обмежити 15.

### Очікуваний результат

```text
+----+----------+---------------+---------------+
| id | plate    | plate_trimmed | car_no_spaces |
+----+----------+---------------+---------------+
|  1 | AA0001BB | AA0001BB      | Car_1         |
|  2 | AA0002BB | AA0002BB      | Car_2         |
|  3 | AA0003BB | AA0003BB      | Car_3         |
|  4 | AA0004BB | AA0004BB      | Car_4         |
|  5 | AA0005BB | AA0005BB      | Car_5         |
|  6 | AA0006BB | AA0006BB      | Car_6         |
|  7 | AA0007BB | AA0007BB      | Car_7         |
|  8 | AA0008BB | AA0008BB      | Car_8         |
+----+----------+---------------+---------------+
```

### Підказка

`TRIM(BOTH ' ' FROM plate)` і `REPLACE(car, ' ', '_')`.

### Розв'язання

```sql
SELECT id,
       plate,
       TRIM(BOTH ' ' FROM plate)  AS plate_trimmed,
       REPLACE(car, ' ', '_')     AS car_no_spaces
FROM vehicles
WHERE id BETWEEN 1 AND 100
LIMIT 15;
```

### Покрокове пояснення

1. **`TRIM(BOTH ' ' FROM plate)`** багатослівне; `TRIM(plate)` — еквівалентний скорочений варіант для пробілів з обох боків. Явну форму використовуйте, якщо ріжете не пробіл (`TRIM(LEADING '0' FROM '00042')` → `'42'`).
2. **`REPLACE` шукає підрядкові**, не шаблон. `REPLACE('a b  c', ' ', '_')` стане `'a_b__c'` — два пробіли поспіль дадуть два підкреслення.
3. **Для багатошаблонної заміни** у MySQL 8 беріть `REGEXP_REPLACE` (наприклад, схлопнути будь-який пробіл-послідовність до одного `_`: `REGEXP_REPLACE(car, '\\s+', '_')`).
4. **У цьому дампі** `plate` уже чистий — стовпці `plate` і `plate_trimmed` однакові. Запустіть на стовпці з можливими пробілами (наприклад, введені імена), щоб побачити ефект.

---

## Вправа F4 — Числові: `ROUND`, `CEILING`, `FLOOR`, `ABS`, `MOD`

### Контекст

Бухгалтерський вигляд `work_orders.total_cost` потребує п'яти числових «лінз»: округлення до одного знака для відображення, стеля/підлога — для прогнозних бакетів, відстань від орієнтиру (500) — для дисперсії, `MOD(id, 7)` — для трюку «день тижня» / шардингу.

### Чого ви навчитеся

- `ROUND(x, n)` округлює half-away-from-zero до `n` десяткових.
- `CEILING(x)` / `FLOOR(x)` округлюють вгору / вниз до цілого.
- `ABS(x)` повертає модуль.
- `MOD(a, b)` (або `a % b`) — залишок.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Завдання

Для `work_orders` з `id BETWEEN 1 AND 500` повернути `id`, `total_cost`, `cost_1dec`, `cost_ceil`, `cost_floor`, `dist_from_500` (`ABS(total_cost − 500)`), `id_mod_7`. Обмежити 20.

### Очікуваний результат

```text
+----+------------+-----------+-----------+------------+---------------+----------+
| id | total_cost | cost_1dec | cost_ceil | cost_floor | dist_from_500 | id_mod_7 |
+----+------------+-----------+-----------+------------+---------------+----------+
|  1 |     500.10 |     500.1 |       501 |        500 |          0.10 |        1 |
|  2 |     500.20 |     500.2 |       501 |        500 |          0.20 |        2 |
|  3 |     500.30 |     500.3 |       501 |        500 |          0.30 |        3 |
|  4 |     500.40 |     500.4 |       501 |        500 |          0.40 |        4 |
|  5 |     500.50 |     500.5 |       501 |        500 |          0.50 |        5 |
|  6 |     500.60 |     500.6 |       501 |        500 |          0.60 |        6 |
|  7 |     500.70 |     500.7 |       501 |        500 |          0.70 |        0 |
|  8 |     500.80 |     500.8 |       501 |        500 |          0.80 |        1 |
+----+------------+-----------+-----------+------------+---------------+----------+
```

### Підказка

`ROUND(total_cost, 1)`, `CEILING(total_cost)`, `FLOOR(total_cost)`, `ABS(total_cost - 500)`, `MOD(id, 7)`.

### Розв'язання

```sql
SELECT id,
       total_cost,
       ROUND(total_cost, 1)    AS cost_1dec,
       CEILING(total_cost)     AS cost_ceil,
       FLOOR(total_cost)       AS cost_floor,
       ABS(total_cost - 500)   AS dist_from_500,
       MOD(id, 7)              AS id_mod_7
FROM work_orders
WHERE id BETWEEN 1 AND 500
LIMIT 20;
```

### Покрокове пояснення

1. **`ROUND(500.45, 1)`** → `500.5` (для `DECIMAL` MySQL округлює **half away from zero**; для `DOUBLE` — «банківське» округлення). Якщо треба відрізати, а не округлити — `TRUNCATE(x, n)`.
2. **`CEILING(500.10)` = `501`, `FLOOR(500.90)` = `500`** — обидві повертають ціле; фактичний тип — `BIGINT` для цілих входів, `DECIMAL` — для `DECIMAL`.
3. **`ABS(total_cost - 500)`** — модуль відстані від `500`. Результат того ж `DECIMAL(12,2)`, що й вхід.
4. **`MOD(id, 7)`** записується також як `id % 7`. У прикладі видно `MOD(7, 7) = 0`, `MOD(8, 7) = 1` — класична семантика залишку.
5. **Стережіться знака:** `MOD(-1, 7)` у MySQL повертає `-1`, а не `6` (конвенція Python/SQL Server). Для лише додатних бакетів: `((id - 1) MOD 7) + 1`.

---

## Вправа F5 — Дата / час: `DATE_FORMAT`, `YEAR`, `TIMESTAMPDIFF`

### Контекст

Дашборд записів показує кожне бронювання з форматованою позначкою часу (`YYYY-MM-DD HH:MM`), окремим роком та «днями з моменту запису» — для нагадувань і трендів.

### Чого ви навчитеся

- `DATE_FORMAT(dt, format)` — форматування на стороні SQL.
- `YEAR(dt)`, `MONTH(dt)`, `DAY(dt)` — швидкі екстрактори.
- `TIMESTAMPDIFF(unit, start, end)` — знакова різниця; позитивна, коли `end` пізніше.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `appointments` | `id`, `scheduled_at` |

### Завдання

Для `appointments` з `id BETWEEN 1 AND 200` повернути `id`, `scheduled_at`, `sched_fmt` (`%Y-%m-%d %H:%i`), `sched_year`, `days_since_scheduled` (`TIMESTAMPDIFF(DAY, scheduled_at, NOW())`). Обмежити 20.

### Очікуваний результат

```text
+----+---------------------+------------------+------------+----------------------+
| id | scheduled_at        | sched_fmt        | sched_year | days_since_scheduled |
+----+---------------------+------------------+------------+----------------------+
|  1 | 2025-01-01 08:01:00 | 2025-01-01 08:01 |       2025 |                  495 |
|  2 | 2025-01-01 08:02:00 | 2025-01-01 08:02 |       2025 |                  495 |
|  3 | 2025-01-01 08:03:00 | 2025-01-01 08:03 |       2025 |                  495 |
|  4 | 2025-01-01 08:04:00 | 2025-01-01 08:04 |       2025 |                  495 |
|  5 | 2025-01-01 08:05:00 | 2025-01-01 08:05 |       2025 |                  495 |
|  6 | 2025-01-01 08:06:00 | 2025-01-01 08:06 |       2025 |                  495 |
|  7 | 2025-01-01 08:07:00 | 2025-01-01 08:07 |       2025 |                  495 |
|  8 | 2025-01-01 08:08:00 | 2025-01-01 08:08 |       2025 |                  495 |
+----+---------------------+------------------+------------+----------------------+
```

(`days_since_scheduled` залежить від поточної дати — наступний запуск буде на 1 більше.)

### Підказка

`DATE_FORMAT(scheduled_at, '%Y-%m-%d %H:%i')` і `TIMESTAMPDIFF(DAY, scheduled_at, NOW())`.

### Розв'язання

```sql
SELECT id,
       scheduled_at,
       DATE_FORMAT(scheduled_at, '%Y-%m-%d %H:%i') AS sched_fmt,
       YEAR(scheduled_at)                          AS sched_year,
       TIMESTAMPDIFF(DAY, scheduled_at, NOW())     AS days_since_scheduled
FROM appointments
WHERE id BETWEEN 1 AND 200
LIMIT 20;
```

### Покрокове пояснення

1. **Специфікатори `DATE_FORMAT`:** `%Y` — 4-значний рік, `%y` — 2-значний; `%m` — місяць із нулем, `%c` — без; `%H` — 24-годинний, `%h` — 12-годинний; `%i` — хвилини (не `%M`, бо це назва місяця!). Класичний баг — переплутати `%i` і `%M`.
2. **`YEAR(scheduled_at)`** — швидкий екстрактор для побудови графіків. Еквівалент `EXTRACT(YEAR FROM scheduled_at)`.
3. **`TIMESTAMPDIFF(DAY, a, b)`** повертає `b − a` у цілих днях. Перший аргумент — **одиниця**: `SECOND`, `MINUTE`, `HOUR`, `DAY`, `WEEK`, `MONTH`, `YEAR`.
4. **Знак:** ми передаємо `(scheduled_at, NOW())`, тому позитивні значення означають, що `scheduled_at` у минулому. У T3 аргументи переставлено, щоб читати «днів до» з протилежним знаком.
5. **Часові пояси:** і `NOW()`, і `scheduled_at` обчислюються у `@@session.time_zone`. Невідповідні пояси дають сюрприз «±1 день».

---

## Вправа F6 — Умовні: `IF`, `IFNULL`, `NULLIF`, `COALESCE`

### Контекст

В інвойсі касиру потрібні чотири маленькі рішення на замовлення: безпечне відображення телефону, ланцюжок контактів, бенд «high»/«normal» та спосіб **приховати** `cancelled` замовлення, замінивши статус на `NULL`. Кожне — інша умовна функція.

### Чого ви навчитеся

- `IF(cond, t, f)` — тернарна функція.
- `IFNULL(a, fallback)` — повертає `fallback` лише коли `a` дорівнює `NULL`.
- `COALESCE(a, b, c, …)` — перший не-`NULL`.
- `NULLIF(a, b)` — повертає `NULL`, коли `a = b`, інакше `a`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `status`, `total_cost`, `vehicle_id` |
| `vehicles` | `id`, `customer_id` |
| `customers` | `id`, `phone`, `email` |

### Завдання

Зробити join `work_orders → vehicles → customers`. Для `wo.id BETWEEN 1 AND 300` повернути `id`, `status`, `total_cost`, `phone_display` (`IFNULL(c.phone, 'no phone')`), `contact_fallback` (`COALESCE(c.phone, c.email, 'no contact')`), `cost_band` (`IF(total_cost >= 600, 'high', 'normal')`), `status_unless_cancelled` (`NULLIF(status, 'cancelled')`). Обмежити 20.

### Очікуваний результат

```text
+----+---------------+------------+---------------+------------------+-----------+-------------------------+
| id | status        | total_cost | phone_display | contact_fallback | cost_band | status_unless_cancelled |
+----+---------------+------------+---------------+------------------+-----------+-------------------------+
|  1 | new           |     500.10 | +380500000001 | +380500000001    | normal    | new                     |
|  2 | in_progress   |     500.20 | +380500000002 | +380500000002    | normal    | in_progress             |
|  3 | waiting_parts |     500.30 | +380500000003 | +380500000003    | normal    | waiting_parts           |
|  4 | completed     |     500.40 | +380500000004 | +380500000004    | normal    | completed               |
|  5 | cancelled     |     500.50 | +380500000005 | +380500000005    | normal    | NULL                    |
|  6 | new           |     500.60 | +380500000006 | +380500000006    | normal    | new                     |
|  7 | in_progress   |     500.70 | +380500000007 | +380500000007    | normal    | in_progress             |
|  8 | waiting_parts |     500.80 | +380500000008 | +380500000008    | normal    | waiting_parts           |
+----+---------------+------------+---------------+------------------+-----------+-------------------------+
```

### Підказка

Кожна вихідна колонка — своя умовна функція: `IFNULL`, `COALESCE`, `IF`, `NULLIF`.

### Розв'язання

```sql
SELECT wo.id,
       wo.status,
       wo.total_cost,
       IFNULL(c.phone, 'no phone')                    AS phone_display,
       COALESCE(c.phone, c.email, 'no contact')       AS contact_fallback,
       IF(wo.total_cost >= 600, 'high', 'normal')     AS cost_band,
       NULLIF(wo.status, 'cancelled')                 AS status_unless_cancelled
FROM work_orders AS wo
INNER JOIN vehicles  AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
WHERE wo.id BETWEEN 1 AND 300
LIMIT 20;
```

### Покрокове пояснення

1. **`IFNULL(a, b)`** = «якщо `a` `NULL`, поверни `b`, інакше `a`». `COALESCE` узагальнює на будь-яку кількість аргументів.
2. **`COALESCE(c.phone, c.email, 'no contact')`** іде зліва направо і повертає перший не-`NULL`. Стандарт SQL; працює всюди.
3. **`IF(cond, t, f)`** — специфічне для MySQL; стандарт — `CASE WHEN cond THEN t ELSE f END`. Поведінка ідентична.
4. **`NULLIF(a, b)`** повертає `NULL`, коли `a = b`. У рядку 5: `cancelled` → `NULL`; інші статуси проходять без змін.
5. **Поширена пастка:** `IFNULL` перевіряє лише `NULL` — `IFNULL('', 'fallback')` поверне `''`, а не `'fallback'`. Для «порожнє АБО `NULL`» комбінуйте: `COALESCE(NULLIF(phone, ''), 'no phone')`.

---

## Вправа F7 — Min / max по рядку: `GREATEST`, `LEAST`

### Контекст

Дві маленькі потреби: затиснути ціну знизу (`100.0` або `250.5`) і обрізати зверху (`800.0`). Без `GREATEST` / `LEAST` довелося б писати громіздкий `CASE`. З ними — однорядкові.

### Чого ви навчитеся

- `GREATEST(a, b, c, …)` повертає **найбільше** значення.
- `LEAST(a, b, c, …)` повертає **найменше**.
- Обидві поширюють `NULL` (один `NULL` робить весь вираз `NULL`).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Завдання

Для `work_orders` з `id BETWEEN 1 AND 400` повернути `id`, `total_cost`, `at_least_threshold = GREATEST(total_cost, 100.0, 250.5)`, `capped_display = LEAST(total_cost, 800.0)`. Обмежити 15.

### Очікуваний результат

```text
+----+------------+--------------------+----------------+
| id | total_cost | at_least_threshold | capped_display |
+----+------------+--------------------+----------------+
|  1 |     500.10 |             500.10 |         500.10 |
|  2 |     500.20 |             500.20 |         500.20 |
|  3 |     500.30 |             500.30 |         500.30 |
|  4 |     500.40 |             500.40 |         500.40 |
|  5 |     500.50 |             500.50 |         500.50 |
|  6 |     500.60 |             500.60 |         500.60 |
|  7 |     500.70 |             500.70 |         500.70 |
|  8 |     500.80 |             500.80 |         500.80 |
+----+------------+--------------------+----------------+
```

### Підказка

`GREATEST(total_cost, 100.0, 250.5)` і `LEAST(total_cost, 800.0)`.

### Розв'язання

```sql
SELECT id,
       total_cost,
       GREATEST(total_cost, 100.0, 250.5) AS at_least_threshold,
       LEAST(total_cost, 800.0)           AS capped_display
FROM work_orders
WHERE id BETWEEN 1 AND 400
LIMIT 15;
```

### Покрокове пояснення

1. **`GREATEST` ≠ `MAX`.** `MAX` — **агрегат** по рядках; `GREATEST` — **скаляр** по аргументах одного рядка.
2. **Поширення `NULL`:** `GREATEST(100, NULL, 50)` → `NULL`. Щоб ігнорувати `NULL`, оберніть кожен аргумент: `IFNULL(x, -1e18)` (або інша «дно»).
3. **Приведення типів:** змішування рядків і чисел — невизначена поведінка. `GREATEST('9', 10)` поверне `'9'`, бо обидва приведуться до спільного рядкового типу. Тримайте типи аргументів однорідними.
4. **Усі значення тут ≥ 250.5**, тому `at_least_threshold` дорівнює `total_cost`. Щоб побачити «дно», запустіть на колонці зі значеннями `< 250.5` (наприклад, вставте `total_cost = 50` у пісочницю).

---

## Вправа F8 — `FORMAT` (локалізоване відображення чисел)

### Контекст

У чеку для клієнта `total_cost` показуємо з роздільниками тисяч (`1,234.56`), а не сирий `1234.56`. `FORMAT(x, n)` дає локалізований рядок із `n` знаками.

### Чого ви навчитеся

- `FORMAT(x, n)` повертає **рядок** із роздільниками тисяч і `n` десятковими.
- Результат **не** годиться для подальшої числової арифметики.
- Варіанти з локаллю (`FORMAT(x, n, 'de_DE')`) міняють роздільники (`1.234,56`).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Завдання

Для `work_orders` з `id BETWEEN 1 AND 20` повернути `id`, `total_cost`, `cost_formatted = FORMAT(total_cost, 2)`. Обмежити 15.

### Очікуваний результат

```text
+----+------------+----------------+
| id | total_cost | cost_formatted |
+----+------------+----------------+
|  1 |     500.10 | 500.10         |
|  2 |     500.20 | 500.20         |
|  3 |     500.30 | 500.30         |
|  4 |     500.40 | 500.40         |
|  5 |     500.50 | 500.50         |
|  6 |     500.60 | 500.60         |
|  7 |     500.70 | 500.70         |
|  8 |     500.80 | 500.80         |
|  9 |     500.90 | 500.90         |
| 10 |     501.00 | 501.00         |
| 11 |     501.10 | 501.10         |
| 12 |     501.20 | 501.20         |
| 13 |     501.30 | 501.30         |
| 14 |     501.40 | 501.40         |
| 15 |     501.50 | 501.50         |
+----+------------+----------------+
```

### Підказка

`FORMAT(total_cost, 2)`. Для значень ≥ 1000 будуть коми: `FORMAT(12345.6, 2)` → `'12,345.60'`.

### Розв'язання

```sql
SELECT id,
       total_cost,
       FORMAT(total_cost, 2) AS cost_formatted
FROM work_orders
WHERE id BETWEEN 1 AND 20
LIMIT 15;
```

### Покрокове пояснення

1. **`FORMAT` — функція презентації.** Допаджує десяткові, вставляє коми та повертає рядок. Не передавайте результат у `SUM`/`AVG`.
2. **Усі значення у цьому зрізі менше 1000**, тому ком немає. Спробуйте `SELECT FORMAT(12345678.9, 2);` — `'12,345,678.90'`.
3. **Форма з локаллю:** `FORMAT(12345.6, 2, 'de_DE')` → `'12.345,60'` (крапка — тисячі, кома — десяткова). Корисно для експорту в європейські інвойси.
4. **Для машинної точності** беріть сиру колонку або `CAST(total_cost AS CHAR)`. `FORMAT` тримайте лише на самому краю пайплайну (UI / CSV).

---

## Вправа F9 — Шаблони: `REGEXP` / `RLIKE`

### Контекст

Операційна хоче швидкий фільтр «e-mail, що починається з малої літери» — димова перевірка погано імпортованих адрес (`"  bob@…"` не пройде через провідний пробіл). `REGEXP` — інструмент за замовчуванням.

### Чого ви навчитеся

- `s REGEXP pattern` (alias `RLIKE`) істинний, коли `pattern` збігається будь-де в `s`.
- `^` — якір початку; `$` — якір кінця; `[a-z]` — клас символів.
- Регістрочутливість залежить від колації — `utf8mb4_0900_ai_ci` **нечутлива**, тому `'^[a-z]'` ловить і `a`, і `A`. Для суворого регістру — `BINARY` або `COLLATE utf8mb4_0900_as_cs`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `customers` | `id`, `email` |

### Завдання

Для `customers` з `id BETWEEN 1 AND 500` повернути `id`, `email`, де `email REGEXP '^[a-z]'`. Обмежити 15.

### Очікуваний результат

```text
+----+-----------------------+
| id | email                 |
+----+-----------------------+
|  1 | customer1@example.com |
|  2 | customer2@example.com |
|  3 | customer3@example.com |
|  4 | customer4@example.com |
|  5 | customer5@example.com |
|  6 | customer6@example.com |
|  7 | customer7@example.com |
|  8 | customer8@example.com |
+----+-----------------------+
```

### Підказка

`email REGEXP '^[a-z]'` — `^` прив'язує до початку рядка.

### Розв'язання

```sql
SELECT id,
       email
FROM customers
WHERE id BETWEEN 1 AND 500
  AND email REGEXP '^[a-z]'
LIMIT 15;
```

### Покрокове пояснення

1. **`REGEXP` за замовчуванням шукає будь-де.** Додайте `^` для початку, `$` для кінця. `^abc$` вимагає, щоб увесь рядок був `abc`.
2. **Класи символів:** `[a-z]` — одна мала літера, `[A-Za-z]` — будь-яка літера, `[0-9]` — цифра. Заперечення через `^` у дужках: `[^a-z]` — «не мала».
3. **Поширені шаблони:**
   - `'@example\\.com$'` — зворотний слеш екранує літеральну крапку. У SQL сам бекслеш екранується, звідси `\\.`.
   - `'^[A-Z]{2}[0-9]{4}[A-Z]{2}$'` — точний формат «AA0001BB».
4. **Регістр:** колація за замовчуванням нечутлива, тому `^[a-z]` ловить і `Bob`. Для суворої — `email REGEXP BINARY '^[a-z]'` або `email COLLATE utf8mb4_0900_as_cs REGEXP '^[a-z]'`.
5. **MySQL 8 також має `REGEXP_LIKE`, `REGEXP_INSTR`, `REGEXP_REPLACE`, `REGEXP_SUBSTR`** для потужніших операцій.

---

## Вправа F10 — `GROUP_CONCAT` (агрегування рядків за групою)

### Контекст

Диспетчерська панель статусів хоче по одному рядку на статус, де також є **зразок ідентифікаторів** через кому — для швидкого «клік-і-провалися». `GROUP_CONCAT` створений саме для цього.

### Чого ви навчитеся

- `GROUP_CONCAT(expr [ORDER BY …] [SEPARATOR sep])` об'єднує значення групи у один рядок.
- За замовчуванням роздільник `,`; перевизначити — `SEPARATOR '; '`.
- Вивід обрізається до `group_concat_max_len` байтів (за замовчуванням `1024`).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `status` |

### Завдання

Для `work_orders` з `id BETWEEN 1 AND 50` (малий зріз для читабельного виводу) повернути `status`, `n = COUNT(*)`, `sample_ids = GROUP_CONCAT(id ORDER BY id SEPARATOR ',')` згруповане за `status`, упорядковано за `status`.

### Очікуваний результат

```text
+---------------+----+------------------------------+
| status        | n  | sample_ids                   |
+---------------+----+------------------------------+
| cancelled     | 10 | 5,10,15,20,25,30,35,40,45,50 |
| completed     | 10 | 4,9,14,19,24,29,34,39,44,49  |
| in_progress   | 10 | 2,7,12,17,22,27,32,37,42,47  |
| new           | 10 | 1,6,11,16,21,26,31,36,41,46  |
| waiting_parts | 10 | 3,8,13,18,23,28,33,38,43,48  |
+---------------+----+------------------------------+
```

Скрипт-компаньйон використовує `id BETWEEN 1 AND 5000`. Там у кожній групі по 1000 ідентифікаторів — рядок ~4 800 байтів, який мовчки **обрізається** до `group_concat_max_len = 1024`. Зробіть `SET SESSION group_concat_max_len = 16384;` перед запитом, щоб побачити повний результат.

### Підказка

`GROUP_CONCAT(id ORDER BY id SEPARATOR ',')` — `ORDER BY` всередині агрегату.

### Розв'язання

```sql
SELECT status,
       COUNT(*)                                       AS n,
       GROUP_CONCAT(id ORDER BY id SEPARATOR ',')     AS sample_ids
FROM work_orders
WHERE id BETWEEN 1 AND 50
GROUP BY status
ORDER BY status;
```

### Покрокове пояснення

1. **`GROUP_CONCAT(expr)`** склеює елементи кожної групи в один рядок. `ORDER BY id` робить вивід детермінованим — без нього порядок не визначений.
2. **`SEPARATOR ','`** змінює «клей». Корисні значення: `' '`, `' | '`, `'\n'` (літеральний перенос).
3. **Мовчазне обрізання** до `@@group_concat_max_len` байтів. Помилки немає — просто коротший рядок. Завжди підіймайте ліміт, якщо покладаєтеся на повний контент.
4. **`DISTINCT` всередині агрегату:** `GROUP_CONCAT(DISTINCT brand ORDER BY brand)` спершу дедуплікує, потім зливає.
5. **Тип результату:** `TEXT`, не `JSON`-масив — для справжнього JSON беріть `JSON_ARRAYAGG(id)` (MySQL 8).

---

## Вправа T1 — Нормалізація контактів клієнта (Medium)

### Контекст

Маркетинг хоче по одному рядку на клієнта з: proper-case ім'ям, єдиним «кращим» контактом, явною міткою `contact_type` і e-mail-ом з маскою (перші два символи локальної частини + `***`).

### Чого ви навчитеся

- Поєднувати кілька рядкових функцій для «презентаційного» рядка.
- Виразу `CASE` для багатогілкової логіки.
- `SUBSTRING_INDEX(s, delim, n)` для розщеплення за роздільником — зручно для e-mail.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `customers` | `id`, `first_name`, `last_name`, `phone`, `email` |

### Завдання

Для `customers` з `id BETWEEN 1 AND 300` повернути `customer_id`, `full_name` (proper-case прізвище), `primary_contact` (`COALESCE(phone, email, 'NO_CONTACT')`), `contact_type` (`PHONE` / `EMAIL` / `NONE`), `masked_email` (`xx***@host` або `NO_EMAIL`). Обмежити 50.

### Очікуваний результат

```text
+-------------+------------------+-----------------+--------------+-------------------+
| customer_id | full_name        | primary_contact | contact_type | masked_email      |
+-------------+------------------+-----------------+--------------+-------------------+
|           1 | Name_1 Surname_1 | +380500000001   | PHONE        | cu***@example.com |
|           2 | Name_2 Surname_2 | +380500000002   | PHONE        | cu***@example.com |
|           3 | Name_3 Surname_3 | +380500000003   | PHONE        | cu***@example.com |
|           4 | Name_4 Surname_4 | +380500000004   | PHONE        | cu***@example.com |
|           5 | Name_5 Surname_5 | +380500000005   | PHONE        | cu***@example.com |
|           6 | Name_6 Surname_6 | +380500000006   | PHONE        | cu***@example.com |
|           7 | Name_7 Surname_7 | +380500000007   | PHONE        | cu***@example.com |
|           8 | Name_8 Surname_8 | +380500000008   | PHONE        | cu***@example.com |
+-------------+------------------+-----------------+--------------+-------------------+
```

### Підказка

`SUBSTRING_INDEX(email, '@', 1)` — локальна частина; `SUBSTRING_INDEX(email, '@', -1)` — домен.

### Розв'язання

```sql
SELECT c.id AS customer_id,
       CONCAT(c.first_name, ' ',
              CONCAT(UPPER(SUBSTRING(c.last_name, 1, 1)),
                     LOWER(SUBSTRING(c.last_name, 2)))) AS full_name,
       COALESCE(c.phone, c.email, 'NO_CONTACT')         AS primary_contact,
       CASE
           WHEN c.phone IS NOT NULL THEN 'PHONE'
           WHEN c.phone IS NULL AND c.email IS NOT NULL THEN 'EMAIL'
           ELSE 'NONE'
       END                                              AS contact_type,
       CASE
           WHEN c.email IS NULL OR c.email NOT LIKE '%@%' THEN 'NO_EMAIL'
           ELSE CONCAT(LEFT(SUBSTRING_INDEX(c.email, '@', 1), 2),
                       '***', '@',
                       SUBSTRING_INDEX(c.email, '@', -1))
       END                                              AS masked_email
FROM customers AS c
WHERE c.id BETWEEN 1 AND 300
LIMIT 50;
```

### Покрокове пояснення

1. **Proper-case** використовує ідіому з F1 на `last_name`, далі `CONCAT` з `first_name`.
2. **`COALESCE(c.phone, c.email, 'NO_CONTACT')`** — найпростіше правило «найкращий контакт»: перший не-`NULL`; якщо обидва відсутні — мітка-літерал.
3. **`CASE` для `contact_type`** читабельніший за вкладені `IF`. Середня гілка (`phone IS NULL AND email IS NOT NULL`) формально надмірна після першої, але документує намір.
4. **`SUBSTRING_INDEX(email, '@', 1)`** повертає підрядок **до** першої `@`. З `-1` — після останньої `@` (зручно при некоректних адресах із кількома `@`).
5. **Граничний випадок (`NOT LIKE '%@%'`)** захищає від адрес типу `'noreply'` — інакше отримали б `'no***@'`, що виглядає поломано.

---

## Вправа T2 — Сегментація вартості замовлень (Medium)

### Контекст

Дашборд ціноутворення групує замовлення у три бенди (`LOW` / `MEDIUM` / `HIGH`) і показує відстань від історичної базової `500`. Округлені значення тримають таблицю охайною.

### Чого ви навчитеся

- `ROUND(x, 2)` для відображення.
- `CASE` із трьома гілками для сегментації.
- `ABS(x)` як одноразова «магнітуда відхилення».

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Завдання

Для `work_orders` з `id BETWEEN 1 AND 800` повернути `id`, `total_cost`, `rounded_cost`, `cost_segment` (`LOW` якщо `< 300`, `MEDIUM` якщо `< 800`, інакше `HIGH`), `distance_from_avg_500 = ABS(total_cost − 500)`. Сортувати за `total_cost DESC`. Обмежити 40.

### Очікуваний результат

```text
+-----+------------+--------------+--------------+-----------------------+
| id  | total_cost | rounded_cost | cost_segment | distance_from_avg_500 |
+-----+------------+--------------+--------------+-----------------------+
| 800 |     580.00 |       580.00 | MEDIUM       |                 80.00 |
| 799 |     579.90 |       579.90 | MEDIUM       |                 79.90 |
| 798 |     579.80 |       579.80 | MEDIUM       |                 79.80 |
| 797 |     579.70 |       579.70 | MEDIUM       |                 79.70 |
| 796 |     579.60 |       579.60 | MEDIUM       |                 79.60 |
| 795 |     579.50 |       579.50 | MEDIUM       |                 79.50 |
| 794 |     579.40 |       579.40 | MEDIUM       |                 79.40 |
| 793 |     579.30 |       579.30 | MEDIUM       |                 79.30 |
+-----+------------+--------------+--------------+-----------------------+
```

### Підказка

`CASE WHEN total_cost < 300 THEN 'LOW' WHEN total_cost < 800 THEN 'MEDIUM' ELSE 'HIGH' END`.

### Розв'язання

```sql
SELECT wo.id,
       wo.total_cost,
       ROUND(wo.total_cost, 2)        AS rounded_cost,
       CASE
           WHEN wo.total_cost < 300 THEN 'LOW'
           WHEN wo.total_cost < 800 THEN 'MEDIUM'
           ELSE 'HIGH'
       END                            AS cost_segment,
       ABS(wo.total_cost - 500)       AS distance_from_avg_500
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 800
ORDER BY wo.total_cost DESC
LIMIT 40;
```

### Покрокове пояснення

1. **`CASE` оцінюється згори вниз.** Перша «правдива» гілка перемагає, тож порядок важливий: `< 300` має бути перед `< 800`, щоб малі значення не потрапляли у `MEDIUM`.
2. **`ROUND(total_cost, 2)`** тут no-op (колонка вже `DECIMAL(12,2)`), але це захисний крок — якби тип був `DOUBLE`, могли б побачити шум `579.9000000001`.
3. **`ABS(total_cost - 500)`** прибирає знак — корисно для «наскільки далеко від 500 у будь-який бік».
4. **`ORDER BY total_cost DESC` + `LIMIT 40`** відбирає **40 найдорожчих** у зрізі. У цьому дампі мінімум — `541.0`, тому всі 40 потрапляють у `MEDIUM` — змініть пороги (наприклад, `< 600`), щоб побачити `HIGH`.

---

## Вправа T3 — Скоринг терміновості записів (High)

### Контекст

Сторінка бронювань потребує мітки терміновості одним поглядом: `OVERDUE` (минуло), `TODAY`, `SOON` (1–7 днів), `PLANNED` (далі). Разом із форматованою позначкою диспетчер бачить пріоритети миттєво.

### Чого ви навчитеся

- `TIMESTAMPDIFF(DAY, NOW(), scheduled_at)` дає **знакову** кількість днів від «зараз».
- Сходи `CASE` для чотирьох рівнів терміновості з `BETWEEN`.
- Перевикористання виразу в `CASE` проти одноразового обчислення — компроміси.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `appointments` | `id`, `scheduled_at` |

### Завдання

Для `appointments` з `id BETWEEN 1 AND 400` повернути `id`, `scheduled_at`, `scheduled_fmt`, `days_until_or_since` (`TIMESTAMPDIFF(DAY, NOW(), scheduled_at)`), `urgency_label` (`OVERDUE` / `TODAY` / `SOON` / `PLANNED`). Сортувати за `scheduled_at`. Обмежити 60.

### Очікуваний результат

```text
+----+---------------------+------------------+---------------------+---------------+
| id | scheduled_at        | scheduled_fmt    | days_until_or_since | urgency_label |
+----+---------------------+------------------+---------------------+---------------+
|  1 | 2025-01-01 08:01:00 | 2025-01-01 08:01 |                -495 | OVERDUE       |
|  2 | 2025-01-01 08:02:00 | 2025-01-01 08:02 |                -495 | OVERDUE       |
|  3 | 2025-01-01 08:03:00 | 2025-01-01 08:03 |                -495 | OVERDUE       |
|  4 | 2025-01-01 08:04:00 | 2025-01-01 08:04 |                -495 | OVERDUE       |
|  5 | 2025-01-01 08:05:00 | 2025-01-01 08:05 |                -495 | OVERDUE       |
|  6 | 2025-01-01 08:06:00 | 2025-01-01 08:06 |                -495 | OVERDUE       |
|  7 | 2025-01-01 08:07:00 | 2025-01-01 08:07 |                -495 | OVERDUE       |
|  8 | 2025-01-01 08:08:00 | 2025-01-01 08:08 |                -495 | OVERDUE       |
+----+---------------------+------------------+---------------------+---------------+
```

(Кількість днів залежить від `NOW()` — наступного запуску абсолютне значення буде більше; усі рядки показуватимуть `OVERDUE`, бо всі записи в дампі — у минулому.)

### Підказка

`CASE WHEN diff < 0 THEN 'OVERDUE' WHEN diff = 0 THEN 'TODAY' WHEN diff BETWEEN 1 AND 7 THEN 'SOON' ELSE 'PLANNED' END`.

### Розв'язання

```sql
SELECT a.id,
       a.scheduled_at,
       DATE_FORMAT(a.scheduled_at, '%Y-%m-%d %H:%i')   AS scheduled_fmt,
       TIMESTAMPDIFF(DAY, NOW(), a.scheduled_at)        AS days_until_or_since,
       CASE
           WHEN TIMESTAMPDIFF(DAY, NOW(), a.scheduled_at) < 0 THEN 'OVERDUE'
           WHEN TIMESTAMPDIFF(DAY, NOW(), a.scheduled_at) = 0 THEN 'TODAY'
           WHEN TIMESTAMPDIFF(DAY, NOW(), a.scheduled_at) BETWEEN 1 AND 7 THEN 'SOON'
           ELSE 'PLANNED'
       END                                              AS urgency_label
FROM appointments AS a
WHERE a.id BETWEEN 1 AND 400
ORDER BY a.scheduled_at
LIMIT 60;
```

### Покрокове пояснення

1. **Порядок аргументів у `TIMESTAMPDIFF(unit, start, end)`** — `end − start`. Ставлячи `NOW()` першим, отримуємо: позитивне = майбутнє, негативне = минуле.
2. **Сходи `CASE`:** гілки оцінюються по черзі. `< 0` ловить минуле першим; `= 0` — «сьогодні»; `BETWEEN 1 AND 7` — «скоро»; решта — `PLANNED`.
3. **Компроміс — повторюваний вираз:** `TIMESTAMPDIFF(...)` обчислюється до чотирьох разів на рядок. Сучасна альтернатива — `LATERAL` похідна таблиця або CTE. Для 400 рядків — несуттєво.
4. **`NOW()` у запиті:** усі чотири обчислення в одному рядку використовують **те ж саме** `NOW()`, тож класифікація консистентна — ніяких гонок із годинником у середині рядка.

---

## Вправа T4 — Перевірки якості SKU (High)

### Контекст

Каталог хоче помітити неякісні SKU перед публікацією: SKU вважається `BAD`, якщо в ньому є пробіл або він закороткий. Прапорець також виробляє «нормалізовану» версію (UPPER, без пробілів) для нижчих систем.

### Чого ви навчитеся

- `REGEXP ' '` для виявлення пробілу.
- Складати `BAD` / `GOOD` через `CASE` і `OR`.
- Будувати `normalized_sku` через `UPPER(REPLACE(sku, ' ', ''))`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `parts` | `id`, `sku` |

### Завдання

Для `parts` з `id BETWEEN 1 AND 1000` повернути `id`, `sku`, `sku_len = LENGTH(sku)`, `sku_quality` (`BAD`, якщо `sku REGEXP ' ' OR LENGTH(sku) < 6`, інакше `GOOD`), `normalized_sku = UPPER(REPLACE(sku, ' ', ''))`. Обмежити 60.

### Очікуваний результат

```text
+----+--------------+---------+-------------+----------------+
| id | sku          | sku_len | sku_quality | normalized_sku |
+----+--------------+---------+-------------+----------------+
|  1 | SKU-00000001 |      12 | GOOD        | SKU-00000001   |
|  2 | SKU-00000002 |      12 | GOOD        | SKU-00000002   |
|  3 | SKU-00000003 |      12 | GOOD        | SKU-00000003   |
|  4 | SKU-00000004 |      12 | GOOD        | SKU-00000004   |
|  5 | SKU-00000005 |      12 | GOOD        | SKU-00000005   |
|  6 | SKU-00000006 |      12 | GOOD        | SKU-00000006   |
|  7 | SKU-00000007 |      12 | GOOD        | SKU-00000007   |
|  8 | SKU-00000008 |      12 | GOOD        | SKU-00000008   |
+----+--------------+---------+-------------+----------------+
```

### Підказка

`p.sku REGEXP ' '` повертає `1`, якщо у `sku` є хоч один пробіл.

### Розв'язання

```sql
SELECT p.id,
       p.sku,
       LENGTH(p.sku) AS sku_len,
       CASE
           WHEN p.sku REGEXP ' ' OR LENGTH(p.sku) < 6 THEN 'BAD'
           ELSE 'GOOD'
       END                                  AS sku_quality,
       UPPER(REPLACE(p.sku, ' ', ''))       AS normalized_sku
FROM parts AS p
WHERE p.id BETWEEN 1 AND 1000
LIMIT 60;
```

### Покрокове пояснення

1. **`p.sku REGEXP ' '`** істинний, якщо шаблон `' '` (пробіл) зустрічається хоч раз. Для «будь-який пробіл», включно з табуляцією — `'\\s'`.
2. **`OR` між `REGEXP` і `LENGTH(...) < 6`** поєднує дві причини провалу: наявність пробілу або занадто коротко.
3. **`UPPER(REPLACE(sku, ' ', ''))`** — «полагоджена» версія. `REPLACE` прибирає пробіли, `UPPER` нормалізує регістр (хоча всі SKU у дампі вже uppercase).
4. **У цьому дампі** кожен SKU — `SKU-NNNNNNNN` (12 символів, без пробілів), тож усі рядки `GOOD`. Для `BAD` — вставте у пісочницю `('A SKU', 'name')` і перезапустіть.

---

## Вправа T5 — Аналітика вартості за статусом (High)

### Контекст

Фінанси хочуть «по одному рядку на статус»: кількість, мін, макс, середнє, розмах і список-зразок ID для «клік-і-дивися». Один запит із `GROUP BY` дає увесь рядок.

### Чого ви навчитеся

- Поєднання `COUNT`, `MIN`, `MAX`, `AVG` і похідного `cost_span` в одному `GROUP BY`.
- `GROUP_CONCAT(id ORDER BY id SEPARATOR ',')` для списків-зразків.
- Що `group_concat_max_len` мовчки обрізає при великих групах.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Завдання

Для `work_orders` з `id BETWEEN 1 AND 5000` групувати за `status`. Повернути `status`, `orders_count`, `min_cost`, `max_cost`, `avg_cost_2d = ROUND(AVG(total_cost), 2)`, `cost_span = max_cost − min_cost`, `sample_order_ids` як обрізаний список через кому. Сортувати за `avg_cost_2d DESC`.

### Очікуваний результат

```text
+---------------+--------------+----------+----------+-------------+-----------+-------------------------------------+
| status        | orders_count | min_cost | max_cost | avg_cost_2d | cost_span | sample_order_ids_head               |
+---------------+--------------+----------+----------+-------------+-----------+-------------------------------------+
| cancelled     |         1000 |   500.50 |  1000.00 |      750.25 |    499.50 | 5,10,15,20,25,30,35,40,45,50,55,60, |
| completed     |         1000 |   500.40 |   999.90 |      750.15 |    499.50 | 4,9,14,19,24,29,34,39,44,49,54,59,6 |
| waiting_parts |         1000 |   500.30 |   999.80 |      750.05 |    499.50 | 3,8,13,18,23,28,33,38,43,48,53,58,6 |
| in_progress   |         1000 |   500.20 |   999.70 |      749.95 |    499.50 | 2,7,12,17,22,27,32,37,42,47,52,57,6 |
| new           |         1000 |   500.10 |   999.60 |      749.85 |    499.50 | 1,6,11,16,21,26,31,36,41,46,51,56,6 |
+---------------+--------------+----------+----------+-------------+-----------+-------------------------------------+
```

(Стовпець `sample_order_ids` у таблиці вище показано через `LEFT(..., 35)` для влізання. Запустіть розв'язання як є — отримаєте повний `GROUP_CONCAT`, обрізаний `group_concat_max_len = 1024` приблизно до ~330 id на групу.)

### Підказка

`MAX(total_cost) - MIN(total_cost) AS cost_span`; `GROUP_CONCAT(id ORDER BY id SEPARATOR ',') AS sample_order_ids`.

### Розв'язання

```sql
SELECT wo.status,
       COUNT(*)                                              AS orders_count,
       MIN(wo.total_cost)                                    AS min_cost,
       MAX(wo.total_cost)                                    AS max_cost,
       ROUND(AVG(wo.total_cost), 2)                          AS avg_cost_2d,
       MAX(wo.total_cost) - MIN(wo.total_cost)               AS cost_span,
       GROUP_CONCAT(wo.id ORDER BY wo.id SEPARATOR ',')      AS sample_order_ids
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 5000
GROUP BY wo.status
ORDER BY avg_cost_2d DESC;
```

### Покрокове пояснення

1. **Один рядок на `status`.** `GROUP BY` згортає 5000 рядків у 5 кошиків. Усі інші вирази мають бути агрегатами або групованою колонкою.
2. **`cost_span = MAX - MIN`** обчислюється на **групових** значеннях — не по рядках. Можна також `GREATEST(MAX(...)) - LEAST(MIN(...))`, але це надмірно.
3. **`ROUND(AVG(total_cost), 2)`** тримає вивід охайним (`AVG` від `DECIMAL(12,2)` повертає ширшу точність).
4. **Обрізання `GROUP_CONCAT`:** за `group_concat_max_len = 1024` влізе лише перші ~330 id з 1000. `SET SESSION group_concat_max_len = 16384;` перед запитом — для повного.
5. **`ORDER BY avg_cost_2d DESC`** сортує статуси від найвищого середнього чека. У цьому дампі середні стиснуті у `749 – 750` — головна цінність прикладу у **шаблоні**, а не в аналітичній знахідці.

---

## Вправа T6 — Діагностика номерних знаків (High)

### Контекст

Вхідні дані іноді мають номерні знаки з пробілами на краях, у не тому регістрі або занадто короткі. Хочемо діагностичний рядок на авто: «чистий» вигляд, префікс, суфікс і прапорець якості.

### Чого ви навчитеся

- Складати `UPPER(TRIM(...))` для нормалізації рядка.
- Витягати `prefix`/`suffix` через `LEFT`/`RIGHT` після нормалізації.
- `CASE` з трьома категоріями: `MISSING`, `SHORT`, `OK`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `vehicles` | `id`, `plate` |

### Завдання

Для `vehicles` з `id BETWEEN 1 AND 400` повернути `id`, `plate`, `plate_clean = UPPER(TRIM(plate))`, `prefix = LEFT(plate_clean, 2)`, `suffix = RIGHT(plate_clean, 2)`, `plate_flag` (`MISSING` якщо `plate` `NULL` або порожній після `TRIM`, `SHORT` якщо довжина `< 5`, інакше `OK`). Обмежити 50.

### Очікуваний результат

```text
+----+----------+-------------+--------+--------+------------+
| id | plate    | plate_clean | prefix | suffix | plate_flag |
+----+----------+-------------+--------+--------+------------+
|  1 | AA0001BB | AA0001BB    | AA     | BB     | OK         |
|  2 | AA0002BB | AA0002BB    | AA     | BB     | OK         |
|  3 | AA0003BB | AA0003BB    | AA     | BB     | OK         |
|  4 | AA0004BB | AA0004BB    | AA     | BB     | OK         |
|  5 | AA0005BB | AA0005BB    | AA     | BB     | OK         |
|  6 | AA0006BB | AA0006BB    | AA     | BB     | OK         |
|  7 | AA0007BB | AA0007BB    | AA     | BB     | OK         |
|  8 | AA0008BB | AA0008BB    | AA     | BB     | OK         |
+----+----------+-------------+--------+--------+------------+
```

### Підказка

`UPPER(TRIM(plate))` дає канонічну форму; `LEFT(..., 2)` / `RIGHT(..., 2)` ріжуть префікс і суфікс.

### Розв'язання

```sql
SELECT v.id,
       v.plate,
       UPPER(TRIM(v.plate))                  AS plate_clean,
       LEFT(UPPER(TRIM(v.plate)), 2)         AS prefix,
       RIGHT(UPPER(TRIM(v.plate)), 2)        AS suffix,
       CASE
           WHEN v.plate IS NULL OR TRIM(v.plate) = '' THEN 'MISSING'
           WHEN LENGTH(TRIM(v.plate)) < 5             THEN 'SHORT'
           ELSE 'OK'
       END                                   AS plate_flag
FROM vehicles AS v
WHERE v.id BETWEEN 1 AND 400
LIMIT 50;
```

### Покрокове пояснення

1. **`UPPER(TRIM(plate))`** — канонічна форма: верхній регістр, без пробілів. Тут ми обчислюємо її тричі; CTE (`WITH cleaned AS (...)`) дозволив би обчислити раз.
2. **Порядок у `CASE`:** спершу перевіряємо `NULL` і порожнє — інакше `LENGTH(NULL)` буде `NULL`, що не `< 5`, і гілка `MISSING` пропуститься.
3. **`LEFT` і `RIGHT` на 2-символьному вікні**: навіть якщо чистий знак коротший 2 символів, `LEFT('A', 2)` поверне `'A'` (без паддинга). `plate_flag` уже розділяє ці випадки у `SHORT`.
4. **Усі знаки в цьому дампі — 8 ASCII-символів** (`AA0001BB` тощо), тому всі рядки `OK`. Щоб побачити інші гілки — вставте у пісочницю `(NULL, …)`, `('AB', …)` і перезапустіть.
5. **Для суворої валідації** — `REGEXP '^[A-Z]{2}[0-9]{4}[A-Z]{2}$'` (див. F9).

---

## Розв'язання проблем

| Симптом | Що зробити |
|---|---|
| `CONCAT(...)` дав `NULL` | Один з аргументів був `NULL`. Використайте `CONCAT_WS(' ', a, b, c)` для пропуску `NULL`. |
| `LENGTH('Привіт')` = `12`, а не `6` | `LENGTH` повертає байти. Беріть `CHAR_LENGTH` для символів. |
| `REGEXP '^[a-z]'` ловить великі літери | Колація нечутлива. Використайте `BINARY` або чутливу колацію. |
| `GROUP_CONCAT` обрізано | За замовчуванням `group_concat_max_len = 1024`. `SET SESSION group_concat_max_len = 16384;` перед запитом. |
| Кількість днів зміщена на 1 | Розбіжність часових поясів між `NOW()` і збереженим `DATETIME`. `SET time_zone = '+00:00';`. |

Щоб запустити **всі** приклади одразу: `mysql -t -u root car_service_db < 03_mysql/13_functions/car_service_functions_examples.sql`.
