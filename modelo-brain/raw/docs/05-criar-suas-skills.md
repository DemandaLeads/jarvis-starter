---
title: "Criar suas skills"
---

# Criar suas skills (receitas que o Jarvis guarda)

Uma **skill** é uma receita: você ensina uma vez como fazer uma tarefa e depois chama com uma barra, tipo `/resumo-de-reuniao`. Elas moram na pasta `.claude/commands/` do seu Brain.

Por segurança, **o painel não consegue criar skills**: essa pasta é protegida e o Claude Code só mexe nela com você aprovando na hora. Por isso a criação é pelo terminal, onde ele te pergunta antes de salvar.

## 1. Abra o terminal no seu Brain
No VS Code: menu **Terminal → Novo Terminal**, e digite:

```
{{CMD_ABRIR_BRAIN}}
```

## 2. Peça a skill
Cole e adapte:

```
Quero criar uma skill chamada resumo-de-reuniao. Quando eu colar a transcrição de uma reunião, você lista as decisões, as pendências (o quê, quem, quando) e a próxima data. Crie o arquivo em .claude/commands/ e me mostre antes de salvar.
```

Ele mostra o arquivo e pede permissão pra salvar: escolha **Yes**.

**Deu certo se:** a skill aparece na aba **Skills** do painel, em "Seus comandos".
**Se der errado:** confira se você abriu o `claude` dentro da pasta do Brain (o primeiro comando acima).

## 3. Use
No painel ou no terminal, digite `/resumo-de-reuniao` e cole o texto.

Pra sair do terminal do Claude: digite `/exit`.
