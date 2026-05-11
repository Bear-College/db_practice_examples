# Запити вибірки у MongoDB (`02_selection_queries`)

> Translation / Переклад: [English](../../../../04_mongodb/02_selection_queries/selection_queries_mongodb.md)

Ці вправи проходять **оператори порівняння та належності до списку** (`$eq`, `$ne`, `$gt`, `$lt`, `$gte`, `$lte`, `$in`, `$nin`) і додатково три приклади з **вкладеними документами** через точкову нотацію (`profile.city`, `profile.experience`, `profile.role`).

Усі приклади виконуються на практичній базі `edu_academy_seed` та колекції **`selection_queries_people`**.

Готовий приклад: [`02_selection_queries/example.py`](../../../../04_mongodb/02_selection_queries/example.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/02_selection_queries/example.py
```

Налаштування за замовчуванням:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

На початку запуску скрипт скидає колекцію, тож рядки **`count`** і **`docs`** у кожному «Очікуваному результаті» нижче — детерміновані.

---

## Шаблон вправи (повторюється у кожному розділі нижче)

| Секція | Що вона дає |
|---|---|
| **Контекст** | Навіщо реальній CRM/HR цей запит. |
| **Чого ви навчитеся** | Конструкції PyMongo/mongosh, що тренує саме ця вправа. |
| **Колекція** | Документи й поля, які ми справді запитуємо. |
| **Завдання** | Конкретна вимога до фільтра. |
| **Очікуваний результат** | Реальні рядки `count` і `docs` з живого запуску. |
| **Підказка** | Один натяк на потрібний оператор. |
| **Розв'язання** | Робочий Python (PyMongo) **та** еквівалентний JS для mongosh. |
| **Покрокове пояснення** | Семантика оператора і пастки BSON / приведення типів. |

---

## Карта: оператори порівняння та списків

| Оператор | Значення | Аналог у SQL |
|---|---|---|
| `$eq` | Дорівнює | `=` |
| `$ne` | Не дорівнює | `<>` |
| `$gt` | Більше | `>` |
| `$lt` | Менше | `<` |
| `$gte` | Більше або дорівнює | `>=` |
| `$lte` | Менше або дорівнює | `<=` |
| `$in` | Значення зі списку | `IN (…)` |
| `$nin` | Значення поза списком | `NOT IN (…)` |

Для вкладених документів **точкова нотація** (`profile.city`) адресує поля всередині суб-документів — оператори при цьому ті самі.

## Схема колекції

Колекція `selection_queries_people` містить 7 документів з пласким верхом і вкладеним `profile`:

```json
{
  "name": "Anna",
  "age": 17,
  "city": "Chicago",
  "profile": { "city": "Chicago", "experience": 1, "role": "intern" }
}
```

| Поле | Тип BSON | Приклади значень |
|---|---|---|
| `name` | `string` | Anna, Bohdan, Chris, Daria, Emma, Farid, Hanna |
| `age` | `int` | 17, 18, 25, 30, 45, 60, 61 |
| `city` | `string` | Chicago, New York, Los Angeles, Kyiv, Berlin, Warsaw |
| `profile.city` | `string` | Той самий набір, продубльований у `profile` |
| `profile.experience` | `int` | 1, 2, 4, 7, 15, 20, 21 |
| `profile.role` | `string` | intern, junior, developer, lead, architect, principal, advisor |

---

## Вправа 1 — `$eq` (дорівнює)

### Контекст

HR-дашборд хоче підсвітити кожного співробітника, у якого вік **рівно** 25 — офіс відзначає «чверть століття».

### Чого ви навчитеся

- Явній формі `{ field: { $eq: value } }`.
- Чому неявна коротка форма `{ field: value }` еквівалентна.

### Колекція

| Поле | Тип | Значення фільтра |
|---|---|---|
| `age` | `int` | `25` |

### Завдання

Знайти всіх з `age == 25`, відсортувавши за `name` за зростанням.

### Очікуваний результат

```text
$eq  (equals)
  query={'age': {'$eq': 25}}
  count=1
  docs=[Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4)]
