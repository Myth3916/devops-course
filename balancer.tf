# Группа целевых серверов
resource "yandex_alb_target_group" "web_servers" {
  name = "web-servers-tg"

  target {
    subnet_id  = yandex_vpc_subnet.private_a.id
    ip_address = yandex_compute_instance.web_a.network_interface[0].ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.private_b.id
    ip_address = yandex_compute_instance.web_b.network_interface[0].ip_address
  }
}

# HTTP роутер
resource "yandex_alb_http_router" "web_router" {
  name = "web-router"
  # network_id НЕ нужен для этого ресурса
}

# Виртуальный хост
resource "yandex_alb_virtual_host" "web_host" {
  name           = "web-vhost"
  http_router_id = yandex_alb_http_router.web_router.id
  route {
    name = "default-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_backend.id
      }
    }
  }
}

# Группа бэкендов
resource "yandex_alb_backend_group" "web_backend" {
  name = "web-backend-group"

  http_backend {
    name = "backend-a"
    weight = 1
    port = 80

    target_group_ids = [yandex_alb_target_group.web_servers.id]

    healthcheck {
      timeout = "1s"
      interval = "2s"
      healthy_threshold = 2
      unhealthy_threshold = 2
      http_healthcheck {
        path = "/"
      }
    }
  }

  http_backend {
    name = "backend-b"
    weight = 1
    port = 80

    target_group_ids = [yandex_alb_target_group.web_servers.id]

    healthcheck {
      timeout = "1s"
      interval = "2s"
      healthy_threshold = 2
      unhealthy_threshold = 2
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_load_balancer" "web_balancer" {
    name = "web-balancer"
    network_id = yandex_vpc_network.devops_net.id
    region_id  = "ru-central1"
  
    allocation_policy {
      location {
        zone_id   = "ru-central1-a"
        subnet_id = yandex_vpc_subnet.public_a.id  # ← ПУБЛИЧНАЯ подсеть!
      }
      location {
        zone_id   = "ru-central1-b"
        subnet_id = yandex_vpc_subnet.public_b.id  # ← ПУБЛИЧНАЯ подсеть!
      }
    }
  
    listener {
      name = "http-listener"  # ← Такое имя, как в конфиге
      endpoint {
        address {
          external_ipv4_address {}
        }
        ports = [80]
      }
      http {
        handler {
          http_router_id = yandex_alb_http_router.web_router.id
        }
      }
    }
  
    security_group_ids = [
      yandex_vpc_security_group.sg_public.id,
      yandex_vpc_security_group.sg_internal.id #вот этой строки нехватало
      ]
  
    # 🔑 lifecycle для безопасности
    lifecycle {
      create_before_destroy = true
    }
  }
  
# Output: публичный IP балансировщика
output "balancer_public_ip" {
  value = yandex_alb_load_balancer.web_balancer.listener[0].endpoint[0].address[0].external_ipv4_address[0].address
}