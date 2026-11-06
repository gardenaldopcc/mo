@echo off
chcp 65001 >nul
cd /d "%~dp0"
rem Uso: laboratorio.bat            (todas as personas)
rem      laboratorio.bat 5          (5 sorteadas)
rem      laboratorio.bat todas 8 instalacao
set "PYTHONUTF8=1"
python laboratorio\rodar.py %*
pause
