# ───────────────────────────────────────────────────────────────────────────
#  Jarvis · instalador guiado para Windows (o de verdade; o porteiro é o instalar.ps1 da raiz)
#
#  Primeiro ESTUDA o que o PC já tem. Depois instala só o que falta, um passo por vez,
#  perguntando antes de cada download. Pode rodar de novo: o que já está pronto ele pula,
#  e nada seu é apagado.
#
#  Salvo em UTF-8 COM BOM de propósito: sem a marca, o Windows PowerShell 5.1 lê os acentos errado.
# ───────────────────────────────────────────────────────────────────────────
param([switch]$Diagnostico, [switch]$Voz)

# 'Continue' de propósito: no PowerShell 5.1, com 'Stop', qualquer aviso que um programa externo
# escreva no stderr (o Python e o uv escrevem) vira erro fatal. Cada passo confere o próprio resultado.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = New-Object System.Text.UTF8Encoding $false     # texto com acento indo pro Python/Node chega inteiro
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$App   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # scripts\windows → raiz do app
$JH    = Join-Path $HOME '.jarvis';  if ($env:JARVIS_HOME)  { $JH = $env:JARVIS_HOME }
$PORTA = 3131;                       if ($env:JARVIS_PORTA) { $PORTA = [int]$env:JARVIS_PORTA }
$AUTO  = [bool]$env:JARVIS_AUTO      # testes: aceita a resposta padrão de toda pergunta
$NODE  = Join-Path $JH 'node\node.exe'
$NPM   = Join-Path $JH 'node\npm.cmd'
$PY    = Join-Path $JH 'voz\.venv\Scripts\python.exe'
$YTDLP = Join-Path $JH 'bin\yt-dlp.exe'
$CLAUDE_PADRAO = Join-Path $HOME '.local\bin\claude.exe'
$env:Path = (Join-Path $HOME '.local\bin') + ';' + (Join-Path $JH 'node') + ';' + $env:Path
$script:TOTAL = 7

