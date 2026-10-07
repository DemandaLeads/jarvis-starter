# Jarvis

Um assistente pessoal que roda no seu computador (Mac ou Windows). Você conversa com ele por texto ou voz, e ele organiza tudo num **Brain**: uma pasta de notas que você também abre no Obsidian. Cada pasta do Brain vira uma **aba** do painel, então ele toma a forma do que você faz.

- **Conversa** pelo painel (`localhost:3131`) ou pelo terminal, com o Claude Code por trás.
- **Fala** com voz neural grátis, que roda no próprio Mac (Piper). **Ouve** pelo microfone do navegador.
- **Lembra**: guarda o que aprende sobre você, um fato por arquivo.
- **Abas suas**: crie quantas quiser, pelo botão ＋ ou pedindo no chat.
- **Email com aprovação**: ele escreve, você revisa e aprova. Nada sai sem você.
- **YouTube → Brain**: cola o link e ele salva a transcrição e um resumo.

## Instalar no Mac

Abra o terminal (no VS Code: menu **Terminal → Novo Terminal**), cole e aperte Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/DemandaLeads/jarvis-starter/main/instalar.sh | bash
```

O instalador **primeiro estuda o seu Mac** e mostra o que já tem e o que falta. Só depois, se você disser sim, ele instala o que faltar, um passo por vez, perguntando antes de cada download:

| Passo | O que acontece |
|---|---|
| 1. Estudo do Mac | confere macOS, espaço, internet, e o que já está instalado. Não muda nada |
| 2. Claude Code | instala pelo comando oficial da Anthropic e faz o login no navegador |
| 3. Node | instala dentro de `~/.jarvis`, com o download conferido pela assinatura oficial |
| 4. Seu Brain | cria a pasta na sua pasta pessoal com o manual do Jarvis e as primeiras abas |
| 5. Obsidian | baixa do site oficial (conferido) e te guia pra abrir o Brain nele |
| 6. Voz | instala o Piper, toca as vozes pra você escolher |
| 7. Painel | deixa o Jarvis no ar e ligando sozinho quando o Mac liga |

No fim ele oferece o **tour guiado** (`/primeiros-passos`): cria as suas abas, testa voz e microfone e guarda as primeiras coisas sobre você.

Só quer ver o estudo, sem instalar? Rode `bash instalar.sh --diagnostico` depois de clonar.

## Instalar no Windows

No VS Code, abra o terminal (menu **Terminal → Novo Terminal**; no Windows ele já é o PowerShell), cole e aperte Enter:

```powershell
irm https://raw.githubusercontent.com/DemandaLeads/jarvis-starter/main/instalar.ps1 | iex
```

São os mesmos 7 passos do Mac: estudo do PC, Claude Code, Node, Brain, Obsidian, voz e painel. O painel liga sozinho quando o Windows liga (pasta Inicializar) e religa se cair. Precisa do **Windows 10 versão 1809** ou mais novo, ou do Windows 11. A voz neural (Piper) roda em PC com processador Intel ou AMD; em PC com chip ARM fica a voz do próprio Windows. O microfone funciona no Chrome e no Edge.

Só o estudo do PC: `powershell -ExecutionPolicy Bypass -File "$HOME\.jarvis\app\instalar.ps1" -Diagnostico`

## O que precisa

- Mac com **macOS 13** ou mais novo, ou Windows 10 (1809) / Windows 11, e uns 3 GB livres.
- Uma **conta Claude paga (Pro ou Max)**. É o único custo: o plano grátis do Claude não inclui o Claude Code. Todo o resto (Obsidian, voz, Node, painel) é grátis.
- O **Google Chrome** (ou o Edge, no Windows) é recomendado pro microfone.

Não precisa de git, Homebrew, Xcode nem permissão de administrador.

## Onde fica cada coisa

| O quê | Onde |
|---|---|
| Seu Brain (notas, memória, abas) | `~/<seu nome> Brain` (na sua pasta pessoal) |
| O painel | http://localhost:3131 |
| O programa, o Node e a voz | `~/.jarvis` |
| O registro de erros | `~/.jarvis/logs/jarvis.log` |

## Privacidade

O painel só aceita conexões desta máquina (`127.0.0.1`) e desta página: outro site aberto no navegador não consegue mandar ordem pro Jarvis. A voz roda offline. As conversas vão para o Claude, como em qualquer uso do Claude Code. Pelo painel, o Jarvis só lê e edita arquivos **dentro do Brain** e pesquisa na web: ele não tem terminal, e leitura fora do Brain é recusada. Quem baixa vídeo do YouTube é o próprio painel, com argumentos fixos. Conteúdo de site ou vídeo entra como informação, e o manual do Jarvis manda tratar como tal, mas nenhum modelo é imune a texto malicioso: o que ele lê na web pode influenciar o que ele escreve no Brain. Nada é enviado (email incluso) sem você aprovar no painel.

## Atualizar

Cole o mesmo comando da instalação de novo: ele baixa a versão nova, mantém o seu config, a senha do email e a fila, e não mexe no Brain.

## Comandos úteis (Mac)

```bash
bash ~/.jarvis/app/instalar.sh                 # conserta o que faltar (não apaga nada seu)
bash ~/.jarvis/app/instalar.sh --voz           # trocar a voz
launchctl kickstart -k gui/$(id -u)/com.jarvis.painel   # reiniciar o painel
bash ~/.jarvis/app/desinstalar.sh              # remover (o Brain fica)
```

## Comandos úteis (Windows)

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.jarvis\app\instalar.ps1"        # conserta o que faltar
powershell -ExecutionPolicy Bypass -File "$HOME\.jarvis\app\instalar.ps1" -Voz   # trocar a voz
powershell -ExecutionPolicy Bypass -File "$HOME\.jarvis\app\reiniciar.ps1"       # reiniciar o painel
powershell -ExecutionPolicy Bypass -File "$HOME\.jarvis\app\desinstalar.ps1"     # remover (o Brain fica)
```

## Para quem mexe no código

`server.js` (Express + WebSocket) recebe as mensagens e roda `claude -p` na pasta do Brain, numa sessão fixa. `public/index.html` é o painel. `voz/falar.py` mantém o modelo do Piper carregado e conversa com o servidor por stdin/stdout, sem porta de rede. `modelo-brain/` é o que o instalador copia para o Brain novo.

Testes (sem gastar crédito e sem som; o `claude` e a voz são trocados por dublês):

```bash
npm install && npm test
```

A cada envio, o GitHub roda os testes num Mac e num Windows de verdade (`.github/workflows/teste.yml`); no Windows, ele instala tudo do zero pelo mesmo `irm ... | iex` que a pessoa cola.
