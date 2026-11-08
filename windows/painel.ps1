# Painel do bot: ícone ao lado do relógio (verde = tudo certo, amarelo = algum número desconectado,
# vermelho = bot fora do ar), avisos quando algo cai e atalhos para tudo.
. (Join-Path $PSScriptRoot 'comum.ps1')

# Só um painel aberto por vez
$mutex = New-Object Threading.Mutex($false, 'Local\ChatbotAtacadaoPainel')
if (-not $mutex.WaitOne(0)) {
  Add-Type -AssemblyName System.Windows.Forms
  [Windows.Forms.MessageBox]::Show("O painel já está aberto.`n`nEle fica no ícone ao lado do relógio. Se não aparecer, clique na setinha ^ perto do relógio.", 'Bot do WhatsApp') | Out-Null
  exit 0
}

function Icone($cor) {
  $bmp = New-Object Drawing.Bitmap 32, 32; $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
  $g.FillEllipse((New-Object Drawing.SolidBrush $cor), 2, 2, 28, 28)
  $g.DrawString('W', (New-Object Drawing.Font('Segoe UI', 13, [Drawing.FontStyle]::Bold)), [Drawing.Brushes]::White, 4, 3); $g.Dispose()
  [Drawing.Icon]::FromHandle($bmp.GetHicon())
}
$IcVerde = Icone $Verde; $IcAmarelo = Icone ([Drawing.Color]::Orange); $IcVermelho = Icone ([Drawing.Color]::Crimson); $IcCinza = Icone ([Drawing.Color]::Gray)

