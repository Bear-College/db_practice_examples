# Транзакції — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/09_transactions/transactions_car_service_db.md)

Ці вправи проходять **явні транзакції** (`START TRANSACTION` / `COMMIT` / `ROLLBACK` / `SAVEPOINT`) та чотири **рівні ізоляції**, які підтримує InnoDB. Використовуються лабораторні таблиці **`tx_lab`** (два «банківські рахунки майстерень», між якими переказують гроші) та **`iso_lab`** (склад запчастин) усередині **`car_service_db`** (із дампу **`01_database_mysql/car_service_db.sql.gz`**).

Готові скрипти-компаньйони:

- [`09_transactions/car_service_transactions_examples.sql`](../../../../03_mysql/09_transactions/car_service_transactions_examples.sql) — begin / commit / rollback / savepoints
- [`09_transactions/car_service_isolation_levels_examples.sql`](../../../../03_mysql/09_transactions/car_service_isolation_levels_examples.sql) — `READ UNCOMMITTED` / `READ COMMITTED` / `REPEATABLE READ` / `SERIALIZABLE`. Частина A — одна сесія; Частина B — рецепт для двох терміналів.

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/09_transactions/car_service_transactions_examples.sql
mysql -u root car_service_db < 03_mysql/09_transactions/car_service_isolation_levels_examples.sql
```

**Важливо:** запускайте **увесь файл в одній клієнтській сесії** (наприклад, `mysql < file` або вставте в одну вкладку). Транзакції не «переходять» між підключеннями — якщо кожне твердження виконується в окремому з'єднанні, демо не спрацює.

---

## Шаблон вправи (повторюється у кожному розділі нижче)

| Секція | Що вона дає |
|---|---|
| **Контекст** | Невеликий сценарій майстерні (переказ грошей, списання зі складу). |
| **Чого ви навчитеся** | Конкретний транзакційний примітив, який тренує саме ця вправа. |
| **Задіяні таблиці** | Лабораторна таблиця (`tx_lab` чи `iso_lab`). |
| **Завдання** | Пронумеровані твердження, які треба виконати. |
| **Очікуваний результат** | Реальний вивід «до / під час / після» з живого запуску `mysql`. |
| **Підказка** | Яка команда відкриває, фіксує чи відкочує транзакцію. |
| **Розв'язання** | Повний SQL-блок. |
| **Покрокове пояснення** | Що робить кожна команда і які типові помилки. |

---

## Шпаргалка з понять

| Фраза | Значення |
|--------|---------|
| **`START TRANSACTION`** / **`BEGIN`** | Відкрити явну транзакцію (InnoDB). |
| **`COMMIT`** | Зафіксувати усі зміни з моменту `START TRANSACTION` **постійно**. |
| **`ROLLBACK`** | **Відкинути** усі зміни з моменту `START TRANSACTION` (або останнього `COMMIT`). |
| **`SAVEPOINT name`** | Позначка всередині транзакції, до якої можна відкотитися. |
| **`ROLLBACK TO SAVEPOINT name`** | Скасувати лише роботу **після** цієї позначки; раніша робота лишається. |
| **`RELEASE SAVEPOINT name`** | Видалити позначку (необов'язково). |
| **Autocommit** | Коли `@@autocommit = 1` (за замовчуванням), кожне окреме твердження — це окрема міні-транзакція, якщо ви не відкрили явну через `START TRANSACTION`. |
| **Рівень ізоляції** | Наскільки видимі цій транзакції зміни інших сесій (виконані чи в польоті). `SET SESSION TRANSACTION ISOLATION LEVEL …` перед `START TRANSACTION`. У InnoDB за замовчуванням — **`REPEATABLE READ`**. |

**«Додати» транзакцію:** обгорнути DML у `START TRANSACTION` … `COMMIT` (зберегти) або `ROLLBACK` (відкинути).
**«Завершити» транзакцію:** `COMMIT` або `ROLLBACK`. Після цього сесія повертається до звичайної autocommit-поведінки до наступного `START TRANSACTION`.

---

## Скидання лабораторії (один раз на сесію)

```sql
DROP TABLE IF EXISTS tx_lab;

