# 00 Git Workflow for SQL

Use a lightweight Git workflow for SQL exercises and review.

## Goal

Track SQL changes clearly and avoid losing work while iterating on lessons.

## Branching

- Create a branch per task or lesson block:

```bash
git checkout -b mysql/lesson-setup
```

## Commit habits

- Keep commits small and focused by topic.
- Use clear commit messages:
  - `feat(mysql): add joins practice queries`
  - `docs(mysql): improve transactions notes`
  - `fix(mysql): correct foreign key in ddl script`

## Before commit checklist

- [ ] SQL scripts run without syntax errors
- [ ] Destructive commands are intentional
- [ ] File names match lesson naming convention
- [ ] Docs and SQL examples stay in sync

## Suggested review checklist

- Query readability and style consistency
- Correct joins and predicates
- Index-awareness for heavy queries
- Transaction safety for write operations

## Output of this stage

A predictable versioning and review process for SQL learning artifacts.
