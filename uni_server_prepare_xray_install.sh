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

# Установка Xray через скрипт
echo "Установка Xray с помощью официального скрипта..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install #последний скрипт
#bash -c "$(curl -L https://raw.githubusercontent.com/EgorSinyavets/vpn_auto_deploy/refs/heads/main/backup_xray_install_script.sh)" @ install --version v1.8.10
 #точно рабочий скрипт
if [[ $? -eq 0 ]]; then
    echo "Xray успешно установлен."
else
    echo "Ошибка установки Xray!"
    exit 1
fi

# Настройка Xray: генерация UUID и ключей x25519
echo "Настройка Xray..."

# Генерация UUID (логина пользователя)
UUID=$(xray uuid)
if [[ $? -eq 0 ]]; then
    echo "UUID успешно сгенерирован: $UUID"
else
    echo "Ошибка при генерации UUID!"
    exit 1
fi

# Генерация ключей x25519 (публичный и приватный ключи)
X25519_OUTPUT=$(xray x25519)
if [[ $? -eq 0 ]]; then
    # Извлечение приватного и публичного ключей из вывода
    echo "$X25519_OUTPUT"
    PRIVATE_KEY=$(echo "$X25519_OUTPUT" | grep -i "Private key:" | awk -F ': ' '{print $2}')
    PUBLIC_KEY=$(echo "$X25519_OUTPUT" | grep -i "Public key:" | awk -F ': ' '{print $2}')
    echo "Приватный ключ: $PRIVATE_KEY"
    echo "Публичный ключ: $PUBLIC_KEY"
else
    echo "Ошибка при генерации ключей x25519!"
    exit 1
fi

# Запрос маскировочного домена у пользователя
read -p "Введите маскировочный домен: " MASKING_DOMAIN
if [[ -z "$MASKING_DOMAIN" ]]; then
    echo "Маскировочный домен не может быть пустым!"
    exit 1
fi
echo "Маскировочный домен: $MASKING_DOMAIN"

# Сохранение переменных в файл
VARS_FILE="/usr/local/etc/xray/script_vars"
echo "Сохранение переменных в $VARS_FILE..."
mkdir -p "$(dirname "$VARS_FILE")"
{
    echo "SERVER_IP=$SERVER_IP"
    echo "UUID=$UUID"
    echo "MASKING_DOMAIN=$MASKING_DOMAIN"
    echo "PRIVATE_KEY=$PRIVATE_KEY"
    echo "PUBLIC_KEY=$PUBLIC_KEY"
} > "$VARS_FILE"

# Создание конфигурационного файла Xray
CONFIG_FILE="/usr/local/etc/xray/config.json"

echo "Создание конфигурационного файла $CONFIG_FILE..."
cat <<EOF > "$CONFIG_FILE"
{
  "log": {
    "loglevel": "info"
  },
  "inbounds": [
    {
      "listen": "$SERVER_IP",
      "port": 443,
      "protocol": "vless",
      "tag": "reality-in",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "email": "user1",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$MASKING_DOMAIN:443",
          "xver": 0,
          "serverNames": [
            "$MASKING_DOMAIN"
          ],
          "privateKey": "$PRIVATE_KEY",
          "minClientVer": "",
          "maxClientVer": "",
          "maxTimeDiff": 0,
          "shortIds": [""]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "protocol": "bittorrent",
        "outboundTag": "block"
      }
    ],
    "domainStrategy": "IPIfNonMatch"
  }
}
EOF

if [[ -f "$CONFIG_FILE" ]]; then
    echo "Файл $CONFIG_FILE успешно создан."
else
    echo "Ошибка создания файла $CONFIG_FILE!"
    exit 1
fi

# Изменение порта SSH
NEW_SSH_PORT=449
sed -i "s/^#Port 22/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^Port 22/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
systemctl restart sshd
echo "SSH теперь работает на порту $NEW_SSH_PORT."

# Вывод ссылки VLESS
VLESS_LINK="vless://${UUID}@${SERVER_IP}:443/?sni=${MASKING_DOMAIN}&security=reality&pbk=${PUBLIC_KEY}"
echo "Ссылка для подключения VLESS: $VLESS_LINK"
