# Агрегаційні функції з Motor (`10_odm/04_agregation_functions`)

> Translation / Переклад: [English](../../../../../04_mongodb/10_odm/04_agregation_functions/agregation_functions_motor.md)

Ці вправи проходять **аґреґаційний фреймворк MongoDB** з callsite на Motor (async). Скрипт-компаньйон запускає два конвеєри, що разом задіюють вісім найбільш уживаних стадій: `$match`, `$group`, `$sum`, `$avg`, `$count`, `$max`, `$min`, `$sort`, `$project`.

Готовий файл-компаньйон: [`10_odm/04_agregation_functions/main.py`](../../../../../04_mongodb/10_odm/04_agregation_functions/main.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/04_agregation_functions/main.py
```

З'єднання за замовчуванням (можна перевизначити змінними оточення):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Колекція: `odm_aggregation_orders`

---

## Колекція: `odm_aggregation_orders`

Сід вставляє шість замовлень чотирьох клієнтів і трьох категорій:

| `order_id` | `customer` | `category` | `amount` | `quantity` |
|---|---|---|---|---|
| ORD-001 | Anna | Laptop | 1200 | 1 |
| ORD-002 | Anna | Laptop | 900 | 1 |
| ORD-003 | Bohdan | Smartphone | 800 | 2 |
| ORD-004 | Chris | Smartphone | 700 | 1 |
| ORD-005 | Daria | Tablet | 500 | 3 |
| ORD-006 | Daria | Tablet | 450 | 1 |

Раннер:

```python
async def run_pipeline(coll, title, pipeline):
    docs = await coll.aggregate(pipeline).to_list(length=100)
    print(f"\n{title}")
    for d in docs:
        print(f"  {d}")
```

---

## Шаблон вправи (повторюється в кожному розділі нижче)

| Секція | Що дає |
|---|---|
| **Контекст** | Який бізнес-звіт обслуговує цей конвеєр. |
| **Чого ви навчитеся** | Які стадії та акумулятори тренуються. |
| **Колекція** | Поля, що задіяні. |
| **Завдання** | Пронумерований список стадій конвеєра. |
| **Очікуваний результат** | Реальний вивід `python main.py`. |
| **Підказка** | Жменька `$`-операторів. |
| **Розв'язання** | Версії Motor (Python) і `mongosh` поряд. |
| **Покрокове пояснення** | Що робить кожна стадія і типові помилки. |

---

## Вправа 1 — Виручка за категорією (`$match → $group → $sort → $project`)

### Контекст

Фінансовій команді потрібен «one-shot» звіт по категоріях для замовлень понад $400: скільки замовлень, сумарна виручка, середній чек, найменше і найбільше замовлення в кожній категорії, відсортовано за виручкою.

### Чого ви навчитеся

- Фільтрувати до групування через `$match` (аналог SQL `WHERE`).
- Групувати `$group`, акумулювати `$sum`, `$avg`, `$count`, `$max`, `$min`.
- Сортувати групи `$sort` (аналог `ORDER BY`).
- Переформовувати вивід через `$project` (аналог `SELECT`).

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `category` | string | Ключ групування. |
| `amount` | int | Акумулюємо. |

### Завдання

Збудувати конвеєр:

1. **`$match`** — лишити замовлення з `amount >= 400`.
2. **`$group`** — групувати за `$category`; акумулятори `total_revenue` (`$sum $amount`), `avg_revenue` (`$avg $amount`), `orders_count` (`$count`), `max_order` (`$max $amount`), `min_order` (`$min $amount`).
3. **`$sort`** — за `total_revenue` спаданням.
4. **`$project`** — перейменувати `_id` у `category`, прибрати оригінальний `_id`.

### Очікуваний результат

```text
Revenue by category ($match + $group + $sum + $count + $avg + $max/$min + $sort + $project)
  {'total_revenue': 2100, 'avg_revenue': 1050.0, 'orders_count': 2, 'max_order': 1200, 'min_order': 900, 'category': 'Laptop'}
  {'total_revenue': 1500, 'avg_revenue': 750.0, 'orders_count': 2, 'max_order': 800, 'min_order': 700, 'category': 'Smartphone'}
  {'total_revenue': 950, 'avg_revenue': 475.0, 'orders_count': 2, 'max_order': 500, 'min_order': 450, 'category': 'Tablet'}
```

Laptop очолює $2100. Усі шість замовлень потрапили (найменше — $450, що ≥ 400), тож звіт охоплює весь набір.

### Підказка

Всередині `$group` нове поле `_id` — це ключ групування. Записуйте його як `"$category"` (це *field path*), а не `"category"`. Кожен акумулятор — `{$op: <вираз>}`.

### Розв'язання

```python
await run_pipeline(
    coll,
    "Revenue by category",
    [
        {"$match": {"amount": {"$gte": 400}}},
        {
            "$group": {
                "_id": "$category",
                "total_revenue": {"$sum": "$amount"},
                "avg_revenue":   {"$avg": "$amount"},
                "orders_count":  {"$count": {}},
                "max_order":     {"$max": "$amount"},
                "min_order":     {"$min": "$amount"},
            }
        },
        {"$sort": {"total_revenue": -1}},
        {
            "$project": {
                "_id": 0,
                "category":      "$_id",
                "total_revenue": 1,
                "avg_revenue":   1,
                "orders_count":  1,
                "max_order":     1,
                "min_order":     1,
            }
        },
    ],
)
```

```javascript
use("edu_academy_seed");
db.odm_aggregation_orders.aggregate([
  { $match: { amount: { $gte: 400 } } },
  {
    $group: {
      _id: "$category",
      total_revenue: { $sum: "$amount" },
      avg_revenue:   { $avg: "$amount" },
      orders_count:  { $count: {} },
      max_order:     { $max: "$amount" },
      min_order:     { $min: "$amount" }
    }
  },
  { $sort: { total_revenue: -1 } },
  {
    $project: {
      _id: 0,
      category: "$_id",
      total_revenue: 1,
      avg_revenue: 1,
      orders_count: 1,
      max_order: 1,
      min_order: 1
    }
  }
]);
```

### Покрокове пояснення

1. **Спочатку `$match` — завжди.** Раннє фільтрування — менше документів далі, і `$match` *перед* `$group` може користуватися індексами.
2. **`$group._id` — обов'язковий.** `null` — все в один кошик; тут — `$category`.
3. **`$count: {}` vs `$sum: 1`.** Обидва дають кількість рядків. `$count` — синтаксичний цукор з 5.0; раніше — `{$sum: 1}`.
4. **`$avg` ігнорує `null`.** Якщо половина рядків мала `amount: null`, середнє рахується по *не-null* підмножині.
5. **`$sort` після `$group` працює над згрупованими документами.** `_id` — те, що ви туди поклали (тут — `"Laptop"`, `"Smartphone"`, `"Tablet"`), і сортується як рядок.
6. **`$project` переформовує.** `"category": "$_id"` *копіює* значення `_id` у нове поле `category`. Потім `"_id": 0` прибирає оригінал.
7. **Порядок стадій важливий.** Поміняйте `$sort` і `$group` місцями — і сортуватимете 6 сирих документів замість 3 згрупованих — інша вартість і семантика.

---

## Вправа 2 — Замовлення за клієнтом (`$group → $sum(quantity) → $sort → $project`)

### Контекст

CRM потребує підсумки на клієнта: кількість замовлень, скільки одиниць відвантажили, скільки витратили — сортувати за витратами.

### Чого ви навчитеся

- Двом акумуляторам `$sum` на різних полях в одному `$group`.
- Перевикористанню `$count` і `$project` з Вправи 1.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `customer` | string | Ключ групування. |
| `quantity` | int | Сумуємо. |
| `amount` | int | Сумуємо. |

### Завдання

1. **`$group`** за `$customer` з `orders_count` (`$count`), `total_items` (`$sum $quantity`), `total_spent` (`$sum $amount`).
2. **`$sort`** за `total_spent` спаданням.
3. **`$project`** перейменувати `_id` → `customer`.

### Очікуваний результат

```text
Orders grouped by customer ($group + $sum(quantity) + $sort + $project)
  {'orders_count': 2, 'total_items': 2, 'total_spent': 2100, 'customer': 'Anna'}
  {'orders_count': 2, 'total_items': 4, 'total_spent': 950, 'customer': 'Daria'}
  {'orders_count': 1, 'total_items': 2, 'total_spent': 800, 'customer': 'Bohdan'}
  {'orders_count': 1, 'total_items': 1, 'total_spent': 700, 'customer': 'Chris'}
```

Anna лідирує за `total_spent` (два ноутбуки = $2100), а Daria — за `total_items` (4 планшети у двох замовленнях).

### Підказка

В одному `$group` може бути **скільки завгодно** акумуляторів — по одному на метрику.

### Розв'язання

```python
await run_pipeline(
    coll,
    "Orders grouped by customer",
    [
        {
            "$group": {
                "_id": "$customer",
                "orders_count": {"$count": {}},
                "total_items":  {"$sum": "$quantity"},
                "total_spent":  {"$sum": "$amount"},
            }
        },
        {"$sort": {"total_spent": -1}},
        {
            "$project": {
                "_id": 0,
                "customer":     "$_id",
                "orders_count": 1,
                "total_items":  1,
                "total_spent":  1,
            }
        },
    ],
)
```

```javascript
db.odm_aggregation_orders.aggregate([
  {
    $group: {
      _id: "$customer",
      orders_count: { $count: {} },
      total_items:  { $sum: "$quantity" },
      total_spent:  { $sum: "$amount" }
    }
  },
  { $sort: { total_spent: -1 } },
  {
    $project: {
      _id: 0,
      customer: "$_id",
      orders_count: 1,
      total_items: 1,
      total_spent: 1
    }
  }
]);
```

### Покрокове пояснення

1. **Тут нема `$match`.** Усі шість замовлень потрапляють в агрегацію. Додавайте `$match` спочатку для звуження за датою, статусом тощо.
2. **`$sum: "$amount"` vs `$sum: 1`.** Перше сумує поле; друге рахує рядки. Поведінка відрізняється, коли поле містить числа.
3. **`$sort` після `$group` — *блокуюча* стадія.** Якщо згрупований набір великий, треба індекс на попередній `$match` або `allowDiskUse=True`.
4. **Порядок полів у `$project`** не впливає на правила інклюзії, але впливає на порядок ключів у виводі — корисно для візуальних дифів.

---

## Шпаргалка

| Стадія / Акумулятор | Призначення | Приклад |
|---|---|---|
| `$match` | фільтр | `{$match: {amount: {$gte: 400}}}` |
| `$group` | групувати | `{$group: {_id: "$category", n: {$count: {}}}}` |
| `$sum` | сума | `{$sum: "$amount"}` (або `{$sum: 1}` — лічильник) |
| `$avg` | середнє | `{$avg: "$amount"}` |
| `$count` | кількість у групі | `{$count: {}}` (5.0+) |
| `$max` / `$min` | екстремум | `{$max: "$amount"}` |
| `$sort` | сортування | `{$sort: {total: -1}}` |
| `$project` | переформувати | `{$project: {_id: 0, category: "$_id", total: 1}}` |

## Розв'язання проблем

| Симптом | Імовірне виправлення |
|---|---|
| `unknown group operator '$count'` | MongoDB до 5.0. Замініть на `{$sum: 1}`. |
| `_id` — рядок, а ви очікували об'єкт | Групуєте по `"$field"` — повертається значення поля. Для багатьох полів — `{_id: {a: "$a", b: "$b"}}`. |
| `Sort exceeded memory limit` | Передфільтруйте через `$match` + індекс або дозвольте диск: `db.coll.aggregate(pipeline, {allowDiskUse: true})`. |
| `$avg` повертає null | Усі значення в групі — null. Додайте `$match` на ненульове поле. |
| `$project: {a: 1, _id: 0}` зрізає `a` | Порядок полів для інклюзії не важить — баг в іншому місці; перевірте попередню стадію. |
| Вихідні рядки у випадковому порядку | `$group` не зберігає порядок. Додайте `$sort` після `$group`. |
