@echo off
rem Live BLE sniffing into Wireshark:
rem   btle_wireshark.bat [channel] [lna_dB] [vga_dB] [extra btle_rx options]
rem   channel 37/38/39 (default 37), LNA 0..40 step 8 (default 16), VGA 0..62 step 2 (default 20)
rem   example: btle_wireshark.bat 38 8 30
cd /d "%~dp0"
rem a leftover btle_rx keeps the HackRF busy (semaphore timeout / access denied)
taskkill /IM btle_rx.exe /F >nul 2>&1
set CH=%~1
set LNA=%~2
set VGA=%~3
if "%CH%"=="" set CH=37
if "%LNA%"=="" set LNA=16
if "%VGA%"=="" set VGA=20
echo Channel %CH%, LNA %LNA% dB, VGA %VGA% dB
rem btle_rx creates the pipe, so give it a head start before Wireshark connects
start "" /min cmd /c "timeout /t 3 /nobreak >nul & start "" "C:\Program Files\Wireshark\Wireshark.exe" -k -i \\.\pipe\btle"
"%~dp0btle_rx.exe" -c %CH% -l %LNA% -g %VGA% -s \\.\pipe\btle %4 %5 %6 %7 %8 %9