# ── conversa ───────────────────────────────────────────────────────────────
function Passo($n, $titulo) { Write-Host ''; Write-Host "━━━ PASSO $n de $script:TOTAL · $titulo ━━━" -ForegroundColor Green; Write-Host '' }
function Ok($t)        { Write-Host '  ✓ ' -ForegroundColor Green -NoNewline; Write-Host $t }
function Aviso($t)     { Write-Host '  ! ' -ForegroundColor Yellow -NoNewline; Write-Host $t }
function Erro($t)      { Write-Host '  ✗ ' -ForegroundColor Red -NoNewline; Write-Host $t }
function Info($t)      { Write-Host "  $t" }
function DeuCerto($t)  { Write-Host '  Deu certo se: ' -ForegroundColor Green -NoNewline; Write-Host $t }
function SeErrado($t)  { Write-Host '  Se der errado: ' -ForegroundColor Yellow -NoNewline; Write-Host $t }
function Perguntar($texto, $padrao) {
  if ($AUTO) { Write-Host "  $texto [$padrao] (automático)" -ForegroundColor DarkGray; return $padrao }
  $r = Read-Host "  $texto [$padrao]"
  if ([string]::IsNullOrWhiteSpace($r)) { return $padrao }
  return $r.Trim()
}
function Sim($texto) { $r = Perguntar "$texto (S/n)" 'S'; return -not ($r -match '^[nN]') }
function Enter($texto) { if ($AUTO) { return }; if (-not $texto) { $texto = 'Aperte Enter pra continuar...' }; [void](Read-Host "  $texto") }
function Parar($msg, $comoResolver) {
  Write-Host ''; Erro $msg
  if ($comoResolver) { SeErrado $comoResolver }
  Write-Host ''; Info "Quando resolver, rode de novo: powershell -ExecutionPolicy Bypass -File `"$App\instalar.ps1`""
  exit 1
}
function Linha($status, $nome, $detalhe) {
  $marca = @{ ok = '✓'; falta = '○'; erro = '✗'; info = '·' }[$status]
  $cor = @{ ok = 'Green'; falta = 'Yellow'; erro = 'Red'; info = 'DarkGray' }[$status]
  Write-Host "  $marca " -ForegroundColor $cor -NoNewline
  Write-Host ($nome.PadRight(22)) -NoNewline
  Write-Host $detalhe -ForegroundColor DarkGray
}
function Baixar($url, $destino) {
  & curl.exe -fL --progress-bar -o $destino $url
  if ($LASTEXITCODE -ne 0) { return $false }
  return (Test-Path $destino)
}
function Sha256($arq) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $arq).Hash.ToLower() }
function NovaPastaTemp { $t = Join-Path ([IO.Path]::GetTempPath()) ('jarvis-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Force -Path $t | Out-Null; return $t }

# ── o que existe nesta máquina ─────────────────────────────────────────────
function Achar-Claude {
  $c = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($c -and $c.Source -like '*.exe') { return $c.Source }
  if (Test-Path $CLAUDE_PADRAO) { return $CLAUDE_PADRAO }
  return $null
}
function Claude-Logado($claude) { & $claude auth status *> $null; return ($LASTEXITCODE -eq 0) }
function Node-Ok { if (-not (Test-Path $NODE)) { return $false }; $v = (& $NODE -v) -replace '^v(\d+).*', '$1'; return ([int]$v -ge 20) }
function Achar-Obsidian {
  foreach ($p in @("$env:LOCALAPPDATA\Programs\Obsidian\Obsidian.exe", "$env:LOCALAPPDATA\Obsidian\Obsidian.exe", "$env:ProgramFiles\Obsidian\Obsidian.exe")) {
    if (Test-Path $p) { return $p }
  }
  # o instalador registra onde pôs o programa
  $reg = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like 'Obsidian*' -and $_.InstallLocation } | Select-Object -First 1
  if ($reg) { $p = Join-Path $reg.InstallLocation 'Obsidian.exe'; if (Test-Path $p) { return $p } }
  return $null
}
function Voz-Instalada { if (-not (Test-Path $PY)) { return $false }; & $PY -c 'import piper' *> $null; return ($LASTEXITCODE -eq 0) }
function Achar-YtDlp { if (Test-Path $YTDLP) { return $YTDLP }; $c = Get-Command yt-dlp -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { return $c.Source }; return $null }
function Achar-Navegador {
  foreach ($p in @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")) { if (Test-Path $p) { return $p } }
  foreach ($p in @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")) { if (Test-Path $p) { return $p } }
  return $null
}
function Tem-VSCode { return [bool](Get-Command code -ErrorAction SilentlyContinue) -or (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") }
function Eh-ARM { try { return ((Get-CimInstance Win32_Processor | Select-Object -First 1).Architecture -eq 12) } catch { return $false } }
function Porta-Ocupada { return [bool](Get-NetTCPConnection -LocalPort $PORTA -State Listen -ErrorAction SilentlyContinue) }
function Config-No-Ar { try { return Invoke-RestMethod -Uri "http://127.0.0.1:$PORTA/api/config" -TimeoutSec 2 } catch { return $null } }
function Jarvis-No-Ar { $c = Config-No-Ar; return ($c -and $c.app -eq 'jarvis-starter') }
function Voz-PtBR-Windows {
  try { Add-Type -AssemblyName System.Speech; $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
        return ($s.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -eq 'pt-BR' } | Select-Object -First 1) } catch { return $null }
}
# desliga o Jarvis que estiver rodando: primeiro o vigia (senão ele religa o servidor), depois o servidor
function Parar-Jarvis {
  $alvos = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -and $_.CommandLine -like "*$JH*" -and
    ($_.CommandLine -like '*vigia.cmd*' -or $_.CommandLine -like '*iniciar.vbs*' -or $_.CommandLine -like '*server.js*' -or $_.CommandLine -like '*falar.py*') }
  $alvos | Sort-Object { if ($_.CommandLine -like '*server.js*') { 1 } else { 0 } } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 800
}

# ═══ PASSO 1 · ESTUDO DO SEU PC ════════════════════════════════════════════
function Diagnostico {
  Passo 1 'Estudo do seu PC'
  Info 'Antes de instalar qualquer coisa, vou ver o que você já tem. Isso não muda nada no seu PC.'
  Write-Host ''
  $script:PLANO = @(); $script:MB = 0; $bloqueio = $null
  $os = Get-CimInstance Win32_OperatingSystem
  $build = [int]$os.BuildNumber
  $ram = [math]::Round($os.TotalVisibleMemorySize / 1MB)
  $livre = [math]::Floor((Get-PSDrive -Name $HOME.Substring(0, 1)).Free / 1GB)
  $chip = 'Intel/AMD'; if (Eh-ARM) { $chip = 'ARM' }
  if ($build -ge 17763) { Linha ok ($os.Caption -replace 'Microsoft ', '') "$chip · $ram GB de RAM · $livre GB livres" }
  else { Linha erro ($os.Caption -replace 'Microsoft ', '') 'o Claude Code precisa do Windows 10 versão 1809 ou mais novo'; $bloqueio = 'Atualize o Windows (Configurações → Windows Update).' }
  if ($livre -lt 3) { Linha erro 'Espaço em disco' "só $livre GB livres; precisa de uns 3 GB"; if (-not $bloqueio) { $bloqueio = 'Libere uns 3 GB de espaço.' } }

  & curl.exe -sI --max-time 8 https://claude.ai *> $null
  if ($LASTEXITCODE -eq 0) { Linha ok 'Internet' 'funcionando' } else { Linha erro 'Internet' 'não consegui acessar claude.ai'; if (-not $bloqueio) { $bloqueio = 'Confira a conexão com a internet.' } }

  $claude = Achar-Claude
  if ($claude) {
    if (Claude-Logado $claude) { Linha ok 'Claude Code' ((& $claude --version | Select-Object -First 1) + ' · logado') }
    else { Linha falta 'Claude Code' 'instalado, falta fazer login'; $script:PLANO += 'login no Claude Code' }
  } else { Linha falta 'Claude Code' 'vou instalar (precisa de conta Claude Pro ou Max)'; $script:PLANO += 'Claude Code, o motor do Jarvis' }

  if (Node-Ok) { Linha ok 'Node' ((& $NODE -v) + ' · já tem') }
  else { Linha falta 'Node' 'vou pôr um só do Jarvis em .jarvis (~30 MB; não mexe no seu)'; $script:PLANO += 'Node, o que faz o painel rodar'; $script:MB += 30 }

  if (Achar-Obsidian) { Linha ok 'Obsidian' 'já tem' }
  else { Linha falta 'Obsidian' 'vou instalar (~325 MB, do site oficial)'; $script:PLANO += 'Obsidian, onde o seu Brain fica organizado'; $script:MB += 325 }

  if (Eh-ARM) { Linha info 'Voz grátis (Piper)' 'não roda em chip ARM; fica a voz do Windows' }
  elseif (Voz-Instalada) { Linha ok 'Voz grátis (Piper)' 'já tem' }
  else { Linha falta 'Voz grátis (Piper)' 'vou instalar (~110 MB, roda sem internet)'; $script:PLANO += 'a voz do Jarvis (Piper, grátis e offline)'; $script:MB += 110 }

  if (Achar-YtDlp) { Linha ok 'yt-dlp' 'já tem (card do YouTube)' }
  else { Linha falta 'yt-dlp' 'vou instalar (~17 MB, card YouTube → Brain)'; $script:PLANO += 'yt-dlp, pra transformar vídeo do YouTube em resumo'; $script:MB += 17 }

  $nav = Achar-Navegador
  if ($nav) { Linha ok 'Navegador' ((Split-Path -Leaf $nav) + ' · o microfone funciona nele') } else { Linha falta 'Navegador' 'recomendado: Google Chrome ou Microsoft Edge' }
  if (Tem-VSCode) { Linha ok 'VS Code' 'já tem' } else { Linha info 'VS Code' 'opcional' }

  if (-not (Test-Path (Join-Path $App 'jarvis.config.json'))) { $script:PLANO += 'a pasta do seu Brain, com as primeiras abas' }
  if (Jarvis-No-Ar) { Linha ok 'Jarvis' "já está no ar na porta $PORTA" }
  elseif (Porta-Ocupada) { Linha erro "Porta $PORTA" 'outro programa está usando (talvez um Jarvis antigo)'; if (-not $bloqueio) { $bloqueio = "Feche o programa que usa a porta $PORTA, ou rode com a variável JARVIS_PORTA=3132." } }
  else { $script:PLANO += 'o painel do Jarvis, que liga sozinho quando o PC liga' }

  Write-Host ''
  if ($bloqueio) { Parar 'Antes de seguir, falta uma coisa.' $bloqueio }
  if ($script:PLANO.Count) {
    Write-Host '  O que eu vou fazer:' -ForegroundColor White
    $script:PLANO | ForEach-Object { Info "  · $_" }
    if ($script:MB -gt 150) { Info "Download total: uns $script:MB MB. Tempo: 10 a 15 minutos." } elseif ($script:MB -gt 0) { Info "Download total: uns $script:MB MB. Tempo: uns 5 minutos." }
  } else { Ok 'Tudo já está instalado. Vou só conferir e deixar o Jarvis no ar.' }
}

# ═══ PASSO 2 · CLAUDE CODE ═════════════════════════════════════════════════
function Passo-Claude {
  Passo 2 'Claude Code, o motor do Jarvis'
  Info 'O Claude Code é o programa que pensa, escreve e organiza. O Jarvis é a cara dele.'
  Info 'Ele precisa de uma conta Claude paga (Pro ou Max). O plano grátis não inclui o Claude Code.'
  Write-Host ''
  $script:CLAUDE = Achar-Claude
  if (-not $script:CLAUDE) {
    if (-not (Sim 'Instalar o Claude Code agora, pelo comando oficial da Anthropic?')) { Parar 'Sem o Claude Code o Jarvis não funciona.' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command 'irm https://claude.ai/install.ps1 | iex'
    $script:CLAUDE = Achar-Claude
    if (-not $script:CLAUDE) { Parar 'O Claude Code instalou, mas não achei o claude.exe.' 'Feche o terminal, abra outro e rode o instalador de novo.' }
  }
  Ok ('Claude Code ' + (& $script:CLAUDE --version | Select-Object -First 1))
  # deixa o comando "claude" disponível em qualquer terminal novo (PATH do usuário)
  $bin = Join-Path $HOME '.local\bin'
  $pathUsuario = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $env:JARVIS_HOME -and ($pathUsuario -notlike "*$bin*")) {
    [Environment]::SetEnvironmentVariable('Path', "$bin;$pathUsuario", 'User')
    Info '(acrescentei a pasta do claude no PATH do seu usuário, pra ele funcionar em qualquer terminal)'
  }
  if ($env:JARVIS_PULAR_LOGIN) { Aviso 'login pulado (modo de teste)'; return }
  if (-not (Claude-Logado $script:CLAUDE)) {
    Write-Host ''
    Info 'Agora o login. Vai abrir o navegador: entre com a sua conta Claude e clique em Autorizar.'
    Info 'Depois volte pra cá.'
    Enter
    & $script:CLAUDE auth login
    if (-not (Claude-Logado $script:CLAUDE)) { Aviso 'Ainda não apareceu como logado. Vamos tentar mais uma vez.'; Enter; & $script:CLAUDE auth login }
    if (-not (Claude-Logado $script:CLAUDE)) { Parar 'O login no Claude Code não terminou.' 'Rode no terminal: claude auth login  e depois este instalador de novo.' }
  }
  Ok 'Logado no Claude'
  DeuCerto 'aparece ✓ Logado no Claude logo acima.'
}

# ═══ PASSO 3 · NODE ════════════════════════════════════════════════════════
function Instalar-Node {
  $arq = 'x64'; if (Eh-ARM) { $arq = 'arm64' }
  $lts = (Invoke-RestMethod https://nodejs.org/dist/index.json) | Where-Object { $_.lts } | Select-Object -First 1
  $ver = $lts.version; $nome = "node-$ver-win-$arq.zip"; $tmp = NovaPastaTemp
  Info "Baixando o Node $ver..."
  if (-not (Baixar "https://nodejs.org/dist/$ver/$nome" (Join-Path $tmp $nome))) { return $false }
  $linha = (& curl.exe -fsSL "https://nodejs.org/dist/$ver/SHASUMS256.txt") | Where-Object { $_ -match ('\s' + [regex]::Escape($nome) + '$') } | Select-Object -First 1
  $esperado = ($linha -split '\s+')[0]
  if (-not $esperado -or $esperado -ne (Sha256 (Join-Path $tmp $nome))) { Erro 'O arquivo baixado não bate com a assinatura oficial do Node. Parei por segurança.'; return $false }
  Ok 'Download conferido com a assinatura oficial (sha256)'
  Expand-Archive -Path (Join-Path $tmp $nome) -DestinationPath (Join-Path $tmp 'x') -Force
  if (Test-Path (Join-Path $JH 'node')) { Remove-Item -Recurse -Force (Join-Path $JH 'node') }
  New-Item -ItemType Directory -Force -Path $JH | Out-Null
  Move-Item (Get-ChildItem (Join-Path $tmp 'x') -Directory | Select-Object -First 1).FullName (Join-Path $JH 'node')
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  return (Node-Ok)
}
function Passo-Node {
  Passo 3 'Node, o que faz o painel rodar'
  if (-not (Node-Ok)) {
    Info 'O Node fica guardado dentro da pasta .jarvis. Não mexe em nada do resto do seu PC.'
    if (-not (Sim 'Instalar o Node?')) { Parar 'Sem o Node o painel não roda.' }
    if (-not (Instalar-Node)) { Parar 'Não consegui instalar o Node.' 'Confira a internet e rode de novo.' }
  }
  Ok ('Node ' + (& $NODE -v))
}

# ═══ PASSO 4 · VOCÊ E O SEU BRAIN ══════════════════════════════════════════
# Caminho digitado ou arrastado pro terminal: tira aspas e espaço, desfaz "~", vira absoluto
function Limpar-Caminho($c) {
  $c = ([string]$c).Trim().Trim('"').Trim("'").Trim()
  if ($c.StartsWith('~')) { $c = $HOME + $c.Substring(1) }
  if ($c -and -not [IO.Path]::IsPathRooted($c)) { $c = Join-Path $HOME $c }
  if ($c) { $c = [IO.Path]::GetFullPath($c).TrimEnd('\') }
  return $c
}
function Caminho-Problema($c) {   # devolve o motivo de recusa, ou $null se serve
  if (-not $c) { return 'caminho vazio' }
  $raiz = [IO.Path]::GetPathRoot($c).TrimEnd('\')
  foreach ($proibido in @($HOME, $raiz, (Join-Path $HOME 'Documents'), (Join-Path $HOME 'Desktop'))) {
    if ($c -ieq $proibido.TrimEnd('\')) { return "precisa ser uma pasta só do Brain, não $c" }
  }
  if ($c -ieq $JH -or $c.StartsWith($JH + '\', [StringComparison]::OrdinalIgnoreCase)) { return "dentro de $JH ele seria apagado numa atualização" }
  if ((Test-Path -LiteralPath $c) -and -not (Test-Path -LiteralPath $c -PathType Container)) { return 'já existe um arquivo com esse nome' }
  return $null
}
function Passo-Brain {
  Passo 4 'Você e o seu Brain'
  $cfg = Join-Path $App 'jarvis.config.json'; $antigoNome = ''; $antigoBrain = ''
  if (Test-Path $cfg) { try { $j = Get-Content -Raw -Encoding UTF8 $cfg | ConvertFrom-Json; $antigoNome = $j.userName; $antigoBrain = $j.brainDir } catch {} }
  $sugestao = $env:JARVIS_NOME
  if (-not $sugestao) { $sugestao = $antigoNome }
  if (-not $sugestao) { try { $sugestao = (([adsi]"WinNT://$env:COMPUTERNAME/$env:USERNAME,user").FullName -split ' ')[0] } catch {} }
  if (-not $sugestao) { $sugestao = $env:USERNAME }
  $script:NOME = ((Perguntar 'Como você quer que o Jarvis te chame?' $sugestao) -replace '["\\]', '')
  if ($script:NOME.Length -gt 40) { $script:NOME = $script:NOME.Substring(0, 40) }
  Write-Host ''
  Info 'O Brain é a pasta onde tudo vai morar: suas páginas, a memória do Jarvis e as suas abas.'
  Info 'O Obsidian abre essa mesma pasta pra você ler e editar.'
  $padrao = $env:JARVIS_BRAIN
  if (-not $padrao) { $padrao = $antigoBrain }
  if (-not $padrao) { $padrao = Join-Path $HOME "$($script:NOME) Brain" }
  $script:BRAIN = $null
  foreach ($t in 1..3) {
    $c = Limpar-Caminho (Perguntar 'Onde criar o Brain? (Enter aceita)' $padrao)
    $motivo = Caminho-Problema $c
    if (-not $motivo) { $script:BRAIN = $c; break }
    Aviso "Esse lugar não serve: $motivo"
    if ($AUTO) { break }
  }
  if (-not $script:BRAIN) { Parar 'Não consegui um lugar válido pro Brain.' 'Rode de novo e aperte Enter pra aceitar o lugar sugerido.' }
  if ($script:BRAIN -like '*OneDrive*') { Aviso 'Essa pasta fica no OneDrive. Funciona, mas peça pro OneDrive manter os arquivos "sempre neste dispositivo".' }
  New-Item -ItemType Directory -Force -Path $script:BRAIN | Out-Null
  $saida = & $NODE (Join-Path $App 'scripts\montar-brain.js') (Join-Path $App 'modelo-brain') $script:BRAIN $script:NOME pt windows 2>&1
  if ($LASTEXITCODE -ne 0) { Parar "Não consegui montar o Brain: $saida" }
  Info $saida
  Ok "Brain em: $($script:BRAIN)"
  DeuCerto 'dentro da pasta tem CLAUDE.md (o manual do Jarvis), wiki e raw.'
}

# ═══ PASSO 5 · OBSIDIAN ════════════════════════════════════════════════════
function Instalar-Obsidian {
  $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest' -Headers @{ 'User-Agent' = 'jarvis-starter' }
  $a = $rel.assets | Where-Object { $_.name -match '^Obsidian-[\d.]+\.exe$' } | Select-Object -First 1
  if (-not $a) { return $false }
  $tmp = NovaPastaTemp; $exe = Join-Path $tmp $a.name
  Info 'Baixando o Obsidian...'
  if (-not (Baixar $a.browser_download_url $exe)) { return $false }
  $sha = ([string]$a.digest) -replace '^sha256:', ''
  if ($sha) {
    if ($sha -ne (Sha256 $exe)) { Erro 'O arquivo não bate com a assinatura publicada pelo Obsidian. Parei por segurança.'; return $false }
    Ok 'Download conferido com a assinatura oficial (sha256)'
  } else { Aviso 'O Obsidian não publicou assinatura deste arquivo; segui só com o HTTPS do GitHub.' }
  Info 'Instalando (sem perguntas, só pro seu usuário)...'
  Start-Process -FilePath $exe -ArgumentList '/S' -Wait
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  return [bool](Achar-Obsidian)
}
function Esperar-Cofre {   # o Obsidian cria .obsidian dentro da pasta quando abre como cofre
  if ($AUTO) { return $false }
  for ($i = 0; $i -lt 600; $i++) {
    if (Test-Path (Join-Path $script:BRAIN '.obsidian')) { Write-Host ''; return $true }
    try { if ([Console]::KeyAvailable) { [void][Console]::ReadKey($true); Write-Host ''; return $false } } catch {}
    Start-Sleep -Seconds 1
    if ($i % 3 -eq 0) { Write-Host '.' -NoNewline -ForegroundColor DarkGray }
  }
  return $false
}
function Passo-Obsidian {
  Passo 5 'Obsidian, onde o seu Brain fica organizado'
  $obs = Achar-Obsidian
  if (-not $obs) {
    Info 'O Obsidian é grátis. Ele mostra as páginas do Brain e como elas se ligam.'
    if (Sim 'Baixar e instalar o Obsidian (~325 MB)?') {
      $okInst = $false; try { $okInst = Instalar-Obsidian } catch { $okInst = $false }
      $obs = Achar-Obsidian
      if (-not ($okInst -and $obs)) {
        Aviso 'Não consegui instalar o Obsidian agora. Sigo sem ele: o Jarvis funciona igual.'
        Aviso "Depois é só baixar em https://obsidian.md e abrir a pasta $($script:BRAIN)."
        return
      }
      Ok "Obsidian instalado em $(Split-Path -Parent $obs)"
    } else { Aviso 'Sem problema. O Jarvis funciona sem o Obsidian; dá pra instalar depois em https://obsidian.md'; return }
  } else { Ok 'Obsidian já instalado' }
  if (Test-Path (Join-Path $script:BRAIN '.obsidian')) {
    Ok 'O Obsidian já conhece o seu Brain'
    if (-not $AUTO) { Start-Process ('obsidian://open?path=' + [uri]::EscapeDataString($script:BRAIN)) }
    return
  }
  Write-Host ''
  Info 'Agora vou abrir o Obsidian. Faça assim:'
  Info '  1. Clique em "Abrir pasta como cofre" (em inglês: Open folder as vault)'
  Info "  2. Na janela que abrir, vá na sua pasta de usuário ($env:USERNAME) → $(Split-Path -Leaf $script:BRAIN) → Selecionar pasta"
  Info '  3. Se ele perguntar se confia no autor, clique em Confiar'
  Info "  (a pasta fica em: $($script:BRAIN))"
  Enter 'Aperte Enter que eu abro o Obsidian...'
  if (-not $AUTO) { Start-Process -FilePath $obs }
  Info 'Esperando você abrir a pasta no Obsidian (qualquer tecla pula)'
  if (Esperar-Cofre) { Ok 'Pronto: o Obsidian está com o seu Brain aberto' }
  else { Aviso "Pulei. Quando quiser: Obsidian → Abrir pasta como cofre → $($script:BRAIN)" }
  DeuCerto 'na esquerda do Obsidian aparecem as pastas wiki e raw.'
}

# ═══ PASSO 6 · VOZ ═════════════════════════════════════════════════════════
$FALAR_PY = Join-Path $App 'voz\falar.py'
function Wav-Piper($voz, $texto) {   # gera o áudio e devolve o caminho do wav (ou $null)
  $pedido = (@{ id = 'teste'; texto = $texto } | ConvertTo-Json -Compress)
  try { $saida = $pedido | & $PY $FALAR_PY (Join-Path $JH "voz\vozes\$voz.onnx") 2>$null } catch { return $null }
  $ultima = @($saida)[-1]
  try { $wav = ($ultima | ConvertFrom-Json).wav } catch { return $null }
  if ($wav -and (Test-Path $wav)) { return $wav }
  return $null
}
function Voz-Funciona($voz) { $w = Wav-Piper $voz 'ok'; if ($w) { Remove-Item $w -ErrorAction SilentlyContinue; return $true }; return $false }
function Baixar-Voz($voz) {   # download pela metade não passa: confere os 2 arquivos e testa uma síntese
  $pasta = Join-Path $JH 'voz\vozes'; $onnx = Join-Path $pasta "$voz.onnx"; $json = "$onnx.json"
  foreach ($t in 1..2) {
    if ((Test-Path $onnx) -and (Test-Path $json) -and (Voz-Funciona $voz)) { return $true }
    Remove-Item $onnx, $json -ErrorAction SilentlyContinue
    Info "Baixando a voz $voz (~60 MB)..."
    & $PY -m piper.download_voices --download-dir $pasta $voz *> $null
  }
  return ((Test-Path $onnx) -and (Voz-Funciona $voz))
}
function Tocar-Piper($voz, $texto) {
  $w = Wav-Piper $voz $texto; if (-not $w) { return $false }
  if (-not $env:JARVIS_SEM_SOM) { (New-Object Media.SoundPlayer $w).PlaySync() }
  Remove-Item $w -ErrorAction SilentlyContinue; return $true
}
function Tocar-Windows($texto) {
  $v = Voz-PtBR-Windows; if (-not $v) { return $false }
  if (-not $env:JARVIS_SEM_SOM) { $s = New-Object System.Speech.Synthesis.SpeechSynthesizer; $s.SelectVoice($v.VoiceInfo.Name); $s.Speak($texto) }
  return $true
}
function Sem-Piper($motivo) { Aviso "$motivo Fico com a voz do Windows e sigo. Pra tentar de novo depois: powershell -ExecutionPolicy Bypass -File `"$App\instalar.ps1`" -Voz" }
function Passo-Voz {
  Passo 6 'A voz do Jarvis'
  Info 'Falar: Piper, uma voz neural que roda no seu PC. Grátis, sem internet, sem conta, sem cobrança.'
  Info 'Ouvir: o microfone usa o reconhecimento de voz do navegador (grátis, no Chrome ou no Edge).'
  Write-Host ''
  $script:MOTOR = 'say'; $script:VOZ = 'pt_BR-faber-medium'
  if (Eh-ARM) {
    Aviso 'O Piper não tem versão pra PC com chip ARM. Fico com a voz do próprio Windows.'
  } elseif (-not (Voz-Instalada)) {
    if (Sim 'Instalar a voz grátis (~110 MB)?') {
      $uv = Get-Command uv -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $uv) {
        Info 'Instalando o uv (instala o Python da voz sem mexer no do sistema)...'
        $env:UV_NO_MODIFY_PATH = '1'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command 'irm https://astral.sh/uv/install.ps1 | iex' *> $null
        $uv = Get-Command uv -ErrorAction SilentlyContinue | Select-Object -First 1
      }
      New-Item -ItemType Directory -Force -Path (Join-Path $JH 'voz') | Out-Null
      Info 'Preparando o Python da voz...'
      if (-not $uv) { Sem-Piper 'Não consegui instalar o uv.' }
      else {
        & $uv.Source venv -q --python 3.12 (Join-Path $JH 'voz\.venv') *> $null
        if ($LASTEXITCODE -ne 0) { Sem-Piper 'Não consegui criar o ambiente da voz.' }
        else {
          & $uv.Source pip install -q --python $PY 'piper-tts==1.8.0' *> $null
          if ($LASTEXITCODE -ne 0) { Sem-Piper 'Não consegui instalar o Piper.' }
        }
      }
    } else { Aviso "Ok, fico com a voz do Windows. Dá pra trocar depois com: powershell -ExecutionPolicy Bypass -File `"$App\instalar.ps1`" -Voz" }
  }
  if ((Voz-Instalada) -and -not (Baixar-Voz $script:VOZ)) { Sem-Piper 'Não consegui baixar a voz.' }
  elseif (Voz-Instalada) {
    Info 'Vou tocar as vozes. Aumente o volume e escute.'
    Enter
    while ($true) {
      Info 'Voz 1 (Piper faber)...'
      if (-not (Tocar-Piper $script:VOZ "Olá, $($script:NOME). Eu sou a voz um. Neural, gratuita e roda no seu computador.")) { Aviso 'a voz 1 não tocou' }
      $temMaria = [bool](Voz-PtBR-Windows)
      if ($temMaria) { Info 'Voz 2 (a do Windows)...'; [void](Tocar-Windows "Olá, $($script:NOME). Eu sou a voz dois, a do próprio Windows.") }
      $r = Perguntar 'Qual você prefere? 1 = Piper · 2 = Windows · 3 = ouvir outra voz do Piper (cadu) · 4 = ouvir de novo' '1'
      if ($r -eq '2') { $script:MOTOR = 'say'; break }
      elseif ($r -eq '3') {
        if (Baixar-Voz 'pt_BR-cadu-medium') {
          [void](Tocar-Piper 'pt_BR-cadu-medium' "Olá, $($script:NOME). Eu sou a voz cadu.")
          if (Sim 'Ficar com a voz cadu?') { $script:VOZ = 'pt_BR-cadu-medium'; $script:MOTOR = 'piper'; break }
        }
      }
      elseif ($r -eq '4') { }
      else { $script:MOTOR = 'piper'; break }
    }
  }
  if ($script:MOTOR -eq 'piper') { Ok "Voz escolhida: Piper ($($script:VOZ))" } else {
    if (Voz-PtBR-Windows) { Ok 'Voz escolhida: a do Windows (português)' }
    else { Aviso 'O Windows não tem voz em português instalada: Configurações → Hora e idioma → Fala → Adicionar vozes → Português (Brasil).' }
  }
  if (-not (Achar-Navegador)) { Write-Host ''; Aviso 'Pro microfone, use o Google Chrome ou o Microsoft Edge.' }
  DeuCerto 'você ouviu a voz que escolheu.'
  SeErrado 'confira o volume e se a saída de som é a certa (ícone do alto-falante na barra de tarefas).'
}

# ═══ PASSO 7 · JARVIS NO AR ════════════════════════════════════════════════
function Instalar-YtDlp {
  $tmp = NovaPastaTemp; $base = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download'
  if (-not (Baixar "$base/yt-dlp.exe" (Join-Path $tmp 'yt-dlp.exe'))) { return $false }
  $linha = (& curl.exe -fsSL "$base/SHA2-256SUMS") | Where-Object { $_ -match '\syt-dlp\.exe$' } | Select-Object -First 1
  $esperado = ($linha -split '\s+')[0]
  if (-not $esperado -or $esperado -ne (Sha256 (Join-Path $tmp 'yt-dlp.exe'))) { Erro 'O yt-dlp baixado não bate com a assinatura oficial. Parei por segurança.'; return $false }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $YTDLP) | Out-Null
  Move-Item -Force (Join-Path $tmp 'yt-dlp.exe') $YTDLP
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  & $YTDLP --version *> $null; return ($LASTEXITCODE -eq 0)
}
function Gravar-Config {
  $nav = Achar-Navegador; if (-not $nav) { $nav = '' }
  $yt = $script:YTDLP_ACHADO; if (-not $yt) { $yt = $YTDLP }
  & $NODE (Join-Path $App 'scripts\config.js') (Join-Path $App 'jarvis.config.json') `
    "userName=$($script:NOME)" "brandName=Jarvis · $($script:NOME)" "brainDir=$($script:BRAIN)" "brainName=$(Split-Path -Leaf $script:BRAIN)" 'lang=pt' `
    "navegador=$nav" "ytdlp=$yt" "voz.motor=$($script:MOTOR)" "voz.python=$PY" "voz.modelo=$(Join-Path $JH "voz\vozes\$($script:VOZ).onnx")" 'voz.say='
}
# Liga o painel escondido e religa se ele cair (o "vigia"); entra no início do Windows pela pasta Inicializar
function Subir-Jarvis {
  New-Item -ItemType Directory -Force -Path (Join-Path $JH 'logs') | Out-Null
  Parar-Jarvis
  Remove-Item (Join-Path $App '.aberto-no-boot') -ErrorAction SilentlyContinue   # o painel abre uma vez nesta instalação
  # caminhos relativos ao próprio arquivo (%~dp0): funciona com nome de usuário com acento
  $vigia = @(
    '@echo off',
    'rem Jarvis: mantem o painel ligado e religa em 5 segundos se ele cair',
    'cd /d "%~dp0app"',
    "set PORT=$PORTA",
    ':loop',
    '"%~dp0node\node.exe" server.js >> "%~dp0logs\jarvis.log" 2>&1',
    'ping -n 6 127.0.0.1 >nul',
    'goto loop'
  )
  Set-Content -Path (Join-Path $JH 'vigia.cmd') -Value $vigia -Encoding ASCII
  $vbs = @(
    "' Jarvis: liga o vigia sem janela preta",
    'Set fso = CreateObject("Scripting.FileSystemObject")',
    'pasta = fso.GetParentFolderName(WScript.ScriptFullName)',
    'CreateObject("WScript.Shell").Run """" & pasta & "\vigia.cmd""", 0, False'
  )
  Set-Content -Path (Join-Path $JH 'iniciar.vbs') -Value $vbs -Encoding ASCII
  if (-not $env:JARVIS_SEM_AUTOINICIO) {
    $atalho = Join-Path ([Environment]::GetFolderPath('Startup')) 'Jarvis.lnk'
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut($atalho)
    $lnk.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
    $lnk.Arguments = '"' + (Join-Path $JH 'iniciar.vbs') + '"'
    $lnk.WorkingDirectory = $JH
    $lnk.Save()
  }
  Start-Process -FilePath (Join-Path $env:WINDIR 'System32\wscript.exe') -ArgumentList ('"' + (Join-Path $JH 'iniciar.vbs') + '"')
  # "no ar" só quando quem responde é a versão que acabou de ser instalada
  $esperada = (Sha256 (Join-Path $App 'server.js')).Substring(0, 12)
  for ($i = 0; $i -lt 40; $i++) { $c = Config-No-Ar; if ($c -and $c.versao -eq $esperada) { return $true }; Start-Sleep -Seconds 1 }
  return $false
}
function Passo-Jarvis {
  Passo 7 'O painel do Jarvis'
  $script:YTDLP_ACHADO = Achar-YtDlp
  if (-not $script:YTDLP_ACHADO) {
    Info 'Instalando o yt-dlp (card YouTube → Brain)...'
    $okYt = $false; try { $okYt = Instalar-YtDlp } catch { $okYt = $false }
    if ($okYt) { $script:YTDLP_ACHADO = $YTDLP; Ok 'yt-dlp instalado e conferido (sha256)' }
    else { Aviso 'O yt-dlp não instalou; o card do YouTube fica sem funcionar. Rode o instalador de novo depois.' }
  }
  Info 'Instalando as peças do painel...'
  Push-Location $App
  & $NPM install --omit=dev --no-audit --no-fund --loglevel=error *> $null
  $npmOk = ($LASTEXITCODE -eq 0)
  Pop-Location
  if (-not $npmOk) { Parar 'O npm install falhou.' "Veja o erro com: cd `"$App`"; & `"$NPM`" install" }
  Gravar-Config
  Info 'Ligando o Jarvis (e deixando ele ligar sozinho quando o PC ligar)...'
  if (-not (Subir-Jarvis)) { Parar 'O painel novo não subiu.' "Veja o motivo no fim de $JH\logs\jarvis.log" }
  Ok "Jarvis no ar: http://localhost:$PORTA"
  $b = $null; try { $b = Invoke-RestMethod "http://127.0.0.1:$PORTA/api/brain" -TimeoutSec 5 } catch {}
  if (-not ($b -and $b.legivel)) { Aviso 'O painel não está conseguindo ler o Brain. Confira se o antivírus ou o OneDrive não estão bloqueando a pasta.' }
  DeuCerto 'o navegador abriu o painel e o canto de cima diz ONLINE.'
  SeErrado "abra http://localhost:$PORTA no Chrome ou no Edge. Se não abrir, reinicie com: powershell -ExecutionPolicy Bypass -File `"$App\reiniciar.ps1`""
}

# ═══ FIM ═══════════════════════════════════════════════════════════════════
function Final {
  Write-Host ''; Write-Host "━━━ PRONTO, $($script:NOME) ━━━" -ForegroundColor Green; Write-Host ''
  Linha ok 'Claude Code' 'instalado e logado'
  Linha ok 'Brain' $script:BRAIN
  if (Test-Path (Join-Path $script:BRAIN '.obsidian')) { Linha ok 'Obsidian' 'abrindo o seu Brain' } else { Linha falta 'Obsidian' "falta abrir a pasta: Abrir pasta como cofre → $(Split-Path -Leaf $script:BRAIN)" }
  if ($script:MOTOR -eq 'piper') { Linha ok 'Voz' 'Piper, grátis e offline' } else { Linha ok 'Voz' 'a voz do Windows' }
  Linha ok 'Painel' "http://localhost:$PORTA (liga sozinho com o PC)"
  Write-Host ''
  Info 'O próximo passo é o tour guiado: ele cria as SUAS abas, testa a voz e o microfone'
  Info 'e guarda as primeiras coisas sobre você. Uma pergunta por vez.'
  Write-Host ''
  $r = Perguntar 'Onde quer fazer o tour? 1 = no painel, com voz · 2 = aqui no terminal' '1'
  if ($r -eq '2') {
    Info 'Abrindo o Claude Code no seu Brain. Pra sair depois, digite /exit.'
    if (-not $AUTO) { Set-Location -LiteralPath $script:BRAIN; & $script:CLAUDE '/primeiros-passos' }
  } else {
    Info 'No painel, clique em 🚀 Primeiros passos.'
    Info "(o painel abriu no navegador; se fechou, é só abrir http://localhost:$PORTA)"
    Write-Host ''
    Info "Amanhã: o painel já liga sozinho. Pra conversar pelo terminal: cd `"$($script:BRAIN)`"; claude --continue"
  }
}

