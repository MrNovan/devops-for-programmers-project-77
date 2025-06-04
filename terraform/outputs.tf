# terraform/outputs.tf
output "lb_ip" {
  value = yandex_alb_load_balancer.test-balancer.status.address[0].external_ipv4_address[0].address
}

output "db_host" {
  value = yandex_mdb_postgresql_cluster.dbcluster.host[0].name
}