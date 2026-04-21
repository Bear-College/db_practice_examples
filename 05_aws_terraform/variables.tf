variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name prefix for AWS resources."
  type        = string
  default     = "db-practice"
}

variable "db_name" {
  description = "Initial database name created by RDS."
  type        = string
  default     = "car_service_db"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "adminuser"
}

variable "db_password" {
  description = "Master password for RDS. Leave empty to auto-generate."
  type        = string
  sensitive   = true
  default     = ""
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage size in GB."
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0.36"
}

variable "allowed_cidr" {
  description = "Public CIDR allowed to connect to MySQL (for example your office/home IP)."
  type        = string
}

variable "publicly_accessible" {
  description = "Whether RDS gets a public endpoint."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy."
  type        = bool
  default     = true
}
