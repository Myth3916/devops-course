# Получаем образ Ubuntu 22.04 LTS
data "yandex_compute_image" "ubuntu_2204" {
  family = "ubuntu-2204-lts"
}

# Bastion Host — точка входа (экономная конфигурация)
resource "yandex_compute_instance" "bastion" {
  name        = "bastion-host"
  description = "Точка входа для управления инфраструктурой"
  platform_id = "standard-v2"  # Cascade Lake (дешевле)
  zone        = "ru-central1-a"

  # ⚡ Прерываемая ВМ — скидка до 70% (через блок scheduling_policy)
  scheduling_policy {
    preemptible = true
  }

  # Минимальные ресурсы для экономии
  resources {
    cores         = 2
    memory        = 1          # 1 ГБ RAM
    core_fraction = 20         # 20% доли ядра
  }

  # Диск: только HDD, 8 ГБ
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204.image_id
      size     = 8
      type     = "network-hdd"  # HDD вместо SSD
    }
  }

  # Сеть: публичная подсеть + публичный IP + группа безопасности
  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg_bastion.id]  # <-- ВНУТРИ блока!
  }

  # SSH-ключ
  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# Output: публичный IP bastion
output "bastion_public_ip" {
  value = yandex_compute_instance.bastion.network_interface[0].nat_ip_address 
}