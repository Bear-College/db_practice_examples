# JOIN-и — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/07_join/joins_car_service_db.md)

Приклади використовують **`car_service_db`** з **`01_database_mysql/car_service_db.sql.gz`**. Виконуваний скрипт — **`07_join/car_service_join_examples.sql`**.

```bash
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 07_join/car_service_join_examples.sql
```

**Продуктивність:** `WHERE … id BETWEEN …` та **`LIMIT`** утримують великі таблиці керованими.

---

## Просто vs складно

| Рівень | Тема |
|--------|------|
| **Просто** | `INNER JOIN` двох таблиць; ланцюжок із **трьох** таблиць за зовнішніми ключами. |
| **Просто** | **`LEFT JOIN`**: зберегти всі рядки лівої таблиці; права сторона може бути `NULL`. |
| **Просто** | **`INNER JOIN` + `WHERE`** — фільтрування після з'єднання. |
| **Складно** | **Anti-join** через `LEFT JOIN … WHERE … IS NULL` (рядки *без* відповідника праворуч). |
| **Складно** | **Кілька `LEFT JOIN`** (один «головний» рядок і кілька опціональних таблиць). |
| **Складно** | **Само-з'єднання** через міст (`equivalents` + два аліаси на `parts`). |
| **Складно** | **`INNER JOIN` до похідної таблиці** (`FROM (SELECT … GROUP BY …) AS t`). |
| **Складно** | **Шаблон `FULL OUTER JOIN`** у MySQL: `UNION` рядків з лівого боку та з правого (без власного ключового слова). |
| **Додатково** | **`RIGHT JOIN`** — те саме, що `LEFT JOIN`, але з обміняними таблицями (всі рядки з **правої**). |
| **Додатково** | **`CROSS JOIN`** — декартів добуток; **завжди** обмежуйте обидві сторони (або беріть малі підзапити). |
| **Додатково** | **Шаблон `FULL OUTER`** — `LEFT JOIN … UNION ALL … LEFT JOIN … WHERE протилежний бік IS NULL` (у MySQL немає ключового `FULL OUTER JOIN`). |
| **Додатково** | **Багато з'єднань** — один `FROM` з кількома `INNER` / `LEFT` (напр., замовлення → авто → клієнт → бренд → позиція замовлення → тип робіт). |

---

## Точки дотику зі схемою

- **`vehicles.car_brands_id`** → **`car_brands.id`**
- **`work_orders.vehicle_id`** → **`vehicles.id`**
- **`vehicles.customer_id`** → **`customers.id`**
- **`feedback.customer_id`** → **`customers.id`**
- **`employees.role_id`** → **`roles.id`**
- **`equivalents.part_id_1` / `part_id_2`** → **`parts.id`**
- **`part_prices.part_id`** → **`parts.id`**
- **`fuel_types`** — невелика довідкова таблиця (`id`, `name`) для безпечних демо `CROSS JOIN`

Зіставте кожен пронумерований блок у `.sql`-файлі з вправами нижче.

---

## Прості вправи

1. **`INNER JOIN`** — `vehicles` + `car_brands` (назва бренду для кожного авто).
2. **`INNER JOIN`** — `work_orders` + `vehicles` (номерний знак для кожного замовлення).
3. **Три-табличний `INNER JOIN`** — `work_orders` → `vehicles` → `customers`.
4. **`LEFT JOIN`** — `customers` + `feedback` (rating може бути `NULL`).
5. **`INNER JOIN`** — `parts` + `part_prices` (SKU + роздрібна ціна).

6. **`INNER JOIN`** — `employees` + `roles` (працівник + посада).

## Складні вправи

6. **Anti-join** — клієнти в діапазоні, які **не** мають жодного авто (`LEFT JOIN` + `vehicles.id IS NULL`).
7. **Кілька `LEFT JOIN`** — клієнт з не більше ніж **одним** записом feedback і **одним** авто (через агрегати «перший id» з подальшим з'єднанням з реальними рядками).
8. **Міст + само-з'єднання** — `equivalents` + двічі `parts` (`p1`, `p2`) для пар SKU.
9. **З'єднання з похідною таблицею** — клієнти з попередньо обчисленою кількістю авто.
10. **Шаблон `FULL OUTER`** — `UNION` непоєднаних з лівої та з правої для двох малих зрізів (напр., `warehouses` ↔ `inventory`).

## Додаткові типи з'єднань (той самий `.sql`, блоки **R1–R3**, **MJ1**)

11. **`RIGHT JOIN`** — `car_brands` `RIGHT JOIN` `vehicles` (усі авто зі зрізу; бренд зліва).
12. **`CROSS JOIN`** — невеликі зрізи **`car_brands`** × **`fuel_types`** (сітка 12 рядків); ніколи не робіть `CROSS JOIN` на великих базових таблицях без фільтрів.
13. **Шаблон `FULL OUTER`** — `warehouses` `LEFT JOIN` `inventory` **union all** «сироти inventory» (`inventory` `LEFT JOIN` `warehouses` … `WHERE w.id IS NULL`); друга частина зазвичай порожня, якщо FK цілі.
14. **Багато з'єднань** — **`work_orders` → `vehicles` → `customers` → `car_brands` → `order_jobs` → `job_types`** (шість відношень в одному стейтменті).

Якщо результат порожній — розширте межі `BETWEEN`.
