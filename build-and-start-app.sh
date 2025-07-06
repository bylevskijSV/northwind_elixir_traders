#!/bin/bash

app_uid=$(id -u)
app_gid=$(id -g)
echo "APP_UID=${app_uid}, APP_GID=${app_gid}"

export APP_UID=${app_uid}
export APP_GID=${app_gid}

if docker-compose up -d --build; then
  echo ""
  echo "✅ Сборка успешно завершена. Контейнер запущен."
else
  echo ""
  echo "❌ Ошибка: Сборка или запуск контейнера завершились с ошибкой."
  exit 1
fi
