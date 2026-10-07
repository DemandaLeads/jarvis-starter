---
title: "Voz e microfone"
---

# Voz e microfone

## A voz (o Jarvis falando)
Usa o **Piper**: uma voz neural que roda no seu Mac, de graça, sem internet e sem conta. Fica em `~/.jarvis/voz`.

**Trocar de voz:** no terminal do VS Code, rode o passo da voz do instalador de novo. Ele toca cada opção pra você ouvir e escolher, e reinicia o Jarvis sozinho:

```
bash ~/.jarvis/app/instalar.sh --voz
```

As opções: vozes neurais do Piper em português do Brasil (faber e cadu, masculinas) ou a voz do Mac (Luciana, feminina). A Luciana fica bem melhor na versão Premium, que é grátis: Ajustes do Sistema → Acessibilidade → Conteúdo Falado → Voz do Sistema → Gerenciar Vozes → Português (Brasil) → Luciana (Premium).

## O microfone (você falando)
Usa o reconhecimento de voz do navegador, grátis. Funciona melhor no **Google Chrome**.

1. Abra http://localhost:3131 no Chrome.
2. Clique na bolinha do microfone (ou aperte espaço).
3. Na primeira vez, clique em **Permitir** quando o Chrome pedir o microfone.

**Deu certo se:** enquanto você fala, o texto aparece embaixo da caixa de mensagem.
**Se der errado:** clique no cadeado ao lado do endereço → Microfone → Permitir. Se o Mac bloquear, vá em Ajustes do Sistema → Privacidade e Segurança → Microfone e ligue o Google Chrome.
