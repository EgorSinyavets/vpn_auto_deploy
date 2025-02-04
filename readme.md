Скрипт для настройки сервера и установки VPN 


Можно запустить одной командой с сервера:
bash -c "$(curl -L https://raw.githubusercontent.com/EgorSinyavets/vpn_auto_deploy/refs/heads/main/server_prepare_menu.sh)"

Тестировался на Alma Linux 9.

Требования:
- RHEL like or Debian like OS

Возможности скрипта:
     "1) Установка и настройка vless+xray"
     "2) Полное удаление vless+xray"
     "3) Очистка всех firewall правил"
     "4) Настройка безопасности для xray "
     "5) Настройка безопасности для amnesia"
     "6) Добавить порт или адрес в firewall"
     "7) Смена ssh порта на кастомный"



ВАЖНО: Во время установки вы должны будете ввести маскировочный домен (в идеале вы должны сами его определить, примеры www.amazon.com, images.apple.com)