function Abrir($arquivo, $extra = '') { Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSScriptRoot\$arquivo`" $extra" }

# ---------- Janela do painel ----------
$f = New-Object Windows.Forms.Form; $f.Text = 'Painel do bot do WhatsApp'; $f.Size = New-Object Drawing.Size(720, 560)
$f.StartPosition = 'CenterScreen'; $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.Font = $Fonte; $f.Icon = $IcCinza
$lStatus = New-Object Windows.Forms.Label; $lStatus.Location = New-Object Drawing.Point(15, 12); $lStatus.Size = New-Object Drawing.Size(680, 28)
$lStatus.Font = New-Object Drawing.Font('Segoe UI', 13, [Drawing.FontStyle]::Bold); $f.Controls.Add($lStatus)
$lVersao = New-Object Windows.Forms.Label; $lVersao.Location = New-Object Drawing.Point(15, 42); $lVersao.Size = New-Object Drawing.Size(680, 20)
$lVersao.ForeColor = [Drawing.Color]::DimGray; $lVersao.Font = $FontePequena; $f.Controls.Add($lVersao)

$lista = New-Object Windows.Forms.ListView; $lista.View = 'Details'; $lista.FullRowSelect = $true; $lista.MultiSelect = $false
$lista.Location = New-Object Drawing.Point(15, 70); $lista.Size = New-Object Drawing.Size(675, 250); $f.Controls.Add($lista)
foreach ($c in @(@('Número (conexão)', 160), @('Atendente', 150), @('Situação', 150), @('Grupo da equipe', 190))) { $lista.Columns.Add($c[0], $c[1]) | Out-Null }

function Botao($texto, $x, $y, $acao, $largura = 160) {
  $b = New-Object Windows.Forms.Button; $b.Text = $texto; $b.Size = New-Object Drawing.Size($largura, 38); $b.Location = New-Object Drawing.Point($x, $y)
  $b.Add_Click($acao); $f.Controls.Add($b); $b
}
$bReconectar = Botao '🔄 Reconectar número' 15 330 { ReconectarSelecionado } 200
Botao '➕ Novo número' 225 330 { Abrir 'adicionar-numero.ps1' } | Out-Null
Botao '⚙️ Configurações' 395 330 { Abrir 'configuracoes.ps1' } | Out-Null
Botao '🎥 Vídeo e imagem' 565 330 { Abrir 'configuracoes.ps1' '-Aba midia' } 125 | Out-Null
Botao '▶ Ligar bot' 15 385 { Ligar } | Out-Null
Botao '🔁 Reiniciar bot' 185 385 { Reiniciar } | Out-Null
Botao '⏹ Desligar bot' 355 385 { Desligar } | Out-Null
Botao '📄 Ver registros' 525 385 { Start-Process cmd -ArgumentList "/k `"$Pasta\logs.bat`"" } | Out-Null
$bAtualizar = Botao '⬇ Procurar atualização' 15 440 { Abrir 'atualizar.ps1' } 200
Botao '↩ Voltar versão anterior' 225 440 { VoltarVersao } 200 | Out-Null
$lDica = New-Object Windows.Forms.Label; $lDica.Text = 'Fechar esta janela não desliga o bot: ele continua no ícone ao lado do relógio.'
$lDica.Location = New-Object Drawing.Point(15, 490); $lDica.AutoSize = $true; $lDica.ForeColor = [Drawing.Color]::DimGray; $lDica.Font = $FontePequena; $f.Controls.Add($lDica)
$f.Add_FormClosing({ if ($_.CloseReason -eq 'UserClosing' -and -not $script:saindo) { $_.Cancel = $true; $f.Hide() } })

# ---------- Ícone ao lado do relógio ----------
$icone = New-Object Windows.Forms.NotifyIcon; $icone.Icon = $IcCinza; $icone.Text = 'Bot do WhatsApp: verificando...'; $icone.Visible = $true
$menu = New-Object Windows.Forms.ContextMenuStrip
function ItemMenu($texto, $acao) { $i = $menu.Items.Add($texto); $i.Add_Click($acao) }
ItemMenu 'Abrir painel' { MostrarPainel }
ItemMenu 'Novo número' { Abrir 'adicionar-numero.ps1' }
ItemMenu 'Configurações' { Abrir 'configuracoes.ps1' }
ItemMenu 'Procurar atualização' { Abrir 'atualizar.ps1' }
$menu.Items.Add('-') | Out-Null
ItemMenu 'Fechar o painel (o bot continua)' { $script:saindo = $true; $icone.Visible = $false; $f.Close(); [Windows.Forms.Application]::Exit() }
$icone.ContextMenuStrip = $menu
$icone.Add_MouseDoubleClick({ MostrarPainel })
$icone.Add_BalloonTipClicked({ MostrarPainel })
function MostrarPainel { Verificar; $f.Show(); $f.WindowState = 'Normal'; $f.Activate() }
function Notificar($titulo, $texto, $tipo = 'Warning') { $icone.ShowBalloonTip(10000, $titulo, $texto, $tipo) }

# ---------- Ações ----------
function Ligar { $lStatus.Text = 'Ligando o bot...'; $f.Refresh(); Start-Process cmd -ArgumentList "/c `"$Pasta\iniciar.bat`" painel" -WindowStyle Hidden -Wait; Verificar }
function Reiniciar { $lStatus.Text = 'Reiniciando...'; $f.Refresh(); Docker 'compose restart' -Esperar | Out-Null; Start-Sleep 10; Verificar }
function Desligar {
  if (-not (Pergunta "Desligar o bot?`n`nNinguém vai ser atendido no WhatsApp até você ligar de novo.")) { return }
  $lStatus.Text = 'Desligando...'; $f.Refresh(); Set-Content (Join-Path $Pasta '.desligado') 'desligado'; Docker 'compose down' -Esperar | Out-Null; $script:desligadoDeProposito = $true; Verificar
}
function ReconectarSelecionado {
  if (-not $lista.SelectedItems.Count) { Aviso 'Clique primeiro no número da lista que quer reconectar.' 'Escolha um número'; return }
  $nome = $lista.SelectedItems[0].Text; $d = (LerNumeros)[$nome]; $at = if ($d) { $d.atendente } else { $nome }
  try {
    if (-not (@(ListarConexoes) | Where-Object { $_.nome -eq $nome })) { Evo POST '/instance/create' @{ instanceName = $nome; integration = 'WHATSAPP-BAILEYS'; qrcode = $true } | Out-Null }
    if (MostrarQR $nome $at) { LigarAoBot $nome; Aviso "O número de $at está conectado de novo." 'Conectado' }
  } catch { Aviso "Não deu certo: $($_.Exception.Message)" 'Erro' 'Error' }
  Verificar
}
function VoltarVersao {
  $antes = Get-ChildItem (Join-Path $Pasta 'backups') -Directory -Filter 'antes-da-*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $antes) { Aviso 'Não há versão anterior guardada.' 'Voltar versão'; return }
  if (-not (Pergunta "Desfazer a última atualização ($($antes.Name -replace 'antes-da-', 'versão '))?`n`nOs seus dados (configurações, números, catálogo) não são alterados.")) { return }
  foreach ($a in Get-ChildItem $antes.FullName -Recurse -File | Where-Object { $_.Name -notmatch '^(banco-bot\.sql|instalador.*\.log)$' }) {
    $rel = $a.FullName.Substring($antes.FullName.Length + 1); Copy-Item $a.FullName (Join-Path $Pasta $rel) -Force
  }
  $env:SO_FLUXO = '1'; $env:MSYS_NO_PATHCONV = '1'; $env:PATH = "$PSScriptRoot\bin;$env:PATH"
  Start-Process (Join-Path $env:ProgramFiles 'Git\bin\bash.exe') -ArgumentList './instalar-fluxo.command' -WorkingDirectory $Pasta -WindowStyle Hidden -Wait
  Remove-Item (Join-Path $Pasta 'backups\instalado.json') -ErrorAction SilentlyContinue
  Aviso "Pronto: voltei para a versão $(VersaoLocal)." 'Versão anterior'; Verificar
}

# ---------- Verificação periódica ----------
$script:anterior = @{}; $script:falhasBot = 0
function Verificar {
  $nums = LerNumeros
  $noAr = BotNoAr
  $lista.Items.Clear()
  if (-not $noAr) {
    $script:falhasBot++
    $lStatus.Text = '🔴 Bot fora do ar'; $lStatus.ForeColor = 'Crimson'; $icone.Icon = $IcVermelho; $f.Icon = $IcVermelho; $icone.Text = 'Bot do WhatsApp: FORA DO AR'
    # Avisa na 2ª verificação seguida (evita alarme falso enquanto o Docker liga)
    if ($script:falhasBot -eq 2 -and -not $script:desligadoDeProposito) { Notificar 'Bot do WhatsApp fora do ar' 'Os clientes não estão sendo atendidos. Clique para abrir o painel e ligar.' 'Error' }
    return
  }
  $script:falhasBot = 0; $script:desligadoDeProposito = $false
  $conexoes = @(ListarConexoes); $caidos = @()
  foreach ($c in $conexoes) {
    $d = $nums[$c.nome]; $at = if ($d) { $d.atendente } else { '(sem cadastro)' }
    $ok = $c.estado -eq 'open'
    $it = New-Object Windows.Forms.ListViewItem($c.nome)
    $it.SubItems.Add($at) | Out-Null
    $it.SubItems.Add($(if ($ok) { '✅ Conectado' } elseif ($c.estado -eq 'connecting') { '⏳ Conectando' } else { '❌ Desconectado' })) | Out-Null
    $it.SubItems.Add($(if ($d) { $d.grupo_equipe } else { '' })) | Out-Null
    if (-not $ok) { $it.ForeColor = 'Crimson'; $caidos += $at }
    $lista.Items.Add($it) | Out-Null
    if ($script:anterior[$c.nome] -eq 'open' -and -not $ok) { Notificar "WhatsApp de $at desconectou" 'Clique para abrir o painel e reconectar (vai pedir o QR Code).' }
    $script:anterior[$c.nome] = $c.estado
  }
  if ($caidos) {
    $lStatus.Text = "🟡 Bot no ar, mas $($caidos.Count) número(s) desconectado(s)"; $lStatus.ForeColor = 'DarkOrange'
    $icone.Icon = $IcAmarelo; $f.Icon = $IcAmarelo; $icone.Text = "Bot: $($caidos.Count) número(s) desconectado(s)"
  } elseif (-not $conexoes) {
    $lStatus.Text = '🟡 Bot no ar, sem nenhum número conectado'; $lStatus.ForeColor = 'DarkOrange'; $icone.Icon = $IcAmarelo; $f.Icon = $IcAmarelo; $icone.Text = 'Bot: nenhum número conectado'
  } else {
    $lStatus.Text = "🟢 Tudo funcionando — $($conexoes.Count) número(s) conectado(s)"; $lStatus.ForeColor = 'Green'
    $icone.Icon = $IcVerde; $f.Icon = $IcVerde; $icone.Text = 'Bot do WhatsApp: tudo funcionando'
  }
  $cfg = LerJson $ArqConfig
  $lVersao.Text = "Versão $(VersaoLocal)$(if ($script:temAtualizacao) { '  •  ⬇ ATUALIZAÇÃO DISPONÍVEL' })$(if ($cfg.modo_teste) { '  •  ⚠ MODO TESTE LIGADO' })"
}
function ProcurarAtualizacao {
  $p = Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSScriptRoot\atualizar.ps1`" -Verificar" -WindowStyle Hidden -Wait -PassThru
  if ($p.ExitCode -eq 10 -and -not $script:temAtualizacao) {
    $script:temAtualizacao = $true; $bAtualizar.BackColor = $Verde; $bAtualizar.ForeColor = 'White'
    Notificar 'Atualização do bot disponível' 'Abra o painel e clique em "Procurar atualização" para instalar.' 'Info'
  }
}

$timer = New-Object Windows.Forms.Timer; $timer.Interval = 60000; $timer.Add_Tick({ try { Verificar } catch {} })
$script:ultimaBusca = [DateTime]::MinValue
$timerAtualizacao = New-Object Windows.Forms.Timer; $timerAtualizacao.Interval = 600000
$timerAtualizacao.Add_Tick({ if (((Get-Date) - $script:ultimaBusca).TotalHours -ge 6) { $script:ultimaBusca = Get-Date; try { ProcurarAtualizacao } catch {} } })
try { Verificar } catch {}
$timer.Start(); $timerAtualizacao.Start()
[Windows.Forms.Application]::Run()
$icone.Visible = $false
