# Atualização com um clique: baixa a versão nova do repositório privado no GitHub,
# guarda cópia de segurança, aplica só os arquivos de código, reinstala o necessário,
# testa e, se algo falhar, volta sozinha para a versão anterior.
# Uso: atualizar.ps1            (janela, pergunta antes de instalar)
#      atualizar.ps1 -Verificar (sem janela: sai com código 10 se houver versão nova)
param([switch]$Verificar)
. (Join-Path $PSScriptRoot 'comum.ps1')

$Repo = LerEnv 'GITHUB_REPO'; if (-not $Repo) { $Repo = 'gardenaldopcc/chatbot-atacadao' }
$Token = LerEnv 'GITHUB_TOKEN'
$PastaBackups = Join-Path $Pasta 'backups'
$ArqEstado = Join-Path $PastaBackups 'instalado.json'
$ArqLog = Join-Path $PastaBackups 'atualizacoes.log'
# Arquivos que são SEUS: a atualização nunca grava por cima deles, mesmo se vierem no pacote
$Protegidos = '^(\.env|\.modelos|catalogo/(config|numeros|produtos)\.json|catalogo/catalogo\.txt|catalogo/.*\.(jpg|jpeg|png|mp4|mov|webp)|imagens_produtos/.*|backups/.*|laboratorio/resultados/.*)$'

