terraform {
  required_providers {
    yandex = {
      source  = "terraform.example.com/local/yandex"
      version = "0.104.0"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
}