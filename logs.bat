@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Mostrando os registros (feche a janela para sair)...
docker compose logs -f --tail 100
