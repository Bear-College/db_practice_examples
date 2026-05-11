# Aggregation Functions with Motor (`10_odm/04_agregation_functions`)

> Translation / Переклад: [Українська](../../../i18n/uk/04_mongodb/10_odm/04_agregation_functions/agregation_functions_motor.md)

These exercises walk through the **MongoDB aggregation framework** from a Motor (async) callsite. The companion script runs two pipelines that together exercise the eight most-used pipeline operators: `$match`, `$group`, `$sum`, `$avg`, `$count`, `$max`, `$min`, `$sort`, and `$project`.

Runnable companion file: [`10_odm/04_agregation_functions/main.py`](main.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/04_agregation_functions/main.py
```

Default connection (override with env vars):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Collection: `odm_aggregation_orders`

---

## Collection: `odm_aggregation_orders`

The seed inserts six orders across four customers and three categories:

| `order_id` | `customer` | `category` | `amount` | `quantity` |
|---|---|---|---|---|
| ORD-001 | Anna | Laptop | 1200 | 1 |
| ORD-002 | Anna | Laptop | 900 | 1 |
| ORD-003 | Bohdan | Smartphone | 800 | 2 |
| ORD-004 | Chris | Smartphone | 700 | 1 |
| ORD-005 | Daria | Tablet | 500 | 3 |
| ORD-006 | Daria | Tablet | 450 | 1 |

The runner is:

```python
async def run_pipeline(coll, title, pipeline):
    docs = await coll.aggregate(pipeline).to_list(length=100)
    print(f"\n{title}")
    for d in docs:
        print(f"  {d}")
```

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | The business report this pipeline supports. |
| **What you'll learn** | The aggregation stages and accumulators trained. |
| **Collection in play** | Fields used by the pipeline. |
| **Task** | The numbered stage list that builds the pipeline. |
| **Expected result** | The real output of `python main.py`. |
| **Hint** | The handful of `$`-operators you'll need. |
| **Solution** | Motor (Python) and `mongosh` versions. |
| **Step-by-step explanation** | What each stage does and the typical mistakes. |

---

## Exercise 1 — Revenue by category (`$match → $group → $sort → $project`)

### Context

The finance team wants a one-shot per-category report of orders above $400: how many orders, total revenue, average ticket, the cheapest and the most expensive order in each category, sorted by total revenue.

### What you'll learn

- Filtering before grouping with `$match` (the aggregation analogue of `WHERE`).
- Grouping with `$group`, accumulating with `$sum`, `$avg`, `$count`, `$max`, `$min`.
- Sorting result groups with `$sort` (analogue of `ORDER BY`).
- Reshaping the output with `$project` (analogue of the `SELECT` clause).

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `category` | string | Group key. |
| `amount` | int | Accumulated. |

### Task

Build a pipeline:

1. **`$match`** — keep orders with `amount >= 400`.
2. **`$group`** — group by `$category`; accumulate `total_revenue` (`$sum $amount`), `avg_revenue` (`$avg $amount`), `orders_count` (`$count`), `max_order` (`$max $amount`), `min_order` (`$min $amount`).
3. **`$sort`** — by `total_revenue` descending.
4. **`$project`** — rename `_id` to `category`, drop the original `_id`, keep all accumulated fields.

### Expected result

```text
Revenue by category ($match + $group + $sum + $count + $avg + $max/$min + $sort + $project)
  {'total_revenue': 2100, 'avg_revenue': 1050.0, 'orders_count': 2, 'max_order': 1200, 'min_order': 900, 'category': 'Laptop'}
  {'total_revenue': 1500, 'avg_revenue': 750.0, 'orders_count': 2, 'max_order': 800, 'min_order': 700, 'category': 'Smartphone'}
  {'total_revenue': 950, 'avg_revenue': 475.0, 'orders_count': 2, 'max_order': 500, 'min_order': 450, 'category': 'Tablet'}
```

Laptop tops the chart at $2,100. Notice that all six orders are kept (the smallest is $450, still ≥ 400), so the report includes the whole dataset.

### Hint

Inside `$group` the new `_id` field is the grouping key. Express it as `"$category"` (a *field path*), not `"category"`. Each accumulator is a `{$op: <expression>}` document.

### Solution

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

### Step-by-step explanation

1. **`$match` first, always.** Filtering early means the rest of the pipeline processes fewer documents — and `$match` *before* `$group` can use indexes.
2. **`$group._id` is mandatory.** Use `null` to group everything into one bucket; here we use `$category`.
3. **`$count: {}` vs `$sum: 1`.** Both produce the row count. `$count` is the newer (5.0+) sugar; older versions used `{$sum: 1}`.
4. **`$avg` ignores nulls.** If half the rows had `amount: null`, the average would be over the *non-null* subset, not over the whole group.
5. **`$sort` after `$group` operates on grouped documents.** The `_id` is whatever you put there (`"Laptop"`, `"Smartphone"`, `"Tablet"` here) — sortable as a string.
6. **`$project` reshapes.** `"category": "$_id"` *copies* the value of `_id` into a new field named `category`. Then `"_id": 0` discards the original.
7. **Stage order matters.** Swap `$sort` and `$group` and you sort 6 raw documents instead of 3 grouped ones — different cost, different semantics.

---

## Exercise 2 — Orders by customer (`$group → $sum(quantity) → $sort → $project`)

### Context

The CRM wants per-customer totals: order count, total items shipped, total amount spent — sorted by who spent the most.

### What you'll learn

- Two `$sum` accumulators on different fields in one `$group`.
- Reusing `$count` and `$project` from Exercise 1.

### Collection in play

| Field | Type | Notes |
|---|---|---|
| `customer` | string | Group key. |
| `quantity` | int | Summed. |
| `amount` | int | Summed. |

### Task

1. **`$group`** by `$customer` with `orders_count` (`$count`), `total_items` (`$sum $quantity`), `total_spent` (`$sum $amount`).
2. **`$sort`** by `total_spent` descending.
3. **`$project`** rename `_id` → `customer`.

### Expected result

```text
Orders grouped by customer ($group + $sum(quantity) + $sort + $project)
  {'orders_count': 2, 'total_items': 2, 'total_spent': 2100, 'customer': 'Anna'}
  {'orders_count': 2, 'total_items': 4, 'total_spent': 950, 'customer': 'Daria'}
  {'orders_count': 1, 'total_items': 2, 'total_spent': 800, 'customer': 'Bohdan'}
  {'orders_count': 1, 'total_items': 1, 'total_spent': 700, 'customer': 'Chris'}
```

Anna leads in `total_spent` (two laptops = $2,100), but Daria leads in `total_items` (4 tablets across two orders).

### Hint

You can have **as many accumulator fields as you want** inside a single `$group` — one for each metric you need.

### Solution

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

### Step-by-step explanation

1. **No `$match` here.** All six orders are aggregated. Add a `$match` first to scope by date, status, etc.
2. **`$sum: "$amount"` vs `$sum: 1`.** The former sums the field; the latter counts rows. They differ when the field contains numbers.
3. **`$sort` after `$group` is a *blocking* stage.** If the grouped set is huge, you'll need either an index that supports the pre-aggregation `$match` or an `allowDiskUse=True` option.
4. **`$project` ordering matters in the input.** When you both promote `_id` to `customer` *and* drop the original `_id`, the result document fields are emitted in the order you list them. Output ordering rarely matters semantically but does matter for visual diffs.

---

## Quick reference

| Stage / Accumulator | Job | Example |
|---|---|---|
| `$match` | filter rows | `{$match: {amount: {$gte: 400}}}` |
| `$group` | bucket by key | `{$group: {_id: "$category", n: {$count: {}}}}` |
| `$sum` | total | `{$sum: "$amount"}` (or `{$sum: 1}` to count) |
| `$avg` | mean | `{$avg: "$amount"}` |
| `$count` | row count per group | `{$count: {}}` (5.0+) |
| `$max` / `$min` | extreme | `{$max: "$amount"}` |
| `$sort` | reorder | `{$sort: {total: -1}}` |
| `$project` | reshape | `{$project: {_id: 0, category: "$_id", total: 1}}` |

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `unknown group operator '$count'` | MongoDB pre-5.0. Replace with `{$sum: 1}`. |
| `_id` is a string when you wanted an object | Group on `"$field"` returns the field's value. To group on multiple fields, use `{_id: {a: "$a", b: "$b"}}`. |
| `Sort exceeded memory limit` | Either pre-filter with `$match` + an index, or allow disk: `db.coll.aggregate(pipeline, {allowDiskUse: true})`. |
| `$avg` returns null | All values for that group were null. Add `$match` to require a non-null field. |
| `$project: {a: 1, _id: 0}` drops `a` | Field order doesn't matter for inclusion. The bug is somewhere else — check the stage upstream. |
| Output rows in random order | `$group` does not preserve input order. Add `$sort` after `$group`. |
