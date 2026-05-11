# Built-in functions — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/13_functions/functions_car_service_db.md)

Examples use **`car_service_db`** (from **`01_database_mysql/car_service_db.sql.gz`**) and focus on common **MySQL built-in functions**: strings, numbers, dates, conditionals, and a few utilities. They are **not** stored routines (`CREATE FUNCTION`); those are a separate topic.

**Script:** `13_functions/car_service_functions_examples.sql`

```bash
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 13_functions/car_service_functions_examples.sql
```

**Performance:** large tables are filtered with **`WHERE id BETWEEN …`** / **`LIMIT`**.

---

## Map (by section in the `.sql` file)

| Section | Functions (idea) |
|---------|------------------|
| **F1** | Strings: **`CONCAT`**, **`UPPER`**, **`LOWER`** on names / email |
| **F2** | **`LENGTH`**, **`LEFT`**, **`RIGHT`**, **`SUBSTRING`** on **`parts.sku`** |
| **F3** | **`TRIM`**, **`REPLACE`** |
| **F4** | Numeric: **`ROUND`**, **`CEIL`**, **`FLOOR`**, **`ABS`**, **`MOD`** on **`work_orders.total_cost`** |
| **F5** | Date/time: **`DATE_FORMAT`**, **`YEAR`**, **`TIMESTAMPDIFF`**, **`CURDATE()`** on **`appointments.scheduled_at`** |
| **F6** | Conditionals: **`IF`**, **`IFNULL`**, **`NULLIF`**, **`COALESCE`** |
| **F7** | **`GREATEST`**, **`LEAST`** |
| **F8** | **`FORMAT`** (locale-style number formatting) |
| **F9** | Pattern: **`REGEXP`** / **`RLIKE`** (simple) |
| **F10** | Aggregate helper: **`GROUP_CONCAT`** (with **`GROUP BY`**) |

---

## Notes

- **`NOW()`**, **`CURDATE()`** — results change with wall clock; fine for demos.  
- **`REGEXP`** behavior can depend on collation / version.  
- For production, prefer **parameterized** queries over building strings with **`CONCAT`** where injection is a risk (not shown here).

---

## Practice Tasks (medium / high complexity)

### T1 (Medium) — Customer contact normalization
Create a query that returns: `customer_id`, `full_name`, `primary_contact`, `contact_type`, `masked_email`.

Requirements:
- `full_name` = `first_name` + space + `last_name` (proper-case last name as in F1 approach).
- `primary_contact` uses `COALESCE(phone, email, 'NO_CONTACT')`.
- `contact_type`:
  - `PHONE` if `phone` is not `NULL`
  - `EMAIL` if `phone` is `NULL` and `email` is not `NULL`
  - `NONE` otherwise
- `masked_email` should keep first 2 chars before `@` and replace rest of local-part with `***` (e.g. `jo***@mail.com`).
- Limit to customer IDs `1..300`.

### T2 (Medium) — Work order value segmentation
Create a query over `work_orders` that returns: `id`, `total_cost`, `rounded_cost`, `cost_segment`, `distance_from_avg_500`.

Requirements:
- `rounded_cost` = `ROUND(total_cost, 2)`.
- `cost_segment` with `CASE`:
  - `< 300` => `LOW`
  - `300..799.99` => `MEDIUM`
  - `>= 800` => `HIGH`
- `distance_from_avg_500` = absolute difference from `500`.
- Return rows for IDs `1..800`, order by `total_cost DESC`, limit `40`.

### T3 (High) — Appointment urgency scoring
Create a query over `appointments` that returns: `id`, `scheduled_at`, `days_until_or_since`, `urgency_label`.

Requirements:
- `days_until_or_since` = `TIMESTAMPDIFF(DAY, NOW(), scheduled_at)`.
- `urgency_label`:
  - `OVERDUE` if days < 0
  - `TODAY` if days = 0
  - `SOON` if days between 1 and 7
  - `PLANNED` otherwise
- Add formatted date as `%Y-%m-%d %H:%i`.
- IDs `1..400`, ordered by `scheduled_at`.

### T4 (High) — SKU quality checks
Create a query over `parts` that returns: `id`, `sku`, `sku_len`, `sku_quality`, `normalized_sku`.

Requirements:
- `sku_len` = `LENGTH(sku)`.
- `sku_quality`:
  - `BAD` if `sku` has spaces (`REGEXP ' '`) or length < 6
  - `GOOD` otherwise
- `normalized_sku` = uppercase SKU with spaces removed.
- IDs `1..1000`, limit `60`.

### T5 (High) — Status-level cost analytics
Create an aggregate query on `work_orders` grouped by `status` that returns:
`status`, `orders_count`, `min_cost`, `max_cost`, `avg_cost_2d`, `cost_span`, `sample_order_ids`.

Requirements:
- `cost_span` = `max_cost - min_cost` (use expression or `GREATEST/LEAST` logically).
- `sample_order_ids` = `GROUP_CONCAT(id ORDER BY id SEPARATOR ',')`.
- Use orders with IDs `1..5000`.
- Sort by `avg_cost_2d DESC`.

### T6 (High) — Vehicle plate diagnostics
Create a query over `vehicles` that returns:
`id`, `plate`, `plate_clean`, `prefix`, `suffix`, `plate_flag`.

Requirements:
- `plate_clean` = trimmed plate, uppercase.
- `prefix` = first 2 chars, `suffix` = last 2 chars.
- `plate_flag`:
  - `MISSING` if plate is `NULL` or empty after trim
  - `SHORT` if cleaned length < 5
  - `OK` otherwise
- IDs `1..400`, limit `50`.
