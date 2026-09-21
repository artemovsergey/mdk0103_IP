@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM  Android Emulator Launcher - Pixel 5 API 33 (fast boot)
REM  ASCII-only text to avoid codepage parsing issues
REM ============================================================

REM ====== SETTINGS ======
set "AVD_NAME=Pixel_5_API_33"
set "SYSTEM_IMAGE=system-images;android-33;google_apis;x86_64"
set "DEVICE=pixel_5"
set "GPU_MODE=host"
set "RAM_MB=4096"
set "CPU_CORES=4"
set "BOOT_TIMEOUT=120"
set "ADB_WAIT=60"

REM ====== SDK SEARCH ======
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
echo [!] Android SDK not found.
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
echo   Android Emulator - Pixel 5 API 33 (fast boot)
echo ============================================================
echo [*] ANDROID_HOME = %ANDROID_HOME%
echo [*] GPU_MODE     = %GPU_MODE%
echo [*] RAM / CPU    = %RAM_MB% MB / %CPU_CORES% cores
echo ============================================================
echo.

REM ====== KILL OLD PROCESSES ======
echo [*] Stopping old emulator gracefully (saves quickboot snapshot)...
if exist "%ADB%" call "%ADB%" emu kill >nul 2>&1

REM Wait up to 45s for graceful exit + snapshot save
set /a KILL_WAIT=0
:wait_qemu_exit
set "QEMU_RUNNING="
tasklist /FI "IMAGENAME eq qemu-system-x86_64.exe" 2>nul | findstr /i "x86_64.exe" >nul
if not errorlevel 1 set "QEMU_RUNNING=1"
tasklist /FI "IMAGENAME eq qemu-system-x86_64-headless.exe" 2>nul | findstr /i "x86_64-headless.exe" >nul
if not errorlevel 1 set "QEMU_RUNNING=1"
if not defined QEMU_RUNNING goto :qemu_gone

set /a KILL_WAIT+=1
if !KILL_WAIT! GEQ 45 (
    echo [*] Force killing emulator (snapshot may be lost)...
    taskkill /F /IM qemu-system-x86_64.exe /T >nul 2>&1
    taskkill /F /IM qemu-system-x86_64-headless.exe /T >nul 2>&1
    goto :kill_done
)
set /a KILL_MOD=KILL_WAIT %% 5
if !KILL_MOD! EQU 0 echo [*] Saving snapshot... !KILL_WAIT! sec.
timeout /t 1 /nobreak >nul
goto :wait_qemu_exit

:qemu_gone
echo [+] Emulator stopped, snapshot saved.
:kill_done
taskkill /F /IM emulator.exe /T >nul 2>&1
taskkill /F /IM adb.exe /T >nul 2>&1
timeout /t 1 /nobreak >nul

REM ====== AVD CHECK / CREATE ======
"%EMULATOR%" -list-avds 2>nul | findstr /x /c:"%AVD_NAME%" >nul
if errorlevel 1 (
    echo [!] AVD "%AVD_NAME%" not found. Creating...
    if not exist "%SDKMANAGER%" (echo [!] sdkmanager not found. & pause & exit /b 1)
    call "%SDKMANAGER%" --sdk_root="%ANDROID_HOME%" "%SYSTEM_IMAGE%" --licenses < nul
    call "%SDKMANAGER%" --sdk_root="%ANDROID_HOME%" "%SYSTEM_IMAGE%"
    if not exist "%AVDMANAGER%" (echo [!] avdmanager not found. & pause & exit /b 1)
    echo no | call "%AVDMANAGER%" create avd -n "%AVD_NAME%" -k "%SYSTEM_IMAGE%" -d "%DEVICE%" --force
) else (
    echo [+] AVD "%AVD_NAME%" found.
)

set "AVD_DIR=%USERPROFILE%\.android\avd\%AVD_NAME%.avd"
set "AVD_INI=%AVD_DIR%\config.ini"
set "HW_QEMU_INI=%AVD_DIR%\hardware-qemu.ini"
set "GPU_CHANGED=0"

