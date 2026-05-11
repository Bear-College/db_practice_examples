# DDL (Data Definition Language) — тема `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/02_ddl/ddl_car_service_db.md)

Ці приклади використовують **ту саму предметну область**, що й MySQL-дамп `01_database_mysql/car_service_db.sql.gz` (СТО, постачальники, деталі, робочі замовлення). Виконувані скрипти:

- `car_service_ddl_examples.sql` — широкі DDL-операції (`CREATE`, `ALTER`, `RENAME`, `VIEW`, очищення)
- `car_service_relationships_examples.sql` — DDL, сфокусований на зв'язках (один-до-багатьох, багато-до-багатьох, само-посилання, дії FK)

Обидва скрипти створюють невелику пісочницю **`ddl_practice`**, щоб ви не змінювали і не конфліктували з таблицями `car_service_db`.

Зіставте кожну вправу нижче з відповідним блоком у `.sql`-файлі.

## Карта DDL-команд (MySQL 8 / 9)

| Інструкція | Роль |
|------------|------|
| `CREATE DATABASE` / `CREATE SCHEMA` | Визначити простір імен для об'єктів |
| `CREATE TABLE` | Визначити базове відношення: стовпці, ключі, обмеження, індекси |
| `ALTER TABLE` | Додати, видалити або змінити стовпці, ключі та обмеження |
| `CREATE INDEX` / `CREATE UNIQUE INDEX` | Додати вторинні шляхи доступу (часто оголошуються всередині `CREATE TABLE`) |
| `DROP TABLE` / `DROP DATABASE` | Видалити об'єкти (порядок важливий, коли є зовнішні ключі) |
| `RENAME TABLE` | Перейменувати одну або кілька таблиць |
| `CREATE VIEW` | Іменований збережений запит (у курсах часто групується з DDL) |

**Споріднене, але не суто DDL:** `TRUNCATE TABLE` (швидко видалити всі рядки; скинути auto-increment; потребує права `DROP`). `INSERT`/`UPDATE`/`DELETE` — це DML.

---

## Точки дотику зі схемою (з реального дампу)

Поняття з `car_service_db`, які закріплюють ці вправи:

- **Числові ключі:** `INT` з `AUTO_INCREMENT`, `PRIMARY KEY`
- **Текст:** `VARCHAR(n)`, опціонально `NOT NULL`
- **Гроші / суми:** `DECIMAL(p,s)` (напр., `DECIMAL(12,2)`, як у `work_orders.total_cost`)
- **Дати:** `DATE`, `DATETIME`, `TIMESTAMP`
- **Референтна цілісність:** `FOREIGN KEY` … `REFERENCES` … (`ON DELETE` / `ON UPDATE` опціонально)
- **Довідкові / каталогові таблиці:** напр. `suppliers`, `purchase_orders`, `parts`, `warehouses`

---

## Вправа 1 — Створити навчальну базу даних

**Завдання:** створити базу лише для DDL-лабораторій (пропустіть, якщо вже маєте).

**Ідея DDL:** `CREATE DATABASE …` / `CREATE SCHEMA …` (синоніми в MySQL).

---

## Вправа 2 — `CREATE TABLE` з первинним ключем і `AUTO_INCREMENT`

**Завдання:** створити таблицю `demo_suppliers`: сурогатний ключ `id`, `name`, `phone` — за зразком **`suppliers`** з дампу.

**Ідея DDL:** `INT NOT NULL AUTO_INCREMENT`, `PRIMARY KEY (id)`, розумні довжини `VARCHAR`.

---

## Вправа 3 — Дочірня таблиця з зовнішнім ключем

**Завдання:** створити `demo_purchase_orders` зі стовпцем `supplier_id`, що посилається на `demo_suppliers(id)`, плюс `order_date`.

**Ідея DDL:** `FOREIGN KEY (supplier_id) REFERENCES demo_suppliers(id)` — батьківська таблиця має існувати першою.

---

## Вправа 4 — Унікальний бізнес-ключ `UNIQUE`

**Завдання:** у новій таблиці `demo_parts` гарантувати унікальність `sku` (як у **`parts.sku`** з дампу).

**Ідея DDL:** `UNIQUE KEY uk_demo_parts_sku (sku)` або `UNIQUE` на рівні стовпця.

---

## Вправа 5 — `DEFAULT` і `NOT NULL`

