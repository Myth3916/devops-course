terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "= 0.193.0"  # <-- Изменили на 0.193.0
    }
  }
}
# Объявляем переменные
variable "folder_id" {
  description = "ID каталога Yandex Cloud"
  type        = string
}

variable "zone" {
  description = "Зона доступности"
  type        = string
  default     = "ru-central1-a"
}

variable "service_account_key_file" {
  description = "Путь к файлу ключа сервисного аккаунта"
  type        = string
  default     = "~/.yandex/authorized_key.json" # Путь по умолчанию
}

provider "yandex" {
  # Используем функцию file() для чтения файла. 
  # pathexpand() нужен, чтобы раскрыть тильду ~ до полного пути /home/oleg
  service_account_key_file = file(pathexpand(var.service_account_key_file))
  folder_id                = var.folder_id
  zone                     = var.zone
}

data "yandex_client_config" "client" {}

output "cloud_id" {
  value = data.yandex_client_config.client.cloud_id
}

output "folder_id_out" {
  value = var.folder_id
}