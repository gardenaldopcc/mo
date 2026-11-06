@echo off
chcp 65001 >nul
cd /d "%~dp0"
rem Abre o assistente (janela) para colocar um número novo de WhatsApp no bot.
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0windows\adicionar-numero.ps1"
