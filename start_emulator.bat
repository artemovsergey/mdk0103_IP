@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM ============================================================
REM  ADB DIAGNOSTIC — только проверка, без запуска эмулятора
REM  Лог: %USERPROFILE%\Desktop\adb_diag.txt
REM ============================================================

set "LOG=%USERPROFILE%\Desktop\adb_diag.txt"

> "%LOG%" echo ============================================================
>>"%LOG%" echo  ADB DIAGNOSTIC
>>"%LOG%" echo  Дата: %DATE% %TIME%
>>"%LOG%" echo  Компьютер: %COMPUTERNAME%
>>"%LOG%" echo  Пользователь: %USERNAME%
>>"%LOG%" echo ============================================================
>>"%LOG%" echo.

REM ====== 1. ПОИСК SDK ======
>>"%LOG%" echo ====== 1. ПОИСК SDK ======
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
    >>"%LOG%" echo [!] SDK не найден
    goto :finish
)
>>"%LOG%" echo.

set "EMULATOR=%ANDROID_HOME%\emulator\emulator.exe"
set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
>>"%LOG%" echo EMULATOR = %EMULATOR%
>>"%LOG%" echo ADB      = %ADB%
>>"%LOG%" echo.

REM ====== 2. ПРОВЕРКА ФАЙЛОВ ======
>>"%LOG%" echo ====== 2. ФАЙЛЫ ======
if exist "%EMULATOR%" (>>"%LOG%" echo [+] emulator.exe) else (>>"%LOG%" echo [!] emulator.exe НЕ найден)
if exist "%ADB%" (>>"%LOG%" echo [+] adb.exe) else (>>"%LOG%" echo [!] adb.exe НЕ найден)
>>"%LOG%" echo.

REM ====== 3. ВЕРСИЯ ADB ======
>>"%LOG%" echo ====== 3. ВЕРСИЯ ADB ======
"%ADB%" version >>"%LOG%" 2>&1
>>"%LOG%" echo.

REM ====== 4. ПОРТ 5037 ======
>>"%LOG%" echo ====== 4. ПОРТ 5037 ======
netstat -ano 2>nul | findstr ":5037" >>"%LOG%" 2>&1
>>"%LOG%" echo.

REM ====== 5. ПРОЦЕССЫ ======
>>"%LOG%" echo ====== 5. ПРОЦЕССЫ ADB/EMULATOR/QEMU ======
tasklist 2>nul | findstr /i "adb emulator qemu" >>"%LOG%" 2>&1
>>"%LOG%" echo.

REM ====== 6. ПРОВЕРКА adb devices С ТАЙМАУТОМ ======
>>"%LOG%" echo ====== 6. adb devices (таймаут 5 сек) ======
set "PROBE=%TEMP%\adb_probe.txt"
del /q "%PROBE%" >nul 2>&1

start "" /min cmd /c ""%ADB%" devices > "%PROBE%" 2>&1"

set /a WAIT=0
:probe_loop
if exist "%PROBE%" (
    for %%S in ("%PROBE%") do (
        if %%~zS GTR 0 goto :probe_done
    )
)
set /a WAIT+=1
if !WAIT! GEQ 5 (
    >>"%LOG%" echo [!] adb devices не ответил за 5 секунд — ЗАВИС
    >>"%LOG%" echo [*] Убиваю adb.exe...
    taskkill /F /IM adb.exe /T >>"%LOG%" 2>&1
    del /q "%PROBE%" >nul 2>&1
    goto :probe_killed
)
timeout /t 1 /nobreak >nul
goto :probe_loop

:probe_done
>>"%LOG%" echo [+] adb devices ответил за !WAIT! сек:
>>"%LOG%" echo ---
type "%PROBE%" >>"%LOG%" 2>&1
>>"%LOG%" echo ---
del /q "%PROBE%" >nul 2>&1
goto :probe_after

:probe_killed
>>"%LOG%" echo [!] adb.exe убит. Ждём 2 сек и пробуем снова с явным портом...
timeout /t 2 /nobreak >nul

set "PROBE=%TEMP%\adb_probe2.txt"
del /q "%PROBE%" >nul 2>&1
start "" /min cmd /c ""%ADB%" -L tcp:5037 devices > "%PROBE%" 2>&1"

set /a WAIT=0
:probe_loop2
if exist "%PROBE%" (
    for %%S in ("%PROBE%") do (
        if %%~zS GTR 0 goto :probe_done2
    )
)
set /a WAIT+=1
if !WAIT! GEQ 5 (
    >>"%LOG%" echo [!] adb devices с -L tcp:5037 тоже не ответил за 5 сек.
    del /q "%PROBE%" >nul 2>&1
    goto :probe_after
)
timeout /t 1 /nobreak >nul
goto :probe_loop2

:probe_done2
>>"%LOG%" echo [+] adb -L tcp:5037 devices ответил за !WAIT! сек:
>>"%LOG%" echo ---
type "%PROBE%" >>"%LOG%" 2>&1
>>"%LOG%" echo ---
del /q "%PROBE%" >nul 2>&1

:probe_after
>>"%LOG%" echo.

REM ====== 7. ПРОБА FINDSTR ======
>>"%LOG%" echo ====== 7. Проверка findstr ======
set "PROBE=%TEMP%\adb_probe3.txt"
del /q "%PROBE%" >nul 2>&1
"%ADB%" devices > "%PROBE%" 2>nul

>>"%LOG%" echo Содержимое %PROBE%:
>>"%LOG%" echo ---
type "%PROBE%" >>"%LOG%" 2>&1
>>"%LOG%" echo ---

>>"%LOG%" echo.
>>"%LOG%" echo Попытка for /f:
for /f "tokens=1" %%D in (%PROBE%) do (
    >>"%LOG%" echo Строка: [%%D]
)
del /q "%PROBE%" >nul 2>&1
>>"%LOG%" echo.

REM ====== 8. ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ ДЛЯ ADB ======
>>"%LOG%" echo ====== 8. Переменные ADB ======
>>"%LOG%" echo ADB_MDNS_OPENSCREEN=%ADB_MDNS_OPENSCREEN%
>>"%LOG%" echo ADB_MDNS_ENABLED=%ADB_MDNS_ENABLED%
>>"%LOG%" echo ADB_MDNS_AUTO_CONNECT=%ADB_MDNS_AUTO_CONNECT%
>>"%LOG%" echo TEMP=%TEMP%
>>"%LOG%" echo.

REM ====== 9. СЛУЖБА ADB ======
>>"%LOG%" echo ====== 9. Служба adb ======
sc query adb 2>nul >>"%LOG%" 2>&1
>>"%LOG%" echo.

REM ====== 10. АНТИВИРУС ======
>>"%LOG%" echo ====== 10. Антивирус ======
wmic /namespace:\\root\SecurityCenter2 path AntiVirusProduct get displayName,productState /format:list 2>nul | findstr /r "." >>"%LOG%" 2>&1
>>"%LOG%" echo.

:finish

>>"%LOG%" echo ============================================================
>>"%LOG%" echo  КОНЕЦ ДИАГНОСТИКИ
>>"%LOG%" echo ============================================================

echo.
echo ============================================================
echo  Готово! Лог сохранён:
echo  %LOG%
echo ============================================================
echo.
pause
endlocal