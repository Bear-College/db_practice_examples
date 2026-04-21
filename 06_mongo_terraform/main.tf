resource "mongodbatlas_project" "project" {
  org_id = var.atlas_org_id
  name   = var.project_name
}

resource "mongodbatlas_cluster" "free_tier" {
  project_id   = mongodbatlas_project.project.id
  name         = var.cluster_name
  cluster_type = "REPLICASET"

  # Free shared tier
  provider_name               = "TENANT"
  backing_provider_name       = "AWS"
  provider_instance_size_name = "M0"
  provider_region_name        = var.atlas_region

  # Set a stable version for reproducible labs.
  mongo_db_major_version = "7.0"
}

locals {
  ip_access_entries = var.allow_from_anywhere ? concat(["0.0.0.0/0"], var.allowed_cidrs) : var.allowed_cidrs
}

resource "mongodbatlas_project_ip_access_list" "access" {
  for_each = toset(local.ip_access_entries)

  project_id = mongodbatlas_project.project.id
  cidr_block = each.value
  comment    = "Terraform managed access: ${each.value}"
}

resource "mongodbatlas_database_user" "db_user" {
  project_id         = mongodbatlas_project.project.id
  auth_database_name = "admin"
  username           = var.db_username
  password           = var.db_password

  roles {
    role_name     = "readWrite"
    database_name = var.database_name
  }
}
