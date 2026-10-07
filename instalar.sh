#!/bin/bash
# ───────────────────────────────────────────────────────────────────────────
#  Jarvis · instalador guiado para Mac
#
#  Cole no terminal (VS Code: menu Terminal → Novo Terminal):
#    curl -fsSL https://raw.githubusercontent.com/DemandaLeads/jarvis-starter/main/instalar.sh | bash
#
#  Primeiro ele ESTUDA o que o seu Mac já tem. Depois instala só o que falta,
#  um passo por vez, perguntando antes de cada download. Pode rodar de novo
#  quantas vezes quiser: o que já está pronto ele pula, e nada seu é apagado.
#
#    bash instalar.sh                só o estudo do Mac:  bash instalar.sh --diagnostico
#    trocar a voz:                   bash instalar.sh --voz
# ───────────────────────────────────────────────────────────────────────────
set -u

REPO="${JARVIS_REPO:-DemandaLeads/jarvis-starter}"
RAMO="${JARVIS_RAMO:-main}"
JH="${JARVIS_HOME:-$HOME/.jarvis}"
PORTA="${JARVIS_PORTA:-3131}"
AUTO="${JARVIS_AUTO:-}"          # testes: aceita a resposta padrão de toda pergunta
LABEL="com.jarvis.painel"
MODO="completo"
case "${1:-}" in --diagnostico) MODO="diagnostico";; --voz) MODO="voz";; esac

if [ -t 1 ]; then B=$'\033[1m'; D=$'\033[2m'; V=$'\033[32m'; A=$'\033[33m'; R=$'\033[31m'; L=$'\033[38;5;154m'; N=$'\033[0m'
else B=""; D=""; V=""; A=""; R=""; L=""; N=""; fi

# ── conversa ───────────────────────────────────────────────────────────────
TOTAL=7
passo()     { echo; echo "${L}${B}━━━ PASSO $1 de $TOTAL · $2 ━━━${N}"; echo; }
ok()        { echo "  ${V}✓${N} $*"; }
aviso()     { echo "  ${A}!${N} $*"; }
erro()      { echo "  ${R}✗${N} $*"; }
info()      { echo "  $*"; }
deu_certo() { echo "  ${V}Deu certo se:${N} $*"; }
se_errado() { echo "  ${A}Se der errado:${N} $*"; }
perguntar() {   # $1 pergunta · $2 resposta padrão → $REPLY
  if [ -n "$AUTO" ]; then REPLY="$2"; echo "  $1 ${D}[$2] (automático)${N}"; return; fi
  printf "  %s " "$1"; [ -n "$2" ] && printf "${D}[%s]${N} " "$2"
  IFS= read -r REPLY </dev/tty || REPLY=""
  [ -z "$REPLY" ] && REPLY="$2"
  return 0
}
sim()   { perguntar "$1 (S/n)" "S"; case "$REPLY" in [nN]*) return 1;; *) return 0;; esac; }
enter() { [ -n "$AUTO" ] && return 0; printf "  ${D}%s${N}" "${1:-Aperte Enter pra continuar...}"; read -r _ </dev/tty || true; echo; }
parar() { echo; erro "$1"; [ -n "${2:-}" ] && se_errado "$2"; echo; echo "  Quando resolver, rode de novo: ${B}bash \"${APP:-$JH/app}/instalar.sh\"${N}"; exit 1; }

# ── se veio pelo curl, baixa o Jarvis e roda a cópia local ──────────────────
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
# pelo curl não existe arquivo do script (BASH_SOURCE vazio): aí sempre baixa a versão nova
if [ ! -f "${BASH_SOURCE[0]:-}" ] || [ ! -f "$AQUI/server.js" ] || [ ! -d "$AQUI/modelo-brain" ]; then
  [ "$(uname)" = "Darwin" ] || { echo "Este instalador é para Mac."; exit 1; }
  echo; echo "  Baixando o Jarvis..."
  mkdir -p "$JH"; TMP="$(mktemp -d)"
  curl -fsSL "${JARVIS_TARBALL_URL:-https://codeload.github.com/$REPO/tar.gz/refs/heads/$RAMO}" | tar -xz -C "$TMP" \
    || { echo "  Não consegui baixar o Jarvis. Confira a internet e tente de novo."; exit 1; }
  NOVO="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)"
  # uma instalação anterior guarda o seu config, a senha do email e a fila: tudo isso vem junto
  for f in jarvis.config.json .env .pending-emails.json .jarvis-session-id; do
    [ -f "$JH/app/$f" ] && cp "$JH/app/$f" "$NOVO/"
  done
  rm -rf "$JH/app.velho"; [ -d "$JH/app" ] && mv "$JH/app" "$JH/app.velho"
  mv "$NOVO" "$JH/app" && rm -rf "$JH/app.velho" "$TMP"
  # pelo curl o teclado não está no stdin: reconecta no terminal (se houver um)
  if [ -z "$AUTO" ] && ( : </dev/tty ) 2>/dev/null; then exec bash "$JH/app/instalar.sh" "$@" </dev/tty; fi
  exec bash "$JH/app/instalar.sh" "$@"
