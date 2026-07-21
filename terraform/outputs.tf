output "cluster_id" {
  description = "Managed Kubernetes cluster ID"
  value       = yandex_kubernetes_cluster.app.id
}

output "cluster_name" {
  description = "Managed Kubernetes cluster name"
  value       = yandex_kubernetes_cluster.app.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = yandex_kubernetes_cluster.app.master[0].external_v4_endpoint
}

output "node_group_id" {
  description = "Worker node group ID"
  value       = yandex_kubernetes_node_group.workers.id
}

output "db_host" {
  description = "Managed PostgreSQL FQDN"
  value       = yandex_mdb_postgresql_cluster.app_db.host[0].fqdn
}

output "db_port" {
  description = "Managed PostgreSQL port"
  value       = 6432
}

output "db_name" {
  description = "Application database name"
  value       = yandex_mdb_postgresql_database.app_db.name
}

output "db_user" {
  description = "Application database user"
  value       = yandex_mdb_postgresql_user.app_user.name
}
