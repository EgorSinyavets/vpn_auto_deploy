#!/bin/bash

# Переменные
RULES_URL="https://raw.githubusercontent.com/EgorSinyavets/vpn_auto_deploy/refs/heads/main/fw_actual.v4" # URL для скачивания правил
RULES_DIR="/etc/iptables"
RULES_FILE="$RULES_DIR/fw_actual.v4"

# Установка пакета iptables-services, если он отсутствует
if ! rpm -q iptables-services &> /dev/null; then
    echo "Установка iptables-services..."
    yum install -y iptables-services
fi

# Создание директории для хранения правил, если её нет
if [[ ! -d "$RULES_DIR" ]]; then
  echo "Создание директории для хранения правил iptables: $RULES_DIR"
  mkdir -p "$RULES_DIR"
fi

# Скачивание новых правил с GitLab
echo "Скачивание новых правил iptables с GitLab..."
curl -o "$RULES_FILE" "$RULES_URL"
if [[ $? -ne 0 ]]; then
  echo "Ошибка: не удалось скачать файл правил. Проверьте URL и соединение."
  exit 1
fi
echo "Правила iptables успешно скачаны в $RULES_FILE."

# Применение новых правил через iptables-restore
if [[ -f "$RULES_FILE" ]]; then
    echo "Применение новых правил iptables..."
    iptables-restore < "$RULES_FILE"
    if [[ $? -ne 0 ]]; then
      echo "Ошибка: не удалось применить правила iptables."
      exit 1
    fi
    echo "Новые правила iptables успешно применены."
else
    echo "Ошибка: файл правил iptables не найден!"
    exit 1
fi

# Настройка iptables для автозагрузки
echo "Сохранение текущих правил iptables в автозагрузку..."
iptables-save > /etc/sysconfig/iptables

# Включение iptables в автозагрузку и запуск службы
echo "Включение iptables в автозагрузку..."
systemctl enable iptables
systemctl start iptables
echo "iptables добавлен в автозагрузку и запущен."
