@echo off

rem This file updates the repo, creates the containers and runs the app.
rem It creates 2 containers : 1 with the gateway (openclaw) and one with the chrome browser.
rem NOTE : ".openclaw" configuration directory is located in "./config" dir !

setlocal EnableDelayedExpansion

:: --- CONFIGURATION ---
set BRANCH=main
set IMAGE_GATEWAY=openclaw-local
set IMAGE_SANDBOX=openclaw-sandbox-browser:latest
set CONTAINER_GATEWAY=openclaw_gateway
set CONTAINER_SANDBOX=openclaw-sandbox-browser

:: Repo root (où se trouve ce script)
set REPO_ROOT=%~dp0
if "!REPO_ROOT:~-1!"=="\" set REPO_ROOT=!REPO_ROOT:~0,-1!

set CONFIG_DIR=!REPO_ROOT!\config

:: Conversion chemin pour Docker Desktop/WSL
:: Sur Windows: utilise format native Docker Desktop (C:\...) ou WSL (/mnt/c/...)
:: Docker Desktop gère automatiquement la conversion
set CONFIG_MOUNT=!CONFIG_DIR!

echo ========================================================
echo OPENCLAW LAUNCHER (IMPROVED)
echo ========================================================
echo.
echo [INFO] Repo Root: !REPO_ROOT!
echo [INFO] Config Dir: !CONFIG_MOUNT!
echo.

:: --- 1. GIT UPDATE ---
echo [STEP 1/6] Updating Git repository...
cd /d "!REPO_ROOT!"
if !ERRORLEVEL! NEQ 0 (
    echo [ERROR] Could not CD to repo root.
    goto :ERROR
)

if not exist .git (
    echo [ERROR] No .git directory found here!
    echo Please run this script from the root of your git repo.
    goto :ERROR
)

echo - Fetching origin/!BRANCH!...
git fetch origin !BRANCH!
if !ERRORLEVEL! NEQ 0 goto :ERROR

echo - Pulling changes...
git pull --rebase --autostash origin !BRANCH!
if !ERRORLEVEL! NEQ 0 goto :ERROR

echo [OK] Git update complete.
echo.

:: --- 2. DOCKER BUILD (GATEWAY) ---
set /p REBUILD="[QUESTION] Rebuild Gateway image? (y/N) "
if /i "!REBUILD!"=="y" (
    echo [STEP 2/6] Building Gateway image...
    docker build -t !IMAGE_GATEWAY! .
    if !ERRORLEVEL! NEQ 0 goto :ERROR
    echo [OK] Build complete.
) else (
    echo [STEP 2/6] Skipping build.
)
echo.

:: --- 3. CLEANUP CONTAINERS ---
echo [STEP 3/6] Cleaning up old containers...
docker rm -f !CONTAINER_SANDBOX! >nul 2>&1
docker rm -f !CONTAINER_GATEWAY! >nul 2>&1
echo [OK] Cleanup complete.
echo.

:: --- 4. START GATEWAY ---
echo [STEP 4/6] Starting Gateway (!CONTAINER_GATEWAY!)...
docker run -d ^
    --name !CONTAINER_GATEWAY! ^
    --restart unless-stopped ^
    -p 18789:18789 ^
    -p 18791:18791 ^
    -p 18792:18792 ^
    -p 18793:18793 ^
    -p 9222:9222 ^
    -p 5900:5900 ^
    -p 6080:6080 ^
    -e OPENCLAW_GATEWAY_TOKEN=ae44caec89309c57d77aeab12f1b33a0131e11345cd85ed2 ^
    -v "!CONFIG_MOUNT!:/home/node/.openclaw" ^
    !IMAGE_GATEWAY! ^
    node openclaw.mjs gateway --allow-unconfigured --bind lan

if !ERRORLEVEL! NEQ 0 goto :ERROR

echo - Waiting 5 seconds for Gateway startup...
timeout /t 5 /nobreak >nul

docker ps | findstr !CONTAINER_GATEWAY! >nul
if !ERRORLEVEL! NEQ 0 (
    echo [ERROR] Gateway failed to start!
    docker logs !CONTAINER_GATEWAY! --tail 30
    goto :ERROR
)

