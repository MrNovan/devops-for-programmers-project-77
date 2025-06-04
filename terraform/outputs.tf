# terraform/outputs.tf
output "lb_ip" {
  value = yandex_lb_listener.test-balancer.external_address_spec[0].address
}

output "db_host" {
  value = yandex_mdb_postgresql_cluster.dbcluster.host[0].name
}