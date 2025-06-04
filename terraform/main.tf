# terraform/main.tf

# --- Сеть ---
resource "yandex_vpc_network" "net" {
  # name = "tfhexlet"
  name = var.network_name
}

# подсеть

resource "yandex_vpc_subnet" "subnet" {
  name           = var.subnet_name
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["192.168.192.0/24"]
}

# --- Виртуальные машины ---
resource "yandex_compute_instance" "vm" {
  count = 2

  name = "vm${count.index}"
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
    subnet_id = yandex_vpc_subnet.subnet.id
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
resource "yandex_alb_target_group" "target_group" {
  name      = "my-target-group"
  region = "ru-central1"

  dynamic "target" {
    for_each = yandex_compute_instance.vm.*.network_interface.0.ip_address
    content {
      subnet_id  = yandex_vpc_subnet.subnet.id
      ip_address = target.value
    }
  }
}

# --- Группа бэкендов ---
resource "yandex_alb_backend_group" "test-backend-group" {
  name = "my-backend-group"

  http_backend {
    name             = "test-http-backend"
    weight           = 1
    port             = 80
    target_group_ids = ["${yandex_alb_target_group.target_group.id}"]

    healthcheck {
      timeout  = "1s"
      interval = "1s"
      http_healthcheck {
        path = "/"
      }
      healthcheck_port = 80
    }
  }
}

# --- HTTP-роутер ---
resource "yandex_alb_http_router" "tf-router" {
  name = "my-http-router"

}

# --- Балансировщик нагрузки (HTTPS) ---
resource "yandex_alb_load_balancer" "test-balancer" {
  name = "my-load-balancer"

  network_id = yandex_vpc_network.net.id

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.subnet.id
    }
  }

  listener {
    name = "listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [443]
    }
    tls {
      default_handler {
        certificate_ids = ["fpq1j2b0a17o9l6vpq1o"]
        http_handler {
          http_router_id = yandex_alb_http_router.tf-router.id
        }
      }
    }
  }
}

# --- База данных PostgreSQL ---
resource "yandex_mdb_postgresql_cluster" "dbcluster" {
  name        = "tfhexlet"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.net.id
  depends_on  = [yandex_vpc_network.net, yandex_vpc_subnet.subnet]

  config {
    version = var.yc_postgresql_version
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 15
    }
    postgresql_config = {
      max_connections = 100
    }
  }

  maintenance_window {
    type = "WEEKLY"
    day  = "SAT"
    hour = 12
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.subnet.id
  }
}

resource "yandex_mdb_postgresql_user" "dbuser" {
  cluster_id = yandex_mdb_postgresql_cluster.dbcluster.id
  name       = var.db_user
  password   = var.db_password
  depends_on = [yandex_mdb_postgresql_cluster.dbcluster]
}

resource "yandex_mdb_postgresql_database" "db" {
  cluster_id = yandex_mdb_postgresql_cluster.dbcluster.id
  name       = var.db_database
  owner      = yandex_mdb_postgresql_user.dbuser.name
  lc_collate = "en_US.UTF-8"
  lc_type    = "en_US.UTF-8"
  depends_on = [yandex_mdb_postgresql_cluster.dbcluster]
}