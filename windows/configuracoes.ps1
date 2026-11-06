# Janela de configurações do bot: dados da loja, modo teste, números/atendentes e vídeo/imagem do catálogo.
param([string]$Aba = '')
. (Join-Path $PSScriptRoot 'comum.ps1')

$Config = LerJson $ArqConfig
function Cfg($nome) { $v = $Config.$nome; if ($null -eq $v) { '' } else { $v } }

$f = New-Object Windows.Forms.Form
$f.Text = 'Configurações do bot'; $f.Size = New-Object Drawing.Size(720, 640); $f.StartPosition = 'CenterScreen'
$f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.Font = $Fonte
$abas = New-Object Windows.Forms.TabControl; $abas.Location = New-Object Drawing.Point(10, 10); $abas.Size = New-Object Drawing.Size(685, 580); $f.Controls.Add($abas)

function NovaAba($titulo) { $t = New-Object Windows.Forms.TabPage; $t.Text = $titulo; $t.AutoScroll = $true; $abas.TabPages.Add($t); $t }
function Rotulo($aba, $texto, $x, $y, $negrito = $false, $cinza = $false) {
  $l = New-Object Windows.Forms.Label; $l.Text = $texto; $l.Location = New-Object Drawing.Point($x, $y); $l.AutoSize = $true
  if ($negrito) { $l.Font = $FonteNegrito }; if ($cinza) { $l.ForeColor = [Drawing.Color]::DimGray; $l.Font = $FontePequena }
  $aba.Controls.Add($l); $l
}
function Caixa($aba, $valor, $x, $y, $largura = 380) {
  $t = New-Object Windows.Forms.TextBox; $t.Text = $valor; $t.Location = New-Object Drawing.Point($x, $y); $t.Size = New-Object Drawing.Size($largura, 26); $aba.Controls.Add($t); $t
}

# ================= Aba 1: Geral =================
$g = NovaAba 'Geral'
$campos = [ordered]@{
  nome_loja = 'Nome da loja'; link_app = 'Link do app (padrão)'; cnpj_loja = 'CNPJ da loja'; endereco_matriz = 'Endereço da matriz'
  instagram = 'Instagram (link)'; site = 'Site (link)'; grupo_equipe = 'Grupo da equipe (padrão)'; link_video = 'Link do vídeo (reserva)'
}
$caixas = @{}; $y = 15
foreach ($k in $campos.Keys) {
  Rotulo $g $campos[$k] 15 ($y + 4) | Out-Null
  $caixas[$k] = Caixa $g (Cfg $k) 250 $y 400
  $y += 36
}
Rotulo $g 'Tempo de pausa (minutos)' 15 ($y + 4) | Out-Null
$pausa = New-Object Windows.Forms.NumericUpDown; $pausa.Minimum = 5; $pausa.Maximum = 600; $pausa.Value = [Math]::Max(5, [int](Cfg 'pausa_minutos'))
$pausa.Location = New-Object Drawing.Point(250, $y); $pausa.Width = 80; $g.Controls.Add($pausa)
Rotulo $g 'Quanto tempo o bot fica calado depois que alguém da equipe responde.' 340 ($y + 6) $false $true | Out-Null
$y += 45

$modo = New-Object Windows.Forms.CheckBox; $modo.Text = 'MODO TESTE ligado'; $modo.Font = $FonteNegrito; $modo.AutoSize = $true
$modo.Location = New-Object Drawing.Point(15, $y); $modo.Checked = [bool](Cfg 'modo_teste'); $g.Controls.Add($modo)
$explica = Rotulo $g '' 15 ($y + 28) $false $true
function AtualizaModo {
  if ($modo.Checked) { $modo.ForeColor = [Drawing.Color]::DarkOrange; $explica.Text = 'Respostas rápidas e comandos de teste (#reset) liberados. DESLIGUE antes de atender clientes de verdade.' }
  else { $modo.ForeColor = [Drawing.Color]::Green; $explica.Text = 'Bot em produção: atendendo clientes de verdade.' }
}
$modo.Add_CheckedChanged({ AtualizaModo }); AtualizaModo
$y += 60
Rotulo $g 'Números de teste (um por linha, com DDI e DDD, ex.: 5547999998888)' 15 $y | Out-Null
$testes = New-Object Windows.Forms.TextBox; $testes.Multiline = $true; $testes.ScrollBars = 'Vertical'
$testes.Location = New-Object Drawing.Point(15, ($y + 24)); $testes.Size = New-Object Drawing.Size(300, 70)
$testes.Text = (@($Config.numeros_teste) -join "`r`n"); $g.Controls.Add($testes)

