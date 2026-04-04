# ------------------------------------------------------------------
# 1. VPC (сеть)
# ------------------------------------------------------------------
resource "yandex_vpc_network" "devops_net" {
  name        = "devops-course-network"
  description = "Основная сеть для курсового проекта"
}

# ------------------------------------------------------------------
# 2. Подсети (2 зоны доступности для отказоустойчивости)
# ------------------------------------------------------------------

# Зона A
resource "yandex_vpc_subnet" "public_a" {
  name           = "public-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.devops_net.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

resource "yandex_vpc_subnet" "private_a" {
  name           = "private-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.devops_net.id
  v4_cidr_blocks = ["10.0.2.0/24"]
}

# Зона B
resource "yandex_vpc_subnet" "public_b" {
  name           = "public-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.devops_net.id
  v4_cidr_blocks = ["10.0.3.0/24"]
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "private-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.devops_net.id
  v4_cidr_blocks = ["10.0.4.0/24"]
}

# ------------------------------------------------------------------
# 3. Группы безопасности
# ------------------------------------------------------------------

# Bastion: точка входа по SSH из интернета
resource "yandex_vpc_security_group" "sg_bastion" {
  name        = "sg-bastion"
  description = "SSH доступ из интернета (точка входа)"
  network_id  = yandex_vpc_network.devops_net.id

  ingress {
    protocol       = "TCP"
    port           = 22
    description    = "SSH из интернета"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Весь исходящий трафик"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Internal: для внутренних сервисов (веб-серверы)
resource "yandex_vpc_security_group" "sg_internal" {
  name        = "sg-internal"
  description = "Внутренние сервисы: доступ только с bastion и между собой"
  network_id  = yandex_vpc_network.devops_net.id

  # SSH только с bastion
  ingress {
    protocol          = "TCP"
    port              = 22
    description       = "SSH only from bastion"
    security_group_id = yandex_vpc_security_group.sg_bastion.id
  }

  # HTTP/HTTPS для внутренних сервисов (для проверки балансировщиком и диагностики)
  ingress {
    protocol       = "TCP"
    port           = 80
    description    = "HTTP для внутренних сервисов"
    v4_cidr_blocks = ["0.0.0.0/0"]  # Разрешаем всем (включая bastion и балансировщик)
  }

  # Внутренний трафик между сервисами этой же группы
  ingress {
    protocol          = "ANY"
    description       = "Internal traffic between services"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  # Health checks от балансировщика (ОБЯЗАТЕЛЬНО: весь TCP-диапазон и все IP-диапазоны Yandex Cloud)
  ingress {
    protocol       = "TCP"
    description    = "Health checks from load balancer (all TCP ports)"
    from_port      = 1
    to_port        = 65535
    v4_cidr_blocks = [
      "198.18.232.0/22",
      "198.18.240.0/22",
      "198.18.235.0/24",
      "198.18.248.0/24"
    ]
  }

  # ICMP (ping) от bastion
  ingress {
    protocol          = "ICMP"
    description       = "Ping from bastion"
    security_group_id = yandex_vpc_security_group.sg_bastion.id
  }

  # Node Exporter (порт 9100) — доступ из всей приватной сети
  ingress {
    protocol       = "TCP"
    port           = 9100
    description    = "Node Exporter metrics"
    v4_cidr_blocks = ["10.0.0.0/16"]
  }

  # Nginx Log Exporter (порт 9113)
  ingress {
    protocol       = "TCP"
    port           = 9113
    description    = "Nginx Log Exporter"
    v4_cidr_blocks = ["10.0.0.0/16"]
  }

  # Исходящий трафик
  egress {
    protocol       = "ANY"
    description    = "All outbound"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Public: для публичных сервисов (балансировщик)
resource "yandex_vpc_security_group" "sg_public" {
  name        = "sg-public"
  description = "Публичные сервисы: HTTP/HTTPS из интернета [ALB health checks enabled]"
  network_id  = yandex_vpc_network.devops_net.id

  # 🔑 ОБЯЗАТЕЛЬНО: Health checks от ALB
  ingress {
    protocol       = "TCP"
    from_port      = 1
    to_port        = 65535
    description    = "ALB health checks from YC ranges"
    v4_cidr_blocks = [
      "198.18.232.0/22",
      "198.18.240.0/22",
    ]
  }

  # HTTP из интернета
  ingress {
    protocol       = "TCP"
    port           = 80
    description    = "HTTP from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS из интернета
  ingress {
    protocol       = "TCP"
    port           = 443
    description    = "HTTPS from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH только с bastion
  ingress {
    protocol          = "TCP"
    port              = 22
    description       = "SSH only from bastion"
    security_group_id = yandex_vpc_security_group.sg_bastion.id
  }

  # Grafana
  ingress {
    protocol       = "TCP"
    port           = 3000
    description    = "Grafana UI from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus
  ingress {
    protocol          = "TCP"
    port              = 9090
    description       = "Prometheus API"
    security_group_id = yandex_vpc_security_group.sg_bastion.id
  }

  # Elasticsearch
  ingress {
    protocol       = "TCP"
    port           = 9200
    description    = "Elasticsearch API"
    v4_cidr_blocks = ["10.0.0.0/16"]
  }

  # Kibana
  ingress {
    protocol       = "TCP"
    port           = 5601
    description    = "Kibana UI from internet"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Исходящий трафик
  egress {
    protocol       = "ANY"
    description    = "All outbound traffic"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
   