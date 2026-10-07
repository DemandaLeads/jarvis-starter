---
title: "Como usar o Jarvis"
---

# Como usar o Jarvis no dia a dia

## O painel
Abre sozinho quando o Mac liga. Se fechou a aba, é só abrir no navegador (de preferência o Google Chrome):

```
http://localhost:3131
```

- **Escrever:** digite na caixa de baixo e aperte Enter.
- **Falar:** clique na bolinha do microfone (ou aperte a barra de espaço), fale e espere. Na primeira vez o navegador pede o microfone: clique em **Permitir**.
- **Voz ligada ou desligada:** botão **🔊 VOZ** no topo.
- **Abas:** a barra da esquerda. Cada aba é uma pasta do seu Brain. O **＋** cria uma nova.

**Deu certo se:** o canto de cima mostra **ONLINE** em verde.
**Se der errado:** se aparecer OFFLINE, reinicie o Jarvis com o comando da seção "Reiniciar".

## O Obsidian
É onde o seu Brain mora: as mesmas páginas do painel, que dá pra ler e editar à mão. Abra o Obsidian e escolha o cofre com o seu nome.

## O terminal (para conversas longas)
No VS Code, abra o terminal (menu Terminal → Novo Terminal) e digite:

```
cd "{{BRAIN}}" && claude --continue
```

O `--continue` retoma a última conversa, então ele lembra do que vocês falaram.

## Reiniciar o Jarvis
Se o painel travar ou ficar OFFLINE:

```
launchctl kickstart -k gui/$(id -u)/com.jarvis.painel
```

**Deu certo se:** em uns 5 segundos o painel volta a mostrar ONLINE.
**Se der errado:** rode o instalador de novo, ele conserta o que faltar e não apaga nada: `bash ~/.jarvis/app/instalar.sh`

## Onde fica cada coisa
| O quê | Onde |
|---|---|
| Seu Brain (páginas, memória) | `{{BRAIN}}` |
| O programa do Jarvis | `~/.jarvis/app` |
| A voz | `~/.jarvis/voz` |
| O registro de erros | `~/.jarvis/logs/jarvis.log` |

## Desinstalar
Remove o programa e a voz. **O seu Brain fica**, com tudo dentro.

```
bash ~/.jarvis/app/desinstalar.sh
```
