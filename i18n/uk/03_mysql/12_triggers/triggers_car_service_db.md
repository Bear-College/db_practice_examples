# Тригери — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/12_triggers/triggers_car_service_db.md)

Ці вправи встановлюють **тригери InnoDB** на малі лабораторні таблиці **`tri_lab_account`** і **`tri_lab_audit`** усередині **`car_service_db`** і демонструють повний життєвий цикл: **`BEFORE INSERT`** (валідація через **`SIGNAL`**), **`AFTER INSERT`**, **`BEFORE UPDATE`**, **`AFTER UPDATE`** і **`AFTER DELETE`**. Робота в ізольованих лабораторних таблицях зберігає продакшен-таблиці недоторканими і робить аудит-лог легким для читання.

> **Назва теки:** цей модуль — **`12_triggers`** (тригери йдуть перед збереженими функціями у нумерації репозиторію).

Готові запити лежать у файлі-компаньйоні: [`12_triggers/car_service_triggers_examples.sql`](../../../../03_mysql/12_triggers/car_service_triggers_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/12_triggers/car_service_triggers_examples.sql
```

Використовуйте клієнт **`mysql`** (або сумісний); **`DELIMITER`** обробляється клієнтом, коли ви робите `SOURCE` / перенаправлення файлу. **Повторні запуски** скрипта безпечні — він починається з `DROP TABLE IF EXISTS …` і скидає тригери разом з таблицями.

---

## Швидкий довідник

| Час спрацювання × подія | Типове застосування |
|---|---|
| **`BEFORE INSERT`** | Валідувати / нормалізувати **`NEW.*`**; відхилити некоректний рядок через **`SIGNAL`**. |
| **`AFTER  INSERT`** | Писати аудит, інкрементувати лічильники (використовуйте **`NEW`**). |
| **`BEFORE UPDATE`** | Валідувати нові значення стовпців; можна **модифікувати `NEW.*`**. |
| **`AFTER  UPDATE`** | Записати зміну з **`OLD`** і **`NEW`**. |
| **`BEFORE DELETE`** | Останній шанс заветувати видалення (рідко використовується). |
| **`AFTER  DELETE`** | Аудит / каскад через **`OLD`**. |

| Псевдо-рядок | Доступний у |
|---|---|
| **`NEW.column`** | Усі тригери `INSERT` і `UPDATE` — рядок, що ось-ось приземлиться / значення після оновлення. |
| **`OLD.column`** | Усі тригери `UPDATE` і `DELETE` — рядок, як він був. |

- **`SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '…';`** — стандартний спосіб відхилити операцію з тригера. Клас SQLSTATE `45000` зарезервований під користувацькі винятки.
- Тригери **не замінюють** обмеження, коли вистачає `CHECK`, `FOREIGN KEY` або `NOT NULL`. Беріть їх для крос-рядкової логіки, аудиту або коли DML іде в обхід застосунку.
- Видалення таблиці видаляє її тригери; **`DROP TRIGGER name`** прибирає окремий тригер, якщо таблицю потрібно зберегти.

---

## Лабораторна схема (створюється скриптом)

| Таблиця | Колонки |
|---|---|
| `tri_lab_account` | `id` (PK, AUTO_INCREMENT), `label VARCHAR(80)`, `balance DECIMAL(12,2)` |
| `tri_lab_audit`   | `id` (PK), `event VARCHAR(20)`, `account_id INT`, `old_val`, `new_val`, `msg`, `ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP` |

---

## Вправа T1 — Створіть лабораторні таблиці

### Контекст

Тригери не мають сенсу без «жертви» і журналу аудиту. Потрібна мала таблиця «рахунків», яку будемо мутувати, і таблиця «аудиту», у яку тригери писатимуть. Розмістити обидві в `car_service_db` зручно — поруч з рештою прикладів, але з префіксом `tri_lab_` для відокремлення.

### Чого ви навчитеся

- Описувати **лабораторну пару** (`tri_lab_account` + `tri_lab_audit`).
- Використовувати `DROP TABLE IF EXISTS`, щоб скрипт був **ідемпотентним** (придатним до повторного запуску).
- Чому важливий правильний порядок видалень, якщо є зовнішні ключі.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tri_lab_account` | `id`, `label`, `balance` |
| `tri_lab_audit` | `id`, `event`, `account_id`, `old_val`, `new_val`, `msg`, `ts` |

### Завдання

Видалити обидві таблиці, якщо існують, потім створити з InnoDB / `utf8mb4_0900_ai_ci`. `tri_lab_account.balance` за замовчуванням `0.00`; `tri_lab_audit.ts` — `CURRENT_TIMESTAMP`.

### Очікуваний результат

```text
Query OK, 0 rows affected
Query OK, 0 rows affected
```

(без таблиці-результату — лише DDL).

### Підказка

`DROP TABLE IF EXISTS tri_lab_audit;` **перед** `tri_lab_account` — дочірня першою, якби були FK. Потім два `CREATE TABLE`.

### Розв'язання

```sql
USE car_service_db;

DROP TABLE IF EXISTS tri_lab_audit;
DROP TABLE IF EXISTS tri_lab_account;

CREATE TABLE tri_lab_account (
  id       INT NOT NULL AUTO_INCREMENT,
  label    VARCHAR(80) NOT NULL,
  balance  DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE tri_lab_audit (
  id         INT NOT NULL AUTO_INCREMENT,
  event      VARCHAR(20) NOT NULL,
  account_id INT DEFAULT NULL,
  old_val    VARCHAR(200) DEFAULT NULL,
  new_val    VARCHAR(200) DEFAULT NULL,
  msg        VARCHAR(300) DEFAULT NULL,
  ts         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

### Покрокове пояснення

1. **`USE car_service_db`** тримає лабораторні таблиці поруч з рештою курсу. Вони мають чіткий префікс `tri_lab_`, тож їх легко відфільтрувати при прибиранні.
2. **`DROP TABLE IF EXISTS`** на початку робить скрипт **придатним до повторного запуску** під час практики. Видалення таблиці також видаляє її тригери — жодного «залишеного» тригера з попередньої спроби.
3. **`DECIMAL(12,2)` для грошей** — правильний тип; `FLOAT/DOUBLE` ввели б шум округлення.
4. **`tri_lab_audit.ts` default** — `CURRENT_TIMESTAMP`, тому з тригера не треба передавати позначку часу — InnoDB її проставить.
5. **InnoDB** обов'язковий для коректної транзакційності: якщо тригер кидає `SIGNAL`, оригінальний оператор у транзакції відкочується.

---

## Вправа T2 — `BEFORE INSERT`: відхиляти від'ємний баланс через `SIGNAL`

### Контекст

Бізнес-правило: баланс рахунку при створенні не може бути від'ємним. Хочемо, щоб **сама база** це гарантувала — навіть якщо хтось обійде шар застосунку.

### Чого ви навчитеся

- Синтаксис `CREATE TRIGGER … BEFORE INSERT … FOR EACH ROW`.
- Читання рядка-кандидата через **`NEW.column`**.
- Перерви оператора через **`SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT`**.
- Чому потрібен **танок з делімітерами** (`DELIMITER $$ … $$`) для багатооператорного тіла.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tri_lab_account` | `balance` (у `NEW`) |

### Завдання

Визначити `tri_lab_account_bi_check` — тригер `BEFORE INSERT` на `tri_lab_account`, який кидає SQLSTATE `45000` з повідомленням `'tri_lab_account: balance cannot be negative'`, коли `NEW.balance < 0`.

### Очікуваний результат

(без рядків — DDL). Перевіримо у Вправі T8 спробою `INSERT … (balance = -10.00)`.

### Підказка

Загорніть тіло у `DELIMITER $$ … END$$ DELIMITER ;`, щоб парсер не зашпортнувся на `;` усередині.

### Розв'язання

```sql
DELIMITER $$

CREATE TRIGGER tri_lab_account_bi_check
BEFORE INSERT ON tri_lab_account
FOR EACH ROW
BEGIN
  IF NEW.balance < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'tri_lab_account: balance cannot be negative';
  END IF;
END$$

DELIMITER ;
```

### Покрокове пояснення

1. **`BEFORE INSERT`** спрацьовує *до* того, як рядок потрапить у таблицю. Можна читати `NEW.*` і за потреби **модифікувати** його (наприклад, `SET NEW.balance = 0;`).
2. **`FOR EACH ROW`** обов'язковий у MySQL — тригер виконується раз на кожен порушений рядок. Масовий `INSERT … SELECT` на 1000 рядків запустить тіло 1000 разів.
3. **`NEW.balance`** — значення-кандидат. Рядка ще немає в сховищі, тому `OLD` тут немає.
4. **`SIGNAL SQLSTATE '45000'`** перериває оператор. Клас `45000` — стандартний «User-Defined Exception». Клієнт отримає `ERROR 1644 (45000)` з нашим `MESSAGE_TEXT`.
5. **`DELIMITER $$`** тимчасово змінює роздільник операторів у клієнті. Без нього перша `;` після `IF NEW.balance < 0 THEN` завершила б `CREATE TRIGGER`, і парсер видав би помилку.

---

## Вправа T3 — `AFTER INSERT`: записати рядок аудиту

### Контекст

Коли створюється новий рахунок, аудит має зафіксувати «хто, що, коли». З тригером **`AFTER INSERT`** ми пишемо у `tri_lab_audit` автоматично — застосунок не може «забути».

### Чого ви навчитеся

- Час спрацювання `AFTER INSERT` — спрацьовує, коли рядок уже безпечно в таблиці.
- Читання остаточного `NEW.*` для побудови запису аудиту.
- `CAST(… AS CHAR)` для розміщення чисел у колонці `VARCHAR`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tri_lab_account` (джерело `NEW.*`) | `id`, `label`, `balance` |
| `tri_lab_audit` (приймач) | `event`, `account_id`, `new_val`, `msg` |

### Завдання

Визначити `tri_lab_account_ai_log` — тригер `AFTER INSERT`, який пише один рядок у `tri_lab_audit` з `event = 'INSERT'`, `account_id = NEW.id`, `new_val = NEW.balance` (cast у `CHAR`) і `msg = 'created: ' || NEW.label`.

### Очікуваний результат

(без рядків від DDL). Після демо-`INSERT`ів у T7 у `tri_lab_audit` з'являться два нові рядки з `event = 'INSERT'`.

### Підказка

`CONCAT('created: ', NEW.label)` для повідомлення; `CAST(NEW.balance AS CHAR)` для `new_val`.

### Розв'язання

```sql
DELIMITER $$

CREATE TRIGGER tri_lab_account_ai_log
AFTER INSERT ON tri_lab_account
FOR EACH ROW
BEGIN
  INSERT INTO tri_lab_audit (event, account_id, new_val, msg)
  VALUES ('INSERT', NEW.id, CAST(NEW.balance AS CHAR), CONCAT('created: ', NEW.label));
END$$

DELIMITER ;
```

### Покрокове пояснення

1. **Чому `AFTER INSERT`?** На цьому етапі `NEW.id` має фінальне auto-increment значення. У `BEFORE INSERT` `NEW.id` був би `0` (або літерал, який ви передали).
2. **`event = 'INSERT'`** — довільна мітка; ми залишаємо `INSERT`, `UPDATE`, `DELETE` консистентними, щоб дашборди робили `GROUP BY event`.
3. **`CAST(NEW.balance AS CHAR)`** перетворює `DECIMAL(12,2)` у рядок, щоб помістити в `VARCHAR(200)` аудит-колонку. `CONVERT(NEW.balance, CHAR)` — еквівалент.
4. **`OLD` тут недоступний** — рядка раніше не існувало. `OLD.balance` дасть синтаксичну помилку.
5. **Тригер у транзакції:** `INSERT` у аудит — частина тієї ж транзакції, що й оригінальний `INSERT`. Якщо зовнішня транзакція відкочується, аудит-рядок теж зникає.

---

## Вправа T4 — `BEFORE UPDATE`: відхиляти від'ємний баланс при оновленні

### Контекст

Те саме правило поширюється на оновлення — аудит-команда впіймала молодшого розробника, який пушнув «фікс», що зробив баланс від'ємним. Потрібен тригер, який дзеркалить `BEFORE INSERT`-валідацію для `UPDATE`.

### Чого ви навчитеся

- Час спрацювання `BEFORE UPDATE` — до перезапису рядка.
- `NEW.column` — значення **після оновлення**; `OLD.column` — те, що замінюється.
- Як поширити правило на два тригери без копіпасту (порівняйте зі збереженою процедурою).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tri_lab_account` | `balance` (`OLD` і `NEW`) |

### Завдання

Визначити `tri_lab_account_bu_check` — тригер `BEFORE UPDATE`, що кидає `SQLSTATE '45000'` з повідомленням `'tri_lab_account: balance cannot be negative after update'`, коли новий баланс від'ємний.

### Очікуваний результат

(без рядків — DDL). Перевіримо так: `UPDATE tri_lab_account SET balance = -1 WHERE id = 1;` → `ERROR 1644`.

### Підказка

Те саме тіло, що в T2, але з `BEFORE UPDATE` і трохи іншим повідомленням.

### Розв'язання

```sql
DELIMITER $$

CREATE TRIGGER tri_lab_account_bu_check
BEFORE UPDATE ON tri_lab_account
FOR EACH ROW
BEGIN
  IF NEW.balance < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'tri_lab_account: balance cannot be negative after update';
  END IF;
END$$

DELIMITER ;
```

### Покрокове пояснення

1. **`BEFORE UPDATE`** дозволяє нам **заветувати** зміну. Порівняння `NEW.balance` з `0` достатньо; `OLD.balance` для цього правила неважливий.
2. **Тут також можна переписати `NEW.*`** (`SET NEW.balance = 0;`) — мовчки «обрізати» значення. Скрипт обрав суворий шлях: підняти `SIGNAL`.
3. **Чому не `CHECK`-обмеження?** MySQL 8.0.16+ підтримує `CHECK (balance >= 0)`. Тригер-варіант гнучкіший (своє повідомлення, динамічна логіка, аудит самої відмови), але простий `CHECK` легший, коли правило суто декларативне.
4. **Два майже однакові тригери (T2 + T4)** — типова ситуація; рефакторинг виніс би правило у збережену процедуру, яку викликали б обидва. Тут ми тримаємо їх окремо для наочності.

---

## Вправа T5 — `AFTER UPDATE`: аудит `OLD` проти `NEW`

### Контекст

Після успішного оновлення хочемо записати **що саме змінилося** — і `OLD.balance`, і `NEW.balance`, плюс попередній і новий `label`. Це класичний «diff»-рядок аудиту.

### Чого ви навчитеся

- Читання одночасно `OLD` і `NEW` у тригері `UPDATE`.
- Складання людино-читаного `msg` про зміну.
- Чому аудит-рядки часто типу `VARCHAR` — задля гнучкості.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tri_lab_account` | `id`, `label`, `balance` (обидва `OLD` і `NEW`) |
| `tri_lab_audit` | (приймач) |

### Завдання

Визначити `tri_lab_account_au_log` — тригер `AFTER UPDATE`, який вставляє рядок аудиту з `event = 'UPDATE'`, `account_id = NEW.id`, `old_val` і `new_val` з cast-значеннями `balance`, і `msg` виду `'label was: <OLD.label> -> <NEW.label>'`.

### Очікуваний результат

Після прикладу `UPDATE` у T7:

```text
| 3 | UPDATE |          1 | 250.00  | 200.00  | label was: Parts petty cash -> Parts petty cash (adjusted) | 2026-05-11 16:55:04 |
```

### Підказка

`CONCAT('label was: ', OLD.label, ' -> ', NEW.label)` для `msg`.

### Розв'язання

```sql
DELIMITER $$

CREATE TRIGGER tri_lab_account_au_log
AFTER UPDATE ON tri_lab_account
FOR EACH ROW
BEGIN
  INSERT INTO tri_lab_audit (event, account_id, old_val, new_val, msg)
  VALUES (
    'UPDATE',
    NEW.id,
    CAST(OLD.balance AS CHAR),
    CAST(NEW.balance AS CHAR),
    CONCAT('label was: ', OLD.label, ' -> ', NEW.label)
  );
END$$

DELIMITER ;
```

### Покрокове пояснення

1. **`OLD.balance` vs `NEW.balance`** — одна колонка, два значення. `OLD` — те, що було у сховищі; `NEW` — те, що тепер у сховищі (ми у `AFTER UPDATE`).
2. **`CAST(... AS CHAR)`** робить кожен аудит-рядок рядком, тож будь-який тип помістимо без зміни схеми. «Запит-зручний» дизайн мав би типізовані колонки (`old_balance DECIMAL`, `new_balance DECIMAL`).
3. **`account_id = NEW.id`** — так, `OLD.id` і `NEW.id` однакові, якщо ви не міняєте первинний ключ (зазвичай не міняють). `NEW.id` чіткіше каже намір — «поточний id».
4. **Без фільтра «змінилось чи ні»:** тригер спрацює, навіть якщо `UPDATE` фактично нічого не змінив (наприклад, `balance = balance`). Щоб логувати лише реальні зміни, оберніть тіло в `IF NEW.balance <> OLD.balance OR NEW.label <> OLD.label THEN … END IF;`.

---

## Вправа T6 — `AFTER DELETE`: аудит видалення через `OLD`

### Контекст

Коли рахунок видаляють, ми хочемо «надгробний камінь» у журналі аудиту — щоб знати, що зникло. Тригери `AFTER DELETE` бачать **лише `OLD.*`** — `NEW` не існує, бо рядок зник.

### Чого ви навчитеся

- Час спрацювання `AFTER DELETE` і контекст «тільки `OLD`».
- Використання мітки події `'DELETE'` в аудиті.
- Чому аудит-рядки «переживають» видалення (окрема таблиця, окремий час життя).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tri_lab_account` (джерело `OLD.*`) | `id`, `label`, `balance` |
| `tri_lab_audit` (приймач) | `event`, `account_id`, `old_val`, `msg` |

### Завдання

Визначити `tri_lab_account_ad_log` — тригер `AFTER DELETE`, що пише `event = 'DELETE'`, `account_id = OLD.id`, `old_val = OLD.balance`, `msg = 'removed: ' || OLD.label`.

### Очікуваний результат

Після прикладу `DELETE` у T7:

```text
| 4 | DELETE |          2 | 1200.50 | NULL    | removed: Tooling budget                                    | 2026-05-11 16:55:04 |
```

### Підказка

Доступний тільки `OLD.*` — посилання на `NEW.id` тут було б синтаксичною помилкою.

### Розв'язання

```sql
DELIMITER $$

CREATE TRIGGER tri_lab_account_ad_log
AFTER DELETE ON tri_lab_account
FOR EACH ROW
BEGIN
  INSERT INTO tri_lab_audit (event, account_id, old_val, msg)
  VALUES ('DELETE', OLD.id, CAST(OLD.balance AS CHAR), CONCAT('removed: ', OLD.label));
END$$

DELIMITER ;
```

### Покрокове пояснення

1. **`AFTER DELETE`** спрацьовує після того, як рядок зник. `OLD.*` (знімок видаленого) лишається — тому ми можемо записати втрачені дані.
2. **`new_val` залишаємо `NULL`** в аудит-рядку. У `DELETE` немає «після» — `NULL` тут конвенція.
3. **Аудит не каскадно видаляється.** Коли рядок №2 у `tri_lab_account` зникає, аудит-рядок з `account_id = 2` живе далі. Це і є сенс — аудит зберігає історію.
4. **Що якщо потім зробити `TRUNCATE`?** `TRUNCATE` **не** запускає row-level тригери (фактично дропає й перестворює таблицю). Якщо тригери мають спрацювати — використовуйте `DELETE FROM table`.

---

## Вправа T7 — Прогнати лабораторію і подивитися на аудит

### Контекст

Тригери встановлені — запустимо демо-дані: два `INSERT`и, один `UPDATE`, один `DELETE`, потім `SELECT` із аудиту. Це момент, коли вся «обв'язка» себе виправдовує — кожен DML породжує аудит-рядок.

### Чого ви навчитеся

- Що тригери спрацьовують **автоматично** — код застосунку взагалі не згадує `tri_lab_audit`.
- Читати аудит-трейл end-to-end: створення, мутацію, видалення.
- Підтвердити семантику `OLD`/`NEW` на конкретних рядках.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tri_lab_account` (мутуємо) | `label`, `balance` |
| `tri_lab_audit` (читаємо) | `id`, `event`, `account_id`, `old_val`, `new_val`, `msg`, `ts` |

### Завдання

Вставити два рахунки (`Parts petty cash` 250.00 і `Tooling budget` 1200.50). Оновити рахунок `id = 1`: `balance = balance − 50.00`, мітка `Parts petty cash (adjusted)`. Видалити рахунок `id = 2`. Потім `SELECT … FROM tri_lab_audit ORDER BY id`.

### Очікуваний результат

```text
+----+--------+------------+---------+---------+------------------------------------------------------------+---------------------+
| id | event  | account_id | old_val | new_val | msg                                                        | ts                  |
+----+--------+------------+---------+---------+------------------------------------------------------------+---------------------+
|  1 | INSERT |          1 | NULL    | 250.00  | created: Parts petty cash                                  | 2026-05-11 16:55:04 |
|  2 | INSERT |          2 | NULL    | 1200.50 | created: Tooling budget                                    | 2026-05-11 16:55:04 |
|  3 | UPDATE |          1 | 250.00  | 200.00  | label was: Parts petty cash -> Parts petty cash (adjusted) | 2026-05-11 16:55:04 |
|  4 | DELETE |          2 | 1200.50 | NULL    | removed: Tooling budget                                    | 2026-05-11 16:55:04 |
+----+--------+------------+---------+---------+------------------------------------------------------------+---------------------+
```

### Підказка

Запустіть DML, потім `SELECT id, event, account_id, old_val, new_val, msg, ts FROM tri_lab_audit ORDER BY id;`.

### Розв'язання

```sql
INSERT INTO tri_lab_account (label, balance) VALUES
  ('Parts petty cash', 250.00),
  ('Tooling budget', 1200.50);

UPDATE tri_lab_account
SET balance = balance - 50.00,
    label = 'Parts petty cash (adjusted)'
WHERE id = 1;

DELETE FROM tri_lab_account WHERE id = 2;

SELECT id, event, account_id, old_val, new_val, msg, ts
FROM tri_lab_audit
ORDER BY id;
```

### Покрокове пояснення

1. **Два `INSERT`и** → два аудит-рядки `INSERT`. `NEW.id` був `1` і `2` (auto-increment); `new_val` містить cast балансу; `old_val` = `NULL`, бо рядка раніше не існувало.
2. **Один `UPDATE`** → один аудит-рядок `UPDATE`. `old_val` = `250.00`, `new_val` = `200.00` (ми відняли `50.00`). `msg` фіксує зміну мітки.
3. **Один `DELETE`** → один аудит-рядок `DELETE`. `old_val` зберігає фінальний баланс перед видаленням. `new_val` = `NULL` — нічого не залишилось.
4. **`ts`** задається через `tri_lab_audit.ts DEFAULT CURRENT_TIMESTAMP`, не через тригер. Усі чотири рядки мають однакову секунду, бо скрипт швидкий.
5. **Auto-increment `tri_lab_audit.id`** дає природний порядок аудиту (`1, 2, 3, 4`). `ORDER BY id` робить вивід детермінованим.

---

## Вправа T8 — Перевірити `SIGNAL` (від'ємний `INSERT` має впасти)

### Контекст

Ми встановили валідаційні тригери — але аудит-команда повірить тільки тоді, коли ми **доведемо**, що вони реально відхиляють поганий рядок. У скрипті ця перевірка лежить як закоментований `INSERT`, щоб демо-прогон лишався чистим; розкоментуйте — побачите помилку.

### Чого ви навчитеся

- Як `SIGNAL` виглядає у клієнті (`ERROR 1644 (45000)`).
- Що тригер спрацьовує **до** запису — нічого не зміниться у `tri_lab_account`.
- Практичне підтвердження, що **`BEFORE INSERT`** не пускає погані дані.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `tri_lab_account` | `label`, `balance` |

### Завдання

Спробувати `INSERT INTO tri_lab_account (label, balance) VALUES ('Bad row', -10.00);` і подивитися на помилку. (Опціонально: перевірте через `SELECT COUNT(*) FROM tri_lab_account`, що нічого не змінилося.)

### Очікуваний результат

```text
ERROR 1644 (45000) at line 1: tri_lab_account: balance cannot be negative
```

### Підказка

Код помилки (`1644`) і SQLSTATE (`45000`) відповідають `SIGNAL`-у тригера. Текст збігається з `MESSAGE_TEXT`.

### Розв'язання

```sql
-- Цей INSERT має ВПАСТИ через SIGNAL (у скрипті закоментований):
INSERT INTO tri_lab_account (label, balance) VALUES ('Bad row', -10.00);
```

### Покрокове пояснення

1. **MySQL повертає `1644`** — внутрішній номер помилки для `SIGNAL`. `45000` — стандартний SQLSTATE-клас для користувацьких винятків.
2. **`INSERT` не виконується.** `BEFORE INSERT` спрацьовує до запису у сховище. Запустіть `SELECT COUNT(*) FROM tri_lab_account` і переконайтеся.
3. **Аудит-рядка теж немає.** Тригер `AFTER INSERT` не спрацював, бо операція провалилась — відхилений insert не лишає сліду в `tri_lab_audit`. Якщо хочете «аудит відмови» — логуйте явно **перед** `SIGNAL` (і пам'ятайте, що рядок відкотиться разом з транзакцією).
4. **Перехоплення у застосунку:** драйвери віддають це як `SQLException` (Java), `OperationalError` (Python) тощо. `MESSAGE_TEXT` зумисне зроблено читабельним.
5. **Прибирання:** щоб одночасно видалити лабораторні таблиці й тригери, розкоментуйте блок у кінці скрипта: `DROP TABLE IF EXISTS tri_lab_audit; DROP TABLE IF EXISTS tri_lab_account;`. Щоб видалити тільки тригер: `DROP TRIGGER IF EXISTS tri_lab_account_bi_check;` (імена мають збігатися точно).

---

## Розв'язання проблем

| Симптом | Що зробити |
|---|---|
| `You have an error in your SQL syntax …` біля `BEGIN`/`END` | Не перемкнули `DELIMITER $$` — парсер «з'їв» `;` усередині тіла тригера. |
| `Trigger already exists` | Попередній запуск лишив тригер. Перезапустіть скрипт (він робить `DROP` таблиць, разом з ними дропаються тригери) або зробіть `DROP TRIGGER IF EXISTS name;` руками. |
| Аудит-таблиця порожня | Раніший тригер кинув `SIGNAL` → весь оператор відкотився разом із `INSERT` у аудит. Перевірте `ERROR 1644`. |
| `ts` показує неправильний пояс | `CURRENT_TIMESTAMP` слідує за `@@session.time_zone`. `SET time_zone = '+00:00';` для UTC. |
| `TRUNCATE` не запустив тригери | `TRUNCATE` обходить row-level тригери — використовуйте `DELETE FROM table`. |

Щоб запустити **всі** приклади одразу: `mysql -t -u root car_service_db < 03_mysql/12_triggers/car_service_triggers_examples.sql`.
