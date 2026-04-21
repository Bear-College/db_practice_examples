variable "atlas_public_key" {
  description = "MongoDB Atlas API public key."
  type        = string
  sensitive   = true
}

variable "atlas_private_key" {
  description = "MongoDB Atlas API private key."
  type        = string
  sensitive   = true
}

variable "atlas_org_id" {
  description = "MongoDB Atlas Organization ID."
  type        = string
}

variable "project_name" {
  description = "Atlas project name."
  type        = string
  default     = "db-practice-atlas"
}

variable "cluster_name" {
  description = "Atlas cluster name."
  type        = string
  default     = "db-practice-free"
}

variable "atlas_region" {
  description = "Atlas region for M0 tenant cluster (AWS region code Atlas expects, e.g. US_EAST_1)."
  type        = string
  default     = "US_EAST_1"
}

variable "db_username" {
  description = "Database user for remote connection."
  type        = string
  default     = "dbpractice_user"
}

variable "db_password" {
  description = "Database user password."
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Default auth database and target database name."
  type        = string
  default     = "db_practice"
}

variable "allow_from_anywhere" {
  description = "If true, add 0.0.0.0/0 to Atlas IP access list."
  type        = bool
  default     = true
}

variable "allowed_cidrs" {
  description = "Additional CIDR blocks to allow."
  type        = list(string)
  default     = []
}
