# Funções usadas por todas as janelas do bot no Windows (painel, configurações, novo número, atualização).
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$Pasta = Split-Path -Parent $PSScriptRoot
$PastaCatalogo = Join-Path $Pasta 'catalogo'
$ArqNumeros = Join-Path $PastaCatalogo 'numeros.json'
$ArqConfig = Join-Path $PastaCatalogo 'config.json'
$ArqEnv = Join-Path $Pasta '.env'
$Evolution = 'http://localhost:8080'
$Utf8 = New-Object System.Text.UTF8Encoding $false
$Fonte = New-Object Drawing.Font('Segoe UI', 10)
$FonteNegrito = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
$FontePequena = New-Object Drawing.Font('Segoe UI', 8.5)
$Verde = [Drawing.Color]::FromArgb(37, 211, 102)

function Aviso($texto, $titulo = 'Bot do WhatsApp', $icone = 'Information') {
  [System.Windows.Forms.MessageBox]::Show($texto, $titulo, 'OK', $icone) | Out-Null
}
function Pergunta($texto, $titulo = 'Bot do WhatsApp') {
  ([System.Windows.Forms.MessageBox]::Show($texto, $titulo, 'YesNo', 'Question')) -eq 'Yes'
}

function LerTexto($arq) { [IO.File]::ReadAllText($arq, $Utf8) }
function GravarTexto($arq, $texto) { [IO.File]::WriteAllText($arq, $texto, $Utf8) }
function LerJson($arq) { if (Test-Path $arq) { LerTexto $arq | ConvertFrom-Json } else { $null } }
function GravarJson($arq, $obj) { GravarTexto $arq ($obj | ConvertTo-Json -Depth 8) }

# .env: lê e grava variáveis (sem mexer nas outras linhas)
function LerEnv($nome) {
  if (-not (Test-Path $ArqEnv)) { return '' }
  foreach ($l in [IO.File]::ReadAllLines($ArqEnv, $Utf8)) {
    if ($l -match "^\s*$nome\s*=\s*(.*?)\s*$") { return $Matches[1].Trim('"') }
  }
  return ''
}
function GravarEnv($nome, $valor) {
  $linhas = @(); $achou = $false
  if (Test-Path $ArqEnv) { $linhas = @([IO.File]::ReadAllLines($ArqEnv, $Utf8)) }
  for ($i = 0; $i -lt $linhas.Count; $i++) {
    if ($linhas[$i] -match "^\s*$nome\s*=") { $linhas[$i] = "$nome=$valor"; $achou = $true }
  }
  if (-not $achou) { $linhas += "$nome=$valor" }
  [IO.File]::WriteAllText($ArqEnv, (($linhas -join "`n") + "`n"), $Utf8)
}

# Números cadastrados (catalogo\numeros.json) como dicionário ordenado
function LerNumeros {
  $n = [ordered]@{}
  $obj = LerJson $ArqNumeros
  if ($obj) { foreach ($p in $obj.PSObject.Properties) { $n[$p.Name] = $p.Value } }
  return $n
}
function GravarNumeros($n) {
  if (-not $n.Contains('_LEIA')) {
    $n.Insert(0, '_LEIA', 'Um bloco por número de WhatsApp. A chave é o NOME DA CONEXÃO no Evolution. O que não estiver aqui usa o config.json.')
  }
  GravarJson $ArqNumeros $n
}

