# Aggregation Functions (`10_odm/04_agregation_functions`)

Motor + MongoDB aggregation examples for:

- `$match` (filter)
- `$group` (grouping)
- `$sum` (sum)
- `$avg` (average)
- `$count` (count)
- `$max`, `$min` (max/min)
- `$sort` (sorting)
- `$project` (field projection)

Defaults:

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

Collection:

- `odm_aggregation_orders`

## Run

```bash
pip install -r mongodb/requirements.txt
python mongodb/10_odm/04_agregation_functions/main.py
```
