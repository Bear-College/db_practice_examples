# Вбудовані функції — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/13_functions/functions_car_service_db.md)

Приклади працюють з **`car_service_db`** (з **`01_database_mysql/car_service_db.sql.gz`**) і фокусуються на типових **вбудованих функціях MySQL**: рядкових, числових, дат, умовних та кількох допоміжних. Це **не** збережені функції (`CREATE FUNCTION`) — їх розглянемо окремо.

**Скрипт:** `13_functions/car_service_functions_examples.sql`

```bash
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 13_functions/car_service_functions_examples.sql
```

**Продуктивність:** великі таблиці фільтруються через **`WHERE id BETWEEN …`** / **`LIMIT`**.

---

## Карта (за розділами у `.sql`-файлі)

| Розділ | Функції (ідея) |
|--------|----------------|
| **F1** | Рядкові: **`CONCAT`**, **`UPPER`**, **`LOWER`** на іменах / email |
| **F2** | **`LENGTH`**, **`LEFT`**, **`RIGHT`**, **`SUBSTRING`** на **`parts.sku`** |
| **F3** | **`TRIM`**, **`REPLACE`** |
| **F4** | Числові: **`ROUND`**, **`CEIL`**, **`FLOOR`**, **`ABS`**, **`MOD`** на **`work_orders.total_cost`** |
| **F5** | Дата/час: **`DATE_FORMAT`**, **`YEAR`**, **`TIMESTAMPDIFF`**, **`CURDATE()`** на **`appointments.scheduled_at`** |
| **F6** | Умовні: **`IF`**, **`IFNULL`**, **`NULLIF`**, **`COALESCE`** |
| **F7** | **`GREATEST`**, **`LEAST`** |
| **F8** | **`FORMAT`** (форматування числа у локалі) |
| **F9** | Шаблон: **`REGEXP`** / **`RLIKE`** (просто) |
| **F10** | Допоміжний агрегат: **`GROUP_CONCAT`** (з **`GROUP BY`**) |

---

## Примітки

- **`NOW()`**, **`CURDATE()`** — результати змінюються з годинником; для демо це нормально.
- Поведінка **`REGEXP`** може залежати від collation / версії.
- У продакшні віддавайте перевагу **параметризованим** запитам замість збирання рядків через **`CONCAT`**, де є ризик ін'єкцій (тут не показано).

---

## Практичні задачі (середня / висока складність)

### T1 (середня) — Нормалізація контактів клієнта
Створіть запит, який повертає: `customer_id`, `full_name`, `primary_contact`, `contact_type`, `masked_email`.

Вимоги:
- `full_name` = `first_name` + пробіл + `last_name` (прізвище у Proper Case, як у F1).
- `primary_contact` через `COALESCE(phone, email, 'NO_CONTACT')`.
- `contact_type`:
  - `PHONE`, якщо `phone` не `NULL`
  - `EMAIL`, якщо `phone` = `NULL`, а `email` не `NULL`
  - `NONE` в інших випадках
- `masked_email`: зберегти перші 2 символи перед `@`, а решту локальної частини замінити на `***` (напр., `jo***@mail.com`).
- Обмежити до `customer_id` `1..300`.

### T2 (середня) — Сегментація вартості замовлень
Створіть запит до `work_orders`, що повертає: `id`, `total_cost`, `rounded_cost`, `cost_segment`, `distance_from_avg_500`.

Вимоги:
- `rounded_cost` = `ROUND(total_cost, 2)`.
- `cost_segment` через `CASE`:
  - `< 300` => `LOW`
  - `300..799.99` => `MEDIUM`
  - `>= 800` => `HIGH`
- `distance_from_avg_500` = абсолютна різниця з `500`.
- Рядки для id `1..800`, сортувати за `total_cost DESC`, ліміт `40`.

### T3 (висока) — Оцінка терміновості записувань
Створіть запит до `appointments`, що повертає: `id`, `scheduled_at`, `days_until_or_since`, `urgency_label`.

Вимоги:
- `days_until_or_since` = `TIMESTAMPDIFF(DAY, NOW(), scheduled_at)`.
- `urgency_label`:
  - `OVERDUE`, якщо днів < 0
  - `TODAY`, якщо днів = 0
  - `SOON`, якщо днів від 1 до 7
  - `PLANNED` в інших випадках
- Додайте відформатовану дату у форматі `%Y-%m-%d %H:%i`.
- id `1..400`, сортувати за `scheduled_at`.

### T4 (висока) — Перевірки якості SKU
Створіть запит до `parts`, що повертає: `id`, `sku`, `sku_len`, `sku_quality`, `normalized_sku`.

Вимоги:
- `sku_len` = `LENGTH(sku)`.
- `sku_quality`:
  - `BAD`, якщо `sku` містить пробіли (`REGEXP ' '`) або довжина < 6
  - `GOOD` в інших випадках
- `normalized_sku` = SKU великими літерами без пробілів.
- id `1..1000`, ліміт `60`.

### T5 (висока) — Аналітика вартості за статусами
Створіть агрегатний запит до `work_orders`, згрупований за `status`, що повертає:
`status`, `orders_count`, `min_cost`, `max_cost`, `avg_cost_2d`, `cost_span`, `sample_order_ids`.

Вимоги:
- `cost_span` = `max_cost - min_cost` (через вираз або `GREATEST/LEAST` логічно).
- `sample_order_ids` = `GROUP_CONCAT(id ORDER BY id SEPARATOR ',')`.
- Використати замовлення з id `1..5000`.
- Сортувати за `avg_cost_2d DESC`.

### T6 (висока) — Діагностика номерних знаків
Створіть запит до `vehicles`, що повертає:
`id`, `plate`, `plate_clean`, `prefix`, `suffix`, `plate_flag`.

Вимоги:
- `plate_clean` = обрізаний номер у верхньому регістрі.
- `prefix` = перші 2 символи, `suffix` = останні 2.
- `plate_flag`:
  - `MISSING`, якщо плита `NULL` або порожня після обрізки
  - `SHORT`, якщо очищена довжина < 5
  - `OK` в інших випадках
- id `1..400`, ліміт `50`.
