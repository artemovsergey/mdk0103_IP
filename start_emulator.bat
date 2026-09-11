@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM ============================================================
REM  Android Emulator Launcher — API 33 optimized
REM ============================================================

REM ====== НАСТРОЙКИ ======
set "AVD_NAME=Pixel_5_API_33"
set "SYSTEM_IMAGE=system-images;android-33;google_apis;x86_64"
set "DEVICE=pixel_5"
set "GPU_MODE=swiftshader_indirect"
set "BOOT_TIMEOUT=300"
set "ADB_WAIT=60"
set "ADB_CMD_TIMEOUT=5"
set "ANDROID_EMULATOR_WAIT_TIME_BEFORE_KILL=5"

REM ====== ПОИСК SDK ======
set "ANDROID_HOME="
for %%D in (
    "%LOCALAPPDATA%\Android\Sdk"
    "%USERPROFILE%\AppData\Local\Android\Sdk"
    "C:\Android\Sdk"
    "C:\Program Files\Android\Sdk"
    "C:\Program Files (x86)\Android\Sdk"
) do (
    if exist "%%~D\emulator\emulator.exe" (
        set "ANDROID_HOME=%%~D"
        goto :sdk_found
    )
)
echo [!] Android SDK не найден.
pause & exit /b 1
:sdk_found
set "ANDROID_SDK_ROOT=%ANDROID_HOME%"

set "EMULATOR=%ANDROID_HOME%\emulator\emulator.exe"
set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"

set "SDKMANAGER="
set "AVDMANAGER="
for /d %%V in ("%ANDROID_HOME%\cmdline-tools\*") do (
    if exist "%%~V\bin\sdkmanager.bat" (
        set "SDKMANAGER=%%~V\bin\sdkmanager.bat"
        set "AVDMANAGER=%%~V\bin\avdmanager.bat"
    )
)

echo [*] ANDROID_HOME = %ANDROID_HOME%
echo [*] AVD_NAME     = %AVD_NAME%
echo [*] GPU_MODE     = %GPU_MODE%

REM ====== ГИПЕРВИЗОР ======
sc query aehd >nul 2>&1 && (echo [+] AEHD активен) || (
    sc query gvm >nul 2>&1 && (echo [+] GVM активен) || (
        sc query whpx >nul 2>&1 && (echo [+] WHPX активен) || (
            echo [!] Гипервизор не обнаружен — будет медленно.
        )
    )
)

REM ====== СТОП СТАРЫХ ЭМУЛЯТОРОВ ======
if exist "%ADB%" (
    taskkill /F /IM adb.exe /T >nul 2>&1
    timeout /t 1 /nobreak >nul
    "%ADB%" start-server >nul 2>&1
    for /f "tokens=1" %%E in ('"%ADB%" devices 2^>nul ^| findstr /r "^emulator-"') do (
        "%ADB%" -s %%E emu kill >nul 2>&1
    )
)
taskkill /F /IM emulator.exe /T >nul 2>&1
taskkill /F /IM qemu-system-x86_64.exe /T >nul 2>&1
taskkill /F /IM qemu-system-i386.exe /T >nul 2>&1
taskkill /F /IM qemu-system-aarch64.exe /T >nul 2>&1

set /a WAIT=0
:wait_kill
tasklist /FI "IMAGENAME eq emulator.exe" 2>nul | find /i "emulator.exe" >nul
if not errorlevel 1 (
    set /a WAIT+=1
    if !WAIT! GEQ 3 goto :after_kill
    timeout /t 1 /nobreak >nul
    taskkill /F /IM emulator.exe /T >nul 2>&1
    goto :wait_kill
)
:after_kill

