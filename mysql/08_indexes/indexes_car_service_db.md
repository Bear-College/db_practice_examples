# Indexes — `car_service_db` lab

This module adds a **practice table** `idx_lab` (and a tiny `idx_geo` for **spatial** indexes) inside **`car_service_db`**. You can **`CREATE INDEX`** / **`DROP INDEX`** yourself and compare plans and timings **with vs without** an index.

**Script:** `08_indexes/car_service_indexes_examples.sql`

```bash
gunzip -c database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 08_indexes/car_service_indexes_examples.sql
```

**Requirements:** MySQL **8.0+** recommended (functional indexes, `EXPLAIN ANALYZE`, expression indexes). Some statements are guarded with version notes in the `.sql` file.

---

## How to compare speed manually

1. Run the **baseline** `EXPLAIN` / `EXPLAIN ANALYZE` blocks **before** creating a secondary index (script order does this first).
2. Run the matching **`CREATE INDEX`** (or uncomment it if you moved it below the baseline).
3. Run the **same `SELECT`** again and compare:
   - **`EXPLAIN`**: `type` should move from **`ALL`** (full scan) toward **`ref`**, **`range`**, or **`const`** when the index applies.
   - **`EXPLAIN ANALYZE`** (8.0.18+): compare **actual time** / **rows read**.
4. Remove the index to re-test a cold scan:
   ```sql
   DROP INDEX index_name ON idx_lab;
   ```
5. Optional: `ANALYZE TABLE idx_lab;` after bulk load or many DML changes.

**Note:** `SHOW PROFILES` / `profiling` are deprecated in recent MySQL versions; prefer **`EXPLAIN ANALYZE`** where available.

---

## Index types demonstrated (MySQL / InnoDB)

| Kind | In script | Typical use |
|------|-----------|-------------|
| **Primary key** | `PRIMARY KEY (id)` on lab tables | Clustered B-tree; unique row id. |
| **Secondary B-tree (non-unique)** | `CREATE INDEX … ON idx_lab (ref_num)` | Equality / range on `ref_num`. |
| **UNIQUE** | `CREATE UNIQUE INDEX … ON idx_lab (sku)` | One row per SKU (data must stay unique). |
| **Composite** | `(status, ref_num)` | Filters on leading column + sort/range on next. |
| **Prefix** | `sku(16)` on long `VARCHAR` | Shorter index on left part of string. |
| **FULLTEXT** | `FULLTEXT (note)` | `MATCH(note) AGAINST(...)` (InnoDB FULLTEXT). |
| **Functional / expression** (8.0.13+) | `(LOWER(sku))` | Equality on expression used in `WHERE`. |
| **SPATIAL** | `POINT` + `SPATIAL INDEX` on `idx_geo` | Point-in-region style queries (small demo table). |

**Not included (rare in app DBs):** `HASH` is only for **`MEMORY`** engine, not InnoDB default secondary indexes.

**Optional (MySQL 8+):** **Descending** secondary index (`CREATE INDEX … (col DESC)`), **invisible** indexes (`CREATE INDEX … INVISIBLE`) for A/B testing — see MySQL manual; not required for this lab script.

---

## Cleanup

The script ends with optional **`DROP TABLE`** for lab tables. Comment those lines out if you want to keep experimenting. Index names use the prefix **`ix_`** so you can find them in `SHOW INDEX FROM idx_lab`.

---

## Troubleshooting

- **`CREATE UNIQUE INDEX` fails:** duplicate `sku` values in `idx_lab` — empty table and re-run, or relax to non-unique index on `sku`.
- **FULLTEXT returns nothing:** stopwords / token length — try a longer word from your data in `MATCH … AGAINST`.
- **`SPATIAL` errors:** need MySQL 8+ with InnoDB spatial; ensure `POINT` is `NOT NULL` and SRID matches.
