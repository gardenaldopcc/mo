@echo off
chcp 65001 >nul
cd /d "%~dp0"
rem Marca que foi desligado de proposito: o vigia do Windows nao religa ate rodar o iniciar.bat
echo desligado > .desligado
docker compose down
pause
