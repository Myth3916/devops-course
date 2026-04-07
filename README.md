#  Отказоустойчивая инфраструктура для сайта в Yandex Cloud

> Курсовая работа по профессии "DevOps-инженер с нуля" - Шаров Олег

## 📋 Содержание

- [Описание проекта](#-описание-проекта)
- [Архитектура](#-архитектура)
- [Технологии](#-технологии)
- [Инфраструктура](#-инфраструктура)
  - [Сеть](#-сеть)
  - [Веб-серверы](#-веб-серверы)
  - [Балансировщик нагрузки](#-балансировщик-нагрузки)
  - [Мониторинг](#-мониторинг)
  - [Сбор логов](#-сбор-логов)
  - [Резервное копирование](#-резервное-копирование)
- [Развёртывание](#-развёртывание)
- [Доступ к сервисам](#-доступ-к-сервисам)
- [Скриншоты](#-скриншоты)
- [Компромиссы и решения](#-компромиссы-и-решения)

---

## 📖 Описание проекта

Разработана отказоустойчивая инфраструктура для хостинга сайта в облаке Yandex Cloud, включающая:
- ✅ Дублирование веб-серверов в разных зонах доступности
- ✅ Балансировку трафика через Application Load Balancer
- ✅ Централизованный сбор и визуализацию логов (ELK Stack)
- ✅ Мониторинг метрик инфраструктуры (Prometheus + Grafana)
- ✅ Автоматическое резервное копирование дисков
- ✅ Безопасный доступ через Bastion Host

---

## 🏗️ Архитектура

```markdown
┌─────────────────────────────────────────────────────────┐
│                    Yandex Cloud                          │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │           VPC: devops-course                     │   │
│  │                                                  │   │
│  │  ┌──────────────┐  ┌────────────────────────┐  │   │
│  │  │Public Subnet │  │   Private Subnets      │  │   │
│  │  │              │  │                        │  │   │
│  │  │  • ALB (80)  │  │  • web-server-a        │  │   │
│  │  │  • Grafana   │  │  • web-server-b        │  │   │
│  │  │  • Kibana    │  │  • monitoring          │  │   │
│  │  │  • Bastion   │  │  • logging             │  │   │
│  │  └──────────────┘  └────────────────────────┘  │   │
│  │                                                  │   │
│  │  Security Groups:                               │   │
│  │  • sg-public:    80, 443, 3000, 5601, 22       │   │
│  │  • sg-internal:  9200, 9090, 9100, 22          │   │
│  │  • sg-bastion:   22 (только из интернета)      │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Поток запроса:**
Пользователь → ALB (158.160.184.65:80)
→ Backend Group
→ web-server-a ИЛИ web-server-b (nginx:80)
→ Filebeat → Elasticsearch → Kibana

Пользователь
    ↓
    → ALB (158.160.184.65:80)
           ↓
           → Backend Group
                  ↓
                  → web-server-a (nginx:80)  ИЛИ
                  → web-server-b (nginx:80)
                         ↓
                         → Filebeat
                                ↓
                                → Elasticsearch
                                       ↓
                                       → Kibana



---

## ⚙️ Технологии

| Компонент | Технология | Версия | Назначение |
|-----------|-----------|--------|-----------|
| **IaC** | Terraform | 1.x | Создание инфраструктуры |
| **Config Management** | Ansible | 2.x | Настройка серверов |
| **Web Server** | nginx | 1.18.0 | Раздача статики |
| **Load Balancer** | Yandex ALB | - | Распределение трафика |
| **Logging** | Elasticsearch | 7.17.0 | Хранение логов |
| **Logging UI** | Kibana | 7.17.0 | Визуализация логов |
| **Log Shipper** | Filebeat | 8.14.0 | Отправка логов в ES |
| **Metrics** | Prometheus | 2.45.0 | Сбор метрик |
| **Metrics UI** | Grafana | 10.x | Дашборды метрик |
| **Node Metrics** | Node Exporter | 1.6.1 | Метрики ОС |
| **Backup** | yc CLI + bash | - | Снапшоты дисков |

---

## 🏗️ Инфраструктура

### 🔷 Сеть

- **VPC**: `devops-course`
- **Подсети**:
  - `public-subnet-a` (ru-central1-a) — публичные сервисы
  - `private-subnet-a` (ru-central1-a) — веб-серверы, мониторинг, логирование
  - `private-subnet-b` (ru-central1-b) — веб-сервер для отказоустойчивости
- **Security Groups**:
  - `sg-public`: разрешает 80, 443, 3000, 5601, 22 из 0.0.0.0/0
  - `sg-internal`: разрешает 9200, 9090, 9100, 22 только из 10.0.0.0/16
  - `sg-bastion`: разрешает 22 только из интернета

### 🔷 Веб-серверы

| Параметр | Значение |
|----------|----------|
| Количество | 2 ВМ |
| Зоны | ru-central1-a, ru-central1-b |
| ОС | Ubuntu 22.04 LTS |
| vCPU / RAM | 2 vCPU / 2 GB |
| Диск | 10 GB network-ssd |
| Сервис | nginx (статический сайт) |
| Логи | /var/log/nginx/{access,error}.log → Filebeat |

### 🔷 Балансировщик нагрузки

- **Тип**: Application Load Balancer (управляемый сервис)
- **Публичный IP**: `158.160.184.65`
- **Listener**: HTTP:80 (auto)
- **Router**: `/` → Backend Group
- **Backend Group**: Target Group с двумя ВМ
- **Health Check**: HTTP GET `/` на порт 80, интервал 10с

**Тест балансировки:**
```bash
$ for i in {1..6}; do curl -s http://158.160.184.65 | grep -o 'web-server-[ab]'; sleep 1; done
```
web-server-a
web-server-b
web-server-a
web-server-b
web-server-a
web-server-b

🔷 Мониторинг

| Сервис | ВМ | Порт | Протокол | Назначение | Статус |
|--------|----|------|----------|-----------|--------|
| **Prometheus** | monitoring-server | 9090 | HTTP | Сбор и хранение метрик | ✅ Работает |
| **Grafana** | monitoring-server (публичный) | 3000 | HTTP | Визуализация метрик, дашборды | ✅ Работает |
| **Node Exporter** | все ВМ (4 шт.) | 9100 | HTTP | Экспорт метрик ОС (CPU, RAM, Disk, Network) | ✅ Работает |
| **Nginx Log Exporter** | web-server-a, web-server-b | 9113 | HTTP | Экспорт метрик nginx (запросы, ответы, размер) | ⚙️ Готов к настройке |

Метрики для сбора:
- ✅ CPU utilization / saturation / errors
- ✅ RAM usage / available
- ✅ Disk usage / I/O
- ✅ Network traffic
- ✅ nginx: http_response_count_total, http_response_size_bytes

| Категория | Метрики | Thresholds (пороги) |
|-----------|---------|-------------------|
| **CPU** | `node_cpu_seconds_total`, `rate(node_cpu_seconds_total)` | Warning: >80%, Critical: >95% |
| **RAM** | `node_memory_MemTotal_bytes`, `node_memory_MemAvailable_bytes` | Warning: <20% free, Critical: <10% free |
| **Disk** | `node_filesystem_avail_bytes`, `node_filesystem_size_bytes` | Warning: >80% used, Critical: >95% used |
| **Network** | `node_network_receive_bytes_total`, `node_network_transmit_bytes_total` | Warning: >80% bandwidth |
| **nginx** | `http_response_count_total`, `http_response_size_bytes` | Warning: 5xx errors >1%/min |


🔷 Сбор логов

| Сервис | ВМ | Порт | Протокол | Назначение | Статус |
|--------|----|------|----------|-----------|--------|
| **Elasticsearch** | logging-server | 9200 | HTTP | Хранение и индексация логов | ✅ Работает (v7.17.0) |
| **Kibana** | logging-server (публичный) | 5601 | HTTP | Поиск, анализ и визуализация логов | ✅ Работает (статус: GREEN) |
| **Filebeat** | web-server-a, web-server-b | - | - | Сбор и отправка логов nginx в Elasticsearch | ✅ Работает (10 000+ событий) |


Конфигурация Filebeat:
```yaml
filebeat.inputs:
- type: filestream
  enabled: true
  id: nginx-logs
  paths:
    - /var/log/nginx/access.log
    - /var/log/nginx/error.log
  fields:
    server: web-server-a  # или web-server-b
    log_type: nginx

output.elasticsearch:
  hosts: ["10.0.1.15:9200"]
```  
Проверка отправки логов:

```bash
$ curl -s 'http://10.0.1.15:9200/filebeat-*/_search?size=1&pretty' -H 'Content-Type: application/json' -d'
{
  "query": { "match": { "fields.server": "web-server-b" }},
  "_source": ["message", "fields.server"],
  "sort": [ { "@timestamp": "desc" } ]
}' | jq '.hits.total.value'
10000  # ✅ Более 10 000 событий от каждого сервера
```

🔷 Резервное копирование
Скрипт: `backup.sh`
Функционал:
- ✅ Ежедневное создание снапшотов всех 5 дисков
- ✅ Автоматическое удаление снапшотов старше 7 дней
- ✅ Асинхронное выполнение для скорости

Запуск:

```bash
# Вручную
./backup.sh

# Ежедневно в 3:00 (crontab)
0 3 * * * /home/oleg/playground/devops-course/backup.sh >> /var/log/backup.log 2>&1
```
Проверка снапшотов:

```bash
$ yc compute snapshot list --folder-id b1gu6pcctq3f129snd9r
+----------------------+----------------------------+----------------------+----------+
|          ID          |            NAME            |     PRODUCT IDS      |  STATUS  |
+----------------------+----------------------------+----------------------+----------+
| fd89oehe1jo3b0db64pk | snapshot-epdv4m76-20260404 | f2enc5rilhjbemil8529 | READY    |
| fd8cmkgjskj8n269be3k | snapshot-fhmg5eac-20260404 | f2enc5rilhjbemil8529 | READY    |
| ...                  | ...                        | ...                  | ...      |
+----------------------+----------------------------+----------------------+----------+
```

🚀 Развёртывание
Предварительные требования
- ✅ Аккаунт Yandex Cloud с правами editor
- ✅ Установлен и настроен yc CLI
- ✅ Terraform 1.x
- ✅ Ansible 2.x
- ✅ Python 3.10+

Шаги

```bash
# 1. Клонировать репозиторий
git clone <your-repo>
cd devops-course

# 2. Настроить переменные
cp terraform.tfvars.example terraform.tfvars
# Отредактировать: folder_id, SSH ключи и т.д.

# 3. Развернуть инфраструктуру (Terraform)
terraform init
terraform plan
terraform apply -auto-approve

# 4. Настроить серверы (Ansible)
cd ansible
ansible-playbook playbooks/setup_all.yml -v

# 5. Проверить работу
curl -v http://<ALB_PUBLIC_IP>

# 6. Настроить бэкапы (опционально)
crontab -e
# Добавить: 0 3 * * * /path/to/backup.sh
```
🔐 Доступ к сервисам


---

## 🔐 Доступ к сервисам

```markdown
| Сервис | Тип | Адрес | Порт | Доступ из | Метод подключения |
|--------|-----|-------|------|-----------|------------------|
| **Сайт** | Публичный | `158.160.184.65` | 80 (HTTP) | Интернет (0.0.0.0/0) | `curl http://158.160.184.65` |
| **Kibana** | Публичный | `46.21.244.85` | 5601 (HTTP) | Интернет (0.0.0.0/0) | Браузер: `http://46.21.244.85:5601` |
| **Grafana** | Публичный | `84.252.129.62` | 3000 (HTTP) | Интернет (0.0.0.0/0) | Браузер: `http://84.252.129.62:3000` |
| **Elasticsearch** | Приватный | `10.0.1.15` | 9200 (HTTP) | Только из VPC (10.0.0.0/16) | `curl http://10.0.1.15:9200` (через bastion) |
| **Prometheus** | Приватный | `10.0.1.38` | 9090 (HTTP) | Только из VPC (10.0.0.0/16) | `curl http://10.0.1.38:9090` (через bastion) |
| **SSH ко всем ВМ** | Через Bastion | `84.252.129.233` | 22 (SSH) | Только через bastion | `ssh -J bastion web-a` |

```

Подключение через Bastion:

```bash
# ~/.ssh/config
Host bastion
    HostName 93.77.176.114
    User ubuntu
    IdentityFile ~/.ssh/id_rsa

Host monitoring
    HostName 10.0.1.38
    User ubuntu
    ProxyJump bastion

Host web-a
    HostName 10.0.2.13
    User ubuntu
    ProxyJump bastion

Host web-b
    HostName 10.0.4.15
    User ubuntu
    ProxyJump bastion

Host logging
    HostName 10.0.1.15
    User ubuntu
    ProxyJump bastion


# Подключение
ssh -J bastion web-a
ssh -J bastion web-b
ssh bastion
ssh logging 
ssh monitoring

```


---

## ⚖️ Почему выбраны именно эти технологии?

```markdown
| Решение | Альтернатива | Почему выбрано |
|---------|-------------|---------------|
| **Terraform + Ansible** | Только Terraform / Только Ansible / Pulumi | ✅ IaC для инфраструктуры + CM для конфигурации = лучшее разделение ответственности. Terraform идеален для создания ресурсов в Yandex Cloud, Ansible — для настройки ОС и сервисов. |
| **Filebeat 8.14.0** | Filebeat 7.17.0 / Logstash / Fluentd | ✅ Поддержка Ubuntu 22.04, тип `filestream` вместо устаревшего `log`. Лёгкий агент с минимальным потреблением ресурсов. |
| **Elasticsearch 7.17.0** | Elasticsearch 8.x / OpenSearch / Loki | ✅ Стабильная версия с полной совместимостью с курсовыми материалами. 8.x требует больше ресурсов и имеет breaking changes. |
| **Prometheus + Grafana** | Zabbix / Nagios / Datadog | ✅ Облачно-нативная архитектура, гибкие дашборды, активное сообщество. Prometheus идеально подходит для сбора метрик с Node Exporter. |
| **Application Load Balancer (Yandex)** | Nginx HAProxy / Cloudflare / Self-hosted | ✅ Управляемый сервис с автоматическим масштабированием, health checks и интеграцией с Yandex Cloud. Не нужно администрировать отдельно. |
| **Снапшоты через yc CLI** | Yandex Backup Service / Rclone / Velero | ✅ Простота реализации для курсовой, полный контроль над процессом, не требует дополнительных сервисов. |
| **Ubuntu 22.04 LTS** | CentOS 7/8 / Debian 11 / Alpine | ✅ Долгосрочная поддержка (до 2027), актуальные пакеты, хорошая совместимость с инструментами мониторинга и логирования. |
| **Security Groups вместо iptables** | Только iptables / UFW / Firewalld | ✅ Централизованное управление правилами в Yandex Cloud, визуализация, интеграция с VPC. |


