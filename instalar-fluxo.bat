@echo off
chcp 65001 >nul
cd /d "%~dp0"

set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not exist "%BASH%" (
  echo [ERRO] Git Bash nao encontrado. Rode primeiro o 0-instalar-programas.bat.
  pause & exit /b 1
)
rem Evita que o Git Bash troque caminhos como /tmp por C:\... e usa o "python" do Windows como python3
set "MSYS_NO_PATHCONV=1"
set "PATH=%~dp0windows\bin;%PATH%"

"%BASH%" ./instalar-fluxo.command
pause