# ═══ ORDEM ═════════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '   J A R V I S   ' -ForegroundColor Green -NoNewline; Write-Host 'instalador guiado' -ForegroundColor DarkGray
if ($Diagnostico) {
  Diagnostico; Write-Host ''; Info "Isso foi só o estudo. Pra instalar, cole o comando de instalação de novo."; Write-Host ''
} elseif ($Voz) {
  if (-not (Node-Ok) -or -not (Test-Path (Join-Path $App 'jarvis.config.json'))) { Parar 'Rode o instalador completo primeiro.' }
  $script:NOME = (Get-Content -Raw -Encoding UTF8 (Join-Path $App 'jarvis.config.json') | ConvertFrom-Json).userName
  $script:TOTAL = 6; Passo-Voz
  & $NODE (Join-Path $App 'scripts\config.js') (Join-Path $App 'jarvis.config.json') "voz.motor=$($script:MOTOR)" "voz.python=$PY" "voz.modelo=$(Join-Path $JH "voz\vozes\$($script:VOZ).onnx")"
  [void](Subir-Jarvis); Ok 'Voz trocada e Jarvis reiniciado.'
} else {
  Diagnostico
  Write-Host ''
  if (-not (Sim 'Posso começar?')) { Info 'Tudo bem. Quando quiser, cole o comando de instalação de novo.'; exit 0 }
  Passo-Claude; Passo-Node; Passo-Brain; Passo-Obsidian; Passo-Voz; Passo-Jarvis; Final
}