REM ====== AVD ======
"%EMULATOR%" -list-avds 2>nul | findstr /x /c:"%AVD_NAME%" >nul
if errorlevel 1 (
    echo [!] AVD "%AVD_NAME%" не найден. Создаю...
    if not exist "%SDKMANAGER%" (echo [!] sdkmanager не найден. & pause & exit /b 1)
    call "%SDKMANAGER%" --sdk_root="%ANDROID_HOME%" "%SYSTEM_IMAGE%" --licenses < nul
    call "%SDKMANAGER%" --sdk_root="%ANDROID_HOME%" "%SYSTEM_IMAGE%"
    if not exist "%AVDMANAGER%" (echo [!] avdmanager не найден. & pause & exit /b 1)
    echo no | call "%AVDMANAGER%" create avd -n "%AVD_NAME%" -k "%SYSTEM_IMAGE%" -d "%DEVICE%" --force
) else (
    echo [+] AVD "%AVD_NAME%" найден.
)

REM ====== ЖЁСТКАЯ ПЕРЕЗАПИСЬ config.ini ======
set "AVD_DIR=%USERPROFILE%\.android\avd\%AVD_NAME%.avd"
set "AVD_INI=%AVD_DIR%\config.ini"
set "GPU_CHANGED=0"

if exist "%AVD_INI%" (
    echo [*] Перезапись GPU-настроек в config.ini...

    set "CUR_GPU="
    for /f "tokens=1,* delims==" %%A in ('findstr /b /i "hw.gpu.mode" "%AVD_INI%" 2^>nul') do (
        if not defined CUR_GPU set "CUR_GPU=%%B"
    )

    if /i not "!CUR_GPU!"=="%GPU_MODE%" (
        echo [*] Было hw.gpu.mode=!CUR_GPU! — станет %GPU_MODE%
        set "GPU_CHANGED=1"
    )

    findstr /v /b /i "hw.gpu.enabled hw.gpu.mode hw.ramSize hw.cpu.ncore vm.heapSize" "%AVD_INI%" > "%AVD_INI%.tmp"
    move /y "%AVD_INI%.tmp" "%AVD_INI%" >nul

    >>"%AVD_INI%" echo hw.gpu.enabled=yes
    >>"%AVD_INI%" echo hw.gpu.mode=%GPU_MODE%
    >>"%AVD_INI%" echo hw.ramSize=2048
    >>"%AVD_INI%" echo hw.cpu.ncore=2
    >>"%AVD_INI%" echo vm.heapSize=256

    echo [+] config.ini обновлён: hw.gpu.mode=%GPU_MODE%, RAM=2048, CPU=2
) else (
    echo [!] config.ini не найден: %AVD_INI%
)

REM ====== СБРОС СНАПШОТА ПРИ СМЕНЕ GPU ======
if "%GPU_CHANGED%"=="1" (
    echo [*] GPU изменился — удаляю старый снапшот...
    rmdir /s /q "%AVD_DIR%\snapshots\default_boot" >nul 2>&1
)

REM ====== ADB ДО ЭМУЛЯТОРА ======
if exist "%ADB%" (
    echo [*] Запуск ADB-сервера...
    taskkill /F /IM adb.exe /T >nul 2>&1
    timeout /t 1 /nobreak >nul
    "%ADB%" start-server >nul 2>&1
)

REM ====== ЗАПУСК ЭМУЛЯТОРА ======
echo [*] Запуск эмулятора "%AVD_NAME%" (GPU: %GPU_MODE%)...
start "" "%EMULATOR%" -avd "%AVD_NAME%" ^
    -no-boot-anim ^
    -no-audio ^
    -camera-back none ^
    -camera-front none ^
    -netdelay none ^
    -netspeed full ^
    -no-metrics

REM ============================================================
REM  ОЖИДАНИЕ ADB С ЗАЩИТОЙ ОТ ЗАВИСАНИЯ
REM ============================================================
if not exist "%ADB%" goto :done

echo [*] Ожидание устройства в ADB (макс. %ADB_WAIT% сек)...

set /a TOTAL_WAIT=0
set /a ADB_RETRIES=0
set "DEVICE_FOUND="

:wait_device_loop

