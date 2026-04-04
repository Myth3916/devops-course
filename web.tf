# Веб-сервер 1 (зона A, приватная подсеть)
resource "yandex_compute_instance" "web_a" {
  name        = "web-server-a"
  description = "Веб-сервер в зоне ru-central1-a"
  platform_id = "standard-v2"
  zone        = "ru-central1-a"

  scheduling_policy {
    preemptible = true
  }

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204.image_id
      size     = 8
      type     = "network-hdd"
    }
  }

  # ЕДИНСТВЕННЫЙ сетевой интерфейс для web_a
  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = true # false # Временно включаем для установки пакетов
    security_group_ids = [yandex_vpc_security_group.sg_internal.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Веб-сервер 2 (зона B, приватная подсеть)
resource "yandex_compute_instance" "web_b" {
  name        = "web-server-b"
  description = "Веб-сервер в зоне ru-central1-b"
  platform_id = "standard-v2"
  zone        = "ru-central1-b"

  scheduling_policy {
    preemptible = true
  }

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204.image_id
      size     = 8
      type     = "network-hdd"
    }
  }

  # ЕДИНСТВЕННЫЙ сетевой интерфейс для web_b
  network_interface {
    subnet_id          = yandex_vpc_subnet.private_b.id
    nat                = true # false # Временно включаем для установки пакетов
    security_group_ids = [yandex_vpc_security_group.sg_internal.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Outputs: внутренние IP веб-серверов
output "web_servers_private_ips" {
  value = {
    web_a = yandex_compute_instance.web_a.network_interface[0].ip_address
    web_b = yandex_compute_instance.web_b.network_interface[0].ip_address
  }
}