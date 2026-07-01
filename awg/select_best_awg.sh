#!/bin/bash

# --- НАСТРОЙКИ ---
CONFIGS_DIR="/home/anton/awg_configs"
GAME_SERVER_IP="1.2.3.4"       # Сюда впишите IP сервера BF6
GAME_SERVER_PORT="443"         # Сюда порт (TCP предпочтительнее для точного замера)
INTERFACE_NAME="awg-best"      # Имя поднимаемого интерфейса
TIMEOUT_SEC=2                  # Таймаут на одну попытку

# Проверка на права root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт от имени root (sudo)."
  exit 1
fi

# Отключаем текущий интерфейс, если он запущен
echo "Очистка старых соединений..."
awg-quick down "$INTERFACE_NAME" 2>/dev/null

BEST_CONFIG=""
BEST_PING=99999

# Создаем временную директорию для теста одного конфига
TMP_CONF="/etc/amneziawg/${INTERFACE_NAME}.conf"

cd "$CONFIGS_DIR" || exit 1

echo "Начинаем тестирование конфигураций..."
echo "------------------------------------------------"

for config in *.conf; do
    [ -e "$config" ] || continue
    echo "Тестируем: $config"
    
    # Копируем конфиг в системную директорию AWG под стандартным именем тестируемого интерфейса
    cp "$config" "$TMP_CONF"
    
    # Поднимаем туннель
    awg-quick up "$INTERFACE_NAME" >/dev/null 2>&1
    
    # Даем 1 секунду на инициализацию туннеля и хэндшейк
    sleep 1
    
    # --- УМНЫЙ ПИНГ (TCP Handshake) ---
    # Измеряем время выполнения запроса netcat в миллисекундах
    start_time=$(date +%s%N)
    nc -w "$TIMEOUT_SEC" -z "$GAME_SERVER_IP" "$GAME_SERVER_PORT" >/dev/null 2>&1
    exit_code=$?
    end_time=$(date +%s%N)
    
    # Опускаем туннель сразу после теста
    awg-quick down "$INTERFACE_NAME" >/dev/null 2>&1
    rm -f "$TMP_CONF"

    if [ $exit_code -eq 0 ]; then
        # Считаем разницу в мс
        duration=$(( (end_time - start_time) / 1000000 ))
        echo "Успешно! Отклик (TCP): ${duration} ms"
        
        # Ищем минимальный пинг
        if [ "$duration" -lt "$BEST_PING" ]; then
            BEST_PING=$duration
            BEST_CONFIG=$config
        fi
    else
        echo "Ошибка: Сервер недоступен через этот конфиг (Таймаут)."
    fi
    echo "------------------------------------------------"
done

# --- ИТОГ ---
if [ -n "$BEST_CONFIG" ]; then
    echo "=== РЕЗУЛЬТАТ ==="
    echo "Лучший конфиг: $BEST_CONFIG с откликом ${BEST_PING}ms"
else
    echo "Критическая ошибка: Ни один из конфигов не смог подключиться к серверу."
    exit 1
fi