echo [OK] Gateway started.
echo.

:: --- 4.5. DIAGNOSTIC: Check listening ports in Gateway ---
echo [DEBUG] Checking listening ports in Gateway...
docker exec !CONTAINER_GATEWAY! sh -c "netstat -tlnp 2>/dev/null || ss -tlnp 2>/dev/null" | findstr "18792"
if !ERRORLEVEL! NEQ 0 (
    echo [WARN] Port 18792 not found listening in Gateway. Checking all ports...
    docker exec !CONTAINER_GATEWAY! sh -c "netstat -tlnp 2>/dev/null || ss -tlnp 2>/dev/null"
)
echo.

:: --- 5. START SANDBOX ---
echo [STEP 5/6] Starting Sandbox (!CONTAINER_SANDBOX!)...
docker run -d ^
    --name !CONTAINER_SANDBOX! ^
    --restart unless-stopped ^
    --network container:!CONTAINER_GATEWAY! ^
    --shm-size=2g ^
    --tmpfs /tmp:rw,exec,nosuid,size=1g ^
    !IMAGE_SANDBOX!

if !ERRORLEVEL! NEQ 0 goto :ERROR

echo - Waiting 5 seconds for Chrome startup...
timeout /t 5 /nobreak >nul

docker ps | findstr !CONTAINER_SANDBOX! >nul
if !ERRORLEVEL! NEQ 0 (
    echo [ERROR] Sandbox failed to start!
    docker logs !CONTAINER_SANDBOX! --tail 30
    goto :ERROR
)

echo [OK] Sandbox started.
echo.

:: --- 6. VERIFICATION ---
echo [TEST] Checking connection between Gateway and Sandbox...
docker exec !CONTAINER_GATEWAY! curl -s --max-time 2 http://127.0.0.1:9222/json/version > temp_check.json

if !ERRORLEVEL! NEQ 0 (
    echo [FAIL] Gateway cannot reach Sandbox CDP port 9222!
    docker logs !CONTAINER_SANDBOX! --tail 30
    del temp_check.json >nul 2>&1
    goto :ERROR
)

findstr "Browser" temp_check.json >nul
if !ERRORLEVEL! EQU 0 (
    echo [PASS] Chrome is responding correctly!
    type temp_check.json
) else (
    echo [FAIL] Invalid response from Chrome.
    type temp_check.json
)

del temp_check.json >nul 2>&1
echo.

:: --- 7. FINAL DIAGNOSTICS ---
echo [INFO] Final network diagnostics:
docker exec -u root  !CONTAINER_GATEWAY! apt-get update
docker exec -u root !CONTAINER_GATEWAY! apt-get install -y net-tools
docker exec -u root !CONTAINER_GATEWAY! ln -s /app/openclaw.mjs /usr/local/bin/openclaw 
docker exec -u root !CONTAINER_GATEWAY! chmod a+rw /usr/local/bin/openclaw 
docker exec !CONTAINER_GATEWAY! sh -c "netstat -tln 2>/dev/null || ss -tln 2>/dev/null | grep -E ':(18789|18791|18792|9222|5900|6080)'"
echo.

echo ========================================================
echo SYSTEM READY
echo ========================================================
echo.
echo Gateway Ports:
echo   - Port 18792: http://localhost:18792
echo   - Port 18789: http://localhost:18789
echo   - Port 18791: http://localhost:18791
echo   - CDP Port 9222: http://localhost:9222
echo.
echo Browser VNC: http://localhost:6080/vnc.html
echo.
echo [TIP] Debug ports in Gateway: docker exec !CONTAINER_GATEWAY! netstat -tlnp
echo [TIP] View logs: docker logs !CONTAINER_GATEWAY! -f
echo.
pause
exit /b 0

:ERROR
echo.
echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
echo CRITICAL ERROR - See details above
echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
echo.
echo [TIP] Check Gateway logs: docker logs !CONTAINER_GATEWAY! --tail 50
echo [TIP] Check Sandbox logs: docker logs !CONTAINER_SANDBOX! --tail 50
echo.
pause
exit /b 1