$salvar = New-Object Windows.Forms.Button; $salvar.Text = 'Salvar'; $salvar.Size = New-Object Drawing.Size(140, 38)
$salvar.Location = New-Object Drawing.Point(510, ($y + 55)); $salvar.BackColor = $Verde; $salvar.ForeColor = 'White'; $salvar.FlatStyle = 'Flat'; $g.Controls.Add($salvar)
$salvar.Add_Click({
  foreach ($k in $campos.Keys) {
    $v = $caixas[$k].Text.Trim()
    if ($k -in 'link_app', 'link_video', 'instagram', 'site' -and $v -and $v -notmatch '^https?://\S+$') { Aviso "O campo '$($campos[$k])' precisa ser um link começando com https://." 'Confira' 'Warning'; return }
    $Config | Add-Member -NotePropertyName $k -NotePropertyValue $v -Force
  }
  $nums = @($testes.Text -split "`r?`n" | ForEach-Object { ($_ -replace '\D', '') } | Where-Object { $_.Length -ge 10 })
  $Config | Add-Member -NotePropertyName pausa_minutos -NotePropertyValue ([int]$pausa.Value) -Force
  $Config | Add-Member -NotePropertyName modo_teste -NotePropertyValue $modo.Checked -Force
  $Config | Add-Member -NotePropertyName numeros_teste -NotePropertyValue $nums -Force
  if (-not $modo.Checked -and ((Cfg 'link_app') -match 'example\.com')) { Aviso 'Atenção: o link do app ainda é o provisório (example.com).' 'Confira' 'Warning' }
  GravarJson $ArqConfig $Config
  Aviso 'Configurações salvas. Já valem na próxima mensagem.' 'Salvo'
})

# ================= Aba 2: Números =================
$n = NovaAba 'Números e atendentes'
$lista = New-Object Windows.Forms.ListView; $lista.View = 'Details'; $lista.FullRowSelect = $true; $lista.MultiSelect = $false
$lista.Location = New-Object Drawing.Point(15, 15); $lista.Size = New-Object Drawing.Size(645, 420); $n.Controls.Add($lista)
foreach ($c in @(@('Conexão', 120), @('Atendente', 110), @('Situação', 110), @('Grupo', 110), @('Link do app', 190))) { $lista.Columns.Add($c[0], $c[1]) | Out-Null }

function CarregaLista {
  $lista.Items.Clear()
  $nums = LerNumeros
  $estados = @{}; try { foreach ($c in ListarConexoes) { $estados[$c.nome] = $c.estado } } catch {}
  $nomes = @($nums.Keys | Where-Object { $_ -ne '_LEIA' }) + @($estados.Keys | Where-Object { -not $nums.Contains($_) })
  foreach ($nome in $nomes) {
    $d = $nums[$nome]
    $sit = switch ($estados[$nome]) { 'open' { '✅ Conectado' } $null { '➖ Não criado' } default { '❌ Desconectado' } }
    $it = New-Object Windows.Forms.ListViewItem($nome)
    $it.SubItems.Add($(if ($d) { $d.atendente } else { '(sem cadastro)' })) | Out-Null
    $it.SubItems.Add($sit) | Out-Null
    $it.SubItems.Add($(if ($d) { $d.grupo_equipe } else { '' })) | Out-Null
    $it.SubItems.Add($(if ($d) { $d.link_app } else { '' })) | Out-Null
    $lista.Items.Add($it) | Out-Null
  }
}
function Selecionado { if ($lista.SelectedItems.Count) { $lista.SelectedItems[0].Text } else { Aviso 'Clique primeiro num número da lista.' 'Escolha um número'; $null } }
function Botao($aba, $texto, $x, $y, $largura = 120) { $b = New-Object Windows.Forms.Button; $b.Text = $texto; $b.Size = New-Object Drawing.Size($largura, 36); $b.Location = New-Object Drawing.Point($x, $y); $aba.Controls.Add($b); $b }