```

### Підказка

`{"age": {"$eq": 25}}` і `{"age": 25}` — це одне й те саме.

### Розв'язання

```python
docs = list(coll.find({"age": {"$eq": 25}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $eq: 25 } }, { _id: 0 }).sort({ name: 1 })
```

### Покрокове пояснення

1. **`$eq` зіставляє і за значенням, *і* за типом BSON.** `{"age": {"$eq": 25}}` не збіжить документ із `"age": "25"` (string). MongoDB не виконує неявне приведення числових рядків.
2. **Неявна форма** `{"age": 25}` ідентична: якщо значення не є dict із ключем на `$`, драйвер обгортає його в `$eq`.
3. **Проєкція `{"_id": 0}`** прибирає `ObjectId` із результату — у прикладі для зручного виводу.
4. **`.sort("name", 1)`** просить сервер сортувати за `name` за зростанням. Без сортування порядок — storage-порядок, він не стабільний.

---

## Вправа 2 — `$ne` (не дорівнює)

### Контекст

Двадцятип'ятилітні отримують одну акцію, решта — стандартну розсилку. Перелічіть усіх, чий вік **не** 25.

### Чого ви навчитеся

- Семантиці `$ne` для відсутніх полів.
- Чому `$ne` майже не користується індексом.

### Колекція

| Поле | Тип | Значення фільтра |
|---|---|---|
| `age` | `int` | не `25` |

### Завдання

Повернути всіх із `age != 25`, відсортовано за `name`.

### Очікуваний результат

```text
$ne  (not equals)
  query={'age': {'$ne': 25}}
  count=6
  docs=[Anna (age=17, city=Chicago, profile.city=Chicago, profile.experience=1), Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Daria (age=30, city=Kyiv, profile.city=Kyiv, profile.experience=7), Emma (age=45, city=New York, profile.city=New York, profile.experience=15), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20), Hanna (age=61, city=Warsaw, profile.city=Warsaw, profile.experience=21)]
```

### Підказка

`{"age": {"$ne": 25}}`.

### Розв'язання

```python
docs = list(coll.find({"age": {"$ne": 25}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $ne: 25 } }, { _id: 0 }).sort({ name: 1 })
```

### Покрокове пояснення

1. **`$ne` включає документи, де поле відсутнє.** Документ без `age` теж вважається «не рівним 25» і потрапить у результат. Якщо треба виключити такі — комбінуйте з `$exists: true` (див. урок `05_check_operators`).
2. **`$ne` не індексо-дружній.** Там, де `$eq` робить точковий пошук, `$ne` змушений сканувати майже весь діапазон індексу. На великих колекціях по можливості перепишіть умову через `$gt` + `$lt`.
3. Як і `$eq`, **`$ne` суворий до типу**: `{"age": {"$ne": "25"}}` пройде кожен документ, бо `25` (int) не дорівнює рядку `"25"`.

---

## Вправа 3 — `$gt` (більше)

### Контекст

Маркетинг хоче «старший» сегмент — усіх, кому строго більше 25.

### Чого ви навчитеся

- Суворому компаратору `$gt` (без рівності на межі).
- Правилам впорядкування числових типів у BSON.

### Колекція

| Поле | Тип | Значення фільтра |
|---|---|---|
| `age` | `int` | `> 25` |

### Завдання

Знайти всіх з `age > 25`, відсортовано за `name`.

### Очікуваний результат

```text
$gt  (greater than)
  query={'age': {'$gt': 25}}
  count=4
  docs=[Daria (age=30, city=Kyiv, profile.city=Kyiv, profile.experience=7), Emma (age=45, city=New York, profile.city=New York, profile.experience=15), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20), Hanna (age=61, city=Warsaw, profile.city=Warsaw, profile.experience=21)]
