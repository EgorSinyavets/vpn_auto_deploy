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

# Функции для разных действий
function action1() {
    
    echo "Выполняется установка и настройка xray + vless"
    
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
    echo "Выполняется очистка firewall правил"

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

    # Очистка всех правил iptables
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -t raw -F
    iptables -t raw -X

    # Установка политик по умолчанию на ACCEPT
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    pause
    }

function action4() {
    echo "Выполняется настройка безопасности для xray + vless"
    
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


    # Функция для выбора варианта
    choose_option() {
        echo "Выберите вариант:"
        echo "1) Разрешить доступ по всем портам для указанной подсети."
        echo "2) Разрешить доступ к определенному SSH порту для всех."
        read -p "Введите номер варианта (1 или 2): " choice

        case $choice in
            1)
                read -p "Введите домашнюю подсеть (например, 145.218.0.0/16): " subnet
                ;;
            2)
                read -p "Введите порт SSH (по умолчанию 22): " ssh_port
                ssh_port=${ssh_port:-22}  # Если порт не введен, используем 22
                ;;
            *)
                echo "Неверный выбор. Завершение скрипта."
                exit 1
                ;;
        esac
    }

    # Очистка всех правил и установка политик по умолчанию
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -t raw -F
    iptables -t raw -X

    # Установка политик по умолчанию
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    # Разрешить локальный трафик
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Разрешить установленные и связанные соединения
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Выбор варианта
    choose_option

    # Применение выбранного варианта
    case $choice in
        1)
            # Разрешить доступ по всем портам для указанной подсети
            iptables -A INPUT -s $subnet -j ACCEPT
            echo "Доступ по всем портам разрешен для подсети $subnet."
            ;;
        2)
            # Разрешить доступ к порту SSH для всех
            iptables -A INPUT -p tcp --dport $ssh_port -j ACCEPT
            echo "Доступ к порту $ssh_port (SSH) разрешен для всех."
            ;;
    esac

    # Разрешить доступ по портам 80 (HTTP) и 443 (HTTPS) для всех
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    echo "Доступ по портам 80 (HTTP) и 443 (HTTPS) разрешен для всех."

    # Сохранение правил
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4

    # Установка iptables-persistent (если не установлен)
    if ! command -v netfilter-persistent &> /dev/null; then
        echo "Установка iptables-persistent..."
        sudo apt update
        sudo apt install iptables-persistent -y
    fi

    # Включение автозагрузки правил
    systemctl enable netfilter-persistent

    echo "Правила iptables настроены и сохранены в автозагрузку."

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
    echo "3) Очистка всех firewall правил"
    echo "4) Настройка безопасности для xray "
    echo "5) Настройка безопасности для amnesia"
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
