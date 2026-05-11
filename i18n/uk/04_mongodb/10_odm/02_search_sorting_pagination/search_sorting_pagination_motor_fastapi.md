# Пошук, сортування, пагінація (`10_odm/02_search_sorting_pagination`)

> Translation / Переклад: [English](../../../../../04_mongodb/10_odm/02_search_sorting_pagination/search_sorting_pagination_motor_fastapi.md)

Цей модуль демонструє:

- Пошук (текстова фільтрація через regex)
- Сортування (`name`, `price`, `rating`)
- Пагінацію (`page`, `page_size`)

Стек технологій:

- **FastAPI**
- **Motor** (асинхронний драйвер MongoDB)
- **Pydantic**

Значення за замовчуванням:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

Колекція:

- `odm_search_sort_pagination_products`

## Встановлення

```bash
pip install -r 04_mongodb/requirements.txt
```

## Запуск API

З кореня репозиторію:

```bash
uvicorn main:app --reload --app-dir 04_mongodb/10_odm/02_search_sorting_pagination
```

Відкрийте:

- Swagger UI: `http://127.0.0.1:8000/docs`
- Endpoint: `GET /products`

## Приклади запитів

```bash
# дефолтний список
curl "http://127.0.0.1:8000/products"

# пошук
curl "http://127.0.0.1:8000/products?q=phone"

# сортування за price за спаданням
curl "http://127.0.0.1:8000/products?sort_by=price&sort_dir=desc"

# сторінка 2, розмір сторінки 3
curl "http://127.0.0.1:8000/products?page=2&page_size=3"
```