fi
APP="$AQUI"
export PATH="$HOME/.local/bin:$JH/node/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# ── o que existe nesta máquina ─────────────────────────────────────────────
tem()           { command -v "$1" >/dev/null 2>&1; }
claude_logado() { claude auth status >/dev/null 2>&1; }
node_major()    { "$1" -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'; }
achar_node() {  # sempre o Node do próprio Jarvis: um do sistema (nvm, Homebrew) pode sumir ou mudar e derrubar o painel
  local v
  [ -x "$JH/node/bin/node" ] || return 1
  v="$(node_major "$JH/node/bin/node")"; [ -n "$v" ] && [ "$v" -ge 20 ] && { echo "$JH/node/bin/node"; return 0; }
  return 1
}
achar_obsidian() {
  local d
  [ -n "${JARVIS_FORCAR_OBSIDIAN:-}" ] && { [ -d "${JARVIS_APPS_DIR:-/x}/Obsidian.app" ] && echo "$JARVIS_APPS_DIR/Obsidian.app" && return 0; return 1; }
  for d in /Applications "$HOME/Applications"; do [ -d "$d/Obsidian.app" ] && { echo "$d/Obsidian.app"; return 0; }; done
  return 1
}
YTDLP="$JH/bin/yt-dlp"
achar_ytdlp() { [ -x "$JH/bin/yt-dlp" ] && { echo "$JH/bin/yt-dlp"; return 0; }; [ -n "${JARVIS_FORCAR_YTDLP:-}" ] && return 1; command -v yt-dlp 2>/dev/null; }
PY="$JH/voz/.venv/bin/python"
voz_instalada() { [ -x "$PY" ] && "$PY" -c "import piper" 2>/dev/null; }
tem_chrome()    { [ -d "/Applications/Google Chrome.app" ] || [ -d "$HOME/Applications/Google Chrome.app" ]; }
tem_vscode()    { [ -d "/Applications/Visual Studio Code.app" ] || tem code; }
tem_luciana()   { say -v '?' 2>/dev/null | grep -q '^Luciana'; }
porta_ocupada() { lsof -nP -iTCP:"$PORTA" -sTCP:LISTEN >/dev/null 2>&1; }
jarvis_no_ar()  { curl -s --max-time 2 "http://127.0.0.1:$PORTA/api/config" 2>/dev/null | grep -q '"app":"jarvis-starter"'; }
versao_no_ar()  { curl -s --max-time 2 "http://127.0.0.1:$PORTA/api/config" 2>/dev/null | sed -n 's/.*"versao":"\([0-9a-f]*\)".*/\1/p'; }
json_str()      { "$NODE" -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$1"; }
xml()           { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
linha() {       # status · nome · detalhe
  local m
  case "$1" in ok) m="${V}✓${N}";; falta) m="${A}○${N}";; erro) m="${R}✗${N}";; *) m="${D}·${N}";; esac
  local pad=$(( 22 - ${#2} )); [ "$pad" -lt 1 ] && pad=1   # ${#} conta letras; o printf contaria bytes (á = 2)
  printf "  %s %s%*s${D}%s${N}\n" "$m" "$2" "$pad" "" "$3"
}

# ═══ PASSO 1 · ESTUDO DO SEU MAC ═══════════════════════════════════════════
diagnostico() {
  passo 1 "Estudo do seu Mac"
  info "Antes de instalar qualquer coisa, vou ver o que você já tem. Isso não muda nada no seu Mac."
  echo
  [ "$(uname)" = "Darwin" ] || parar "Este instalador é para Mac."
  MACOS="$(sw_vers -productVersion)"; MAJ="${MACOS%%.*}"
  CHIP="Intel"; [ "$(uname -m)" = "arm64" ] && CHIP="Apple Silicon"
  RAM=$(( $(sysctl -n hw.memsize) / 1073741824 ))
  DISCO="$(df -g "$HOME" | awk 'NR==2{print $4}')"
  PLANO=""; MB=0; BLOQUEIO=""

  if [ "$MAJ" -ge 13 ]; then linha ok "macOS $MACOS" "$CHIP · $RAM GB de RAM · $DISCO GB livres"
  else linha erro "macOS $MACOS" "o Claude Code precisa do macOS 13 ou mais novo"; BLOQUEIO="Atualize o macOS (Ajustes do Sistema → Geral → Atualização de Software)."; fi
  [ "${DISCO:-0}" -lt 3 ] && { linha erro "Espaço em disco" "só $DISCO GB livres; precisa de uns 3 GB"; BLOQUEIO="${BLOQUEIO:-Libere uns 3 GB de espaço.}"; }

  if curl -sI --max-time 8 https://claude.ai >/dev/null 2>&1; then linha ok "Internet" "funcionando"
  else linha erro "Internet" "não consegui acessar claude.ai"; BLOQUEIO="${BLOQUEIO:-Confira a conexão com a internet.}"; fi

  if tem claude; then
    if claude_logado; then linha ok "Claude Code" "$(claude --version 2>/dev/null | head -1) · logado"
    else linha falta "Claude Code" "instalado, falta fazer login"; PLANO="$PLANO\n    · login no Claude Code"; fi
  else linha falta "Claude Code" "vou instalar (precisa de conta Claude Pro ou Max)"; PLANO="$PLANO\n    · Claude Code, o motor do Jarvis"; fi

  if NODE="$(achar_node)"; then linha ok "Node" "$("$NODE" -v) · já tem"
  else linha falta "Node" "vou pôr um só do Jarvis em ~/.jarvis (~50 MB; não mexe no seu)"; PLANO="$PLANO\n    · Node, o que faz o painel rodar"; MB=$((MB+50)); fi

  if OBS="$(achar_obsidian)"; then linha ok "Obsidian" "já tem"
  else linha falta "Obsidian" "vou instalar (~220 MB, do site oficial)"; PLANO="$PLANO\n    · Obsidian, onde o seu Brain fica organizado"; MB=$((MB+220)); fi

  if voz_instalada; then linha ok "Voz grátis (Piper)" "já tem"
  else linha falta "Voz grátis (Piper)" "vou instalar (~110 MB, roda sem internet)"; PLANO="$PLANO\n    · a voz do Jarvis (Piper, grátis e offline)"; MB=$((MB+110)); fi

  if achar_ytdlp >/dev/null; then linha ok "yt-dlp" "já tem (card do YouTube)"
  else linha falta "yt-dlp" "vou instalar (~35 MB, card YouTube → Brain)"; PLANO="$PLANO\n    · yt-dlp, pra transformar vídeo do YouTube em resumo"; MB=$((MB+35)); fi

  if tem_chrome; then linha ok "Google Chrome" "o microfone funciona nele"
  else linha falta "Google Chrome" "recomendado pro microfone (eu te mostro onde baixar)"; fi
  if tem_vscode; then linha ok "VS Code" "já tem"; else linha info "VS Code" "opcional"; fi

  [ -f "$APP/jarvis.config.json" ] || PLANO="$PLANO\n    · a pasta do seu Brain, com as primeiras abas"
  if jarvis_no_ar; then linha ok "Jarvis" "já está no ar na porta $PORTA"
  elif porta_ocupada; then linha erro "Porta $PORTA" "outro programa está usando (talvez um Jarvis antigo)"; BLOQUEIO="${BLOQUEIO:-Feche o programa que usa a porta $PORTA. Se for um Jarvis antigo: launchctl list | grep -i jarvis  mostra o nome; desligue com  launchctl bootout gui/\$(id -u)/<nome>. Ou rode este instalador com JARVIS_PORTA=3132.}"
  else PLANO="$PLANO\n    · o painel do Jarvis, que liga sozinho quando o Mac liga"; fi

  echo
  [ -n "$BLOQUEIO" ] && parar "Antes de seguir, falta uma coisa." "$BLOQUEIO"
  if [ -n "$PLANO" ]; then
    info "${B}O que eu vou fazer:${N}"; printf "%b\n" "$PLANO"
    if [ "$MB" -gt 150 ]; then info "Download total: uns $MB MB. Tempo: 10 a 15 minutos."
    elif [ "$MB" -gt 0 ]; then info "Download total: uns $MB MB. Tempo: uns 5 minutos."; fi
  else
    ok "Tudo já está instalado. Vou só conferir e deixar o Jarvis no ar."
  fi
}

# ═══ PASSO 2 · CLAUDE CODE ═════════════════════════════════════════════════
passo_claude() {
  passo 2 "Claude Code, o motor do Jarvis"
  info "O Claude Code é o programa que pensa, escreve e organiza. O Jarvis é a cara dele."
  info "Ele precisa de uma ${B}conta Claude paga (Pro ou Max)${N}. O plano grátis não inclui o Claude Code."
  echo
  if ! tem claude; then
    sim "Instalar o Claude Code agora, pelo comando oficial da Anthropic?" || parar "Sem o Claude Code o Jarvis não funciona."
    curl -fsSL https://claude.ai/install.sh | bash || parar "A instalação do Claude Code falhou." "Veja https://code.claude.com/docs/en/troubleshoot-install"
    export PATH="$HOME/.local/bin:$PATH"; hash -r
    tem claude || parar "O Claude Code instalou, mas não achei o comando claude." "Feche o terminal, abra outro e rode o instalador de novo."
  fi
  ok "Claude Code $(claude --version 2>/dev/null | head -1)"
  if ! claude_logado; then
    echo
    info "Agora o login. Vai abrir o navegador: entre com a sua conta Claude e clique em ${B}Autorizar${N}."
    info "Depois volte pra cá."
    enter
    claude auth login </dev/tty
    claude_logado || { aviso "Ainda não apareceu como logado. Vamos tentar mais uma vez."; enter; claude auth login </dev/tty; }
    claude_logado || parar "O login no Claude Code não terminou." "Rode no terminal: claude auth login  e depois este instalador de novo."
  fi
  ok "Logado no Claude"
  deu_certo "aparece ✓ Logado no Claude logo acima."
  if [ "$JH" = "$HOME/.jarvis" ] && ! grep -qs '.local/bin' "$HOME/.zshrc"; then
    printf '\n# Jarvis: deixa os comandos claude, uv e yt-dlp disponíveis em todo terminal\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zshrc"
    info "${D}(acrescentei ~/.local/bin no seu ~/.zshrc pra o comando claude funcionar em qualquer terminal)${N}"
  fi
}

# ═══ PASSO 3 · NODE ════════════════════════════════════════════════════════
instalar_node() {
  local arq=x64 ver f tmp esperado obtido
  [ "$(uname -m)" = "arm64" ] && arq=arm64
  ver="$(curl -fsSL https://nodejs.org/dist/index.json | tr '{' '\n' | grep -m1 '"lts":"' | sed -E 's/.*"version":"(v[0-9.]+)".*/\1/')"
  [ -n "$ver" ] || return 1
  f="node-$ver-darwin-$arq.tar.gz"; tmp="$(mktemp -d)"
  info "Baixando o Node $ver..."
  curl -fL --progress-bar -o "$tmp/$f" "https://nodejs.org/dist/$ver/$f" || return 1
  esperado="$(curl -fsSL "https://nodejs.org/dist/$ver/SHASUMS256.txt" | awk -v f="$f" '$2==f{print $1}')"
  obtido="$(shasum -a 256 "$tmp/$f" | awk '{print $1}')"
  if [ -z "$esperado" ] || [ "$esperado" != "$obtido" ]; then erro "O arquivo baixado não bate com a assinatura oficial do Node. Parei por segurança."; rm -rf "$tmp"; return 1; fi
  ok "Download conferido com a assinatura oficial (sha256)"
  rm -rf "$JH/node"; mkdir -p "$JH/node"
  tar -xzf "$tmp/$f" -C "$JH/node" --strip-components 1 || return 1
  rm -rf "$tmp"
}
passo_node() {
  passo 3 "Node, o que faz o painel rodar"
  if ! NODE="$(achar_node)"; then
    info "O Node fica guardado dentro de ~/.jarvis. Não mexe em nada do resto do seu Mac."
    sim "Instalar o Node?" || parar "Sem o Node o painel não roda."
    instalar_node || parar "Não consegui instalar o Node." "Confira a internet e rode de novo."
    NODE="$JH/node/bin/node"
  fi
  NPM="$(dirname "$NODE")/npm"
  export PATH="$(dirname "$NODE"):$PATH"
  ok "Node $("$NODE" -v)"
}

# Caminho digitado ou arrastado pro terminal: tira aspas, desfaz "\ " e "~", vira absoluto
limpar_caminho() {
  local c="$1"
  c="$(printf '%s' "$c" | sed -E "s/^[[:space:]]+|[[:space:]]+$//g; s/^'(.*)'$/\1/; s/^\"(.*)\"$/\1/; s/\\\\(.)/\1/g")"
  c="${c/#\~/$HOME}"
  case "$c" in /*) ;; "") ;; *) c="$HOME/$c";; esac
  printf '%s' "${c%/}"
}
caminho_ok() {   # recusa lugares onde o Brain seria apagado junto com o programa, ou que não são uma pasta própria
  MOTIVO=""
  case "$1" in
    "") MOTIVO="caminho vazio";;
    "/"|"$HOME"|"$HOME/Documents"|"$HOME/Desktop") MOTIVO="precisa ser uma pasta só do Brain, não $1";;
    "$JH"|"$JH"/*) MOTIVO="dentro de $JH ele seria apagado numa atualização";;
    *) [ -e "$1" ] && [ ! -d "$1" ] && MOTIVO="já existe um arquivo com esse nome";;
  esac
  [ -z "$MOTIVO" ]
}

# ═══ PASSO 4 · VOCÊ E O SEU BRAIN ══════════════════════════════════════════
passo_brain() {
  passo 4 "Você e o seu Brain"
  local antigo_nome="" antigo_brain=""
  if [ -f "$APP/jarvis.config.json" ]; then
    antigo_nome="$("$NODE" -e 'try{process.stdout.write(require(process.argv[1]).userName||"")}catch{}' "$APP/jarvis.config.json")"
    antigo_brain="$("$NODE" -e 'try{process.stdout.write(require(process.argv[1]).brainDir||"")}catch{}' "$APP/jarvis.config.json")"
  fi
  local sugestao="${JARVIS_NOME:-${antigo_nome:-$(id -F 2>/dev/null | awk '{print $1}')}}"
  perguntar "Como você quer que o Jarvis te chame?" "${sugestao:-Você}"
  NOME="$(printf '%s' "$REPLY" | tr -d '"\\' | cut -c1-40)"
  echo
  info "O ${B}Brain${N} é a pasta onde tudo vai morar: suas páginas, a memória do Jarvis e as suas abas."
  info "O Obsidian abre essa mesma pasta pra você ler e editar."
  local padrao="${JARVIS_BRAIN:-${antigo_brain:-$HOME/$NOME Brain}}" tentativa saida
  for tentativa in 1 2 3; do
    perguntar "Onde criar o Brain? (Enter aceita)" "$padrao"
    BRAIN="$(limpar_caminho "$REPLY")"
    if caminho_ok "$BRAIN"; then break; fi
    BRAIN=""; aviso "Esse lugar não serve: $MOTIVO"
    [ -n "$AUTO" ] && break
  done
  [ -n "$BRAIN" ] || parar "Não consegui um lugar válido pro Brain." "Rode de novo e aperte Enter pra aceitar o lugar sugerido."
  case "$BRAIN" in "$HOME/Documents"*|"$HOME/Desktop"*)
    aviso "Documentos e Mesa são pastas protegidas do Mac: na 1ª vez ele vai perguntar se o ${B}node${N} pode acessar. Clique em ${B}Permitir${N}.";;
  esac
  mkdir -p "$BRAIN" || parar "Não consegui criar a pasta $BRAIN."
  saida="$("$NODE" "$APP/scripts/montar-brain.js" "$APP/modelo-brain" "$BRAIN" "$NOME" pt 2>&1)" || parar "Não consegui montar o Brain: $saida"
  info "$saida"
  ok "Brain em: $BRAIN"
  deu_certo "dentro da pasta tem CLAUDE.md (o manual do Jarvis), wiki/ e raw/."
}

# ═══ PASSO 5 · OBSIDIAN ════════════════════════════════════════════════════
instalar_obsidian() {
  local dados url sha tmp dest r
  dados="$("$NODE" -e '
    fetch("https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest",{headers:{"User-Agent":"jarvis-starter"}})
      .then(r=>r.json()).then(d=>{
        const dmg=(d.assets||[]).filter(a=>/\.dmg$/.test(a.name));
        const a=dmg.find(a=>!/arm64|intel|x64/i.test(a.name))||dmg[0];
        if(!a) process.exit(1);
        console.log(a.browser_download_url+" "+String(a.digest||"").replace("sha256:",""));
      }).catch(()=>process.exit(1))')" || return 1
  url="${dados%% *}"; sha="${dados#* }"; [ "$sha" = "$url" ] && sha=""
  tmp="$(mktemp -d)"
  info "Baixando o Obsidian..."
  curl -fL --progress-bar -o "$tmp/Obsidian.dmg" "$url" || { rm -rf "$tmp"; return 1; }
  if [ -n "$sha" ]; then
    [ "$(shasum -a 256 "$tmp/Obsidian.dmg" | awk '{print $1}')" = "$sha" ] || { erro "O arquivo não bate com a assinatura publicada pelo Obsidian. Parei por segurança."; rm -rf "$tmp"; return 1; }
    ok "Download conferido com a assinatura oficial (sha256)"
  else aviso "O Obsidian não publicou assinatura deste arquivo; segui só com o HTTPS do GitHub."; fi
  hdiutil attach -nobrowse -quiet -mountpoint "$tmp/disco" "$tmp/Obsidian.dmg" || { rm -rf "$tmp"; return 1; }
  dest="${JARVIS_APPS_DIR:-/Applications}"; [ -w "$dest" ] || dest="$HOME/Applications"; mkdir -p "$dest"
  ditto "$tmp/disco/Obsidian.app" "$dest/Obsidian.app"; r=$?
  hdiutil detach -quiet "$tmp/disco" >/dev/null 2>&1; rm -rf "$tmp"
  return $r
}
esperar_cofre() {   # espera o Obsidian abrir a pasta (ele cria .obsidian dentro dela)
  local i=0
  while [ ! -d "$BRAIN/.obsidian" ]; do
    [ -n "$AUTO" ] && return 1
    if read -r -t 3 _ </dev/tty; then return 1; fi    # Enter = pular
    i=$((i+3)); [ "$i" -ge 600 ] && return 1
    printf "${D}.${N}"
  done
  echo; return 0
}
passo_obsidian() {
  passo 5 "Obsidian, onde o seu Brain fica organizado"
  if ! OBS="$(achar_obsidian)"; then
    info "O Obsidian é grátis. Ele mostra as páginas do Brain e como elas se ligam."
    if sim "Baixar e instalar o Obsidian (~220 MB)?"; then
      if ! instalar_obsidian || ! OBS="$(achar_obsidian)"; then
        aviso "Não consegui instalar o Obsidian agora. Sigo sem ele: o Jarvis funciona igual."
        aviso "Depois é só baixar em https://obsidian.md e abrir a pasta $BRAIN."
        return
      fi
      ok "Obsidian instalado em $(dirname "$OBS")"
    else aviso "Sem problema. O Jarvis funciona sem o Obsidian; dá pra instalar depois em https://obsidian.md"; return; fi
  else ok "Obsidian já instalado"; fi
  if [ -d "$BRAIN/.obsidian" ]; then
    ok "O Obsidian já conhece o seu Brain"
    [ -z "$AUTO" ] && open "obsidian://open?path=$("$NODE" -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$BRAIN")" 2>/dev/null
    return
  fi
  echo
  info "Agora vou abrir o Obsidian. ${B}Faça assim:${N}"
  info "  1. Clique em ${B}Abrir pasta como cofre${N} (em inglês: Open folder as vault)"
  if [ "$(dirname "$BRAIN")" = "$HOME" ]; then info "  2. Na janela que abrir, vá na sua pasta pessoal (a ${B}casinha${N}, $(id -un)) → ${B}$(basename "$BRAIN")${N} → ${B}Abrir${N}"
  elif [ "$(dirname "$BRAIN")" = "$HOME/Documents" ]; then info "  2. Vá em ${B}Documentos${N} → ${B}$(basename "$BRAIN")${N} → ${B}Abrir${N}"
  else info "  2. Escolha a pasta ${B}$(basename "$BRAIN")${N} (o caminho está logo abaixo) → ${B}Abrir${N}"; fi
  info "  3. Se ele perguntar se confia no autor, clique em ${B}Confiar${N}"
  info "  ${D}(a pasta fica em: $BRAIN)${N}"
  enter "Aperte Enter que eu abro o Obsidian..."
  [ -z "$AUTO" ] && open -a "$OBS"
  info "Esperando você abrir a pasta no Obsidian ${D}(Enter pula)${N}"
  if esperar_cofre; then ok "Pronto: o Obsidian está com o seu Brain aberto"
  else aviso "Pulei. Quando quiser: Obsidian → Abrir pasta como cofre → $BRAIN"; fi
  deu_certo "na esquerda do Obsidian aparecem as pastas wiki e raw."
}

# ═══ PASSO 6 · VOZ ═════════════════════════════════════════════════════════
voz_funciona() {  # gera um áudio de teste sem tocar: prova que o arquivo da voz está inteiro
  local wav
  wav="$(printf '{"id":"prova","texto":"ok"}\n' | "$PY" "$APP/voz/falar.py" "$JH/voz/vozes/$1.onnx" 2>/dev/null | sed -n 's/.*"wav": *"\([^"]*\)".*/\1/p')"
  [ -n "$wav" ] && [ -s "$wav" ] && { rm -f "$wav"; return 0; }
  return 1
}
baixar_voz() {   # $1 = nome da voz do Piper. Download pela metade não passa: confere os 2 arquivos e testa
  local t
  for t in 1 2; do
    if [ -s "$JH/voz/vozes/$1.onnx" ] && [ -s "$JH/voz/vozes/$1.onnx.json" ] && voz_funciona "$1"; then return 0; fi
    rm -f "$JH/voz/vozes/$1.onnx" "$JH/voz/vozes/$1.onnx.json"
    info "Baixando a voz $1 (~60 MB)..."
    "$PY" -m piper.download_voices --download-dir "$JH/voz/vozes" "$1" >/dev/null 2>&1
  done
  [ -s "$JH/voz/vozes/$1.onnx" ] && voz_funciona "$1"
}
sem_piper() { aviso "$1 Fico com a voz do Mac (Luciana) e sigo. Pra tentar de novo depois: bash \"$APP/instalar.sh\" --voz"; }
tocar_piper() {  # $1 voz · $2 texto
  local wav
  wav="$(printf '{"id":"teste","texto":%s}\n' "$(json_str "$2")" | "$PY" "$APP/voz/falar.py" "$JH/voz/vozes/$1.onnx" 2>/dev/null | sed -n 's/.*"wav": *"\([^"]*\)".*/\1/p')"
  [ -n "$wav" ] && [ -f "$wav" ] || return 1
  [ -z "${JARVIS_SEM_SOM:-}" ] && afplay "$wav"
  rm -f "$wav"; return 0
}
tocar_mac() { [ -z "${JARVIS_SEM_SOM:-}" ] && say -v Luciana "$1"; return 0; }
passo_voz() {
  passo 6 "A voz do Jarvis"
  info "${B}Falar:${N} Piper, uma voz neural que roda no seu Mac. Grátis, sem internet, sem conta, sem cobrança."
  info "${B}Ouvir:${N} o microfone usa o reconhecimento de voz do navegador (grátis, melhor no Chrome)."
  echo
  MOTOR="say"; VOZ="pt_BR-faber-medium"
  if ! voz_instalada; then
    if sim "Instalar a voz grátis (~110 MB)?"; then
      if ! tem uv; then
        info "Instalando o uv (instala o Python da voz sem mexer no do sistema)..."
        curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null 2>&1; export PATH="$HOME/.local/bin:$PATH"; hash -r
      fi
      mkdir -p "$JH/voz"
      info "Preparando o Python da voz..."
      if ! tem uv; then sem_piper "Não consegui instalar o uv."
      elif ! uv venv -q --python 3.12 "$JH/voz/.venv" >/dev/null 2>&1; then sem_piper "Não consegui criar o ambiente da voz."
      elif ! uv pip install -q --python "$PY" "piper-tts==1.8.0" >/dev/null 2>&1; then sem_piper "Não consegui instalar o Piper."; fi
    else aviso "Ok, fico com a voz do Mac. Dá pra trocar depois com: bash \"$APP/instalar.sh\" --voz"; fi
  fi
  if voz_instalada && ! baixar_voz "$VOZ"; then sem_piper "Não consegui baixar a voz."
  elif voz_instalada; then
    info "Vou tocar as vozes. ${B}Aumente o volume${N} e escute."
    enter
    while :; do
      info "Voz 1 (Piper faber)..."; tocar_piper "$VOZ" "Olá, $NOME. Eu sou a voz um. Neural, gratuita e roda no seu computador." || aviso "a voz 1 não tocou"
      if tem_luciana; then info "Voz 2 (Luciana, do Mac)..."; tocar_mac "Olá, $NOME. Eu sou a voz dois, a Luciana, do próprio Mac."; fi
      perguntar "Qual você prefere? 1 = Piper · 2 = Luciana · 3 = ouvir outra voz do Piper (cadu) · 4 = ouvir de novo" "1"
      case "$REPLY" in
        2) MOTOR="say"; break;;
        3) baixar_voz "pt_BR-cadu-medium" && { tocar_piper "pt_BR-cadu-medium" "Olá, $NOME. Eu sou a voz cadu."; if sim "Ficar com a voz cadu?"; then VOZ="pt_BR-cadu-medium"; MOTOR="piper"; break; fi; };;
        4) ;;
        *) MOTOR="piper"; break;;
      esac
    done
  fi
  if [ "$MOTOR" = "piper" ]; then ok "Voz escolhida: Piper ($VOZ)"; else ok "Voz escolhida: Luciana (voz do Mac)"; fi
  if ! tem_chrome; then
    echo
    aviso "Pro microfone, instale o Google Chrome (grátis): https://www.google.com/chrome/"
    [ -z "$AUTO" ] && sim "Abrir a página de download do Chrome agora?" && open "https://www.google.com/chrome/"
  fi
  deu_certo "você ouviu a voz que escolheu."
  se_errado "confira o volume e se a saída de som é a certa (Ajustes do Sistema → Som)."
}

