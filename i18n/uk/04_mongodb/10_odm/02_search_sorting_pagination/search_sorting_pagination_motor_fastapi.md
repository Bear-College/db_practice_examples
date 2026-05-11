# Пошук, сортування, пагінація — Motor + FastAPI (`10_odm/02_search_sorting_pagination`)

> Translation / Переклад: [English](../../../../../04_mongodb/10_odm/02_search_sorting_pagination/search_sorting_pagination_motor_fastapi.md)

Ці вправи проходять невеликий, але **повний** read-side API, що поєднує три ортогональні задачі: повнотекстоподібний **пошук** (через regex + `$or`), багатопольне **сортування** і offset-**пагінацію** — усе подається асинхронно через **FastAPI + Motor + Pydantic**.

Готовий файл-компаньйон: [`10_odm/02_search_sorting_pagination/main.py`](../../../../../04_mongodb/10_odm/02_search_sorting_pagination/main.py).

```bash
pip install -r 04_mongodb/10_odm/02_search_sorting_pagination/requirements.txt
uvicorn main:app --reload --app-dir 04_mongodb/10_odm/02_search_sorting_pagination
```

Далі відкривайте `http://127.0.0.1:8000/docs` (Swagger UI) або стукайте в endpoint через `curl`.

З'єднання за замовчуванням (можна перевизначити змінними оточення):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Колекція: `odm_search_sort_pagination_products`

---

## Що у скрипті

```python
class ProductsPage(BaseModel):
    total: int
    page: int
    page_size: int
    sort_by: str
    sort_dir: Literal["asc", "desc"]
    q: str | None
    items: List[ProductOut]


@app.get("/products", response_model=ProductsPage)
async def list_products(
    q: str | None = Query(default=None),
    sort_by: Literal["name", "price", "rating"] = Query(default="name"),
    sort_dir: Literal["asc", "desc"]            = Query(default="asc"),
    page: int      = Query(default=1, ge=1),
    page_size: int = Query(default=5, ge=1, le=50),
) -> ProductsPage:
    query = {}
    if q:
        query = {"$or": [
            {"name":        {"$regex": q, "$options": "i"}},
            {"category":    {"$regex": q, "$options": "i"}},
            {"description": {"$regex": q, "$options": "i"}},
        ]}
    sort_order = 1 if sort_dir == "asc" else -1
    skip_n = (page - 1) * page_size
    total  = await coll.count_documents(query)
    cursor = coll.find(query).sort(sort_by, sort_order).skip(skip_n).limit(page_size)
    docs   = await cursor.to_list(length=page_size)
    ...
```

Колекція засіяна 10 товарами (ті самі дані, що й в `07_pagination_sorting`, плюс поле `description` для пошуку):

| `name` | `category` | `description` | `price` | `rating` |
|---|---|---|---|---|
| iPhone 14 | Smartphone | "Apple smartphone" | 899 | 4.8 |
| Galaxy S23 | Smartphone | "Samsung flagship phone" | 799 | 4.7 |
| Pixel 8 | Smartphone | "Google Android phone" | 699 | 4.6 |
| MacBook Air | Laptop | "Apple ultrabook laptop" | 1299 | 4.9 |
| ThinkPad X1 | Laptop | "Business laptop" | 1399 | 4.8 |
| iPad Pro | Tablet | "Apple tablet device" | 999 | 4.7 |
| Kindle Paperwhite | Tablet | "E-reader tablet" | 159 | 4.5 |
| Sony WH-1000XM5 | Audio | "Noise canceling headphones" | 399 | 4.8 |
| AirPods Pro | Audio | "Wireless earbuds" | 249 | 4.6 |
| Logitech MX Master 3S | Accessories | "Premium wireless mouse" | 99 | 4.9 |

Усі вправи нижче захоплюють **реальні відповіді** від `curl` до сервера на порті 8765 (щоб не конфліктувати з тим, що може крутитись на 8000).

