# Jarvis - instalador guiado para Windows
#
#   Cole no terminal do VS Code (menu Terminal > Novo Terminal, que no Windows ja e o PowerShell):
#     irm https://raw.githubusercontent.com/DemandaLeads/jarvis-starter/main/instalar.ps1 | iex
#
# Este arquivo e so o "porteiro": baixa o Jarvis e chama o instalador de verdade
# (scripts\windows\instalador.ps1), que conversa em portugues.
# Ele fica so em ASCII de proposito: roda pelo "irm | iex", dentro do terminal da pessoa, e por
# isso tambem nunca usa "exit" (fecharia a janela dela).
#
#   Rodar de novo (conserta, atualiza, nao apaga nada):  cole o mesmo comando
#   So o estudo do PC:   powershell -ExecutionPolicy Bypass -File "$HOME\.jarvis\app\instalar.ps1" -Diagnostico
#   Trocar a voz:        powershell -ExecutionPolicy Bypass -File "$HOME\.jarvis\app\instalar.ps1" -Voz
param([switch]$Diagnostico, [switch]$Voz)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Repo = 'DemandaLeads/jarvis-starter'; if ($env:JARVIS_REPO) { $Repo = $env:JARVIS_REPO }
$Ramo = 'main';                        if ($env:JARVIS_RAMO) { $Ramo = $env:JARVIS_RAMO }
$JH = Join-Path $HOME '.jarvis';       if ($env:JARVIS_HOME) { $JH = $env:JARVIS_HOME }
$App = Join-Path $JH 'app'

# desliga um Jarvis que esteja rodando: o Windows nao deixa trocar a pasta de um programa em uso
function Parar-Jarvis {
  $alvos = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -and $_.CommandLine -like "*$JH*" -and
    ($_.CommandLine -like '*vigia.cmd*' -or $_.CommandLine -like '*iniciar.vbs*' -or $_.CommandLine -like '*server.js*' -or $_.CommandLine -like '*falar.py*')
  }
  # primeiro o vigia (senao ele religa o servidor), depois o servidor
  $alvos | Sort-Object { if ($_.CommandLine -like '*server.js*') { 1 } else { 0 } } | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
  }
  Start-Sleep -Milliseconds 800
}

$aqui = ''; if ($PSCommandPath) { $aqui = Split-Path -Parent $PSCommandPath }
$real = ''; if ($aqui) { $real = Join-Path $aqui 'scripts\windows\instalador.ps1' }
$local = $aqui -and (Test-Path $real) -and (Test-Path (Join-Path $aqui 'server.js'))

if (-not $local) {
  # veio pelo "irm | iex": baixa o Jarvis (zip do GitHub) e roda a copia local
  Write-Host ''
  Write-Host '  Baixando o Jarvis...'
  New-Item -ItemType Directory -Force -Path $JH | Out-Null
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('jarvis-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $zipUrl = "https://codeload.github.com/$Repo/zip/refs/heads/$Ramo"
  if ($env:JARVIS_ZIP_URL) { $zipUrl = $env:JARVIS_ZIP_URL }
  & curl.exe -fsSL -o (Join-Path $tmp 'jarvis.zip') $zipUrl
  if ($LASTEXITCODE -ne 0) { Write-Host '  Nao consegui baixar o Jarvis. Confira a internet e tente de novo.'; return }
  Expand-Archive -Path (Join-Path $tmp 'jarvis.zip') -DestinationPath (Join-Path $tmp 'x') -Force
  $novo = Get-ChildItem (Join-Path $tmp 'x') -Directory | Select-Object -First 1
  # uma instalacao anterior guarda o config, a senha do email e a fila: tudo isso vem junto
  foreach ($f in @('jarvis.config.json', '.env', '.pending-emails.json', '.jarvis-session-id')) {
    $velho = Join-Path $App $f
    if (Test-Path $velho) { Copy-Item $velho (Join-Path $novo.FullName $f) -Force }
  }
  Parar-Jarvis
  if (Test-Path $App) { Remove-Item -Recurse -Force $App }
  Move-Item $novo.FullName $App
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  $real = Join-Path $App 'scripts\windows\instalador.ps1'
}

$argsReal = @()
if ($Diagnostico) { $argsReal += '-Diagnostico' }
if ($Voz) { $argsReal += '-Voz' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $real @argsReal