# ═══ PASSO 7 · JARVIS NO AR ════════════════════════════════════════════════
gravar_config() {
  local nav=""; tem_chrome && nav="Google Chrome"
  "$NODE" "$APP/scripts/config.js" "$APP/jarvis.config.json" \
    "userName=$NOME" "brandName=Jarvis · $NOME" "brainDir=$BRAIN" "brainName=$(basename "$BRAIN")" "lang=pt" \
    "navegador=$nav" "ytdlp=${YTDLP_ACHADO:-$YTDLP}" "voz.motor=$MOTOR" "voz.python=$PY" "voz.modelo=$JH/voz/vozes/$VOZ.onnx" "voz.say=Luciana"
}
subir_jarvis() {
  mkdir -p "$JH/logs"
  if [ -n "${JARVIS_SEM_LAUNCHD:-}" ]; then   # modo de teste: sobe direto, sem mexer no login do Mac
    local velho; for velho in $(lsof -t -nP -iTCP:"$PORTA" -sTCP:LISTEN 2>/dev/null); do
      ps -o command= -p "$velho" | grep -q "server.js" && kill "$velho" 2>/dev/null
    done; sleep 1
    ( cd "$APP" && PORT="$PORTA" JARVIS_SEM_NAVEGADOR=1 nohup "$NODE" server.js >>"$JH/logs/jarvis.log" 2>&1 & )
  else
    local plist="$HOME/Library/LaunchAgents/$LABEL.plist"
    mkdir -p "$HOME/Library/LaunchAgents"
    cat >"$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$(xml "$NODE")</string><string>$(xml "$APP/server.js")</string></array>
  <key>WorkingDirectory</key><string>$(xml "$APP")</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>$(xml "$HOME/.local/bin:$(dirname "$NODE"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin")</string>
    <key>HOME</key><string>$(xml "$HOME")</string>
    <key>PORT</key><string>$PORTA</string>
  </dict>
  <key>StandardOutPath</key><string>$(xml "$JH/logs/jarvis.log")</string>
  <key>StandardErrorPath</key><string>$(xml "$JH/logs/jarvis.log")</string>
</dict></plist>
PLIST
    launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1
    launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || launchctl load "$plist"
  fi
  # "no ar" só quando quem responde é a versão que acabou de ser instalada (não uma antiga presa na porta)
  local i esperada; esperada="$(shasum -a 256 "$APP/server.js" | cut -c1-12)"
  for i in $(seq 1 30); do [ "$(versao_no_ar)" = "$esperada" ] && return 0; sleep 1; done
  return 1
}
instalar_ytdlp() {
  local tmp esperado obtido base="https://github.com/yt-dlp/yt-dlp/releases/latest/download"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/yt-dlp" "$base/yt-dlp_macos" && curl -fsSL -o "$tmp/SUMS" "$base/SHA2-256SUMS" || { rm -rf "$tmp"; return 1; }
  esperado="$(awk '$2=="yt-dlp_macos"{print $1}' "$tmp/SUMS")"; obtido="$(shasum -a 256 "$tmp/yt-dlp" | awk '{print $1}')"
  [ -n "$esperado" ] && [ "$esperado" = "$obtido" ] || { erro "O yt-dlp baixado não bate com a assinatura oficial. Parei por segurança."; rm -rf "$tmp"; return 1; }
  mkdir -p "$JH/bin" && mv "$tmp/yt-dlp" "$JH/bin/yt-dlp" && chmod +x "$JH/bin/yt-dlp"; rm -rf "$tmp"
  "$JH/bin/yt-dlp" --version >/dev/null 2>&1
}
passo_jarvis() {
  passo 7 "O painel do Jarvis"
  if ! YTDLP_ACHADO="$(achar_ytdlp)"; then
    info "Instalando o yt-dlp (card YouTube → Brain)..."
    if instalar_ytdlp; then YTDLP_ACHADO="$JH/bin/yt-dlp"; ok "yt-dlp instalado e conferido (sha256)"
    else YTDLP_ACHADO=""; aviso "O yt-dlp não instalou; o card do YouTube fica sem funcionar. Rode o instalador de novo depois."; fi
  fi
  info "Instalando as peças do painel..."
  ( cd "$APP" && "$NPM" install --omit=dev --no-audit --no-fund --loglevel=error >/dev/null 2>&1 ) || parar "O npm install falhou." "Veja o erro com: cd \"$APP\" && npm install"
  gravar_config
  info "Ligando o Jarvis (e deixando ele ligar sozinho quando o Mac ligar)..."
  rm -f "$APP/.aberto-no-boot"     # o servidor abre o painel uma vez nesta instalação (e não a cada reinício)
  subir_jarvis || parar "O painel novo não subiu." "Veja o motivo no fim de $JH/logs/jarvis.log (se disser que a porta $PORTA está em uso, tem um Jarvis antigo ligado: launchctl list | grep -i jarvis)"
  ok "Jarvis no ar: ${B}http://localhost:$PORTA${N}"
  if ! curl -s --max-time 5 "http://127.0.0.1:$PORTA/api/brain" | grep -q '"legivel":true'; then
    aviso "O painel não está conseguindo ler o Brain. Se o Mac perguntou se o ${B}node${N} pode acessar uma pasta, era isso:"
    aviso "Ajustes do Sistema → Privacidade e Segurança → Arquivos e Pastas → node → ligue a pasta. Depois rode o instalador de novo."
  fi
  deu_certo "o navegador abriu o painel e o canto de cima diz ONLINE."
  se_errado "abra http://localhost:$PORTA no Chrome. Se não abrir, reinicie com: launchctl kickstart -k gui/\$(id -u)/$LABEL"
}

