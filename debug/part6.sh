"

# Объявляем новый SSH порт
NEW_SSH_PORT=449

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

# Перезапуск службы Ssh
echo "Перезапуск службы SSH..."
systemctl restart sshd
if [[ $? -eq 0 ]]; then
    echo "Служба SSHD успешно перезапущена. Теперь вы можете подключаться через порт $NEW_SSH_PORT"
else
    echo "Ошибка перезапуска службы SSHD!"
    exit 1
fi