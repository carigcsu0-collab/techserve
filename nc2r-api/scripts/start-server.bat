@echo off
setlocal
REM NC2R API supervisor for Windows. Starts `php artisan serve` and restarts it
REM forever if it crashes or is killed. Only ONE supervisor can run at a time
REM (lock file), so double-clicking it twice or a duplicate task is harmless.
REM
REM Optional environment variables:
REM   NC2R_HOST (default 127.0.0.1)   NC2R_PORT (default 8000)
cd /d "%~dp0.."
if not defined NC2R_HOST set NC2R_HOST=127.0.0.1
if not defined NC2R_PORT set NC2R_PORT=8000
if not exist storage\logs mkdir storage\logs
set "LOCK=%~dp0..\storage\nc2r-api.lock"
set "RLOG=%~dp0..\storage\logs\server-restarts.log"

2>nul (call :supervise) 9>>"%LOCK%"
if errorlevel 1 echo Another NC2R API supervisor is already running. Exiting.
exit /b 0

:supervise
set DELAY=5
:loop
echo [%date% %time%] Starting NC2R API on http://%NC2R_HOST%:%NC2R_PORT% ...
php artisan serve --host=%NC2R_HOST% --port=%NC2R_PORT%
echo [%date% %time%] Server exited with code %errorlevel%, restarting in %DELAY%s >> "%RLOG%"
echo [%date% %time%] Server exited with code %errorlevel%. Restarting in %DELAY%s...
timeout /t %DELAY% /nobreak >nul
goto loop
