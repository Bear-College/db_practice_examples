# Збережені процедури — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/14_procedures/procedures_car_service_db.md)

Приклади визначають **збережені процедури MySQL** з параметрами **`IN`**, **`OUT`** і **`INOUT`**, локальними змінними через **`DECLARE`** та викликом через **`CALL`**. Усі вони живуть у **`car_service_db`** (з **`01_database_mysql/car_service_db.sql.gz`**).

**Скрипт:** `14_procedures/car_service_procedures_examples.sql`

```bash
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 14_procedures/car_service_procedures_examples.sql
```

Використовуйте клієнт **mysql**, щоб **`DELIMITER`** працював при перенаправленні або `SOURCE` файлу.

---

## Поняття

| Елемент | Роль |
|---------|------|
| **`CREATE PROCEDURE name …`** | Іменований SQL-блок, що зберігається на сервері. |
| **`IN`** | Вхідний параметр (за замовчуванням, якщо опущено). |
| **`OUT`** | Вихідний параметр; викликач передає **користувацьку змінну** (наприклад, `@sum`). |
| **`INOUT`** | Читання й запис того ж параметра через користувацьку змінну. |
| **`DECLARE`** | Локальні змінні всередині `BEGIN … END`. |
| **`CALL proc(...)`** | Виконати процедуру. |

**Безпека:** у продакшні віддавайте перевагу **`DEFINER`** / **`SQL SECURITY INVOKER`** та мінімальним привілеям; ці лаб-приклади використовують значення за замовчуванням з освітньою метою.

---

## Процедури у `.sql`-файлі

1. **`sp_work_orders_by_status`** — `IN` статус + ліміт; повертає **набір результатів** (`SELECT`).
2. **`sp_sum_cost_slice`** — `OUT` загальна `SUM(total_cost)` по зрізу id.
3. **`sp_customer_count`** — `IN` мін/макс id; `OUT` кількість; використовує **`DECLARE`** + **`IF`**.
4. **`sp_append_tag`** — `INOUT` для користувацької змінної (рядковий тег).
5. Опціональне **`DROP PROCEDURE IF EXISTS`** наприкінці для видалення визначень.
