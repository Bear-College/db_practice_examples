# Пагінація та сортування в MongoDB (`07_pagination_sorting`)

> Translation / Переклад: [English](../../../../04_mongodb/07_pagination_sorting/pagination_sorting_mongodb.md)

Ці вправи проходять три методи курсора, що перетворюють «знайди все» на готовий лістинг товарів: `sort(...)` — впорядкування, `skip(...)` — зсув для пагінації, `limit(...)` — розмір сторінки. Скрипт-компаньйон засіває невеликий каталог і запускає весь робочий процес сортування та сторінок.

Готовий файл-компаньйон: [`07_pagination_sorting/example.py`](../../../../04_mongodb/07_pagination_sorting/example.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/07_pagination_sorting/example.py
```

З'єднання за замовчуванням (можна перевизначити змінними оточення):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Колекція: `pagination_sorting_products`

---

## Шаблон вправи (повторюється у кожному розділі нижче)

| Секція | Що вона дає |
|---|---|
| **Контекст** | Навіщо реальному UI лістингу цей запит. |
| **Чого ви навчитеся** | Які методи курсора тренує ця вправа. |
| **Колекція** | Які поля використовуються. |
| **Завдання** | Конкретний ключ сортування і координати сторінки. |
| **Очікуваний результат** | Реальний вивід `python example.py`. |
| **Підказка** | Один виклик API, що робить роботу. |
| **Розв'язання** | PyMongo і `mongosh` поряд. |
| **Покрокове пояснення** | Що робить кожен виклик і типові помилки. |

---

## Колекція: `pagination_sorting_products`

Сід вставляє 10 товарів із 5 категорій:

| `name` | `category` | `price` | `rating` |
|---|---|---|---|
| iPhone 14 | Smartphone | 899 | 4.8 |
| Galaxy S23 | Smartphone | 799 | 4.7 |
| Pixel 8 | Smartphone | 699 | 4.6 |
| MacBook Air | Laptop | 1299 | 4.9 |
| ThinkPad X1 | Laptop | 1399 | 4.8 |
| iPad Pro | Tablet | 999 | 4.7 |
| Kindle Paperwhite | Tablet | 159 | 4.5 |
| Sony WH-1000XM5 | Audio | 399 | 4.8 |
| AirPods Pro | Audio | 249 | 4.6 |
| Logitech MX Master 3S | Accessories | 99 | 4.9 |

Допоміжна функція зі скрипта:

```python
from pymongo import ASCENDING, DESCENDING

def fetch_page(coll, *, page, per_page, sort_spec):
    skip_n = (page - 1) * per_page
    return list(
        coll.find({}, {"_id": 0})
        .sort(sort_spec)
        .skip(skip_n)
        .limit(per_page)
    )
```

---

## Вправа 1 — `sort(...)` (один ключ, за зростанням)

### Контекст

Вкладка «Найдешевші спочатку» каталогу. Покупець очікує найдешевший товар угорі, найдорожчий — унизу.

### Чого ви навчитеся

- Сортуванню за одним ключем з `ASCENDING`.
- Використанню констант `pymongo.ASCENDING` / `pymongo.DESCENDING` замість «магічних» чисел.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `price` | int | Ключ сортування. |
| `name`, `category`, `rating` | різні | Лише для виводу. |

### Завдання

Повернути всі 10 товарів за `price` за зростанням. Проєктувати все, крім `_id`.

### Очікуваний результат

```text
Sorted by price ASC
  name=Logitech MX Master 3S, category=Accessories, price=99, rating=4.9
  name=Kindle Paperwhite, category=Tablet, price=159, rating=4.5
  name=AirPods Pro, category=Audio, price=249, rating=4.6
  name=Sony WH-1000XM5, category=Audio, price=399, rating=4.8
  name=Pixel 8, category=Smartphone, price=699, rating=4.6
  name=Galaxy S23, category=Smartphone, price=799, rating=4.7
  name=iPhone 14, category=Smartphone, price=899, rating=4.8
  name=iPad Pro, category=Tablet, price=999, rating=4.7
  name=MacBook Air, category=Laptop, price=1299, rating=4.9
  name=ThinkPad X1, category=Laptop, price=1399, rating=4.8
```

### Підказка

`cursor.sort("price", ASCENDING)` — форма з комою. Список-кортежів `sort([("price", 1)])` — еквівалент.

### Розв'язання

```python
from pymongo import ASCENDING, MongoClient

coll = MongoClient("mongodb://localhost:27017")["edu_academy_seed"]["pagination_sorting_products"]

docs = list(coll.find({}, {"_id": 0}).sort("price", ASCENDING))
for d in docs:
    print(d["name"], d["price"])
```

```javascript
use("edu_academy_seed");
db.pagination_sorting_products
  .find({}, { _id: 0 })
  .sort({ price: 1 });
```

### Покрокове пояснення

1. **`sort` виконується на сервері.** PyMongo лише надсилає інструкцію в MongoDB — у пам'яті Python нічого не сортується.
2. **`1` (або `ASCENDING`) — від меншого до більшого.** `-1` (або `DESCENDING`) — навпаки.
3. **Без індексу на `price` сортування блокує курсор у пам'яті.** Для 10 документів — дрібниця, для 10 мільйонів — `Sort exceeded memory limit`.
4. **Стабільний порядок збігів.** Два товари з однаковою ціною можуть прийти у непередбачуваному порядку. Додайте ключ-розв'язувач збігів (Вправа 2), коли потрібен детермінований лістинг.

---

## Вправа 2 — `sort(...)` (складене, з різним напрямком)

### Контекст

Вкладка «Рекомендовані»: спочатку найвищий рейтинг, але **в межах** однакового рейтингу — найдешевше попереду, щоб «знахідка дня» була згори.

### Чого ви навчитеся

- Багатоключове сортування з різними напрямками.
- Чому порядок ключів сортування має значення.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `rating` | float | Первинний ключ, спадання. |
| `price` | int | Розв'язувач збігів, зростання. |

### Завдання

Повернути всі 10 товарів, відсортованих за `rating` за спаданням, далі за `price` за зростанням. Спочатку 4.9, у межах них — дешевше.

### Очікуваний результат

```text
Sorted by rating DESC, then price ASC
  name=Logitech MX Master 3S, category=Accessories, price=99, rating=4.9
  name=MacBook Air, category=Laptop, price=1299, rating=4.9
  name=Sony WH-1000XM5, category=Audio, price=399, rating=4.8
  name=iPhone 14, category=Smartphone, price=899, rating=4.8
  name=ThinkPad X1, category=Laptop, price=1399, rating=4.8
  name=Galaxy S23, category=Smartphone, price=799, rating=4.7
  name=iPad Pro, category=Tablet, price=999, rating=4.7
  name=AirPods Pro, category=Audio, price=249, rating=4.6
  name=Pixel 8, category=Smartphone, price=699, rating=4.6
  name=Kindle Paperwhite, category=Tablet, price=159, rating=4.5
```

Спочатку блок 4.9 (`MX Master 3S` дешевший за `MacBook Air`), потім блок 4.8 (`Sony WH-1000XM5` → `iPhone 14` → `ThinkPad X1`) і т. д.

### Підказка

Передавайте **список кортежів**: `.sort([("rating", DESCENDING), ("price", ASCENDING)])`. Кожен кортеж — `(поле, напрямок)`.

### Розв'язання

```python
from pymongo import ASCENDING, DESCENDING

docs = list(
    coll.find({}, {"_id": 0}).sort(
        [("rating", DESCENDING), ("price", ASCENDING)]
    )
)
for d in docs:
    print(d["name"], "rating=", d["rating"], "price=", d["price"])
```

```javascript
db.pagination_sorting_products
  .find({}, { _id: 0 })
  .sort({ rating: -1, price: 1 });
```

### Покрокове пояснення

1. **Порядок ключів = пріоритет.** `rating` — первинне сортування; `price` спрацьовує лише при збігу рейтингу.
2. **Змішані напрямки — нормально.** `{ rating: -1, price: 1 }` — «спочатку спадання, потім зростання»: MongoDB проходить обидва індекси узгоджено.
3. **Складений індекс на `(rating, price)` уникає сортування в пам'яті.** Напрямок у індексі має збігатися з порядком сортування (або бути точно зворотним).
4. **Пастка літерала-словника в mongosh.** `{ rating: -1, price: 1 }` зберігає порядок, бо літерали об'єктів JavaScript впорядковані. У Python використовуйте список кортежів — словники Python теж тепер впорядковані за вставкою, але явна форма читається чіткіше.

---

## Вправа 3 — `skip(...)` + `limit(...)` (offset-пагінація)

### Контекст

Сітка каталогу показує **3 товари на сторінку**. Користувач відкриває сторінку 2 — потрібні рядки 4-6 алфавітного лістингу.

### Чого ви навчитеся

- Зв'язку між `page`, `page_size`, `skip` і `limit`.
- Чому кожен пагінований запит **зобов'язаний** мати детерміноване `sort`.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `name` | string | Ключ сортування — визначає поняття «сторінка N». |

### Завдання

З `page_size = 3` і сортуванням за `name` за зростанням отримати сторінки 1, 2 і 3. Кожен виклик повертає 3 документи; разом вони покривають 9 із 10 товарів.

### Очікуваний результат

```text
Page 1 (size=3, sort=name ASC)
  name=AirPods Pro, category=Audio, price=249, rating=4.6
  name=Galaxy S23, category=Smartphone, price=799, rating=4.7
  name=Kindle Paperwhite, category=Tablet, price=159, rating=4.5

Page 2 (size=3, sort=name ASC)
  name=Logitech MX Master 3S, category=Accessories, price=99, rating=4.9
  name=MacBook Air, category=Laptop, price=1299, rating=4.9
  name=Pixel 8, category=Smartphone, price=699, rating=4.6

Page 3 (size=3, sort=name ASC)
  name=Sony WH-1000XM5, category=Audio, price=399, rating=4.8
  name=ThinkPad X1, category=Laptop, price=1399, rating=4.8
  name=iPad Pro, category=Tablet, price=999, rating=4.7

Total documents: 10
```

Десятий товар (`iPhone 14`) опинився б на сторінці 4 (`skip=9`, `limit=3`).

### Підказка

`skip_n = (page - 1) * per_page`. З'єднайте: `cursor.sort(...).skip(skip_n).limit(per_page)`.

### Розв'язання

```python
from pymongo import ASCENDING

def fetch_page(coll, *, page, per_page, sort_spec):
    if page < 1:
        raise ValueError("page must be >= 1")
    skip_n = (page - 1) * per_page
    return list(
        coll.find({}, {"_id": 0})
        .sort(sort_spec)
        .skip(skip_n)
        .limit(per_page)
    )

page_size = 3
for p in (1, 2, 3):
    rows = fetch_page(coll, page=p, per_page=page_size, sort_spec=[("name", ASCENDING)])
    print(f"--- сторінка {p} ---")
    for d in rows:
        print(d["name"])
```

```javascript
const pageSize = 3;
for (const page of [1, 2, 3]) {
  const skipN = (page - 1) * pageSize;
  const rows = db.pagination_sorting_products
    .find({}, { _id: 0 })
    .sort({ name: 1 })
    .skip(skipN)
    .limit(pageSize)
    .toArray();
  print(`--- сторінка ${page} ---`);
  rows.forEach((d) => print(d.name));
}
```

### Покрокове пояснення

1. **MongoDB виконує `sort → skip → limit` на сервері саме в цьому порядку.** Сторінки беруться з *відсортованої* послідовності — так само, як SQL `ORDER BY ... LIMIT ... OFFSET`.
2. **Без `sort` пагінувати не можна.** Інакше порядок курсора недетермінований, і рядок може з'явитись на двох сторінках або зникнути між двома.
3. **Обирайте унікальний ключ сортування.** Тут `name` унікальний, але якби два товари мали однакову назву — порядок між ними був би невизначений. Додайте `_id` останнім ключем (`.sort([("name", 1), ("_id", 1)])`) для гарантованої детермінованості.
4. **`skip` має складність O(N) від зсуву.** Кожен запит знову проходить перші `(page - 1) * page_size` рядків. Для глибоких сторінок переходьте на **keyset-пагінацію**: зберігайте останнє побачене `name` (або `_id`) і вживайте `find({"name": {"$gt": last_name}}).sort("name", 1).limit(page_size)` — без `skip`.
5. **`count_documents({})` дає загальну кількість** (`10` тут). Разом із `page_size` це дає «сторінка 2 із 4» в UI.

---

## Шпаргалка

| Мета | Виклик курсора | Аналог mongosh |
|---|---|---|
| Сортувати за зростанням за одним ключем | `.sort("price", 1)` | `.sort({ price: 1 })` |
| Сортувати з розв'язувачем збігів | `.sort([("rating", -1), ("price", 1)])` | `.sort({ rating: -1, price: 1 })` |
| Пропустити N рядків | `.skip(N)` | `.skip(N)` |
| Взяти лише M рядків | `.limit(M)` | `.limit(M)` |
| Підрахунок для «X з Y» | `coll.count_documents({})` | `db.coll.countDocuments({})` |

## Розв'язання проблем

| Симптом | Імовірне виправлення |
|---|---|
| `Sort exceeded memory limit` | Додайте індекс на ключ(і) сортування — або обмежте результат фільтром у `find`. |
| Сторінка 2 повторює рядки зі сторінки 1 | Сортування недетерміноване (немає унікального розв'язувача). Додайте `_id` останнім ключем. |
| `skip` повільний на сторінці 10 000 | Перейдіть на keyset-пагінацію (`find({"_id": {"$gt": last_id}})`). |
| Ліміт 32 МБ на сортування | Те ж саме — індекс або попередній фільтр. |
| `find().limit(0)` повертає *усі* рядки | У MongoDB `limit(0)` означає «без ліміту». Використайте `-1` або реальне додатне число. |
