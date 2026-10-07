---
title: "Configurar o email"
---

# Configurar o envio de email (Gmail)

Sem isto o Jarvis já **escreve** emails e deixa na aba Email pra você revisar. Isto aqui é só pra ele conseguir **enviar** depois que você aprovar. Leva uns 5 minutos.

## 1. Ligue a verificação em 2 etapas
Abra e siga a tela do Google: https://myaccount.google.com/signinoptions/two-step-verification

**Deu certo se:** a página mostra "A verificação em duas etapas está ativada".

## 2. Crie uma senha de app
Abra: https://myaccount.google.com/apppasswords
Dê o nome **Jarvis** e clique em Criar. Aparecem **16 letras**. Deixe essa janela aberta.

**Se der errado:** se a página disser que a opção não está disponível, a verificação em 2 etapas ainda não está ligada (volte ao passo 1). Conta de empresa às vezes bloqueia: aí fale com quem administra.

## 3. Cole a senha no Jarvis
No terminal do VS Code:

```
{{CMD_ENV}}
```

Abre um arquivo de texto. Troque `seuemail@gmail.com` pelo seu Gmail e cole as 16 letras depois de `EMAIL_APP_PASSWORD=`. Salve ({{ATALHO_SALVAR}}) e feche.

**Nunca** mande essa senha no chat, nem pro Jarvis. Ela vai só nesse arquivo.

## 4. Reinicie o Jarvis

```
{{CMD_REINICIAR}}
```

**Deu certo se:** a aba Email não mostra mais o aviso amarelo.
**Teste:** peça "escreve um email pra mim mesmo com o assunto teste", aprove na aba Email e veja se chega na sua caixa.