```

### Підказка

`$gt` суворий — `age = 25` у результат **не** потрапляє.

### Розв'язання

```python
docs = list(coll.find({"age": {"$gt": 25}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $gt: 25 } }, { _id: 0 }).sort({ name: 1 })
```

### Покрокове пояснення

1. **`$gt`** виключає межу. Якщо треба включити — `$gte` (Вправа 5).
2. **Числові порівняння між `Int32`, `Int64`, `Double`, `Decimal128`** працюють — Mongo впорядковує всю «числову» категорію як єдиний набір. А порівняння `int` з `string` нічого не поверне: типи BSON упорядковані суворо, числа < рядки.
3. **Узгодженість з індексом:** `{age: 1}` обслужить `$gt` як діапазонний скан від `25` ексклюзивно. Якщо додасте сортування за тим самим ключем (`.sort("age", 1)`), отримаєте чистий index scan без in-memory sort.

---

## Вправа 4 — `$lt` (менше)

### Контекст

Показати «молодіжну» когорту для стажерської програми — всі, хто строго молодший за 30.

### Чого ви навчитеся

- Суворому `<`.
- Дзеркальному відповіднику `$gt`.

### Колекція

| Поле | Тип | Значення фільтра |
|---|---|---|
| `age` | `int` | `< 30` |

### Завдання

Знайти всіх з `age < 30`, відсортовано за `name`.

### Очікуваний результат

```text
$lt  (less than)
  query={'age': {'$lt': 30}}
  count=3
  docs=[Anna (age=17, city=Chicago, profile.city=Chicago, profile.experience=1), Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4)]
```

### Підказка

`$lt` суворий — `age = 30` **не** в результаті.

### Розв'язання

```python
docs = list(coll.find({"age": {"$lt": 30}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $lt: 30 } }, { _id: 0 }).sort({ name: 1 })
```

### Покрокове пояснення

1. **`$lt` суворий.** Daria (age = 30) виключена; вона з'явиться лише з `$lte: 30`.
2. **Комбінуйте `$gt` + `$lt`** в одному запиті, щоб задати діапазон: `{"age": {"$gt": 17, "$lt": 30}}` — це `17 < age < 30`.
3. **Порівняння дат і ObjectId** використовує той самий `$lt`: BSON-дати — це 64-бітні мс від епохи, тому компаруються лінійно.

---

## Вправа 5 — `$gte` (більше або дорівнює)

### Контекст

Фільтр «дорослих»: усі, кому 18 і більше, межу включаємо.

### Чого ви навчитеся

- Інклюзивній формі.
- Коли обирати `$gte`, а не `$gt + offset`.

### Колекція

| Поле | Тип | Значення фільтра |
|---|---|---|
| `age` | `int` | `>= 18` |

### Завдання

Знайти всіх з `age >= 18`, відсортовано за `name`.

### Очікуваний результат

```text
$gte (greater or equals)
  query={'age': {'$gte': 18}}
  count=6
  docs=[Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4), Daria (age=30, city=Kyiv, profile.city=Kyiv, profile.experience=7), Emma (age=45, city=New York, profile.city=New York, profile.experience=15), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20), Hanna (age=61, city=Warsaw, profile.city=Warsaw, profile.experience=21)]
```

### Підказка

`{"age": {"$gte": 18}}` — Bohdan (age 18) тепер у результаті.

### Розв'язання

```python
docs = list(coll.find({"age": {"$gte": 18}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $gte: 18 } }, { _id: 0 }).sort({ name: 1 })
```

### Покрокове пояснення

1. **`$gte` включає межу.** Порівняйте з Вправою 3 (4 збіги) і цією (6 збігів): додано Bohdan (age 18) **і** Chris (age 25, який пройшов `$gte: 18`).
2. **Краще `$gte`, ніж арифметичні трюки** на кшталт `$gt: 17`. З цілими вони еквівалентні, але з float-ами `$gt: 17.0` виключить `17.000000001`, тоді як `$gte: 18.0` однозначний.
3. **Off-by-one** у пагінації й фільтрах «мінімальний вік» майже завжди приходить з помилкового вибору `$gt` vs `$gte` — пишіть межу явно.

---

## Вправа 6 — `$lte` (менше або дорівнює)

### Контекст

Передпенсійна сегментація: лишити всіх, кому до 60 включно.

### Чого ви навчитеся

- Інклюзивній формі `<`.
- Як `$lte` поводиться з відсутнім полем.

### Колекція

| Поле | Тип | Значення фільтра |
|---|---|---|
| `age` | `int` | `<= 60` |

### Завдання

Знайти всіх з `age <= 60`, відсортовано за `name`.

### Очікуваний результат

```text
$lte (less or equals)
  query={'age': {'$lte': 60}}
  count=6
  docs=[Anna (age=17, city=Chicago, profile.city=Chicago, profile.experience=1), Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4), Daria (age=30, city=Kyiv, profile.city=Kyiv, profile.experience=7), Emma (age=45, city=New York, profile.city=New York, profile.experience=15), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20)]
