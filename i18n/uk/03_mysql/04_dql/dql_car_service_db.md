# DQL (Data Query Language) — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/04_dql/dql_car_service_db.md)

Ці приклади покривають **основні теми `SELECT`** (базові секції, `NULL`, насичений `WHERE`, агрегати, `GROUP BY`, `HAVING`, `ORDER BY`, `DISTINCT`, `LIMIT` / `OFFSET`). Вони виконуються на реальній базі, завантаженій з **`01_database_mysql/car_service_db.sql.gz`** (ім'я бази: **`car_service_db`**).

Виконувані запити: **`04_dql/car_service_dql_examples.sql`** (з кореня репозиторію).

```bash
mysql -u ... -p ... -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 04_dql/car_service_dql_examples.sql
```

**Продуктивність:** дамп великий; скрипт використовує **`WHERE id BETWEEN …`** (і подібне), щоб запити лишалися швидкими на занятті.

---

## Карта секцій та операторів (відповідає матеріалам курсу)

| Тема | Ідеї SQL |
|------|----------|
| **(a) `SELECT`** | Обрати стовпці або вирази; перейменувати через `AS`. |
| **(b) `FROM`** | З яких таблиць беруться рядки (`FROM customers`, далі — `JOIN`). |
| **(c) `WHERE`** | Фільтрувати рядки **до** групування. |
| **(d) `GROUP BY`** | Один результуючий рядок на групу; використовується з агрегатами. |
| **`SELECT … FROM …`** | Мінімальна форма запиту: перелік стовпців, перелік таблиць. |
| **`NULL`** | Невідоме / відсутнє; перевіряти через `IS NULL`, `IS NOT NULL`; за потреби `COALESCE(col, default)`. |
| **`WHERE` (просте)** | Одна умова, напр. `status = 'completed'`. |
| **`WHERE` + `AND`, `OR`, `IN`, `LIKE`, `IS`, `NOT`** | Поєднання предикатів; шаблони з `LIKE 'A%'`; множини з `IN (...)`; заперечення через `NOT` або `<>`. |
| **Агрегати** | `COUNT`, `SUM`, `AVG`, `MIN`, `MAX` — підсумок над багатьма рядками. |
| **`GROUP BY`** | Задати групи (напр., за `status`); агрегати працюють у межах групи. |
| **`HAVING`** | Фільтр **груп** (після `GROUP BY`); умови з агрегатами. |
| **`ORDER BY`** | Сортування (`ASC` / `DESC`). |
| **`DISTINCT`** | Видалити дублікати значень у вказаних виразах. |
| **`LIMIT`** | Повернути не більше *N* рядків. |
| **`LIMIT` … `OFFSET` …** | Пропустити *OFFSET* рядків, потім узяти *LIMIT* (пагінація). |

---

## Точки дотику зі схемою (з дампу)

- **`customers`** — `id`, `first_name`, `last_name`, `phone`, `email`
- **`vehicles`** — `id`, `customer_id`, `plate`, `car_brands_id`, …
- **`car_brands`** — `id`, `name`
- **`work_orders`** — `id`, `vehicle_id`, `mechanic_id`, `status`, `total_cost`
- **`parts`** — `id`, `sku`, `name`, `brand`

Приклади значень **`work_orders.status`:** `new`, `in_progress`, `waiting_parts`, `completed`, `cancelled`.

---

## Вправи (зіставлені з `car_service_dql_examples.sql`)

### 1 — `SELECT … FROM …`

**Завдання:** обрати конкретні стовпці з **`customers`** (обмежений діапазон id).

### 2 — `NULL`

**Завдання:** рядки **без** `phone`; покажіть `COALESCE` для відображення.

### 3 — `WHERE` (просте)

**Завдання:** **`work_orders`** зі `status = 'completed'`.

### 4 — `WHERE` з `AND`, `OR`, `IN`, `LIKE`, `IS`, `NOT`

**Завдання:** кілька прикладів: шаблони імен з **`LIKE`**; множини статусів з **`IN`**; **`IS NOT NULL`** на `mechanic_id`; **`NOT`** на status.

### 5 — Агрегати: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`

**Завдання:** один **`SELECT`** на зрізі **`work_orders`**, що повертає всі п'ять агрегатів.

### 6 — `GROUP BY`

**Завдання:** підрахувати кількість рядків на кожен **`status`**.

### 7 — `HAVING`

**Завдання:** залишити лише групи з достатньою кількістю рядків і мінімальною середньою вартістю (разом з **`GROUP BY status`**).

### 8 — `ORDER BY`

**Завдання:** відсортувати **`work_orders`** за **`total_cost`** за спаданням.

### 9 — `DISTINCT`

**Завдання:** унікальні значення **`status`**; унікальні значення **`parts.brand`** (не-NULL).

### 10 — `LIMIT`

**Завдання:** обмежити розмір вибірки з **`parts`**.

### 11 — `LIMIT` … `OFFSET` …

**Завдання:** перейти по сторінках **`customers`** (напр., рядки 21–30 за `LIMIT 10 OFFSET 20`).

### Доповнення S1–S2 — `JOIN` (після основ одної таблиці)

**Завдання:** **`vehicles`** + **`car_brands`**; потім **`work_orders`** + **`vehicles`** + **`customers`**.

---

### Якщо запит повертає порожній результат

Розширте межі **`BETWEEN`**. Фільтри **`HAVING`** можуть відкинути всі групи, якщо пороги задано надто суворо — зменшіть обмеження на **`COUNT`** або **`AVG`** для тестування.
