#!/bin/bash

# Сохраняем первый IP-адрес сервера в переменную SERVER_IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Выводим значение переменной для проверки
echo "IP-адрес сервера: $SERVER_IP"

# Отключаем firewalld
echo "Отключение firewalld..."
systemctl stop firewalld
systemctl disable firewalld
echo "firewalld отключен и больше не будет запускаться автоматически."

# Очистка правил iptables
echo "Очистка всех правил iptables..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
echo "Все правила iptables очищены."

# Скачивание новых правил с GitHub
RULES_URL="https://raw.githubusercontent.com/username/repository/branch/iptables.rules" # Замените на фактический URL
RULES_FILE="/tmp/iptables.rules"
echo "Скачивание новых правил iptables с GitHub..."
curl -o "$RULES_FILE" "$RULES_URL"

# Применение новых правил через iptables-restore
if [[ -f "$RULES_FILE" ]]; then
    echo "Применение новых правил iptables..."
    iptables-restore < "$RULES_FILE"
    echo "Новые правила iptables успешно применены."
else
    echo "Ошибка: файл правил iptables не найден!"
    exit 1
fi

# Добавление iptables в автозагрузку
echo "Сохранение текущих правил iptables в автозагрузку..."
iptables-save > /etc/sysconfig/iptables
systemctl enable iptables
systemctl start iptables
echo "iptables добавлен в автозагрузку и запущен."

# Установка Xray через скрипт
echo "Установка Xray с помощью официального скрипта..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
if [[ $? -eq 0 ]]; then
    echo "Xray успешно установлен."
else
    echo "Ошибка установки Xray!"
    exit 1
fi

# Настройка Xray: генерация UUID и ключей x25519
echo "Настройка Xray..."

# Генерация UUID (логина пользователя)
UUID=$(./xray uuid)
if [[ $? -eq 0 ]]; then
    echo "UUID успешно сгенерирован: $UUID"
else
    echo "Ошибка при генерации UUID!"
    exit 1
fi

# Генерация ключей x25519 (публичный и приватный ключи)
X25519_OUTPUT=$(./xray x25519)
if [[ $? -eq 0 ]]; then
    # Извлечение приватного и публичного ключей из вывода
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

# Перезапуск службы Xray
echo "Перезапуск службы Xray..."
systemctl restart xray
if [[ $? -eq 0 ]]; then
    echo "Служба Xray успешно перезапущена."
else
    echo "Ошибка перезапуска службы Xray!"
    exit 1
fi


# Объявляем новый SSH порт
NEW_SSH_PORT=445

# Проверяем текущую версию системы и путь к SSH-конфигурации
SSH_CONFIG_FILE="/etc/ssh/sshd_config"

# Изменяем порт в конфигурации SSH
echo "Изменение стандартного SSH-порта на $NEW_SSH_PORT..."
if [[ -f "$SSH_CONFIG_FILE" ]]; then
    # Создаем резервную копию конфигурационного файла
    cp "$SSH_CONFIG_FILE" "$SSH_CONFIG_FILE.bak"
    echo "Резервная копия SSH-конфигурации сохранена как $SSH_CONFIG_FILE.bak."

    # Обновляем порт в конфигурации
    sed -i "s/^#Port 22/Port $NEW_SSH_PORT/" "$SSH_CONFIG_FILE"
    sed -i "s/^Port 22/Port $NEW_SSH_PORT/" "$SSH_CONFIG_FILE"

    # Перезапускаем службу SSH
    echo "Перезапуск SSH-службы..."
    systemctl restart sshd
    if [[ $? -eq 0 ]]; then
        echo "SSH успешно перезапущен. Теперь вы можете подключаться через порт $NEW_SSH_PORT."
    else
        echo "Ошибка перезапуска SSH! Проверьте конфигурацию."
        exit 1
    fi
else
    echo "Ошибка: файл $SSH_CONFIG_FILE не найден!"
    exit 1
fi


# Шаг: Формирование ссылки для подключения VLESS
echo "Формирование ссылки для подключения VLESS..."

# Формируем ссылку, используя значения переменных
VLESS_LINK="vless://${UUID}@${SERVER_IP}:443/?encryption=none&type=tcp&sni=${MASKING_DOMAIN}&fp=chrome&security=reality&alpn=h2&flow=xtls-rprx-vision&pbk=${PUBLIC_KEY}&packetEncoding=xudp"

# Сохраняем ссылку в файл
VLESS_LINK_FILE="/tmp/vless_connect_code"
echo "$VLESS_LINK" > "$VLESS_LINK_FILE"

# Проверяем, успешно ли сохранена ссылка
if [[ -f "$VLESS_LINK_FILE" ]]; then
    echo "Ссылка для подключения VLESS успешно сохранена в $VLESS_LINK_FILE."
    echo "Ссылка для подключения: $VLESS_LINK"
else
    echo "Ошибка при сохранении ссылки для подключения VLESS!"
    exit 1
fi
