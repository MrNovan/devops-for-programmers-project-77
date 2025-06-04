# terraform/outputs.tf
output "db_host" {
  value = yandex_mdb_postgresql_cluster.dbcluster.host[0].name
}