$bNovo = Botao $n '+ Novo número' 15 450 140
$bNovo.BackColor = $Verde; $bNovo.ForeColor = 'White'; $bNovo.FlatStyle = 'Flat'
$bNovo.Add_Click({ Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSScriptRoot\adicionar-numero.ps1`"" -Wait; CarregaLista })

$bEditar = Botao $n 'Editar' 165 450
$bEditar.Add_Click({
  $nome = Selecionado; if (-not $nome) { return }
  $nums = LerNumeros; $d = $nums[$nome]
  $e = New-Object Windows.Forms.Form; $e.Text = "Editar $nome"; $e.Size = New-Object Drawing.Size(520, 260); $e.StartPosition = 'CenterParent'; $e.Font = $Fonte; $e.FormBorderStyle = 'FixedDialog'
  $t1 = New-Object Windows.Forms.TextBox; $t2 = New-Object Windows.Forms.TextBox; $t3 = New-Object Windows.Forms.TextBox
  $i = 0
  foreach ($par in @(@('Atendente', $t1, $(if ($d) { $d.atendente })), @('Link do app', $t2, $(if ($d) { $d.link_app })), @('Grupo', $t3, $(if ($d) { $d.grupo_equipe } else { 'Bot Geral' })))) {
    $l = New-Object Windows.Forms.Label; $l.Text = $par[0]; $l.Location = New-Object Drawing.Point(15, (20 + $i * 40)); $l.AutoSize = $true; $e.Controls.Add($l)
    $par[1].Text = $par[2]; $par[1].Location = New-Object Drawing.Point(130, (17 + $i * 40)); $par[1].Width = 360; $e.Controls.Add($par[1]); $i++
  }
  $ok = New-Object Windows.Forms.Button; $ok.Text = 'Salvar'; $ok.Location = New-Object Drawing.Point(370, 145); $ok.Size = New-Object Drawing.Size(120, 34); $ok.DialogResult = 'OK'; $e.Controls.Add($ok); $e.AcceptButton = $ok
  if ($e.ShowDialog() -ne 'OK') { return }
  if (-not $t1.Text.Trim() -or $t2.Text.Trim() -notmatch '^https?://\S+$') { Aviso 'Preencha o atendente e um link começando com https://.' 'Confira' 'Warning'; return }
  $nums[$nome] = [ordered]@{ atendente = $t1.Text.Trim(); link_app = $t2.Text.Trim(); grupo_equipe = $t3.Text.Trim() }
  GravarNumeros $nums; CarregaLista
})

$bReconectar = Botao $n 'Reconectar' 295 450
$bReconectar.Add_Click({
  $nome = Selecionado; if (-not $nome) { return }
  $d = (LerNumeros)[$nome]; $at = if ($d) { $d.atendente } else { $nome }
  try {
    if (-not (@(ListarConexoes) | Where-Object { $_.nome -eq $nome })) { Evo POST '/instance/create' @{ instanceName = $nome; integration = 'WHATSAPP-BAILEYS'; qrcode = $true } | Out-Null }
    if (MostrarQR $nome $at) { LigarAoBot $nome; Aviso "O número de $at está conectado de novo." 'Conectado' }
  } catch { Aviso "Não deu certo: $($_.Exception.Message)" 'Erro' 'Error' }
  CarregaLista
})

$bRemover = Botao $n 'Remover' 425 450
$bRemover.Add_Click({
  $nome = Selecionado; if (-not $nome) { return }
  if (-not (Pergunta "Remover o número '$nome'?`n`nEle será desconectado do WhatsApp e sai do bot. As conversas antigas continuam guardadas.")) { return }
  $u = [Uri]::EscapeDataString($nome)
  try { Evo DELETE "/instance/logout/$u" | Out-Null } catch {}
  try { Evo DELETE "/instance/delete/$u" | Out-Null } catch {}
  $nums = LerNumeros; if ($nums.Contains($nome)) { $nums.Remove($nome) }; GravarNumeros $nums
  CarregaLista
})
$bAtualizar = Botao $n 'Atualizar lista' 555 450 105
$bAtualizar.Add_Click({ CarregaLista })
Rotulo $n 'Dica: depois de conectar, adicione o número no grupo da equipe dele.' 15 500 $false $true | Out-Null

# ================= Aba 3: Vídeo e imagem =================
$m = NovaAba 'Vídeo e imagem'
$ArqVideo = Join-Path $PastaCatalogo ((Cfg 'video_instalacao'), 'video-instalacao.mp4' | Where-Object { $_ } | Select-Object -First 1)
$ArqImagem = Join-Path $PastaCatalogo 'catalogo-imagem.jpg'
$PastaBackupMidia = Join-Path $Pasta 'backups\midia'

Rotulo $m 'Vídeo de como instalar o app' 15 15 $true | Out-Null
$infoVideo = Rotulo $m '' 15 42 $false $true
Rotulo $m 'Aceita qualquer vídeo (inclusive .MOV do iPhone). Ele é convertido para um formato que abre em qualquer celular.' 15 66 $false $true | Out-Null
$bVideo = Botao $m 'Escolher vídeo...' 15 92 170

Rotulo $m 'Imagem do catálogo' 15 160 $true | Out-Null
$infoImg = Rotulo $m '' 15 187 $false $true
$preview = New-Object Windows.Forms.PictureBox; $preview.Location = New-Object Drawing.Point(15, 255); $preview.Size = New-Object Drawing.Size(220, 280); $preview.SizeMode = 'Zoom'; $preview.BorderStyle = 'FixedSingle'; $m.Controls.Add($preview)
$bImg = Botao $m 'Escolher imagem...' 15 212 170
$status = Rotulo $m '' 260 255

function InfoMidia {
  $infoVideo.Text = if (Test-Path $ArqVideo) { "Atual: $(Split-Path $ArqVideo -Leaf) — $([Math]::Round((Get-Item $ArqVideo).Length / 1MB, 1)) MB, trocado em $((Get-Item $ArqVideo).LastWriteTime.ToString('dd/MM/yyyy HH:mm'))" } else { 'Nenhum vídeo na pasta (o bot manda o link do vídeo no lugar).' }
  if (Test-Path $ArqImagem) {
    $infoImg.Text = "Atual: catalogo-imagem.jpg — trocada em $((Get-Item $ArqImagem).LastWriteTime.ToString('dd/MM/yyyy HH:mm'))"
    $bytes = [IO.File]::ReadAllBytes($ArqImagem); $preview.Image = [Drawing.Image]::FromStream((New-Object IO.MemoryStream (, $bytes)))
  } else { $infoImg.Text = 'Nenhuma imagem na pasta.' }
}
function GuardarCopia($arq) {
  if (Test-Path $arq) { New-Item -ItemType Directory -Force $PastaBackupMidia | Out-Null; Copy-Item $arq (Join-Path $PastaBackupMidia ("$(Get-Date -Format 'yyyy-MM-dd_HHmm')_" + (Split-Path $arq -Leaf))) }
}

$bVideo.Add_Click({
  $d = New-Object Windows.Forms.OpenFileDialog; $d.Title = 'Escolha o vídeo de como instalar o app'
  $d.Filter = 'Vídeos|*.mp4;*.mov;*.m4v;*.avi;*.mkv;*.3gp;*.webm|Todos os arquivos|*.*'
  if ($d.ShowDialog() -ne 'OK') { return }
  $status.Text = "Convertendo o vídeo...`nPode levar 1 ou 2 minutos (na primeira vez, um pouco mais)."; $f.Cursor = 'WaitCursor'; $m.Enabled = $false; $f.Refresh()
  $saida = Join-Path $env:TEMP 'video-instalacao-novo.mp4'; Remove-Item $saida -ErrorAction SilentlyContinue
  $filtros = '-vf "scale=720:-2,fps=30" -c:v libx264 -preset veryfast -crf 26 -profile:v main -pix_fmt yuv420p -c:a aac -b:a 64k -ac 1 -movflags +faststart'
  $ff = Get-Command ffmpeg -ErrorAction SilentlyContinue
  if ($ff) {
    $p = Start-Process $ff.Source -ArgumentList "-y -loglevel error -i `"$($d.FileName)`" $filtros `"$saida`"" -WindowStyle Hidden -Wait -PassThru
  } else {
    # Sem ffmpeg no Windows: usa o ffmpeg dentro do Docker
    $dir = Split-Path $d.FileName; $nome = Split-Path $d.FileName -Leaf
    $p = Start-Process docker -ArgumentList "run --rm -v `"$($dir):/entrada`" -v `"$($env:TEMP):/saida`" jrottenberg/ffmpeg:6.1-ubuntu -y -loglevel error -i `"/entrada/$nome`" $filtros /saida/video-instalacao-novo.mp4" -WindowStyle Hidden -Wait -PassThru
  }
  $f.Cursor = 'Default'; $m.Enabled = $true
  if ($p.ExitCode -ne 0 -or -not (Test-Path $saida) -or (Get-Item $saida).Length -lt 10KB) { $status.Text = ''; Aviso 'Não consegui converter esse vídeo. Tente outro arquivo (de preferência .mp4 ou .mov).' 'Erro' 'Error'; return }
  $mb = [Math]::Round((Get-Item $saida).Length / 1MB, 1)
  if ($mb -gt 15 -and -not (Pergunta "O vídeo ficou com $mb MB. Vídeos grandes demoram para chegar no celular do cliente. Usar mesmo assim?")) { $status.Text = ''; return }
  GuardarCopia $ArqVideo
  Copy-Item $saida $ArqVideo -Force
  $Config | Add-Member -NotePropertyName video_instalacao -NotePropertyValue (Split-Path $ArqVideo -Leaf) -Force; GravarJson $ArqConfig $Config
  $status.Text = "✅ Vídeo trocado ($mb MB).`nJá vale para os próximos clientes."; InfoMidia
})

