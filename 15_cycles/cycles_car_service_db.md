# Cycles (loops) — `car_service_db`

“Cycles” here means **repeated execution** in SQL in two main ways:

1. **Procedural loops** inside **`CREATE PROCEDURE`** — **`WHILE`**, **`REPEAT` … `UNTIL`**, and **`LOOP` … `LEAVE`** (MySQL stored programs).
2. **Recursive CTE** — **`WITH RECURSIVE`** (MySQL **8.0+**) for set-oriented “iteration” (e.g. number series, trees), not the same syntax as stored-program loops.

**Script:** `15_cycles/car_service_cycles_examples.sql`

```bash
gunzip -c database/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 15_cycles/car_service_cycles_examples.sql
```

Use the **mysql** client so **`DELIMITER`** works.

---

## Procedural loops (in procedures)

| Construct | When it stops |
|-----------|----------------|
| **`WHILE condition DO … END WHILE`** | While the condition is true (check at top). |
| **`REPEAT … UNTIL condition END REPEAT`** | Until the condition becomes true (check at bottom). |
| **`label: LOOP … END LOOP`** | Use **`LEAVE label`** (and optionally **`ITERATE label`**) to exit or re-run. |

Prefer **set-based** SQL when possible; loops are for procedural logic, small batches, or teaching.

---

## Recursive CTE

- **`WITH RECURSIVE name AS ( anchor UNION ALL recursive )`** — anchor + recursive part must be **union**-compatible.
- Server limit: **`cte_max_recursion_depth`** (session) — raise only when needed.

---

## Script contents

- Lab table **`cyc_log`** for rows inserted by loop demos.  
- Procedures: **`WHILE`**, **`REPEAT`**, **`LOOP` + `LEAVE`**, optional **cursor** over a tiny **`work_orders`** slice.  
- **`WITH RECURSIVE`** number series.  
- Optional **`DROP`** / **`DROP TABLE`** at the end.
