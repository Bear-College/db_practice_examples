# AWS RDS workflow with Terraform (`aws-terraform/`)

This Terraform module provisions an AWS MySQL RDS instance and lets you connect to it remotely from:

- terminal (`mysql` CLI)
- MySQL Workbench

It also creates the initial database (`db_name` variable), so you can start using it immediately.

## What it creates

- Security group allowing MySQL (`3306`) from your `allowed_cidr`
- DB subnet group in the default VPC subnets
- MySQL RDS instance
- Initial database (default: `car_service_db`)

## Prerequisites

- AWS account
- AWS CLI configured (`aws configure`)
- Terraform `>= 1.5`
- `mysql` client (for terminal access)

## 1) Configure variables

```bash
cd aws-terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- set `allowed_cidr` to your public IP CIDR (`x.x.x.x/32`)
- optionally set `db_password` (if empty, Terraform generates one)
- adjust region/class/storage if needed

Tip to get your public IP:

```bash
curl ifconfig.me
```

## 2) Create infrastructure

```bash
terraform init
terraform plan
terraform apply
```

Save these outputs:

- `rds_endpoint`
- `rds_port`
- `master_username`
- `database_name`
- `master_password` (sensitive output)

Read sensitive password:

```bash
terraform output -raw master_password
```

## 3) Connect from terminal

```bash
mysql -h <RDS_ENDPOINT> -P 3306 -u <MASTER_USERNAME> -p <DATABASE_NAME>
```

Example:

```bash
mysql -h db-practice-mysql.abc123xyz.eu-central-1.rds.amazonaws.com -P 3306 -u adminuser -p car_service_db
```

## 4) Connect from MySQL Workbench

Create a new connection with:

- Connection Method: `Standard (TCP/IP)`
- Hostname: `<RDS_ENDPOINT>`
- Port: `3306`
- Username: `<MASTER_USERNAME>`
- Password: store `<MASTER_PASSWORD>`
- Default Schema: `<DATABASE_NAME>`

Then click **Test Connection** and **Connect**.

## 5) Security notes

- Use `allowed_cidr = "<your_ip>/32"` (do not use `0.0.0.0/0` in production).
- Rotate DB credentials regularly.
- For production, prefer private RDS + VPN/bastion instead of public access.

## 6) Destroy infrastructure

```bash
terraform destroy
```

If `skip_final_snapshot = false`, Terraform will ask for final snapshot settings.
