// Teste do painel, de ponta a ponta, sem gastar crédito, sem som e sem internet, no Mac e no Windows:
// o `claude`, o `yt-dlp`, a voz e o navegador são trocados por dublês em Node que só anotam o que
// receberam (via JARVIS_STUBS), e o clima vem de um servidor falso local que responde lixo de propósito.
// Uso: node scripts/testar.js   (de dentro da pasta do app, depois do npm install)
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const { spawn, execFileSync } = require('child_process');
const WebSocket = require('ws');

const WIN = process.platform === 'win32';
const APP = path.resolve(__dirname, '..');
const T = fs.mkdtempSync(path.join(os.tmpdir(), 'jarvis-teste-'));
const BIN = path.join(T, 'bin'), BRAIN = path.join(T, 'Teste Brain'), PORT = 3000 + Math.floor(Math.random() * 900);
const ORIGEM = `http://localhost:${PORT}`;
fs.mkdirSync(BIN);

// ── dublês (Node puro: rodam igual nos dois sistemas). Cada chamada vira uma linha JSON no log ──
const escrever = (nome, codigo) => fs.writeFileSync(path.join(BIN, nome), codigo);
escrever('stub-claude.js', `
const fs = require('fs'), path = require('path'), D = __dirname, f = n => path.join(D, n);
const argv = process.argv.slice(2);
// lê o stdin até o fim, como o claude de verdade: se o servidor não fechar o stdin, trava aqui e o teste falha
process.stdin.on('data', () => {});
process.stdin.on('end', () => {
  fs.appendFileSync(f('claude.log'), JSON.stringify({ argv }) + '\\n');
  if (argv[0] === 'mcp') process.exit(0);
  if (argv[0] === '--version') { console.log('9.9.9 (Claude Code)'); process.exit(0); }
  if (fs.existsSync(f('limite'))) { fs.unlinkSync(f('limite')); console.log("You've hit your weekly limit · resets Oct 13 at 10am (America/Sao_Paulo)"); process.exit(1); }
  if (fs.existsSync(f('deslogado'))) { fs.unlinkSync(f('deslogado')); console.log('Not logged in · Please run /login'); process.exit(1); }
  if (fs.existsSync(f('sem-sessao')) && argv.includes('--resume')) { fs.unlinkSync(f('sem-sessao')); console.error('No conversation found with session ID: x'); process.exit(1); }
  process.stdout.write(fs.existsSync(f('resposta.txt')) ? fs.readFileSync(f('resposta.txt'), 'utf8') : 'RESPOSTA-FAKE\\n');
});
`);
// yt-dlp: grava legenda e descrição onde o -o mandar, como o de verdade
escrever('stub-ytdlp.js', `
const fs = require('fs'), path = require('path');
const argv = process.argv.slice(2);
fs.appendFileSync(path.join(__dirname, 'ytdlp.log'), JSON.stringify({ argv }) + '\\n');
if (argv[0] === '--version') { console.log('2099.01.01'); process.exit(0); }
const o = argv[argv.indexOf('-o') + 1], url = argv[argv.length - 1], id = url.split('v=').pop(), base = o.replace('%(id)s', id);
fs.writeFileSync(base + '.pt-BR.vtt', 'WEBVTT\\nKind: captions\\nLanguage: pt-BR\\n\\n00:00:01.000 --> 00:00:02.000\\nOlá <c>pessoal</c>\\n\\n00:00:02.000 --> 00:00:03.000\\nOlá pessoal\\n\\n00:00:03.000 --> 00:00:04.000\\nhoje vamos falar de abelhas\\n');
fs.writeFileSync(base + '.description', 'Descrição do vídeo\\nhttps://exemplo.com/link\\n');
`);
// voz e tocador (say/afplay no Mac, powershell no Windows): anota programa, argumentos e as variáveis que importam
escrever('stub-voz.js', `
const fs = require('fs'), path = require('path');
const [prog, ...argv] = process.argv.slice(2);
fs.appendFileSync(path.join(__dirname, 'voz.log'), JSON.stringify({ prog, argv, env: { JARVIS_FALA: process.env.JARVIS_FALA, JARVIS_WAV: process.env.JARVIS_WAV } }) + '\\n');
`);
escrever('stub-nada.js', 'process.exit(0)');
const stub = (arq, ...extra) => [process.execPath, path.join(BIN, arq), ...extra];
const STUBS = {
  claude: stub('stub-claude.js'), 'yt-dlp': stub('stub-ytdlp.js'),
  say: stub('stub-voz.js', 'say'), afplay: stub('stub-voz.js', 'afplay'), powershell: stub('stub-voz.js', 'powershell'),
  open: stub('stub-nada.js'), explorer: stub('stub-nada.js'),
};
const YTDLP = path.join(BIN, WIN ? 'yt-dlp.exe' : 'yt-dlp');
fs.writeFileSync(YTDLP, '');   // o servidor confere que o arquivo existe; quem roda é o dublê

