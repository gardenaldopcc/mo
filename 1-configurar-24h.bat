@echo off
chcp 65001 >nul
rem Deixa o PC pronto para rodar o bot 24 horas. Rode como administrador.
cd /d "%~dp0"
net session >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Clique com o botao direito neste arquivo e escolha "Executar como administrador".
  pause & exit /b 1
)
echo === 1/3 Desligando suspensao e hibernacao (na tomada) ===
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change disk-timeout-ac 0
powercfg /hibernate off

echo === 2/3 Ligando o bot sozinho quando o Windows entrar ===
schtasks /create /tn "Chatbot Atacadao - iniciar" /tr "\"%~dp0iniciar.bat\" auto" /sc onlogon /rl highest /f

echo === 3/4 Conferindo a cada 10 minutos se o bot continua de pe ===
schtasks /create /tn "Chatbot Atacadao - vigia" /tr "\"%~dp0iniciar.bat\" auto" /sc minute /mo 10 /rl highest /f

echo === 4/4 Abrindo o painel (icone ao lado do relogio) quando o Windows entrar ===
schtasks /create /tn "Chatbot Atacadao - painel" /tr "\"%~dp0painel.bat\"" /sc onlogon /it /f

echo.
echo Pronto. Faltam 2 ajustes manuais (veja o LEIA-ME-WINDOWS.md):
echo  - Docker Desktop: Settings ^> General ^> marcar "Start Docker Desktop when you sign in"
echo  - Login automatico do Windows (netplwiz), para o bot voltar sozinho depois de uma queda de energia
pause
