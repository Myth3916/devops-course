#!/bin/bash
# backup.sh — ежедневное резервное копирование дисков в Yandex Cloud

set -e

FOLDER_ID="b1gu6pcctq3f129snd9r"  # Твой folder_id

# ✅ ID ДИСКОВ (вместо имён)
DISK_IDS=(
  "epdv4m76d7m5ditviunc"   # web-server-b (ru-central1-b)
  "fhm041nh5hfu453gi1ke"   # bastion-host
  "fhmemc7hio3slb45drid"   # web-server-a
  "fhmg5eaciq1k1e6uqtvj"   # monitoring-server
  "fhmt2qg5134tto07vvbu"   # logging-server
)

RETENTION_DAYS=7

echo "=== 📦 Создание снапшотов $(date) ==="

for disk_id in "${DISK_IDS[@]}"; do
  echo "🔄 Создаю снапшот для диска: $disk_id ..."
  yc compute snapshot create \
    --disk-id "$disk_id" \
    --name "snapshot-${disk_id:0:8}-$(date +%Y%m%d)" \
    --folder-id "$FOLDER_ID" \
    --async
done

echo "🧹 Удаляю снапшоты старше $RETENTION_DAYS дней..."
yc compute snapshot list --folder-id "$FOLDER_ID" --format json | \
  jq -r --arg cutoff "$(date -d "$RETENTION_DAYS days ago" -Iseconds)" \
  '.[] | select(.created_at < $cutoff) | .id' | \
  xargs -r -I {} yc compute snapshot delete {} --async

echo "✅ Готово! Снапшоты созданы, старые удалены."