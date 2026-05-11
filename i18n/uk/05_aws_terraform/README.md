# Робота з AWS RDS через Terraform (`05_aws_terraform/`)

> Translation / Переклад: [English](../../../05_aws_terraform/README.md)

Цей Terraform-модуль провіжнить інстанс AWS MySQL RDS і дозволяє підключатися до нього віддалено з:

- терміналу (CLI `mysql`)
- MySQL Workbench

Він також створює початкову базу даних (змінна `db_name`), тож ви можете одразу почати її використовувати.

## Що створює

- Security group, що дозволяє MySQL (`3306`) з вашого `allowed_cidr`
- DB subnet group у дефолтних підмережах VPC
- Інстанс MySQL RDS
- Початкову базу даних (за замовчуванням: `car_service_db`)

## Передумови

- Обліковий запис AWS
- Налаштований AWS CLI (`aws configure`)
- Terraform `>= 1.5`
- Клієнт `mysql` (для доступу з терміналу)

## 1) Налаштуйте змінні

```bash
cd aws-terraform
cp terraform.tfvars.example terraform.tfvars
```

Відредагуйте `terraform.tfvars`:

- встановіть `allowed_cidr` у CIDR вашої публічної IP (`x.x.x.x/32`)
- опційно встановіть `db_password` (якщо порожньо — Terraform згенерує)
- за потреби налаштуйте регіон/клас/обсяг сховища

Підказка, як дізнатися публічну IP:

```bash
curl ifconfig.me
```

## 2) Створіть інфраструктуру

```bash
terraform init
terraform plan
terraform apply
```

Збережіть ці значення (outputs):

- `rds_endpoint`
- `rds_port`
- `master_username`
- `database_name`
- `master_password` (sensitive output)

Прочитайте чутливий пароль:

```bash
terraform output -raw master_password
```

## 3) Підключення з терміналу

```bash
mysql -h <RDS_ENDPOINT> -P 3306 -u <MASTER_USERNAME> -p <DATABASE_NAME>
```

Приклад:

```bash
mysql -h db-practice-mysql.abc123xyz.eu-central-1.rds.amazonaws.com -P 3306 -u adminuser -p car_service_db
```

## 4) Підключення з MySQL Workbench

Створіть нове з'єднання з параметрами:

- Connection Method: `Standard (TCP/IP)`
- Hostname: `<RDS_ENDPOINT>`
- Port: `3306`
- Username: `<MASTER_USERNAME>`
- Password: збережіть `<MASTER_PASSWORD>`
- Default Schema: `<DATABASE_NAME>`

Натисніть **Test Connection** і **Connect**.

## 5) Нотатки з безпеки

- Використовуйте `allowed_cidr = "<your_ip>/32"` (не використовуйте `0.0.0.0/0` у продакшні).
- Регулярно ротуйте облікові дані БД.
- Для продакшну віддавайте перевагу приватному RDS + VPN/bastion замість публічного доступу.

## 6) Знищити інфраструктуру

```bash
terraform destroy
```

Якщо `skip_final_snapshot = false`, Terraform запитає налаштування фінального snapshot.