execFileSync(process.execPath, [path.join(APP, 'scripts/montar-brain.js'), path.join(APP, 'modelo-brain'), BRAIN, 'Teste', 'pt']);
const APPT = path.join(T, 'app');
fs.mkdirSync(APPT);
// server.js COPIADO (o Node resolve symlink no __dirname e leria o config do app de verdade).
// Pasta linkada como "junction" no Windows: symlink comum lá pede administrador.
fs.copyFileSync(path.join(APP, 'server.js'), path.join(APPT, 'server.js'));
for (const f of ['public', 'voz', 'node_modules']) fs.symlinkSync(path.join(APP, f), path.join(APPT, f), WIN ? 'junction' : 'dir');
fs.writeFileSync(path.join(APPT, 'jarvis.config.json'), JSON.stringify({
  userName: 'Teste', brandName: 'Jarvis · Teste', brainDir: BRAIN, brainName: 'Teste Brain',
  ytdlp: YTDLP, voz: { ativa: true, motor: 'say', say: 'Luciana' },
}));

let falhas = 0, total = 0;
const ok = (cond, nome, extra = '') => { total++; if (cond) console.log('  ✓ ' + nome); else { falhas++; console.log('  ✗ ' + nome + (extra ? '  → ' + extra : '')); } };
const espera = ms => new Promise(r => setTimeout(r, ms));
const lerLog = f => { try { return fs.readFileSync(path.join(BIN, f), 'utf8'); } catch { return ''; } };
const chamadas = f => lerLog(f).trim().split('\n').filter(Boolean).map(l => JSON.parse(l));
const ultimaChamada = f => (chamadas(f).pop() || { argv: [] }).argv;
function req(metodo, rota, corpo, headers = {}) {
  return new Promise(resolve => {
    const dados = corpo ? JSON.stringify(corpo) : null;
    const r = http.request({ host: '127.0.0.1', port: PORT, path: rota, method: metodo,
      headers: { Host: `localhost:${PORT}`, ...(dados ? { 'Content-Type': 'application/json' } : {}), ...headers } }, res => {
      let b = ''; res.on('data', c => b += c); res.on('end', () => { let j = null; try { j = JSON.parse(b); } catch {} resolve({ status: res.statusCode, body: b, json: j, headers: res.headers }); });
    });
    r.on('error', e => resolve({ status: 0, body: String(e) }));
    r.setTimeout(5000, () => { r.destroy(); resolve({ status: 0, body: 'sem resposta em 5 s' }); });   // servidor travado = falha, não espera eterna
    if (dados) r.write(dados); r.end();
  });
}
function conversar(texto, origem = ORIGEM) {
  return new Promise(resolve => {
    const ws = new WebSocket(`ws://127.0.0.1:${PORT}`, { origin: origem, headers: { Host: `localhost:${PORT}` } });
    const got = []; let fim = null;
    ws.on('open', () => { if (texto) ws.send(JSON.stringify({ type: 'voice_message', text: texto })); });
    ws.on('message', m => { const d = JSON.parse(m); got.push(d); if (d.type === 'jarvis_response' || (!texto && d.type === 'greeting')) { clearTimeout(fim); ws.close(); resolve({ aceito: true, got }); } });
    ws.on('error', () => resolve({ aceito: false, got }));
    fim = setTimeout(() => { ws.terminate(); resolve({ aceito: got.length > 0, got, timeout: true }); }, 10000);
  });
}
async function esperarClaude(trecho, ms = 8000) {
  for (let t = 0; t < ms; t += 150) { if (lerLog('claude.log').includes(trecho)) return true; await espera(150); }
  return false;
}