REM --- Проверяем, жив ли adb.exe ---
tasklist /FI "IMAGENAME eq adb.exe" 2>nul | find /i "adb.exe" >nul
if errorlevel 1 (
    echo [!] adb.exe не запущен. Стартую...
    "%ADB%" start-server >nul 2>&1
    timeout /t 2 /nobreak >nul
)

REM --- Запускаем adb devices в фоне с записью в файл ---
set "ADB_OUT=%TEMP%\adb_devices_%RANDOM%.txt"
del /q "%ADB_OUT%" >nul 2>&1
start /b cmd /c ""%ADB%" devices 2>nul > "%ADB_OUT%""

REM --- Ждём максимум ADB_CMD_TIMEOUT секунд появления непустого файла ---
set /a ADB_CMD_WAIT=0
:wait_adb_output
if exist "%ADB_OUT%" (
    for %%S in ("%ADB_OUT%") do (
        if %%~zS GTR 0 goto :check_devices
    )
)
set /a ADB_CMD_WAIT+=1
if !ADB_CMD_WAIT! GEQ %ADB_CMD_TIMEOUT% (
    echo [!] adb devices не ответил за %ADB_CMD_TIMEOUT% сек. Убиваю adb.exe и перезапускаю...
    taskkill /F /IM adb.exe /T >nul 2>&1
    timeout /t 2 /nobreak >nul
    "%ADB%" start-server >nul 2>&1
    set /a ADB_RETRIES+=1
    if !ADB_RETRIES! GEQ 3 (
        echo [!] ADB не удаётся запустить. Проверьте антивирус и порт 5037.
        echo     netstat -ano ^| findstr :5037
        del /q "%ADB_OUT%" >nul 2>&1
        goto :done
    )
    del /q "%ADB_OUT%" >nul 2>&1
    goto :wait_device_loop
)
timeout /t 1 /nobreak >nul
goto :wait_adb_output

:check_devices
REM --- Ищем эмулятор в выводе ---
for /f "tokens=1" %%D in ('findstr /r "^emulator-" "%ADB_OUT%" 2^>nul') do (
    set "DEVICE_FOUND=%%D"
    del /q "%ADB_OUT%" >nul 2>&1
    goto :device_appeared
)

del /q "%ADB_OUT%" >nul 2>&1

set /a TOTAL_WAIT+=1
if !TOTAL_WAIT! GEQ %ADB_WAIT% (
    echo [!] Устройство не появилось за %ADB_WAIT% сек.
    echo     Проверьте: adb devices, netstat -ano ^| findstr :5037
    goto :done
)
timeout /t 1 /nobreak >nul
goto :wait_device_loop

:device_appeared
echo [+] Устройство найдено: !DEVICE_FOUND!

REM ============================================================
REM  ОЖИДАНИЕ ЗАГРУЗКИ ANDROID
REM ============================================================
echo [*] Ожидание полной загрузки Android (макс. %BOOT_TIMEOUT% сек)...
set /a BOOT_WAIT=0

:wait_boot
for /f "delims=" %%B in ('"%ADB%" -s !DEVICE_FOUND! shell getprop sys.boot_completed 2^>nul') do set "BOOT=%%B"
if "!BOOT!"=="1" goto :boot_done

set /a BOOT_WAIT+=1
if !BOOT_WAIT! GEQ %BOOT_TIMEOUT% (
    echo [!] Загрузка не завершилась за %BOOT_TIMEOUT% сек.
    echo     Возможно, эмулятор завис. Проверьте окно эмулятора.
    goto :done
)

REM Раз в 30 секунд выводим статус, чтобы было видно, что скрипт жив
set /a MOD=BOOT_WAIT %% 30
if !MOD! EQU 0 echo [*] Всё ещё грузится... прошло !BOOT_WAIT! сек.

timeout /t 1 /nobreak >nul
goto :wait_boot

:boot_done
echo.
echo [+] ====================================================
echo [+]  Эмулятор "%AVD_NAME%" загружен и готов к работе!
echo [+] ====================================================
echo.

:done
endlocal