# Evolution API (WhatsApp)
function Evo($metodo, $caminho, $corpo = $null) {
  $p = @{ Method = $metodo; Uri = "$Evolution$caminho"; Headers = @{ apikey = (LerEnv 'EVOLUTION_API_KEY') }
    ContentType = 'application/json; charset=utf-8'; TimeoutSec = 15 }
  if ($corpo) { $p.Body = $Utf8.GetBytes(($corpo | ConvertTo-Json -Depth 6)) }
  Invoke-RestMethod @p
}
function NomeInstancia($i) { foreach ($c in @($i.name, $i.instanceName, $i.instance.instanceName)) { if ($c) { return $c } }; '' }
function ListarConexoes {
  # Devolve lista de { nome, estado } ('open' = conectado)
  @(Evo GET '/instance/fetchInstances') | ForEach-Object {
    $estado = $_.connectionStatus; if (-not $estado) { $estado = $_.instance.state }
    [pscustomobject]@{ nome = (NomeInstancia $_); estado = $estado }
  } | Where-Object { $_.nome }
}
function EstadoConexao($nome) {
  try { (Evo GET "/instance/connectionState/$([Uri]::EscapeDataString($nome))").instance.state } catch { '' }
}
function LigarAoBot($nome) {
  Evo POST "/webhook/set/$([Uri]::EscapeDataString($nome))" @{ webhook = @{ enabled = $true; url = 'http://n8n:5678/webhook/whatsapp'; byEvents = $false; base64 = $true; events = @('MESSAGES_UPSERT') } } | Out-Null
}
function BotNoAr {
  try { Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:5678/healthz' -TimeoutSec 5 | Out-Null; Evo GET '/instance/fetchInstances' | Out-Null; $true } catch { $false }
}

# Janela do QR Code: devolve $true quando o celular conecta
function MostrarQR($conexao, $atendente) {
  $url = [Uri]::EscapeDataString($conexao)
  if ((EstadoConexao $conexao) -eq 'open') { return $true }
  $q = New-Object Windows.Forms.Form
  $q.Text = "Conectar o WhatsApp de $atendente"; $q.Size = New-Object Drawing.Size(480, 640); $q.StartPosition = 'CenterScreen'
  $q.FormBorderStyle = 'FixedDialog'; $q.MaximizeBox = $false; $q.Font = $Fonte; $q.TopMost = $true
  $passos = New-Object Windows.Forms.Label
  $passos.Text = "No celular do número de $($atendente):`n1. Abra o WhatsApp`n2. Toque em ⋮ (ou Configurações) > Aparelhos conectados`n3. Toque em Conectar aparelho e aponte para o código abaixo"
  $passos.Location = New-Object Drawing.Point(20, 15); $passos.Size = New-Object Drawing.Size(430, 95); $q.Controls.Add($passos)
  $img = New-Object Windows.Forms.PictureBox; $img.Location = New-Object Drawing.Point(65, 115); $img.Size = New-Object Drawing.Size(340, 340)
  $img.SizeMode = 'Zoom'; $img.BorderStyle = 'FixedSingle'; $q.Controls.Add($img)
  $status = New-Object Windows.Forms.Label; $status.Text = 'Gerando o código...'; $status.Location = New-Object Drawing.Point(20, 470)
  $status.Size = New-Object Drawing.Size(430, 50); $status.TextAlign = 'MiddleCenter'; $q.Controls.Add($status)
  $fechar = New-Object Windows.Forms.Button; $fechar.Text = 'Fazer depois'; $fechar.Size = New-Object Drawing.Size(130, 34)
  $fechar.Location = New-Object Drawing.Point(320, 545); $fechar.DialogResult = 'Cancel'; $q.Controls.Add($fechar)

  $script:ultimoQR = [DateTime]::MinValue
  $timer = New-Object Windows.Forms.Timer; $timer.Interval = 3000
  $timer.Add_Tick({
    if ((EstadoConexao $conexao) -eq 'open') { $timer.Stop(); $q.DialogResult = 'OK'; $q.Close(); return }
    # O código do WhatsApp vence em uns 40 segundos: pede outro a cada 30
    if (((Get-Date) - $script:ultimoQR).TotalSeconds -gt 30) {
      try {
        $r = Evo GET "/instance/connect/$url"
        $b64 = ($r.base64 -replace '^data:image/\w+;base64,', '')
        if ($b64) {
          $img.Image = [Drawing.Image]::FromStream((New-Object IO.MemoryStream (, [Convert]::FromBase64String($b64))))
          $script:ultimoQR = Get-Date; $status.Text = 'Aguardando a leitura... (o código se renova sozinho)'
        }
      } catch { $status.Text = 'Não consegui gerar o código. Confira se o bot está ligado.' }
    }
  })
  $q.Add_Shown({ $timer.Start() })
  $res = $q.ShowDialog(); $timer.Stop()
  return ($res -eq 'OK')
}

# Docker (rodado escondido, sem abrir janela preta)
function Docker([string]$argumentos, [switch]$Esperar) {
  $p = Start-Process -FilePath 'docker' -ArgumentList $argumentos -WorkingDirectory $Pasta -WindowStyle Hidden -PassThru
  if ($Esperar) { $p.WaitForExit(); return $p.ExitCode }
}

# Versão instalada
function VersaoLocal { $a = Join-Path $Pasta 'VERSAO.txt'; if (Test-Path $a) { (LerTexto $a).Trim() } else { '0' } }
