output "atlas_project_id" {
  description = "MongoDB Atlas project id."
  value       = mongodbatlas_project.project.id
}

output "atlas_cluster_name" {
  description = "MongoDB Atlas cluster name."
  value       = mongodbatlas_cluster.free_tier.name
}

output "standard_srv_connection_string" {
  description = "Standard SRV connection string (replace username/password placeholders if present)."
  value       = mongodbatlas_cluster.free_tier.connection_strings[0].standard_srv
}

output "database_name" {
  description = "Application database name."
  value       = var.database_name
}

output "db_username" {
  description = "Database username."
  value       = var.db_username
}
