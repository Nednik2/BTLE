#!/usr/bin/env bash
# Живой просмотр BLE в Wireshark на Linux.
# Положи рядом с бинарником btle_rx и запускай оттуда.
#
#   ./btle_wireshark.sh [канал] [LNA] [VGA]
#   канал 37/38/39 (по умолч. 37), LNA 0..40 шаг 8 (16), VGA 0..62 шаг 2 (20)
#   пример:  ./btle_wireshark.sh 38 24 20
#
# Остановка: Ctrl+C в этом терминале (скрипт сам подчистит FIFO и Wireshark).

DIR="$(cd "$(dirname "$0")" && pwd)"
CH=${1:-37}
LNA=${2:-16}
VGA=${3:-20}
shift 3 2>/dev/null || shift $# 2>/dev/null
FIFO=$(mktemp -u /tmp/btle.XXXXXX)

cleanup() { kill "$WS_PID" 2>/dev/null; rm -f "$FIFO"; }
trap cleanup EXIT INT TERM

mkfifo "$FIFO"
echo "Канал $CH, LNA $LNA dB, VGA $VGA dB"

# На Linux читатель (Wireshark) открывает FIFO первым и ждёт данные.
wireshark -k -i "$FIFO" >/dev/null 2>&1 &
WS_PID=$!
sleep 1

# btle_rx пишет pcap в FIFO. fopen на FIFO ждёт читателя — HackRF не
# захватывается, пока Wireshark не подключился.
"$DIR/btle_rx" -c "$CH" -l "$LNA" -g "$VGA" -s "$FIFO" "$@"
