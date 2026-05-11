# Built-in functions — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/13_functions/functions_car_service_db.md)

These exercises walk through common **MySQL built-in functions** — strings, numbers, dates, conditionals, regex, and aggregate helpers — on the real database from **`01_database_mysql/car_service_db.sql.gz`** (database name: **`car_service_db`**). They are **not** stored routines (`CREATE FUNCTION`); those are a separate topic.

Runnable companion file: [`13_functions/car_service_functions_examples.sql`](car_service_functions_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/13_functions/car_service_functions_examples.sql
```

**Performance:** large tables are filtered with **`WHERE id BETWEEN …`** / **`LIMIT`** to keep query times short.

---

## Quick reference

| Section | Functions |
|---|---|
| **F1** Strings | `CONCAT`, `UPPER`, `LOWER`, `SUBSTRING` (proper-case trick) |
| **F2** String lengths and slicing | `LENGTH`, `LEFT`, `RIGHT`, `SUBSTRING` |
| **F3** Cleaning strings | `TRIM`, `REPLACE` |
| **F4** Numeric | `ROUND`, `CEILING`, `FLOOR`, `ABS`, `MOD` |
| **F5** Date / time | `DATE_FORMAT`, `YEAR`, `TIMESTAMPDIFF`, `NOW()`, `CURDATE()` |
| **F6** Conditionals | `IF`, `IFNULL`, `NULLIF`, `COALESCE` |
| **F7** Per-row min / max | `GREATEST`, `LEAST` |
| **F8** Number formatting | `FORMAT` |
| **F9** Pattern matching | `REGEXP` / `RLIKE` |
| **F10** Aggregate helper | `GROUP_CONCAT` (with `GROUP BY`) |
| **T1–T6** | Composite "real-shop" tasks combining the above |

### Notes

- `NOW()` and `CURDATE()` change with the wall clock; expected outputs that depend on dates will vary if you re-run the script weeks later.
- `REGEXP` behavior depends on collation and version. The dump uses `utf8mb4_0900_ai_ci`, which is **case-insensitive** by default — relevant for F9.
- `GROUP_CONCAT` is truncated to **`group_concat_max_len`** characters (default `1024`). For huge groups, raise it with `SET SESSION group_concat_max_len = 16384;` before the query.

---

## Schema touchpoints (from the dump)

- **`customers`** — `id`, `first_name`, `last_name`, `email`, `phone`
- **`parts`** — `id`, `sku`, `name`
- **`vehicles`** — `id`, `plate`, `car`
- **`work_orders`** — `id`, `status`, `total_cost`, `vehicle_id`
- **`appointments`** — `id`, `scheduled_at`

---

## Exercise F1 — Strings: `CONCAT`, `UPPER`, `LOWER`, proper-case

### Context

The CRM exports customer rolls in three styles depending on the consumer: a single `full_name`, an all-lowercase email for deduplication, an all-uppercase last name for printed labels, and a proper-case last name for "Welcome, Surname_1" emails. All five fits in one `SELECT`.

### What you'll learn

- `CONCAT(a, b, c)` joins strings; if any arg is `NULL`, the **result is `NULL`** (use `CONCAT_WS` for "skip NULLs").
- `UPPER(s)` and `LOWER(s)` are the standard case shifters.
- The proper-case idiom: `CONCAT(UPPER(LEFT(s,1)), LOWER(SUBSTRING(s,2)))`.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `first_name`, `last_name`, `email` |

### Task

For `customers` with `id BETWEEN 1 AND 150`, return `id`, `full_name`, `email_lower`, `last_upper`, `last_proper`. Limit 20.

### Expected result

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

### Hint

`CONCAT(UPPER(SUBSTRING(last_name, 1, 1)), LOWER(SUBSTRING(last_name, 2)))` is the proper-case recipe.

### Solution

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

### Step-by-step explanation

1. **`CONCAT(first_name, ' ', last_name)`** glues parts with a literal space. `CONCAT('a', NULL, 'c')` returns `NULL` — if either name can be missing, prefer `CONCAT_WS(' ', first_name, last_name)`.
2. **`UPPER` / `LOWER`** are encoding-aware in MySQL 8 (work for Cyrillic, accented Latin, etc.) but their behavior depends on the column's collation.
3. **Proper-case idiom:** `UPPER(SUBSTRING(s,1,1))` uppercases the first character; `LOWER(SUBSTRING(s,2))` lowercases the rest. Some teams write a wrapper UDF — `INITCAP` doesn't exist in MySQL.
4. **In this dump** the values are already `Surname_N`, so `last_upper` and `last_proper` differ only in case. On real-world data with `JOHN DOE` you would see `john.doe@…`, `JOHN DOE`, and `John Doe`.

---

## Exercise F2 — Lengths and slicing: `LENGTH`, `LEFT`, `RIGHT`, `SUBSTRING`

### Context

The inventory UI shows a one-line preview of each SKU and its product name: the first 5 chars of the SKU as a "category prefix", the last 4 as a sequence number, and the first 40 chars of the name as a teaser. We also want to display the SKU length to spot bad imports.

### What you'll learn

- `LENGTH(s)` returns **bytes**, not characters — for multibyte strings prefer `CHAR_LENGTH(s)`.
- `LEFT(s, n)` and `RIGHT(s, n)` return the first / last `n` characters.
- `SUBSTRING(s, start [, length])` slices from position `start` (1-indexed).

### Tables in play

| Table | Columns |
|---|---|
| `parts` | `id`, `sku`, `name` |

### Task

For `parts` with `id BETWEEN 1 AND 200`, return `id`, `sku`, `sku_len`, `sku_prefix5`, `sku_suffix4`, `name_short` (first 40 chars). Limit 20.

### Expected result

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

### Hint

`LEFT(sku, 5)`, `RIGHT(sku, 4)`, `SUBSTRING(name, 1, 40)`.

### Solution

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

### Step-by-step explanation

1. **`LENGTH` returns bytes.** For ASCII it equals the character count, but a Cyrillic letter under `utf8mb4` takes 2 bytes — `CHAR_LENGTH('Ні')` is `2` while `LENGTH('Ні')` is `4`.
2. **`LEFT(sku, 5)` ≡ `SUBSTRING(sku, 1, 5)`** — both work. `RIGHT(sku, 4)` ≡ `SUBSTRING(sku, -4)`.
3. **`SUBSTRING(s, start, length)`**: positions are 1-indexed; negative `start` counts from the end. Omit `length` to grab to the end of the string.
4. **Empty result on short strings:** `LEFT('abc', 10)` returns `'abc'` — MySQL doesn't pad or error. If you need padded output, combine with `LPAD` / `RPAD`.

---

## Exercise F3 — Cleaning strings: `TRIM` and `REPLACE`

### Context

User-entered plates are notorious for leading/trailing spaces, and the `car` free-text column can contain spaces we want to replace with underscores when exporting to CSV/JSON. Both fixes are one-liners with built-ins.

### What you'll learn

- `TRIM([BOTH | LEADING | TRAILING] 'x' FROM s)` strips characters from string edges.
- `REPLACE(s, old, new)` substitutes every occurrence (not regex — straight substring).
- That `TRIM` only trims **what you ask** — by default it strips spaces.

### Tables in play

| Table | Columns |
|---|---|
| `vehicles` | `id`, `plate`, `car` |

### Task

For `vehicles` with `id BETWEEN 1 AND 100`, return `id`, `plate`, `plate_trimmed` (spaces stripped), `car_no_spaces` (spaces in `car` replaced with `_`). Limit 15.

### Expected result

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

### Hint

`TRIM(BOTH ' ' FROM plate)` and `REPLACE(car, ' ', '_')`.

### Solution

```sql
SELECT id,
       plate,
       TRIM(BOTH ' ' FROM plate)  AS plate_trimmed,
       REPLACE(car, ' ', '_')     AS car_no_spaces
FROM vehicles
WHERE id BETWEEN 1 AND 100
LIMIT 15;
```

### Step-by-step explanation

1. **`TRIM(BOTH ' ' FROM plate)`** is verbose; `TRIM(plate)` is the equivalent shortcut for spaces from both sides. Use the explicit form when the character to trim is non-space (`TRIM(LEADING '0' FROM '00042')` → `'42'`).
2. **`REPLACE` matches whole substrings**, not patterns. `REPLACE('a b  c', ' ', '_')` becomes `'a_b__c'` — two adjacent spaces produce two underscores.
3. **For multi-pattern replacement** in MySQL 8, use `REGEXP_REPLACE` (e.g., collapse all whitespace runs to one underscore: `REGEXP_REPLACE(car, '\\s+', '_')`).
4. **In this dump** the plates are already clean — the column shows `plate` and `plate_trimmed` identical. Run on a column that may have spaces (e.g., user-entered names) to see the effect.

---

## Exercise F4 — Numeric: `ROUND`, `CEILING`, `FLOOR`, `ABS`, `MOD`

### Context

The accountant's view of `work_orders.total_cost` needs five numerical lenses: rounded to one decimal for display, ceiling/floor to integer for forecast buckets, distance from a reference (500) for variance, and `MOD(id, 7)` for a "day-of-week" sharding trick.

### What you'll learn

- `ROUND(x, n)` rounds half-away-from-zero to `n` decimals.
- `CEILING(x)` / `FLOOR(x)` round to the nearest integer up / down.
- `ABS(x)` returns the absolute value.
- `MOD(a, b)` (or `a % b`) returns the remainder.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 500`, return `id`, `total_cost`, `cost_1dec`, `cost_ceil`, `cost_floor`, `dist_from_500` (`ABS(total_cost − 500)`), `id_mod_7`. Limit 20.

### Expected result

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

### Hint

`ROUND(total_cost, 1)`, `CEILING(total_cost)`, `FLOOR(total_cost)`, `ABS(total_cost - 500)`, `MOD(id, 7)`.

### Solution

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

### Step-by-step explanation

1. **`ROUND(500.45, 1)`** → `500.5` (MySQL rounds **half away from zero** for `DECIMAL`; for `DOUBLE` the behavior is "banker's rounding"). Use `TRUNCATE(x, n)` if you need to chop rather than round.
2. **`CEILING(500.10)` = `501`, `FLOOR(500.90)` = `500`** — both return integers; the actual return type is `BIGINT` for integer inputs and `DECIMAL` for `DECIMAL` inputs.
3. **`ABS(total_cost - 500)`** — absolute distance from `500`. The result is the same `DECIMAL(12,2)` as the input.
4. **`MOD(id, 7)`** is also writable as `id % 7`. The example shows `MOD(7, 7) = 0`, `MOD(8, 7) = 1` — classic remainder semantics.
5. **Watch the sign:** `MOD(-1, 7)` returns `-1` in MySQL, not `6` (Python/SQL Server convention). For positive-only buckets, `((id - 1) MOD 7) + 1`.

---

## Exercise F5 — Date / time: `DATE_FORMAT`, `YEAR`, `TIMESTAMPDIFF`

### Context

The appointment dashboard shows each booking with a formatted timestamp (`YYYY-MM-DD HH:MM`), the bare year, and "days since scheduled" — both for past-due reminders and trend reports.

### What you'll learn

- `DATE_FORMAT(dt, format)` for SQL-side string formatting.
- `YEAR(dt)`, `MONTH(dt)`, `DAY(dt)` — quick extractors.
- `TIMESTAMPDIFF(unit, start, end)` — signed difference; positive when `end` is later.

### Tables in play

| Table | Columns |
|---|---|
| `appointments` | `id`, `scheduled_at` |

### Task

For `appointments` with `id BETWEEN 1 AND 200`, return `id`, raw `scheduled_at`, formatted `sched_fmt` (`%Y-%m-%d %H:%i`), `sched_year`, `days_since_scheduled` (`TIMESTAMPDIFF(DAY, scheduled_at, NOW())`). Limit 20.

### Expected result

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

(`days_since_scheduled` depends on the current date — re-running tomorrow will show 496.)

### Hint

`DATE_FORMAT(scheduled_at, '%Y-%m-%d %H:%i')` and `TIMESTAMPDIFF(DAY, scheduled_at, NOW())`.

### Solution

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

### Step-by-step explanation

1. **`DATE_FORMAT` specifiers:** `%Y` = 4-digit year, `%y` = 2-digit; `%m` = month with zero, `%c` = without; `%H` = 24-hour, `%h` = 12-hour; `%i` = minute (not `%M`, which is the month name!). Bugged dashboards usually mix up `%i` and `%M`.
2. **`YEAR(scheduled_at)`** is a fast extractor for plotting. Equivalent to `EXTRACT(YEAR FROM scheduled_at)`.
3. **`TIMESTAMPDIFF(DAY, a, b)`** returns `b − a` in whole days. The first argument is the **unit**: `SECOND`, `MINUTE`, `HOUR`, `DAY`, `WEEK`, `MONTH`, `YEAR`.
4. **Sign convention:** because we pass `(scheduled_at, NOW())`, positive results mean `scheduled_at` is in the past. The T3 task flips the arguments to read "days until" with the opposite sign.
5. **Time zones:** both `NOW()` and `scheduled_at` are evaluated in `@@session.time_zone`. Mismatched zones produce off-by-one-day surprises.

---

## Exercise F6 — Conditionals: `IF`, `IFNULL`, `NULLIF`, `COALESCE`

### Context

The cashier's invoice view needs four small decisions per work order: a safe phone display, a contact fallback chain, a "high"/"normal" cost band, and a way to **hide** `cancelled` orders by mapping their status to `NULL`. Each maps to a different conditional function.

### What you'll learn

- `IF(cond, t, f)` — three-arg ternary.
- `IFNULL(a, fallback)` — returns `fallback` only when `a` is `NULL`.
- `COALESCE(a, b, c, …)` — first non-`NULL`.
- `NULLIF(a, b)` — returns `NULL` when `a = b`, else `a`.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost`, `vehicle_id` |
| `vehicles` | `id`, `customer_id` |
| `customers` | `id`, `phone`, `email` |

### Task

Join `work_orders → vehicles → customers`. For `wo.id BETWEEN 1 AND 300`, return `id`, `status`, `total_cost`, `phone_display` (`IFNULL(c.phone, 'no phone')`), `contact_fallback` (`COALESCE(c.phone, c.email, 'no contact')`), `cost_band` (`IF(total_cost >= 600, 'high', 'normal')`), `status_unless_cancelled` (`NULLIF(status, 'cancelled')`). Limit 20.

### Expected result

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

### Hint

Each output column maps to a different conditional: `IFNULL`, `COALESCE`, `IF`, `NULLIF`.

### Solution

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

### Step-by-step explanation

1. **`IFNULL(a, b)`** = "if `a` is `NULL`, return `b`, else return `a`". `COALESCE` generalises this to any number of arguments.
2. **`COALESCE(c.phone, c.email, 'no contact')`** walks the list left-to-right and returns the first non-`NULL`. Standard SQL; works in every database.
3. **`IF(cond, t, f)`** is MySQL-specific; the standard equivalent is `CASE WHEN cond THEN t ELSE f END`. Both perform the same.
4. **`NULLIF(a, b)`** returns `NULL` when `a = b`. Row 5 shows `cancelled` → `NULL`; the other statuses pass through unchanged.
5. **Common trap:** `IFNULL` checks `NULL` only — `IFNULL('', 'fallback')` is `''`, not `'fallback'`. For "empty string OR null", combine: `COALESCE(NULLIF(phone, ''), 'no phone')`.

---

## Exercise F7 — Per-row min / max: `GREATEST`, `LEAST`

### Context

Two small needs: clamp a price to at least a floor (`100.0` or `250.5`), and clamp it to at most a ceiling (`800.0`). Without `GREATEST` / `LEAST` you'd write a clunky `CASE`. With them it's a one-liner per column.

### What you'll learn

- `GREATEST(a, b, c, …)` returns the **largest** value.
- `LEAST(a, b, c, …)` returns the **smallest** value.
- Both ignore types beyond promotion rules and propagate `NULL` (a `NULL` argument makes the whole expression `NULL`).

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 400`, return `id`, `total_cost`, `at_least_threshold = GREATEST(total_cost, 100.0, 250.5)`, `capped_display = LEAST(total_cost, 800.0)`. Limit 15.

### Expected result

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

### Hint

`GREATEST(total_cost, 100.0, 250.5)` and `LEAST(total_cost, 800.0)`.

### Solution

```sql
SELECT id,
       total_cost,
       GREATEST(total_cost, 100.0, 250.5) AS at_least_threshold,
       LEAST(total_cost, 800.0)           AS capped_display
FROM work_orders
WHERE id BETWEEN 1 AND 400
LIMIT 15;
```

### Step-by-step explanation

1. **`GREATEST` ≠ `MAX`.** `MAX` is an **aggregate** over rows; `GREATEST` is a **scalar** over arguments of the same row.
2. **`NULL` propagation:** `GREATEST(100, NULL, 50)` returns `NULL`. To ignore `NULL`s, wrap each argument in `IFNULL(x, -1e18)` (or a similar floor).
3. **Type coercion:** mixing strings and numbers is undefined behaviour. `GREATEST('9', 10)` returns `'9'` because both arguments get cast to a common string type. Keep argument types homogeneous.
4. **All values are ≥ 250.5 here**, so `at_least_threshold` simply equals `total_cost`. To see the floor in action, run on a column with values below `250.5` (e.g., add a row with `total_cost = 50` to a sandbox table).

---

## Exercise F8 — `FORMAT` (locale-aware number display)

### Context

The customer-facing receipt shows `total_cost` with thousands separators (`1,234.56`) instead of the raw `1234.56`. `FORMAT(x, n)` produces a locale-styled string with `n` decimals.

### What you'll learn

- `FORMAT(x, n)` returns a **string**, with thousands grouping and `n` decimals.
- The output is **not** safe to plug back into numeric arithmetic.
- Locale-aware variants (`FORMAT(x, n, 'de_DE')`) flip the separators (`1.234,56`).

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 20`, return `id`, `total_cost`, `cost_formatted = FORMAT(total_cost, 2)`. Limit 15.

### Expected result

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

### Hint

`FORMAT(total_cost, 2)`. For values ≥ 1000, expect commas: `FORMAT(12345.6, 2)` → `'12,345.60'`.

### Solution

```sql
SELECT id,
       total_cost,
       FORMAT(total_cost, 2) AS cost_formatted
FROM work_orders
WHERE id BETWEEN 1 AND 20
LIMIT 15;
```

### Step-by-step explanation

1. **`FORMAT` is a presentation function.** It pads decimals, inserts grouping commas, and returns a string. Don't feed the result back into `SUM`/`AVG`.
2. **All values in this slice are under 1000**, so no commas appear. Try `SELECT FORMAT(12345678.9, 2);` for `'12,345,678.90'`.
3. **Locale form:** `FORMAT(12345.6, 2, 'de_DE')` returns `'12.345,60'` (dot as thousands, comma as decimal). Useful for export to European invoices.
4. **For machine-precision output**, use the raw column or `CAST(total_cost AS CHAR)`. Use `FORMAT` only at the very edge of your pipeline (UI / CSV).

---

## Exercise F9 — Pattern matching: `REGEXP` / `RLIKE`

### Context

Operations wants a quick filter for "emails that start with a lowercase letter" — a smoke test for badly imported addresses (`"  bob@…"` would fail because of the leading space). `REGEXP` is the right tool.

### What you'll learn

- `s REGEXP pattern` (alias `RLIKE`) is true when `pattern` matches anywhere in `s`.
- `^` anchors to the start; `$` to the end; `[a-z]` is a character class.
- Collation determines case sensitivity — `utf8mb4_0900_ai_ci` is **case-insensitive**, so `'^[a-z]'` actually matches both `a` and `A`. Use `BINARY` or `COLLATE utf8mb4_0900_as_cs` for strict case.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `email` |

### Task

For `customers` with `id BETWEEN 1 AND 500`, return `id`, `email` where `email REGEXP '^[a-z]'`. Limit 15.

### Expected result

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

### Hint

`email REGEXP '^[a-z]'` — the `^` anchors to the start of the string.

### Solution

```sql
SELECT id,
       email
FROM customers
WHERE id BETWEEN 1 AND 500
  AND email REGEXP '^[a-z]'
LIMIT 15;
```

### Step-by-step explanation

1. **`REGEXP` matches anywhere by default.** Add `^` to anchor at the start, `$` at the end. `^abc$` requires the whole string to be `abc`.
2. **Character classes:** `[a-z]` is one lowercase letter, `[A-Za-z]` is any letter, `[0-9]` is a digit. Negation with `^` inside brackets: `[^a-z]` is "not lowercase".
3. **Common patterns:**
   - `'@example\\.com$'` — backslash escapes the literal `.`. In SQL, the backslash itself must be escaped, hence `\\.`.
   - `'^[A-Z]{2}[0-9]{4}[A-Z]{2}$'` — exact plate format like `AA0001BB`.
4. **Case sensitivity:** because the default collation is case-insensitive, `^[a-z]` matches `Bob` too. For strict case use `email REGEXP BINARY '^[a-z]'` or `email COLLATE utf8mb4_0900_as_cs REGEXP '^[a-z]'`.
5. **MySQL 8 also has `REGEXP_LIKE`, `REGEXP_INSTR`, `REGEXP_REPLACE`, `REGEXP_SUBSTR`** for more powerful operations.

---

## Exercise F10 — `GROUP_CONCAT` (aggregate strings per group)

### Context

The dispatcher's status board wants a one-row-per-status summary that includes a comma-separated **sample of order ids** in each bucket — for quick "click to drill down" links. `GROUP_CONCAT` is purpose-built for this.

### What you'll learn

- `GROUP_CONCAT(expr [ORDER BY …] [SEPARATOR sep])` concatenates per-group values into one string.
- Default separator is `,`; override with `SEPARATOR '; '` (or any literal).
- Output is truncated at `group_concat_max_len` bytes (default `1024`).

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status` |

### Task

For `work_orders` with `id BETWEEN 1 AND 50` (small slice so the output stays readable), return `status`, `n = COUNT(*)`, `sample_ids = GROUP_CONCAT(id ORDER BY id SEPARATOR ',')` grouped by `status`, ordered by `status`.

### Expected result

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

The companion `.sql` uses `id BETWEEN 1 AND 5000`. There each group has 1000 ids — the concatenated string is ~4 800 bytes and is silently **truncated** at `group_concat_max_len = 1024`. Run `SET SESSION group_concat_max_len = 16384;` first to see the full strings.

### Hint

`GROUP_CONCAT(id ORDER BY id SEPARATOR ',')` — the `ORDER BY` is inside the aggregate.

### Solution

```sql
SELECT status,
       COUNT(*)                                       AS n,
       GROUP_CONCAT(id ORDER BY id SEPARATOR ',')     AS sample_ids
FROM work_orders
WHERE id BETWEEN 1 AND 50
GROUP BY status
ORDER BY status;
```

### Step-by-step explanation

1. **`GROUP_CONCAT(expr)`** concatenates one row per group entry into a single string. The `ORDER BY id` makes the output deterministic — without it, the order is unspecified.
2. **`SEPARATOR ','`** changes the glue. Useful values: `' '`, `' | '`, `'\n'` (literal newline).
3. **Silent truncation** at `@@group_concat_max_len` bytes. There's no error — just a shorter string. Always raise the limit before relying on the full content.
4. **`DISTINCT` inside aggregate:** `GROUP_CONCAT(DISTINCT brand ORDER BY brand)` deduplicates first, then concatenates.
5. **Result type:** the output is a `TEXT` value, not a `JSON` array — wrap with `JSON_ARRAYAGG(id)` if you want true JSON output (MySQL 8).

---

## Exercise T1 — Customer contact normalization (Medium)

### Context

Marketing wants one row per customer with: a proper-cased name, a single best contact value, an explicit `contact_type` label, and a privacy-masked email (first two chars of the local part, then `***`).

### What you'll learn

- Combining several string functions to build a "presentation" row.
- The `CASE` expression for multi-branch logic.
- `SUBSTRING_INDEX(s, delim, n)` for splitting on a delimiter — handy for emails.

### Tables in play

| Table | Columns |
|---|---|
| `customers` | `id`, `first_name`, `last_name`, `phone`, `email` |

### Task

For `customers` with `id BETWEEN 1 AND 300`, return `customer_id`, `full_name` (proper-cased last name), `primary_contact` (`COALESCE(phone, email, 'NO_CONTACT')`), `contact_type` (`PHONE` / `EMAIL` / `NONE`), `masked_email` (`xx***@host` or `NO_EMAIL`). Limit 50.

### Expected result

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

### Hint

`SUBSTRING_INDEX(email, '@', 1)` is the local part; `SUBSTRING_INDEX(email, '@', -1)` is the domain.

### Solution

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

### Step-by-step explanation

1. **Proper-case** uses the F1 idiom on `last_name`, then `CONCAT`s with `first_name`.
2. **`COALESCE(c.phone, c.email, 'NO_CONTACT')`** is the simplest "best contact" rule — first non-`NULL` wins; if both are null, a literal label appears.
3. **`CASE` for `contact_type`** is more readable than nesting `IF`s. The middle branch (`phone IS NULL AND email IS NOT NULL`) is technically redundant once the first branch caught all phone cases, but it documents intent.
4. **`SUBSTRING_INDEX(email, '@', 1)`** returns the substring **before** the first `@`. With `-1` it returns the substring **after** the last `@` (handy if someone has multiple `@` in a malformed address).
5. **Edge case (`NOT LIKE '%@%'`)** protects against bogus emails like `'noreply'` — we'd otherwise return `'no***@'` which looks broken.

---

## Exercise T2 — Work order value segmentation (Medium)

### Context

The pricing dashboard groups orders into three cost tiers (`LOW` / `MEDIUM` / `HIGH`) and shows distance from the historical baseline of `500`. Rounded display values keep the table tidy.

### What you'll learn

- `ROUND(x, 2)` for display rounding.
- A `CASE` expression with three branches for value segmentation.
- `ABS(x)` as a one-shot "magnitude of difference".

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 800`, return `id`, `total_cost`, `rounded_cost`, `cost_segment` (`LOW` if `< 300`, `MEDIUM` if `< 800`, else `HIGH`), `distance_from_avg_500 = ABS(total_cost − 500)`. Sort by `total_cost DESC`. Limit 40.

### Expected result

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

### Hint

Use `CASE WHEN total_cost < 300 THEN 'LOW' WHEN total_cost < 800 THEN 'MEDIUM' ELSE 'HIGH' END`.

### Solution

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

### Step-by-step explanation

1. **`CASE` evaluation is top-down.** The first matching `WHEN` wins, so order matters: `< 300` before `< 800` keeps small values out of `MEDIUM`.
2. **`ROUND(total_cost, 2)`** is a no-op here (column is already `DECIMAL(12,2)`) but is defensive — if the column were `DOUBLE`, the display would show `579.9000000001` style noise.
3. **`ABS(total_cost - 500)`** drops the sign — useful for "how far from 500 in either direction".
4. **`ORDER BY total_cost DESC` + `LIMIT 40`** selects the **40 most expensive** in the slice. The smallest of those is `541.0` in this dump, so all 40 rows land in `MEDIUM` — adjust thresholds (e.g., `< 600`) to see `HIGH` rows.

---

## Exercise T3 — Appointment urgency scoring (High)

### Context

The booking page needs a glanceable urgency label: `OVERDUE` (in the past), `TODAY`, `SOON` (1–7 days), `PLANNED` (further out). Combined with a formatted timestamp, the dispatcher can triage at a glance.

### What you'll learn

- `TIMESTAMPDIFF(DAY, NOW(), scheduled_at)` produces a **signed** day count from now.
- A `CASE` ladder for four urgency tiers including `BETWEEN`.
- Reusing the same expression in `CASE` versus computing it once — and the trade-offs.

### Tables in play

| Table | Columns |
|---|---|
| `appointments` | `id`, `scheduled_at` |

### Task

For `appointments` with `id BETWEEN 1 AND 400`, return `id`, `scheduled_at`, `scheduled_fmt`, `days_until_or_since` (`TIMESTAMPDIFF(DAY, NOW(), scheduled_at)`), `urgency_label` (`OVERDUE` / `TODAY` / `SOON` / `PLANNED`). Sort by `scheduled_at`. Limit 60.

### Expected result

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

(Day count depends on `NOW()` — re-run later and the absolute number will be larger; all rows still show `OVERDUE` because every appointment in the dump is in the past relative to today.)

### Hint

`CASE WHEN diff < 0 THEN 'OVERDUE' WHEN diff = 0 THEN 'TODAY' WHEN diff BETWEEN 1 AND 7 THEN 'SOON' ELSE 'PLANNED' END`.

### Solution

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

### Step-by-step explanation

1. **Argument order matters in `TIMESTAMPDIFF(unit, start, end)`** — `end − start`. Putting `NOW()` first means positive = future, negative = past.
2. **`CASE` ladder:** branches are evaluated in order. `< 0` catches the past first; the `= 0` branch then targets exactly today; `BETWEEN 1 AND 7` is the "soon" window; the rest fall through to `PLANNED`.
3. **Trade-off — repeated expression:** the `TIMESTAMPDIFF(...)` is computed up to four times per row. A modern alternative is a `LATERAL` derived table or a window expression. For 400 rows the cost is negligible.
4. **`NOW()` per query:** all four evaluations within one row use the **same** `NOW()` value, so the categorisation is consistent — no race on the wall clock mid-row.

---

## Exercise T4 — SKU quality checks (High)

### Context

The catalog team wants to flag low-quality SKUs before publishing: an SKU is `BAD` if it has whitespace or is too short. The flag also produces a "cleaned" version (upper-cased, spaces removed) for downstream consumers.

### What you'll learn

- Using `REGEXP ' '` to detect any whitespace.
- Composing `BAD` / `GOOD` with `CASE` and `OR`.
- Building a `normalized_sku` with `UPPER(REPLACE(sku, ' ', ''))`.

### Tables in play

| Table | Columns |
|---|---|
| `parts` | `id`, `sku` |

### Task

For `parts` with `id BETWEEN 1 AND 1000`, return `id`, `sku`, `sku_len = LENGTH(sku)`, `sku_quality` (`BAD` if `sku REGEXP ' ' OR LENGTH(sku) < 6`, else `GOOD`), `normalized_sku = UPPER(REPLACE(sku, ' ', ''))`. Limit 60.

### Expected result

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

### Hint

`p.sku REGEXP ' '` returns `1` if `sku` contains a space anywhere.

### Solution

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

### Step-by-step explanation

1. **`p.sku REGEXP ' '`** is true if the pattern `' '` (a single space) appears anywhere. For "any whitespace" — including tabs — use `'\\s'`.
2. **`OR` between `REGEXP` and `LENGTH(...) < 6`** combines two reasons to fail: presence of a space, or too short.
3. **`UPPER(REPLACE(sku, ' ', ''))`** is the "fixed" version. `REPLACE` strips spaces, `UPPER` normalises case — even though all SKUs in the dump are uppercase already.
4. **In this dump** every SKU is `SKU-NNNNNNNN` (12 chars, no spaces), so all rows are `GOOD`. To force a `BAD` row, insert `('A SKU', 'name')` into a sandbox and re-run.

---

## Exercise T5 — Status-level cost analytics (High)

### Context

The finance team wants per-status totals — count, min, max, average, span — plus a comma-separated sample of order IDs for "click to inspect". One `GROUP BY` query produces the whole row.

### What you'll learn

- Combining `COUNT`, `MIN`, `MAX`, `AVG`, and a derived `cost_span` in one `GROUP BY`.
- `GROUP_CONCAT(id ORDER BY id SEPARATOR ',')` for sample lists.
- That `group_concat_max_len` truncates silently when groups are large.

### Tables in play

| Table | Columns |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Task

For `work_orders` with `id BETWEEN 1 AND 5000`, group by `status`. Return `status`, `orders_count`, `min_cost`, `max_cost`, `avg_cost_2d = ROUND(AVG(total_cost), 2)`, `cost_span = max_cost − min_cost`, `sample_order_ids` as the truncated comma-separated id list. Sort by `avg_cost_2d DESC`.

### Expected result

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

(The `sample_order_ids` column shown above was truncated with `LEFT(..., 35)` for the table to fit. Run the solution as-is to get the full `GROUP_CONCAT` output, which is truncated by `group_concat_max_len = 1024` to about ~330 ids per group.)

### Hint

`MAX(total_cost) - MIN(total_cost) AS cost_span`; `GROUP_CONCAT(id ORDER BY id SEPARATOR ',') AS sample_order_ids`.

### Solution

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

### Step-by-step explanation

1. **One row per `status`.** `GROUP BY` collapses the 5000 source rows into 5 buckets. Every other expression must be an aggregate or grouped column.
2. **`cost_span = MAX - MIN`** computed on the **grouped** values — not row-by-row. Could also be written as `GREATEST(MAX(...)) - LEAST(MIN(...))` but that's redundant.
3. **`ROUND(AVG(total_cost), 2)`** keeps the display tidy (`AVG` of `DECIMAL(12,2)` returns a wider precision by default).
4. **`GROUP_CONCAT` truncation:** at default `group_concat_max_len = 1024`, only the first ~330 ids of 1000 fit. `SET SESSION group_concat_max_len = 16384;` before the query for full output.
5. **`ORDER BY avg_cost_2d DESC`** sorts statuses from highest average ticket to lowest. In this dump the averages are tightly bunched (`749 – 750`) — the script's chief value is showcasing the **template**, not the analytical insight.

---

## Exercise T6 — Vehicle plate diagnostics (High)

### Context

Inbound data sometimes has plates with leading/trailing whitespace, wrong case, or impossibly short text. We want a one-row-per-vehicle diagnostic: clean form, prefix, suffix, and a quality flag.

### What you'll learn

- Composing `UPPER(TRIM(...))` to normalize a string.
- Extracting `prefix`/`suffix` with `LEFT`/`RIGHT` after normalisation.
- A `CASE` with three categories: `MISSING`, `SHORT`, `OK`.

### Tables in play

| Table | Columns |
|---|---|
| `vehicles` | `id`, `plate` |

### Task

For `vehicles` with `id BETWEEN 1 AND 400`, return `id`, `plate`, `plate_clean = UPPER(TRIM(plate))`, `prefix = LEFT(plate_clean, 2)`, `suffix = RIGHT(plate_clean, 2)`, `plate_flag` (`MISSING` if `plate` is `NULL` or empty after trim, `SHORT` if cleaned length `< 5`, else `OK`). Limit 50.

### Expected result

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

### Hint

`UPPER(TRIM(plate))` produces the canonical form; `LEFT(..., 2)` / `RIGHT(..., 2)` slice prefix and suffix.

### Solution

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

### Step-by-step explanation

1. **`UPPER(TRIM(plate))`** is the canonical form: uppercased, whitespace-stripped. We compute it three times in this query; a CTE (`WITH cleaned AS (...)`) would let us compute it once.
2. **`CASE` ordering:** check `NULL` and empty first — otherwise `LENGTH(NULL)` is `NULL`, which is not `< 5`, and the `MISSING` branch would be skipped.
3. **`LEFT` and `RIGHT` on a 2-char window**: even if the cleaned plate is shorter than 2 chars, `LEFT('A', 2)` returns `'A'` (no padding). The `plate_flag` already separates those into `SHORT`.
4. **All plates in this dump are 8 ASCII chars** (`AA0001BB` etc.), so every row reads `OK`. To force the other branches, insert sandbox rows like `(NULL, …)`, `('AB', …)` and re-run.
5. **For stricter validation** consider `REGEXP '^[A-Z]{2}[0-9]{4}[A-Z]{2}$'` — see Exercise F9.

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `CONCAT(...)` produced `NULL` | One of the arguments was `NULL`. Use `CONCAT_WS(' ', a, b, c)` to skip `NULL`s. |
| `LENGTH('Привіт')` is `12`, not `6` | `LENGTH` returns bytes. Use `CHAR_LENGTH` for characters. |
| `REGEXP '^[a-z]'` matched uppercase | The collation is case-insensitive. Use `BINARY` or a case-sensitive collation. |
| `GROUP_CONCAT` cut off | Default `group_concat_max_len = 1024`. `SET SESSION group_concat_max_len = 16384;` before the query. |
| Day count off by one | Time-zone mismatch between `NOW()` and the stored `DATETIME`. Set `SET time_zone = '+00:00';`. |

If you want to run **all** examples at once: `mysql -t -u root car_service_db < 03_mysql/13_functions/car_service_functions_examples.sql`.
