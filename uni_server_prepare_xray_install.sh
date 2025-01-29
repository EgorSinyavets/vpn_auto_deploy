#!/bin/bash

# Определяем дистрибутив
if [ -f /etc/redhat-release ]; then
    DISTRO="alma"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
else
    echo "Ошибка: неподдерживаемая ОС"
    exit 1
fi

# Сохраняем первый IP-адрес сервера
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "IP-адрес сервера: $SERVER_IP"

# Отключаем firewalld (только для AlmaLinux)
if [ "$DISTRO" == "alma" ]; then
    echo "Отключение firewalld..."
    systemctl stop firewalld
    systemctl disable firewalld
fi

# Установка необходимых пакетов
if [ "$DISTRO" == "alma" ]; then
    yum install -y iptables-services curl
elif [ "$DISTRO" == "debian" ]; then
    apt update && apt install -y iptables iptables-persistent curl
fi

# Очистка iptables
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

echo "Все правила iptables очищены."

# Настройка iptables
RULES_URL="https://raw.githubusercontent.com/EgorSinyavets/vpn_auto_deploy/refs/heads/main/fw_actual.v4"
RULES_DIR="/etc/iptables"
RULES_FILE="$RULES_DIR/fw_actual.v4"

mkdir -p "$RULES_DIR"
curl -o "$RULES_FILE" "$RULES_URL"

if [[ -f "$RULES_FILE" ]]; then
    iptables-restore < "$RULES_FILE"
    echo "Правила iptables применены."
else
    echo "Ошибка: не удалось скачать файл правил!"
    exit 1
fi

# Сохранение правил iptables в автозагрузку
if [ "$DISTRO" == "alma" ]; then
    iptables-save > /etc/sysconfig/iptables
    systemctl enable iptables
    systemctl start iptables
elif [ "$DISTRO" == "debian" ]; then
    iptables-save > /etc/iptables/rules.v4
    systemctl enable netfilter-persistent
    systemctl restart netfilter-persistent
fi

echo "Установка Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Генерация UUID и ключей x25519
UUID=$(xray uuid)
X25519_OUTPUT=$(xray x25519)
PRIVATE_KEY=$(echo "$X25519_OUTPUT" | grep -i "Private key:" | awk -F ': ' '{print $2}')
PUBLIC_KEY=$(echo "$X25519_OUTPUT" | grep -i "Public key:" | awk -F ': ' '{print $2}')

echo "Введите маскировочный домен: "
read MASKING_DOMAIN

# Создание конфигурационного файла Xray
CONFIG_FILE="/usr/local/etc/xray/config.json"
cat <<EOF > "$CONFIG_FILE"
{
  "log": { "loglevel": "info" },
  "inbounds": [
    {
      "listen": "$SERVER_IP",
      "port": 443,
      "protocol": "vless",
      "settings": { "clients": [{ "id": "$UUID", "flow": "xtls-rprx-vision" }] },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": { "privateKey": "$PRIVATE_KEY", "serverNames": ["$MASKING_DOMAIN"] }
      }
    }
  ]
}
EOF

systemctl restart xray
echo "Xray перезапущен."

# Изменение порта SSH
NEW_SSH_PORT=449
sed -i "s/^#Port 22/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^Port 22/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
systemctl restart sshd
echo "SSH теперь работает на порту $NEW_SSH_PORT."

# Вывод ссылки VLESS
VLESS_LINK="vless://${UUID}@${SERVER_IP}:443/?sni=${MASKING_DOMAIN}&security=reality&pbk=${PUBLIC_KEY}"
echo "Ссылка для подключения VLESS: $VLESS_LINK"
