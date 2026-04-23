# 00 SQL Style Guide

Use one consistent style across all SQL scripts in this repository.

## Goal

Make SQL readable, reviewable, and production-friendly from day one.

## Naming rules

- Use `snake_case` for tables, columns, indexes, and constraints.
- Use descriptive names (`service_order_id` instead of `id2`).
- Keep aliases short and meaningful (`c` for customers, `so` for service orders).

## Query formatting

- SQL keywords in uppercase (`SELECT`, `FROM`, `JOIN`, `WHERE`).
- One selected column per line for medium/large queries.
- Place each `JOIN` on its own line with explicit `ON`.
- Add comments only when business logic is not obvious.

## Safety rules

- Never run `UPDATE`/`DELETE` without a `WHERE` clause unless intentional.
- Preview destructive changes with `SELECT` first.
- Wrap multi-step writes in transactions where appropriate.

## Review checklist

- [ ] Query has clear intent and readable structure
- [ ] Joins use correct keys and no accidental cartesian products
- [ ] Predicates can use existing indexes where possible
- [ ] Script is repeatable or clearly marked as one-time

## Output of this stage

A shared SQL style that reduces errors and review friction in all lessons.
