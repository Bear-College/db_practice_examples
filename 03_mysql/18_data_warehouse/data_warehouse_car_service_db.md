# Data Warehouse — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/18_data_warehouse/data_warehouse_car_service_db.md)

This lesson introduces a **data warehouse** layer as a **star schema** inside `car_service_db`: dimension tables (`dw_dim_*`) and a fact table (`dw_fact_work_orders`) loaded from operational tables. You will see how ETL copies a bounded slice of OLTP data and how analytical queries join dimensions to facts.

Companion script: [`18_data_warehouse/car_service_data_warehouse_examples.sql`](car_service_data_warehouse_examples.sql).

```bash
mysql -u root car_service_db < 03_mysql/18_data_warehouse/car_service_data_warehouse_examples.sql
```

---

## Star schema overview

```text
                    dw_dim_customer
                           |
                           | customer_sk
                           v
    dw_dim_brand ----> dw_fact_work_orders
         |                    |
    brand_sk              measures:
                            total_cost, status
                            grain: 1 row / work order
```

| Object | Role |
|--------|------|
| **Fact** `dw_fact_work_orders` | Numeric measures + foreign keys to dimensions; grain = one row per work order |
| **Dimension** `dw_dim_customer` | Who — attributes: `last_name`, `email` |
| **Dimension** `dw_dim_brand` | What vehicle brand — attribute: `brand_name` |
| **ETL** | `INSERT … SELECT` from `customers`, `car_brands`, `work_orders` |

---

## Exercise 1 — Create dimension and fact tables

### Context

Before any report runs, the warehouse team defines **conformed dimensions** and a **fact table** with a clear grain (one row per work order).

### What you'll learn

- Surrogate keys (`customer_sk`, `brand_sk`) vs natural keys (`customer_id`, `brand_id`).
- Fact table holds **measures** (`total_cost`) and **degenerate dimensions** (`status`, `work_order_id`).

### Tables in play

| Table | Columns |
|---|---|
| `dw_dim_customer` | `customer_sk`, `customer_id`, `last_name`, `email` |
| `dw_dim_brand` | `brand_sk`, `brand_id`, `brand_name` |
| `dw_fact_work_orders` | `work_order_id`, `customer_sk`, `brand_sk`, `status`, `total_cost` |

### Task

Create the three `dw_*` tables with primary keys, unique business keys on dimensions, and foreign keys from fact to dimensions.

### Expected result

Tables appear in `SHOW TABLES LIKE 'dw_%';` — no row output until Exercise 3.

### Hint

Use `AUTO_INCREMENT` surrogate keys on dimensions; fact uses `work_order_id` as primary key.

### Solution

See the `CREATE TABLE` blocks in [`car_service_data_warehouse_examples.sql`](car_service_data_warehouse_examples.sql) (sections 1–2).

### Step-by-step explanation

1. **Surrogate keys** insulate the warehouse from OLTP id changes and support slowly changing dimensions later.
2. **`UNIQUE (customer_id)`** on the dimension is the **business key** used during ETL lookup.
3. **Foreign keys** document the star; in huge warehouses they are sometimes omitted for load speed.

---

## Exercise 2 — ETL load from operational tables

### Context

Nightly batch job: copy customers, brands, and work orders from OLTP into the warehouse tables (here: a bounded slice for class speed).

### What you'll learn

- ETL as `INSERT … SELECT` with joins to resolve surrogate keys.
- Load order: dimensions first, then facts.

### Tables in play

| Source (OLTP) | Target (DW) |
|---|---|
| `customers` | `dw_dim_customer` |
| `car_brands` | `dw_dim_brand` |
| `work_orders` + `vehicles` | `dw_fact_work_orders` |

### Task

Load customers `id 1–500`, brands `1–300`, facts for work orders `id 1–5000`. Return `COUNT(*)` from `dw_fact_work_orders`.

### Expected result (real rows from the dump)

```text
+-----------+
| fact_rows |
+-----------+
|       500 |
+-----------+
```

### Hint

Join `work_orders → vehicles → dw_dim_customer` and `dw_dim_brand` when inserting facts.

### Solution

```sql
INSERT INTO dw_dim_customer (customer_id, last_name, email)
SELECT c.id, c.last_name, c.email
FROM customers AS c
WHERE c.id BETWEEN 1 AND 500;

INSERT INTO dw_dim_brand (brand_id, brand_name)
SELECT b.id, b.name
FROM car_brands AS b
WHERE b.id BETWEEN 1 AND 300;

INSERT INTO dw_fact_work_orders (work_order_id, customer_sk, brand_sk, status, total_cost)
SELECT wo.id,
       dc.customer_sk,
       db.brand_sk,
       wo.status,
       wo.total_cost
FROM work_orders AS wo
INNER JOIN vehicles AS v ON v.id = wo.vehicle_id
INNER JOIN dw_dim_customer AS dc ON dc.customer_id = v.customer_id
INNER JOIN dw_dim_brand AS db ON db.brand_id = v.brand_id
WHERE wo.id BETWEEN 1 AND 5000;

SELECT COUNT(*) AS fact_rows FROM dw_fact_work_orders;
```

