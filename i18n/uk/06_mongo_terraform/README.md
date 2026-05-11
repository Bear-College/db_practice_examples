# MongoDB Atlas через Terraform (`06_mongo_terraform/`)

> Translation / Переклад: [English](../../../06_mongo_terraform/README.md)

Цей модуль провіжнить **безкоштовний кластер MongoDB Atlas (M0)** і налаштовує доступ для віддаленого підключення.

Створює:

- Проєкт Atlas
- Кластер Atlas M0
- Користувача БД в Atlas
- Запис у IP access list Atlas (`0.0.0.0/0`), якщо `allow_from_anywhere = true`

## Передумови

- Terraform `>= 1.5`
- Обліковий запис MongoDB Atlas
- API-ключі Atlas з правами на проєкт/організацію

## 1) Налаштуйте змінні

```bash
cd mongo-terraform
cp terraform.tfvars.example terraform.tfvars
```

Відредагуйте `terraform.tfvars`:

- `atlas_public_key`
- `atlas_private_key`
- `atlas_org_id`
- `db_password`

За замовчуванням модуль відкриває доступ з будь-якої адреси:

- `allow_from_anywhere = true` => `0.0.0.0/0`

Для кращої безпеки встановіть `allow_from_anywhere = false` і вкажіть CIDR-и у `allowed_cidrs`.

## 2) Створіть ресурси Atlas

```bash
terraform init
terraform plan
terraform apply
```

Отримайте значення (outputs):

```bash
terraform output
```

Важливе значення:

- `standard_srv_connection_string`

## 3) Підключення з терміналу (`mongosh`)

Використовуйте SRV-output і додайте свою БД:

```bash
mongosh "mongodb+srv://<USER>:<PASSWORD>@<CLUSTER_HOST>/<DATABASE_NAME>?retryWrites=true&w=majority"
```

Приклад:

```bash
mongosh "mongodb+srv://dbpractice_user:ChangeMe_StrongPassword123!@db-practice-free.xxxxx.mongodb.net/db_practice?retryWrites=true&w=majority"
```

## 4) Підключення з MongoDB Compass

1. Відкрийте Compass
2. Вставте SRV-рядок підключення
3. Вкажіть користувача/пароль
4. Підключіться

## 5) Швидко створити базу/колекцію

MongoDB створює БД при першому записі:

```javascript
use db_practice
db.demo.insertOne({ hello: "atlas" })
```

## 6) Знищити ресурси

```bash
terraform destroy
```

## Нотатки

- Кластери M0 можуть кілька хвилин ставати доступними.
- Atlas-провайдер може повертати connection-string кластера лише після того, як кластер повністю готовий.
