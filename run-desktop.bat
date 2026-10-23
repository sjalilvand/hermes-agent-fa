@echo off
setlocal
rem =====================================================================
rem  run-desktop.bat - ways to run Hermes Desktop from this checkout
rem
rem  Usage:
rem     run-desktop.bat            (or: quick) - run the existing build (dist)
rem     run-desktop.bat dev        - dev mode: Vite 5174 + Electron hot reload
rem     run-desktop.bat build      - full build (npm run build), then run
rem
rem  Requirements: Node.js 22+ on PATH; workspace deps installed:
rem     npm install   (once, from this repo root)
rem =====================================================================

set "APP_DIR=%~dp0apps\desktop"
cd /d "%APP_DIR%"

where node >nul 2>&1
if errorlevel 1 (
    echo [error] Node.js not found on PATH. Install Node 22+.
    exit /b 1
)

set "MODE=%~1"
if "%MODE%"=="" set "MODE=quick"

if /i "%MODE%"=="dev" goto :dev
if /i "%MODE%"=="build" goto :build
if /i "%MODE%"=="quick" goto :quick
echo [error] unknown mode: %MODE%  (valid: dev^|build^|no argument)
exit /b 1

:quick
if not exist "node_modules\.bin\electron.cmd" (
    echo [error] dependencies not installed. Run once from the repo root:  npm install
    exit /b 1
)
if exist "dist\electron-main.mjs" (
    echo [run] existing build: dist\electron-main.mjs
    call node_modules\.bin\electron.cmd .
    goto :done
)
echo [warn] no existing build found - running a full build first...
goto :build

:dev
echo [dev] Vite on 127.0.0.1:5174 + Electron with hot reload
call npm run dev
goto :done

:build
echo [build] npm run build - this may take a few minutes...
call npm run build
if errorlevel 1 (
    echo [error] build failed.
    exit /b 1
)
echo [run] electron .
call node_modules\.bin\electron.cmd .
goto :done

:done
endlocal
