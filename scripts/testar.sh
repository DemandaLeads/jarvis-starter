#!/bin/bash
# Roda os testes (sem gastar crédito, sem som, sem internet). Uso: bash scripts/testar.sh
cd "$(dirname "$0")/.." || exit 1
[ -d node_modules ] || npm install --no-audit --no-fund --loglevel=error || exit 1
echo "━━ painel: markdown e escape (XSS) ━━"; node scripts/testar-painel.js || exit 1
echo; echo "━━ servidor, de ponta a ponta ━━"; node scripts/testar.js