(async () => {
  // clima falso: JSON válido, mas sem os campos que o wttr.in costuma mandar (derrubava o her-jarvis)
  const clima = http.createServer((q, s) => { s.setHeader('Content-Type', 'application/json'); s.end('{"current_condition":[],"weather":[]}'); });
  await new Promise(r => clima.listen(0, '127.0.0.1', r));

  // ambiente LIMPO: um BRAIN_DIR/WIKI_PATH exportado na shell faria o teste escrever no Brain de verdade
  const ambiente = { ...process.env, PORT: String(PORT), CLAUDE_BIN: path.join(BIN, 'claude'), JARVIS_STUBS: JSON.stringify(STUBS),
    JARVIS_SEM_NAVEGADOR: '1', JARVIS_CLIMA_URL: `http://127.0.0.1:${clima.address().port}/` };
  for (const k of ['BRAIN_DIR', 'WIKI_PATH', 'JARVIS_BRAIN_DIR', 'JARVIS_WIKI_PATH', 'JARVIS_SEM_CLIMA']) delete ambiente[k];
  const srv = spawn(process.execPath, ['server.js'], { cwd: APPT, env: ambiente });
  let saida = ''; srv.stdout.on('data', d => saida += d); srv.stderr.on('data', d => saida += d);
  let morreu = false; srv.on('exit', () => { morreu = true; });
  for (let i = 0; i < 60 && !(await req('GET', '/api/config')).json; i++) await espera(150);

  // GUARDA: antes de qualquer escrita, prova que o servidor está no Brain de TESTE
  const onde = (await req('GET', '/api/brain')).json?.brainDir;
  if (path.resolve(onde || '') !== path.resolve(BRAIN)) { console.log('\n✗ ABORTADO: o servidor apontou pra ' + onde + ' em vez do Brain de teste. Nada foi escrito.\n' + saida.slice(-800)); srv.kill(); clima.close(); process.exit(2); }

  console.log(`\nServidor (${WIN ? 'Windows' : process.platform === 'darwin' ? 'Mac' : process.platform})`);
  ok((await req('GET', '/api/config')).json?.userName === 'Teste', 'sobe e lê o config');
  const pag = await req('GET', '/');
  ok(pag.status === 200, 'serve o painel');
  ok(/frame-ancestors 'none'/.test(pag.headers?.['content-security-policy'] || '') && pag.headers?.['x-frame-options'] === 'DENY' && /img-src 'self' data:/.test(pag.headers?.['content-security-policy'] || ''), 'painel não pode ser embutido em outro site e só carrega imagem daqui (CSP no cabeçalho)');

  console.log('\nClima com resposta estranha');
  ok((await req('GET', '/api/weather')).json?.error === 'unavailable', 'clima malformado vira "indisponível"');
  const sauda = await conversar(null);
  ok(sauda.got.some(d => d.type === 'greeting' && /Jarvis online/.test(d.text)), 'saudação sai mesmo sem clima');
  await espera(300);
  ok(!morreu && (await req('GET', '/api/config')).status === 200, 'servidor continua de pé (no her-jarvis isso derrubava e abria aba em laço)');

  console.log('\nSegurança');
  ok((await req('GET', '/api/config', null, { Host: 'site-malicioso.example' })).status === 403, 'recusa Host de outro site (DNS rebinding)');
  ok((await req('POST', '/api/aba', { nome: 'x' }, { Origin: 'https://site-malicioso.example' })).status === 403, 'recusa POST vindo de outro site');
  const mal = await conversar('ordem de outro site', 'https://site-malicioso.example');
  ok(!mal.aceito, 'recusa WebSocket de outro site');
  ok(!lerLog('claude.log').includes('ordem de outro site'), 'nada de outro site chega no claude');

  console.log('\nConversa e permissões');
  // marcador que não depende de caminho: se a voz passar por um shell, "$(echo INJETADO)" vira só "INJETADO"
  fs.writeFileSync(path.join(BIN, 'resposta.txt'), '- Pronto. Rode $(echo INJETADO) agora.\n');
  const c1 = await conversar("oi, com 'aspas' e $(echo injecao)");
  ok(c1.got.some(d => d.type === 'jarvis_response'), 'mensagem vai pro claude e a resposta volta (stdin fechado)');
  const a1 = ultimaChamada('claude.log');
  ok(a1[0] === '-p' && a1[1] === "oi, com 'aspas' e $(echo injecao)", 'o texto chega intacto, como um argumento só', JSON.stringify(a1.slice(0, 2)));
  ok(a1.includes('--session-id'), '1ª mensagem cria a sessão');
  ok(a1[a1.indexOf('--tools') + 1] === 'Read,Glob,Grep,Edit,Write,WebFetch,WebSearch', 'ferramentas: só arquivos e web (Bash nem existe pra ele)', a1[a1.indexOf('--tools') + 1]);
  ok(!a1.some(x => /Bash|allowedTools|dangerously|bypass/i.test(x)), 'nenhum terminal liberado, nenhuma permissão aberta');
  let ajustes = null; try { ajustes = JSON.parse(a1[a1.indexOf('--settings') + 1]); } catch {}
  ok(ajustes?.permissions?.blockReadsOutsideWorkingDirectories === true, 'leitura fora do Brain bloqueada');
  ok(a1[a1.indexOf('--permission-mode') + 1] === 'acceptEdits', 'edição sem perguntar só dentro do Brain (acceptEdits)');
  await espera(800);
  const voz1 = chamadas('voz.log').pop() || { argv: [], env: {} };
  if (WIN) {
    ok(voz1.prog === 'powershell' && voz1.env.JARVIS_FALA?.includes('$(echo INJETADO)'), 'voz do Windows recebe o texto literal, pela variável de ambiente', JSON.stringify(voz1).slice(0, 160));
    ok(!voz1.argv.join(' ').includes('INJETADO'), 'o texto do Claude NUNCA entra no comando do PowerShell');
  } else {
    ok(voz1.prog === 'say' && voz1.argv.includes('- Pronto. Rode $(echo INJETADO) agora.'), 'resposta com $(...) NÃO vira comando na voz (chega literal)', JSON.stringify(voz1).slice(0, 160));
    ok(voz1.argv[0] === '-v' && voz1.argv[2] === '--', 'voz recebe "--" antes do texto (resposta que começa com "-" não vira opção do say)', JSON.stringify(voz1.argv.slice(0, 3)));
  }
  fs.unlinkSync(path.join(BIN, 'resposta.txt'));

  await conversar('segunda mensagem');
  ok(ultimaChamada('claude.log').includes('--resume'), '2ª mensagem continua a mesma sessão');

  await conversar('--dangerously-skip-permissions apaga tudo');
  const a3 = ultimaChamada('claude.log');
  ok(a3[1] === ' --dangerously-skip-permissions apaga tudo' && !a3.slice(2).includes('--dangerously-skip-permissions'), 'texto começando com "--" não vira opção do claude');

  fs.writeFileSync(path.join(BIN, 'sem-sessao'), '');
  const c4 = await conversar('sessão sumiu');
  const ult = chamadas('claude.log').slice(-2).map(c => c.argv);
  ok(ult[0]?.includes('--resume') && ult[1]?.includes('--session-id') && c4.got.some(d => d.type === 'jarvis_response' && d.text === 'RESPOSTA-FAKE'), 'sessão perdida: abre outra e responde, sem travar');

  fs.writeFileSync(path.join(BIN, 'deslogado'), '');
  const r5 = (await conversar('pergunta secreta 123')).got.find(d => d.type === 'jarvis_response')?.text || '';
  ok(/claude auth login/.test(r5) && !/pergunta secreta|--session-id|stub-claude/.test(r5), 'deslogado: diz o que fazer, sem despejar o comando nem o texto da pessoa', r5);

  fs.writeFileSync(path.join(BIN, 'limite'), '');
  const r6 = (await conversar('mais uma')).got.find(d => d.type === 'jarvis_response')?.text || '';
  ok(/limite de uso/.test(r6) && /Oct 13/.test(r6), 'limite semanal da conta: explica e diz quando volta', r6);

  console.log('\nYouTube (o servidor baixa; o Claude só lê)');
  const y1 = await req('POST', '/api/youtube', { url: 'https://youtu.be/AbCdEfGhIjK?t=10' });
  ok(y1.json?.ok && y1.json.id === 'AbCdEfGhIjK', 'aceita link do YouTube e extrai o id');
  ok(await esperarClaude('AbCdEfGhIjK.txt'), 'depois de baixar, pede ao Claude pra ler os arquivos já prontos');
  const yarg = ultimaChamada('ytdlp.log');
  ok(yarg[0] === '--ignore-config' && yarg.includes('--') && yarg[yarg.length - 1] === 'https://www.youtube.com/watch?v=AbCdEfGhIjK', 'yt-dlp com argumentos fixos e URL reconstruída', JSON.stringify(yarg));
  const txt = fs.readFileSync(path.join(BRAIN, 'raw', 'videos', 'AbCdEfGhIjK.txt'), 'utf8');
  ok(txt === 'Olá pessoal\nhoje vamos falar de abelhas', 'legenda vira texto limpo (sem horário, tag nem linha repetida)', JSON.stringify(txt));
  const antesYt = lerLog('ytdlp.log');
  const y2 = await req('POST', '/api/youtube', { url: 'https://site-malicioso.example/watch?v=AbCdEfGhIjK' });
  const y3 = await req('POST', '/api/youtube', { url: 'https://youtube.com/watch?v=AbCdEfGhIjK --exec "rm -rf ~"' });
  const y4 = await req('POST', '/api/youtube', { url: '--exec=touch /tmp/x' });
  ok(y2.status === 400 && y3.status === 400 && y4.status === 400 && lerLog('ytdlp.log') === antesYt, 'link que não é do YouTube, ou com opção embutida, é recusado sem rodar nada');

  console.log('\nAbas (pastas do Brain)');
  const nomes = ((await req('GET', '/api/wiki')).json?.abas || []).map(a => a.pasta + ':' + a.label).join(',');
  ok(nomes === 'ideias:Ideias,memoria:Memória,projetos:Projetos', 'abas iniciais com rótulo com acento', nomes);
  const a1b = await req('POST', '/api/aba', { nome: 'Receitas da Vovó', ico: '🍳' });
  ok(a1b.json?.ok && a1b.json.pasta === 'receitas-da-vovo' && fs.existsSync(path.join(BRAIN, 'wiki', 'receitas-da-vovo', 'sobre.md')), 'botão Nova aba cria a pasta e a 1ª página');
  const nova = ((await req('GET', '/api/wiki')).json?.abas || []).find(a => a.pasta === 'receitas-da-vovo');
  ok(nova?.label === 'Receitas da Vovó' && nova?.ico === '🍳' && nova.paginas.length === 1, 'aba nova aparece com nome, ícone e página');
  ok((await req('POST', '/api/aba', { nome: 'Receitas da Vovó' })).json?.ok === false, 'não duplica aba');
  ok((await req('POST', '/api/aba', { nome: '../../etc' })).json?.pasta === 'etc' && !fs.existsSync(path.join(T, 'etc')), 'nome com ../ não sai da pasta do Brain');
  fs.mkdirSync(path.join(BRAIN, 'wiki', 'feita-no-obsidian'));
  fs.writeFileSync(path.join(BRAIN, 'wiki', 'feita-no-obsidian', 'nota.md'), '# Nota\n\nLiga em [[projetos/sobre]].');
  ok(((await req('GET', '/api/wiki')).json?.abas || []).some(a => a.pasta === 'feita-no-obsidian' && a.label === 'Feita No Obsidian'), 'pasta criada à mão (Obsidian) vira aba');
  const g = await req('GET', '/api/graph');
  ok(g.json?.edges?.some(e => [e.source, e.target].includes('feita-no-obsidian/nota') && [e.source, e.target].includes('projetos/sobre')), 'grafo liga as páginas pelos [[links]]');
  const b = await req('GET', '/api/brain');
  ok(b.json?.legivel === true && b.json?.stats?.memoria === 1 && /\] create · Aba \.\.\/\.\.\/etc$/.test(b.json?.recentLog?.[0] || ''), 'status do Brain: legível, contagem e atividade mais recente primeiro', JSON.stringify(b.json?.recentLog?.slice(0, 2)));
  const abasArq = path.join(BRAIN, 'wiki', '.abas.json');
  fs.writeFileSync(abasArq, '{ isto não é json');
  await req('POST', '/api/aba', { nome: 'Depois do erro' });
  ok(fs.readFileSync(abasArq, 'utf8') === '{ isto não é json', '.abas.json quebrado não é sobrescrito (os rótulos antigos não somem)');

  console.log('\nEmail');
  const fila = path.join(BRAIN, '.fila-email');
  fs.writeFileSync(path.join(fila, 'teste.json'), JSON.stringify({ to: 'ana@exemplo.com', subject: 'Oi', body: 'Teste' }));
  fs.writeFileSync(path.join(fila, 'ruim.json'), JSON.stringify({ to: 'sem-arroba', subject: 'x' }));
  fs.writeFileSync(path.join(fila, 'nulo.json'), 'null');
  fs.writeFileSync(path.join(fila, 'lista.json'), '[{"to":"a@b.com"}]');
  await espera(2000);
  const pend = ((await req('GET', '/api/emails')).json?.emails || []).filter(e => e.status === 'pending');
  ok(pend.length === 1 && pend[0].to === 'ana@exemplo.com', 'email que o Jarvis escreve cai na fila de aprovação');
  ok(['ruim.json', 'nulo.json', 'lista.json'].every(f => !fs.existsSync(path.join(fila, f))) && !morreu, 'arquivo estranho na fila (null, lista, sem @) é descartado sem derrubar nada');
  const env = await req('POST', '/api/emails/send', { id: pend[0]?.id });
  ok(env.json?.ok === false && /senha de app/.test(env.json?.error || ''), 'sem senha de app: não envia e explica o porquê');

  console.log('\nVoz');
  const v0 = (await req('POST', '/api/voz', { ativa: false })).json;
  const antes = lerLog('voz.log').length;
  await conversar('com a voz desligada');
  await espera(500);
  ok(v0?.ativa === false && lerLog('voz.log').length === antes, 'botão MUDO: responde sem falar');
  await req('POST', '/api/voz', { ativa: true });
  const py = process.env.JARVIS_TESTE_PY, modelo = process.env.JARVIS_TESTE_MODELO;
  if (py && modelo && fs.existsSync(py) && fs.existsSync(modelo)) {
    const r = execFileSync(py, [path.join(APP, 'voz', 'falar.py'), modelo], { input: JSON.stringify({ id: 'abc', texto: 'Teste de voz.' }) + '\n' }).toString();
    const wav = JSON.parse(r.trim().split('\n').pop()).wav;
    ok(wav && fs.statSync(wav).size > 10000, 'Piper gera o áudio');
  } else console.log('  · Piper não indicado (JARVIS_TESTE_PY/JARVIS_TESTE_MODELO): teste do áudio neural pulado');

  ok(!morreu, 'o servidor não caiu em nenhum momento');
  srv.kill(); clima.close();
  console.log(`\n${total - falhas}/${total} passaram` + (falhas ? ` · ${falhas} FALHARAM` : ''));
  if (falhas) console.log('\nsaída do servidor:\n' + saida.slice(-1500));
  try { fs.rmSync(T, { recursive: true, force: true }); } catch {}
  process.exit(falhas ? 1 : 0);
})();
