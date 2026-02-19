@echo off
setlocal ENABLEDELAYEDEXPANSION

rem === Config : nom du conteneur gateway ===
set CONTAINER=openclaw_gateway

echo ============================================
echo   OpenClaw - Outil de pairing (devices / canaux)
echo   Conteneur cible : %CONTAINER%
echo ============================================
echo.

rem === Vérifier l'existence du conteneur ===
for /f "tokens=1" %%i in ('
  docker ps -a -q --filter "name=%CONTAINER%"
') do set CONTAINER_ID=%%i

if "%CONTAINER_ID%"=="" (
    echo [ERREUR] Le conteneur "%CONTAINER%" n'existe pas.
    echo Lance d'abord "docker compose up -d" ou adapte le nom du conteneur dans ce script.
    goto :EOF
)

rem === S'assurer qu'il est demarre ===
set RUNNING=
for /f "tokens=1" %%i in ('
  docker ps -q --filter "name=%CONTAINER%"
') do set RUNNING=%%i

if "%RUNNING%"=="" (
    echo [INFO] Le conteneur "%CONTAINER%" est arrete. Demarrage...
    docker start %CONTAINER% >nul 2>&1
    if errorlevel 1 (
        echo [ERREUR] Impossible de demarrer le conteneur "%CONTAINER%".
        goto :EOF
    )
    echo [OK] Conteneur demarre.
)

:MENU
echo.
echo ============================================
echo   MENU PAIRING OPENCLAW
echo ============================================
echo   1^) Lister les demandes de pairing UI (devices)
echo   2^) Approuver une demande UI (devices)
echo   3^) Lister les demandes de pairing de canaux (WhatsApp/Telegram/...)
echo   4^) Approuver une demande de pairing de canal
echo   Q^) Quitter
echo ============================================
set "CHOIX="
set /p CHOIX="Votre choix : "

if /I "%CHOIX%"=="1" goto DEVICES_LIST
if /I "%CHOIX%"=="2" goto DEVICES_APPROVE
if /I "%CHOIX%"=="3" goto PAIRING_LIST
if /I "%CHOIX%"=="4" goto PAIRING_APPROVE
if /I "%CHOIX%"=="Q" goto EOF

echo.
echo [ERREUR] Choix invalide.
goto MENU

:DEVICES_LIST
echo.
echo [INFO] Demandes de pairing UI / devices en attente :
echo.
docker exec -it %CONTAINER% ./openclaw.mjs devices list
echo.
pause
goto MENU

:DEVICES_APPROVE
echo.
set "REQ_ID="
set /p REQ_ID="ID de la demande a approuver (requestId) : "
if "%REQ_ID%"=="" (
    echo [INFO] Aucun ID saisi, retour au menu.
    goto MENU
)
echo.
echo Vous allez approuver la demande "%REQ_ID%".
choice /M "Confirmer l'approbation"
if errorlevel 2 (
    echo [INFO] Annule.
    goto MENU
)

echo.
docker exec -it %CONTAINER% ./openclaw.mjs devices approve %REQ_ID%
echo.
pause
goto MENU

:PAIRING_LIST
echo.
echo [INFO] Demandes de pairing de canaux (WhatsApp/Telegram/etc.) :
echo.
docker exec -it %CONTAINER% ./openclaw.mjs pairing list
echo.
pause
goto MENU

:PAIRING_APPROVE
echo.
set "CHANNEL="
set /p CHANNEL="Nom du canal a approuver (ex: whatsapp, telegram, slack...) : "
if "%CHANNEL%"=="" (
    echo [INFO] Aucun canal saisi, retour au menu.
    goto MENU
)
echo.
echo Vous allez approuver le pairing pour le canal "%CHANNEL%".
choice /M "Confirmer l'approbation"
if errorlevel 2 (
    echo [INFO] Annule.
    goto MENU
)

echo.
docker exec -it %CONTAINER% ./openclaw.mjs pairing approve %CHANNEL%
echo.
pause
goto MENU

:EOF
echo.
echo [INFO] Fin du script.
endlocal