### Step-by-step explanation

1. **Dimensions before facts** — facts need existing `customer_sk` / `brand_sk`.
2. **Bounded `BETWEEN`** keeps the classroom load under a few seconds.
3. Production ETL adds **incremental loads** (`WHERE updated_at > @last_run`), **deduplication**, and **error quarantine** rows.

---

## Exercise 3 — Star join analytical query

### Context

Analyst asks: *revenue by brand and status* on the warehouse — join fact to dimension only, not back to raw OLTP.

### What you'll learn

- Reporting query shape: `FROM fact JOIN dimension`.
- Aggregates on measures in the fact table.

### Tables in play

| Table | Columns |
|---|---|
| `dw_fact_work_orders` | `brand_sk`, `status`, `total_cost` |
| `dw_dim_brand` | `brand_sk`, `brand_name` |

### Task

Group by `brand_name` and `status`; show order count and revenue; top 15 by revenue.

### Expected result (real rows from the dump)

```text
+------------+---------------+--------+---------+
| brand_name | status        | orders | revenue |
+------------+---------------+--------+---------+
| Brand_100  | cancelled     |      5 | 2650.00 |
| Brand_099  | completed     |      5 | 2649.50 |
| Brand_098  | waiting_parts |      5 | 2649.00 |
| ...        |               |        |         |
+------------+---------------+--------+---------+
```

### Hint

`FROM dw_fact_work_orders f INNER JOIN dw_dim_brand db ON db.brand_sk = f.brand_sk`.

### Solution

```sql
SELECT db.brand_name,
       f.status,
       COUNT(*) AS orders,
       ROUND(SUM(f.total_cost), 2) AS revenue
FROM dw_fact_work_orders AS f
INNER JOIN dw_dim_brand AS db ON db.brand_sk = f.brand_sk
GROUP BY db.brand_name, f.status
ORDER BY revenue DESC
LIMIT 15;
```

### Step-by-step explanation

1. **Fewer joins than OLTP** — brand name is already in the dimension; no `vehicles` table at query time.
2. **Same SQL idioms** as OLAP in lesson `17_oltp_olap`, but on denormalized warehouse tables.
3. BI tools (Metabase, Power BI) often generate this join pattern automatically from a semantic model.

---

## Exercise 4 — Why a warehouse exists (OLTP vs DW)

### Context

You could run Exercise 3's report directly on `work_orders` + `vehicles` + `car_brands` (see `17_oltp_olap` Exercise 4). The warehouse exists to **isolate analytics load**, **historical snapshots**, and **consistent definitions**.

### What you'll learn

- When to query OLTP vs warehouse.
- Typical warehouse properties: read-optimized, batch-loaded, subject-oriented.

### Tables in play

| Layer | When to use |
|---|---|
| OLTP (`work_orders`, …) | Live operations, single-row updates |
| DW (`dw_fact_*`, `dw_dim_*`) | Dashboards, trends, heavy aggregates |

### Task

Compare mentally: list three reasons the `dw_*` tables help the car service business.

### Expected result

No SQL — conceptual checklist:

1. Heavy `GROUP BY` on the warehouse does not slow down the cashier's OLTP lookups.
2. Dimensions can store **history** (SCD Type 2) while OLTP keeps only current state.
3. **Conformed dimensions** let finance and operations share the same definition of "customer" and "brand".

### Hint

Re-read the star diagram and lesson `17_oltp_olap` Exercise 4.

### Solution

No additional SQL — the design is the deliverable. Re-run the ETL section of the companion script after dropping `dw_*` tables to rebuild the lab.

### Step-by-step explanation

1. **ETL decouples** refresh cadence (hourly/daily) from real-time OLTP commits.
2. **Grain** on `dw_fact_work_orders` is documented once; ambiguous aggregates are avoided.
3. At scale, warehouses move to **column stores** (Snowflake, BigQuery) or **OLAP cubes**; the star model remains the same idea.

---

## Related lessons

- [`17_oltp_olap/`](../17_oltp_olap/) — OLTP vs OLAP query patterns on raw schema.
- [`07_join/`](../07_join/) — join mechanics used in ETL and star queries.