**Завдання:** стовпці на кшталт `is_active` зі значенням за замовчуванням `1` і `created_at` зі значенням `CURRENT_TIMESTAMP`.

**Ідея DDL:** `DEFAULT`, `NOT NULL`, значення за замовчуванням `TIMESTAMP` / `DATETIME`.

---

## Вправа 6 — Обмеження `CHECK` (MySQL 8.0.16+)

**Завдання:** забезпечити, щоб `quantity` у таблиці позицій (на кшталт `order_jobs`) було строго додатним.

**Ідея DDL:** `CHECK (quantity > 0)` — MySQL дотримується `CHECK` починаючи з 8.0.16.

---

## Вправа 7 — Вторинний індекс для пошуку

**Завдання:** додати неунікальний індекс на `demo_purchase_orders(order_date)` для діапазонних сканувань (аналогічно звітності на **`purchase_orders.order_date`**).

**Ідея DDL:** `CREATE INDEX … ON … (…)` або `ALTER TABLE … ADD INDEX …`.

---

## Вправа 8 — `ALTER TABLE` — додати стовпець

**Завдання:** додати необов'язковий стовпець `notes` (`TEXT`) до `demo_suppliers` після того, як таблицю створено.

**Ідея DDL:** `ALTER TABLE … ADD COLUMN …`.

---

## Вправа 9 — `ALTER TABLE` — змінити тип або nullable

**Завдання:** розширити `phone` або посилити обмеження на NULL — попрактикуйте `MODIFY COLUMN` / `CHANGE COLUMN`.

**Ідея DDL:** `ALTER TABLE … MODIFY COLUMN …`.

---

## Вправа 10 — `ALTER TABLE` — видалити стовпець

**Завдання:** видалити стовпець, який більше не потрібен (виконуйте лише за умови, що обмеження це дозволяють).

**Ідея DDL:** `ALTER TABLE … DROP COLUMN …`.

---

## Вправа 11 — `RENAME TABLE`

**Завдання:** перейменувати демо-таблицю (напр., `demo_parts` → `demo_catalog_parts`) без копіювання даних.

**Ідея DDL:** `RENAME TABLE old TO new`.

---

## Вправа 12 — Порядок `DROP TABLE` і прибирання

**Завдання:** видаляти дочірні таблиці перед батьківськими або обережно використовуйте `SET foreign_key_checks` для повного очищення.

**Ідея DDL:** `DROP TABLE IF EXISTS child, parent` у безпечному порядку; опціонально `DROP DATABASE` для повного скидання.

---

## Вправа 13 — `CREATE VIEW` (іменоване визначення)

**Завдання:** визначити подання, яке з'єднує демо-постачальників із їхніми покупками (об'єкт схеми «лише для читання»).

**Ідея DDL:** `CREATE OR REPLACE VIEW … AS SELECT …`.

---

## Вправа 14 — `TRUNCATE` (необов'язкова вправа)

**Завдання:** очистити демо-таблицю, на яку **не вказують** FK (або після видалення дочірніх).

**Ідея DDL:** `TRUNCATE TABLE …` проти `DELETE` — різна семантика блокувань і скидання auto-increment.

---

## Лабораторія зі зв'язків (додатковий файл)

Використовуйте `car_service_relationships_examples.sql` для практики дизайну зв'язків:

- Батько/нащадок (`rel_customers` -> `rel_work_orders`)
- Само-посилання (`rel_technicians.manager_id` -> `rel_technicians.id`)
- Багато-до-багатьох через міст (`rel_work_orders` <-> `rel_parts` через `rel_order_parts`)
- Дії FK (`RESTRICT`, `SET NULL`, `CASCADE`) та складений PK у мості

Лабораторія містить мінімальні дані-засіви та перевірочний запит з'єднання.

---

### Як виконати SQL

1. Відкрийте клієнт MySQL.
2. Запустіть будь-який скрипт:
   - `SOURCE …/car_service_ddl_examples.sql` або `mysql … < car_service_ddl_examples.sql`
   - `SOURCE …/car_service_relationships_examples.sql` або `mysql … < car_service_relationships_examples.sql`
3. Перевірте: `USE ddl_practice; SHOW TABLES; SHOW CREATE TABLE …;`

Щоб порівняти з реальними назвами, завантажте `car_service_db` з gzip-дампу та виконайте `SHOW CREATE TABLE suppliers\G` поруч з `demo_suppliers`.
