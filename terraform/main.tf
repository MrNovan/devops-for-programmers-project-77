# terraform/main.tf

# --- Сеть ---
resource "yandex_vpc_network" "app-network" {
  name = "app-network"
}

resource "yandex_vpc_subnet" "app-subnet" {
  name           = "app-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.app-network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# --- Виртуальные машины ---
resource "yandex_compute_instance" "web-server" {
  count = 2

  name = "web-server-${count.index}"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8f7d58v3ov2vruuusj" # Ubuntu 22.04 LTS
      type     = "network-hdd"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.app-subnet.id
    ip_address = "192.168.10.1${count.index}"
    nat        = true
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_pub}"
    user_data = data.template_cloudinit_config.web-server-config[count.index].rendered
  }

  
}

# --- Автоматическая настройка ВМ ---
data "template_cloudinit_config" "web-server-config" {
  count = 2

  gzip = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = <<-EOF
      #!/bin/bash
      sudo apt update -y
      sudo apt install -y nginx
      echo "<h1>Hello from web-server-${count.index}</h1>" | sudo tee /var/www/html/index.html
      sudo systemctl start nginx
      sudo systemctl enable nginx
    EOF
  }
}

# --- Целевая группа для балансировщика ---
resource "yandex_alb_target_group" "app-target-group" {
  name      = "app-target-group"

  dynamic "target" {
    for_each = yandex_compute_instance.web-server.*.network_interface.0.ip_address
    content {
      subnet_id = yandex_vpc_subnet.app-subnet.id
      ip_address   = target.value
    }
  }
}

# --- Группа бэкендов ---
resource "yandex_alb_backend_group" "app-backend-group" {
  name = "app-backend-group"

  http_backend {
    name                  = "web-server-be"
    port                  = 80
    target_group_ids       = yandex_alb_target_group.app-target-group.id
    http2                 = false
    load_balancing_config {
      panic_threshold     = 90
    }
    healthcheck {
      timeout             = "10s"
      interval            = "2s"
      healthy_threshold   = 2
      unhealthy_threshold = 2
      http_healthcheck {
        path                = "/"
        port                = 80
      }
    }
  }
}

# --- HTTP-роутер ---
resource "yandex_alb_http_router" "app-router" {
  name = "app-router"
}

resource "yandex_alb_virtual_host" "app-vhost" {
  name           = "default-host"
  http_router_id = yandex_alb_http_router.app-router.id

  route {
    name = "default-route"
    http_route {
      http_match {
        no_match_action {
          backend_group {
            backend_group_id = yandex_alb_backend_group.app-backend-group.id
          }
        }
      }
    }
  }
}

# --- Балансировщик нагрузки (HTTPS) ---
resource "yandex_alb_listener" "app-listener" {
  name = "app-listener"
  external_address_spec {
    ip_version = "ipv4"
  }

  ssl_certificate_ids = [yandex_certificatemanager_certificate.app-tls.id]
  http_router_id      = yandex_alb_http_router.app-router.id
}

# --- База данных PostgreSQL ---
resource "yandex_mdb_mysql_cluster" "dbcluster" {
  name        = "dbcluster-mollyj"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.net.id
  version     = "8.0"

  resources {
    resource_preset_id = "s2.micro"
    disk_type_id       = "network-ssd"
    disk_size          = 16
  }

  mysql_config = {
    sql_mode                      = "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
    max_connections               = 100
    default_authentication_plugin = "MYSQL_NATIVE_PASSWORD"
    innodb_print_all_deadlocks    = true
  }

  host {
    zone      = var.zone_id
    subnet_id = yandex_vpc_subnet.subnet.id
  }

  depends_on = [yandex_vpc_network.net, yandex_vpc_subnet.subnet]
}

resource "yandex_mdb_mysql_user" "dbuser" {
  cluster_id = yandex_mdb_mysql_cluster.dbcluster.id
  name       = var.db_user
  password   = var.db_password

  permission {
    database_name = yandex_mdb_mysql_database.db.name
    roles         = ["ALL"]
  }

  depends_on = [yandex_mdb_mysql_cluster.dbcluster]
}

resource "yandex_mdb_mysql_database" "db" {
  cluster_id = yandex_mdb_mysql_cluster.dbcluster.id
  name       = var.db_name

  depends_on = [yandex_mdb_mysql_cluster.dbcluster]
  lifecycle {
    ignore_changes = [name]
  }
}