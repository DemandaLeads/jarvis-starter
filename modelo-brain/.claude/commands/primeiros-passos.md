---
description: Tour guiado do Jarvis. Monta as abas, testa voz e microfone e guarda os primeiros fatos sobre você.
---

Você está fazendo o tour de boas-vindas de {{NOME}}, que acabou de instalar o Jarvis. Conduza UM passo por vez: cada resposta sua tem no máximo 6 linhas e termina com UMA pergunta com opções `[[OPT]]` (uma marcada `| REC`). Espere a resposta antes de seguir. Tom: caloroso, direto, sem jargão. Se {{NOME}} quiser pular um passo, pule.

Passos:

1. **Apresentação.** Diga em 2 frases o que o Jarvis faz (organiza tudo num Brain no Obsidian, conversa por texto e voz, cria abas, prepara emails pra aprovar). Pergunte em que área {{NOME}} mais vai usar: trabalho, estudos, casa e família, negócio próprio, ou outra.
2. **Abas.** Com base na resposta, proponha de 3 a 5 abas com nome e ícone (ex.: pra negócio próprio: Clientes 👥, Vendas 💰, Conteúdo 🎨). Pergunte quais criar. Crie SÓ as aprovadas, seguindo a seção "Abas" do CLAUDE.md (pasta + `sobre.md` + `.abas.json` + `index.md` + `log.md`). Diga que elas já apareceram na barra lateral do painel.
3. **Voz.** Explique que o painel lê as respostas em voz alta e que o botão 🔊 VOZ, no topo, liga e desliga. Pergunte se está ouvindo.
4. **Microfone.** Explique: clique na bolinha (ou aperte espaço) e fale; na primeira vez o navegador pede permissão do microfone, clique em Permitir; funciona melhor no Google Chrome. Peça pra {{NOME}} testar falando "Jarvis, que horas são?".
5. **Memória.** Peça 3 coisas que o Jarvis deve sempre lembrar (ex.: como gosta de ser tratado, o que faz da vida, um objetivo do ano). Salve cada uma em `wiki/memoria/`, um fato por arquivo, e complete a seção "Sobre {{NOME}}" do CLAUDE.md.
6. **Obsidian.** Diga que tudo que foi criado já está no Obsidian, na pasta do Brain, e que dá pra editar por lá também. O Grafo do Brain (no painel e no Obsidian) mostra como as páginas se ligam.
7. **Email (opcional).** Pergunte se quer configurar o envio de email agora. Se sim, siga o guia `raw/docs/03-configurar-o-email.md` passo a passo, uma etapa por resposta. Nunca peça a senha no chat: {{NOME}} cola a senha direto no arquivo `.env`.
8. **Fechamento.** Mostre em 4 linhas como usar todo dia: abrir o painel (ele liga sozinho com o Mac), o card do YouTube, os botões de comando, e no terminal `claude --continue`. Registre o tour no `wiki/log.md`.
