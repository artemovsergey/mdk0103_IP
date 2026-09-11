@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM ============================================================
REM  Android Emulator Launcher — Pixel 7 API 35 (final)
REM ============================================================

REM ====== НАСТРОЙКИ ======
set "AVD_NAME=Pixel_7_API_35"
set "SYSTEM_IMAGE=system-images;android-35;google_apis_playstore;x86_64"
set "DEVICE=pixel_7"
set "GPU_MODE=angle_indirect"
set "RAM_MB=2048"
set "CPU_CORES=2"
set "BOOT_TIMEOUT=180"
set "ADB_WAIT=40"
set "ANDROID_EMULATOR_WAIT_TIME_BEFORE_KILL=3"

REM ====== ПОИСК SDK ======
set "ANDROID_HOME="
for %%D in (
    "%LOCALAPPDATA%\Android\Sdk"
    "%USERPROFILE%\AppData\Local\Android\Sdk"
    "C:\Android\Sdk"
    "C:\Program Files\Android\Sdk"
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

echo ============================================================
echo   Android Emulator — Pixel 7 API 35
echo ============================================================
echo [*] GPU_MODE     = %GPU_MODE%
echo [*] RAM / CPU    = %RAM_MB% MB / %CPU_CORES% ядер
echo ============================================================
echo.

REM ====== СТОП СТАРЫХ ЭМУЛЯТОРОВ ======
echo [*] Остановка старых эмуляторов...
taskkill /F /IM emulator.exe /T >nul 2>&1
taskkill /F /IM qemu-system-x86_64.exe /T >nul 2>&1
timeout /t 1 /nobreak >nul

REM ====== AVD: ПРОВЕРКА / СОЗДАНИЕ ======
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

set "AVD_DIR=%USERPROFILE%\.android\avd\%AVD_NAME%.avd"
set "AVD_INI=%AVD_DIR%\config.ini"
set "HW_QEMU_INI=%AVD_DIR%\hardware-qemu.ini"
set "GPU_CHANGED=0"

REM ====== ПРАВКА config.ini ======
if exist "%AVD_INI%" (
    set "CUR_GPU="
    for /f "tokens=1,* delims==" %%A in ('findstr /b /i "hw.gpu.mode" "%AVD_INI%" 2^>nul') do (
        if not defined CUR_GPU set "CUR_GPU=%%B"
    )
    if /i not "!CUR_GPU!"=="%GPU_MODE%" (
        echo [*] config.ini: было !CUR_GPU! -^> %GPU_MODE%
        set "GPU_CHANGED=1"
    )

    findstr /v /b /i "hw.gpu.enabled hw.gpu.mode hw.ramSize hw.cpu.ncore vm.heapSize hw.audioInput hw.audioOutput" "%AVD_INI%" > "%AVD_INI%.tmp"
    move /y "%AVD_INI%.tmp" "%AVD_INI%" >nul

    >>"%AVD_INI%" echo hw.gpu.enabled=yes
    >>"%AVD_INI%" echo hw.gpu.mode=%GPU_MODE%
    >>"%AVD_INI%" echo hw.ramSize=%RAM_MB%
    >>"%AVD_INI%" echo hw.cpu.ncore=%CPU_CORES%
    >>"%AVD_INI%" echo vm.heapSize=256
    >>"%AVD_INI%" echo hw.audioInput=no
    >>"%AVD_INI%" echo hw.audioOutput=no

    echo [+] config.ini: GPU=%GPU_MODE%, RAM=%RAM_MB%, CPU=%CPU_CORES%
)

REM ====== ПРАВКА hardware-qemu.ini (он перебивает config.ini!) ======
if exist "%HW_QEMU_INI%" (
    findstr /v /b /i "hw.gpu.enabled hw.gpu.mode" "%HW_QEMU_INI%" > "%HW_QEMU_INI%.tmp"
    move /y "%HW_QEMU_INI%.tmp" "%HW_QEMU_INI%" >nul
    >>"%HW_QEMU_INI%" echo hw.gpu.enabled=yes
    >>"%HW_QEMU_INI%" echo hw.gpu.mode=%GPU_MODE%
    echo [+] hardware-qemu.ini: GPU=%GPU_MODE%
)

REM ====== СБРОС СНАПШОТА ПРИ СМЕНЕ GPU ======
if "%GPU_CHANGED%"=="1" (
    echo [*] GPU изменился — удаляю старый снапшот...
    rmdir /s /q "%AVD_DIR%\snapshots" >nul 2>&1
)

REM ====== ADB ДО ЭМУЛЯТОРА ======
if exist "%ADB%" (
    "%ADB%" start-server >nul 2>&1
)

REM ====== ЗАПУСК ЭМУЛЯТОРА ======
REM Важно: НЕ передаём -gpu, чтобы эмулятор брал режим из config.ini/hardware-qemu.ini
echo [*] Запуск эмулятора...
start "" "%EMULATOR%" -avd "%AVD_NAME%" ^
    -no-boot-anim ^
    -no-audio ^
    -no-metrics

REM ====== ОЖИДАНИЕ ADB ======
if not exist "%ADB%" goto :done

echo [*] Ожидание устройства в ADB...
set /a DEV_WAIT=0
:wait_dev
"%ADB%" devices 2>nul | findstr /r "^emulator-" >nul
if not errorlevel 1 goto :dev_ready
set /a DEV_WAIT+=1
if !DEV_WAIT! GEQ %ADB_WAIT% (
    echo [!] Не появился в ADB за %ADB_WAIT% сек.
    goto :done
)
timeout /t 1 /nobreak >nul
goto :wait_dev

:dev_ready
set "DEV="
for /f "tokens=1" %%E in ('"%ADB%" devices 2^>nul ^| findstr /r "^emulator-"') do (
    set "DEV=%%E"
    goto :dev_ready2
)
:dev_ready2

echo [*] Устройство: %DEV%. Ждём загрузку Android...
set /a BOOT_WAIT=0
:wait_boot
for /f "delims=" %%B in ('"%ADB%" -s %DEV% shell getprop sys.boot_completed 2^>nul') do set "BOOT=%%B"
if "!BOOT!"=="1" goto :boot_done
set /a BOOT_WAIT+=1
if !BOOT_WAIT! GEQ %BOOT_TIMEOUT% (
    echo [!] Таймаут загрузки.
    goto :done
)
set /a MOD=BOOT_WAIT %% 15
if !MOD! EQU 0 echo [*] Загрузка... !BOOT_WAIT! сек.
timeout /t 1 /nobreak >nul
goto :wait_boot

:boot_done
echo.
echo [+] ====================================================
echo [+]  Эмулятор "%AVD_NAME%" загружен!
echo [+] ====================================================
echo.

:done
endlocal