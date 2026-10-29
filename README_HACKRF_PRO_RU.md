# BTLE-сниффер на HackRF Pro — Windows, Linux и WSL

Инструкция по сборке и использованию `btle_rx` (BLE-сниффер) на **HackRF Pro**
с прошивкой Mayhem. Проверено на реальном эфире: приём рекламных BLE-пакетов
на каналах 37/38/39 — под Windows (MSYS2), под Ubuntu и под Ubuntu в WSL2 с
пробросом USB через `usbipd`.

## Содержание

- [Что исправлено в коде](#что-исправлено-в-коде)
- [Windows: сборка](#windows-сборка)
- [Windows: использование](#windows-использование)
- [Linux (Ubuntu/Debian): сборка](#linux-ubuntudebian-сборка)
- [Linux: использование](#linux-использование)
- [WSL2: проброс HackRF через usbipd](#wsl2-проброс-hackrf-через-usbipd)
- [Подбор усиления](#подбор-усиления)
- [Фильтры Wireshark](#фильтры-wireshark)
- [Что видно, а что нет](#что-видно-а-что-нет)
- [Решение проблем](#решение-проблем)

---

## Что исправлено в коде

Правки кроссплатформенные (под `#ifdef _WIN32`), оригинальное поведение на
Linux сохранено.

| Файл | Изменение |
|------|-----------|
| `host/btle-tools/src/btle_rx.c` | В pcap писался индекс BLE-канала (37/38/39) вместо номера **физического RF-канала** → Wireshark определял пакеты неверно. Теперь пишется RF-channel (ch37→0, ch38→12, ch39→39). |
| `host/btle-tools/src/btle_rx.c` | В pcap не дописывались **3 байта CRC** → все пакеты были `Malformed`. Теперь длина записи включает CRC. |
| `host/btle-tools/src/btle_rx.c` | `fflush` после каждого пакета — для живого просмотра и чтобы не терять хвост файла при остановке. |
| `host/btle-tools/src/btle_rx.c` | На Windows вместо `netinet/in.h` подключается `winsock2.h`; добавлен именованный канал `\\.\pipe\...` для живого Wireshark; `#include <io.h>`. |
| `host/btle-tools/src/CMakeLists.txt` | Линковка с `ws2_32` на Windows. |

> **Про тулчейн:** gcc 15/16 по умолчанию использует C23, где `bool` —
> ключевое слово и старый код не собирается. Поэтому собираем с `-std=gnu11`.
> cmake 4 требует `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`.

---

## Windows: сборка

Нужен [MSYS2](https://www.msys2.org/). В оболочке **UCRT64**:

```bash
pacman -S --needed mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-cmake \
                   mingw-w64-ucrt-x86_64-ninja mingw-w64-ucrt-x86_64-hackrf

cd host
cmake -S . -B build -G Ninja -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_C_FLAGS=-std=gnu11
cmake --build build
```

Бинарники: `host/build/btle-tools/src/btle_rx.exe` и `btle_tx.exe`.
Рядом с ними положи DLL из MSYS2, чтобы запускать без настройки PATH:
`libhackrf.dll`, `libusb-1.0.dll`, `libwinpthread-1.dll`
(из `D:\msys64\ucrt64\bin` или где установлен MSYS2).

---

## Windows: использование

Полная версия — в [`host/README_RU.txt`](host/README_RU.txt).

**Живой просмотр в Wireshark** (скрипт сам создаёт именованный канал и
открывает Wireshark):

```bat
cd host\build\btle-tools\src
btle_wireshark.bat [канал] [LNA] [VGA]
```

| Параметр | Диапазон | По умолчанию |
|----------|----------|--------------|
| канал | 37 / 38 / 39 | 37 |
| LNA | 0..40, шаг 8 | 16 |
| VGA | 0..62, шаг 2 | 20 |

Примеры: `btle_wireshark.bat`, `btle_wireshark.bat 38 24 20`.
**Остановка:** закрыть чёрное окно консоли (одного Wireshark мало).

**Запись в файл:**

```bat
btle_rx.exe -c 37 -l 16 -g 20 -s capture.pcap
```

---

## Linux (Ubuntu/Debian): сборка

Одной командой — скрипт [`host/build_ubuntu.sh`](host/build_ubuntu.sh):

```bash
cd host
bash build_ubuntu.sh
```

Он ставит `build-essential cmake libhackrf-dev hackrf wireshark`, кладёт
udev-правила (после этого **перевоткни HackRF**) и собирает с нужными флагами.

Вручную:

```bash
sudo apt-get install -y build-essential cmake libhackrf-dev hackrf wireshark
cd host
cmake -S . -B build -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_C_FLAGS=-std=gnu11
cmake --build build -j
```

Захват в Wireshark без root:

```bash
sudo usermod -aG wireshark $USER   # затем перелогиниться
```

---

## Linux: использование

Полная версия — в [`host/README_LINUX_RU.txt`](host/README_LINUX_RU.txt).

**Живой просмотр** — скрипт [`host/btle-tools/src/btle_wireshark.sh`](host/btle-tools/src/btle_wireshark.sh)
(создаёт FIFO в `/tmp`, запускает Wireshark, затем `btle_rx`):

```bash
cp host/btle-tools/src/btle_wireshark.sh host/build/btle-tools/src/
chmod +x host/build/btle-tools/src/btle_wireshark.sh
cd host/build/btle-tools/src
./btle_wireshark.sh 37 16 20     # канал, LNA, VGA
```

На Linux **первым** стартует Wireshark (читатель FIFO), затем `btle_rx` —
в отличие от Windows. Остановка: `Ctrl+C`.

**Запись в файл:**

```bash
./btle_rx -c 37 -l 16 -g 20 -s capture.pcap
```

---

## WSL2: проброс HackRF через usbipd

HackRF подключён к Windows, а `btle_rx` работает внутри WSL. Нужен
[usbipd-win](https://github.com/dorssel/usbipd-win) (ставится на Windows,
требует прав администратора). Готовый скрипт —
[`host/usb_attach_hackrf.cmd`](host/usb_attach_hackrf.cmd).

```powershell
# 1. Узнать BUSID прибора (например, 2-4)
usbipd list

# 2. Привязать (нужен админ; --force из-за фильтра USBPcap)
usbipd bind -b 2-4 --force

# 3. Дистрибутив WSL должен быть запущен — в отдельном окне:
wsl -d Ubuntu

# 4. Пробросить (в usbipd 5.x имя идёт через --wsl, флага -d НЕТ)
usbipd attach -b 2-4 -w Ubuntu
```

Проверка внутри WSL: `hackrf_info` должен найти прибор.
**Вернуть в Windows:** `usbipd detach -b 2-4` или переткнуть USB
(привязка `bind` переживает переподключение, `attach` — нет).

> При USB/IP-пробросе невалидных пакетов (`CRC1`) обычно больше из-за задержек
> на шине, но приём работает.

---

## Подбор усиления

| Ситуация | Действие |
|----------|----------|
| Пакетов мало или нет | Поднимай LNA: 16 → 24 → 32 |
| Прибор вплотную к источнику | Снижай: LNA 0..8, VGA 10..20 |
| Много пакетов `Malformed` | Перегрузка — снизь усиление |

Число пакетов скачет между запусками — эфир нерегулярный, это нормально.

---

## Фильтры Wireshark

```
!_ws.malformed                                 # скрыть битые
btle.advertising_address == aa:bb:cc:dd:ee:ff  # одно устройство
btle.advertising_header.pdu_type == 0x00       # только ADV_IND
btcommon.eir_ad.entry.device_name              # пакеты с именем устройства
```

---

## Что видно, а что нет

На каналах 37/38/39 ловятся **только рекламные пакеты** (маячки): MAC-адрес,
тип устройства, имя, данные производителя.

Содержимое соединений (клавиатуры, наушники, обмен данными) **не видно**:
после сопряжения оно шифруется и прыгает по 37 каналам данных.

---

## Решение проблем

| Симптом | Решение |
|---------|---------|
| `netinet/in.h: No such file` при сборке на Windows | Собрано без правок этого форка — обнови исходники. |
| `'bool' cannot be defined via typedef` | Не задан `-std=gnu11`. |
| `cmake ... policy version` | Не задан `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`. |
| `bad interpreter` у `.sh` на Linux | Файл с CRLF: `dos2unix script.sh` (в этом форке `.gitattributes` хранит `.sh` как LF). |
| «Превышен таймаут семафора» / `Access denied` (Windows) | Прибор занят зависшим процессом: `taskkill /IM btle_rx.exe /F`. |
| `The selected WSL distribution is not running` | Открой окно `wsl -d Ubuntu` и держи его перед `attach`. |
| `-d was not matched` у usbipd | В версии 5.x имя дистрибутива — через `-w Ubuntu`, не `-d`. |
| Прибор не находится | Включи режим HackRF на PortaPack; проверь `hackrf_info`. |
