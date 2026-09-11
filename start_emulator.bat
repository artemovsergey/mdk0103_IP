@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM ============================================================
REM  Android Emulator Launcher — Pixel 5 API 33 (final v7)
REM  Без start /b, без echo ^| findstr в цикле
REM ============================================================

REM ====== НАСТРОЙКИ ======
set "AVD_NAME=Pixel_5_API_33"
set "SYSTEM_IMAGE=system-images;android-33;google_apis;x86_64"
set "DEVICE=pixel_5"
set "GPU_MODE=angle_indirect"
set "RAM_MB=2048"
set "CPU_CORES=2"
set "BOOT_TIMEOUT=180"
set "ADB_WAIT=60"

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
echo   Android Emulator — Pixel 5 API 33
echo ============================================================
echo [*] ANDROID_HOME = %ANDROID_HOME%
echo [*] GPU_MODE     = %GPU_MODE%
echo [*] RAM / CPU    = %RAM_MB% MB / %CPU_CORES% ядер
echo ============================================================
echo.

REM ====== СТОП СТАРЫХ ПРОЦЕССОВ ======
echo [*] Остановка старых эмуляторов и ADB...
taskkill /F /IM emulator.exe /T >nul 2>&1
taskkill /F /IM qemu-system-x86_64.exe /T >nul 2>&1
taskkill /F /IM adb.exe /T >nul 2>&1
timeout /t 2 /nobreak >nul

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

REM ====== ПРАВКА hardware-qemu.ini ======
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

REM ====== ЗАПУСК ЭМУЛЯТОРА ======
echo [*] Запуск эмулятора...
start "" "%EMULATOR%" -avd "%AVD_NAME%" ^
    -no-boot-anim ^
    -no-audio ^
    -no-metrics

REM ============================================================
REM  ОЖИДАНИЕ ADB — без echo ^| findstr в цикле
REM ============================================================
if not exist "%ADB%" goto :done

echo.
echo [*] Ожидание устройства в ADB (макс. %ADB_WAIT% сек)...

set "ADB_LIST=%TEMP%\adb_list.txt"
set "ADB_FILTERED=%TEMP%\adb_filtered.txt"
set /a TOTAL_WAIT=0
set "DEVICE_FOUND="

:wait_device_loop

REM --- adb devices пишет в файл ---
"%ADB%" devices > "%ADB_LIST%" 2>nul

REM --- фильтруем через findstr ПРЯМО по файлу (без цикла) ---
findstr /r "^emulator-" "%ADB_LIST%" > "%ADB_FILTERED%" 2>nul

set "DEVICE_FOUND="
for /f "tokens=1" %%D in (%ADB_FILTERED%) do (
    if not defined DEVICE_FOUND set "DEVICE_FOUND=%%D"
)

if defined DEVICE_FOUND goto :device_appeared

set /a TOTAL_WAIT+=1
if !TOTAL_WAIT! GEQ %ADB_WAIT% (
    echo [!] Устройство не появилось за %ADB_WAIT% сек.
    del /q "%ADB_LIST%" "%ADB_FILTERED%" >nul 2>&1
    goto :done
)

set /a MOD=TOTAL_WAIT %% 10
if !MOD! EQU 0 echo [*] Ждём... !TOTAL_WAIT! сек.

timeout /t 1 /nobreak >nul
goto :wait_device_loop

:device_appeared
echo [+] Устройство найдено: %DEVICE_FOUND%
del /q "%ADB_LIST%" "%ADB_FILTERED%" >nul 2>&1

REM ============================================================
REM  ОЖИДАНИЕ ЗАГРУЗКИ ANDROID
REM ============================================================
echo [*] Ожидание полной загрузки Android (макс. %BOOT_TIMEOUT% сек)...
set /a BOOT_WAIT=0

:wait_boot
set "BOOT="
for /f "delims=" %%B in ('"%ADB%" -s %DEVICE_FOUND% shell getprop sys.boot_completed 2^>nul') do set "BOOT=%%B"
if "!BOOT!"=="1" goto :boot_done

set /a BOOT_WAIT+=1
if !BOOT_WAIT! GEQ %BOOT_TIMEOUT% (
    echo [!] Загрузка не завершилась за %BOOT_TIMEOUT% сек.
    goto :done
)

set /a MOD=BOOT_WAIT %% 15
if !MOD! EQU 0 echo [*] Загрузка... !BOOT_WAIT! сек.

timeout /t 1 /nobreak >nul
goto :wait_boot

:boot_done
echo.
echo [+] ====================================================
echo [+]  Эмулятор "%AVD_NAME%" загружен и готов к работе!
echo [+] ====================================================
echo.

:done
del /q "%ADB_LIST%" "%ADB_FILTERED%" >nul 2>&1
endlocal