# ═══ FIM ═══════════════════════════════════════════════════════════════════
final() {
  echo; echo "${L}${B}━━━ PRONTO, $NOME ━━━${N}"; echo
  linha ok "Claude Code" "instalado e logado"
  linha ok "Brain" "$BRAIN"
  if [ -d "$BRAIN/.obsidian" ]; then linha ok "Obsidian" "abrindo o seu Brain"; else linha falta "Obsidian" "falta abrir a pasta: Abrir pasta como cofre → $(basename "$BRAIN")"; fi
  linha ok "Voz" "$([ "$MOTOR" = piper ] && echo "Piper, grátis e offline" || echo "Luciana, voz do Mac")"
  linha ok "Painel" "http://localhost:$PORTA (liga sozinho com o Mac)"
  echo
  info "${B}O próximo passo é o tour guiado:${N} ele cria as SUAS abas, testa a voz e o microfone"
  info "e guarda as primeiras coisas sobre você. Uma pergunta por vez."
  echo
  perguntar "Onde quer fazer o tour? 1 = no painel, com voz · 2 = aqui no terminal" "1"
  if [ "$REPLY" = "2" ]; then
    info "Abrindo o Claude Code no seu Brain. Pra sair depois, digite /exit."
    echo
    [ -z "$AUTO" ] && { cd "$BRAIN" && exec claude "/primeiros-passos" </dev/tty; }
  else
    info "No painel, clique em ${B}🚀 Primeiros passos${N}."
    info "${D}(o painel abriu no navegador; se fechou, é só abrir http://localhost:$PORTA)${N}"
    echo
    info "${D}Amanhã: o painel já liga sozinho. Pra conversar pelo terminal: cd \"$BRAIN\" && claude --continue${N}"
  fi
}

