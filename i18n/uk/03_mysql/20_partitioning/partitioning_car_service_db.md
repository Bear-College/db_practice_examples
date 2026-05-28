# Розбиття на частини в реляційних базах даних — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/20_partitioning/partitioning_car_service_db.md)

Урок про **секціонування (partitioning)** таблиць у MySQL: одна логічна таблиця — кілька **фізичних розділів**, щоб запити з ключем секції **відсікали** зайві частини. Створите таблицю `RANGE` по `id`, переглянете метадані та `EXPLAIN`.

Готовий скрипт: [`20_partitioning/car_service_partitioning_examples.sql`](../../../../03_mysql/20_partitioning/car_service_partitioning_examples.sql).

```bash
mysql -u root car_service_db < 03_mysql/20_partitioning/car_service_partitioning_examples.sql
```

**Вимоги:** MySQL **8.0+**, InnoDB.

---

## Поняття секціонування

| Термін | Зміст |
|--------|--------|
| **Розділ (partition)** | Підмножина рядків (`p_low`, `p_mid`, …) |
| **Ключ секції** | Стовпець у `PARTITION BY` (`id`) |
| **Partition pruning** | Оптимізатор пропускає нерелевантні розділи |
| **RANGE** | Рядок потрапляє в розділ, де ключ `<` межі |
| **MAXVALUE** | «Хвіст» для всіх більших значень |

Секціонування **не замінює** індекси — доповнює їх для дуже великих таблиць і архівації (`DROP PARTITION`).

---

## Вправа 1 — Таблиця з RANGE-секціями

### Контекст

Історія замовлень розбита за діапазонами `id` — звіти по «свіжих» id читають менше розділів.

### Завдання

Створити `part_wo_lab` з 4 RANGE-розділами; завантажити `work_orders` з `id 1–25000`; показати `COUNT(*)`.

### Очікуваний результат

```text
| total_rows |
|      25000 |
```

### Розв'язання

```sql
CREATE TABLE part_wo_lab (
  id INT NOT NULL,
  status VARCHAR(20) NOT NULL,
  total_cost DECIMAL(10, 2) NOT NULL,
  PRIMARY KEY (id, status)
) ENGINE=InnoDB
PARTITION BY RANGE (id) (
  PARTITION p_low    VALUES LESS THAN (10001),
  PARTITION p_mid    VALUES LESS THAN (20001),
  PARTITION p_high   VALUES LESS THAN (30001),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

INSERT INTO part_wo_lab (id, status, total_cost)
SELECT wo.id, wo.status, wo.total_cost
FROM work_orders AS wo
WHERE wo.id BETWEEN 1 AND 25000;

SELECT COUNT(*) AS total_rows FROM part_wo_lab;
```

### Покрокове пояснення

1. Кожен рядок потрапляє в один розділ за значенням `id`.
2. PK має включати ключ секції (`id`).
3. Додаток зазвичай не вказує ім’я розділу в SQL.

---

## Вправа 2 — Partition pruning в EXPLAIN

### Контекст

Запит `id BETWEEN 15000 AND 15010` має торкатися переважно `p_mid`, не всієї таблиці.

### Завдання

`EXPLAIN` для діапазонів `15000–15010` та `500–510`.

### Очікуваний результат

```text
-> Index range scan ... over (15000 <= id <= 15010)
-> Index range scan ... over (500 <= id <= 510)
```

### Розв'язання

```sql
EXPLAIN SELECT id, status, total_cost FROM part_wo_lab WHERE id BETWEEN 15000 AND 15010;
EXPLAIN SELECT id, status, total_cost FROM part_wo_lab WHERE id BETWEEN 500 AND 510;
```

### Покрокове пояснення

1. Без предиката на ключ секції pruning не працює.
2. У табличному `EXPLAIN` дивіться колонку `partitions`.

---

## Вправа 3 — Метадані розділів

### Контекст

DBA перевіряє розподіл рядків перед `ADD PARTITION`.

### Завдання

Вибірка з `information_schema.partitions` для `part_wo_lab`.

### Очікуваний результат

```text
| PARTITION_NAME | TABLE_ROWS | PARTITION_DESCRIPTION |
| p_low          |      10000 | 10001                 |
| p_mid          |      10000 | 20001                 |
| p_high         |       5000 | 30001                 |
| p_future       |          0 | MAXVALUE              |
```

### Розв'язання

```sql
SELECT partition_name, table_rows, partition_description
FROM information_schema.partitions
WHERE table_schema = 'car_service_db'
  AND table_name = 'part_wo_lab'
  AND partition_name IS NOT NULL
ORDER BY partition_ordinal_position;
```

---

## Вправа 4 — Агрегація в межах одного діапазону id

### Контекст

Виручка за статусом лише для замовлень `id` 10k–20k — pruning на `p_mid`.

### Завдання

`GROUP BY status` для `id BETWEEN 10000 AND 19999`.

### Очікуваний результат

```text
| status        | cnt  | revenue    |
| completed     | 2000 | 4000300.00 |
| ...           |      |            |
```

### Розв'язання

```sql
SELECT status,
       COUNT(*) AS cnt,
       ROUND(SUM(total_cost), 2) AS revenue
FROM part_wo_lab
WHERE id BETWEEN 10000 AND 19999
GROUP BY status
ORDER BY revenue DESC;
```

### Покрокове пояснення

1. Індекси працюють **всередині** кожного розділу.
2. Якщо у `WHERE` немає ключа секції — секціонування мало допомагає.
3. `DROP PARTITION` швидше за масовий `DELETE` для архіву.

---

## Пов’язані уроки

- [`08_indexes/`](../../../03_mysql/08_indexes/)
- [`19_indexing/`](../../../03_mysql/19_indexing/)
- [`18_data_warehouse/`](../../../03_mysql/18_data_warehouse/)
