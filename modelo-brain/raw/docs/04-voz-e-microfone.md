---
title: "Voz e microfone"
---

# Voz e microfone

## A voz (o Jarvis falando)
Usa o **Piper**: uma voz neural que roda no seu {{COMPUTADOR}}, de graça, sem internet e sem conta. Fica em `{{DIR_JARVIS}}{{SEP}}voz`.

**Trocar de voz:** no terminal do VS Code, rode o passo da voz do instalador de novo. Ele toca cada opção pra você ouvir e escolher, e reinicia o Jarvis sozinho:

```
{{CMD_VOZ}}
```

{{TEXTO_VOZ_SISTEMA}}

## O microfone (você falando)
Usa o reconhecimento de voz do navegador, grátis. Funciona melhor no **{{NAVEGADOR_MIC}}**.

1. Abra http://localhost:3131 no Chrome.
2. Clique na bolinha do microfone (ou aperte espaço).
3. Na primeira vez, clique em **Permitir** quando o Chrome pedir o microfone.

**Deu certo se:** enquanto você fala, o texto aparece embaixo da caixa de mensagem.
**Se der errado:** clique no cadeado ao lado do endereço → Microfone → Permitir. {{AJUSTE_MICROFONE}}
