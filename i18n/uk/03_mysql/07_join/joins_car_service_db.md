# JOIN-и — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/07_join/joins_car_service_db.md)

Ці вправи проходять **сімейство джоїнів**, з якими ви працюєте щодня: `INNER`, `LEFT`, ланцюжки з кількох таблиць, `RIGHT`, `CROSS`, міст / self-join, джоїни до похідних таблиць і обхідний шлях для відсутнього в MySQL `FULL OUTER`. Виконуються на справжній базі з **`01_database_mysql/car_service_db.sql.gz`** (ім'я бази: **`car_service_db`**).

Готові запити лежать у файлі-компаньйоні: [`07_join/car_service_join_examples.sql`](../../../../03_mysql/07_join/car_service_join_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/07_join/car_service_join_examples.sql
```

**Продуктивність:** усі вправи використовують **`WHERE id BETWEEN …`** і **`LIMIT`**, щоб великі таблиці лишалися керованими на занятті.

---

## Шаблон вправи (повторюється у кожному розділі нижче)

| Секція | Що вона дає |
|---|---|
| **Контекст** | Навіщо реальній СТО цей запит (1-2 речення). |
| **Чого ви навчитеся** | Яку форму джоїна тренує саме ця вправа. |
| **Задіяні таблиці** | Лише ті колонки, які насправді потрібні. |
| **Завдання** | Чіткі вимоги (фільтр, сортування, ліміт). |
| **Очікуваний результат** | Реальні рядки з дампу (скопійовані з живого запуску). |
| **Підказка** | Один натяк на правильну форму джоїна. |
| **Розв'язання** | Робочий SQL, який можна вставити в `mysql`. |
| **Покрокове пояснення** | Що робить кожна секція і які типові помилки. |

---

## Карта форм джоїнів (легше → складніше)

| Рівень | Тема |
|--------|------|
| **Легко** | `INNER JOIN` двох таблиць; ланцюжок із трьох таблиць за зовнішніми ключами. |
| **Легко** | `LEFT JOIN`: лишаємо всі рядки лівої таблиці; права може бути `NULL`. |
| **Легко** | `INNER JOIN` із довідником (`employees` ↔ `roles`). |
| **Складно** | Semi-join через `EXISTS` (шаблон «чи є у них взагалі?»). |
| **Складно** | Кілька `LEFT JOIN` із прийомом «перший id» для одного рядка на батька. |
| **Складно** | Місток + self-join (`equivalents` зджойнений із `parts` двічі). |
| **Складно** | Джоїн до **похідної** таблиці (`FROM (SELECT … GROUP BY …) AS t`). |
| **Складно** | `FULL OUTER` **шаблон** у MySQL: `LEFT JOIN … UNION ALL … LEFT JOIN … WHERE … IS NULL`. |
| **Додатково** | `RIGHT JOIN` (дзеркало `LEFT JOIN`). |
| **Додатково** | `CROSS JOIN` на **дуже малих** зрізах для каталожної сітки. |
| **Додатково** | Багато джоїнів в одному запиті (`work_order → vehicle → customer → brand → order_jobs → job_types`). |

---

## Точки дотику зі схемою

- **`vehicles.brand_id`** → **`car_brands.id`**
- **`work_orders.vehicle_id`** → **`vehicles.id`**
- **`vehicles.customer_id`** → **`customers.id`**
- **`feedback.customer_id`** → **`customers.id`**
- **`employees.role_id`** → **`roles.id`**
- **`equivalents.part_id_1` / `part_id_2`** → **`parts.id`**
- **`part_prices.part_id`** → **`parts.id`**
- **`inventory.warehouse_id`** → **`warehouses.id`**
- **`order_jobs.work_order_id`** → **`work_orders.id`**, **`order_jobs.job_type_id`** → **`job_types.id`**
- **`fuel_types`** — маленький довідник (`id`, `name`) для безпечних демо `CROSS JOIN`.

---

## Вправа E1 — `INNER JOIN`: авто + назва бренда

### Контекст

Форма прийому має поруч з кожним номерним знаком показувати назву бренда, але в `vehicles` зберігається лише `brand_id`. Джоїнимося з `car_brands`, щоб дістати читабельну назву.

### Чого ви навчитеся

- Найпростіший двотабличний `INNER JOIN` за зовнішнім ключем.
- Псевдоніми (`v`, `b`) для зручного запису.
- Чому `INNER` відкидає рядки без відповідності у брендах.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `vehicles` | `id`, `plate`, `car`, `brand_id` |
| `car_brands` | `id`, `name` |

### Завдання

Повернути `vehicle_id`, `plate`, `car`, `brand_name` для `vehicles.id BETWEEN 1 AND 200`. Ліміт 30.

### Очікуваний результат (реальні рядки з дампу)

```text
+------------+----------+--------+------------+
| vehicle_id | plate    | car    | brand_name |
+------------+----------+--------+------------+
|          1 | AA0001BB | Car_1  | Brand_001  |
|          2 | AA0002BB | Car_2  | Brand_002  |
|          3 | AA0003BB | Car_3  | Brand_003  |
|          4 | AA0004BB | Car_4  | Brand_004  |
|          5 | AA0005BB | Car_5  | Brand_005  |
| ...        |          |        |            |
|         30 | AA0030BB | Car_30 | Brand_030  |
+------------+----------+--------+------------+
```

### Підказка

`INNER JOIN car_brands AS b ON b.id = v.brand_id`.

### Розв'язання

```sql
SELECT v.id AS vehicle_id,
       v.plate,
       v.car,
       b.name AS brand_name
FROM vehicles AS v
INNER JOIN car_brands AS b ON b.id = v.brand_id
WHERE v.id BETWEEN 1 AND 200
LIMIT 30;
```

### Покрокове пояснення

1. **`INNER JOIN`** залишає рядок, лише якщо предикат `ON` істинний з **обох** боків. Авто з `brand_id`, що вказує на відсутній бренд, у результат не потрапить — для збереження лівої частини використовуйте `LEFT JOIN`.
2. **`ON b.id = v.brand_id`** — це збіг за зовнішнім ключем. `USING (brand_id)` дав би коротший запис, якби колонки називалися однаково з обох боків.
3. **Псевдоніми** `v` і `b` роблять запит компактним. Без них довелося б писати `vehicles.id`, `vehicles.plate`, `car_brands.name`.

---

## Вправа E2 — `INNER JOIN`: замовлення + номерний знак

### Контекст

Сторінка механіка для активного замовлення повинна показувати **номерний знак** авто — без нього на бокса не зрозуміють, який автомобіль обслуговують. У `work_orders` зберігається лише `vehicle_id`; джоїнимо `vehicles` за номером.

### Чого ви навчитеся

- Джоїн транзакційної таблиці (`work_orders`) до її «майстер»-таблиці (`vehicles`).
- Зчитування колонок з обох сторін джоїна.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `status`, `total_cost` |
| `vehicles` | `id`, `plate` |

### Завдання

Повернути `work_order_id`, `status`, `total_cost`, `plate`, `vehicle_id` для `work_orders.id BETWEEN 1 AND 500`. Ліміт 25.

### Очікуваний результат (реальні рядки з дампу)

```text
+---------------+---------------+------------+----------+------------+
| work_order_id | status        | total_cost | plate    | vehicle_id |
+---------------+---------------+------------+----------+------------+
|             1 | new           |     500.10 | AA0001BB |          1 |
|             2 | in_progress   |     500.20 | AA0002BB |          2 |
|             3 | waiting_parts |     500.30 | AA0003BB |          3 |
|             4 | completed     |     500.40 | AA0004BB |          4 |
|             5 | cancelled     |     500.50 | AA0005BB |          5 |
| ...           |               |            |          |            |
|            25 | cancelled     |     502.50 | AA0025BB |         25 |
+---------------+---------------+------------+----------+------------+
```

### Підказка

`ON v.id = wo.vehicle_id`.

### Розв'язання

```sql
SELECT wo.id AS work_order_id,
       wo.status,
       wo.total_cost,
       v.plate,
       v.id AS vehicle_id
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
WHERE wo.id BETWEEN 1 AND 500
LIMIT 25;
```

### Покрокове пояснення

1. **`wo.vehicle_id`** — це зовнішній ключ; **`v.id`** — первинний. Стрілка завжди йде від дитини до батька.
2. **Порядок таблиць у `FROM` не змінює семантику `INNER JOIN`:** `vehicles INNER JOIN work_orders ON v.id = wo.vehicle_id` дасть той самий результат.
3. **Без `WHERE wo.id BETWEEN …`** MySQL прокрутив би всі 100 000 рядків — повільно на навчальних машинах.

---

## Вправа E3 — Триланковий ланцюжок: work_order → vehicle → customer

### Контекст

Касир друкує шапку чеку, де мають бути **номер замовлення**, **ім'я клієнта** та **номерний знак**. Три таблиці, два зовнішні ключі, один запит.

### Чого ви навчитеся

- Зв'язку двох `INNER JOIN` у одному запиті.
- Читати дерево залежностей: `work_order` → `vehicle` → `customer`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `total_cost` |
| `vehicles` | `id`, `customer_id`, `plate` |
| `customers` | `id`, `first_name`, `last_name` |

### Завдання

Повернути `work_order_id`, `total_cost`, `plate`, `customer_id`, `first_name`, `last_name` для `wo.id BETWEEN 1 AND 300`. Ліміт 25.

### Очікуваний результат (реальні рядки з дампу)

```text
+---------------+------------+----------+-------------+------------+------------+
| work_order_id | total_cost | plate    | customer_id | first_name | last_name  |
+---------------+------------+----------+-------------+------------+------------+
|             1 |     500.10 | AA0001BB |           1 | Name_1     | Surname_1  |
|             2 |     500.20 | AA0002BB |           2 | Name_2     | Surname_2  |
|             3 |     500.30 | AA0003BB |           3 | Name_3     | Surname_3  |
|             4 |     500.40 | AA0004BB |           4 | Name_4     | Surname_4  |
|             5 |     500.50 | AA0005BB |           5 | Name_5     | Surname_5  |
| ...           |            |          |             |            |            |
|            25 |     502.50 | AA0025BB |          25 | Name_25    | Surname_25 |
+---------------+------------+----------+-------------+------------+------------+
```

### Підказка

Два `INNER JOIN` поспіль: спершу до `vehicles`, потім до `customers`.

### Розв'язання

```sql
SELECT wo.id AS work_order_id,
       wo.total_cost,
       v.plate,
       c.id AS customer_id,
       c.first_name,
       c.last_name
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN customers AS c ON c.id = v.customer_id
WHERE wo.id BETWEEN 1 AND 300
LIMIT 25;
```

### Покрокове пояснення

1. **Кожен `ON` зв'язує наступну пару.** Якщо забути один, MySQL зробить декартів добуток — мільйони рядків.
2. **`INNER JOIN` викидає рядки без збігу** на будь-якому з кроків. Якщо `customer_id` авто `NULL`, увесь рядок з `work_order` зникне — для збереження беріть `LEFT JOIN`.
3. **Читайте ланцюжок як бізнес-фразу:** «це замовлення — для тієї машини, що належить тому клієнту».

---

## Вправа E4 — `LEFT JOIN`: клієнти + відгуки

### Контекст

Адмін-дашборд показує всіх клієнтів у діапазоні; якщо клієнт залишав відгуки — виводимо їх, але **ніколи не приховуємо** клієнтів без відгуків.

### Чого ви навчитеся

- Семантику `LEFT JOIN`: усі рядки лівої таблиці лишаються, права — `NULL`, якщо немає збігу.
- Чому `WHERE` по колонці правої таблиці непомітно перетворює `LEFT JOIN` на `INNER JOIN`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `customers` | `id`, `email` |
| `feedback` | `customer_id`, `rating`, `comment` |

### Завдання

Повернути `customer_id`, `email`, `rating`, `comment` для `customers.id BETWEEN 1 AND 80` із `LEFT JOIN feedback`. Ліміт 40.

### Очікуваний результат (реальні рядки з дампу)

```text
+-------------+------------------------+--------+----------------------+
| customer_id | email                  | rating | comment              |
+-------------+------------------------+--------+----------------------+
|           1 | customer1@example.com  |      1 | Feedback comment #1  |
|           2 | customer2@example.com  |      2 | Feedback comment #2  |
|           3 | customer3@example.com  |      3 | Feedback comment #3  |
|           4 | customer4@example.com  |      4 | Feedback comment #4  |
|           5 | customer5@example.com  |      5 | Feedback comment #5  |
| ...         |                        |        |                      |
|          40 | customer40@example.com |      5 | Feedback comment #40 |
+-------------+------------------------+--------+----------------------+
```

### Підказка

`LEFT JOIN feedback AS f ON f.customer_id = c.id` — без `WHERE` по `f.*`.

### Розв'язання

```sql
SELECT c.id AS customer_id,
       c.email,
       f.rating,
       f.comment
FROM customers AS c
LEFT JOIN feedback AS f ON f.customer_id = c.id
WHERE c.id BETWEEN 1 AND 80
LIMIT 40;
```

### Покрокове пояснення

1. **`LEFT JOIN`** зберігає кожен рядок лівої таблиці. Якщо клієнт не має відгуків, праві колонки повертаються як `NULL`.
2. **У цьому дампі у кожного клієнта є відгук**, тому вивід виглядає як для `INNER JOIN`. Щоб побачити різницю, переключіться на менш заповнену дочірню таблицю.
3. **Увага:** якщо написати `WHERE f.rating = 5`, ви відріжете і збіги, і `NULL`-рядки — ваш `LEFT JOIN` перетвориться на `INNER`. Перенесіть умову в `ON`, щоб зберегти ліві рядки.
4. **Кілька збігів** множать рядки: клієнт із трьома відгуками дасть три рядки в результаті.

---

## Вправа E5 — `INNER JOIN`: запчастина + роздрібна ціна

### Контекст

Прайс-лист повинен показати SKU, назву і поточну роздрібну ціну для кожної запчастини. Ціна зберігається в `part_prices` по ключу `part_id`.

### Чого ви навчитеся

- Джоїн майстра (`parts`) до one-to-one чи one-to-many «дитини» (`part_prices`).
- Вибирати колонки з обох таблиць.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `parts` | `id`, `sku`, `name` |
| `part_prices` | `part_id`, `retail_price` |

### Завдання

Повернути `part_id`, `sku`, `name`, `retail_price` для `parts.id BETWEEN 1 AND 500`. Ліміт 25.

### Очікуваний результат (реальні рядки з дампу)

```text
+---------+--------------+---------+--------------+
| part_id | sku          | name    | retail_price |
+---------+--------------+---------+--------------+
|       1 | SKU-00000001 | Part_1  |        50.14 |
|       2 | SKU-00000002 | Part_2  |        50.29 |
|       3 | SKU-00000003 | Part_3  |        50.43 |
|       4 | SKU-00000004 | Part_4  |        50.57 |
|       5 | SKU-00000005 | Part_5  |        50.71 |
| ...     |              |         |              |
|      25 | SKU-00000025 | Part_25 |        53.57 |
+---------+--------------+---------+--------------+
```

### Підказка

`ON pp.part_id = p.id`.

### Розв'язання

```sql
SELECT p.id AS part_id,
       p.sku,
       p.name,
       pp.retail_price
FROM parts AS p
INNER JOIN part_prices AS pp ON pp.part_id = p.id
WHERE p.id BETWEEN 1 AND 500
LIMIT 25;
```

### Покрокове пояснення

1. **One-to-many ризик:** якщо в `part_prices` є історія цін для запчастини, запит помножить рядки. Додайте `WHERE pp.is_current = 1` або `ORDER BY pp.valid_from DESC LIMIT 1` на запчастину, щоб лишити лише поточну.
2. **`INNER JOIN` відкидає запчастини без рядка-ціни.** Якщо SKU має лишитися (з `NULL`-ціною), беріть `LEFT JOIN`.

---

## Вправа E6 — `INNER JOIN`: працівники + назва посади

### Контекст

HR потрібен реєстр: ім'я кожного працівника й читабельна назва ролі (`'Mechanic'`, `'Cashier'`, …). Назва лежить у `roles`, ключ — `role_id`.

### Чого ви навчитеся

- Лукапу у невеликій довідковій таблиці.
- Як виглядає каталог ролей у дампі.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `employees` | `id`, `first_name`, `last_name`, `role_id` |
| `roles` | `id`, `title` |

### Завдання

Повернути `employee_id`, `first_name`, `last_name`, `role_title` для `employees.id BETWEEN 1 AND 150`. Ліміт 25.

### Очікуваний результат (реальні рядки з дампу)

```text
+-------------+------------+---------------+-----------------+
| employee_id | first_name | last_name     | role_title      |
+-------------+------------+---------------+-----------------+
|           1 | EmpName_1  | EmpSurname_1  | Mechanic        |
|           2 | EmpName_2  | EmpSurname_2  | Senior Mechanic |
|           3 | EmpName_3  | EmpSurname_3  | Electrician     |
|           4 | EmpName_4  | EmpSurname_4  | Painter         |
|           5 | EmpName_5  | EmpSurname_5  | Manager         |
| ...         |            |               |                 |
|          25 | EmpName_25 | EmpSurname_25 | Manager         |
+-------------+------------+---------------+-----------------+
```

### Підказка

Лукап у малу таблицю: `roles AS r ON r.id = e.role_id`.

### Розв'язання

```sql
SELECT e.id AS employee_id,
       e.first_name,
       e.last_name,
       r.title AS role_title
FROM employees AS e
INNER JOIN roles AS r ON r.id = e.role_id
WHERE e.id BETWEEN 1 AND 150
LIMIT 25;
```

### Покрокове пояснення

1. **`roles` крихітна.** MySQL прочитає її раз і використає кеш — джоїн до маленьких довідників майже безкоштовний.
2. **Зверніть увагу на цикл id-ролей 1..10** у seed-даних — `Mechanic`, `Senior Mechanic`, `Electrician`, `Painter`, `Manager`, `Cashier`, `Warehouse`, `HR`, `Administrator`, `Director`.

---

## Вправа H1 — Semi-join через `EXISTS` (клієнти, у яких **є** авто)

### Контекст

Маркетинг хоче список клієнтів з ранніх id (`1..5000`), у кого зареєстровано хоч одне авто. З `vehicles` нам не потрібні колонки — лише тест на існування.

### Чого ви навчитеся

- `EXISTS` як **semi-join** (рядки лівої таблиці при збігу праворуч, **без множення**).
- Чому часто `EXISTS` краще за `JOIN + DISTINCT`.
- (Коментар у скрипті називає це «anti-join» — насправді це позитивний semi-join; anti-join — це `NOT EXISTS`.)

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `customers` | `id`, `first_name`, `last_name` |
| `vehicles` | `customer_id` |

### Завдання

Повернути `id`, `first_name`, `last_name` клієнтів з `id BETWEEN 1 AND 5000`, у яких **є хоча б одне авто**. Ліміт 25.

### Очікуваний результат (реальні рядки з дампу)

```text
+----+------------+------------+
| id | first_name | last_name  |
+----+------------+------------+
|  1 | Name_1     | Surname_1  |
|  2 | Name_2     | Surname_2  |
|  3 | Name_3     | Surname_3  |
|  4 | Name_4     | Surname_4  |
|  5 | Name_5     | Surname_5  |
| ...|            |            |
| 25 | Name_25    | Surname_25 |
+----+------------+------------+
```

### Підказка

`WHERE EXISTS (SELECT 1 FROM vehicles WHERE customer_id = c.id)`.

### Розв'язання

```sql
SELECT c.id,
       c.first_name,
       c.last_name
FROM customers AS c
WHERE c.id BETWEEN 1 AND 5000
  AND EXISTS (
    SELECT 1 FROM vehicles AS v WHERE v.customer_id = c.id
  )
LIMIT 25;
```

### Покрокове пояснення

1. **`EXISTS` зупиняється** на першому збігу — набагато дешевше за `INNER JOIN`, якщо у клієнта багато авто, а нам потрібен сам факт.
2. **Без `DISTINCT`** — `EXISTS` не множить ліву таблицю. Порівняйте з `SELECT DISTINCT c.id FROM customers c INNER JOIN vehicles v ON v.customer_id = c.id`.
3. **Справжній anti-join** («клієнти **без** авто») — `NOT EXISTS` або `LEFT JOIN vehicles v ON … WHERE v.customer_id IS NULL`.

---

## Вправа H2 — Кілька `LEFT JOIN` із ключем «перший id»

### Контекст

Картка клієнта хоче **одне опційне авто** і **один опційний відгук** на клієнта. Наївний `LEFT JOIN customers JOIN vehicles JOIN feedback` помножить рядки. Виправлення: попередньо агрегуємо кожну «дочку» до мінімального id на клієнта, далі джоїнимо до справжнього рядка.

### Чого ви навчитеся

- Уникати «вибуху» рядків при джоїні батька до кількох one-to-many «дочок».
- Попередньо агрегувати в похідних таблицях, щоб обрати одного «представника» на батька.
- Безпечно зв'язати чотири `LEFT JOIN`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `customers` | `id`, `last_name` |
| `feedback` | `id`, `customer_id`, `rating` |
| `vehicles` | `id`, `customer_id`, `plate` |

### Завдання

Повернути `customer_id`, `last_name`, `rating`, `plate`, `vehicle_id` для `customers.id BETWEEN 1 AND 50` з одним рядком відгука (мінімальний `feedback.id`) та одним рядком авто (мінімальний `vehicle.id`). Ліміт 60.

### Очікуваний результат (реальні рядки з дампу)

```text
+-------------+------------+--------+----------+------------+
| customer_id | last_name  | rating | plate    | vehicle_id |
+-------------+------------+--------+----------+------------+
|           1 | Surname_1  |      1 | AA0001BB |          1 |
|           2 | Surname_2  |      2 | AA0002BB |          2 |
|           3 | Surname_3  |      3 | AA0003BB |          3 |
|           4 | Surname_4  |      4 | AA0004BB |          4 |
|           5 | Surname_5  |      5 | AA0005BB |          5 |
| ...         |            |        |          |            |
|          50 | Surname_50 |      5 | AA0050BB |         50 |
+-------------+------------+--------+----------+------------+
```

### Підказка

Дві похідні таблиці: одна для `MIN(feedback.id)`, друга для `MIN(vehicle.id)`. Далі `LEFT JOIN` до справжніх `feedback` і `vehicles` по цих мінімальних id.

### Розв'язання

```sql
SELECT c.id AS customer_id,
       c.last_name,
       f.rating,
       v.plate,
       v.id AS vehicle_id
FROM customers AS c
LEFT JOIN (
            SELECT customer_id,
                   MIN(id) AS first_feedback_id
            FROM feedback
            WHERE id BETWEEN 1 AND 300000
            GROUP BY customer_id
          ) AS fk ON fk.customer_id = c.id
LEFT JOIN feedback AS f ON f.id = fk.first_feedback_id
LEFT JOIN (
            SELECT customer_id,
                   MIN(id) AS first_vehicle_id
            FROM vehicles
            WHERE id BETWEEN 1 AND 20000
            GROUP BY customer_id
          ) AS vk ON vk.customer_id = c.id
LEFT JOIN vehicles AS v ON v.id = vk.first_vehicle_id
WHERE c.id BETWEEN 1 AND 50
LIMIT 60;
```

### Покрокове пояснення

1. **Сенс прийому** — `MIN(id)` на батька повертає одне число. Джоїн до справжньої «дочки» по цьому числу дає максимум один рядок.
2. **Два `LEFT JOIN` на «дочку»** — перший до агрегованого «ключа» (страхує: усі клієнти лишаються навіть без дочірніх рядків), другий повертає колонки самого рядка.
3. **Чому не `ORDER BY … LIMIT 1` на кожного батька?** Це вимагав би корельованого підзапита на кожен рядок — як правило, повільніше за агрегований джоїн.
4. **Зверніть увагу — один рядок на клієнта**, попри many-to-many зв'язки.

---

## Вправа H3 — Місток + self-join на `parts`

### Контекст

`equivalents` — це таблиця-місток, що пов'язує взаємозамінні SKU (тобто гальмівна колодка бренда A еквівалентна колодці бренда B). Щоб вивести звіт «SKU A ↔ SKU B», джоїнимо `parts` саму на себе **двічі**, по обидві сторони пари.

### Чого ви навчитеся

- Джоїн однієї таблиці до себе з двома псевдонімами.
- Як читається таблиця-місток many-to-many.
- Як обирати імена псевдонімів (`p1`, `p2`), щоб уникнути конфлікту колонок.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `equivalents` | `id`, `part_id_1`, `part_id_2` |
| `parts` | `id`, `sku`, `brand` |

### Завдання

Повернути `sku_a`, `sku_b`, `brand_a`, `brand_b` для `equivalents.id BETWEEN 1 AND 500`. Ліміт 25.

### Очікуваний результат (реальні рядки з дампу)

```text
+--------------+--------------+--------------+--------------+
| sku_a        | sku_b        | brand_a      | brand_b      |
+--------------+--------------+--------------+--------------+
| SKU-00000001 | SKU-00000002 | PartBrand_1  | PartBrand_2  |
| SKU-00000002 | SKU-00000003 | PartBrand_2  | PartBrand_3  |
| SKU-00000003 | SKU-00000004 | PartBrand_3  | PartBrand_4  |
| SKU-00000004 | SKU-00000005 | PartBrand_4  | PartBrand_5  |
| SKU-00000005 | SKU-00000006 | PartBrand_5  | PartBrand_6  |
| ...          |              |              |              |
| SKU-00000025 | SKU-00000026 | PartBrand_25 | PartBrand_26 |
+--------------+--------------+--------------+--------------+
```

### Підказка

`INNER JOIN parts AS p1 ON p1.id = e.part_id_1` та `INNER JOIN parts AS p2 ON p2.id = e.part_id_2`.

### Розв'язання

```sql
SELECT p1.sku   AS sku_a,
       p2.sku   AS sku_b,
       p1.brand AS brand_a,
       p2.brand AS brand_b
FROM equivalents AS e
INNER JOIN parts AS p1 ON p1.id = e.part_id_1
INNER JOIN parts AS p2 ON p2.id = e.part_id_2
WHERE e.id BETWEEN 1 AND 500
LIMIT 25;
```

### Покрокове пояснення

1. **Два псевдоніми `p1` і `p2`** вказують на ту саму фізичну таблицю, але дають різні колонки. MySQL ставиться до них як до незалежних.
2. **Кожна пара з'являється лише раз** у цьому дампі (немає симетричної пари `(B, A)` після `(A, B)`). Якщо хочете симетричних, або вставляйте обидва напрямки при записі, або `UNION`-те обидва порядки джоїна на читанні.
3. **Таблиці-містки** — стандартне моделювання many-to-many: два зовнішні ключі, без додаткових полів (або з невеликою метаінформацією: «ким підтверджено», «з якої дати» тощо).

---

## Вправа H4 — `INNER JOIN` до похідної таблиці

### Контекст

Продажам потрібен **топ клієнтів за розміром автопарку** — відсортувати клієнтів за кількістю авто. Попередньо агрегуємо в підзапиті, далі джоїнимо до `customers` для назв.

### Чого ви навчитеся

- Похідна таблиця, що повертає по рядку на групу.
- Джоїн похідної таблиці назад до майстра.
- Чому це канонічна заміна віконним функціям у старішому MySQL.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `customers` | `id`, `last_name` |
| `vehicles` | `customer_id` |

### Завдання

Побудувати похідну таблицю `vc(customer_id, n_vehicles)`, згрупувавши `vehicles` (`id BETWEEN 1 AND 15000`, `customer_id IS NOT NULL`) із `HAVING COUNT(*) >= 1`. Зджойнити `customers` (`id BETWEEN 1 AND 20000`). Відсортувати за `n_vehicles DESC, c.id`. Ліміт 20.

### Очікуваний результат (реальні рядки з дампу)

```text
+----+------------+------------+
| id | last_name  | n_vehicles |
+----+------------+------------+
|  1 | Surname_1  |          1 |
|  2 | Surname_2  |          1 |
|  3 | Surname_3  |          1 |
|  4 | Surname_4  |          1 |
|  5 | Surname_5  |          1 |
| ...|            |            |
| 20 | Surname_20 |          1 |
+----+------------+------------+
```

### Підказка

`FROM customers c INNER JOIN (SELECT customer_id, COUNT(*) … GROUP BY customer_id) AS vc ON vc.customer_id = c.id`.

### Розв'язання

```sql
SELECT c.id,
       c.last_name,
       vc.n_vehicles
FROM customers AS c
INNER JOIN (
             SELECT customer_id,
                    COUNT(*) AS n_vehicles
             FROM vehicles
             WHERE id BETWEEN 1 AND 15000
               AND customer_id IS NOT NULL
             GROUP BY customer_id
             HAVING COUNT(*) >= 1
           ) AS vc ON vc.customer_id = c.id
WHERE c.id BETWEEN 1 AND 20000
ORDER BY vc.n_vehicles DESC, c.id
LIMIT 20;
```

### Покрокове пояснення

1. **Похідна таблиця обчислюється першою**, далі сприймається як звичайна.
2. **`HAVING COUNT(*) >= 1`** надлишкова (у будь-якій групі ≥1 рядка), але показує форму — поставте `>= 2`, щоб лишити лише клієнтів з кількома авто.
3. **Двоключове `ORDER BY`** стабілізує порядок при однакових `n_vehicles`.
4. **Сучасна альтернатива:** `SELECT c.id, c.last_name, COUNT(v.id) OVER (PARTITION BY c.id) AS n_vehicles FROM customers c LEFT JOIN vehicles v ON …`. Обидва спрацюють; похідна таблиця переноситься на старіші движки.

---

## Вправа H5 — `FULL OUTER JOIN` шаблон (MySQL)

### Контекст

У MySQL немає ключового слова `FULL OUTER JOIN`. Щоб вивести **усі склади з будь-якими записами в inventory** **плюс** **усі рядки inventory без матчу зі складом у нашому зрізі**, виконуємо два запити і склеюємо `UNION ALL`.

### Чого ви навчитеся

- Розкладу повного зовнішнього джоїна на «ліво-лише ∪ право-лише».
- Поєднання різних форм через `UNION ALL` і колонку-дискримінатор.
- Чому права частина зазвичай порожня при коректних зовнішніх ключах.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `warehouses` | `id`, `name` |
| `inventory` | `id`, `warehouse_id` |

### Завдання

Дві частини через UNION:

1. Склади з `id BETWEEN 1 AND 30`, у яких **немає** жодного inventory-рядка в `inventory.id BETWEEN 1 AND 50000`. Мітка `'warehouse_without_inventory_in_slice'`.
2. Рядки inventory з `id BETWEEN 1 AND 5000`, чий `warehouse_id` **не входить** у `warehouses.id BETWEEN 1 AND 30`. Мітка `'inventory_row_outside_left_slice'`.

Ліміт 25.

### Очікуваний результат (реальні рядки з дампу)

```text
+---------+-----------+----------------------------------+
| side_id | label     | match_kind                       |
+---------+-----------+----------------------------------+
|      31 | inv_wh_31 | inventory_row_outside_left_slice |
|      32 | inv_wh_32 | inventory_row_outside_left_slice |
|      33 | inv_wh_33 | inventory_row_outside_left_slice |
|      34 | inv_wh_34 | inventory_row_outside_left_slice |
|      35 | inv_wh_35 | inventory_row_outside_left_slice |
| ...     |           |                                  |
|      55 | inv_wh_55 | inventory_row_outside_left_slice |
+---------+-----------+----------------------------------+
```

### Підказка

Частина A — `LEFT JOIN … WHERE … IS NULL`. Частина B — окремий запит з `NOT IN (left-slice ids)`. Склеюємо `UNION ALL`.

### Розв'язання

```sql
SELECT w.id   AS side_id,
       w.name AS label,
       'warehouse_without_inventory_in_slice' AS match_kind
FROM warehouses AS w
LEFT JOIN inventory AS inv
  ON inv.warehouse_id = w.id
 AND inv.id BETWEEN 1 AND 50000
WHERE w.id BETWEEN 1 AND 30
  AND inv.id IS NULL
UNION ALL
SELECT inv.id AS side_id,
       CAST(CONCAT('inv_wh_', inv.warehouse_id) AS CHAR(100)) AS label,
       'inventory_row_outside_left_slice' AS match_kind
FROM inventory AS inv
WHERE inv.id BETWEEN 1 AND 5000
  AND inv.warehouse_id NOT IN (
        SELECT w2.id FROM warehouses AS w2 WHERE w2.id BETWEEN 1 AND 30
      )
LIMIT 25;
```

### Покрокове пояснення

1. **Частина A: ліво-лише.** `LEFT JOIN inventory ON … WHERE inv.id IS NULL` — класичний шаблон anti-join: склади у зрізі без жодного inventory-рядка.
2. **Частина B: право-лише.** Inventory-рядки, чий `warehouse_id` не належить обраному лівому зрізу. При нормальних FK вони все ще пов'язані з якимось складом — просто поза зрізом.
3. **`UNION ALL` вимагає однакової кількості колонок і сумісних типів.** `CAST(...)` вирівнює `varchar` `name` із синтезованою міткою Частини B.
4. **Пастка `NOT IN` + `NULL`:** якщо `warehouses.id` міг би бути `NULL`, предикат `NOT IN` обернувся б на `NULL` для всіх. Додайте `WHERE w2.id IS NOT NULL` всередину для надійності.
5. **У цьому дампі** Частина A порожня (склади `1..30` усі мають inventory ≤50 000); на виході — лише Частина B.

---

## Вправа R1 — `RIGHT JOIN` (дзеркало `LEFT JOIN`)

### Контекст

Ті самі дані, що в E1, але прочитані «з боку авто» — корисно, коли природне формулювання звучить як «для кожного авто додай бренд, якщо є».

### Чого ви навчитеся

- `RIGHT JOIN` зберігає рядки **правої** таблиці.
- `RIGHT JOIN A ON …` ≡ `LEFT JOIN A` зі зміненим порядком таблиць.
- Чому більшість команд віддає перевагу `LEFT JOIN` для одноманітності.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `car_brands` | `id`, `name` |
| `vehicles` | `id`, `plate`, `brand_id` |

### Завдання

Повернути `brand_id`, `brand_name`, `vehicle_id`, `plate` для авто з `v.id BETWEEN 1 AND 40` через `car_brands RIGHT JOIN vehicles`. Ліміт 40.

### Очікуваний результат (реальні рядки з дампу)

```text
+----------+------------+------------+----------+
| brand_id | brand_name | vehicle_id | plate    |
+----------+------------+------------+----------+
|        1 | Brand_001  |          1 | AA0001BB |
|        2 | Brand_002  |          2 | AA0002BB |
|        3 | Brand_003  |          3 | AA0003BB |
|        4 | Brand_004  |          4 | AA0004BB |
|        5 | Brand_005  |          5 | AA0005BB |
| ...      |            |            |          |
|       40 | Brand_040  |         40 | AA0040BB |
+----------+------------+------------+----------+
```

### Підказка

`FROM car_brands b RIGHT JOIN vehicles v ON v.brand_id = b.id`.

### Розв'язання

```sql
SELECT b.id    AS brand_id,
       b.name  AS brand_name,
       v.id    AS vehicle_id,
       v.plate
FROM car_brands AS b
RIGHT JOIN vehicles AS v ON v.brand_id = b.id
WHERE v.id BETWEEN 1 AND 40
LIMIT 40;
```

### Покрокове пояснення

1. **`RIGHT JOIN`** зберігає кожен рядок `vehicles` (таблиця після `RIGHT JOIN`). Якщо `brand_id` авто не збігається з жодним брендом, колонки бренда стануть `NULL`.
2. **Еквівалентний перепис:** помняйте таблиці місцями: `FROM vehicles v LEFT JOIN car_brands b ON b.id = v.brand_id`. Той самий результат, набагато звичніше.
3. **`WHERE v.id BETWEEN …`** безпечне, бо ми фільтруємо по правій (збереженій) стороні. Фільтр по `b.*` перетворив би все на inner join — той самий «пастковий» механізм, що з `LEFT JOIN`.

---

## Вправа R2 — `CROSS JOIN` на крихітних зрізах

### Контекст

Маркетинг хоче маленьку матрицю «бренд × тип палива» для каталожних карток на сайті (наприклад, «Brand_001 Petrol», «Brand_001 Diesel»…). 3 бренди × 4 типи палива — дружня сітка з 12 рядків.

### Чого ви навчитеся

- `CROSS JOIN` — це **декартів добуток**: кожен лівий рядок з кожним правим.
- Чому обидва входи мають бути крихітними — джоїн 100k × 100k вибухне.
- Обгортати кожен бік у `SELECT … LIMIT`, щоб лишатися в безпеці.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `car_brands` | `id`, `name` |
| `fuel_types` | `id`, `name` |

### Завдання

`CROSS JOIN` перших 3 `car_brands` з першими 4 `fuel_types`. Повернути `brand_id`, `brand_name`, `fuel_type_id`, `fuel_name`.

### Очікуваний результат (реальні рядки з дампу)

```text
+----------+------------+--------------+-----------+
| brand_id | brand_name | fuel_type_id | fuel_name |
+----------+------------+--------------+-----------+
|        3 | Brand_003  |            1 | Petrol    |
|        2 | Brand_002  |            1 | Petrol    |
|        1 | Brand_001  |            1 | Petrol    |
|        3 | Brand_003  |            2 | Diesel    |
|        2 | Brand_002  |            2 | Diesel    |
|        1 | Brand_001  |            2 | Diesel    |
|        3 | Brand_003  |            3 | Hybrid    |
|        2 | Brand_002  |            3 | Hybrid    |
|        1 | Brand_001  |            3 | Hybrid    |
|        3 | Brand_003  |            4 | Electric  |
|        2 | Brand_002  |            4 | Electric  |
|        1 | Brand_001  |            4 | Electric  |
+----------+------------+--------------+-----------+
```

### Підказка

`CROSS JOIN` без `ON`. Обмежте обидва боки декількома рядками.

### Розв'язання

```sql
SELECT b.id   AS brand_id,
       b.name AS brand_name,
       ft.id  AS fuel_type_id,
       ft.name AS fuel_name
FROM (SELECT id, name FROM car_brands WHERE id BETWEEN 1 AND 3) AS b
CROSS JOIN (SELECT id, name FROM fuel_types WHERE id BETWEEN 1 AND 4) AS ft;
```

### Покрокове пояснення

1. **`CROSS JOIN` не має `ON`** — кожен лівий рядок зустрічається з кожним правим. Розмір виходу `left × right`.
2. **3 × 4 = 12 рядків** — нормально; **100 000 × 100 000 = 10 000 000 000 рядків** — крах сесії. Завжди обмежуйте.
3. **`INNER JOIN … ON 1=1`** — синонім `CROSS JOIN`; обирайте те, що зручніше.
4. **Порядок рядків** не детермінований — MySQL вирішує сам; у показаному виводі brand_id йде в спадному порядку. Додайте `ORDER BY brand_id, fuel_type_id` для стабільного вигляду.

---

## Вправа R3 — `FULL OUTER` через `LEFT JOIN` + `UNION ALL` (дві частини)

### Контекст

Той самий FULL OUTER, що й H5, але вже відфільтрований: правий бік — «рядки inventory, чий warehouse повністю відсутній». При коректних FK Частина B порожня — здоровий знак.

### Чого ви навчитеся

- Розклад на «зліва + право-лише» через `UNION ALL`.
- Дискримінаторна колонка (`part`), щоб бачити, з якого боку прийшов рядок.
- Що нормальна схема робить «право-лише» порожнім.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `warehouses` | `id`, `name` |
| `inventory` | `id`, `warehouse_id`, `quantity` |

### Завдання

Частина 1: усі склади з `id BETWEEN 1 AND 12`, `LEFT JOIN` до `inventory` (`inv.id BETWEEN 1 AND 5000`). Частина 2: inventory-рядки в тому ж зрізі **без** відповідного складу (буде порожньою при цілих FK). `UNION ALL`. Ліміт 40.

### Очікуваний результат (реальні рядки з дампу)

```text
+--------------+----------------+--------------+----------+-----------+
| warehouse_id | warehouse_name | inventory_id | quantity | part      |
+--------------+----------------+--------------+----------+-----------+
|            1 | Warehouse_001  |            1 |        2 | from_left |
|            1 | Warehouse_001  |          101 |      102 | from_left |
|            1 | Warehouse_001  |          201 |      202 | from_left |
|            1 | Warehouse_001  |          301 |       52 | from_left |
|            1 | Warehouse_001  |          401 |      152 | from_left |
| ...          |                |              |          |           |
|            1 | Warehouse_001  |         3901 |      152 | from_left |
+--------------+----------------+--------------+----------+-----------+
```

### Підказка

Літеральна мітка (`'from_left'`, `'right_only_no_warehouse_match'`) дозволяє розрізнити обидві половини.

### Розв'язання

```sql
SELECT w.id    AS warehouse_id,
       w.name  AS warehouse_name,
       inv.id  AS inventory_id,
       inv.quantity,
       'from_left' AS part
FROM warehouses AS w
LEFT JOIN inventory AS inv
  ON inv.warehouse_id = w.id
 AND inv.id BETWEEN 1 AND 5000
WHERE w.id BETWEEN 1 AND 12
UNION ALL
SELECT w.id,
       w.name,
       inv.id,
       inv.quantity,
       'right_only_no_warehouse_match'
FROM inventory AS inv
LEFT JOIN warehouses AS w ON w.id = inv.warehouse_id
WHERE inv.id BETWEEN 1 AND 5000
  AND w.id IS NULL
LIMIT 40;
```

### Покрокове пояснення

1. **`AND inv.id BETWEEN …` всередині `ON`** обмежує, які рядки inventory беруть участь. Якби умова стояла в `WHERE`, `LEFT JOIN` перетворився б на inner. У `ON` склади лишаються, навіть якщо матчу немає.
2. **Частина 2 повертає 0 рядків** у цьому дампі, бо кожен `warehouse_id` вказує на справжній склад — знак, що FK справний.
3. **`UNION ALL`** зберігає дублікати (дешевше). Використовуйте `UNION` (без `ALL`), лише коли треба дедуплікувати.
4. **Форма результату:** домінує Частина 1; колонка `part` каже, з якого боку рядок.

---

## Вправа MJ1 — Багато джоїнів в одному запиті

### Контекст

Великий «огляд тикета»: id замовлення, статус, сума, ім'я клієнта, номер, бренд плюс **перший рядок замовлення** і **його тип роботи**. Шість таблиць, один `SELECT`.

### Чого ви навчитеся

- Поєднання `INNER` і `LEFT` джоїнів у одному запиті.
- Коли вмонтовувати фільтр у `ON`, а коли в `WHERE`.
- Тримати глибокий запит читабельним за допомогою однакових псевдонімів.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `vehicle_id`, `status`, `total_cost` |
| `vehicles` | `id`, `customer_id`, `brand_id`, `plate` |
| `customers` | `id`, `first_name`, `last_name` |
| `car_brands` | `id`, `name` |
| `order_jobs` | `id`, `work_order_id`, `job_type_id`, `price` |
| `job_types` | `id`, `name` |

### Завдання

Для `wo.id BETWEEN 1 AND 150` повернути `work_order_id`, `status`, `total_cost`, `first_name`, `last_name`, `plate`, `brand_name`, `line_price`, `job_type_name`. `INNER JOIN` для обов'язкового ланцюжка (`vehicles`, `customers`, `car_brands`), `LEFT JOIN` для опційних (`order_jobs`, `job_types`). Ліміт 30.

### Очікуваний результат (реальні рядки з дампу)

```text
+---------------+---------------+------------+------------+------------+----------+------------+------------+---------------+
| work_order_id | status        | total_cost | first_name | last_name  | plate    | brand_name | line_price | job_type_name |
+---------------+---------------+------------+------------+------------+----------+------------+------------+---------------+
|             1 | new           |     500.10 | Name_1     | Surname_1  | AA0001BB | Brand_001  |     300.13 | JobType_0001  |
|             2 | in_progress   |     500.20 | Name_2     | Surname_2  | AA0002BB | Brand_002  |     300.25 | JobType_0002  |
|             3 | waiting_parts |     500.30 | Name_3     | Surname_3  | AA0003BB | Brand_003  |     300.38 | JobType_0003  |
|             4 | completed     |     500.40 | Name_4     | Surname_4  | AA0004BB | Brand_004  |     300.50 | JobType_0004  |
|             5 | cancelled     |     500.50 | Name_5     | Surname_5  | AA0005BB | Brand_005  |     300.63 | JobType_0005  |
| ...           |               |            |            |            |          |            |            |               |
|            30 | cancelled     |     503.00 | Name_30    | Surname_30 | AA0030BB | Brand_030  |     303.75 | JobType_0030  |
+---------------+---------------+------------+------------+------------+----------+------------+------------+---------------+
```

### Підказка

П'ять джоїнів. Три — `INNER` (обов'язковий хребет), два — `LEFT` (рядки замовлень можуть бути відсутні).

### Розв'язання

```sql
SELECT wo.id        AS work_order_id,
       wo.status,
       wo.total_cost,
       c.first_name,
       c.last_name,
       v.plate,
       b.name       AS brand_name,
       oj.price     AS line_price,
       jt.name      AS job_type_name
FROM work_orders AS wo
INNER JOIN vehicles   AS v  ON v.id  = wo.vehicle_id
INNER JOIN customers  AS c  ON c.id  = v.customer_id
INNER JOIN car_brands AS b  ON b.id  = v.brand_id
LEFT JOIN  order_jobs AS oj ON oj.work_order_id = wo.id
                           AND oj.id BETWEEN 1 AND 400000
LEFT JOIN  job_types  AS jt ON jt.id = oj.job_type_id
WHERE wo.id BETWEEN 1 AND 150
LIMIT 30;
```

### Покрокове пояснення

1. **`INNER JOIN` для обов'язкового хребта** (work order → vehicle → customer → brand). Без будь-якого з них рядок втрачає сенс.
2. **`LEFT JOIN order_jobs`** — замовлення без рядків деталей теж має з'явитися. Додатковий `AND oj.id BETWEEN …` всередині `ON`, а не `WHERE`, щоб незмачені замовлення вижили.
3. **`LEFT JOIN job_types`** — якщо `oj` відсутній, `oj.job_type_id` буде `NULL`, і джоїн до `job_types` додає ще `NULL`-рядок. Тому порядок важливий: `LEFT JOIN` після іншого `LEFT JOIN` каскадує.
4. **Множення рядків:** якщо у замовлення 3 рядки робіт, отримаєте 3 рядки у виводі. Щоб скоротити до одного, агрегуйте (`MIN(oj.price)`, `GROUP_CONCAT(jt.name)`) або беріть похідну таблицю — див. H2.

---

## Поради при «розпуханні», «зменшенні» чи дивних результатах джоїна

| Симптом | Імовірне виправлення |
|---|---|
| `INNER JOIN` повертає порожній результат | У `ON` зовнішній ключ містить `NULL`. Беріть `LEFT JOIN` або фільтруйте `IS NOT NULL`. |
| Кількість рядків вибухнула | Забутий `ON` — випадковий декартів добуток. Кожен `JOIN` повинен мати `ON`. |
| `LEFT JOIN` поводиться як `INNER` | Ви фільтруєте `WHERE rhs.col = …`. Перенесіть умову в `ON`. |
| `RIGHT JOIN` плутає | Поміняйте таблиці місцями і беріть `LEFT JOIN`. |
| `CROSS JOIN` повільний | Один або обидва входи завеликі. Загорніть у `(SELECT … LIMIT N)`. |
| `UNION ALL` скаржиться на типи | Привести колонки до однакового типу з обох боків (`CAST(x AS CHAR(100))`). |

Якщо хочеться прогнати **всі** приклади відразу: `mysql -t -u root car_service_db < 03_mysql/07_join/car_service_join_examples.sql`.
