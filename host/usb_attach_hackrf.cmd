@echo off
rem Привязать HackRF и пробросить его в WSL Ubuntu. Запускать от администратора
rem (скрипт сам запросит повышение прав).
net session >nul 2>&1 || (powershell -Command "Start-Process '%~f0' -Verb RunAs" & exit /b)

set USBIPD="C:\Program Files\usbipd-win\usbipd.exe"
set BUSID=2-4

echo === bind %BUSID% ===
%USBIPD% bind --busid %BUSID% --force
echo === attach --wsl %BUSID% ===
%USBIPD% attach --wsl --busid %BUSID% --distribution Ubuntu
echo.
echo === текущее состояние ===
%USBIPD% list
echo.
echo Готово. Окно можно закрыть.
pause
