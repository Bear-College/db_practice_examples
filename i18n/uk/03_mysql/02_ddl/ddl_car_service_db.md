# DDL (Data Definition Language) — тема `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/02_ddl/ddl_car_service_db.md)

Ці вправи тренують **формування схеми** через `CREATE`, `ALTER`, `RENAME`, `DROP`, `TRUNCATE` і `CREATE VIEW` у **безпечній пісочниці** `ddl_practice`. Предметна область відтворює `01_database_mysql/car_service_db.sql.gz` (`suppliers`, `purchase_orders`, `parts`), але демо-таблиці мають префікси `demo_*` / `rel_*`, тож реальний `car_service_db` під час практики **не змінюється**.

Лекцію супроводжують два скрипти:

- [`02_ddl/car_service_ddl_examples.sql`](../../../../03_mysql/02_ddl/car_service_ddl_examples.sql) — широкі DDL-операції (Вправи 1–14)
- [`02_ddl/car_service_relationships_examples.sql`](../../../../03_mysql/02_ddl/car_service_relationships_examples.sql) — DDL зі зв'язками (1:N, N:M, само-посилання, дії FK)

```bash
mysql -u root < 03_mysql/02_ddl/car_service_ddl_examples.sql
mysql -u root < 03_mysql/02_ddl/car_service_relationships_examples.sql
```

Обидва скрипти **ідемпотентні** — видаляють попередні демо-об'єкти перед створенням, тож їх можна перезапускати безліч разів.

---

## Карта DDL-команд (MySQL 8 / 9)

| Інструкція | Роль |
|---|---|
| `CREATE DATABASE` / `CREATE SCHEMA` | Визначити простір імен для об'єктів |
| `CREATE TABLE` | Визначити базове відношення: стовпці, ключі, обмеження, індекси |
| `ALTER TABLE` | Додати, видалити або змінити стовпці, ключі та обмеження |
| `CREATE INDEX` / `CREATE UNIQUE INDEX` | Додати вторинні шляхи доступу (часто оголошуються в `CREATE TABLE`) |
| `DROP TABLE` / `DROP DATABASE` | Видалити об'єкти (порядок важливий при FK) |
| `RENAME TABLE` | Перейменувати одну або кілька таблиць |
| `CREATE VIEW` | Іменований збережений запит (у курсах часто групують з DDL) |

**Споріднене, але не суто DDL:** `TRUNCATE TABLE` (швидке очищення; скидає auto-increment; потребує права `DROP`). `INSERT`/`UPDATE`/`DELETE` — це DML.

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

### Контекст

Викладач хоче, щоб у кожного студента був чистий, ізольований простір імен для DDL-лабораторій — щоб не зіткнутися з реальним `car_service_db` чи з експериментами іншого студента.

### Чого ви навчитеся

- Різницю (її немає в MySQL) між `CREATE DATABASE` і `CREATE SCHEMA`.
- Задавати `CHARACTER SET` і `COLLATE` на рівні бази, щоб таблиці успадковували параметри.
- Захист `IF NOT EXISTS` для ідемпотентних скриптів.

### Задіяні таблиці

| Ціль | Роль |
|---|---|
| (нова база) `ddl_practice` | Пісочниця для всіх інших DDL-вправ |

### Завдання

Створити базу `ddl_practice` з `utf8mb4` / `utf8mb4_0900_ai_ci`. Тихо пропустити, якщо вже існує.

### Очікуваний результат (з `SHOW DATABASES LIKE 'ddl_practice'`)

```text
+----------------------------+
| Database (ddl_practice)    |
+----------------------------+
| ddl_practice               |
+----------------------------+
```

### Підказка

`CREATE DATABASE IF NOT EXISTS …`, потім `USE …;`, щоб наступні стейтменти виконувалися в новій базі.

### Розв'язання

```sql
CREATE DATABASE IF NOT EXISTS ddl_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE ddl_practice;
```

### Покрокове пояснення

1. **`CREATE DATABASE` ≡ `CREATE SCHEMA`** у MySQL — оберіть одне і дотримуйтеся послідовно. У PostgreSQL це різні поняття; у MySQL — синоніми.
2. **`utf8mb4_0900_ai_ci`** — сучасний типовий вибір: повний UTF-8 (емоджі та більшість писемностей), accent-insensitive, case-insensitive порівняння.
3. **`IF NOT EXISTS`** не дає скрипту впасти на другому запуску — обов'язково, коли скрипт виконують повторно.
4. **`USE ddl_practice;`** змінює *поточну* схему сесії, тож подальші `CREATE TABLE` живуть у ній без повного імені.

---

## Вправа 2 — `CREATE TABLE` з первинним ключем і `AUTO_INCREMENT`

### Контекст

