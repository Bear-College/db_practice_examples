# OLTP vs OLAP — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/17_oltp_olap/oltp_olap_car_service_db.md)

Цей урок порівнює навантаження **OLTP** (Online Transaction Processing — операційна обробка транзакцій) та **OLAP** (Online Analytical Processing — аналітична обробка) на одній схемі `car_service_db`. OLTP-запити обслуговують щоденні операції (одне замовлення, один клієнт); OLAP-запити живлять звіти та дашборди (агрегати над тисячами рядків).

Готовий скрипт: [`17_oltp_olap/car_service_oltp_olap_examples.sql`](../../../../03_mysql/17_oltp_olap/car_service_oltp_olap_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/17_oltp_olap/car_service_oltp_olap_examples.sql
```

---

## OLTP vs OLAP коротко

| Аспект | OLTP | OLAP |
|--------|------|------|
| **Мета** | Вести бізнес (записи, оплати, зміна статусів) | Розуміти бізнес (тренди, KPI, зрізи) |
| **Типовий SQL** | `SELECT` за PK; короткі `UPDATE`/`INSERT` | `GROUP BY`, `SUM`, `AVG`, багато `JOIN` |
| **Рядків** | Мало (часто 1) | Багато (тисячі — мільйони) |
| **Узгодженість** | Сильна; у транзакціях | Часто eventual; репліки / сховище |
| **Схема** | Нормалізована (3NF) | Денормалізована (зірка / сніжинка) |
| **Користувачі** | Касири, механіки, API | Аналітики, менеджери, BI |

---

## Точки дотику зі схемою

- **`work_orders`** — `id`, `vehicle_id`, `status`, `total_cost`
- **`vehicles`** — `id`, `customer_id`, `plate`, `brand_id`
- **`customers`** — `id`, `last_name`
- **`car_brands`** — `id`, `name`

---

## Вправа 1 — OLTP: точкове читання (одне замовлення)

### Контекст

Механік відкриває замовлення **№42** на планшеті: один рядок з номером авто та прізвищем клієнта — швидко, за первинним ключем.

### Чого ви навчитеся

- OLTP-читання: фільтр за **первинним ключем**, кілька стовпців для UI.
- `INNER JOIN` лише для відображення пов’язаних сутностей.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `status`, `total_cost`, `vehicle_id` |
| `vehicles` | `id`, `plate`, `customer_id` |
| `customers` | `id`, `last_name` |

### Завдання

Повернути замовлення з `id = 42`, включно з `plate` та `last_name`.

### Очікуваний результат (реальні рядки з дампу)

```text
+----+-------------+------------+----------+------------+
| id | status      | total_cost | plate    | last_name  |
+----+-------------+------------+----------+------------+
| 42 | in_progress |     504.20 | AA0042BB | Surname_42 |
+----+-------------+------------+----------+------------+
```

### Підказка

`WHERE wo.id = 42` — класичний OLTP-доступ за PK.

### Розв'язання

```sql
SELECT wo.id,
       wo.status,
       wo.total_cost,
       v.plate,
       c.last_name
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
WHERE wo.id = 42;
```

### Покрокове пояснення

1. **`WHERE wo.id = 42`** — один пошук по кластерному PK InnoDB.
2. Два join-и додають дані для екрана без зміни зернистості (один рядок результату).
3. У продакшені поруч часто йде `UPDATE` статусу (Вправа 2) в одній транзакції.

---

## Вправа 2 — OLTP: вузький запис (зміна статусу)

### Контекст

СТО переводить замовлення **№2** з `new` у `in_progress`, коли механік починає роботу — один рядок `UPDATE`.

### Чого ви навчитеся

- OLTP-запис: змінити **один рядок** з точним `WHERE`.
- Типовий ланцюжок `SELECT` → `UPDATE` у транзакції.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `status` |

### Завдання

1. Прочитати рядки `id BETWEEN 1 AND 5`.
2. `UPDATE` рядка `id = 2` на `in_progress`, якщо `status = 'new'`.
3. Перевірити; повернути `status = 'new'` для повторного запуску скрипта.

### Очікуваний результат

```text
+----+-------------+
| id | status      |
+----+-------------+
|  2 | in_progress |
+----+-------------+
```

### Підказка

Завжди `WHERE id = …` (і часто старий `status`), щоб не оновити всю таблицю.

### Розв'язання

```sql
SELECT id, status, total_cost
FROM work_orders
WHERE id BETWEEN 1 AND 5;

UPDATE work_orders
SET status = 'in_progress'
WHERE id = 2
  AND status = 'new';

SELECT id, status
FROM work_orders
WHERE id = 2;

UPDATE work_orders
SET status = 'new'
WHERE id = 2;
```

### Покрокове пояснення

1. **`UPDATE … WHERE id = 2 AND status = 'new'`** безпечний при повторному запуску.
2. Обгортайте в `START TRANSACTION` / `COMMIT`, якщо є побічні ефекти (інвойс, склад).
3. OLTP оптимізований під **короткі блокування** на кількох рядках.

---

## Вправа 3 — OLAP: агрегація за статусом

### Контекст

Керівництву потрібні виручка та середній чек **по статусах** замовлень на зрізі даних.

### Чого ви навчитеся

- OLAP: `GROUP BY` + `COUNT`, `SUM`, `AVG` над багатьма рядками.
- Обмеження `WHERE id BETWEEN …` для швидкості на занятті.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Завдання

Для `id BETWEEN 1 AND 50000` по кожному `status`: кількість, виручка, середній чек. Сортувати за виручкою спадно.

### Очікуваний результат

```text
+---------------+-------------+-------------+------------+
| status        | order_count | revenue     | avg_ticket |
+---------------+-------------+-------------+------------+
| completed     |       10000 | 30001500.00 |    3000.15 |
| waiting_parts |       10000 | 30000500.00 |    3000.05 |
| ...           |             |             |            |
+---------------+-------------+-------------+------------+
```

### Підказка

Один `SELECT` з `GROUP BY status` — join не обов’язковий.

### Розв'язання

```sql
SELECT wo.status,
       COUNT(*) AS order_count,
       ROUND(SUM(wo.total_cost), 2) AS revenue,
       ROUND(AVG(wo.total_cost), 2) AS avg_ticket
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 50000
GROUP BY wo.status
ORDER BY revenue DESC;
```

### Покрокове пояснення

1. Сканування десятків тисяч рядків прийнятне в OLAP; на гарячому OLTP-шляху — ні.
2. **`GROUP BY`** збирає рядки в «відра» — протилежність Вправі 1.
3. Такі запити часто йдуть на **репліку** або **сховище** (урок `18_data_warehouse`).

---

## Вправа 4 — OLAP: зріз «бренд × статус»

### Контекст

Дашборд BI: **виручка за брендом авто та статусом замовлення** — кілька join-ів і `HAVING`.

### Чого ви навчитеся

- Звітність по нормалізованій OLTP-схемі (join вимірів під час запиту).
- `HAVING` для відсікання рідкісних груп.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders`, `vehicles`, `car_brands` | див. companion SQL |

### Завдання

Для `wo.id BETWEEN 1 AND 20000`, групувати за `brand_name` та `status`, `HAVING COUNT(*) >= 100`, топ-10 за виручкою.

### Очікуваний результат

```text
+------------+---------------+--------+---------------+
| brand_name | status        | orders | total_revenue |
+------------+---------------+--------+---------------+
| Brand_100  | cancelled     |    200 |     301000.00 |
| ...        |               |        |               |
+------------+---------------+--------+---------------+
```

### Підказка

Ланцюжок `work_orders → vehicles → car_brands`.

### Розв'язання

```sql
SELECT b.name AS brand_name,
       wo.status,
       COUNT(*) AS orders,
       ROUND(SUM(wo.total_cost), 2) AS total_revenue
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN car_brands AS b ON b.id = v.brand_id
WHERE wo.id BETWEEN 1 AND 20000
GROUP BY b.name, wo.status
HAVING COUNT(*) >= 100
ORDER BY total_revenue DESC
LIMIT 10;
```

### Покрокове пояснення

1. Три таблиці в одному запиті — типово для OLTP; сховище попередньо з’єднує в fact/dim.
2. **`HAVING`** фільтрує групи після агрегації.
3. У піковий час краще не навантажувати OLTP такими звітами.

---

## Пов’язані уроки

- [`08_indexes/`](../../../03_mysql/08_indexes/) — прискорення OLTP та фільтрів OLAP.
- [`18_data_warehouse/`](../../../03_mysql/18_data_warehouse/) — зіркова схема та ETL.
- [`09_transactions/`](../../../03_mysql/09_transactions/) — транзакції для OLTP-записів.