REM ====== EDIT config.ini ======
if exist "%AVD_INI%" (
    set "CUR_GPU="
    for /f "tokens=1,* delims==" %%A in ('findstr /b /i "hw.gpu.mode" "%AVD_INI%" 2^>nul') do (
        if not defined CUR_GPU set "CUR_GPU=%%B"
    )
    if /i not "!CUR_GPU!"=="%GPU_MODE%" (
        echo [*] config.ini: was !CUR_GPU! -^> %GPU_MODE%
        set "GPU_CHANGED=1"
    )

    findstr /v /b /i "hw.gpu.enabled hw.gpu.mode hw.ramSize hw.cpu.ncore vm.heapSize hw.audioInput hw.audioOutput hw.camera.back hw.camera.front fastboot.forceColdBoot fastboot.forceFastBoot" "%AVD_INI%" > "%AVD_INI%.tmp"
    move /y "%AVD_INI%.tmp" "%AVD_INI%" >nul

    >>"%AVD_INI%" echo hw.gpu.enabled=yes
    >>"%AVD_INI%" echo hw.gpu.mode=%GPU_MODE%
    >>"%AVD_INI%" echo hw.ramSize=%RAM_MB%
    >>"%AVD_INI%" echo hw.cpu.ncore=%CPU_CORES%
    >>"%AVD_INI%" echo vm.heapSize=512
    >>"%AVD_INI%" echo hw.audioInput=no
    >>"%AVD_INI%" echo hw.audioOutput=no
    >>"%AVD_INI%" echo hw.camera.back=none
    >>"%AVD_INI%" echo hw.camera.front=none
    >>"%AVD_INI%" echo fastboot.forceColdBoot=no
    >>"%AVD_INI%" echo fastboot.forceFastBoot=yes

    echo [+] config.ini: GPU=%GPU_MODE%, RAM=%RAM_MB%, CPU=%CPU_CORES%
)

REM ====== EDIT hardware-qemu.ini ======
if exist "%HW_QEMU_INI%" (
    findstr /v /b /i "hw.gpu.enabled hw.gpu.mode" "%HW_QEMU_INI%" > "%HW_QEMU_INI%.tmp"
    move /y "%HW_QEMU_INI%.tmp" "%HW_QEMU_INI%" >nul
    >>"%HW_QEMU_INI%" echo hw.gpu.enabled=yes
    >>"%HW_QEMU_INI%" echo hw.gpu.mode=%GPU_MODE%
    echo [+] hardware-qemu.ini: GPU=%GPU_MODE%
)

REM ====== RESET SNAPSHOT ON GPU CHANGE ======
if "%GPU_CHANGED%"=="1" (
    echo [*] GPU changed - deleting old snapshot...
    rmdir /s /q "%AVD_DIR%\snapshots" >nul 2>&1
)

REM ====== START EMULATOR (HIDDEN CONSOLE) ======
echo [*] Restarting adb server...
if exist "%ADB%" call "%ADB%" start-server >nul 2>&1

set "VBS=%TEMP%\emu_hidden.vbs"
echo Set WshShell = CreateObject("WScript.Shell") > "%VBS%"
echo WshShell.Run "%EMULATOR% -avd %AVD_NAME% -no-audio -no-metrics -no-boot-anim -camera-back none -camera-front none -gpu %GPU_MODE% -partition-size 2047", 0, False >> "%VBS%"
cscript //nologo "%VBS%" >nul 2>&1
del "%VBS%" >nul 2>&1
echo [*] Starting emulator...

REM ============================================================
REM  WAIT FOR ADB DEVICE
REM ============================================================
if not exist "%ADB%" goto :done

echo.
echo [*] Waiting for device in ADB (max %ADB_WAIT% sec)...

set /a TOTAL_WAIT=0
set "DEVICE_FOUND="

:wait_device_loop

set "DEVICE_FOUND="
for /f "tokens=1" %%D in ('""%ADB%" devices" 2^>nul') do (
    echo %%D | findstr /r "^emulator-" >nul
    if not errorlevel 1 set "DEVICE_FOUND=%%D"
)

if defined DEVICE_FOUND goto :device_appeared

set /a TOTAL_WAIT+=1
if !TOTAL_WAIT! GEQ %ADB_WAIT% (
    echo [!] Device not found within %ADB_WAIT% sec.
    goto :done
)

set /a MOD=TOTAL_WAIT %% 5
if !MOD! EQU 0 echo [*] Waiting... !TOTAL_WAIT! sec.

timeout /t 1 /nobreak >nul
goto :wait_device_loop

:device_appeared
echo [+] Device found: %DEVICE_FOUND%

REM ============================================================
REM  WAIT FOR ANDROID BOOT
REM ============================================================
echo [*] Waiting for full Android boot (max %BOOT_TIMEOUT% sec)...
set /a BOOT_WAIT=0

:wait_boot
set "BOOT="
for /f "delims=" %%B in ('"%ADB%" -s %DEVICE_FOUND% shell getprop sys.boot_completed 2^>nul') do set "BOOT=%%B"
if "!BOOT!"=="1" goto :boot_done

set /a BOOT_WAIT+=1
if !BOOT_WAIT! GEQ %BOOT_TIMEOUT% (
    echo [!] Boot not completed within %BOOT_TIMEOUT% sec.
    goto :done
)

set /a MOD=BOOT_WAIT %% 10
if !MOD! EQU 0 echo [*] Booting... !BOOT_WAIT! sec.

timeout /t 1 /nobreak >nul
goto :wait_boot

:boot_done
echo.
echo [+] ====================================================
echo [+]  Emulator "%AVD_NAME%" is up and ready!
echo [+] ====================================================
echo.

:done
endlocal