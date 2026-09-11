@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM ============================================================
REM  Android Emulator — DIAGNOSTIC
REM  Ничего не меняет, только собирает информацию.
REM ============================================================

set "AVD_NAME=Pixel_5_API_33"
set "LOG=%USERPROFILE%\Desktop\emulator_diag.txt"

echo Сбор диагностики... Подождите.

> "%LOG%" echo ============================================================
>>"%LOG%" echo  Android Emulator Diagnostic
>>"%LOG%" echo  Дата: %DATE% %TIME%
>>"%LOG%" echo  Компьютер: %COMPUTERNAME%
>>"%LOG%" echo  Пользователь: %USERNAME%
>>"%LOG%" echo ============================================================
>>"%LOG%" echo.

REM ====== 1. СИСТЕМА ======
>>"%LOG%" echo ====== 1. СИСТЕМА ======
>>"%LOG%" ver
>>"%LOG%" echo.
>>"%LOG%" wmic os get Caption,Version,OSArchitecture /format:list 2>nul | findstr /r "."
>>"%LOG%" echo.
>>"%LOG%" wmic computersystem get TotalPhysicalMemory /format:list 2>nul | findstr /r "."
>>"%LOG%" echo.
>>"%LOG%" wmic logicaldisk get Caption,Size,FreeSpace 2>nul
>>"%LOG%" echo.

REM ====== 2. ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ ======
>>"%LOG%" echo ====== 2. ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ ======
>>"%LOG%" echo LOCALAPPDATA=%LOCALAPPDATA%
>>"%LOG%" echo USERPROFILE=%USERPROFILE%
>>"%LOG%" echo TEMP=%TEMP%
>>"%LOG%" echo ANDROID_HOME=%ANDROID_HOME%
>>"%LOG%" echo ANDROID_SDK_ROOT=%ANDROID_SDK_ROOT%
>>"%LOG%" echo.
>>"%LOG%" echo PATH:
>>"%LOG%" echo %PATH%
>>"%LOG%" echo.

REM ====== 3. ПОИСК SDK ======
>>"%LOG%" echo ====== 3. ПОИСК SDK ======
set "ANDROID_HOME="
for %%D in (
    "%LOCALAPPDATA%\Android\Sdk"
    "%USERPROFILE%\AppData\Local\Android\Sdk"
    "C:\Android\Sdk"
    "C:\Program Files\Android\Sdk"
) do (
    if exist "%%~D\emulator\emulator.exe" (
        set "ANDROID_HOME=%%~D"
        >>"%LOG%" echo Найден SDK: %%~D
    )
)
if not defined ANDROID_HOME (
    >>"%LOG%" echo [!] SDK НЕ НАЙДЕН ни в одном из стандартных путей
)
>>"%LOG%" echo.

if defined ANDROID_HOME (
    set "EMULATOR=%ANDROID_HOME%\emulator\emulator.exe"
    set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"

    >>"%LOG%" echo EMULATOR = !EMULATOR!
    >>"%LOG%" echo ADB      = !ADB!
    >>"%LOG%" echo.

    REM ====== 4. ПРОВЕРКА ФАЙЛОВ ======
    >>"%LOG%" echo ====== 4. ПРОВЕРКА ФАЙЛОВ ======
    if exist "!EMULATOR!" (>>"%LOG%" echo [+] emulator.exe найден) else (>>"%LOG%" echo [!] emulator.exe НЕ найден)
    if exist "!ADB!" (>>"%LOG%" echo [+] adb.exe найден) else (>>"%LOG%" echo [!] adb.exe НЕ найден)
    >>"%LOG%" echo.

    REM ====== 5. ВЕРСИЯ ADB ======
    >>"%LOG%" echo ====== 5. ВЕРСИЯ ADB ======
    if exist "!ADB!" (
        "!ADB!" version >>"%LOG%" 2>&1
    ) else (
        >>"%LOG%" echo adb.exe не найден
    )
    >>"%LOG%" echo.

    REM ====== 6. ВЕРСИЯ ЭМУЛЯТОРА ======
    >>"%LOG%" echo ====== 6. ВЕРСИЯ ЭМУЛЯТОРА ======
    if exist "!EMULATOR!" (
        "!EMULATOR%" -version >>"%LOG%" 2>&1
    ) else (
        >>"%LOG%" echo emulator.exe не найден
    )
    >>"%LOG%" echo.
)

REM ====== 7. ПОРТ 5037 ======
>>"%LOG%" echo ====== 7. ПОРТ 5037 ======
>>"%LOG%" netstat -ano 2>nul | findstr ":5037"
>>"%LOG%" echo.

REM ====== 8. ПРОЦЕССЫ ADB / EMULATOR / QEMU ======
>>"%LOG%" echo ====== 8. ПРОЦЕССЫ ======
>>"%LOG%" tasklist 2>nul | findstr /i "adb emulator qemu"
>>"%LOG%" echo.

