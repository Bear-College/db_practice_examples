# Індексація в реляційних базах даних — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/19_indexing/indexing_car_service_db.md)

Урок про **стратегію індексації**: кардинальність, **лівий префікс** складених індексів, **покривні** індекси, коли оптимізатор ігнорує індекс. Практику створення B-tree, UNIQUE, FULLTEXT див. у [`08_indexes/`](../../../03_mysql/08_indexes/).

Готовий скрипт: [`19_indexing/car_service_indexing_examples.sql`](../../../../03_mysql/19_indexing/car_service_indexing_examples.sql).

```bash
mysql -u root car_service_db < 03_mysql/19_indexing/car_service_indexing_examples.sql
```

---

## Поняття індексації

| Поняття | Зміст |
|---------|--------|
| **Селективність** | Частка рядків, що відповідають умові |
| **Кардинальність** | Кількість унікальних значень (`SHOW INDEX`, `information_schema`) |
| **Лівий префікс** | Індекс `(a,b,c)` підтримує `WHERE a`, `WHERE a AND b`, не `WHERE b` окремо |
| **Покривний індекс** | Усі стовпці `SELECT` в індексі → `Using index` / Covering index |
| **Обслуговування** | `ANALYZE TABLE` після масового завантаження |

---

## Вправа 1 — Перегляд індексів і кардинальності

### Контекст

Перед новим індексом DBA перевіряє наявні індекси та статистику.

### Завдання

Після створення `idx_design_lab` — `SHOW INDEX` і вибірка з `information_schema.statistics`.

### Очікуваний результат

```text
| INDEX_NAME | COLUMN_NAME | CARDINALITY |
| ix_ref     | ref_num     |           1 |
| ix_status  | status      |           1 |
| PRIMARY    | id          |           1 |
```

### Розв'язання

```sql
SHOW INDEX FROM idx_design_lab;

SELECT index_name, column_name, cardinality, seq_in_index
FROM information_schema.statistics
WHERE table_schema = 'car_service_db'
  AND table_name = 'idx_design_lab'
ORDER BY index_name, seq_in_index;
```

### Покрокове пояснення

1. Кардинальність — оцінка для вибору плану.
2. Після bulk insert потрібен `ANALYZE TABLE`.
3. Уникайте дубльованих індексів на тому самому префіксі.

---

## Вправа 2 — Складений індекс і лівий префікс

### Контекст

Фільтр `status = 'open' AND ref_num BETWEEN …` — індекс `(status, ref_num, total_cost)`.

### Завдання

Створити індекс і `EXPLAIN` запиту з обома умовами.

### Очікуваний результат

```text
-> Covering index range scan ... using ix_status_ref_cost
   over (status = 'open' AND 5000 <= ref_num <= 5010)
```

### Розв'язання

```sql
CREATE INDEX ix_status_ref_cost ON idx_design_lab (status, ref_num, total_cost);

EXPLAIN
SELECT status, ref_num, total_cost
FROM idx_design_lab
WHERE status = 'open'
  AND ref_num BETWEEN 5000 AND 5010;
```

### Покрокове пояснення

1. Рівність на `status`, діапазон на `ref_num`.
2. Лише `ref_num` не використає цей складений індекс ефективно.

---

## Вправа 3 — Покривний індекс

### Контекст

Якщо `SELECT` бере лише стовпці з індексу — читання лише B-tree індексу.

### Завдання

`EXPLAIN SELECT ref_num, total_cost …` з тими самими умовами.

### Очікуваний результат

Covering index range scan на `ix_status_ref_cost`.

### Розв'язання

```sql
EXPLAIN
SELECT ref_num, total_cost
FROM idx_design_lab
WHERE status = 'open'
  AND ref_num BETWEEN 5000 AND 5010;
```

### Покрокове пояснення

1. Менше випадкових читань кластерного PK.
2. Ширший індекс — більше місця на диску, повільніші записи.

---

## Вправа 4 — Низька селективність і ANALYZE

### Контекст

У лабораторії всі рядки `status = 'open'` — індекс на `status` малокорисний.

### Завдання

`EXPLAIN … WHERE status = 'open' LIMIT 20`, потім `ANALYZE TABLE`.

### Розв'язання

```sql
EXPLAIN
SELECT id, sku
FROM idx_design_lab
WHERE status = 'open'
LIMIT 20;

ANALYZE TABLE idx_design_lab;
```

### Покрокове пояснення

1. На великих таблицях оптимізатор може обрати full scan.
2. Додайте селективніший предикат (`ref_num`) або змініть модель даних.

---

## Пов’язані уроки

- [`08_indexes/`](../../../03_mysql/08_indexes/) — типи індексів hands-on.
- [`20_partitioning/`](../../../03_mysql/20_partitioning/) — секціонування.
