#!/bin/bash
# Установка Xray через скрипт
echo "Установка Xray с помощью официального скрипта..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
if [[ $? -eq 0 ]]; then
    echo "Xray успешно установлен."
else
    echo "Ошибка установки Xray!"
    exit 1
fi