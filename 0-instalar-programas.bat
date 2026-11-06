@echo off
chcp 65001 >nul
rem Instala o que o projeto precisa no Windows: Docker Desktop, Git (traz o bash) e Python.
rem Rode clicando com o botao direito > "Executar como administrador".
echo === Instalando os programas (pode demorar alguns minutos) ===
wsl --install --no-distribution
winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements
winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
rem ffmpeg: usado para converter o video de instalacao (opcional; sem ele o painel usa o Docker)
winget install -e --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements
echo.
echo === Pronto. REINICIE o computador, abra o Docker Desktop uma vez, aceite os termos
echo     e depois rode o 1-configurar-24h.bat (como administrador). ===
pause
