# Цикли (loops) — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/15_cycles/cycles_car_service_db.md)

«Цикли» тут означають **повторне виконання** у MySQL двома взаємодоповнюючими способами:

1. **Процедурні цикли** всередині `CREATE PROCEDURE` — `WHILE`, `REPEAT … UNTIL` і помічений `LOOP … LEAVE` (збережені програми MySQL).
2. **Рекурсивний CTE** — `WITH RECURSIVE` (MySQL **8.0+**) для множинно-орієнтованої «ітерації» (числові ряди, дерева), що виконується як один декларативний запит, а не як цикл.

Вправи також охоплюють **курсорний цикл** — канонічний спосіб, у який процедура проходить набір результатів рядок за рядком.

Готові запити лежать у файлі-компаньйоні: [`15_cycles/car_service_cycles_examples.sql`](../../../../03_mysql/15_cycles/car_service_cycles_examples.sql).

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/15_cycles/car_service_cycles_examples.sql
```

Використовуйте клієнт **`mysql`** (а не GUI), щоб **`DELIMITER $$`** працював при `SOURCE` файлу.

---

## Шаблон вправи (повторюється у кожному розділі нижче)

| Секція | Що вона дає |
|---|---|
| **Контекст** | Навіщо реальній СТО ця процедура (1-2 речення). |
| **Чого ви навчитеся** | Які цикли тренує саме ця вправа. |
| **Задіяні таблиці** | Лише ті колонки, які насправді потрібні. |
| **Завдання** | Чіткі вимоги (сигнатура, тіло, як викликати). |
| **Очікуваний результат** | Справжній вивід з живого `CALL`. |
| **Підказка** | Один натяк на потрібне ключове слово/секцію. |
| **Розв'язання** | Робочий SQL, який можна вставити в `mysql`. |
| **Покрокове пояснення** | Що робить кожен рядок і які типові помилки. |

---

## Карта циклічних конструкцій (відповідає матеріалам курсу)

| Конструкція | Коли зупиняється | Нотатки |
|-------------|------------------|---------|
| **`WHILE cond DO … END WHILE`** | Умова перевіряється **на початку**. Може не виконатися жодного разу. | Класичний предтест-цикл. |
| **`REPEAT … UNTIL cond END REPEAT`** | Умова перевіряється **в кінці**. Тіло завжди виконується щонайменше один раз. | Посттест-цикл. |
| **`label: LOOP … END LOOP label`** | Лише через **`LEAVE label`** (break) — інакше нескінченний. **`ITERATE label`** перезапускає з верху. | Найгнучкіший; потребує явного виходу. |
| **`DECLARE cur CURSOR FOR …` + `FETCH` + `LEAVE`** | Коли курсор сигналізує `NOT FOUND` через continue-handler. | Спосіб, у який процедурний код обходить рядки. |
| **`WITH RECURSIVE name AS (anchor UNION ALL rec)`** | Коли рекурсивна частина повертає нуль нових рядків. | Декларативна; тільки **MySQL 8.0+**. |

Віддавайте перевагу **множинному** SQL, коли можливо; цикли — для процедурної логіки, малих батчів або навчання.

Сесійна змінна **`cte_max_recursion_depth`** обмежує кількість ітерацій рекурсивного CTE (за замовчуванням 1000). Підіймайте її явно, лише коли це справді потрібно.

---

## Спільна лабораторна таблиця

Усі чотири процедурні вправи пишуть у крихітну аудит-таблицю, створену скриптом:

```sql
CREATE TABLE cyc_log (
  id        INT NOT NULL AUTO_INCREMENT,
  kind      VARCHAR(20) NOT NULL,
  iteration INT NOT NULL,
  detail    VARCHAR(120) DEFAULT NULL,
  ts        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);
