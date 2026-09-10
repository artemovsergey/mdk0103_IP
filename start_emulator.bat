@echo off
chcp 65001 >nul

set "ANDROID_HOME=C:\Users\prep\AppData\Local\Android\Sdk"
set "ANDROID_SDK_ROOT=C:\Users\prep\AppData\Local\Android\Sdk"

REM Очистка
del /q /s /f "%LOCALAPPDATA%\Temp\*.*" >nul 2>&1
del /q /s /f "%WINDIR%\Temp\*.*" >nul 2>&1
del /q /s /f "%USERPROFILE%\.android\cache\*.*" >nul 2>&1
del /q /s /f "%USERPROFILE%\.gradle\caches\*.*" >nul 2>&1

REM Закрыть старые эмуляторы
taskkill /F /IM emulator.exe /T >nul 2>&1
taskkill /F /IM qemu-system-x86_64.exe /T >nul 2>&1
timeout /t 3 /nobreak >nul

REM Запустить эмулятор
start "" "%ANDROID_HOME%\emulator\emulator.exe" -avd "Pixel_7_API_35"

echo Эмулятор запущен!
timeout /t 3