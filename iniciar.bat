@echo off
chcp 65001 >nul
cd /d "%~dp0"
rem Liga o Docker Desktop (se estiver desligado) e sobe WhatsApp (Evolution), n8n e banco.
rem "iniciar.bat auto" e usado pelo agendador do Windows (nao para no final).
docker info >nul 2>&1
if not errorlevel 1 goto subir
echo Ligando o Docker Desktop...
start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set /a tentativas=0
:esperar
timeout /t 5 /nobreak >nul
docker info >nul 2>&1
if not errorlevel 1 goto subir
set /a tentativas+=1
if %tentativas% lss 60 goto esperar
echo [ERRO] O Docker Desktop nao ligou em 5 minutos.
if /i not "%1"=="auto" pause
exit /b 1

:subir
docker compose up -d
if /i "%1"=="auto" exit /b 0
docker compose ps
echo.
echo Evolution API: http://localhost:8080/manager
echo n8n:           http://localhost:5678
pause