```

`TRUNCATE TABLE cyc_log;` перед кожним демо скидає `AUTO_INCREMENT`, тож наведений нижче вивід починається з `id = 1`.

---

## Вправа 1 — `WHILE … END WHILE` (предтест-цикл)

### Контекст

Нічна задача має вставити рівно *N* плейсхолдер-рядків аудиту («step 1», «step 2», …) перед запуском основного скрипта обслуговування. Цикл `WHILE` тут пасує природно: нуль або більше ітерацій, керованих параметром від планувальника.

### Чого ви навчитеся

- Форма **предтест-циклу**: `WHILE condition DO … END WHILE`.
- Поєднання `DECLARE` + `SET` + `INSERT` у тілі процедури.
- Чому `WHILE` може виконатися **нуль** разів (умова хибна вже на першій перевірці).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `cyc_log` | `id`, `kind`, `iteration`, `detail` |

### Завдання

1. Визначити `sp_cyc_while_demo(IN p_times INT)`.
2. Оголосити локальний лічильник `i`, ініціалізований нулем.
3. Поки `i < p_times`, інкрементувати `i` і `INSERT INTO cyc_log (kind, iteration, detail) VALUES ('WHILE', i, CONCAT('step ', i))`.
4. Викликати з `p_times = 4` і переконатися, що в `cyc_log` лежить 4 рядки.

### Очікуваний результат (`TRUNCATE cyc_log; CALL sp_cyc_while_demo(4);` потім `SELECT * FROM cyc_log`)

```text
+----+-------+-----------+--------+
| id | kind  | iteration | detail |
+----+-------+-----------+--------+
|  1 | WHILE |         1 | step 1 |
|  2 | WHILE |         2 | step 2 |
|  3 | WHILE |         3 | step 3 |
|  4 | WHILE |         4 | step 4 |
+----+-------+-----------+--------+
```

### Підказка

`WHILE i < p_times DO ... END WHILE;` — інкремент **усередині** тіла, інакше зациклюється назавжди.

### Розв'язання

```sql
DROP PROCEDURE IF EXISTS sp_cyc_while_demo;

DELIMITER $$