---

## Шаблон вправи (повторюється у кожному розділі нижче)

| Секція | Що дає |
|---|---|
| **Контекст** | Навіщо реальному лістингу ця «ручка» запиту. |
| **Чого ви навчитеся** | Які частини Motor / Pydantic / FastAPI задіяні. |
| **Endpoint** | Які параметри `/products` використовуються. |
| **Завдання** | Конкретний `curl`-запит. |
| **Очікуваний результат** | Реальне JSON-тіло, що повернув сервер. |
| **Підказка** | Який метод курсора Motor робить роботу. |
| **Розв'язання** | Версії на Python (Motor) і `mongosh`. |
| **Покрокове пояснення** | Як FastAPI / Pydantic / Motor співпрацюють і де грабельки. |

---

## Вправа 1 — Лістинг за замовчуванням (без фільтра, сорт. `name` ASC)

### Контекст

Вкладка «Усі товари» каталогу відкривається без фільтра, відсортована за алфавітом, 5 на сторінку. Загальний лічильник дає футер «Сторінка 1 з 2».

### Чого ви навчитеся

- Як `Query(default=...)` FastAPI підставляє значення за замовчуванням.
- Простий конвеєр Motor: `coll.find(query).sort(...).skip(...).limit(...)`.
- Pydantic-обгортка `ProductsPage` для `(total, page, page_size, items)`.

### Endpoint

```text
GET /products
```

(Параметрів запиту немає.)

### Завдання

Звернутись до endpoint без параметрів і прочитати обгортку.

### Очікуваний результат

```json
{
  "total": 10,
  "page": 1,
  "page_size": 5,
  "sort_by": "name",
  "sort_dir": "asc",
  "q": null,
  "items": [
    {"_id": "...", "name": "AirPods Pro",        "category": "Audio",       "price": 249,  "rating": 4.6},
    {"_id": "...", "name": "Galaxy S23",         "category": "Smartphone",  "price": 799,  "rating": 4.7},
    {"_id": "...", "name": "Kindle Paperwhite",  "category": "Tablet",      "price": 159,  "rating": 4.5},
    {"_id": "...", "name": "Logitech MX Master 3S", "category": "Accessories", "price": 99, "rating": 4.9},
    {"_id": "...", "name": "MacBook Air",        "category": "Laptop",      "price": 1299, "rating": 4.9}
  ]
}
```

Повертаються 5 найвищих за алфавітом (`A`-`M`); `Pixel 8` і далі — на сторінці 2.

### Підказка

Endpoint уже все робить. Просто `curl "http://127.0.0.1:8765/products"`.

### Розв'язання

```python
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

async def main():
    coll = AsyncIOMotorClient("mongodb://localhost:27017")["edu_academy_seed"]["odm_search_sort_pagination_products"]
    total = await coll.count_documents({})
    cursor = coll.find({}).sort("name", 1).skip(0).limit(5)
    docs = await cursor.to_list(length=5)
    print({"total": total, "items": [d["name"] for d in docs]})

asyncio.run(main())
```

```javascript
db.odm_search_sort_pagination_products
  .find({})
  .sort({ name: 1 })
  .skip(0)
  .limit(5);

db.odm_search_sort_pagination_products.countDocuments({});
```

### Покрокове пояснення

1. **FastAPI парсить query-string** у типізовані kwarg-и (`sort_by: Literal["name", "price", "rating"]`). Поганий вибір дає 422.
2. **`count_documents(query)` чекається окремо.** У Motor немає «однотрубного» виклику; ви робите два await — на лічильник і на сторінку — і миритесь з невеликим зайвим round trip.
3. **`to_list(length=page_size)` — канонічний спосіб дренування.** `async for doc in cursor` теж працює, але `to_list` коротший, коли ви вже знаєте межу.
4. **`_id` у відповіді стає рядком.** Handler конвертує `ObjectId` через `str(d["_id"])`; `populate_by_name` + `alias="_id"` у Pydantic v2 робить решту.

