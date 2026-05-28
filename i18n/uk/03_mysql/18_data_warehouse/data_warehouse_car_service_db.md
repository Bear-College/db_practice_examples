# Data Warehouse (сховище даних) — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/18_data_warehouse/data_warehouse_car_service_db.md)

Урок вводить **сховище даних** у вигляді **зіркової схеми** в `car_service_db`: таблиці вимірів (`dw_dim_*`) та фактів (`dw_fact_work_orders`), завантажені з операційних таблиць. Ви побачите ETL-копіювання обмеженого зрізу OLTP-даних і аналітичні запити по зірці.

Готовий скрипт: [`18_data_warehouse/car_service_data_warehouse_examples.sql`](../../../../03_mysql/18_data_warehouse/car_service_data_warehouse_examples.sql).

```bash
mysql -u root car_service_db < 03_mysql/18_data_warehouse/car_service_data_warehouse_examples.sql
```

---

## Зіркова схема

```text
   dw_dim_customer ──customer_sk──> dw_fact_work_orders <──brand_sk── dw_dim_brand
```

| Об’єкт | Роль |
|--------|------|
| **Факт** `dw_fact_work_orders` | Міри (`total_cost`) + ключі вимірів; зерно = 1 рядок / замовлення |
| **Вимір** `dw_dim_customer` | Хто — `last_name`, `email` |
| **Вимір** `dw_dim_brand` | Бренд авто — `brand_name` |
| **ETL** | `INSERT … SELECT` з OLTP-таблиць |

---

## Вправа 1 — Створення вимірів і фактів

### Контекст

Команда DW визначає **узгоджені виміри** та **таблицю фактів** із чітким зерном.

### Чого ви навчитеся

- Сурогатні ключі (`customer_sk`) vs бізнес-ключі (`customer_id`).
- Факт зберігає **міри** та ключі вимірів.

### Задіяні таблиці

`dw_dim_customer`, `dw_dim_brand`, `dw_fact_work_orders` — див. companion SQL.

### Завдання

Створити три таблиці `dw_*` з PK, UNIQUE на бізнес-ключах вимірів, FK з факту.

### Очікуваний результат

Таблиці з’являються після `CREATE`; рядки — після Вправи 2.

### Підказка

`AUTO_INCREMENT` на вимірах; `work_order_id` — PK факту.

### Розв'язання

Блоки `CREATE TABLE` у [`car_service_data_warehouse_examples.sql`](../../../../03_mysql/18_data_warehouse/car_service_data_warehouse_examples.sql).

### Покрокове пояснення

1. Сурогатні ключі відокремлюють DW від змін id в OLTP.
2. `UNIQUE (customer_id)` — бізнес-ключ для ETL.
3. FK документують зірку; у великих DW їх інколи прибирають для швидкості завантаження.

---

## Вправа 2 — ETL-завантаження з OLTP

### Контекст

Нічний batch: копіювання клієнтів, брендів і замовлень у DW (тут — обмежений зріз).

### Чого ви навчитеся

- ETL як `INSERT … SELECT` з join для сурогатних ключів.
- Порядок: спочатку виміри, потім факти.

### Завдання

Завантажити клієнтів `1–500`, бренди `1–300`, факти для замовлень `1–5000`. Показати `COUNT(*)` з `dw_fact_work_orders`.

### Очікуваний результат

```text
+-----------+
| fact_rows |
+-----------+
|       500 |
+-----------+
```

### Розв'язання

```sql
INSERT INTO dw_dim_customer (customer_id, last_name, email)
SELECT c.id, c.last_name, c.email FROM customers AS c WHERE c.id BETWEEN 1 AND 500;

INSERT INTO dw_dim_brand (brand_id, brand_name)
SELECT b.id, b.name FROM car_brands AS b WHERE b.id BETWEEN 1 AND 300;

INSERT INTO dw_fact_work_orders (work_order_id, customer_sk, brand_sk, status, total_cost)
SELECT wo.id, dc.customer_sk, db.brand_sk, wo.status, wo.total_cost
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN dw_dim_customer AS dc ON dc.customer_id = v.customer_id
INNER JOIN dw_dim_brand AS db ON db.brand_id = v.brand_id
WHERE wo.id BETWEEN 1 AND 5000;

SELECT COUNT(*) AS fact_rows FROM dw_fact_work_orders;
```

### Покрокове пояснення

1. Без вимірів немає куди посилатися FK у фактах.
2. `BETWEEN` обмежує час на занятті.
3. У продакшені — інкрементальні завантаження та контроль якості.

---

## Вправа 3 — Аналітичний запит по зірці

### Контекст

Аналітик: *виручка за брендом і статусом* — лише DW-таблиці.

### Завдання

`GROUP BY brand_name, status`; топ-15 за `revenue`.

### Очікуваний результат

```text
+------------+---------------+--------+---------+
| brand_name | status        | orders | revenue |
+------------+---------------+--------+---------+
| Brand_100  | cancelled     |      5 | 2650.00 |
| ...        |               |        |         |
+------------+---------------+--------+---------+
```

### Розв'язання

```sql
SELECT db.brand_name, f.status,
       COUNT(*) AS orders,
       ROUND(SUM(f.total_cost), 2) AS revenue
FROM dw_fact_work_orders AS f
INNER JOIN dw_dim_brand AS db ON db.brand_sk = f.brand_sk
GROUP BY db.brand_name, f.status
ORDER BY revenue DESC
LIMIT 15;
```

### Покрокове пояснення

1. Менше join-ів, ніж на сирому OLTP — ім’я бренду вже у вимірі.
2. Ті самі агрегати, що в OLAP (`17_oltp_olap`), інша фізична модель.

---

## Вправа 4 — Навіщо окреме сховище

### Контекст

Той самий звіт можна зібрати на `work_orders` + `vehicles` (урок `17_oltp_olap`). DW відокремлює навантаження, історію та узгоджені визначення.

### Завдання

Назвіть три причини мати `dw_*` для СТО.

### Очікуваний результат (концептуально)

1. Важкі `GROUP BY` не гальмують касовий OLTP.
2. Виміри можуть зберігати **історію** (SCD).
3. **Узгоджені виміри** для фінансів і операцій.

### Пов’язані уроки

- [`17_oltp_olap/`](../../../03_mysql/17_oltp_olap/)
- [`07_join/`](../../../03_mysql/07_join/)
