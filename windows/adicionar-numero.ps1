# Assistente para colocar um número novo de WhatsApp no bot (Windows).
# Pede os dados numa janela, grava em catalogo\numeros.json, cria a conexão no Evolution,
# mostra o QR Code e, quando o celular conecta, liga o número ao bot.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$Pasta = Split-Path -Parent $PSScriptRoot
$ArqNumeros = Join-Path $Pasta 'catalogo\numeros.json'
$ArqConfig = Join-Path $Pasta 'catalogo\config.json'
$Evolution = 'http://localhost:8080'
$Utf8 = New-Object System.Text.UTF8Encoding $false

function Aviso($texto, $titulo = 'Novo número', $icone = 'Information') {
  [System.Windows.Forms.MessageBox]::Show($texto, $titulo, 'OK', $icone) | Out-Null
}

# Chave do Evolution (fica no .env)
$Chave = ''
$Env = Join-Path $Pasta '.env'
if (Test-Path $Env) {
  foreach ($l in [IO.File]::ReadAllLines($Env, $Utf8)) { if ($l -match '^\s*EVOLUTION_API_KEY\s*=\s*(.+?)\s*$') { $Chave = $Matches[1].Trim('"') } }
}
if (-not $Chave) { Aviso "Não encontrei a EVOLUTION_API_KEY no arquivo .env da pasta do projeto." 'Erro' 'Error'; exit 1 }
$Cab = @{ apikey = $Chave }

function Evo($metodo, $caminho, $corpo = $null) {
  $p = @{ Method = $metodo; Uri = "$Evolution$caminho"; Headers = $Cab; ContentType = 'application/json; charset=utf-8'; TimeoutSec = 20 }
  if ($corpo) { $p.Body = $Utf8.GetBytes(($corpo | ConvertTo-Json -Depth 6)) }
  Invoke-RestMethod @p
}

try { Evo GET '/instance/fetchInstances' | Out-Null }
catch { Aviso "O bot não está ligado (não consegui falar com o Evolution).`n`nRode o iniciar.bat, espere 1 minuto e abra este assistente de novo." 'Bot desligado' 'Warning'; exit 1 }

# Cadastro atual
$Numeros = [ordered]@{}
if (Test-Path $ArqNumeros) {
  $obj = [IO.File]::ReadAllText($ArqNumeros, $Utf8) | ConvertFrom-Json
  foreach ($p in $obj.PSObject.Properties) { $Numeros[$p.Name] = $p.Value }
}
$Config = [IO.File]::ReadAllText($ArqConfig, $Utf8) | ConvertFrom-Json
$Sugestao = "Número $(@($Numeros.Keys | Where-Object { $_ -ne '_LEIA' }).Count + 1)"

# ---------- Tela 1: dados do atendente ----------
$f = New-Object Windows.Forms.Form
$f.Text = 'Novo número de WhatsApp'; $f.Size = New-Object Drawing.Size(560, 470); $f.StartPosition = 'CenterScreen'
$f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.Font = New-Object Drawing.Font('Segoe UI', 10)

$y = 15
function Campo($rotulo, $ajuda, $valor) {
  $l = New-Object Windows.Forms.Label; $l.Text = $rotulo; $l.Location = New-Object Drawing.Point(20, $script:y); $l.AutoSize = $true
  $l.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold); $f.Controls.Add($l)
  $a = New-Object Windows.Forms.Label; $a.Text = $ajuda; $a.Location = New-Object Drawing.Point(20, ($script:y + 22)); $a.Size = New-Object Drawing.Size(510, 20)
  $a.ForeColor = [Drawing.Color]::DimGray; $a.Font = New-Object Drawing.Font('Segoe UI', 8.5); $f.Controls.Add($a)
  $t = New-Object Windows.Forms.TextBox; $t.Text = $valor; $t.Location = New-Object Drawing.Point(20, ($script:y + 44)); $t.Size = New-Object Drawing.Size(505, 26); $f.Controls.Add($t)
  $script:y += 85
  return $t
}
$tAtendente = Campo 'Nome do atendente' 'Como o bot vai se apresentar neste número (ex.: Camila).' ''
$tLink = Campo 'Link do app deste número' 'O link curto que identifica este número (ex.: https://seusite.com/camila).' ''
$tGrupo = Campo 'Grupo da equipe' 'Nome exato do grupo onde este número vai avisar a equipe.' 'Bot Geral'
$tConexao = Campo 'Nome da conexão (pode deixar como está)' 'Só para identificar o número no Evolution. Não mostrado ao cliente.' $Sugestao

$ok = New-Object Windows.Forms.Button; $ok.Text = 'Continuar  →'; $ok.Size = New-Object Drawing.Size(150, 36)
$ok.Location = New-Object Drawing.Point(375, ($y + 5)); $ok.BackColor = [Drawing.Color]::FromArgb(37, 211, 102); $ok.ForeColor = 'White'; $ok.FlatStyle = 'Flat'
$f.Controls.Add($ok); $f.AcceptButton = $ok
$cancelar = New-Object Windows.Forms.Button; $cancelar.Text = 'Cancelar'; $cancelar.Size = New-Object Drawing.Size(110, 36)
$cancelar.Location = New-Object Drawing.Point(255, ($y + 5)); $cancelar.DialogResult = 'Cancel'; $f.Controls.Add($cancelar); $f.CancelButton = $cancelar

