# Оператори вибору в ODM (`10_odm/01_selection_operators`)

> Translation / Переклад: [English](../../../../../04_mongodb/10_odm/01_selection_operators/selection_operators_odm.md)

Ці вправи проходять оператори вибору MongoDB **через ODM** — а саме **MongoEngine**. Там, де урок `08_filtering` користується «сирими» PyMongo-запитами (`{age: {$gt: 18}}`), тут ті ж самі фільтри виражаються через атрибути Python-класу та клас-візитор `Q`. Дротовий запит до MongoDB при цьому однаковий; синтаксис — зовсім інший.

Готовий файл-компаньйон: [`10_odm/01_selection_operators/example.py`](../../../../../04_mongodb/10_odm/01_selection_operators/example.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/01_selection_operators/example.py
```

З'єднання за замовчуванням (можна перевизначити змінними оточення):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Колекція: `odm_selection_operators_people`

---

## Модель документа і сід

```python
from mongoengine import BooleanField, Document, IntField, StringField, connect

class Person(Document):
    name = StringField(required=True, max_length=128)
    age = IntField(required=True, min_value=0)
    status = StringField(required=True, max_length=32)
    active = BooleanField(required=True, default=True)
    email = StringField(required=False, max_length=256)

    meta = {"collection": "odm_selection_operators_people"}
```

Сід (скрипт скидає і перевставляє при кожному запуску):

| `name` | `age` | `status` | `active` | `email` |
|---|---|---|---|---|
| Vlad | 25 | active | True | vlad@gmail.com |
| Anna | 30 | pending | True | — (відсутнє) |
| Bohdan | 17 | deleted | False | bohdan@example.com |
| Chris | 19 | active | True | chris@gmail.com |
| Daria | 65 | pending | False | — (відсутнє) |

Допоміжна функція друку зі скрипта:

```python
def print_result(label: str, qs) -> None:
    names = [d.name for d in qs.order_by("name")]
    print(f"{label}: count={len(names)} -> {names}")
```

---

## Шаблон вправи (повторюється у кожному розділі нижче)

| Секція | Що дає |
|---|---|
| **Контекст** | Навіщо реальному застосунку цей фільтр. |
| **Чого ви навчитеся** | Який саме суфікс MongoEngine `__lookup` і базовий оператор. |
| **Документ** | Які поля задіяні. |
| **Завдання** | Конкретний предикат. |
| **Очікуваний результат** | Реальний захоплений вивід. |
| **Підказка** | Точний суфікс. |
| **Розв'язання** | MongoEngine (Python) і `mongosh` поряд. |
| **Покрокове пояснення** | Як ODM переписує запит, і типові помилки. |

---

## Вправа 1 — `$eq` і `$ne`

### Контекст

Профіль шукає запис з `age = 25` (точна рівність), а аудит виключає всіх з `age = 30`.

### Чого ви навчитеся

- Що звичайний kwarg (`age=25`) — це `$eq`.
- Що суфікс `__ne` мапиться на `$ne`.

### Документ

| Поле | Тип | Примітка |
|---|---|---|
| `age` | int | В обох запитах. |

### Завдання

1. `Person.objects(age=25)`
2. `Person.objects(age__ne=30)`

### Очікуваний результат

```text
$eq   age=25: count=1 -> ['Vlad']
$ne   age!=30: count=4 -> ['Bohdan', 'Chris', 'Daria', 'Vlad']
```

### Підказка

`field=value` → `$eq`. `field__ne=value` → `$ne`. Подвійне підкреслення — це роздільник MongoEngine.

### Розв'язання

```python
print_result("$eq   age=25",     Person.objects(age=25))
print_result("$ne   age!=30",    Person.objects(age__ne=30))
```

```javascript
db.odm_selection_operators_people.find({ age: { $eq: 25 } }, { _id: 0, name: 1 }).sort({ name: 1 });
db.odm_selection_operators_people.find({ age: { $ne: 30 } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Покрокове пояснення

1. **`age=25` — короткий запис.** Драйвер отримує `{age: 25}`, MongoDB трактує його як `{age: {$eq: 25}}` — семантично еквівалентно.
2. **`age__ne=30` приймає `null`.** На відміну від SQL, `$ne 30` поверне рядки з відсутнім `age` — «нічого» не дорівнює 30.
3. **`__` — суфіксний роздільник, не «вкладений».** MongoEngine резервує `__` для операторів (`__ne`, `__gt`, …). Для вкладених полів `__` теж використовують: `profile__city="Kyiv"` стає `{"profile.city": "Kyiv"}`. На практиці колізій майже не буває.

---

## Вправа 2 — Діапазонні порівняння (`$gt`, `$gte`, `$lt`, `$lte`)

### Контекст

Ті ж чотири порівняння трапляються скрізь: «старші за 18», «18 і старші», «молодші за 65», «до 65 включно».

### Чого ви навчитеся

- Суфіксам `__gt`, `__gte`, `__lt`, `__lte`.
- MongoEngine мапить їх на відповідні `$`-оператори.

### Документ

| Поле | Тип | Примітка |
|---|---|---|
| `age` | int | Ключ діапазону. |

### Завдання

Виконати чотири діапазонні запити і вивести лічильник.

### Очікуваний результат

```text
$gt   age>18: count=4 -> ['Anna', 'Chris', 'Daria', 'Vlad']
$gte  age>=18: count=4 -> ['Anna', 'Chris', 'Daria', 'Vlad']
$lt   age<65: count=4 -> ['Anna', 'Bohdan', 'Chris', 'Vlad']
$lte  age<=65: count=5 -> ['Anna', 'Bohdan', 'Chris', 'Daria', 'Vlad']
```

(Bohdan — 17, Chris — 19; `>18` і `>=18` тут збігаються, бо нікому не точно 18.)

### Підказка

`age__gt=18` і т. д. Суфікс — це повне ім'я в нижньому регістрі.

### Розв'язання

```python
print_result("$gt   age>18",   Person.objects(age__gt=18))
print_result("$gte  age>=18",  Person.objects(age__gte=18))
print_result("$lt   age<65",   Person.objects(age__lt=65))
print_result("$lte  age<=65",  Person.objects(age__lte=65))
```

```javascript
db.odm_selection_operators_people.find({ age: { $gt:  18 } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ age: { $gte: 18 } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ age: { $lt:  65 } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ age: { $lte: 65 } }).sort({ name: 1 });
```

### Покрокове пояснення

1. **Суфікс однозначний.** `age__gt=18` — це завжди діапазон, MongoEngine не сприйме `gt` як «вкладене поле».
2. **Типобезпечні порівняння.** Оскільки `age` — `IntField`, MongoEngine відхилить `age__gt="18"` (рядок) ще до запиту.
3. **Жодного `BETWEEN`.** Зв'яжіть два предикати: `Person.objects(age__gte=18, age__lt=65)` — неявний AND між kwargs.

---

## Вправа 3 — `$in` і `$nin`

### Контекст

Два правила: «вважати `active` і `pending` за валідних» (whitelist) і «виключити soft-deleted» (blacklist).

### Чого ви навчитеся

- Суфіксам `__in` і `__nin`.
- MongoEngine згортає список праворуч у драйверні `$in` / `$nin`.

### Документ

| Поле | Тип | Примітка |
|---|---|---|
| `status` | string | Перевіряємо на whitelist/blacklist. |

### Завдання

1. `status in ["active", "pending"]`.
2. `status not in ["deleted"]`.

### Очікуваний результат

```text
$in   status in [active,pending]: count=4 -> ['Anna', 'Chris', 'Daria', 'Vlad']
$nin  status not in [deleted]: count=4 -> ['Anna', 'Chris', 'Daria', 'Vlad']
```

(Bohdan — єдиний `deleted`; обидва запити його відкидають.)

### Підказка

`status__in=[...]` і `status__nin=[...]`. Список Python надходить як аргумент `$in` / `$nin`.

### Розв'язання

```python
print_result("$in   active|pending",  Person.objects(status__in=["active", "pending"]))
print_result("$nin  not deleted",     Person.objects(status__nin=["deleted"]))
```

```javascript
db.odm_selection_operators_people.find({ status: { $in:  ["active", "pending"] } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ status: { $nin: ["deleted"] } }).sort({ name: 1 });
```

### Покрокове пояснення

1. **`$in` проти масиву — перевірка перетину.** Якби `status` був списком, `$in` дав би збіг, коли **будь-який** елемент списку є у правій множині.
2. **`$nin` бере й «відсутні» поля** — як у `08_filtering`, Вправа 4. Додавайте `__exists=True`, якщо відсутніх включати не треба.
3. **Конвертуйте множини в списки.** `status__in=set([...])` в CPython працює, але формально драйвер приймає лише списки; `list(...)` — портабельно.

---

## Вправа 4 — Логіка через `Q` (`$and`, `$or`, `$not`)

### Контекст

Три звіти: «дорослі, ще активні», «діти або деактивовані», «всі, кому не менше 18». Усі три потребують явної булевої композиції, бо kwargs виражають лише неявний AND.

### Чого ви навчитеся

- Класу `mongoengine.queryset.visitor.Q`.
- `&` для `$and`, `|` для `$or`, `~` для `$not`.

### Документ

| Поле | Тип | Примітка |
|---|---|---|
| `age` | int | — |
| `active` | bool | — |

### Завдання

1. `Q(age__gt=18) & Q(active=True)` — дорослі, що активні.
2. `Q(age__lt=18) | Q(active=False)` — діти АБО неактивні.
3. `~Q(age__lt=18)` — не молодші 18.

### Очікуваний результат

```text
$and  age>18 AND active=True: count=3 -> ['Anna', 'Chris', 'Vlad']
$or   age<18 OR active=False: count=2 -> ['Bohdan', 'Daria']
$not  NOT(age<18): count=4 -> ['Anna', 'Chris', 'Daria', 'Vlad']
```

> Примітка: у деяких релізах MongoEngine форма `~Q(...)` падає з `TypeError: bad operand type for unary ~: 'Q'`. Еквівалент `Person.objects(age__gte=18)` працює завжди і дає той самий набір.

### Підказка

`from mongoengine.queryset.visitor import Q`. Композиція через `&`, `|`, `~`.

### Розв'язання

```python
from mongoengine.queryset.visitor import Q

print_result("$and  age>18 AND active",  Person.objects(Q(age__gt=18) & Q(active=True)))
print_result("$or   age<18 OR !active",  Person.objects(Q(age__lt=18) | Q(active=False)))
# `~Q(age__lt=18)` семантично еквівалентне `age__gte=18`:
print_result("$not  NOT(age<18)",        Person.objects(age__gte=18))
```

```javascript
db.odm_selection_operators_people.find(
  { $and: [ { age: { $gt: 18 } }, { active: true } ] }
).sort({ name: 1 });

db.odm_selection_operators_people.find(
  { $or:  [ { age: { $lt: 18 } }, { active: false } ] }
).sort({ name: 1 });

db.odm_selection_operators_people.find(
  { age: { $not: { $lt: 18 } } }
).sort({ name: 1 });
```

### Покрокове пояснення

1. **Без `Q` немає `$or`.** Звичайні kwargs дають лише AND. `Person.objects(age__lt=18, active=False)` — це `AND`, не `OR`.
2. **Дужки важливі.** `Q(a) & Q(b) | Q(c)` за пріоритетом Python (`&` сильніше за `|`) парситься як `(Q(a) & Q(b)) | Q(c)`. Якщо сумніваєтесь — обгортайте явно.
3. **`~Q` — заперечення виразу.** Під капотом виходить `$not` навколо обгорнутого. Якщо у вашій версії `~Q` не працює — переписуйте на позитивну форму (`age__lt=18` → `age__gte=18`).
4. **`Q`-композиція — імутабельна.** Повертає нові об'єкти; перевикористовувати безпечно.

---

## Вправа 5 — `$exists`

### Контекст

Аудит: користувачі, у яких реально є `email` (можемо написати), і ті, у кого нема (треба запитати).

### Чого ви навчитеся

- Суфіксу `__exists`.
- Чому «поле відсутнє» і «поле `None`» — різні речі.

### Документ

| Поле | Тип | Примітка |
|---|---|---|
| `email` | string \| відсутнє | У Anna і Daria — нема. |

### Завдання

Повернути користувачів, у яких поле `email` присутнє.

### Очікуваний результат

```text
$exists email exists: count=3 -> ['Bohdan', 'Chris', 'Vlad']
```

(Anna і Daria — без `email`, бо в `Person.objects.insert(...)` для них його не передали.)

### Підказка

`email__exists=True`. `False` — для відсутнього.

### Розв'язання

```python
print_result("$exists has email",     Person.objects(email__exists=True))
print_result("$exists no email",      Person.objects(email__exists=False))
```

```javascript
db.odm_selection_operators_people.find({ email: { $exists: true } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ email: { $exists: false } }).sort({ name: 1 });
```

### Покрокове пояснення

1. **`$exists` перевіряє лише наявність.** Документ з `email: null` (явним) — «присутній», `__exists=True` його поверне.
2. **MongoEngine і `required` поля.** `email` оголошений `required=False`, тож збереження без нього дозволене. `required=True` спричинило б `ValidationError` під час `.save()`.
3. **Не плутайте з `__eq=None`.** `email__eq=None` шукає явний `null`, а не «відсутнє поле».

---

## Вправа 6 — `$regex`

### Контекст

Маркетинг шукає всіх користувачів, чиє ім'я починається з `"Vlad"`.

### Чого ви навчитеся

- Суфіксу `__regex` і його зв'язку з `$regex`.
- Закріпленню шаблону на початку для індекса.

### Документ

| Поле | Тип | Примітка |
|---|---|---|
| `name` | string | Шукаємо за патерном. |

### Завдання

Повернути користувачів, чий `name` відповідає `^Vlad`.

### Очікуваний результат

```text
$regex name starts with Vlad: count=1 -> ['Vlad']
```

### Підказка

`name__regex=r"^Vlad"`. Raw-string зберігає `^` і `\`.

### Розв'язання

```python
print_result("$regex ^Vlad",  Person.objects(name__regex=r"^Vlad"))

# Регістронечутливий варіант — iregex:
print_result("$regex ^vlad (case-insensitive)",
             Person.objects(name__iregex=r"^vlad"))
```

```javascript
db.odm_selection_operators_people.find({ name: { $regex: "^Vlad" } }).sort({ name: 1 });
db.odm_selection_operators_people.find({ name: /^vlad/i }).sort({ name: 1 });
```

### Покрокове пояснення

1. **`__regex` — регістрозалежний.** Для регістронечутливого — `__iregex` (або `$options: "i"`).
2. **Шаблон, закріплений на початку, дружній до індексу.** `^Vlad` користує звичайний індекс `{name: 1}`. `Vlad$` чи `Vl.*ad` — ні.
3. **Екрануйте літеральні спецсимволи.** Літеральна крапка — `\.`: `r"@gmail\.com$"`.
4. **Шорткати `__startswith`, `__endswith`, `__contains`.** MongoEngine має зрозумілі псевдоніми для типових якорів регулярних виразів.

---

## Шпаргалка

| Оператор | Сирий запит | Kwarg MongoEngine |
|---|---|---|
| `$eq` | `{age: 25}` | `age=25` |
| `$ne` | `{age: {$ne: 30}}` | `age__ne=30` |
| `$gt` / `$gte` | `{age: {$gt: 18}}` | `age__gt=18` |
| `$lt` / `$lte` | `{age: {$lt: 65}}` | `age__lt=65` |
| `$in` / `$nin` | `{status: {$in: [...]}}` | `status__in=[...]` |
| `$and` | `{$and: [...]}` | `Q(...) & Q(...)` |
| `$or` | `{$or: [...]}` | `Q(...) \| Q(...)` |
| `$not` | `{f: {$not: ...}}` | `~Q(...)` (або переписати) |
| `$exists` | `{f: {$exists: true}}` | `f__exists=True` |
| `$regex` | `{f: {$regex: "..."}}` | `f__regex=r"..."` |

## Розв'язання проблем

| Симптом | Імовірне виправлення |
|---|---|
| `TypeError: bad operand type for unary ~: 'Q'` | Стара версія MongoEngine. Перепишіть `~Q(age__lt=18)` як `age__gte=18`. |
| `OperationError` при `.save()` | Не вказане `required=True` поле. Заповніть або послабте модель. |
| Неявний AND, де треба OR | Використовуйте `Q(...) \| Q(...)`. Прості kwargs — це AND. |
| `$exists: true` повертає документи, що ви б назвали «порожніми» | У них значення `null`. Комбінуйте з `__ne=None`. |
| Регулярка повільна на великій колекції | Закріплюйте на початку (`^...`) і індексуйте поле. |