---

## Вправа 2 — Пошук (`q=phone`)

### Контекст

Пошуковий рядок магазину шукає по трьох полях — `name`, `category`, `description`. Введення `"phone"` має винести нагору все «навколо телефонів».

### Чого ви навчитеся

- Обгортанню кількох regex-предикатів у `$or`.
- Регістронечутливому пошуку через `$options: "i"`.
- Чому `count_documents(query)` рахується **по відфільтрованій множині**, не по всій колекції.

### Endpoint

```text
GET /products?q=phone
```

### Завдання

Виконати пошук `"phone"` і прочитати загальний лічильник і масив `items`.

### Очікуваний результат

```json
{
  "total": 4,
  "page": 1,
  "page_size": 5,
  "sort_by": "name",
  "sort_dir": "asc",
  "q": "phone",
  "items": [
    {"name": "Galaxy S23",      "category": "Smartphone", "price": 799, "rating": 4.7},
    {"name": "Pixel 8",         "category": "Smartphone", "price": 699, "rating": 4.6},
    {"name": "Sony WH-1000XM5", "category": "Audio",      "price": 399, "rating": 4.8},
    {"name": "iPhone 14",       "category": "Smartphone", "price": 899, "rating": 4.8}
  ]
}
```

Чотири збіги: три з чотирьох `category: "Smartphone"` (Pixel 8 — за категорією, iPhone 14 і Galaxy S23 — за категорією або описом; *"phone"* — регістронечутливий підрядок) **плюс** Sony WH-1000XM5 (опис містить "headphones").

### Підказка

`{"$or": [{"name": {"$regex": q, "$options": "i"}}, {"category": ...}, {"description": ...}]}`.

### Розв'язання

```python
q = "phone"
query = {"$or": [
    {"name":        {"$regex": q, "$options": "i"}},
    {"category":    {"$regex": q, "$options": "i"}},
    {"description": {"$regex": q, "$options": "i"}},
]}
total  = await coll.count_documents(query)
docs   = await coll.find(query).sort("name", 1).limit(5).to_list(length=5)
```

```javascript
const q = "phone";
db.odm_search_sort_pagination_products.find({
  $or: [
    { name:        { $regex: q, $options: "i" } },
    { category:    { $regex: q, $options: "i" } },
    { description: { $regex: q, $options: "i" } }
  ]
}).sort({ name: 1 }).limit(5);
```

### Покрокове пояснення

1. **Regex на трьох полях = `$or`.** Без `$or` MongoDB поєднала б їх через AND і вимагала б "phone" у *всіх трьох* полях.
2. **`$options: "i"` робить пошук регістронечутливим.** Тоді `"phone"` збігається зі "Smartphone", "headphones" і т. ін.
3. **Пошук без індексу.** Для більших наборів даних — побудуйте *text*-індекс (`{name: "text", description: "text"}`) і переходьте на `$text` — див. урок `09_indexes`.
4. **Не забувайте про вартість count.** `count_documents` повторно проганяє фільтр; для великих наборів іноді кращий варіант — *оцінений* `estimated_document_count` (по всій колекції) і додаткові перевірки на сторінку.

---

## Вправа 3 — Сортування за `price` за спаданням

### Контекст

Перемикач «Дорогі — спершу» у вітрині. Той самий набір даних, без фільтра — лише інші `sort_by` / `sort_dir`.

### Чого ви навчитеся

- Як `sort_dir = "asc" | "desc"` стає `+1 / -1`.
- Що `sort_by` обмежений типом завдяки Pydantic на межі.

### Endpoint

```text
GET /products?sort_by=price&sort_dir=desc
```

### Завдання

Взяти першу сторінку, відсортовану за ціною від найдорожчого.

### Очікуваний результат

