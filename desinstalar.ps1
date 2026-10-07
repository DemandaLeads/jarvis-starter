# Remove o Jarvis no Windows (programa, Node e voz em .jarvis, e o início automático).
# O seu BRAIN não é apagado: as suas páginas e a memória ficam onde estão.
#   powershell -ExecutionPolicy Bypass -File "$HOME\.jarvis\app\desinstalar.ps1"
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$JH = Join-Path $HOME '.jarvis'; if ($env:JARVIS_HOME) { $JH = $env:JARVIS_HOME }
$jhN = [IO.Path]::GetFullPath($JH).TrimEnd('\')
# trava: só apaga uma pasta própria do Jarvis, nunca a pessoal, a raiz ou Documentos/Área de trabalho
foreach ($p in @($HOME, [IO.Path]::GetPathRoot($jhN), (Join-Path $HOME 'Documents'), (Join-Path $HOME 'Desktop'))) {
  if ($jhN -ieq ([string]$p).TrimEnd('\')) { Write-Host "  Pasta do Jarvis estranha ($JH). Não removi nada."; exit 1 }
}
if (-not ((Test-Path "$JH\app\server.js") -or (Test-Path "$JH\node") -or (Test-Path "$JH\voz"))) { Write-Host "  Não achei uma instalação do Jarvis em $JH. Não removi nada."; exit 1 }
$brain = ''; try { $brain = (Get-Content -Raw -Encoding UTF8 "$JH\app\jarvis.config.json" | ConvertFrom-Json).brainDir } catch {}
Write-Host ''
Write-Host "  Isto remove o programa do Jarvis, o Node e a voz que ficam em $JH,"
Write-Host '  e desliga o início automático.'
if ($brain) { Write-Host "  O seu Brain em `"$brain`" NÃO é apagado." }
if ($env:JARVIS_AUTO) { $r = 's' } else { $r = Read-Host '  Remover? (s/N)' }
if ($r -notmatch '^[sS]') { Write-Host '  Nada foi removido.'; exit 0 }
if ($brain) {
  $bN = [IO.Path]::GetFullPath($brain).TrimEnd('\')
  if ($bN -ieq $jhN -or $bN.StartsWith($jhN + '\', [StringComparison]::OrdinalIgnoreCase)) { Write-Host "  ⚠️  O seu Brain está DENTRO de $JH. Não apaguei nada: mova o Brain pra fora antes."; exit 1 }
}
# para o vigia, o servidor e a voz (no Windows, matar o pai não mata os filhos)
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*$JH*" -and
  ($_.CommandLine -like '*vigia.cmd*' -or $_.CommandLine -like '*iniciar.vbs*' -or $_.CommandLine -like '*server.js*' -or $_.CommandLine -like '*falar.py*') } |
  Sort-Object { if ($_.CommandLine -like '*vigia.cmd*') { 0 } else { 1 } } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'Jarvis.lnk') -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Remove-Item -Recurse -Force $JH -ErrorAction SilentlyContinue
if (Test-Path $JH) { Write-Host "  ✗ Algum arquivo de $JH está em uso. Feche o painel no navegador e rode de novo."; exit 1 }
Write-Host '  ✓ Jarvis removido. O Claude Code e o Obsidian continuam instalados (são programas separados).'
