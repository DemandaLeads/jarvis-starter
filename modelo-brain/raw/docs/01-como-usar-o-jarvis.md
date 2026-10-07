---
title: "Como usar o Jarvis"
---

# Como usar o Jarvis no dia a dia

## O painel
Abre sozinho quando o {{COMPUTADOR}} liga. Se fechou a aba, é só abrir no navegador (de preferência o {{NAVEGADOR_MIC}}):

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
{{CMD_CONTINUAR}}
```

O `--continue` retoma a última conversa, então ele lembra do que vocês falaram.

## Reiniciar o Jarvis
Se o painel travar ou ficar OFFLINE:

```
{{CMD_REINICIAR}}
```

**Deu certo se:** em uns 5 segundos o painel volta a mostrar ONLINE.
**Se der errado:** rode o instalador de novo, ele conserta o que faltar e não apaga nada: `{{CMD_CONSERTAR}}`

## Onde fica cada coisa
| O quê | Onde |
|---|---|
| Seu Brain (páginas, memória) | `{{BRAIN}}` |
| O programa do Jarvis | `{{DIR_JARVIS}}{{SEP}}app` |
| A voz | `{{DIR_JARVIS}}{{SEP}}voz` |
| O registro de erros | `{{ARQ_LOG}}` |

## Desinstalar
Remove o programa e a voz. **O seu Brain fica**, com tudo dentro.

```
{{CMD_DESINSTALAR}}
```
