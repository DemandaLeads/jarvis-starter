#!/bin/bash
# Remove o Jarvis (programa, Node e voz em ~/.jarvis e o início automático).
# O seu BRAIN não é apagado: as suas páginas e a memória ficam onde estão.
set -u
JH="${JARVIS_HOME:-$HOME/.jarvis}"
LABEL="com.jarvis.painel"
# trava: só apaga uma pasta própria do Jarvis, nunca a pessoal, a raiz ou algo vazio
case "$JH" in ""|"/"|"$HOME"|"$HOME/"|"$HOME/Documents"*|"$HOME/Desktop"*) echo "  Pasta do Jarvis estranha ($JH). Não removi nada."; exit 1;; esac
[ -f "$JH/app/server.js" ] || [ -d "$JH/node" ] || [ -d "$JH/voz" ] || { echo "  Não achei uma instalação do Jarvis em $JH. Não removi nada."; exit 1; }
NODE="$JH/node/bin/node"; [ -x "$NODE" ] || NODE="$(command -v node)"
BRAIN="$(cd "$JH/app" 2>/dev/null && "$NODE" -e 'try{process.stdout.write(require("./jarvis.config.json").brainDir)}catch{}' 2>/dev/null)"
echo
echo "  Isto remove o programa do Jarvis, o Node e a voz que ficam em $JH,"
echo "  e desliga o início automático. ${BRAIN:+O seu Brain em \"$BRAIN\" NÃO é apagado.}"
printf "  Remover? (s/N) "; read -r r </dev/tty || r=""
case "$r" in [sS]*) ;; *) echo "  Nada foi removido."; exit 0;; esac
launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
case "$BRAIN" in "$JH"|"$JH"/*) echo "  ⚠️  O seu Brain está DENTRO de $JH. Não apaguei nada: mova o Brain pra fora antes."; exit 1;; esac
rm -rf "$JH"
echo "  ✓ Jarvis removido. O Claude Code e o Obsidian continuam instalados (são programas separados)."
