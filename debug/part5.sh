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