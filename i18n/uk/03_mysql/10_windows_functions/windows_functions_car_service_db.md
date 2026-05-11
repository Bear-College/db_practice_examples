# Віконні функції — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/10_windows_functions/windows_functions_car_service_db.md)

Приклади використовують **`car_service_db`** з **`01_database_mysql/car_service_db.sql.gz`**. Скрипт — **`10_windows_functions/car_service_windows_functions_examples.sql`**.

**Вимога:** MySQL **8.0+** (віконні функції недоступні у MySQL 5.7).

```bash
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 10_windows_functions/car_service_windows_functions_examples.sql
```

**Продуктивність:** запити використовують **`WHERE id BETWEEN …`** на великих таблицях, щоб виконуватися швидко.

---

## Поняття

| Функція / секція | Роль |
|------------------|------|
| **`OVER ( )`** | Перетворює агрегатну або ранжувальну функцію на **віконну** (рядок залишається видимим). |
| **`PARTITION BY`** | Окремі вікна на кожну групу (як «GROUP BY», але без згортання рядків). |
| **`ORDER BY` всередині `OVER`** | Сортування рядків **усередині** кожної партиції (потрібно для ранжування / зсувів). |
| **Кадр `ROWS` / `RANGE`** | Які рядки-сусіди беруть участь у **`LAST_VALUE`**, ковзних агрегатах тощо. |
| **`WINDOW name AS (…)`** | Повторно використати одне визначення вікна для кількох стовпців. |

---

## Приклади у `.sql`-файлі

1. **`ROW_NUMBER()`** — унікальна нумерація в межах `work_orders.status`.
2. **`RANK()` / `DENSE_RANK()`** — нічиї обробляються інакше, ніж у `ROW_NUMBER`.
3. **`SUM(…) OVER (PARTITION BY …)`** — підсумок партиції без `GROUP BY`.
4. **`AVG(…) OVER`** — ковзне / партиційне середнє (див. коментарі).
5. **`LAG()` / `LEAD()`** — попередній / наступний рядок за `ORDER BY` (напр., на механіка).
6. **`NTILE(n)`** — розбити партицію на *n* кошиків.
7. **`FIRST_VALUE()` / `LAST_VALUE()`** — явний кадр **`ROWS`** для **`LAST_VALUE`** (типовий кадр може здивувати).
8. **Іменоване `WINDOW`** — одна партиція/порядок повторно використовується для кількох функцій.

---

## Примітка щодо `LAST_VALUE`

З типовим кадром **`LAST_VALUE()`** часто відповідає **поточному** рядку. У скрипті, де потрібно, використовується явний **`ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`** (або еквівалент), щоб «останній» означав останнього у партиції.
