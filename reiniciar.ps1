# Jarvis: reinicia o painel no Windows. O "vigia" religa o servidor sozinho em uns 5 segundos.
#   powershell -ExecutionPolicy Bypass -File "$HOME\.jarvis\app\reiniciar.ps1"
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$JH = Join-Path $HOME '.jarvis'; if ($env:JARVIS_HOME) { $JH = $env:JARVIS_HOME }
$PORTA = 3131; if ($env:JARVIS_PORTA) { $PORTA = [int]$env:JARVIS_PORTA }
$meus = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*$JH*" }
$vigia = $meus | Where-Object { $_.CommandLine -like '*vigia.cmd*' }
$meus | Where-Object { $_.CommandLine -like '*server.js*' -or $_.CommandLine -like '*falar.py*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
if (-not $vigia) { Start-Process -FilePath (Join-Path $env:WINDIR 'System32\wscript.exe') -ArgumentList ('"' + (Join-Path $JH 'iniciar.vbs') + '"') }
Write-Host '  Reiniciando o Jarvis...'
Start-Sleep -Seconds 2
for ($i = 0; $i -lt 30; $i++) {
  try { $c = Invoke-RestMethod "http://127.0.0.1:$PORTA/api/config" -TimeoutSec 2; if ($c.app -eq 'jarvis-starter') { Write-Host "  ✓ Jarvis no ar: http://localhost:$PORTA"; exit 0 } } catch {}
  Start-Sleep -Seconds 1
}
Write-Host "  ✗ O painel não voltou. Veja o fim de $JH\logs\jarvis.log"
exit 1