function GH($caminho, [switch]$Bruto, $Saida) {
  $cab = @{ 'User-Agent' = 'chatbot-atualizador'; Accept = $(if ($Bruto) { 'application/vnd.github.raw' } else { 'application/vnd.github+json' }) }
  if ($Token) { $cab.Authorization = "Bearer $Token" }
  $p = @{ Uri = "https://api.github.com/repos/$Repo$caminho"; Headers = $cab; UseBasicParsing = $true; TimeoutSec = 120 }
  if ($Saida) { Invoke-WebRequest @p -OutFile $Saida | Out-Null; return }
  # O GitHub responde o arquivo bruto como binário; sem isto o PowerShell mostra os bytes ("49 46 48...")
  $c = (Invoke-WebRequest @p).Content
  if ($c -is [byte[]]) { $c = [Text.Encoding]::UTF8.GetString($c) }
  $c.TrimStart([char]0xFEFF)
}
function Log($t) { New-Item -ItemType Directory -Force $PastaBackups | Out-Null; Add-Content -Path $ArqLog -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm') $t" -Encoding UTF8 }
function Hash($arq) { (Get-FileHash -Algorithm SHA256 -LiteralPath $arq).Hash }
function MaisNova($a, $b) { try { [version]($a.Trim()) -gt [version]($b.Trim()) } catch { $a.Trim() -ne $b.Trim() } }

# ---------- Verificar se há versão nova ----------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try { $Remota = ([string](GH '/contents/VERSAO.txt?ref=main' -Bruto)).Trim() }
catch {
  if ($Verificar) { exit 1 }
  $msg = if (-not $Token) { "Falta a chave do GitHub (GITHUB_TOKEN) no arquivo .env.`n`nVeja o passo a passo no LEIA-ME-WINDOWS.md." } else { "Não consegui consultar as atualizações:`n$($_.Exception.Message)`n`nConfira a internet e a chave do GitHub no .env." }
  Aviso $msg 'Atualização' 'Warning'; exit 1
}
$Local = VersaoLocal
if ($Verificar) { if (MaisNova $Remota $Local) { exit 10 } else { exit 0 } }
if (-not (MaisNova $Remota $Local)) { Aviso "Você já está na versão mais nova ($Local)." 'Atualização'; exit 0 }

$Novidades = ''
try { $Novidades = [string](GH '/contents/NOVIDADES.md?ref=main' -Bruto); $Novidades = (($Novidades -split "`n## ")[1] -split "`n" | Select-Object -First 12) -join "`n" } catch {}
if (-not (Pergunta "Há uma versão nova do bot: $Remota (você está na $Local).`n`n$Novidades`n`nInstalar agora? O bot fica fora do ar por 1 a 2 minutos.")) { exit 0 }

# ---------- Janela de progresso ----------
$f = New-Object Windows.Forms.Form; $f.Text = "Atualizando para a versão $Remota"; $f.Size = New-Object Drawing.Size(520, 360)
$f.StartPosition = 'CenterScreen'; $f.FormBorderStyle = 'FixedDialog'; $f.ControlBox = $false; $f.Font = $Fonte; $f.TopMost = $true
$txt = New-Object Windows.Forms.TextBox; $txt.Multiline = $true; $txt.ReadOnly = $true; $txt.ScrollBars = 'Vertical'
$txt.Location = New-Object Drawing.Point(15, 15); $txt.Size = New-Object Drawing.Size(475, 290); $f.Controls.Add($txt)
$f.Show(); $f.Refresh()
function Passo($t) { $txt.AppendText("$t`r`n"); $f.Refresh(); [Windows.Forms.Application]::DoEvents(); Log $t }

$Backup = Join-Path $PastaBackups "antes-da-$Remota"
$Temp = Join-Path $env:TEMP "chatbot-atualizacao-$Remota"
$Alterados = @(); $Novos = @(); $Conflitos = @()
try {
  Passo "1/6 Baixando a versão $Remota..."
  Remove-Item $Temp -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $Temp | Out-Null
  GH '/zipball/main' -Saida (Join-Path $Temp 'pacote.zip')
  Expand-Archive -LiteralPath (Join-Path $Temp 'pacote.zip') -DestinationPath (Join-Path $Temp 'x') -Force
  $Raiz = (Get-ChildItem (Join-Path $Temp 'x') -Directory | Select-Object -First 1).FullName

  Passo '2/6 Guardando cópia de segurança do banco (clientes e conversas)...'
  New-Item -ItemType Directory -Force $Backup | Out-Null
  $pg = Start-Process docker -ArgumentList 'compose exec -T postgres pg_dump -U chatbot bot' -WorkingDirectory $Pasta -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $Backup 'banco-bot.sql')
  if ($pg.ExitCode -ne 0) { Passo '   (não consegui copiar o banco; sigo com a cópia dos arquivos)' }

  Passo '3/6 Aplicando os arquivos novos...'
  $Estado = @{}
  $e = LerJson $ArqEstado; if ($e) { foreach ($p in $e.PSObject.Properties) { $Estado[$p.Name] = $p.Value } }
  $primeira = $Estado.Count -eq 0
  foreach ($arq in Get-ChildItem $Raiz -Recurse -File) {
    $rel = $arq.FullName.Substring($Raiz.Length + 1).Replace('\', '/')
    if ($rel -match $Protegidos -or $rel -match '^\.git') { continue }
    $dest = Join-Path $Pasta $rel; $novo = Hash $arq.FullName
    if (Test-Path -LiteralPath $dest) {
      $atual = Hash $dest
      if ($atual -eq $novo) { $Estado[$rel] = $novo; continue }
      $instalado = if ($primeira) { $atual } else { $Estado[$rel] }
      $copia = Join-Path $Backup $rel; New-Item -ItemType Directory -Force (Split-Path $copia) | Out-Null; Copy-Item -LiteralPath $dest $copia -Force
      if ($instalado -and $atual -ne $instalado) {
        # Você mudou este arquivo: mantém o seu e deixa o novo ao lado
        $base = [IO.Path]::GetFileNameWithoutExtension($dest); $ext = [IO.Path]::GetExtension($dest)
        Copy-Item $arq.FullName (Join-Path (Split-Path $dest) "$base (nova versão)$ext") -Force
        $Conflitos += $rel; continue
      }
      Copy-Item $arq.FullName $dest -Force; $Alterados += $rel
    } else {
      New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null; Copy-Item $arq.FullName $dest -Force; $Novos += $rel
    }
    $Estado[$rel] = $novo
  }
  Passo "   $($Alterados.Count) arquivo(s) atualizado(s), $($Novos.Count) novo(s)."

  $mudou = $Alterados + $Novos
  if ($mudou -match '^docker-compose\.yml$') { Passo '4/6 Reiniciando os serviços...'; Docker 'compose up -d' -Esperar | Out-Null } else { Passo '4/6 Serviços: nada a reiniciar.' }

  if ($mudou -match '^(fluxo|init-db)/') {
    Passo '5/6 Reinstalando o fluxo no n8n (sem pedir a chave)...'
    $bash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
    $env:SO_FLUXO = '1'; $env:MSYS_NO_PATHCONV = '1'; $env:PATH = "$PSScriptRoot\bin;$env:PATH"
    $r = Start-Process $bash -ArgumentList './instalar-fluxo.command' -WorkingDirectory $Pasta -WindowStyle Hidden -Wait -PassThru `
      -RedirectStandardOutput (Join-Path $Backup 'instalador.log') -RedirectStandardError (Join-Path $Backup 'instalador-erros.log')
    if ($r.ExitCode -ne 0) { throw "o instalador do fluxo falhou (veja $Backup\instalador.log)" }
  } else { Passo '5/6 Fluxo: sem mudanças.' }

  Passo '6/6 Testando se o bot responde...'
  $ok = $false; for ($i = 0; $i -lt 36 -and -not $ok; $i++) { $ok = BotNoAr; if (-not $ok) { Start-Sleep 5 } }
  if (-not $ok) { throw 'o bot não voltou a responder depois da atualização' }

  New-Item -ItemType Directory -Force $PastaBackups | Out-Null
  GravarJson $ArqEstado ([pscustomobject]$Estado)
  Passo "✅ Atualizado para a versão $Remota."
  $f.Close()
  $extra = if ($Conflitos) { "`n`nVocê tinha alterado estes arquivos, então mantive os seus e deixei a versão nova ao lado com '(nova versão)' no nome:`n• " + ($Conflitos -join "`n• ") } else { '' }
  Aviso "✅ Bot atualizado para a versão $Remota.$extra`n`nA cópia da versão anterior está em backups\antes-da-$Remota." 'Atualização concluída'
}
catch {
  $erro = $_.Exception.Message
  Passo "❌ Erro: $erro"
  Passo 'Voltando para a versão anterior...'
  foreach ($rel in $Alterados) { $c = Join-Path $Backup $rel; if (Test-Path -LiteralPath $c) { Copy-Item -LiteralPath $c (Join-Path $Pasta $rel) -Force } }
  foreach ($rel in $Novos) { Remove-Item -LiteralPath (Join-Path $Pasta $rel) -Force -ErrorAction SilentlyContinue }
  try {
    if (($Alterados + $Novos) -match '^docker-compose\.yml$') { Docker 'compose up -d' -Esperar | Out-Null }
    if (($Alterados + $Novos) -match '^(fluxo|init-db)/') {
      $env:SO_FLUXO = '1'; Start-Process (Join-Path $env:ProgramFiles 'Git\bin\bash.exe') -ArgumentList './instalar-fluxo.command' -WorkingDirectory $Pasta -WindowStyle Hidden -Wait | Out-Null
    }
  } catch {}
  $f.Close()
  Log "Atualização para $Remota desfeita: $erro"
  Aviso "A atualização para a versão $Remota deu erro e foi desfeita. O bot voltou para a versão $Local.`n`nErro: $erro`n`nMe mande este aviso (e o arquivo backups\atualizacoes.log)." 'Atualização desfeita' 'Error'
  exit 1
}
