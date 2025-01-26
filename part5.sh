#!/bin/bash
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