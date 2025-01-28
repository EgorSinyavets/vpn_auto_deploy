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