CREATE PROCEDURE sp_cyc_while_demo(IN p_times INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  WHILE i < p_times DO
    SET i = i + 1;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('WHILE', i, CONCAT('step ', i));
  END WHILE;
END$$

DELIMITER ;

TRUNCATE TABLE cyc_log;
CALL sp_cyc_while_demo(4);
SELECT id, kind, iteration, detail FROM cyc_log ORDER BY id;
```

### Покрокове пояснення

1. **`DECLARE i INT DEFAULT 0`** уводить лічильник циклу. Усі оголошення мають іти на початку `BEGIN … END`.
2. **`WHILE i < p_times DO`** обчислює умову **перед** кожною ітерацією. Якщо `p_times = 0`, тіло жодного разу не виконається.
3. **`SET i = i + 1`** — невід'ємний інкремент. Забути про нього — це №1 спосіб зависити з'єднання. Ставте інкремент **на початку**, коли `id`/ітерація починається з `1`; **в кінці** — коли з `0`.
4. **`INSERT … VALUES ('WHILE', i, …)`** пише по одному рядку аудиту на ітерацію. Те саме з'єднання може прочитати ці рядки одразу після.
5. **`END WHILE`** закриває цикл. Усередині `WHILE` немає ключового слова `BREAK`; якщо потрібен ранній вихід, оберніть цикл у помічений `LOOP` і використовуйте `LEAVE` (Вправа 3).

---

## Вправа 2 — `REPEAT … UNTIL` (посттест-цикл)

### Контекст

Технічна задача має виконати дію щонайменше раз і **потім** вирішити, чи продовжувати. `REPEAT … UNTIL` відповідає цьому в точності: тіло виконується першим, умова виходу — після.

### Чого ви навчитеся

- Форма **посттест-циклу**: `REPEAT … UNTIL cond END REPEAT`.
- Чому тіло `REPEAT` завжди виконується принаймні раз.
- Інвертована семантика `UNTIL` порівняно з `WHILE` (виходить, коли умова стає **true**).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `cyc_log` | `id`, `kind`, `iteration`, `detail` |

### Завдання

1. Визначити `sp_cyc_repeat_demo()` (без параметрів).
2. Оголосити лічильник `j`, ініціалізований нулем.
3. У циклі `REPEAT`: інкрементувати `j`, вставити рядок `('REPEAT', j, 'repeat step j')`. Вихід коли `j >= 3`.
4. Перевірити, що вставлено три рядки.

### Очікуваний результат (`TRUNCATE cyc_log; CALL sp_cyc_repeat_demo();`)

```text
+----+--------+-----------+---------------+
| id | kind   | iteration | detail        |
+----+--------+-----------+---------------+
|  1 | REPEAT |         1 | repeat step 1 |
|  2 | REPEAT |         2 | repeat step 2 |
|  3 | REPEAT |         3 | repeat step 3 |
+----+--------+-----------+---------------+
```

### Підказка

`UNTIL j >= 3` — цикл **зупиняється**, коли умова стає істинною — навпаки до `WHILE`.

### Розв'язання

```sql
DROP PROCEDURE IF EXISTS sp_cyc_repeat_demo;

DELIMITER $$

CREATE PROCEDURE sp_cyc_repeat_demo()
BEGIN
  DECLARE j INT DEFAULT 0;
  REPEAT
    SET j = j + 1;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('REPEAT', j, CONCAT('repeat step ', j));
  UNTIL j >= 3
  END REPEAT;
END$$

DELIMITER ;

TRUNCATE TABLE cyc_log;
CALL sp_cyc_repeat_demo();
SELECT id, kind, iteration, detail FROM cyc_log ORDER BY id;
```

### Покрокове пояснення

1. **`REPEAT … UNTIL … END REPEAT`** — дуальник `WHILE`. Тіло виконується, **потім** перевіряється `UNTIL`. Якщо `UNTIL` істинне, цикл виходить.
2. **Гарантія «принаймні раз».** Навіть якщо умова виходу вже виконана (напр., лічильник стартує з `99`), тіло виконується **один раз** до перевірки. Корисно, коли треба виконати дію і лише після неї вирішити, чи повторювати.
3. **`UNTIL j >= 3`** — між `UNTIL` і `END REPEAT` немає крапки з комою. Це часта одрука. Граматика рівно `UNTIL cond END REPEAT`.
4. **Три рядки** в `cyc_log`, бо тіло виконалось при `j = 1, 2, 3`; при `j = 3` спрацьовує посттест і цикл закінчується.
5. **Увага:** якщо забути `SET j = j + 1`, `UNTIL j >= 3` ніколи не стане істинною і цикл крутитиметься нескінченно. Та сама гігієна, що й для `WHILE`.

---

## Вправа 3 — `LOOP` + `LEAVE` (помічений break)

### Контекст

Інколи умова виходу — це не охайна перевірка «while» зверху чи «until» знизу, а живе посеред тіла. Комбінація **помічений `LOOP` + `LEAVE label`** дає структурований `break`: цикл безумовний, єдиний шлях виходу — явний `LEAVE`.

### Чого ви навчитеся

- Синтаксис **поміченого** `LOOP … END LOOP label`.
- Використання **`LEAVE label`** як структурованого `break`.
- (Опційно) **`ITERATE label`** для перезапуску тіла циклу («skip to next»).

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `cyc_log` | `id`, `kind`, `iteration`, `detail` |

### Завдання

1. Визначити `sp_cyc_loop_leave_demo()`.
2. Оголосити лічильник `k`, ініціалізований нулем.
3. У `cyc_loop: LOOP` інкрементувати `k`. Якщо `k > 4`, `LEAVE cyc_loop`. Інакше вставити `('LOOP', k, 'loop step k')`.
4. Перевірити, що в `cyc_log` чотири рядки `LOOP`.

### Очікуваний результат (`TRUNCATE cyc_log; CALL sp_cyc_loop_leave_demo();`)

```text
+----+------+-----------+-------------+
| id | kind | iteration | detail      |
+----+------+-----------+-------------+
|  1 | LOOP |         1 | loop step 1 |
|  2 | LOOP |         2 | loop step 2 |
|  3 | LOOP |         3 | loop step 3 |
|  4 | LOOP |         4 | loop step 4 |
+----+------+-----------+-------------+
```

### Підказка

Спочатку інкремент, далі тест виходу, в кінці вставка — щоб `k = 5` ніколи не дійшло до `INSERT`.

### Розв'язання

```sql
DROP PROCEDURE IF EXISTS sp_cyc_loop_leave_demo;

DELIMITER $$

CREATE PROCEDURE sp_cyc_loop_leave_demo()
BEGIN
  DECLARE k INT DEFAULT 0;
  cyc_loop: LOOP
    SET k = k + 1;
    IF k > 4 THEN
      LEAVE cyc_loop;
    END IF;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('LOOP', k, CONCAT('loop step ', k));
  END LOOP cyc_loop;
END$$

DELIMITER ;

TRUNCATE TABLE cyc_log;
CALL sp_cyc_loop_leave_demo();
SELECT id, kind, iteration, detail FROM cyc_log ORDER BY id;
```

### Покрокове пояснення

1. **`cyc_loop:`** — мітка. Імена слідують правилам ідентифікаторів; `cyc_loop` та `END LOOP cyc_loop` мають точно збігатися.
2. **`LOOP … END LOOP`** — єдина з трьох конструкцій, що **не має вбудованої умови виходу.** Потрібен `LEAVE` (або підняття помилки) — інакше цикл нескінченний.
3. **`IF k > 4 THEN LEAVE cyc_loop; END IF;`** — структурований break. Без аргумента-мітки `LEAVE` не знав би, з якого циклу виходити (цикли можна вкладати).
4. **`ITERATE cyc_loop`** (тут не використано, але варто знати) переходить на верх поміченого циклу, пропускаючи решту ітерації — це `continue` у C-подібних мовах.
5. **Порядок важливий.** Інкремент іде перед тестом, тест — перед вставкою, тож зберігаються лише ітерації `k = 1..4`; ітерація `k = 5` — це ітерація виходу.

---

## Вправа 4 — Курсорний цикл по набору результатів

### Контекст

Найпоширеніший процедурний патерн у MySQL: збережена процедура має пройти набір результатів рядок за рядком (щоб викликати функцію, залогувати кожен рядок чи переписати дані в іншу таблицю). MySQL реалізує це через **`DECLARE CURSOR`**, **`OPEN` / `FETCH` / `CLOSE`** та **`CONTINUE HANDLER FOR NOT FOUND`**, що перемикає прапорець, коли в курсорі закінчуються рядки.

### Чого ви навчитеся

- Оголошувати курсор над обмеженим запитом.
- Обов'язковий патерн **`CONTINUE HANDLER FOR NOT FOUND SET done = 1;`**.
- Скелет `OPEN cur → FETCH cur INTO … → LEAVE`.
- Чому важливий порядок оголошень: змінні → курсор → handler.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `work_orders` | `id`, `total_cost` |
| `cyc_log` | `id`, `kind`, `iteration`, `detail` |

### Завдання

1. Визначити `sp_cyc_cursor_wo()` (без параметрів).
2. Оголосити локальні `done INT DEFAULT 0`, `v_id INT`, `v_cost DECIMAL(12,2)`.
3. Оголосити курсор `cur` над `SELECT id, total_cost FROM work_orders WHERE id BETWEEN 1 AND 30 ORDER BY id LIMIT 5`.
4. Оголосити `CONTINUE HANDLER FOR NOT FOUND SET done = 1;`.
5. `OPEN cur`, далі в поміченому циклі `FETCH cur INTO v_id, v_cost`. Якщо `done = 1`, `LEAVE`. Інакше вставити `('CURSOR', v_id, CONCAT('total_cost=', v_cost))`. Закрити курсор.

### Очікуваний результат (`TRUNCATE cyc_log; CALL sp_cyc_cursor_wo();`)

```text
+----+--------+-----------+-------------------+
| id | kind   | iteration | detail            |
+----+--------+-----------+-------------------+
|  1 | CURSOR |         1 | total_cost=500.10 |
|  2 | CURSOR |         2 | total_cost=500.20 |
|  3 | CURSOR |         3 | total_cost=500.30 |
|  4 | CURSOR |         4 | total_cost=500.40 |
|  5 | CURSOR |         5 | total_cost=500.50 |
+----+--------+-----------+-------------------+
```

### Підказка

Оголошуйте в точно такому порядку: змінні → курсор → handler. Зворотний порядок — і MySQL відхилить процедуру.

### Розв'язання

```sql
DROP PROCEDURE IF EXISTS sp_cyc_cursor_wo;

DELIMITER $$

CREATE PROCEDURE sp_cyc_cursor_wo()
BEGIN
  DECLARE done   INT DEFAULT 0;
  DECLARE v_id   INT;
  DECLARE v_cost DECIMAL(12,2);
  DECLARE cur CURSOR FOR
    SELECT id, total_cost
    FROM work_orders
    WHERE id BETWEEN 1 AND 30
    ORDER BY id
    LIMIT 5;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN cur;
  read_rows: LOOP
    FETCH cur INTO v_id, v_cost;
    IF done = 1 THEN
      LEAVE read_rows;
    END IF;
    INSERT INTO cyc_log (kind, iteration, detail)
    VALUES ('CURSOR', v_id, CONCAT('total_cost=', v_cost));
  END LOOP read_rows;
  CLOSE cur;
END$$

DELIMITER ;

TRUNCATE TABLE cyc_log;
CALL sp_cyc_cursor_wo();
SELECT id, kind, iteration, detail FROM cyc_log ORDER BY id;
```

### Покрокове пояснення

1. **Порядок оголошень фіксований граматикою:** спочатку локальні змінні, потім курсори, потім handler-и, потім будь-яка виконувана інструкція. Поміняєте — отримаєте *"Variable declaration must precede cursor declaration"*.
2. **`DECLARE cur CURSOR FOR <SELECT …>`** прив'язує курсор до конкретного запиту; запит не виконується до `OPEN cur`.
3. **`DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;`** — магічний рядок. Коли `FETCH` лишається без рядків, MySQL піднімає умову `NOT FOUND`; handler її ловить, ставить `done = 1` і дає виконанню продовжитися (замість того, щоб упасти).
4. **`OPEN cur` / `FETCH cur INTO v_id, v_cost`** — `FETCH` копіює наступний рядок у вказані змінні. Якщо рядка немає, спрацьовує handler і `done` стає `1`.
5. **`IF done = 1 THEN LEAVE read_rows; END IF;`** — увага: перевіряйте прапорець **одразу після** `FETCH`, до будь-якої роботи зі значеннями. Інакше остання ітерація використає застарілі значення змінних.
6. **`CLOSE cur`** звільняє курсор. Формально MySQL закриває його автоматично в кінці процедури, але явний `CLOSE` — це гарна гігієна.

---

## Вправа 5 — `WITH RECURSIVE` (CTE, MySQL 8.0+)

### Контекст

Потрібен числовий ряд `1..N`, щоб згодувати графіку, згенерувати тестові дані чи зробити join з іншою таблицею для «fill-gaps». Замість циклу в процедурі MySQL 8.0 дозволяє виразити ітерацію **декларативно** через рекурсивний CTE — один запит, який планувальник може оптимізувати.

### Чого ви навчитеся

- Форма рекурсивного CTE: **anchor `UNION ALL` recursive part**.
- Чому рекурсивна частина має посилатися на ім'я CTE, щоб «рекурсувати».
- Роль `cte_max_recursion_depth` як запобіжника.

### Задіяні таблиці

Жодної — CTE генерує рядки з нічого.

### Завдання

Написати одну інструкцію (без процедури), що дає `n = 1..12`. Використати рекурсивний CTE з ім'ям `seq(n)`.

### Очікуваний результат

```text
+------+
| n    |
+------+
|    1 |
|    2 |
|    3 |
|    4 |
|    5 |
|    6 |
|    7 |
|    8 |
|    9 |
|   10 |
|   11 |
|   12 |
+------+
```

### Підказка

`WITH RECURSIVE seq(n) AS ( SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 12 ) SELECT n FROM seq;`

### Розв'язання

```sql
WITH RECURSIVE seq(n) AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 12
)
SELECT n FROM seq;
```

### Покрокове пояснення

1. **`WITH RECURSIVE name(col_list) AS ( … )`** уводить іменований, потенційно самопосилковий підзапит. Без ключового слова `RECURSIVE` MySQL відхилив би саме-посилання.
2. **Anchor:** `SELECT 1 AS n` дає перший рядок. Anchor мусить завершуватися (без рекурсивного посилання) — це базовий випадок.
3. **Рекурсивна частина:** `SELECT n + 1 FROM seq WHERE n < 12` читає з `seq` (наразі) і видає наступний рядок. `WHERE n < 12` — це **умова завершення**: коли вона повертає нуль рядків, рекурсія зупиняється.
4. **`UNION ALL` обов'язковий.** `UNION` (який дедуплікує) заборонений у рекурсивних CTE MySQL.
5. **Запобіжник:** сесійна змінна `cte_max_recursion_depth` (за замовчуванням 1000) обмежує кількість рекурсивних кроків. Якщо треба більше — підіймайте явно: `SET SESSION cte_max_recursion_depth = 10000;`.
6. **Чому це краще, ніж процедурний цикл?** Це одна SQL-інструкція: оптимізатор бачить її цілою, немає клієнтських round-trip-ів на рядок, немає допоміжної `cyc_log` — і вона композується всередині будь-якого іншого запиту.

---

## Усунення проблем: мій цикл не завершується (або не запускається)

| Симптом | Імовірне виправлення |
|---|---|
| З'єднання зависає після `CALL` | Забули інкремент усередині `WHILE` / `REPEAT` / `LOOP`. Уб'єте сесію і додайте `SET i = i + 1;`. |
| Тіло `WHILE` ніколи не виконується | Початкова умова вже хибна (напр., `p_times = 0`). Використайте `REPEAT`, якщо потрібно «принаймні раз». |
| `Variable declaration must precede cursor declaration` | Переставте оголошення: змінні → курсор → handler. |
| Останній рядок обробляється двічі (курсор) | Ви перевіряєте `done` **до** `FETCH`, а не одразу після. |
| `Cursor is not open` на `FETCH` | Немає `OPEN cur;` перед `FETCH` або handler проковтнув помилку під час `OPEN`. |
| `Recursive CTE: max recursion …` | Досягли `cte_max_recursion_depth`. Затягніть умову завершення або `SET SESSION cte_max_recursion_depth = N;`. |
| `UNION` заборонено в рекурсивному CTE | Замініть на `UNION ALL`. |

Щоб запустити **всі** приклади одразу: `mysql -t -u root car_service_db < 03_mysql/15_cycles/car_service_cycles_examples.sql`.