$bImg.Add_Click({
  $d = New-Object Windows.Forms.OpenFileDialog; $d.Title = 'Escolha a imagem do catálogo'; $d.Filter = 'Imagens|*.jpg;*.jpeg;*.png;*.webp;*.bmp|Todos os arquivos|*.*'
  if ($d.ShowDialog() -ne 'OK') { return }
  try {
    $orig = [Drawing.Image]::FromFile($d.FileName)
    # Limita a 1600 px no lado maior e salva em JPG (chega rápido e com boa leitura no WhatsApp)
    $esc = [Math]::Min(1, 1600 / [Math]::Max($orig.Width, $orig.Height))
    $w = [int]($orig.Width * $esc); $h = [int]($orig.Height * $esc)
    $nova = New-Object Drawing.Bitmap $w, $h; $gr = [Drawing.Graphics]::FromImage($nova)
    $gr.Clear([Drawing.Color]::White); $gr.InterpolationMode = 'HighQualityBicubic'; $gr.DrawImage($orig, 0, 0, $w, $h); $gr.Dispose(); $orig.Dispose()
    $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $par = New-Object Drawing.Imaging.EncoderParameters 1; $par.Param[0] = New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality, [long]85)
    $tmp = Join-Path $env:TEMP 'catalogo-imagem-nova.jpg'; $nova.Save($tmp, $codec, $par); $nova.Dispose()
    if ($preview.Image) { $preview.Image.Dispose(); $preview.Image = $null }
    GuardarCopia $ArqImagem; Copy-Item $tmp $ArqImagem -Force
    $status.Text = "✅ Imagem do catálogo trocada.`nJá vale para os próximos clientes."; InfoMidia
  } catch { Aviso "Não consegui usar essa imagem: $($_.Exception.Message)" 'Erro' 'Error' }
})

$f.Add_Shown({
  InfoMidia
  try { CarregaLista } catch {}
  switch ($Aba) { 'numeros' { $abas.SelectedIndex = 1 } 'midia' { $abas.SelectedIndex = 2 } }
})
[void]$f.ShowDialog()
