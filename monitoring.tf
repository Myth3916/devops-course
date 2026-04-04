# ------------------------------------------------------------------
# Мониторинг и Логирование (оптимизировано: 2 ВМ вместо 4)
# ------------------------------------------------------------------

# ВМ для Prometheus + Grafana
resource "yandex_compute_instance" "monitoring" {
  name        = "monitoring-server"
  description = "Сервер мониторинга (Prometheus + Grafana)"
  platform_id = "standard-v2"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 4  # Увеличено для двух сервисов
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204.image_id
      size     = 15
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg_public.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# ВМ для Elasticsearch + Kibana
resource "yandex_compute_instance" "logging" {
  name        = "logging-server"
  description = "Сервер логирования (Elasticsearch + Kibana)"
  platform_id = "standard-v2"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 4  # Elasticsearch требует много RAM
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204.image_id
      size     = 20  # Увеличено для логов
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg_public.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Outputs: IP-адреса новых ВМ
output "monitoring_server_ip" {
  value = yandex_compute_instance.monitoring.network_interface[0].nat_ip_address
}

output "logging_server_ip" {
  value = yandex_compute_instance.logging.network_interface[0].nat_ip_address
}