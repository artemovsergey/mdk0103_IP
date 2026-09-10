@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM ====== НАСТРОЙКИ ======
set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "ANDROID_SDK_ROOT=%LOCALAPPDATA%\Android\Sdk"
set "AVD_NAME=Pixel_7_API_35"
set "SYSTEM_IMAGE=system-images;android-35;google_apis;x86_64"
set "DEVICE=pixel_7"

REM Если SDK нет в LOCALAPPDATA — попробуем стандартные места
if not exist "%ANDROID_HOME%\emulator\emulator.exe" (
    if exist "%USERPROFILE%\AppData\Local\Android\Sdk\emulator\emulator.exe" (
        set "ANDROID_HOME=%USERPROFILE%\AppData\Local\Android\Sdk"
        set "ANDROID_SDK_ROOT=%USERPROFILE%\AppData\Local\Android\Sdk"
    ) else if exist "C:\Android\Sdk\emulator\emulator.exe" (
        set "ANDROID_HOME=C:\Android\Sdk"
        set "ANDROID_SDK_ROOT=C:\Android\Sdk"
    )
)

set "EMULATOR=%ANDROID_HOME%\emulator\emulator.exe"
set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
set "SDKMANAGER=%ANDROID_HOME%\cmdline-tools\latest\bin\sdkmanager.bat"
set "AVDMANAGER=%ANDROID_HOME%\cmdline-tools\latest\bin\avdmanager.bat"

echo [*] ANDROID_HOME = %ANDROID_HOME%

REM ====== ОЧИСТКА ======
echo [*] Очистка временных файлов...
del /q /s /f "%LOCALAPPDATA%\Temp\*.*" >nul 2>&1
del /q /s /f "%WINDIR%\Temp\*.*" >nul 2>&1
del /q /s /f "%USERPROFILE%\.android\cache\*.*" >nul 2>&1
del /q /s /f "%USERPROFILE%\.gradle\caches\*.*" >nul 2>&1

REM ====== ЗАКРЫТЬ СТАРЫЕ ЭМУЛЯТОРЫ ======
echo [*] Закрытие старых эмуляторов...
taskkill /F /IM emulator.exe /T >nul 2>&1
taskkill /F /IM qemu-system-x86_64.exe /T >nul 2>&1
taskkill /F /IM adb.exe /T >nul 2>&1
timeout /t 3 /nobreak >nul

REM ====== ПОИСК ЭМУЛЯТОРА ======
if not exist "%EMULATOR%" (
    echo [!] Эмулятор не найден в "%ANDROID_HOME%".
    echo [*] Пробую найти emulator.exe в системе...

    REM Ищем emulator.exe в типичных местах
    for %%D in (
        "%LOCALAPPDATA%\Android\Sdk"
        "%USERPROFILE%\AppData\Local\Android\Sdk"
        "C:\Android\Sdk"
        "C:\Program Files\Android\Sdk"
        "C:\Program Files (x86)\Android\Sdk"
    ) do (
        if exist "%%~D\emulator\emulator.exe" (
            set "ANDROID_HOME=%%~D"
            set "ANDROID_SDK_ROOT=%%~D"
            set "EMULATOR=%%~D\emulator\emulator.exe"
            set "ADB=%%~D\platform-tools\adb.exe"
            set "SDKMANAGER=%%~D\cmdline-tools\latest\bin\sdkmanager.bat"
            set "AVDMANAGER=%%~D\cmdline-tools\latest\bin\avdmanager.bat"
            echo [+] Найден эмулятор: %%D
            goto :emulator_found
        )
    )

    echo [!] Эмулятор Android SDK не найден.
    echo [*] Установите Android Studio или Android SDK Command-line Tools.
    echo     https://developer.android.com/studio#command-tools
    pause
    exit /b 1
)

:emulator_found

REM ====== ПРОВЕРКА НАЛИЧИЯ AVD ======
echo [*] Проверка наличия AVD "%AVD_NAME%"...
"%EMULATOR%" -list-avds 2>nul | findstr /x /c:"%AVD_NAME%" >nul
if errorlevel 1 (
    echo [!] AVD "%AVD_NAME%" не найден. Создаю новый...

    if not exist "%SDKMANAGER%" (
        echo [!] sdkmanager не найден по пути "%SDKMANAGER%".
        echo     Установите Android SDK Command-line Tools через SDK Manager.
        pause
        exit /b 1
    )

    echo [*] Установка системного образа: %SYSTEM_IMAGE%
    call "%SDKMANAGER%" --sdk_root="%ANDROID_HOME%" "%SYSTEM_IMAGE%" --licenses < nul
    call "%SDKMANAGER%" --sdk_root="%ANDROID_HOME%" "%SYSTEM_IMAGE%"

    if not exist "%AVDMANAGER%" (
        echo [!] avdmanager не найден. Проверьте установку cmdline-tools.
        pause
        exit /b 1
    )

    echo [*] Создание AVD "%AVD_NAME%"...
    echo no | call "%AVDMANAGER%" create avd -n "%AVD_NAME%" -k "%SYSTEM_IMAGE%" -d "%DEVICE%" --force
) else (
    echo [+] AVD "%AVD_NAME%" найден.
)

REM ====== ЗАПУСК ЭМУЛЯТОРА ======
echo [*] Запуск эмулятора "%AVD_NAME%"...
start "" "%EMULATOR%" -avd "%AVD_NAME%"

echo [+] Эмулятор запущен!
timeout /t 3 >nul
endlocal