```json
{
  "total": 10,
  "page": 1,
  "page_size": 5,
  "sort_by": "price",
  "sort_dir": "desc",
  "q": null,
  "items": [
    {"name": "ThinkPad X1",  "category": "Laptop",     "price": 1399, "rating": 4.8},
    {"name": "MacBook Air",  "category": "Laptop",     "price": 1299, "rating": 4.9},
    {"name": "iPad Pro",     "category": "Tablet",     "price": 999,  "rating": 4.7},
    {"name": "iPhone 14",    "category": "Smartphone", "price": 899,  "rating": 4.8},
    {"name": "Galaxy S23",   "category": "Smartphone", "price": 799,  "rating": 4.7}
  ]
}
```

### Підказка

У query-string: `sort_by=price` і `sort_dir=desc`.

### Розв'язання

```python
sort_order = 1 if sort_dir == "asc" else -1
docs = await coll.find({}).sort("price", sort_order).limit(5).to_list(length=5)
```

```javascript
db.odm_search_sort_pagination_products
  .find({})
  .sort({ price: -1 })
  .limit(5);
```

### Покрокове пояснення

1. **`Literal["asc", "desc"]` ловить друкарські помилки на етапі парсингу.** Запит з `sort_dir=descending` повертає 422, перш ніж досягне коду.
2. **`sort_by` теж `Literal`.** Обмеження ним полів, які ви передбачили, не дозволить користувачу провокувати повне сканування по довільному полю.
3. **Тут немає розв'язувача збігів.** Два товари з однією ціною мають невизначений порядок. Для «стабільного» сортування — `.sort([(sort_by, sort_order), ("_id", 1)])`.

---

## Вправа 4 — Пагінація (`page=2`, `page_size=3`)

### Контекст

Сітка з 3 товарами на сторінку. Користувач натискає «Далі» — це `page=2, page_size=3`.

### Чого ви навчитеся

- Арифметиці `(page - 1) * page_size` за `skip`.
- Чому `page_size` має жорстку верхню межу `le=50`.

### Endpoint

```text
GET /products?page=2&page_size=3
```

### Завдання

Отримати сторінку 2 з `page_size=3` і прочитати «вирізаний» зріз.

### Очікуваний результат

```json
{
  "total": 10,
  "page": 2,
  "page_size": 3,
  "sort_by": "name",
  "sort_dir": "asc",
  "q": null,
  "items": [
    {"name": "Logitech MX Master 3S", "category": "Accessories", "price": 99,   "rating": 4.9},
    {"name": "MacBook Air",           "category": "Laptop",      "price": 1299, "rating": 4.9},
    {"name": "Pixel 8",               "category": "Smartphone",  "price": 699,  "rating": 4.6}
  ]
}
```

Елементи 4-6 алфавітного порядку: `Logitech` → `MacBook Air` → `Pixel 8`.

### Підказка

`skip_n = (page - 1) * page_size`. `cursor.skip(skip_n).limit(page_size)`.

### Розв'язання

```python
skip_n = (page - 1) * page_size
docs = await (
    coll.find(query).sort(sort_by, sort_order).skip(skip_n).limit(page_size).to_list(length=page_size)
)
```

```javascript
const pageSize = 3;
const page = 2;
const skipN = (page - 1) * pageSize;
db.odm_search_sort_pagination_products
  .find({})
  .sort({ name: 1 })
  .skip(skipN)
  .limit(pageSize);
```

### Покрокове пояснення

1. **`Query(ge=1, le=50)` накладає межі на рівні FastAPI.** `page_size=1000` дає 422 — захист сервера від «віддай усе».
2. **`skip` має складність O(N) від пропущеного.** На 10 документах — нічого; на «сторінці 10 000» у мільйонному наборі — час переходити на keyset-пагінацію (`_id > last_id`).
3. **Загальна кількість — з *відфільтрованого* набору.** Не замінюйте її на `estimated_document_count()`, якщо тільки реально не маєте на увазі «у колекції всього».

