# Реляційна алгебра (Algebra Koda) — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/01_relational_algebra_Koda/algebra_Koda_car_service_db.md)

Ці вправи використовують **реальні імена таблиць і стовпців** з MySQL-дампу `01_database_mysql/car_service_db.sql.gz` (ім'я бази даних: `car_service_db`). Зіставте кожен алгебраїчний вираз із відповідним запитом у `car_service_algebra_examples.sql`.

## Позначення

| Символ | Значення |
|--------|----------|
| σ<sub>c</sub>(R) | Селекція: рядки R, для яких виконується умова c |
| π<sub>A</sub>(R) | Проєкція: зберегти лише атрибути (стовпці) зі списку A |
| R ⋈<sub>c</sub> S | Тета-з'єднання: об'єднати рядки за умовою c (натуральне з'єднання — окремий випадок, коли c — рівність за всіма спільними іменами) |
| R × S | Декартів добуток |
| R ∪ S, R − S, R ∩ S | Об'єднання, різниця, перетин (операнди мають бути **сумісні за об'єднанням**: однакова арність і сумісні типи) |
| ρ<sub>R(a₁→b₁,…)</sub>(S) | Перейменування (відношення та/або атрибутів) |

**Розширення (відповідність до SQL):** групування та агрегати (COUNT, SUM, …) у SQL виражаються через `GROUP BY`; «книжкова» реляційна алгебра часто розширюється **узагальненою проєкцією** або **агрегацією**; тут ми позначаємо це як **розширена RA → SQL**.

## Підмножина схеми (з дампу)

- **customers** (`id`, `first_name`, `last_name`, `phone`, `email`)
- **vehicles** (`id`, `customer_id`, `vin`, `plate`, `car`, `car_brands_id`) — FK `car_brands_id` → **car_brands**(`id`)
- **car_brands** (`id`, `name`)
- **work_orders** (`id`, `vehicle_id`, `mechanic_id`, `status`, `total_cost`)
- **employees** (`id`, `first_name`, `last_name`, `role_id`)
- **appointments** (`id`, `vehicle_id`, `scheduled_at`, `status`)
- **order_jobs** (`id`, `work_order_id`, `job_type_id`, `price`)
- **job_types** (`id`, `name`, `standard_hours`)
- **parts** (`id`, `sku`, `name`, `brand`)
- **inventory** (`id`, `part_id`, `warehouse_id`, `quantity`)
- **warehouses** (`id`, `name`, `location`)
- **blacklist** (`id`, `customer_id`, `reason`)
- **loyalty_cards** (`id`, `customer_id`, `points`)
- **feedback** (`id`, `customer_id`, `rating`, `comment`)
- **marketing_consents** (`id`, `customer_id`, `email_ok`)

Приклади значень **work_orders.status** у даних: `new`, `in_progress`, `waiting_parts`, `completed`, `cancelled`.
Приклади значень **appointments.status**: `planned`, `confirmed`, `done`, `missed`.

---

## Вправа 1 — Селекція

**Завдання:** усі робочі замовлення зі статусом `completed`.

**Алгебра:**
σ<sub>status = 'completed'</sub>(Work_orders)

**Ідея SQL:** фільтрувати `work_orders` за `status`.

---

## Вправа 2 — Проєкція

**Завдання:** перелічити SKU та бренд кожної деталі (більше нічого).

**Алгебра:**
π<sub>sku, brand</sub>(Parts)

---

## Вправа 3 — Селекція, потім проєкція

**Завдання:** email-адреси клієнтів, у яких записано номер телефону (`phone` не NULL).

**Алгебра:**
π<sub>email</sub>(σ<sub>phone IS NOT NULL</sub>(Customers))

---

## Вправа 4 — Тета-з'єднання (двох відношень)

**Завдання:** для кожного робочого замовлення показати номерний знак авто та підсумкову суму замовлення, але лише за умови `total_cost > 1000`.

**Алгебра (тета-з'єднання за ключем авто):**
π<sub>wo.id, v.plate, wo.total_cost</sub>
 σ<sub>wo.total_cost > 1000</sub>( ρ<sub>wo</sub>(Work_orders) ⋈<sub>wo.vehicle_id = v.id</sub> ρ<sub>v</sub>(Vehicles) )

(ρ перейменовує для усунення неоднозначності `id`; у SQL — аліаси `wo` та `v`.)

---

## Вправа 5 — Ланцюг з'єднань (трьох відношень)

**Завдання:** для кожного `id` робочого замовлення показати ім'я та прізвище клієнта (vehicle пов'язує клієнта з замовленням).

**Алгебра:**
π<sub>wo.id, c.first_name, c.last_name</sub>(
 Work_orders ⋈<sub>wo.vehicle_id = v.id</sub> Vehicles ⋈<sub>v.customer_id = c.id</sub> Customers
)
(із аліасами `wo`, `v`, `c` у SQL).

---

## Вправа 6 — Об'єднання (сумісних за об'єднанням проєкцій)

**Завдання:** усі унікальні значення `customer_id`, що з'являються або у чорному списку, **або** на лояльнісній картці зі строго додатними балами.

**Алгебра:**
π<sub>customer_id</sub>(Blacklist) ∪ π<sub>customer_id</sub>(σ<sub>points > 0</sub>(Loyalty_cards))

---

## Вправа 7 — Різниця множин

**Завдання:** клієнти, які мають принаймні одне авто (з'являються як `vehicles.customer_id`) і яких **немає** в чорному списку.

**Алгебра:**
π<sub>customer_id</sub>(Vehicles) − π<sub>customer_id</sub>(Blacklist)

Використовуйте проєкцію **з усуненням дублікатів** (у SQL — `SELECT DISTINCT`).

---

## Вправа 8 — Перетин

**Завдання:** клієнти, які є **одночасно** в `feedback` і в `marketing_consents` (однаковий `customer_id` в обох таблицях).

**Алгебра:**
π<sub>customer_id</sub>(Feedback) ∩ π<sub>customer_id</sub>(Marketing_consents)

---

## Вправа 9 — Перейменування (для читабельності)

**Завдання:** те саме відношення `Customers`, але потрібні лише атрибути `id` та `email`, причому `id` перейменовано на `cust_id`.

**Алгебра:**
ρ<sub>CustLite(cust_id → id, email → email)</sub>( π<sub>id, email</sub>(Customers) )
(Точна нотація перейменування різниться між підручниками; у SQL: `id AS cust_id`.)

---

## Вправа 10 — З'єднання + агрегація (розширена RA → SQL)

**Завдання:** скільки робочих замовлень припадає на кожного механіка (`work_orders.mechanic_id`)?

**Розширення:**
γ<sub>mechanic_id; COUNT(*) → wo_count</sub>(Work_orders)
(γ — групування / агрегація; у SQL: `GROUP BY mechanic_id`.)

---

## Вправа 11 — Багато-до-багатьох через міст

**Завдання:** перелічити **ім'я** типу робіт і **ціну** для кожної позиції на робочому замовленні `id = 1` (використайте `order_jobs` і `job_types`).

**Алгебра:**
π<sub>jt.name, oj.price</sub>(
 σ<sub>oj.work_order_id = 1</sub>( ρ<sub>oj</sub>(Order_jobs) ⋈<sub>oj.job_type_id = jt.id</sub> ρ<sub>jt</sub>(Job_types) )
)

---

## Вправа 12 — Склад, з'єднаний зі складами та деталями

**Завдання:** для рядків із `quantity < 5` показати ім'я складу, `sku` деталі та `quantity`.

**Алгебра:**
π<sub>w.name, p.sku, inv.quantity</sub>(
 σ<sub>inv.quantity < 5</sub>( Inventory ⋈ Parts ⋈ Warehouses за ключами )
)
(З'єднайте `inventory.part_id = parts.id` і `inventory.warehouse_id = warehouses.id`.)

---

## Вправа 13 — Шаблон існування / напівз'єднання

**Завдання:** клієнти, які мають принаймні одне записування на прийом зі статусом `confirmed` (вивести унікальні id та ім'я клієнта).

**Алгебра (стиль напівз'єднання):**
π<sub>c.id, c.first_name, c.last_name</sub>(
 Customers ⋉ ( Vehicles ⋈ Appointments where appointments.status = 'confirmed' )
)
(«⋉» — напівз'єднання; у SQL це зазвичай `EXISTS` або `INNER JOIN` з `DISTINCT`.)

---

## Вправа 14 — Декартів добуток (з невеликим обмеженням)

**Завдання:** пари `(employee.id, role.id)` **лише там, де** `employees.role_id = roles.id` — тобто покажіть, що θ-з'єднання — це насправді σ( R × S ).

**Алгебра:**
σ<sub>e.role_id = r.id</sub>( Employees × ρ<sub>r</sub>(Roles) )

---

## Вправа 15 — Пари еквівалентів (само-з'єднання на `parts`)

**Завдання:** з таблиці `equivalents` (`part_id_1`, `part_id_2`) перелічити SKU для обох сторін кожної пари.

**Алгебра:**
π<sub>p1.sku, p2.sku</sub>(
 Equivalents ⋈<sub>part_id_1 = p1.id</sub> ρ<sub>p1</sub>(Parts) ⋈<sub>part_id_2 = p2.id</sub> ρ<sub>p2</sub>(Parts)
)

---

### Як виконати SQL

1. Завантажте дамп у MySQL, напр. `mysql ... < car_service_db.sql` після `gunzip`.
2. `USE car_service_db;`
3. Виконайте запити з `car_service_algebra_examples.sql`.

Якщо запит повертає порожню множину на вашій машині, послабте предикати (наприклад, змініть пороги або зніміть фільтри) — **структура** відповідності алгебра ↔ SQL залишиться незмінною.