# ═══ ORDEM ═════════════════════════════════════════════════════════════════
echo
echo "${L}${B}   J A R V I S${N}   ${D}instalador guiado${N}"
case "$MODO" in
  diagnostico)
    diagnostico; echo; info "Isso foi só o estudo. Pra instalar: bash \"$APP/instalar.sh\""; echo ;;
  voz)
    NODE="$(achar_node)" || parar "Rode o instalador completo primeiro."
    [ -f "$APP/jarvis.config.json" ] || parar "Rode o instalador completo primeiro."
    NOME="$("$NODE" -e 'process.stdout.write(require(process.argv[1]).userName||"")' "$APP/jarvis.config.json")"
    TOTAL=6; passo_voz
    "$NODE" "$APP/scripts/config.js" "$APP/jarvis.config.json" "voz.motor=$MOTOR" "voz.python=$PY" "voz.modelo=$JH/voz/vozes/$VOZ.onnx"
    if [ -z "${JARVIS_SEM_LAUNCHD:-}" ]; then launchctl kickstart -k "gui/$(id -u)/$LABEL" >/dev/null 2>&1; fi
    ok "Voz trocada e Jarvis reiniciado." ;;
  *)
    diagnostico
    echo; sim "Posso começar?" || { info "Tudo bem. Quando quiser: bash \"$APP/instalar.sh\""; exit 0; }
    passo_claude; passo_node; passo_brain; passo_obsidian; passo_voz; passo_jarvis; final ;;
esac
