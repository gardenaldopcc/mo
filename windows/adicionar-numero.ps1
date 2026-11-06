# Assistente para colocar um número novo de WhatsApp no bot.
# Pede os dados numa janela, grava em catalogo\numeros.json, cria a conexão no Evolution,
# mostra o QR Code e, quando o celular conecta, liga o número ao bot.
. (Join-Path $PSScriptRoot 'comum.ps1')

if (-not (BotNoAr)) {
  Aviso "O bot não está ligado.`n`nLigue pelo painel (ou rode o iniciar.bat), espere 1 minuto e abra de novo." 'Bot desligado' 'Warning'; exit 1
}
$Numeros = LerNumeros
$Sugestao = "Número $(@($Numeros.Keys | Where-Object { $_ -ne '_LEIA' }).Count + 1)"

$f = New-Object Windows.Forms.Form
$f.Text = 'Novo número de WhatsApp'; $f.Size = New-Object Drawing.Size(560, 470); $f.StartPosition = 'CenterScreen'
$f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.Font = $Fonte

$script:y = 15
function Campo($rotulo, $ajuda, $valor) {
  $l = New-Object Windows.Forms.Label; $l.Text = $rotulo; $l.Location = New-Object Drawing.Point(20, $script:y); $l.AutoSize = $true; $l.Font = $FonteNegrito; $f.Controls.Add($l)
  $a = New-Object Windows.Forms.Label; $a.Text = $ajuda; $a.Location = New-Object Drawing.Point(20, ($script:y + 22)); $a.Size = New-Object Drawing.Size(510, 20)
  $a.ForeColor = [Drawing.Color]::DimGray; $a.Font = $FontePequena; $f.Controls.Add($a)
  $t = New-Object Windows.Forms.TextBox; $t.Text = $valor; $t.Location = New-Object Drawing.Point(20, ($script:y + 44)); $t.Size = New-Object Drawing.Size(505, 26); $f.Controls.Add($t)
  $script:y += 85
  return $t
}
$tAtendente = Campo 'Nome do atendente' 'Como o bot vai se apresentar neste número (ex.: Camila).' ''
$tLink = Campo 'Link do app deste número' 'O link curto que identifica este número (ex.: https://seusite.com/camila).' ''
$tGrupo = Campo 'Grupo da equipe' 'Nome exato do grupo onde este número vai avisar a equipe.' 'Bot Geral'
$tConexao = Campo 'Nome da conexão (pode deixar como está)' 'Só para identificar o número no sistema. O cliente não vê.' $Sugestao

$ok = New-Object Windows.Forms.Button; $ok.Text = 'Continuar  →'; $ok.Size = New-Object Drawing.Size(150, 36)
$ok.Location = New-Object Drawing.Point(375, ($script:y + 5)); $ok.BackColor = $Verde; $ok.ForeColor = 'White'; $ok.FlatStyle = 'Flat'
$f.Controls.Add($ok); $f.AcceptButton = $ok
$cancelar = New-Object Windows.Forms.Button; $cancelar.Text = 'Cancelar'; $cancelar.Size = New-Object Drawing.Size(110, 36)
$cancelar.Location = New-Object Drawing.Point(255, ($script:y + 5)); $cancelar.DialogResult = 'Cancel'; $f.Controls.Add($cancelar); $f.CancelButton = $cancelar

$ok.Add_Click({
  $erro = @()
  if (-not $tAtendente.Text.Trim()) { $erro += '• Preencha o nome do atendente.' }
  if ($tLink.Text.Trim() -notmatch '^https?://\S+$') { $erro += '• O link do app precisa começar com https:// e não pode ter espaços.' }
  if (-not $tGrupo.Text.Trim()) { $erro += '• Preencha o nome do grupo.' }
  if (-not $tConexao.Text.Trim()) { $erro += '• Preencha o nome da conexão.' }
  if ($erro) { Aviso ($erro -join "`n") 'Falta alguma coisa' 'Warning'; return }
  if ($Numeros.Contains($tConexao.Text.Trim()) -and -not (Pergunta "Já existe um número chamado '$($tConexao.Text.Trim())'. Quer atualizar os dados dele?")) { return }
  $f.DialogResult = 'OK'; $f.Close()
})
if ($f.ShowDialog() -ne 'OK') { exit 0 }

$Conexao = $tConexao.Text.Trim(); $Atendente = $tAtendente.Text.Trim(); $Link = $tLink.Text.Trim(); $Grupo = $tGrupo.Text.Trim()
$Numeros[$Conexao] = [ordered]@{ atendente = $Atendente; link_app = $Link; grupo_equipe = $Grupo }
GravarNumeros $Numeros

if (-not (@(ListarConexoes) | Where-Object { $_.nome -eq $Conexao })) {
  try { Evo POST '/instance/create' @{ instanceName = $Conexao; integration = 'WHATSAPP-BAILEYS'; qrcode = $true } | Out-Null }
  catch { Aviso "Não consegui criar a conexão:`n$($_.Exception.Message)" 'Erro' 'Error'; exit 1 }
}
if (-not (MostrarQR $Conexao $Atendente)) {
  Aviso "Os dados de $Atendente foram salvos.`n`nPara conectar o celular depois, abra o painel e clique em 'Reconectar' na linha de $Atendente." 'Fica para depois'
  exit 0
}
try { LigarAoBot $Conexao } catch {
  Aviso "O WhatsApp conectou, mas não consegui ligar o número ao bot:`n$($_.Exception.Message)`n`nRode o ligar-numeros.bat." 'Quase lá' 'Warning'; exit 1
}

Aviso @"
✅ Pronto! O número de $Atendente está conectado ao bot.

Para terminar, faça isto:

1. Adicione este número no grupo "$Grupo" da equipe (é por lá que ele vai avisar quando precisar de alguém).
2. De outro celular, mande "oi" para este número e confira se $Atendente responde.
3. Confira se o link $Link abre a página do app.
"@ 'Tudo certo!'
