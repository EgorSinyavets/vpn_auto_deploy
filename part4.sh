#!/bin/bash
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