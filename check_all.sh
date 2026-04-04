#!/bin/bash
# check_all.sh — быстрая проверка инфраструктуры

echo "=== 🚀 Проверка инфраструктуры ==="

# 1. Elasticsearch
echo -n "Elasticsearch: "
if curl -s --connect-timeout 5 http://10.0.1.15:9200 | grep -q '"number":"7.17.0"'; then
  echo "✅ OK (v7.17.0)"
else
  echo "❌ DOWN"
fi

# 2. Kibana
echo -n "Kibana: "
if curl -s --connect-timeout 5 http://46.21.244.85:5601/api/status | grep -q '"number":"7.17.0"'; then
  echo "✅ OK (v7.17.0)"
else
  echo "❌ DOWN"
fi

# 3. Load Balancer
echo -n "Load Balancer: "
RESP=$(curl -s --connect-timeout 5 http://158.160.184.65)
if echo "$RESP" | grep -q "Web Server"; then
  SERVER=$(echo "$RESP" | grep -o 'Web Server [AB]' | head -1)
  echo "✅ OK ($SERVER)"
else
  echo "❌ DOWN"
fi

# 4. Filebeat статус
echo -n "Filebeat (web-a): "
if ssh -J bastion web-a "sudo systemctl is-active filebeat" 2>/dev/null | grep -q active; then
  echo "✅ active"
else
  echo "❌ inactive"
fi

# 5. Grafana
echo -n "Grafana: "
if curl -s --connect-timeout 5 http://84.252.129.62:3000/api/health | grep -q '"database":"ok"'; then
  echo "✅ OK"
else
  echo "❌ DOWN (или ещё устанавливается)"
fi

echo "=== ✅ Проверка завершена ==="