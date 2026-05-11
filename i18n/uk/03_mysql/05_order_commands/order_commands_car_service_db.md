# Порядок команд у SQL-запитах — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/05_order_commands/order_commands_car_service_db.md)

Ці вправи тренують **порядок написання** секцій у `SELECT` — порядок, у якому ви *пишете* їх (він відрізняється від порядку *виконання*). Кожна вправа парує реальний сценарій СТО із запитом, що задіює дедалі більше ланок ланцюжка, і завершується канонічними шаблонами пагінації.

Скрипт-компаньйон: [`05_order_commands/car_service_order_examples.sql`](../../../../03_mysql/05_order_commands/car_service_order_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/05_order_commands/car_service_order_examples.sql
```

**Продуктивність:** у головних таблицях ~100 000 рядків. Кожен приклад використовує `WHERE id BETWEEN …`, щоб скан був дешевим на занятті.

---

## Порядок написання секцій

| № | Секція | Роль (коротко) |
|---|---|---|
| 1 | **`SELECT`** | Які стовпці або агрегати показати. |
| 2 | **`FROM`** | З якої таблиці беруться рядки (базова таблиця). |
| 3 | **`JOIN`** | Приєднати інші таблиці (`INNER` / `LEFT` тощо). |
| 4 | **`WHERE`** | Фільтрує **рядки** **до** групування. |
| 5 | **`GROUP BY`** | Розбити рядки на групи (для агрегатів). |
| 6 | **`HAVING`** | Фільтрує **групи** **після** агрегації. |
| 7 | **`ORDER BY`** | Відсортувати результат. |
| 8 | **`LIMIT`** | Обмежити кількість рядків у відповіді. |
| 9 | **`LIMIT … OFFSET …`** | Пропустити *N* рядків і взяти наступні (пагінація). |

Не кожен запит містить усі секції. Порядок **виконання**, у якому MySQL **обчислює** запит, інший: `FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT / OFFSET`. Розуміти обидва порядки — і є мета цієї лекції.

---

## Точки дотику зі схемою

Вправи використовують **`work_orders`**, **`vehicles`**, **`customers`** та **`car_brands`**:

- **`customers`** — `id`, `first_name`, `last_name`
- **`vehicles`** — `id`, `customer_id`, `plate`, `brand_id`
- **`car_brands`** — `id`, `name`
- **`work_orders`** — `id`, `vehicle_id`, `status`, `total_cost`

Приклади значень **`work_orders.status`:** `new`, `in_progress`, `waiting_parts`, `completed`, `cancelled`.

---

## Вправа 1 — Повний ланцюжок секцій (сторінка 1)

### Контекст

Власник хоче віджет дашборду «топ клієнтів за середнім чеком». Для кожного клієнта рахуємо кількість замовлень і середню вартість — потім лишаємо тих, у кого хоча б одне замовлення і середній чек > ₴300, сортуємо за середнім спадно і повертаємо першу сторінку з 10 рядків.

### Чого ви навчитеся

- Писати кожну секцію в правильному порядку: `SELECT → FROM → JOIN → WHERE → GROUP BY → HAVING → ORDER BY → LIMIT … OFFSET`.
- Чому `WHERE` фільтрує рядки, а `HAVING` фільтрує групи.
- Додавати тайбрейкер (`c.id`) у `ORDER BY`, щоб пагінація була детермінованою.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `customers` | `id`, `last_name` |
| `vehicles` | `id`, `customer_id` |
| `work_orders` | `id`, `vehicle_id`, `total_cost` |

### Завдання

Для клієнтів `id BETWEEN 1 AND 20000` і замовлень `id BETWEEN 1 AND 200000` згрупувати за клієнтом і лишити лише тих, у кого `COUNT(wo.id) >= 1` і `AVG(wo.total_cost) > 300`. Сортувати за `avg_total_cost DESC`, потім `c.id ASC`. Перші 10 рядків (`LIMIT 10 OFFSET 0`).

### Очікуваний результат (реальні рядки з дампу)

```text
+-------------+---------------+------------------+----------------+
| customer_id | last_name     | work_order_count | avg_total_cost |
+-------------+---------------+------------------+----------------+
|       20000 | Surname_20000 |                1 |        2500.00 |
|       19999 | Surname_19999 |                1 |        2499.90 |
|       19998 | Surname_19998 |                1 |        2499.80 |
|       19997 | Surname_19997 |                1 |        2499.70 |
|       19996 | Surname_19996 |                1 |        2499.60 |
|       19995 | Surname_19995 |                1 |        2499.50 |
|       19994 | Surname_19994 |                1 |        2499.40 |
|       19993 | Surname_19993 |                1 |        2499.30 |
|       19992 | Surname_19992 |                1 |        2499.20 |
|       19991 | Surname_19991 |                1 |        2499.10 |
+-------------+---------------+------------------+----------------+
```

### Підказка

Два `INNER JOIN` через `vehicles`, агрегати в `SELECT`, фільтр **рядків** у `WHERE`, фільтр **груп** у `HAVING`, потім `ORDER BY ... DESC, c.id` і `LIMIT 10 OFFSET 0`.

### Розв'язання

```sql
SELECT c.id AS customer_id,
       c.last_name,
       COUNT(wo.id) AS work_order_count,
       ROUND(AVG(wo.total_cost), 2) AS avg_total_cost
FROM customers AS c
INNER JOIN vehicles AS v ON v.customer_id = c.id
INNER JOIN work_orders AS wo ON wo.vehicle_id = v.id
WHERE c.id BETWEEN 1 AND 20000
  AND wo.id BETWEEN 1 AND 200000
GROUP BY c.id, c.last_name
HAVING COUNT(wo.id) >= 1
   AND AVG(wo.total_cost) > 300
ORDER BY avg_total_cost DESC, c.id
LIMIT 10 OFFSET 0;
```

### Покрокове пояснення

1. **`SELECT` пишеться першим, але виконується останнім.** Аліаси (`avg_total_cost`), визначені тут, працюють у `ORDER BY`, але **не** у `WHERE` чи `GROUP BY` (вони виконуються раніше).
2. **`FROM customers AS c`** обирає драйверну таблицю; два `INNER JOIN` ідуть FK-ланцюжком `customers → vehicles → work_orders`.
3. **`WHERE` фільтрує рядки.** Предикати `id BETWEEN` рівнем рядка, тому вони сюди, а не в `HAVING`.
4. **`GROUP BY c.id, c.last_name`** має містити кожен не-агрегат із `SELECT` (`ONLY_FULL_GROUP_BY` у MySQL 8+ за замовч.).
5. **`HAVING`** бачить агрегати; `WHERE` — ні. `WHERE COUNT(*) >= 1` — синтаксична помилка.
6. **`ORDER BY avg_total_cost DESC, c.id`** використовує аліас `SELECT` як основний ключ і `c.id` як стабільний тайбрейкер — критично для пагінації.
7. **`LIMIT 10 OFFSET 0`** — «сторінка 1, 10 на сторінку». `OFFSET 0` — це явний default; іноді команди вимагають його для прозорості.

---

## Вправа 2 — Той самий ланцюжок, пагінація (сторінка 3)

### Контекст

Той самий віджет дашборду, але користувач натиснув «сторінка 3» — показати рядки 11–15. Пагінація означає, що **тіло запиту незмінне**; змінюємо лише `OFFSET` і `LIMIT`.

### Чого ви навчитеся

- Чому `ORDER BY` обов'язковий при пагінації.
- Формі `LIMIT n OFFSET m` для stateless-пагінації.

### Задіяні таблиці

Як у Вправі 1.

### Завдання

Той самий запит, що й у Вправі 1, але повернути рядки 11–15 (`LIMIT 5 OFFSET 10`).

### Очікуваний результат (реальні рядки з дампу)

```text
+-------------+---------------+------------------+----------------+
| customer_id | last_name     | work_order_count | avg_total_cost |
+-------------+---------------+------------------+----------------+
|       19990 | Surname_19990 |                1 |        2499.00 |
|       19989 | Surname_19989 |                1 |        2498.90 |
|       19988 | Surname_19988 |                1 |        2498.80 |
|       19987 | Surname_19987 |                1 |        2498.70 |
|       19986 | Surname_19986 |                1 |        2498.60 |
+-------------+---------------+------------------+----------------+
```

### Підказка

Всі секції до `ORDER BY` ідентичні; змінюйте лише `LIMIT 5 OFFSET 10`.

### Розв'язання

```sql
SELECT c.id AS customer_id,
       c.last_name,
       COUNT(wo.id) AS work_order_count,
       ROUND(AVG(wo.total_cost), 2) AS avg_total_cost
FROM customers AS c
INNER JOIN vehicles AS v ON v.customer_id = c.id
INNER JOIN work_orders AS wo ON wo.vehicle_id = v.id
WHERE c.id BETWEEN 1 AND 20000
  AND wo.id BETWEEN 1 AND 200000
GROUP BY c.id, c.last_name
HAVING COUNT(wo.id) >= 1
   AND AVG(wo.total_cost) > 300
ORDER BY avg_total_cost DESC, c.id
LIMIT 5 OFFSET 10;
```

### Покрокове пояснення

1. **Перші 10 рядків пропускаються** через `OFFSET 10`, далі `LIMIT 5` бере наступні 5. Рядки обираються вже **після** сортування.
2. **Пагінація потребує стабільного `ORDER BY`.** Без `c.id`-тайбрейкера два рівні `avg_total_cost` могли б помінятися місцями між сторінками — і ви побачили б дублі чи пропуски.
3. **`OFFSET 1000000` повільний.** MySQL все одно обчислить і відкине мільйон рядків. Для глибоких сторінок переходьте на **keyset**: `WHERE c.id > last_seen_id ORDER BY c.id LIMIT 10`.

---

## Вправа 3 — `ORDER BY` + `LIMIT` (без `OFFSET`)

### Контекст

Касиру потрібні 12 найдорожчих замовлень прямо зараз — щоб обдзвонити клієнтів і підтвердити оплату.

### Чого ви навчитеся

- `SELECT → FROM → WHERE → ORDER BY → LIMIT` — мінімальний шаблон «top-N».
- Чому тайбрейкер (`wo.id`) уникає «мерехтіння» порядку при рівних ключах.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Завдання

Повернути 12 замовлень з найбільшим `total_cost` у діапазоні `id BETWEEN 1 AND 50000`. Тайбрейкер — менший `id`.

### Очікуваний результат (реальні рядки з дампу)

```text
+-------+---------------+------------+
| id    | status        | total_cost |
+-------+---------------+------------+
| 49999 | completed     |    5499.90 |
| 49998 | waiting_parts |    5499.80 |
| 49997 | in_progress   |    5499.70 |
| 49996 | new           |    5499.60 |
| 49995 | cancelled     |    5499.50 |
| 49994 | completed     |    5499.40 |
| 49993 | waiting_parts |    5499.30 |
| 49992 | in_progress   |    5499.20 |
| 49991 | new           |    5499.10 |
| 49990 | cancelled     |    5499.00 |
| 49989 | completed     |    5498.90 |
| 49988 | waiting_parts |    5498.80 |
+-------+---------------+------------+
```

### Підказка

`ORDER BY total_cost DESC, id`, потім `LIMIT 12`.

### Розв'язання

```sql
SELECT wo.id,
       wo.status,
       wo.total_cost
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 50000
ORDER BY wo.total_cost DESC, wo.id
LIMIT 12;
```

### Покрокове пояснення

1. **Без `GROUP BY`/`HAVING`** — кожен рядок сам собою результат; агрегація не потрібна.
2. **Двоключове `ORDER BY`.** Перший ключ (`total_cost DESC`) дає топ-чеки; другий (`wo.id ASC`) робить порядок між однаковими цінами детермінованим.
3. **`LIMIT` застосовується після сортування.** Без `ORDER BY` «топ-12» позбавлений сенсу — MySQL може повернути будь-які 12.

---

## Вправа 4 — Без `GROUP BY` / `HAVING` (joins + `LEFT JOIN`)

### Контекст

Принтер чеків хоче на кожне сьогоднішнє замовлення коротку лінійку: id замовлення, ім'я клієнта, номер авто, бренд, сума. У деяких авто немає `brand_id`, тож використовуємо `LEFT JOIN` для бренду — рядок усе одно надрукується.

### Чого ви навчитеся

- Поєднанню `INNER JOIN` і `LEFT JOIN` у тому самому запиті.
- Чому порядок join не важливий для `INNER`, але важливий для `LEFT`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `total_cost` |
| `vehicles` | `id`, `customer_id`, `plate`, `brand_id` |
| `customers` | `id`, `first_name`, `last_name` |
| `car_brands` | `id`, `name` |

### Завдання

Для замовлень `id BETWEEN 1 AND 400` повернути `work_order_id`, `first_name`, `last_name`, `plate`, `brand_name`, `total_cost`. Сортувати за `total_cost DESC`, обмежити 15.

### Очікуваний результат (реальні рядки з дампу — перші 15)

```text
+---------------+------------+-------------+----------+------------+------------+
| work_order_id | first_name | last_name   | plate    | brand_name | total_cost |
+---------------+------------+-------------+----------+------------+------------+
|           400 | Name_400   | Surname_400 | AA0400BB | Brand_100  |     540.00 |
|           399 | Name_399   | Surname_399 | AA0399BB | Brand_099  |     539.90 |
|           398 | Name_398   | Surname_398 | AA0398BB | Brand_098  |     539.80 |
|           397 | Name_397   | Surname_397 | AA0397BB | Brand_097  |     539.70 |
|           396 | Name_396   | Surname_396 | AA0396BB | Brand_096  |     539.60 |
|           395 | Name_395   | Surname_395 | AA0395BB | Brand_095  |     539.50 |
|           394 | Name_394   | Surname_394 | AA0394BB | Brand_094  |     539.40 |
|           393 | Name_393   | Surname_393 | AA0393BB | Brand_093  |     539.30 |
|           392 | Name_392   | Surname_392 | AA0392BB | Brand_092  |     539.20 |
|           391 | Name_391   | Surname_391 | AA0391BB | Brand_091  |     539.10 |
|           390 | Name_390   | Surname_390 | AA0390BB | Brand_090  |     539.00 |
|           389 | Name_389   | Surname_389 | AA0389BB | Brand_089  |     538.90 |
|           388 | Name_388   | Surname_388 | AA0388BB | Brand_088  |     538.80 |
|           387 | Name_387   | Surname_387 | AA0387BB | Brand_087  |     538.70 |
|           386 | Name_386   | Surname_386 | AA0386BB | Brand_086  |     538.60 |
+---------------+------------+-------------+----------+------------+------------+
```

### Підказка

Три `INNER JOIN` (`wo → v → c`) і один `LEFT JOIN` (`v → b`). Без `GROUP BY`.

### Розв'язання

```sql
SELECT wo.id AS work_order_id,
       c.first_name,
       c.last_name,
       v.plate,
       b.name AS brand_name,
       wo.total_cost
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
LEFT JOIN car_brands AS b ON b.id = v.brand_id
WHERE wo.id BETWEEN 1 AND 400
ORDER BY wo.total_cost DESC
LIMIT 15;
```

### Покрокове пояснення

1. **Три `INNER JOIN` в ланцюжку** проходять FK-ієрархію `work_orders → vehicles → customers` — у результаті лишаються рядки, що мають збіги в усіх трьох таблицях.
2. **`LEFT JOIN car_brands`** залишає авто, у яких `brand_id IS NULL`; `b.name` для таких буде `NULL`. Якщо замінити на `INNER JOIN`, MySQL непомітно відкине ці замовлення.
3. **`ORDER BY total_cost DESC` тут достатньо** — результат маленький і не пагінується, тож тайбрейкер опціональний (`work_order_id` був би природним вибором, якби потрібен був).

---

## Вправа 5 — Альтернативний синтаксис `LIMIT offset, row_count`

### Контекст

У старому коді й сніпетах зі Stack Overflow часто бачите дво-аргументну форму `LIMIT m, n` — старіше написання пагінації в MySQL. Воно повністю еквівалентне `LIMIT n OFFSET m` і обов'язково спливе в будь-якій MySQL-кодбазі.

### Чого ви навчитеся

- `LIMIT offset, row_count` ≡ `LIMIT row_count OFFSET offset`.
- Чому сучасна форма з `OFFSET` читабельніша.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `status`, `total_cost` |

### Завдання

Для `id BETWEEN 1 AND 10000`, відсортованих за `total_cost ASC, id`, пропустити перші 10 рядків і взяти наступні 5 (`LIMIT 10, 5`).

### Очікуваний результат (реальні рядки з дампу)

```text
+----+---------------+------------+
| id | status        | total_cost |
+----+---------------+------------+
| 11 | new           |     501.10 |
| 12 | in_progress   |     501.20 |
| 13 | waiting_parts |     501.30 |
| 14 | completed     |     501.40 |
| 15 | cancelled     |     501.50 |
+----+---------------+------------+
```

### Підказка

`LIMIT 10, 5` ≡ `LIMIT 5 OFFSET 10`.

### Розв'язання

```sql
SELECT id,
       status,
       total_cost
FROM work_orders
WHERE id BETWEEN 1 AND 10000
ORDER BY total_cost ASC, id
LIMIT 10, 5;
```

### Покрокове пояснення

1. **Стежте за порядком аргументів.** У `LIMIT a, b` перше число — **offset**, друге — row count. У «сучасній» формі `LIMIT b OFFSET a` числа стоять в тому самому порядку. Плутанина між цими формами — поширений баг.
2. **PostgreSQL та SQL-стандарт** підтримують лише довгу форму `LIMIT … OFFSET …`. Якщо запит, можливо, доведеться переносити, тримайтеся довгої форми.
3. **Ті самі застереження, що у Вправі 2** — `OFFSET 1000000` усе одно сканує і відкидає мільйон рядків; для глибоких сторінок використовуйте keyset-пагінацію.

---

## Швидкий довідник — що означає «порядок написання» на практиці

1. Почніть із форми відповіді: які стовпці потрібні? → це список **`SELECT`**.
2. Визначте базову таблицю → **`FROM`**.
3. Перелічіть FK, по яких треба пройти → **`JOIN`**-клаузи зверху вниз.
4. Фільтр за властивостями **рядка** → **`WHERE`**.
5. Якщо ви підсумовуєте (`COUNT`, `SUM`, `AVG`, …) → **`GROUP BY`** перелічує всі не-агрегати з `SELECT`.
6. Фільтр за властивостями **групи** (`HAVING COUNT(*) >= 5`) → **`HAVING`**.
7. Сортування → **`ORDER BY col [DESC] [, …]`**.
8. Обмеження результату → **`LIMIT n`**, за потреби з **`OFFSET m`** для пагінації.

Порядок виконання (`FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT`) пояснює всі сюрпризи типу «чому цей аліас не працює в `WHERE`?».

---

## Діагностика: моя пагінація поводиться дивно

| Симптом | Імовірне виправлення |
|---|---|
| На наступній сторінці з'являються дублі | Додайте стабільний тайбрейкер (`id`) у `ORDER BY`. |
| Сторінка 2 порожня, хоч сторінка 1 була повна | `OFFSET` перевищує загальну кількість; спершу перевірте `COUNT(*)`. |
| `HAVING` каже «Unknown column» | Агрегати — у формі `COUNT(*) >= n`; не-агрегатні предикати в `WHERE`. |
| `WHERE alias = …` помилка | Аліаси з `SELECT` не бачать `WHERE`. Повторіть вираз. |
| `OFFSET 1000000` повільний | Переходьте на keyset-пагінацію (`WHERE id > last_seen_id`). |

Запустити **усі** приклади одним проходом: `mysql -t -u root car_service_db < 03_mysql/05_order_commands/car_service_order_examples.sql`.