$ok.Add_Click({
  $erro = @()
  if (-not $tAtendente.Text.Trim()) { $erro += '• Preencha o nome do atendente.' }
  if ($tLink.Text.Trim() -notmatch '^https?://\S+$') { $erro += '• O link do app precisa começar com https:// e não pode ter espaços.' }
  if (-not $tGrupo.Text.Trim()) { $erro += '• Preencha o nome do grupo.' }
  if (-not $tConexao.Text.Trim()) { $erro += '• Preencha o nome da conexão.' }
  if ($erro) { Aviso ($erro -join "`n") 'Falta alguma coisa' 'Warning'; return }
  if ($Numeros.Contains($tConexao.Text.Trim())) {
    $r = [Windows.Forms.MessageBox]::Show("Já existe um número chamado '$($tConexao.Text.Trim())'. Quer atualizar os dados dele?", 'Número já cadastrado', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
  }
  $f.DialogResult = 'OK'; $f.Close()
})
if ($f.ShowDialog() -ne 'OK') { exit 0 }

$Conexao = $tConexao.Text.Trim()
$Atendente = $tAtendente.Text.Trim()
$Link = $tLink.Text.Trim()
$Grupo = $tGrupo.Text.Trim()

# ---------- Grava no numeros.json ----------
if (-not $Numeros.Contains('_LEIA')) {
  $Numeros.Insert(0, '_LEIA', 'Um bloco por número de WhatsApp. A chave é o NOME DA CONEXÃO no Evolution. O que não estiver aqui usa o config.json.')
}
$Numeros[$Conexao] = [ordered]@{ atendente = $Atendente; link_app = $Link; grupo_equipe = $Grupo }
[IO.File]::WriteAllText($ArqNumeros, ($Numeros | ConvertTo-Json -Depth 5), $Utf8)

# ---------- Cria a conexão no Evolution ----------
$Url = [Uri]::EscapeDataString($Conexao)
$existe = @(Evo GET '/instance/fetchInstances') | Where-Object { ($_.name, $_.instanceName, $_.instance.instanceName) -contains $Conexao }
if (-not $existe) {
  try { Evo POST '/instance/create' @{ instanceName = $Conexao; integration = 'WHATSAPP-BAILEYS'; qrcode = $true } | Out-Null }
  catch { Aviso "Não consegui criar a conexão no Evolution:`n$($_.Exception.Message)" 'Erro' 'Error'; exit 1 }
}

function Estado { try { (Evo GET "/instance/connectionState/$Url").instance.state } catch { '' } }
function NovoQR {
  try {
    $r = Evo GET "/instance/connect/$Url"
    $b64 = ($r.base64 -replace '^data:image/\w+;base64,', '')
    if ($b64) { return [Drawing.Image]::FromStream((New-Object IO.MemoryStream (, [Convert]::FromBase64String($b64)))) }
  } catch {}
  return $null
}

# ---------- Tela 2: QR Code ----------
$jaConectado = (Estado) -eq 'open'
if (-not $jaConectado) {
  $q = New-Object Windows.Forms.Form
  $q.Text = "Conectar o WhatsApp de $Atendente"; $q.Size = New-Object Drawing.Size(480, 640); $q.StartPosition = 'CenterScreen'
  $q.FormBorderStyle = 'FixedDialog'; $q.MaximizeBox = $false; $q.Font = New-Object Drawing.Font('Segoe UI', 10)
  $passos = New-Object Windows.Forms.Label
  $passos.Text = "No celular do NÚMERO NOVO:`n1. Abra o WhatsApp`n2. Toque em ⋮ (ou Configurações) > Aparelhos conectados`n3. Toque em Conectar aparelho e aponte para o código abaixo"
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
    if ((Estado) -eq 'open') { $timer.Stop(); $q.DialogResult = 'OK'; $q.Close(); return }
    # O código do WhatsApp vence em uns 40 segundos: gera outro a cada 30
    if (((Get-Date) - $script:ultimoQR).TotalSeconds -gt 30) {
      $novo = NovoQR
      if ($novo) { $img.Image = $novo; $script:ultimoQR = Get-Date; $status.Text = 'Aguardando a leitura... (o código se renova sozinho)' }
      else { $status.Text = 'Não consegui gerar o código. Confira se o bot está ligado.' }
    }
  })
  $q.Add_Shown({ $timer.Start() })
  $res = $q.ShowDialog(); $timer.Stop()
  if ($res -ne 'OK') {
    Aviso "Os dados de $Atendente foram salvos.`n`nQuando for conectar o celular, abra este assistente de novo com o MESMO nome de conexão ('$Conexao') e escolha atualizar." 'Fica para depois'
    exit 0
  }
}

# ---------- Liga o número ao bot ----------
try {
  Evo POST "/webhook/set/$Url" @{ webhook = @{ enabled = $true; url = 'http://n8n:5678/webhook/whatsapp'; byEvents = $false; base64 = $true; events = @('MESSAGES_UPSERT') } } | Out-Null
} catch {
  Aviso "O WhatsApp conectou, mas não consegui ligar o número ao bot:`n$($_.Exception.Message)`n`nRode o ligar-numeros.bat." 'Quase lá' 'Warning'; exit 1
}

Aviso @"
✅ Pronto! O número de $Atendente está conectado ao bot.

Para terminar, faça isto:

1. Adicione este número no grupo "$Grupo" da equipe (é por lá que ele vai avisar quando precisar de alguém).
2. De outro celular, mande "oi" para este número e confira se $Atendente responde.
3. Confira se o link $Link abre a página do app.

Se algo der errado, rode o logs.bat e me mande o que aparecer.
"@ 'Tudo certo!'
