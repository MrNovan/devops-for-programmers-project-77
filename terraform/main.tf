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
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  user_data = data.template_cloudinit_config.web-server-config[count.index].rendered
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
resource "yandex_lb_target_group" "app-target-group" {
  name      = "app-target-group"
  region_id = "ru-central1"

  dynamic "target" {
    for_each = yandex_compute_instance.web-server.*.network_interface.0.ip_address
    content {
      subnet_id = yandex_vpc_subnet.app-subnet.id
      address   = target.value
    }
  }
}

# --- Группа бэкендов ---
resource "yandex_lb_backend_group" "app-backend-group" {
  name = "app-backend-group"

  http_backend {
    name                  = "web-server-be"
    port                  = 80
    target_group_id       = yandex_lb_target_group.app-target-group.id
    http2                 = false
    load_balancing_config {
      panic_threshold     = 90
    }
    healthcheck {
      timeout             = "10s"
      interval            = "2s"
      healthy_threshold   = 2
      unhealthy_threshold = 2
      http_health_check {
        path                = "/"
        port                = 80
      }
    }
  }
}

# --- HTTP-роутер ---
resource "yandex_lb_http_router" "app-router" {
  name = "app-router"

  route {
    name = "default-route"
    http_route {
      http_matcher {
        no_match_action {
          backend_group {
            backend_group_id = yandex_lb_backend_group.app-backend-group.id
          }
        }
      }
    }
  }
}

# --- SSL-сертификат (пример, можно заменить на Let's Encrypt) ---
resource "yandex_certificatemanager_certificate" "app-tls" {
  name = "app-tls-cert"
  self_managed {
    certificate = file("cert.pem")
    private_key = file("key.pem")
  }
}

# --- Балансировщик нагрузки (HTTPS) ---
resource "yandex_lb_listener" "app-listener" {
  name = "app-listener"
  external_address_spec {
    ip_version = "ipv4"
  }

  ssl_certificate_ids = [yandex_certificatemanager_certificate.app-tls.id]
  http_router_id      = yandex_lb_http_router.app-router.id
}

# --- База данных PostgreSQL ---
resource "yandex_mdb_postgresql_cluster" "app-db" {
  name                = "app-db"
  environment         = "PRESTABLE"
  network_id          = yandex_vpc_network.app-network.id
  version             = "14"

  resources {
    resource_preset_id = "s2.micro"
    disk_size          = 10
    disk_type_id       = "network-hdd"
  }

  database {
    name  = "app_db"
    owner = "pg-user"
  }

  user {
    name     = "pg-user"
    password = "your-secret-password"
    permission {
      database_name = "app_db"
      roles         = ["ALL"]
    }
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.app-subnet.id
  }
}