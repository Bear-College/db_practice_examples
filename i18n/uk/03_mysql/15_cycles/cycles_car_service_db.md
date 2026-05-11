# Цикли — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/15_cycles/cycles_car_service_db.md)

«Цикли» тут означають **повторюване виконання** в SQL двома основними способами:

1. **Процедурні цикли** всередині **`CREATE PROCEDURE`** — **`WHILE`**, **`REPEAT` … `UNTIL`** і **`LOOP` … `LEAVE`** (збережені програми MySQL).
2. **Рекурсивний CTE** — **`WITH RECURSIVE`** (MySQL **8.0+**) для множинно-орієнтованої «ітерації» (наприклад, числові послідовності, дерева); це не той самий синтаксис, що цикли збережених програм.

**Скрипт:** `15_cycles/car_service_cycles_examples.sql`

```bash
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 15_cycles/car_service_cycles_examples.sql
```

Використовуйте клієнт **mysql**, щоб **`DELIMITER`** працював.

---

## Процедурні цикли (у процедурах)

| Конструкція | Коли зупиняється |
|-------------|-------------------|
| **`WHILE condition DO … END WHILE`** | Поки умова істинна (перевірка зверху). |
| **`REPEAT … UNTIL condition END REPEAT`** | Доки умова не стане істинною (перевірка знизу). |
| **`label: LOOP … END LOOP`** | Використовуйте **`LEAVE label`** (а опційно — **`ITERATE label`**) для виходу або повтору. |

Віддавайте перевагу **множинному (set-based)** SQL, де можливо; цикли — для процедурної логіки, малих пакетів або навчання.

---

## Рекурсивний CTE

- **`WITH RECURSIVE name AS ( anchor UNION ALL recursive )`** — якірна та рекурсивна частини мають бути **сумісними за `UNION`**.
- Серверний ліміт: **`cte_max_recursion_depth`** (сесійний) — піднімайте лише за потреби.

---

## Вміст скрипту

- Лабораторна таблиця **`cyc_log`** для рядків, що вставляються в демо-циклах.
- Процедури: **`WHILE`**, **`REPEAT`**, **`LOOP` + `LEAVE`**, опційно **курсор** по маленькому зрізу **`work_orders`**.
- Числова послідовність через **`WITH RECURSIVE`**.
- Опційне **`DROP`** / **`DROP TABLE`** наприкінці.
