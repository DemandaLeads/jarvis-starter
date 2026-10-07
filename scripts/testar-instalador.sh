#!/bin/bash
# Roda o instalador INTEIRO pelo caminho do `curl | bash`, numa caixa de areia em /tmp:
# baixa e confere de verdade o Node, o Obsidian, a voz e o yt-dlp, mas não mexe no seu ~/.jarvis,
# não cria início automático (launchd), não toca som e responde sozinho às perguntas.
# Pesado: ~450 MB de download. Uso: bash scripts/testar-instalador.sh
set -u
APP="$(cd "$(dirname "$0")/.." && pwd)"
CAIXA="${TMPDIR:-/tmp}/jarvis-caixa-$$"
PORTA="${PORTA_TESTE:-3197}"
mkdir -p "$CAIXA/apps"
tar -czf "$CAIXA/jarvis.tgz" -C "$(dirname "$APP")" --exclude node_modules --exclude .git -s "|^$(basename "$APP")|jarvis-starter-main|" "$(basename "$APP")"
cd "$CAIXA" && cat "$APP/instalar.sh" | env -u BRAIN_DIR -u WIKI_PATH \
  JARVIS_TARBALL_URL="file://$CAIXA/jarvis.tgz" JARVIS_HOME="$CAIXA/jh" JARVIS_AUTO=1 JARVIS_SEM_LAUNCHD=1 JARVIS_SEM_SOM=1 \
  JARVIS_PORTA="$PORTA" JARVIS_NOME=Teste JARVIS_BRAIN="$CAIXA/Teste Brain" \
  JARVIS_FORCAR_OBSIDIAN=1 JARVIS_APPS_DIR="$CAIXA/apps" JARVIS_FORCAR_YTDLP=1 bash
r=$?
for p in $(lsof -t -nP -iTCP:"$PORTA" -sTCP:LISTEN 2>/dev/null); do ps -o command= -p "$p" | grep -q server.js && kill "$p"; done
echo; echo "instalador terminou com código $r · caixa de areia em $CAIXA (apague quando quiser)"
exit $r