---

## Вправа 5 — Сортування за `rating` за спаданням, сторінка 3

### Контекст

Віджет-прев'ю «Топ за рейтингом» — три з найкращим рейтингом, незалежно від категорії чи ціни.

### Чого ви навчитеся

- Як `sort_by=rating` + `page_size=3` дають детермінований «top-N».
- Чому при збігу рейтингу порядок може змінюватись (і як це виправити).

### Endpoint

```text
GET /products?sort_by=rating&sort_dir=desc&page_size=3
```

### Завдання

Отримати перші 3 товари за `rating` спаданням.

### Очікуваний результат

```json
{
  "total": 10,
  "page": 1,
  "page_size": 3,
  "sort_by": "rating",
  "sort_dir": "desc",
  "q": null,
  "items": [
    {"name": "Logitech MX Master 3S", "category": "Accessories", "price": 99,   "rating": 4.9},
    {"name": "MacBook Air",           "category": "Laptop",      "price": 1299, "rating": 4.9},
    {"name": "ThinkPad X1",           "category": "Laptop",      "price": 1399, "rating": 4.8}
  ]
}
```

Обидва товари з 4.9 — попереду; `ThinkPad X1` (один із трьох 4.8) виграв третє місце саме в *цьому* запуску — порядок між трьома 4.8 без розв'язувача збігів недетермінований.

### Підказка

Для детермінованого порядку при однакових рейтингах потрібен другий ключ — змінити `cursor.sort(sort_by, sort_order)` на `cursor.sort([(sort_by, sort_order), ("_id", 1)])`.

### Розв'язання

```python
sort_order = -1
docs = await coll.find({}).sort([("rating", sort_order), ("_id", 1)]).limit(3).to_list(length=3)
```

```javascript
db.odm_search_sort_pagination_products
  .find({})
  .sort({ rating: -1, _id: 1 })
  .limit(3);
```

### Покрокове пояснення

1. **Один ключ достатній для `4.9 > 4.8 > 4.7`**, але не для розрізнення двох 4.8.
2. **`_id` — універсальний розв'язувач збігів.** Унікальне за побудовою, монотонне за часом вставки, майже завжди дешеве.
3. **Pydantic не валідує стан бази.** Якби два документи мали однакове `name`, а ви сортували за `name`, з'явилася б та сама нестабільність.

---

## Шпаргалка

| Мета | Query string | Базовий виклик |
|---|---|---|
| Усе, сорт name ASC, 5/стор | (значення за замовчуванням) | `find({}).sort("name", 1).skip(0).limit(5)` |
| Шукати «phone» скрізь | `?q=phone` | `find({"$or":[{...regex...}]})` |
| Найдорожчі — спершу | `?sort_by=price&sort_dir=desc` | `find({}).sort("price", -1)` |
| Сторінка 2 з 3 | `?page=2&page_size=3` | `find({}).skip(3).limit(3)` |
| Топ-3 за рейтингом | `?sort_by=rating&sort_dir=desc&page_size=3` | `find({}).sort("rating", -1).limit(3)` |

## Розв'язання проблем

| Симптом | Імовірне виправлення |
|---|---|
| 422 на `sort_by=foo` | `sort_by` — `Literal["name", "price", "rating"]`. Виберіть одне з трьох. |
| Пошук повільний | Regex без індексу. Створіть `text`-індекс і перейдіть на `$text`/`$search`. |
| `total` не дорівнює `len(items)` | Так і має бути: `total` — це сумарна відфільтрована кількість, `items` — зріз сторінки. |
| `_id` друкується як `ObjectId(...)` | Забули `str(d["_id"])` перед валідацією у `ProductOut`. |
| Пагінація повторює рядки | Ключ сортування не унікальний. Додайте `_id` як розв'язувач. |
| У логах `Sort exceeded memory limit` | Додайте індекс на ключ сортування або обмежте `query`. |