REM ====== 9. СЛУЖБЫ ГИПЕРВИЗОРА ======
>>"%LOG%" echo ====== 9. ГИПЕРВИЗОР ======
>>"%LOG%" sc query aehd 2>nul | findstr /r "."
>>"%LOG%" echo ---
>>"%LOG%" sc query gvm 2>nul | findstr /r "."
>>"%LOG%" echo ---
>>"%LOG%" sc query whpx 2>nul | findstr /r "."
>>"%LOG%" echo.

REM ====== 10. AVD ======
>>"%LOG%" echo ====== 10. AVD ======
if defined ANDROID_HOME (
    "!EMULATOR!" -list-avds >>"%LOG%" 2>&1
)
>>"%LOG%" echo.

REM ====== 11. ФАЙЛЫ AVD ======
>>"%LOG%" echo ====== 11. ФАЙЛЫ AVD "%AVD_NAME%" ======
set "AVD_DIR=%USERPROFILE%\.android\avd\%AVD_NAME%.avd"
if exist "%AVD_DIR%" (
    >>"%LOG%" echo [+] Папка AVD существует: %AVD_DIR%
    >>"%LOG%" echo Содержимое:
    dir /b "%AVD_DIR%" >>"%LOG%" 2>&1
    >>"%LOG%" echo.
    >>"%LOG%" echo --- config.ini ---
    if exist "%AVD_DIR%\config.ini" (
        type "%AVD_DIR%\config.ini" >>"%LOG%" 2>&1
    ) else (
        >>"%LOG%" echo config.ini НЕ найден
    )
    >>"%LOG%" echo.
    >>"%LOG%" echo --- hardware-qemu.ini ---
    if exist "%AVD_DIR%\hardware-qemu.ini" (
        type "%AVD_DIR%\hardware-qemu.ini" >>"%LOG%" 2>&1
    ) else (
        >>"%LOG%" echo hardware-qemu.ini НЕ найден
    )
    >>"%LOG%" echo.
    >>"%LOG%" echo --- snapshots ---
    if exist "%AVD_DIR%\snapshots" (
        dir /b "%AVD_DIR%\snapshots" >>"%LOG%" 2>&1
    ) else (
        >>"%LOG%" echo папка snapshots отсутствует
    )
) else (
    >>"%LOG%" echo [!] Папка AVD НЕ существует: %AVD_DIR%
)
>>"%LOG%" echo.
>>"%LOG%" echo --- %USERPROFILE%\.android\avd\ (все AVD) ---
if exist "%USERPROFILE%\.android\avd\" (
    dir /b "%USERPROFILE%\.android\avd\" >>"%LOG%" 2>&1
) else (
    >>"%LOG%" echo папка .android\avd отсутствует
)
>>"%LOG%" echo.

REM ====== 12. ADB DEVICES ======
>>"%LOG%" echo ====== 12. ADB DEVICES (без запуска эмулятора) ======
if defined ANDROID_HOME (
    if exist "!ADB!" (
        "!ADB!" devices >>"%LOG%" 2>&1
    )
)
>>"%LOG%" echo.

REM ====== 13. ADB GET-STATE ======
>>"%LOG%" echo ====== 13. ADB GET-STATE ======
if defined ANDROID_HOME (
    if exist "!ADB!" (
        "!ADB!" get-state >>"%LOG%" 2>&1
    )
)
>>"%LOG%" echo.

REM ====== 14. АНТИВИРУС (WMI) ======
>>"%LOG%" echo ====== 14. АНТИВИРУС (Windows Security) ======
>>"%LOG%" wmic /namespace:\\root\SecurityCenter2 path AntiVirusProduct get displayName,productState /format:list 2>nul | findstr /r "."
>>"%LOG%" echo.

REM ====== 15. DXRENDER / GPU ======
>>"%LOG%" echo ====== 15. GPU ======
>>"%LOG%" wmic path win32_VideoController get Name,DriverVersion,DriverDate /format:list 2>nul | findstr /r "."
>>"%LOG%" echo.

REM ====== 16. СВОБОДНАЯ ПАМЯТЬ ======
>>"%LOG%" echo ====== 16. ПАМЯТЬ ======
>>"%LOG%" wmic OS get FreePhysicalMemory,TotalVisibleMemorySize /format:list 2>nul | findstr /r "."
>>"%LOG%" echo.

>>"%LOG%" echo ============================================================
>>"%LOG%" echo  КОНЕЦ ДИАГНОСТИКИ
>>"%LOG%" echo ============================================================

echo.
echo ============================================================
echo  Диагностика собрана:
echo  %LOG%
echo ============================================================
echo.
echo Отправьте этот файл разработчику.
pause
endlocal