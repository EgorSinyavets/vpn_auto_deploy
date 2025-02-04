#!/bin/bash

# Функции для разных действий
function action1() {
    
    echo "Выполняется установка и настройка xray + vless"
    
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
    GITHUB_URL="https://raw.githubusercontent.com/EgorSinyavets/vpn_auto_deploy/refs/heads/main/config.json"

    # Скачивание файла с GitHub
    curl -o /tmp/config.conf "$GITHUB_URL"

    # Замена переменных в файле
    sed -i "s/\$SERVER_IP/$SERVER_IP/g" /tmp/config.conf
    sed -i "s/\$UUID/$UUID/g" /tmp/config.conf
    sed -i "s/\$MASKING_DOMAIN/$MASKING_DOMAIN/g" /tmp/config.conf
    sed -i "s/\$PRIVATE_KEY/$PRIVATE_KEY/g" /tmp/config.conf

    # Перемещение файла в нужное место (опционально)
    mv /tmp/config.conf /usr/local/etc/xray/config.json

    echo "Конфигурационный файл обновлен и перемещен по адресу /usr/local/etc/xray/config.json "
    

    # Перезапуск службы Xray
    echo "Перезапуск службы Xray..."
    systemctl restart xray
    if [[ $? -eq 0 ]]; then
        echo "Служба Xray успешно перезапущена."
    else
        echo "Ошибка перезапуска службы Xray!"
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
        echo "Ссылка для подключения(вставьте ее в клиент типа hiddify): $VLESS_LINK"
    else
        echo "Ошибка при сохранении ссылки для подключения VLESS!"
        exit 1
    fi 
        
    
    pause
}

function action2() {
    echo "Выполняется полное удаление vless + xray"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
    pause
}

function action3() {
    echo "Выполняется действие 3..."
    # Добавьте код для третьего действия
    pause
}

function action4() {
    echo "Выполняется действие 4..."
    # Добавьте код для четвертого действия
    pause
}

function action5() {
    echo "Выполняется действие 5..."
    # Добавьте код для пятого действия
    pause
}

function action6() {
    echo "Выполняется действие 6..."
    # Добавьте код для шестого действия
    pause
}

# Функция паузы перед возвратом в меню
function pause() {
    read -p "Нажмите Enter, чтобы вернуться в меню..."
}

# Основное меню
while true; do
    clear
    echo "============================"
    echo "   Выберите действие:       "
    echo "============================"
    echo "1) Установка и настройка vless+xray"
    echo "2) Полное удаление vless+xray"
    echo "3) Настройка безопасности для xray"
    echo "4) Настройка безопасности для amnesia"
    echo "5) Настройка безопасности комплексная (amnesia+xray+other)"
    echo "6) Добавить домашний ip адрес для администрирования"
    echo "7) Смена ssh порта на 449"
    echo "8) Выход"
    echo "============================"
    read -p "Введите номер действия: " choice

    case $choice in
        1) action1 ;;
        2) action2 ;;
        3) action3 ;;
        4) action4 ;;
        5) action5 ;;
        6) action6 ;;
        7) action7 ;;
        8) echo "Выход..."; exit 0 ;;
        *) echo "Ошибка: выберите число от 1 до 7!" ; pause ;;
    esac
done
