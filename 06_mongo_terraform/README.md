# MongoDB Atlas with Terraform (`06_mongo_terraform/`)

This module provisions a **MongoDB Atlas free-tier cluster (M0)** and configures access so you can connect remotely.

It creates:

- Atlas project
- Atlas M0 cluster
- Atlas DB user
- Atlas IP access list entry (`0.0.0.0/0`) when `allow_from_anywhere = true`

## Prerequisites

- Terraform `>= 1.5`
- MongoDB Atlas account
- Atlas API keys with project/org permissions

## 1) Configure variables

```bash
cd mongo-terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- `atlas_public_key`
- `atlas_private_key`
- `atlas_org_id`
- `db_password`

By default, this module opens access from anywhere:

- `allow_from_anywhere = true` => `0.0.0.0/0`

For better security, set `allow_from_anywhere = false` and provide CIDRs in `allowed_cidrs`.

## 2) Create Atlas resources

```bash
terraform init
terraform plan
terraform apply
```

Get outputs:

```bash
terraform output
```

Important output:

- `standard_srv_connection_string`

## 3) Connect from terminal (`mongosh`)

Use the SRV output and append your DB:

```bash
mongosh "mongodb+srv://<USER>:<PASSWORD>@<CLUSTER_HOST>/<DATABASE_NAME>?retryWrites=true&w=majority"
```

Example:

```bash
mongosh "mongodb+srv://dbpractice_user:ChangeMe_StrongPassword123!@db-practice-free.xxxxx.mongodb.net/db_practice?retryWrites=true&w=majority"
```

## 4) Connect from MongoDB Compass

1. Open Compass
2. Paste SRV connection string
3. Provide user/password
4. Connect

## 5) Create database/collection quickly

MongoDB creates DB on first write:

```javascript
use db_practice
db.demo.insertOne({ hello: "atlas" })
```

## 6) Destroy resources

```bash
terraform destroy
```

## Notes

- M0 clusters can take several minutes to become available.
- Atlas provider may return cluster connection strings after cluster is fully ready.