Перше, що треба будь-якій системі управління СТО, — таблиця **постачальників**. Це місце для оптовиків, які постачають запчастини. Шопу потрібен сурогатний цілочисельний id, який сам зростає, точнісінько як `suppliers.id` у production-дампі.

### Чого ви навчитеся

- Визначати сурогатний `INT AUTO_INCREMENT PRIMARY KEY`.
- Підбирати розумні довжини `VARCHAR`.
- Шаблон аудит-колонки `TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP`.

### Задіяні таблиці

| Ціль | Колонки |
|---|---|
| `demo_suppliers` (нова) | `id`, `name`, `phone`, `created_at` |

### Завдання

Створити `demo_suppliers` з авто-інкрементним первинним ключем, обов'язковим `name`, опціональним `phone` і `created_at` зі значенням за замовчуванням «зараз».

### Очікуваний результат (з `SHOW CREATE TABLE demo_suppliers` після того, як Вправа 7 додасть індекс)

```text
CREATE TABLE `demo_suppliers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `phone` varchar(32) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_demo_supplier_name` (`name`(20))
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

### Підказка

`INT NOT NULL AUTO_INCREMENT`, `PRIMARY KEY (id)`, аудит-timestamp у кінці.

### Розв'язання

```sql
CREATE TABLE demo_suppliers (
  id            INT NOT NULL AUTO_INCREMENT,
  name          VARCHAR(100) NOT NULL,
  phone         VARCHAR(20) DEFAULT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Покрокове пояснення

1. **`AUTO_INCREMENT` — атрибут стовпця**, але стовпець мусить бути проіндексованим. `PRIMARY KEY` дає цей індекс автоматично.
2. **`VARCHAR(100)`** — щедро для назв постачальників, але економніше за `TEXT`: MySQL зберігає лише фактично записані байти, тож верхня межа — це обмеження, а не фіксований розмір.
3. **`DEFAULT NULL`** явно показує, що стовпець опціональний; разом із відсутністю `NOT NULL` документує намір.
4. **`ENGINE=InnoDB`** дає транзакції та зовнішні ключі — єдиний правильний вибір для production.

---

## Вправа 3 — Дочірня таблиця з зовнішнім ключем

### Контекст

Постачальники не живуть у вакуумі: кожен оптовик надсилає нам **замовлення на закупівлю**. Нова `demo_purchase_orders` має посилатися на `demo_suppliers`, щоб виконувалося правило «у кожного PO є реальний постачальник».

### Чого ви навчитеся

- Декларувати `FOREIGN KEY` під час `CREATE TABLE`.
- Обирати дії `ON UPDATE` / `ON DELETE`.
- Чому батьківську таблицю створюють першою.

### Задіяні таблиці

| Ціль | Колонки |
|---|---|
| `demo_suppliers` (батько, з Вправи 2) | `id` |
| `demo_purchase_orders` (новий дочірній) | `id`, `supplier_id`, `order_date` |

### Завдання

Створити `demo_purchase_orders`, що посилається на `demo_suppliers(id)`. Каскадувати оновлення FK, але **заборонити** видалення — постачальник не може зникнути, поки на нього посилаються замовлення.

### Очікуваний результат (з `SHOW CREATE TABLE demo_purchase_orders`)

```text
CREATE TABLE `demo_purchase_orders` (
  `id` int NOT NULL AUTO_INCREMENT,
  `supplier_id` int NOT NULL,
  `order_date` date NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_demo_po_supplier` (`supplier_id`),
  KEY `idx_demo_po_order_date` (`order_date`),
  CONSTRAINT `fk_demo_po_supplier` FOREIGN KEY (`supplier_id`)
    REFERENCES `demo_suppliers` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB ...
```

### Підказка

`CONSTRAINT name FOREIGN KEY (col) REFERENCES parent(col) ON UPDATE … ON DELETE …`.

### Розв'язання

```sql
CREATE TABLE demo_purchase_orders (
  id            INT NOT NULL AUTO_INCREMENT,
  supplier_id   INT NOT NULL,
  order_date    DATE NOT NULL,
  PRIMARY KEY (id),
  KEY idx_demo_po_supplier (supplier_id),
  KEY idx_demo_po_order_date (order_date),
  CONSTRAINT fk_demo_po_supplier
    FOREIGN KEY (supplier_id) REFERENCES demo_suppliers (id)
      ON UPDATE CASCADE
      ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Покрокове пояснення

1. **Батьківська таблиця має існувати першою.** Якщо `demo_suppliers` ще немає, `CONSTRAINT` падає з `errno: 150`.
2. **`KEY idx_demo_po_supplier (supplier_id)`** оголошено явно, хоч InnoDB і сам би його створив — кожен FK-стовпець мусить мати індекс. Іменування полегшує діагностику.
3. **`ON UPDATE CASCADE`**: якщо id постачальника зміниться, дочірні рядки підуть за ним. **`ON DELETE RESTRICT`** забороняє видалення, поки є нащадки — безпечніший типовий вибір.
4. **Іменуйте обмеження.** Без `CONSTRAINT fk_…` MySQL згенерує `demo_purchase_orders_ibfk_1`, що нічого не каже в повідомленнях про помилку.

---

## Вправа 4 — Унікальний бізнес-ключ `UNIQUE`

### Контекст

Каталог `parts` використовує **SKU** як бізнес-ідентифікатор — вони на наклейках, накладних, замовленнях. Два товари не можуть мати однаковий SKU.

### Чого ви навчитеся

- Різницю між сурогатним `PRIMARY KEY` та бізнес-ключем `UNIQUE`.
- Два синтакси: `UNIQUE` на рівні стовпця і `UNIQUE KEY name (col)` на рівні таблиці.

### Задіяні таблиці

| Ціль | Колонки |
|---|---|
| `demo_parts` (нова) | `id`, `sku`, `name`, `brand` |

### Завдання

Створити `demo_parts`. Зробити `sku` унікальним і назвати обмеження (`uk_demo_parts_sku`).

### Очікуваний результат (з `SHOW CREATE TABLE demo_catalog_parts` — та сама таблиця після перейменування у Вправі 11)

```text
CREATE TABLE `demo_catalog_parts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `sku` varchar(50) NOT NULL,
  `name` varchar(200) NOT NULL,
  `brand` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_demo_parts_sku` (`sku`)
) ENGINE=InnoDB ...
```

### Підказка

Або `sku VARCHAR(50) NOT NULL UNIQUE`, або на рівні таблиці `UNIQUE KEY uk_demo_parts_sku (sku)`.

### Розв'язання

```sql
CREATE TABLE demo_parts (
  id            INT NOT NULL AUTO_INCREMENT,
  sku           VARCHAR(50) NOT NULL,
  name          VARCHAR(200) NOT NULL,
  brand         VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_demo_parts_sku (sku)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Покрокове пояснення

1. **`PRIMARY KEY` ⊂ `UNIQUE`.** Кожен PK — унікальний; зворотне неправда (`UNIQUE`-стовпці можуть бути `NULL`, PK — ні).
2. **Форма на рівні таблиці зручніша, коли треба ім'я** — повідомлення «Duplicate entry 'X' for key 'uk_demo_parts_sku'» одразу веде до потрібного рядка схеми.
3. **`UNIQUE` авто-індексує**, тож пошук за `sku` — O(log n) без додаткового `CREATE INDEX`.

---

## Вправа 5 — `DEFAULT` і `NOT NULL`

### Контекст

Кожен рядок замовлення на закупівлю має **вставлятися з розумними значеннями за замовчуванням**: податковий прапорець ON, ціна 0, якщо не задано, аудит-timestamp проставляється сервером. Це спрощує код програми й оминає `NULL`-помилки.

### Чого ви навчитеся

- `DEFAULT` для булевих, числових, дат.
- `DEFAULT CURRENT_TIMESTAMP` для `DATETIME` / `TIMESTAMP`.
- Чому пара `NOT NULL` + `DEFAULT` безпечніша за nullable.

### Задіяні таблиці

| Ціль | Колонки |
|---|---|
| `demo_po_lines` (нова) | `id`, `po_id`, `part_id`, `quantity`, `unit_price`, `is_taxable`, `inserted_at` |

### Завдання

Створити `demo_po_lines`, пов'язану з `demo_purchase_orders` (батько) та `demo_parts` (каталог). `unit_price` за замовчуванням `0.00`, `is_taxable` — `1`, `inserted_at` — «зараз».

### Очікуваний результат (з `SHOW CREATE TABLE demo_po_lines`)

```text
CREATE TABLE `demo_po_lines` (
  `id` int NOT NULL AUTO_INCREMENT,
  `po_id` int NOT NULL,
  `part_id` int NOT NULL,
  `quantity` int NOT NULL,
  `unit_price` decimal(10,2) NOT NULL DEFAULT '0.00',
  `is_taxable` tinyint(1) NOT NULL DEFAULT '1',
  `inserted_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  ...
  CONSTRAINT `chk_demo_po_lines_price` CHECK ((`unit_price` >= 0)),
  CONSTRAINT `chk_demo_po_lines_qty` CHECK ((`quantity` > 0))
) ENGINE=InnoDB ...
```

### Підказка

`unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.00`, `inserted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`.

### Розв'язання

```sql
CREATE TABLE demo_po_lines (
  id            INT NOT NULL AUTO_INCREMENT,
  po_id         INT NOT NULL,
  part_id       INT NOT NULL,
  quantity      INT NOT NULL,
  unit_price    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  is_taxable    TINYINT(1) NOT NULL DEFAULT 1,
  inserted_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_demo_po_lines_po (po_id),
  KEY idx_demo_po_lines_part (part_id),
  CONSTRAINT fk_demo_line_po
    FOREIGN KEY (po_id) REFERENCES demo_purchase_orders (id)
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_demo_line_part
    FOREIGN KEY (part_id) REFERENCES demo_parts (id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_demo_po_lines_qty CHECK (quantity > 0),
  CONSTRAINT chk_demo_po_lines_price CHECK (unit_price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Покрокове пояснення

1. **`DECIMAL(10,2)`** зберігає гроші точно (без двійкового округлення). До 8 цифр перед комою, 2 — після.
2. **`TINYINT(1)`** — традиційна MySQL-«булева»; `(1)` — лише підказка для відображення, на сторінці один байт незалежно.
3. **`DEFAULT CURRENT_TIMESTAMP`** обчислюється при вставці; додайте `ON UPDATE CURRENT_TIMESTAMP`, щоб мати «last modified».
4. **`NOT NULL DEFAULT 0.00`** безпечніше за nullable: у запитах не потрібен `COALESCE`; звіти не «втрачають» рядки в `SUM` через `NULL`.

---

## Вправа 6 — Обмеження `CHECK` (MySQL 8.0.16+)

### Контекст

Рядок замовлення з `quantity = 0` чи `unit_price < 0` беззмістовний — і, ймовірно, баг UI чи спроба шахрайства. Хочемо, щоб сама БД відмовляла такі рядки незалежно від того, який застосунок їх надіслав.

### Чого ви навчитеся

- `CHECK (predicate)` всередині таблиці.
- Що MySQL виконує `CHECK` лише з 8.0.16 (старіші версії синтаксис парсять, але мовчки ігнорують).

### Задіяні таблиці

| Ціль | Колонки |
|---|---|
| `demo_po_lines` | `quantity`, `unit_price` |

### Завдання

Додати два `CHECK`: `quantity > 0` та `unit_price >= 0`.

### Очікуваний результат (релевантні рядки `SHOW CREATE TABLE demo_po_lines`)

```text
CONSTRAINT `chk_demo_po_lines_price` CHECK ((`unit_price` >= 0)),
CONSTRAINT `chk_demo_po_lines_qty`   CHECK ((`quantity` > 0))
```

### Підказка

`CONSTRAINT name CHECK (predicate)` або всередині `CREATE TABLE`, або через `ALTER TABLE … ADD CONSTRAINT …`.

### Розв'язання

```sql
-- у скрипті — інлайн:
CONSTRAINT chk_demo_po_lines_qty   CHECK (quantity > 0),
CONSTRAINT chk_demo_po_lines_price CHECK (unit_price >= 0)
```

### Покрокове пояснення

1. **Завжди іменуйте обмеження.** Інакше повідомлення про порушення виглядатиме як `Check constraint 'demo_po_lines_chk_1' is violated`, і доведеться лізти у схему, щоб зрозуміти, що це.
2. **Предикат `CHECK` бачить лише свій рядок.** Інваріанти між рядками або таблицями потребують `TRIGGER` або логіки в застосунку.
3. **MySQL 8.0.16+** — виконує `CHECK`. Ранішим 8.0 і всім 5.x синтаксис нормально парситься, але мовчки ігнорується — давня пастка, перевіряйте `SHOW WARNINGS`.

---

## Вправа 7 — Вторинний індекс для пошуку

### Контекст

Тижневий звіт сканує `demo_suppliers` за назвою (або її префіксом). Щоб пошук лишався швидким зі зростанням таблиці, додаємо **неунікальний вторинний індекс** на перші 20 символів `name`.

### Чого ви навчитеся

- `ALTER TABLE … ADD INDEX`.
- Форма **префіксного індексу** `(col(20))` для довгих `VARCHAR`.

### Задіяні таблиці

| Ціль | Колонки |
|---|---|
| `demo_suppliers` | `name` |

### Завдання

Додати неунікальний індекс `idx_demo_supplier_name` на перших 20 символах `demo_suppliers.name`.

### Очікуваний результат (релевантний рядок `SHOW CREATE TABLE demo_suppliers`)

```text
KEY `idx_demo_supplier_name` (`name`(20))
```

### Підказка

`ALTER TABLE demo_suppliers ADD INDEX idx_demo_supplier_name (name(20));`

### Розв'язання

```sql
ALTER TABLE demo_suppliers ADD INDEX idx_demo_supplier_name (name(20));
```

### Покрокове пояснення

1. **`ADD INDEX` vs `CREATE INDEX`** — те саме; `ALTER TABLE … ADD INDEX …` канонічне, бо одним стейтментом можна додати кілька змін.
2. **Префіксні індекси** (`name(20)`) роблять індекс меншим (а тому й швидшим), але далі обслуговують `WHERE name LIKE 'Demo%'`. Для `ORDER BY name` вони не підходять.
3. **Не індексуйте все підряд.** Кожен індекс уповільнює `INSERT`/`UPDATE` й займає диск; додавайте ті, що відповідають реальним запитам.

---

## Вправа 8 — `ALTER TABLE` — додати стовпець

### Контекст

Customer support просить вільне поле `notes` на постачальниках — для нагадувань на кшталт «обговорити консолідовані інвойси з Петром». Таблиця вже має дані, тож використовуємо `ALTER`.

### Чого ви навчитеся

- Синтаксис `ALTER TABLE … ADD COLUMN`.
- Позиційний натяк `AFTER col`.
- Що MySQL 8 робить **миттєвий** `ADD COLUMN` для «трейлерної» колонки — таблицю не переписують.

### Задіяні таблиці

| Ціль | Колонки |
|---|---|
| `demo_suppliers` | (додає) `notes` |

### Завдання

Додати опціональний `notes TEXT` до `demo_suppliers` одразу після `phone`.

### Очікуваний результат (`DESC demo_suppliers` після Вправи 8 і *до* того, як Вправа 10 його видалить)

```text
+------------+--------------+------+-----+-------------------+-------------------+
| Field      | Type         | Null | Key | Default           | Extra             |
+------------+--------------+------+-----+-------------------+-------------------+
| id         | int          | NO   | PRI | NULL              | auto_increment    |
| name       | varchar(100) | NO   | MUL | NULL              |                   |
| phone      | varchar(20)  | YES  |     | NULL              |                   |
| notes      | text         | YES  |     | NULL              |                   |
| created_at | timestamp    | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
+------------+--------------+------+-----+-------------------+-------------------+
```

### Підказка

`ALTER TABLE demo_suppliers ADD COLUMN notes TEXT NULL AFTER phone;`

### Розв'язання

```sql
ALTER TABLE demo_suppliers
  ADD COLUMN notes TEXT NULL AFTER phone;
```

### Покрокове пояснення

1. **`AFTER phone`** розміщує стовпець візуально у виводі `DESC`; фізично MySQL зберігає в порядку оголошення, тож це впливає на порядок у `SELECT *` та експортах.
2. **`TEXT NULL`**: `TEXT` — змінної довжини, до 64 KB. Дозволяємо `NULL`, бо у більшості наявних постачальників нотаток немає.
3. **Миттєвий `ADD COLUMN`** (MySQL 8.0.12+) — метадані змінюються без переписування таблиці й без довгого блокування. Додавання не-трейлерної колонки або `NOT NULL` без `DEFAULT` усе ще може перебудовувати таблицю.

---

## Вправа 9 — `ALTER TABLE` — змінити тип або nullable

### Контекст

У міжнародних постачальників телефони довгі (`+44 (0)20 7946 0xxx`); початковий `VARCHAR(20)` замалий. Розширюємо без втрат.

### Чого ви навчитеся

- `MODIFY COLUMN` (змінює тип) vs `CHANGE COLUMN` (перейменовує *і* змінює тип).
- Розширювати завжди безпечно; звужувати — ризиковано.

### Задіяні таблиці

| Ціль | Колонки |
|---|---|
| `demo_suppliers` | `phone` |

### Завдання

Розширити `demo_suppliers.phone` з `VARCHAR(20)` до `VARCHAR(32)`, лишивши nullable.

### Очікуваний результат (`DESC demo_suppliers` після розширення)

```text
+------------+--------------+------+-----+-------------------+-------------------+
| Field      | Type         | Null | Key | Default           | Extra             |
+------------+--------------+------+-----+-------------------+-------------------+
| id         | int          | NO   | PRI | NULL              | auto_increment    |
| name       | varchar(100) | NO   | MUL | NULL              |                   |
| phone      | varchar(32)  | YES  |     | NULL              |                   |
| created_at | timestamp    | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
+------------+--------------+------+-----+-------------------+-------------------+
```

### Підказка

`ALTER TABLE demo_suppliers MODIFY COLUMN phone VARCHAR(32) NULL;`

### Розв'язання

```sql
ALTER TABLE demo_suppliers
  MODIFY COLUMN phone VARCHAR(32) NULL;
```

### Покрокове пояснення

1. **`MODIFY COLUMN`** залишає ім'я і змінює тип / nullability / default.
2. **`CHANGE COLUMN`** використовуйте для перейменування *і* зміни типу: `ALTER TABLE t CHANGE COLUMN old_name new_name VARCHAR(50)`.
3. **Звуження небезпечне.** Перехід `VARCHAR(50)` → `VARCHAR(10)` обріже значення; MySQL попередить, але не зупинить, якщо `sql_mode` не `STRICT_*`.

---

## Вправа 10 — `ALTER TABLE` — видалити стовпець

### Контекст

Після ревізії процесу СТО вирішує, що нотатки місце мають у CRM, а не в `suppliers`. Видаляємо стовпець, щоб схема лишалася стрункою.

### Чого ви навчитеся

- Синтаксис `DROP COLUMN`.
- Що видалення стовпця руйнівне й незворотне.

### Задіяні таблиці

| Ціль | Колонки |
|---|---|
| `demo_suppliers` | (видаляє) `notes` |

### Завдання

Видалити стовпець `notes`, доданий у Вправі 8.

### Очікуваний результат (`DESC demo_suppliers` після видалення — фінальна форма таблиці у скрипті)

```text
+------------+--------------+------+-----+-------------------+-------------------+
| Field      | Type         | Null | Key | Default           | Extra             |
+------------+--------------+------+-----+-------------------+-------------------+
| id         | int          | NO   | PRI | NULL              | auto_increment    |
| name       | varchar(100) | NO   | MUL | NULL              |                   |
| phone      | varchar(32)  | YES  |     | NULL              |                   |
| created_at | timestamp    | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
+------------+--------------+------+-----+-------------------+-------------------+
```

### Підказка

`ALTER TABLE demo_suppliers DROP COLUMN notes;`

### Розв'язання

```sql
ALTER TABLE demo_suppliers
  DROP COLUMN notes;
```

### Покрокове пояснення

1. **Дані безповоротно втрачаються.** Завжди робіть експорт або бекап перед видаленням стовпця.
2. **Індекси на цей стовпець теж видаляються** — MySQL прибере їх сам.
3. **Стовпець не можна видалити, поки на нього посилається FK.** Спершу видаліть або змініть обмеження.

---

## Вправа 11 — `RENAME TABLE`

### Контекст

Команда вирішила, що `demo_parts` занадто загальне; хочуть `demo_catalog_parts`, щоб роль таблиці була явною. Перейменування має бути дешевим — без копіювання даних.

### Чого ви навчитеся

- `RENAME TABLE old TO new` — практично миттєва метадана-операція.
- Що зовнішні ключі, які посилаються **на** перейменовану таблицю, продовжують працювати — InnoDB відстежує таблиці за id, а не за іменем.

### Задіяні таблиці

| Ціль | Нова назва |
|---|---|
| `demo_parts` | `demo_catalog_parts` |

### Завдання

Перейменувати `demo_parts` на `demo_catalog_parts`. Перевірити, що FK з `demo_po_lines` далі працює.

### Очікуваний результат (`SHOW TABLES` після перейменування)

```text
+------------------------+
| Tables_in_ddl_practice |
+------------------------+
| demo_catalog_parts     |
| demo_po_lines          |
| demo_purchase_orders   |
| demo_scratch_log       |
| demo_suppliers         |
| v_demo_supplier_orders |
+------------------------+
```

### Підказка

`RENAME TABLE demo_parts TO demo_catalog_parts;`

### Розв'язання

```sql
RENAME TABLE demo_parts TO demo_catalog_parts;

-- Перевірити, що дочірній FK оновлено автоматично:
SHOW CREATE TABLE demo_po_lines\G
```

### Покрокове пояснення

1. **`RENAME` атомарне і швидке.** Внутрішньо змінюється запис у каталозі; дані не торкаються.
2. **FK оновлюються прозоро.** Після перейменування `SHOW CREATE TABLE demo_po_lines` покаже FK на `demo_catalog_parts`.
3. **Перейменовувати кілька таблиць можна одним стейтментом** (`RENAME TABLE a TO b, b TO a, ...` — зручно для атомарної заміни).

---

## Вправа 12 — Порядок `DROP TABLE` і прибирання

### Контекст

Після заняття хочеться лишити чисту пісочницю, щоб наступний студент починав з нуля. Дочірні таблиці видаляються першими; інакше FK не дадуть прибрати батьків.

### Чого ви навчитеся

- Порядок залежностей: нащадок → батько.
- `SET foreign_key_checks = 0` як свідомий обхід (з поверненням у `= 1`).

### Задіяні таблиці

| Ціль | Видаляється |
|---|---|
| (кілька) | `demo_po_lines`, `demo_purchase_orders`, `demo_catalog_parts`, `demo_scratch_log`, `demo_suppliers` |

### Завдання

Подати чистий teardown-блок (закоментований у кінці скрипту, щоб не виконувався автоматично).

### Очікуваний результат

Після запуску teardown-блоку `SHOW TABLES;` повертає лише `rel_*` (з лабораторії зв'язків) або нічого.

### Підказка

Видаляйте у зворотньому порядку або тимчасово вимикайте `foreign_key_checks`.

### Розв'язання

```sql
SET foreign_key_checks = 0;
DROP TABLE IF EXISTS demo_po_lines;
DROP TABLE IF EXISTS demo_purchase_orders;
DROP VIEW  IF EXISTS v_demo_supplier_orders;
DROP TABLE IF EXISTS demo_catalog_parts;
DROP TABLE IF EXISTS demo_scratch_log;
DROP TABLE IF EXISTS demo_suppliers;
SET foreign_key_checks = 1;
-- Повний reset за бажанням:
-- DROP DATABASE IF EXISTS ddl_practice;
```

### Покрокове пояснення

1. **`IF EXISTS`** не дає MySQL впасти, якщо таблиці вже немає — обов'язково для повторюваних скриптів.
2. **`SET foreign_key_checks = 0`** — параметр сесії; одразу після bulk-DROP поверніть `= 1`, щоб подальші стейтменти знов мали повну референтну цілісність.
3. **`DROP DATABASE`** видаляє *усе* одним стейтментом — швидко й небезпечно. Тільки для одноразових пісочниць.

---

## Вправа 13 — `CREATE VIEW` (іменоване визначення)

### Контекст

Звітність хоче простий join «постачальник ↔ замовлення», який BI може запитувати, не знаючи деталей схеми. View фіксує цей join за стабільним іменем.

### Чого ви навчитеся

- `CREATE OR REPLACE VIEW … AS SELECT …` — ідемпотентне визначення.
- Що `LEFT JOIN` зберігає постачальників без жодного PO у виводі view.

### Задіяні таблиці

| Ціль | Джерельні таблиці |
|---|---|
| `v_demo_supplier_orders` (view) | `demo_suppliers`, `demo_purchase_orders` |

### Завдання

Створити або замінити view, який повертає id постачальника, ім'я, та (на кожен збіг) id і дату замовлення.

### Очікуваний результат (`SELECT * FROM v_demo_supplier_orders;` після seed-даних)

```text
+-------------+----------------------+-------------------+------------+
| supplier_id | supplier_name        | purchase_order_id | order_date |
+-------------+----------------------+-------------------+------------+
|           1 | Demo Parts Wholesale |                 1 | 2026-01-15 |
+-------------+----------------------+-------------------+------------+
```

### Підказка

`CREATE OR REPLACE VIEW v_demo_supplier_orders AS SELECT … FROM … LEFT JOIN … ON … ;`

### Розв'язання

```sql
CREATE OR REPLACE VIEW v_demo_supplier_orders AS
SELECT s.id   AS supplier_id,
       s.name AS supplier_name,
       po.id  AS purchase_order_id,
       po.order_date
FROM demo_suppliers AS s
LEFT JOIN demo_purchase_orders AS po ON po.supplier_id = s.id;
```

### Покрокове пояснення

1. **`OR REPLACE`** дозволяє перезапустити скрипт; без нього другий запуск падає з «view вже існує».
2. **`LEFT JOIN`** зберігає постачальників без замовлень. Заміна на `INNER JOIN` дасть лише «активних» постачальників.
3. **View у MySQL не матеріалізується** — кожен запит до неї переписується в join базових таблиць. Матеріалізовані view вимагають періодичних `CREATE TABLE AS SELECT`.

---

## Вправа 14 — `TRUNCATE` (необов'язкова вправа)

### Контекст

Таблиця `demo_scratch_log` під час практики накопичує одноразові діагностичні повідомлення. Хочемо стерти її миттєво — `DELETE` сканував би кожен рядок.

### Чого ви навчитеся

- `TRUNCATE TABLE` — швидке очищення з присмаком DDL (потребує права `DROP`).
- Воно **скидає** `AUTO_INCREMENT` до seed; `DELETE` ні.
- Не може виконатися, якщо інші таблиці посилаються на цю через FK.

### Задіяні таблиці

| Ціль | Колонки |
|---|---|
| `demo_scratch_log` | (усі рядки видалено) |

### Завдання

Вставити повідомлення `before truncate` у `demo_scratch_log`, потім зробити `TRUNCATE`. Перевірити, що таблиця порожня.

### Очікуваний результат (`SELECT * FROM demo_scratch_log;` після truncate)

```text
Empty set (0.00 sec)
```

### Підказка

`TRUNCATE TABLE demo_scratch_log;`

### Розв'язання

```sql
INSERT INTO demo_scratch_log (message) VALUES ('before truncate');
TRUNCATE TABLE demo_scratch_log;
```

### Покрокове пояснення

1. **`TRUNCATE` ≈ `DROP + CREATE`** усередині — тому й потрібен `DROP`, і AUTO_INCREMENT скидається.
2. **`TRUNCATE` не транзакційний.** Навіть усередині `START TRANSACTION` / `ROLLBACK` його не можна відкотити.
3. **FK-захист.** Якщо інша таблиця має `FOREIGN KEY` **на** цю, `TRUNCATE` відмовиться; запасний варіант — `DELETE` (може жити з «висячими» FK) або тимчасово зняти обмеження.

---

## Лабораторія зв'язків — `car_service_relationships_examples.sql`

### Контекст

Скрипт зі зв'язками будує одним проходом усі класичні форми FK, що зустрічаються в реальних схемах: батько → нащадок, само-посилання, багато-до-багатьох. Це ідеальна вправа для думання про **наслідки моделі даних**.

### Чого ви навчитеся

- `1:N` батько ↔ нащадок (`rel_customers` → `rel_work_orders`).
- Само-посилання для ієрархій (`rel_technicians.manager_id`).
- `N:M` через міст-таблицю зі складним PK (`rel_order_parts`).
- Три дії FK — `RESTRICT`, `SET NULL`, `CASCADE` — і коли яку обирати.

### Задіяні таблиці

| Таблиця | Роль |
|---|---|
| `rel_customers` | Батько (клієнти) |
| `rel_technicians` | Само-посилання (у техніка може бути керівник-технік) |
| `rel_work_orders` | Нащадок `rel_customers`, опційний нащадок `rel_technicians` |
| `rel_parts` | Довідник (каталог запчастин) |
| `rel_order_parts` | N:M міст між `rel_work_orders` та `rel_parts` |

### Завдання

Виконати скрипт; перевірити join по всіх п'яти таблицях.

### Очікуваний результат (фінальний перевірочний запит скрипту)

```text
+---------------+------------------+-------------------+-------------+------------------------+-----+
| work_order_id | customer         | technician        | sku         | part_name              | qty |
+---------------+------------------+-------------------+-------------+------------------------+-----+
|             1 | Olena Kovalenko  | Iryna Lead Tech   | BRK-PAD-01  | Front brake pad set    |   1 |
|             1 | Olena Kovalenko  | Iryna Lead Tech   | OIL-5W30-4L | Synthetic oil 5W-30 4L |   1 |
|             2 | Maksym Danylchuk | Taras Junior Tech | OIL-5W30-4L | Synthetic oil 5W-30 4L |   1 |
+---------------+------------------+-------------------+-------------+------------------------+-----+
```

### Підказка

П'ять таблиць з'єднуються в ланцюжок: `rel_work_orders → rel_customers`, `rel_work_orders → rel_technicians` (left, опційно), `rel_work_orders → rel_order_parts → rel_parts`.

### Розв'язання

```sql
SELECT wo.id          AS work_order_id,
       c.full_name    AS customer,
       t.tech_name    AS technician,
       p.sku,
       p.part_name,
       op.qty
FROM rel_work_orders AS wo
JOIN rel_customers     AS c  ON c.id  = wo.customer_id
LEFT JOIN rel_technicians AS t  ON t.id  = wo.technician_id
JOIN rel_order_parts   AS op ON op.work_order_id = wo.id
JOIN rel_parts         AS p  ON p.id  = op.part_id
ORDER BY wo.id, p.id;
```

### Покрокове пояснення

1. **`LEFT JOIN rel_technicians`** зберігає замовлення без призначеного техніка. Дія FK для `technician_id` — `ON DELETE SET NULL`, що відповідає цій семантиці.
2. **Складений PK `(work_order_id, part_id)`** на `rel_order_parts` робить дублювання пари (order, part) неможливим — змінюйте `qty`, не вставляйте ще раз.
3. **Вибір дії FK — шпаргалка:**
   - **`CASCADE`** — нащадки видаляються разом із батьком (типово для рядків-приналежностей: `demo_po_lines` ↔ `demo_purchase_orders`).
   - **`RESTRICT`** — не дати видалити батька, поки є нащадки (безпечніший default для каталогів).
   - **`SET NULL`** — нащадок лишається, але посилання обнуляється (зручно для опціонального лінку, як технік на замовленні).

---

## Діагностика: мій DDL впав

| Симптом | Імовірне виправлення |
|---|---|
| `Cannot add foreign key constraint` (`errno: 150`) | Батьківської таблиці немає або типи стовпців різні (напр. `INT` vs `BIGINT`). |
| `Cannot delete or update a parent row` | На рядок ще посилається нащадок. Видаліть/змініть нащадків або змініть дію FK. |
| `Duplicate entry … for key 'PRIMARY'` | Вставка з наявним PK. Використайте `INSERT IGNORE` або `ON DUPLICATE KEY UPDATE`. |
| `Specified key was too long` | `VARCHAR` зашироке для індексованої колонки в `utf8mb4`. Префіксний індекс: `KEY (col(191))`. |
| `Check constraint … is violated` | Рядок порушує `CHECK`. Виправте дані або зніміть обмеження. |

Запустити **обидва** скрипти одним рядком: `mysql -u root < 03_mysql/02_ddl/car_service_ddl_examples.sql && mysql -u root < 03_mysql/02_ddl/car_service_relationships_examples.sql`.
