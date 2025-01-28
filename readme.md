Скрипт для натсройки сервера и установки VPN xray-vless

Тестировался на Alma Linux 9.

Требования:
- RHEL like OS
- белый ip v4

Что делает скрипт:
- отключает firewalld , включает iptables
- применяет правила с "https://raw.githubusercontent.com/EgorSinyavets/vpn_auto_deploy/refs/heads/main/fw_actual.v4" . ( необходимо вставить ссылку на ваши правила или переделать эти т.к. идет првязка к ip подсетям, с которых возможно администрирование сервера в будущем)
- устанавливает xray через официальный скрипт
- настраивает xray (генерирует и сохраняет uuid, публичный и приватный ключи)
- сохраняет конфигурацию xray на основе ваших данных
- формирует ссылку для hiddify и других клиентов (показывает в консоле + сохраняет в /tmp/vless_connect_code)
- меняет порт ssh на нестандартный 449

Можно запустить одной командой с сервера:
bash -c "$(curl -L https://raw.githubusercontent.com/EgorSinyavets/vpn_auto_deploy/refs/heads/main/server_prepare_xray_install.sh)"

ВАЖНО: Во время установки вы должны будете ввести маскировочный домен (в идеале вы должны сами его определить, примеры www.amazon.com, images.apple.com)