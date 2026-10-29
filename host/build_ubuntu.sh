#!/usr/bin/env bash
# Сборка BTLE (btle_rx/btle_tx) на Ubuntu/Debian.
# Запуск:  bash build_ubuntu.sh
set -e

echo "== 1. Зависимости =="
sudo apt-get update
sudo apt-get install -y build-essential cmake libhackrf-dev hackrf wireshark

echo "== 2. Права на HackRF без root (udev) =="
# В репозитории есть готовые правила; ставим их и перечитываем.
sudo cp "$(dirname "$0")/btle-tools/52-hackrf.rules" /etc/udev/rules.d/ 2>/dev/null || true
sudo udevadm control --reload-rules && sudo udevadm trigger
# после этого ПЕРЕВОТКНИ HackRF в USB, чтобы правила применились

echo "== 3. Сборка =="
cd "$(dirname "$0")"
rm -rf build
cmake -S . -B build \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_C_FLAGS=-std=gnu11
cmake --build build -j

echo "== Готово =="
echo "Бинарник: $(pwd)/build/btle-tools/src/btle_rx"
"$(pwd)/build/btle-tools/src/btle_rx" -h | head -2 || true
echo
echo "Проверь прибор:  hackrf_info"
echo "Скопируй скрипт запуска рядом с бинарником:"
echo "  cp btle-tools/src/btle_wireshark.sh build/btle-tools/src/ && chmod +x build/btle-tools/src/btle_wireshark.sh"