CREATE TABLE tx_lab (
  id      INT NOT NULL AUTO_INCREMENT,
  name    VARCHAR(80) NOT NULL,
  balance DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO tx_lab (name, balance) VALUES
  ('North Bay Workshop', 1000.00),
  ('South Bay Workshop',  500.00);
```

Два «рахунки майстерень» з початковими залишками 1000.00 і 500.00. Усі вправи нижче будуються від цього seed.

---

## Вправа 1 — Перевірка autocommit і seed-даних

### Контекст

Перш ніж торкатися транзакцій, переконайтесь у двох речах: autocommit увімкнений (за замовчуванням), а `tx_lab` має два seed-рядки. Це базовий стан, до якого ви будете повертатись.

### Чого ви навчитеся

- Як прочитати `@@session.autocommit`.
- Що при autocommit=1 транзакція є неявною для кожного твердження.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tx_lab` | `id`, `name`, `balance` |

### Завдання

Один `SELECT`, що повертає і `@@session.autocommit`, і `COUNT(*)` з `tx_lab` через `UNION ALL`.

### Очікуваний результат (реальний вивід)

```text
+-------------+-------+
| metric      | value |
+-------------+-------+
| autocommit  |     1 |
| tx_lab_rows |     2 |
+-------------+-------+
```

### Підказка

`SELECT "autocommit", @@session.autocommit UNION ALL SELECT "tx_lab_rows", COUNT(*) FROM tx_lab;`.

### Розв'язання

```sql
SELECT "autocommit" AS metric, @@session.autocommit AS value
UNION ALL
SELECT "tx_lab_rows"        AS metric, COUNT(*)            AS value FROM tx_lab;
```

### Покрокове пояснення

1. **`@@session.autocommit`** — значення на рівні сесії; `@@global.autocommit` — серверне за замовчуванням.
2. **`UNION ALL`** залишає обидва рядки. `UNION` (без `ALL`) дедуплікує — тут це не критично, але `UNION ALL` трохи дешевший.
3. **Чому важливо?** При autocommit=1 **кожне твердження — це окрема транзакція**: `UPDATE … WHERE id = 1` вже зафіксований до того, як з'явиться наступний промпт. Вправи нижче відкривають явні транзакції, щоб обійти цю поведінку.

---

## Вправа 2 — `START TRANSACTION` + `ROLLBACK` (відкинути зміни)

### Контекст

Ви починаєте переказати 200 грошових одиниць з North в South — і раптом помічаєте, що сума неправильна. `ROLLBACK` скасовує все зроблене з моменту `START TRANSACTION`, наче нічого не було.

### Чого ви навчитеся

- Найпростіший цикл «відкрити транзакцію, змінити, скасувати».
- Що `ROLLBACK` **не псує** дані, які були до транзакції.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tx_lab` | `id`, `name`, `balance` |

### Завдання

1. `START TRANSACTION`.
2. Зняти 200 з id 1, додати 200 до id 2.
3. `SELECT` — побачити стан у польоті.
4. `ROLLBACK`.
5. `SELECT` знову — залишки повернулись до seed.

### Очікуваний результат (реальний вивід)

Всередині транзакції (до rollback):

```text
+------------------------------------+----+--------------------+---------+
| phase                              | id | name               | balance |
+------------------------------------+----+--------------------+---------+
| inside transaction before rollback |  1 | North Bay Workshop |  800.00 |
| inside transaction before rollback |  2 | South Bay Workshop |  700.00 |
+------------------------------------+----+--------------------+---------+
```

Після `ROLLBACK`:

```text
+----------------------------------------+----+--------------------+---------+
| phase                                  | id | name               | balance |
+----------------------------------------+----+--------------------+---------+
| after ROLLBACK (back to seed balances) |  1 | North Bay Workshop | 1000.00 |
| after ROLLBACK (back to seed balances) |  2 | South Bay Workshop |  500.00 |
+----------------------------------------+----+--------------------+---------+
```

### Підказка

`START TRANSACTION;` … `UPDATE …;` … `ROLLBACK;`.

### Розв'язання

```sql
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 200.00 WHERE id = 1;
UPDATE tx_lab SET balance = balance + 200.00 WHERE id = 2;

SELECT 'inside transaction before rollback' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;

ROLLBACK;

SELECT 'after ROLLBACK (back to seed balances)' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;
```

### Покрокове пояснення

1. **`START TRANSACTION`** відкриває явну транзакцію. Усі наступні DML буферяться в undo-логи движка.
2. **Обидва `UPDATE`** — частина однієї транзакції. У межах сесії ви бачите нові залишки (`800` і `700`), але жодна інша сесія їх не бачить.
3. **`ROLLBACK`** відкидає буферизовані зміни. БД повертається до seed-значень, а блокування знімаються.
4. **Дані не постраждали.** Це і є та «сітка безпеки», яку SQL дає для багатоступеневих змін.
5. **Типовий баг:** виконати `UPDATE` випадково в режимі autocommit (без `START TRANSACTION`) — зміна одразу фіксується, `ROLLBACK` нічого не зробить.

---

## Вправа 3 — `START TRANSACTION` + `COMMIT` (зберегти зміни)

### Контекст

Цього разу переказ правильний (150 з North у South). `COMMIT` робить зміну довговічною: щойно він повернувся, нові залишки переживуть навіть рестарт сервера.

### Чого ви навчитеся

- Завершення транзакції через `COMMIT`.
- Що in-flight зчитування незафіксованого рядка дає нове значення **лише в межах цієї сесії**.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tx_lab` | `id`, `name`, `balance` |

### Завдання

1. `START TRANSACTION`.
2. Зняти 150 з id 1, додати 150 до id 2.
3. `COMMIT`.
4. `SELECT` — обидва рядки відображають переказ.

### Очікуваний результат (реальний вивід)

```text
+-----------------------------------+----+--------------------+---------+
| phase                             | id | name               | balance |
+-----------------------------------+----+--------------------+---------+
| after COMMIT (transfer persisted) |  1 | North Bay Workshop |  850.00 |
| after COMMIT (transfer persisted) |  2 | South Bay Workshop |  650.00 |
+-----------------------------------+----+--------------------+---------+
```

### Підказка

Дзеркало Вправи 2 — `ROLLBACK` замінюється на `COMMIT`.

### Розв'язання

```sql
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 150.00 WHERE id = 1;
UPDATE tx_lab SET balance = balance + 150.00 WHERE id = 2;

COMMIT;

SELECT 'after COMMIT (transfer persisted)' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;
```

### Покрокове пояснення

1. **`COMMIT`** скидає undo-/redo-логи і знімає блокування; рядок стає видимим усім.
2. **Атомарність:** обидва `UPDATE` фіксуються разом. Якщо сервер упаде між ними, при старті InnoDB відкоче часткову транзакцію — неможлива ситуація «гроші зняті, але не зараховані».
3. **Довговічність:** після того як `COMMIT` повернувся, зміна вже на диску. Навіть вимкнення живлення її не втратить.
4. **Зверніть увагу на біжучі підсумки:** Вправа 2 повернула до seed (`1000` / `500`), а цей переказ зняв 150 / додав 150, давши `850` / `650`. Вправи накопичуються.

---

## Вправа 4 — `SAVEPOINT` і `ROLLBACK TO SAVEPOINT` (часткове скасування)

### Контекст

Тонший сценарій: списати з одного рахунка, поставити чекпойнт, нарахувати на другий, потім передумати і скасувати **лише нарахування**, залишивши списання. Зручно, коли попередній крок перевірений, а наступний треба перепробувати з іншими параметрами.

### Чого ви навчитеся

- `SAVEPOINT name` — позначка «сюди можна повернутися».
- `ROLLBACK TO SAVEPOINT name` скасовує лише роботу **після** цієї точки.
- `RELEASE SAVEPOINT name` видаляє маркер (необов'язково).
- Підсумковий `COMMIT` зберігає те, що вижило.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tx_lab` | `id`, `name`, `balance` |

### Завдання

1. `START TRANSACTION`.
2. Зняти 50 з id 1.
3. `SAVEPOINT after_debit`.
4. Додати 50 до id 2.
5. `ROLLBACK TO SAVEPOINT after_debit` — нарахування скасоване, списання лишається.
6. `SELECT` — проміжний стан.
7. Знову нарахувати, `RELEASE SAVEPOINT after_debit`, `COMMIT`.
8. `SELECT` — фінал.

### Очікуваний результат (реальний вивід)

Після `ROLLBACK TO SAVEPOINT` (списання лишилось, нарахування зникло):

```text
+-------------------------------------------------------+----+--------------------+---------+
| phase                                                 | id | name               | balance |
+-------------------------------------------------------+----+--------------------+---------+
| after ROLLBACK TO SAVEPOINT (workshop2 credit undone) |  1 | North Bay Workshop |  800.00 |
| after ROLLBACK TO SAVEPOINT (workshop2 credit undone) |  2 | South Bay Workshop |  650.00 |
+-------------------------------------------------------+----+--------------------+---------+
```

Після `COMMIT` (нарахування повторно):

```text
+---------------------------------------+----+--------------------+---------+
| phase                                 | id | name               | balance |
+---------------------------------------+----+--------------------+---------+
| after COMMIT following savepoint demo |  1 | North Bay Workshop |  800.00 |
| after COMMIT following savepoint demo |  2 | South Bay Workshop |  700.00 |
+---------------------------------------+----+--------------------+---------+
```

### Підказка

`SAVEPOINT name` → `… робота …` → `ROLLBACK TO SAVEPOINT name` → `… переробити / пропустити …` → `COMMIT`.

### Розв'язання

```sql
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 50.00 WHERE id = 1;

SAVEPOINT after_debit;

UPDATE tx_lab SET balance = balance + 50.00 WHERE id = 2;

ROLLBACK TO SAVEPOINT after_debit;

SELECT 'after ROLLBACK TO SAVEPOINT (workshop2 credit undone)' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;

UPDATE tx_lab SET balance = balance + 50.00 WHERE id = 2;

RELEASE SAVEPOINT after_debit;

COMMIT;

SELECT 'after COMMIT following savepoint demo' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;
```

### Покрокове пояснення

1. **Списання — до savepoint.** Після `ROLLBACK TO SAVEPOINT after_debit` воно **залишається**; зникає лише робота, що сталася **після** savepoint.
2. **`SAVEPOINT` локальний для поточної транзакції.** `ROLLBACK` (без `TO SAVEPOINT`) відкочує транзакцію цілком разом з усіма savepoint.
3. **`RELEASE SAVEPOINT`** видаляє маркер. Після цього відкотитися сюди вже не можна, але робота після нього не зникає.
4. **Біжучі залишки:** до цієї вправи — `850` / `650`. Списання −50 ⇒ `800` / `650`. Фінальне нарахування +50 ⇒ `800` / `700`.
5. **Реальний сценарій:** retries в апі. Зовнішня транзакція обгортає бізнес-дію з кількох кроків; кожен retryable-крок огорнутий savepoint, тому одна локальна помилка не зриває все.

---

## Вправа 5 — `SET autocommit = 0` (неявні мультистейтментні транзакції)

### Контекст

Деякі клієнти (зокрема `mysql` CLI в script-режимі) люблять «вимкнути autocommit», щоб послідовність команд стала однією великою транзакцією. Корисно для масових завантажень. Будьте обережні: якщо забути фінальний `COMMIT`, сесія залишиться з відкритою транзакцією і блокуваннями.

### Чого ви навчитеся

- `SET SESSION autocommit = 0` робить кожне наступне твердження неявною частиною транзакції.
- Усе одно потрібен `COMMIT`, інакше робота втратиться при роз'єднанні.
- `SET SESSION autocommit = 1` повертає до стандартної поведінки.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tx_lab` | `id`, `name`, `balance` |

### Завдання

1. `SET SESSION autocommit = 0`.
2. Два `UPDATE` (10 з North в South).
3. `COMMIT`.
4. `SET SESSION autocommit = 1`.

(У файлі-компаньйоні цей блок закоментований — розкоментуйте, щоб виконати.)

### Очікуваний результат

Після блоку залишки змінюються на 10 одиниць (наприклад, `790.00` / `710.00`, якщо ви продовжуєте від Вправи 4). Перевірте через `SELECT`.

### Підказка

Два `UPDATE` між `SET autocommit = 0` і `COMMIT` формують одну транзакцію.

### Розв'язання

```sql
SET SESSION autocommit = 0;

UPDATE tx_lab SET balance = balance - 10 WHERE id = 1;
UPDATE tx_lab SET balance = balance + 10 WHERE id = 2;

COMMIT;

SET SESSION autocommit = 1;

SELECT 'after autocommit=0 demo' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;
```

### Покрокове пояснення

1. **`autocommit = 0`** змушує движок ставитися до записів у `tx_lab` як до частини відкритої транзакції без явного `START TRANSACTION`.
2. **Без фінального `COMMIT`**: роз'єднання (або `SET autocommit = 1` у багатьох клієнтських режимах) відкотить незафіксовану роботу.
3. **Чому не завжди так?** Здивує колег. Явний блок `START TRANSACTION; … COMMIT;` набагато зрозуміліший для читачів і код-рев'юерів.
4. **Безпека:** у спільних сесіях (репліки, міграції схем) зміна `autocommit` посеред скрипта може суперечити припущенням інших інструментів. Не забудьте повернути 1 в кінці.

---

## Вправа 6 — `REPEATABLE READ` (за замовчуванням у InnoDB)

### Контекст

Ви виконуєте денний звіт по складу. Поки ви читаєте, інший технік списує інший SKU. Ваш звіт має показати **узгоджений снапшот** залишків станом на початок вашої транзакції.

### Чого ви навчитеся

- Рівень ізоляції InnoDB за замовчуванням — `REPEATABLE READ`.
- Звичайний `SELECT` у транзакції читає **снапшот**, зафіксований при **першому** читанні.
- Коміти інших сесій не змінюють рядки, які ви вже «бачили».

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `iso_lab` | `id`, `part_code`, `stock_qty` |

### Завдання

1. `SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ`.
2. `START TRANSACTION`.
3. Прочитати `id = 1`.
4. `UPDATE` іншого рядка (`id = 2`).
5. Прочитати `id = 1` знову — те ж значення.
6. `COMMIT`. Перечитати — усі бачать новий стан.

### Очікуваний результат (реальний вивід)

Перше читання у транзакції:

```text
+---------------------+----+------------+-----------+
| phase               | id | part_code  | stock_qty |
+---------------------+----+------------+-----------+
| RR: first read id=1 |  1 | BRK-PAD-01 |        40 |
+---------------------+----+------------+-----------+
```

Друге читання того ж рядка в тій самій транзакції (снапшот — те саме значення):

```text
+----------------------------------------------------------------+----+------------+-----------+
| phase                                                          | id | part_code  | stock_qty |
+----------------------------------------------------------------+----+------------+-----------+
| RR: second read id=1 (same snapshot as first read in this txn) |  1 | BRK-PAD-01 |        40 |
+----------------------------------------------------------------+----+------------+-----------+
```

Після `COMMIT` (видно і `UPDATE` для id 2):

```text
+-------------------------------------------------+----+-------------+-----------+
| phase                                           | id | part_code   | stock_qty |
+-------------------------------------------------+----+-------------+-----------+
| RR: after COMMIT — everyone sees committed data |  1 | BRK-PAD-01  |        40 |
| RR: after COMMIT — everyone sees committed data |  2 | OIL-5W30-4L |        22 |
| RR: after COMMIT — everyone sees committed data |  3 | FLT-AIR-88  |        12 |
+-------------------------------------------------+----+-------------+-----------+
```

### Підказка

`SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ` **перед** `START TRANSACTION`.

### Розв'язання

```sql
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

START TRANSACTION;

SELECT 'RR: first read id=1' AS phase, id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

UPDATE iso_lab SET stock_qty = stock_qty - 3 WHERE id = 2;

SELECT 'RR: second read id=1 (same snapshot as first read in this txn)' AS phase,
       id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

COMMIT;

SELECT 'RR: after COMMIT — everyone sees committed data' AS phase,
       id, part_code, stock_qty FROM iso_lab ORDER BY id;
```

### Покрокове пояснення

1. **Семантика снапшота:** при першому читанні у транзакції InnoDB фіксує «read view». Усі наступні плоскі `SELECT` бачать дані станом на цей снапшот, попри коміти інших сесій.
2. **Записи беруть найсвіжіші зафіксовані дані**, не снапшот, — саме тому ваш `UPDATE` на id 2 змінив `stock_qty` з 25 до 22 (рядок треба читати «свіжим» перед мутацією).
3. **`UPDATE` у вашій транзакції видимий вашим наступним читанням** у тій самій транзакції.
4. **Захист від phantom-рядків:** RR + gap-блокування InnoDB зазвичай запобігають phantom-у в межах однієї транзакції. Нижчі рівні (RC, RU) — ні.

---

## Вправа 7 — `READ COMMITTED`

### Контекст

Реалтайм-дашборди часто беруть `READ COMMITTED` (RC): кожне твердження бачить найсвіжіший зафіксований стан. Якщо між двома вашими `SELECT` хтось закомітить, другий побачить нову цифру.

### Чого ви навчитеся

- `READ COMMITTED` перечитує дані для кожного твердження.
- Платіж: можливі **non-repeatable reads** (однаковий `SELECT` двічі, різні результати).
- Переваги конкурентності: менше gap-блокувань, ніж в RR.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `iso_lab` | `id`, `part_code`, `stock_qty` |

### Завдання

1. `SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED`.
2. `START TRANSACTION`.
3. Прочитати `id = 1`.
4. `COMMIT`.

(Для справжньої демонстрації non-repeatable read потрібні два термінали — див. «Частина B» нижче.)

### Очікуваний результат (реальний вивід)

```text
+-----------------+----+------------+-----------+
| phase           | id | part_code  | stock_qty |
+-----------------+----+------------+-----------+
| RC: read in txn |  1 | BRK-PAD-01 |        40 |
+-----------------+----+------------+-----------+
```

### Підказка

`SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED` перед `START TRANSACTION`.

### Розв'язання

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

START TRANSACTION;

SELECT 'RC: read in txn' AS phase, id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

COMMIT;
```

### Покрокове пояснення

1. **`READ COMMITTED`** перечитує найсвіжіший комітований стан на кожне твердження. Транзакційного снапшота немає.
2. **Non-repeatable read** — ціна: якщо хтось закомітить між вашими `SELECT`, отримаєте інше значення.
3. **Навіщо RC?** Вища паралелізація: немає gap-блокувань на плоский `SELECT`. Корисно для дашбордів з великою кількістю читань.
4. **Аналог у PostgreSQL:** RC — це default Postgres. MySQL за замовчуванням працює на RR, який строгіший.

---

## Вправа 8 — `READ UNCOMMITTED`

### Контекст

Класичний підручниковий рівень «брудного читання». У MySQL/InnoDB ви все одно зазвичай не бачите незакомічених рядків через плоский `SELECT` — але рівень змінює поведінку блокувань для locking-читань (`SELECT … FOR UPDATE`). У реальному коді віддавайте перевагу RC і вище.

### Чого ви навчитеся

- Рівень дозволено, але плоский `SELECT` у InnoDB часто все ще ховає «брудні» дані.
- Класичне brudn-read демо потребує двох сесій (Частина B нижче).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `iso_lab` | `id`, `part_code`, `stock_qty` |

### Завдання

1. `SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED`.
2. `START TRANSACTION`.
3. Прочитати всі рядки.
4. `COMMIT`.

### Очікуваний результат (реальний вивід)

```text
+------------------------------------------------------------+----+-------------+-----------+
| phase                                                      | id | part_code   | stock_qty |
+------------------------------------------------------------+----+-------------+-----------+
| RU: read (level set; use Part B for dirty-read experiment) |  1 | BRK-PAD-01  |        40 |
| RU: read (level set; use Part B for dirty-read experiment) |  2 | OIL-5W30-4L |        22 |
| RU: read (level set; use Part B for dirty-read experiment) |  3 | FLT-AIR-88  |        12 |
+------------------------------------------------------------+----+-------------+-----------+
```

### Підказка

Вивід однієї сесії виглядає як комітований стан — різниця проявляється при паралельних незакомічених записах.

### Розв'язання

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

START TRANSACTION;

SELECT 'RU: read (level set; use Part B for dirty-read experiment)' AS phase,
       id, part_code, stock_qty FROM iso_lab ORDER BY id;

COMMIT;
```

### Покрокове пояснення

1. **Особливість InnoDB:** плоский `SELECT` під `READ UNCOMMITTED` часто **все одно** повертає останній комітований рядок, а не in-flight. «Брудне читання» з підручника — це SQL-92-ідеал, який InnoDB лише частково демонструє.
2. **Де рівень справді важливий:** locking-читання (`SELECT … FOR UPDATE`, `SELECT … LOCK IN SHARE MODE`) і внутрішня обробка undo-логів.
3. **На практиці:** у застосунках уникайте `READ UNCOMMITTED`. Беріть RC або RR.

---

## Вправа 9 — `SERIALIZABLE`

### Контекст

Найстрогіший рівень: кожен `SELECT` поводить себе як `SELECT … LOCK IN SHARE MODE`, а InnoDB додає gap-блокування для заборони phantom-рядків. Беріть, коли потрібна суто лінеаризована семантика (фінансові регістри, склад під високим навантаженням).

### Чого ви навчитеся

- `SERIALIZABLE` неявно підвищує `SELECT` до читання з shared lock.
- Платіж: різке зростання конкуренції за блокування.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `iso_lab` | `id`, `part_code`, `stock_qty` |

### Завдання

1. `SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE`.
2. `START TRANSACTION`.
3. Прочитати `id = 1` (зачиняє shared lock).
4. `COMMIT`.
5. **Поверніть стандартний рівень** для подальшої роботи: `SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ`.

### Очікуваний результат (реальний вивід)

```text
+-----------------------------+----+------------+-----------+
| phase                       | id | part_code  | stock_qty |
+-----------------------------+----+------------+-----------+
| SER: locked consistent read |  1 | BRK-PAD-01 |        40 |
+-----------------------------+----+------------+-----------+
```

### Підказка

Результат на вигляд такий самий, як на іншому рівні — різниця у **тому, що можуть робити інші сесії** поки ваша транзакція відкрита (вони блокуватимуться при спробі змінити цей діапазон).

### Розв'язання

```sql
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;

START TRANSACTION;

SELECT 'SER: locked consistent read' AS phase, id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

COMMIT;

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

### Покрокове пояснення

1. **Плоский `SELECT` ≡ `SELECT … LOCK IN SHARE MODE`** під SERIALIZABLE. Конкурентні writer-и блокуються до завершення вашої транзакції.
2. **Gap-блокування** забороняють вставку нового рядка в скан-діапазон — це захист від phantom-у.
3. **Вартість:** падає пропускна здатність, частіші deadlock-и. Беріть тільки за потреби.
4. **Завжди скидайте** в кінці (`SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ`), щоб сесія далі не йшла на SERIALIZABLE випадково.

---

## Вправа 10 — Частина B: рецепт для двох терміналів

### Контекст

Щоб **побачити** класичні аномалії (non-repeatable read, phantom, dirty read), потрібні дві паралельні `mysql`-сесії. Скрипт-компаньйон містить детальний рецепт для двох терміналів — копіюйте рядки в кожен термінал у вказаному порядку.

### Чого ви навчитеся

- Як показати **non-repeatable read** на `READ COMMITTED` (B2).
- Як показати **repeatable read** на `REPEATABLE READ` (B3).
- Як `REPEATABLE READ` блокує phantom-вставку, а `READ COMMITTED` — ні (B4).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `iso_lab` | `id`, `part_code`, `stock_qty` |

### Завдання

Відкрийте два `mysql`-клієнти (Термінал 1, Термінал 2). Слідуйте рецепту в `09_transactions/car_service_isolation_levels_examples.sql`, Частина B.

### Очікуваний результат

Кожен сценарій дає або «аномалію», або «немає аномалії». Приклад для B2 (non-repeatable read на `READ COMMITTED`):

- Термінал 1, перший `SELECT`: `stock_qty = 40`
- Термінал 2 комітить `stock_qty - 1`
- Термінал 1, другий `SELECT`: `stock_qty = 39` ← змінилося в межах однієї транзакції

### Підказка

`SET SESSION TRANSACTION ISOLATION LEVEL …` перед `START TRANSACTION` у кожному терміналі. Виконуйте команди **у порядку, як написано**.

### Розв'язання

Дивіться [`09_transactions/car_service_isolation_levels_examples.sql`](../../../../03_mysql/09_transactions/car_service_isolation_levels_examples.sql), Частина B (закоментована). Чотири сценарії:

- **B1 — `READ UNCOMMITTED`:** класичне «брудне читання»; InnoDB часто все одно ховає незакомічений рядок.
- **B2 — `READ COMMITTED`:** підтверджений non-repeatable read.
- **B3 — `REPEATABLE READ`:** снапшот повторюваний; ви не бачите коміту іншого терміналу, поки не завершите свою транзакцію.
- **B4 — Phantom range:** `RC` бачить новий рядок у COUNT, `RR` зберігає старий count.

### Покрокове пояснення

1. **Одна транзакція на термінал.** Другий `mysql -u root car_service_db` дає окрему сесію.
2. **Порядок має значення.** Команди виконуйте по черзі. Якщо запустити Термінал 2 повністю першим, експеримент розпадається.
3. **Очищення між сценаріями.** Кожен `START TRANSACTION` має бути закритий `COMMIT` або `ROLLBACK`, інакше наступний сценарій успадковує блокування.
4. **Чому не autocommit?** Бо нам потрібен явний контроль над транзакцією, щоб побачити аномалії. Autocommit їх ховає.

---

## Очищення

Обидва скрипти закінчуються опційними `DROP TABLE` для лабораторних таблиць. Розкоментуйте, якщо хочете «чистий лист»; інакше дані лишаються для подальших дослідів.

---

## Поради при дивній поведінці

| Симптом | Імовірне виправлення |
|---|---|
| `ROLLBACK` нічого не повертає | Сесія в режимі autocommit. Спершу відкрийте транзакцію: `START TRANSACTION;`. |
| `SAVEPOINT` помилка `unknown savepoint` | Savepoint було релізнуто, або `COMMIT` / `ROLLBACK` його стер. Savepoint живе тільки всередині своєї транзакції. |
| Два термінали не бачать змін один одного | У кожного з'єднання свій снапшот (особливо при RR). Спершу `COMMIT`. |
| Lock wait timeout exceeded | Інша сесія тримає row-lock. `SHOW ENGINE INNODB STATUS;` покаже, хто. |
| Deadlock на SERIALIZABLE | Неминуче під високим навантаженням; повторюйте транзакцію у застосунку. |
| Рівень ізоляції не змінився | Встановлюйте **до** `START TRANSACTION` і в тій самій сесії. |