```

### Підказка

`{"age": {"$lte": 60}}` — Farid (60) включений, Hanna (61) — ні.

### Розв'язання

```python
docs = list(coll.find({"age": {"$lte": 60}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find({ age: { $lte: 60 } }, { _id: 0 }).sort({ name: 1 })
```

### Покрокове пояснення

1. **`$lte` включає межу.** Порівняйте з `$lt: 60`, який би прибрав Farid.
2. **Семантика відсутнього поля:** на відміну від `$ne`, `$lte` **не** збігає документи, де поле відсутнє. Mongo може порівнювати лише значення, що існує; відсутні поля тихо виключаються з діапазонних фільтрів.
3. **Індекс:** `{age: 1}` обслужить `$lte: 60` обходом індексу від мінімуму до `60` включно. Якщо додасте `.sort("age", 1)`, in-memory sort не знадобиться.

---

## Вправа 7 — `$in` (значення зі списку)

### Контекст

Регіональний звіт потребує всіх співробітників з офісів **New York або Los Angeles** — два міста, один запит.

### Чого ви навчитеся

- Фільтру за множиною через `$in`.
- Чому `$in` краще, ніж ланцюжок `$or` із `$eq`-ів.

### Колекція

| Поле | Тип | Значення фільтра |
|---|---|---|
| `city` | `string` | `["New York", "Los Angeles"]` |

### Завдання

Знайти людей, чий `city` входить у множину `["New York", "Los Angeles"]`, відсортовано за `name`.

### Очікуваний результат

```text
$in  (in list)
  query={'city': {'$in': ['New York', 'Los Angeles']}}
  count=3
  docs=[Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4), Emma (age=45, city=New York, profile.city=New York, profile.experience=15)]
```

### Підказка

`{"city": {"$in": [...]}}` — значення є списком.

### Розв'язання

```python
docs = list(coll.find({"city": {"$in": ["New York", "Los Angeles"]}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find(
  { city: { $in: ["New York", "Los Angeles"] } },
  { _id: 0 }
).sort({ name: 1 })
```

### Покрокове пояснення

1. **`$in` — це скорочення для `$or` із `$eq`-ів** по одному полю. Mongo оптимізує його в один index range scan, якщо є індекс на `city`.
2. **Список може містити різні типи BSON** (наприклад, `["NY", 5, /regex/]`), але це майже завжди ознака проблем із даними. Тримайте типи однорідними.
3. **Порожній список** `{"city": {"$in": []}}` не збіжить **нічого** (належність до порожньої множини завжди хибна). Дзеркально: `$nin: []` збігає **все**.
4. **`$in` по масиву** збігається, якщо **будь-який елемент** масиву документа є у списку — деталі у `06_array_operators`.

---

## Вправа 8 — `$nin` (значення поза списком)

### Контекст

Звіт «інші локації» — усі, хто **не** в офісах New York або Los Angeles.

### Чого ви навчитеся

- Заперечення `$in`.
- Чому `$nin` має ті ж проблеми з індексами, що й `$ne`.

### Колекція

| Поле | Тип | Значення фільтра |
|---|---|---|
| `city` | `string` | поза `["New York", "Los Angeles"]` |

### Завдання

Знайти всіх, чий `city` **не** у множині `["New York", "Los Angeles"]`, відсортовано за `name`.

### Очікуваний результат

```text
$nin (not in list)
  query={'city': {'$nin': ['New York', 'Los Angeles']}}
  count=4
  docs=[Anna (age=17, city=Chicago, profile.city=Chicago, profile.experience=1), Daria (age=30, city=Kyiv, profile.city=Kyiv, profile.experience=7), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20), Hanna (age=61, city=Warsaw, profile.city=Warsaw, profile.experience=21)]
```

### Підказка

`{"city": {"$nin": [...]}}` — протилежність `$in`.

### Розв'язання

```python
docs = list(coll.find({"city": {"$nin": ["New York", "Los Angeles"]}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find(
  { city: { $nin: ["New York", "Los Angeles"] } },
  { _id: 0 }
).sort({ name: 1 })
```

### Покрокове пояснення

1. **`$nin` включає документи, де поле відсутнє** — як і `$ne`. Якщо потрібні лише ті, що мають поле, додайте `{"city": {"$exists": true}}` (див. урок `05_check_operators`).
2. **Індексація:** `$nin` — це заперечення, тож планувальник зазвичай не може ефективно скористатися індексом. Для довгих чорних списків матеріалізуйте доповнення (use `$in` на білий список).
3. **`$nin: []`** збігає кожен документ — дзеркально до `$in: []`.

---

## Вправа 9 — Вкладений `$eq` на `profile.city`

### Контекст

Через історичні причини у `profile` зберігається друге поле «city». CRM має витягнути працівників за містом **профілю**, а не верхнього рівня.

### Чого ви навчитеся

- Шляхам через крапку у вкладені документи.
- Що оператори працюють однаково для вкладених полів.

### Колекція

| Шлях | Тип | Значення фільтра |
|---|---|---|
| `profile.city` | `string` | `"New York"` |

### Завдання

Знайти людей, у яких `profile.city == "New York"`, відсортовано за `name`.

### Очікуваний результат

```text
Nested $eq on profile.city
  query={'profile.city': {'$eq': 'New York'}}
  count=2
  docs=[Bohdan (age=18, city=New York, profile.city=New York, profile.experience=2), Emma (age=45, city=New York, profile.city=New York, profile.experience=15)]
```

### Підказка

Шлях обгорніть **лапками** і поставте крапку: `"profile.city"`.

### Розв'язання

```python
docs = list(coll.find({"profile.city": {"$eq": "New York"}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find(
  { "profile.city": { $eq: "New York" } },
  { _id: 0 }
).sort({ name: 1 })
```

### Покрокове пояснення

1. **Точкова нотація** — канонічний спосіб адресувати поля у суб-документах. У Python ключ має бути **рядком** (`"profile.city"`) — `profile.city` як Python-вираз не має сенсу, бо змінної `profile` не існує.
2. **Рівність суб-документа vs рівність шляхом:** `{"profile": {"city": "New York"}}` — це **не** те саме, що `{"profile.city": "New York"}`. Перше порівнює *увесь* суб-документ за точною формою і порядком — і провалиться, якщо у `profile` ще є `experience` чи `role`. Завжди беріть dot-notation, якщо вам реально не потрібна повноекземплярна рівність.
3. **Індекси на вкладених шляхах** будуються так само: `db.collection.createIndex({"profile.city": 1})` — звичайний ascending index по вкладеному полю.

---

## Вправа 10 — Вкладений `$gte` на `profile.experience`

### Контекст

Фільтр сеньйорності для внутрішнього хакатона — у наставники йдуть лише ті, у кого **≥ 10 років** досвіду.

### Чого ви навчитеся

- Поєднанню діапазонних операторів із точковою нотацією.
- Що фільтри за досвідом часто потребують tie-breaker сортування.

### Колекція

| Шлях | Тип | Значення фільтра |
|---|---|---|
| `profile.experience` | `int` | `>= 10` |

### Завдання

Знайти всіх з `profile.experience >= 10`, відсортовано за `name`.

### Очікуваний результат

```text
Nested $gte on profile.experience
  query={'profile.experience': {'$gte': 10}}
  count=3
  docs=[Emma (age=45, city=New York, profile.city=New York, profile.experience=15), Farid (age=60, city=Berlin, profile.city=Berlin, profile.experience=20), Hanna (age=61, city=Warsaw, profile.city=Warsaw, profile.experience=21)]
```

### Підказка

Той самий `$gte` — просто інше (вкладене) поле.

### Розв'язання

```python
docs = list(coll.find({"profile.experience": {"$gte": 10}}, {"_id": 0}).sort("name", 1))
```

```javascript
db.selection_queries_people.find(
  { "profile.experience": { $gte: 10 } },
  { _id: 0 }
).sort({ name: 1 })
```

### Покрокове пояснення

1. **Оператори не залежать від поля.** Якщо ви вже знаєте `$gte` для верхнього рівня, він так само працює на `profile.experience`.
2. **Відсутнє поле:** якщо у частини документів немає `profile.experience`, вони мовчки виключаються (те саме правило, що у Вправі 6).
3. **Tie-break при сортуванні:** з трьома збігами проблеми не видно, але на більшому датасеті додавайте `.sort([("profile.experience", -1), ("name", 1)])`, щоб рядки з однаковим досвідом мали стабільний порядок.

---

## Вправа 11 — Вкладений `$in` на `profile.role`

### Контекст

Огляд підвищень: всі, у кого `profile.role` — **developer** або **architect**. Саме ці дві ролі підлягають переходу на наступний рівень кар'єри.

### Чого ви навчитеся

- Поєднанню `$in` із точковою нотацією.
- Чому поля-енуми ідеальні для `$in`.

### Колекція

| Шлях | Тип | Значення фільтра |
|---|---|---|
| `profile.role` | `string` | `["developer", "architect"]` |

### Завдання

Знайти людей з `profile.role` у `["developer", "architect"]`, відсортовано за `name`.

### Очікуваний результат

```text
Nested $in on profile.role
  query={'profile.role': {'$in': ['developer', 'architect']}}
  count=2
  docs=[Chris (age=25, city=Los Angeles, profile.city=Los Angeles, profile.experience=4), Emma (age=45, city=New York, profile.city=New York, profile.experience=15)]
```

### Підказка

Скомбінуйте `"profile.role"` (шлях) із `{"$in": [...]}` (оператор).

### Розв'язання

```python
docs = list(coll.find(
    {"profile.role": {"$in": ["developer", "architect"]}},
    {"_id": 0},
).sort("name", 1))
```

```javascript
db.selection_queries_people.find(
  { "profile.role": { $in: ["developer", "architect"] } },
  { _id: 0 }
).sort({ name: 1 })
```

### Покрокове пояснення

1. **Поля-енуми** (ролі, статуси, категорії) — канонічний кейс для `$in`. Це значно чистіше, ніж ланцюжок `$or` із `$eq`-ів.
2. **Чутливість до регістру:** `$in` стандартно порівнює рядки байт у байт. Щоб збігати «Developer» / «DEVELOPER», або нормалізуйте при записі, або користуйтесь `$regex` із `$options: "i"` (див. урок `04_string_operators`).
3. **Вибір індексу для складених запитів:** якщо ви типово комбінуєте `profile.role` з іншим предикатом, побудуйте складений індекс на кшталт `{"profile.role": 1, "profile.experience": -1}` — він обслужить і фільтр, і сортування за один прохід.

---

## Розв'язання типових проблем

| Симптом | Імовірне рішення |
|---|---|
| `$eq` на числовому полі повертає 0 рядків | Можливо, у базі значення — рядок. Перевірте через `$type` (урок `05_check_operators`). |
| `$ne` повертає набагато більше, ніж очікувалося | Він включає документи, де поле **відсутнє**. Додайте `$exists: true`, щоб виключити. |
| Вкладений `$eq` дає 0 рядків | Скоріш за все ви написали `{"profile": {"city": "..."}}` (рівність всього документа). Використайте dot-notation. |
| `$in: []` повертає 0 | Це правильно: належність до порожньої множини завжди хибна. |
| Порядок виглядає випадково | Додайте явний `.sort([...])` — Mongo ніколи не сортує без запиту. |

Запустити всі приклади: `python 04_mongodb/02_selection_queries/example.py`.
