// Copia o modelo-brain para a pasta do Brain, trocando os {{MARCADORES}} pelo texto certo
// do sistema da pessoa (Mac ou Windows): os guias mostram o comando que funciona NA MÁQUINA DELA.
// NUNCA sobrescreve: arquivo que já existe no Brain fica como está (pode ser um cofre antigo).
// Uso: node montar-brain.js <modelo> <destino> <nome> <pt|en> [mac|windows]
const fs = require('fs');
const path = require('path');
const [modelo, destino, nome, lang, soArg] = process.argv.slice(2);
if (!modelo || !destino || !nome) { console.error('uso: montar-brain.js <modelo> <destino> <nome> <idioma> [mac|windows]'); process.exit(2); }
const so = soArg || (process.platform === 'win32' ? 'windows' : 'mac');

const comum = {
  NOME: nome,
  BRAIN: destino,
  DATA: new Date().toLocaleDateString('sv-SE'),
  IDIOMA: lang === 'en' ? 'inglês' : 'português do Brasil',
};
// Windows: o terminal padrão do VS Code é o Windows PowerShell 5.1, que NÃO aceita "&&" (por isso o ";")
const PS = f => `powershell -ExecutionPolicy Bypass -File "$HOME\\.jarvis\\app\\${f}"`;
const porSistema = {
  mac: {
    COMPUTADOR: 'Mac', NAVEGADOR_MIC: 'Google Chrome', SEP: '/', ATALHO_SALVAR: 'Cmd+S',
    DIR_JARVIS: '~/.jarvis', ARQ_LOG: '~/.jarvis/logs/jarvis.log',
    CMD_CONTINUAR: `cd "${destino}" && claude --continue`,
    CMD_ABRIR_BRAIN: `cd "${destino}" && claude`,
    CMD_REINICIAR: 'launchctl kickstart -k gui/$(id -u)/com.jarvis.painel',
    CMD_CONSERTAR: 'bash ~/.jarvis/app/instalar.sh',
    CMD_DESINSTALAR: 'bash ~/.jarvis/app/desinstalar.sh',
    CMD_VOZ: 'bash ~/.jarvis/app/instalar.sh --voz',
    CMD_ENV: 'cd ~/.jarvis/app && cp -n .env.example .env && open -e .env',
    TEXTO_VOZ_SISTEMA: 'As opções: vozes neurais do Piper em português do Brasil (faber e cadu, masculinas) ou a voz do Mac (Luciana, feminina). A Luciana fica bem melhor na versão Premium, que é grátis: Ajustes do Sistema → Acessibilidade → Conteúdo Falado → Voz do Sistema → Gerenciar Vozes → Português (Brasil) → Luciana (Premium).',
    AJUSTE_MICROFONE: 'Se o Mac bloquear, vá em Ajustes do Sistema → Privacidade e Segurança → Microfone e ligue o Google Chrome.',
  },
  windows: {
    COMPUTADOR: 'PC', NAVEGADOR_MIC: 'Google Chrome ou Microsoft Edge', SEP: '\\', ATALHO_SALVAR: 'Ctrl+S',
    DIR_JARVIS: '%USERPROFILE%\\.jarvis', ARQ_LOG: '%USERPROFILE%\\.jarvis\\logs\\jarvis.log',
    CMD_CONTINUAR: `cd "${destino}"; claude --continue`,
    CMD_ABRIR_BRAIN: `cd "${destino}"; claude`,
    CMD_REINICIAR: PS('reiniciar.ps1'),
    CMD_CONSERTAR: PS('instalar.ps1'),
    CMD_DESINSTALAR: PS('desinstalar.ps1'),
    CMD_VOZ: PS('instalar.ps1') + ' -Voz',
    CMD_ENV: 'cd "$HOME\\.jarvis\\app"; if (-not (Test-Path .env)) { Copy-Item .env.example .env }; notepad .env',
    TEXTO_VOZ_SISTEMA: 'As opções: vozes neurais do Piper em português do Brasil (faber e cadu, masculinas) ou a voz do próprio Windows (Maria, feminina). O Piper roda em PC com processador Intel ou AMD; em PC com chip ARM fica a voz do Windows. Se a Maria não aparecer: Configurações → Hora e idioma → Fala → Adicionar vozes → Português (Brasil).',
    AJUSTE_MICROFONE: 'Se o Windows bloquear, vá em Configurações → Privacidade e segurança → Microfone e ligue o acesso para o navegador.',
  },
};
if (!porSistema[so]) { console.error('sistema desconhecido: ' + so); process.exit(2); }
const vars = { ...comum, ...porSistema[so] };
const faltando = new Set();
const trocar = t => t.replace(/\{\{([A-Z_]+)\}\}/g, (m, k) => (k in vars ? vars[k] : (faltando.add(k), m)));

let criados = 0, mantidos = 0;
(function copiar(de, para) {
  fs.mkdirSync(para, { recursive: true });
  for (const it of fs.readdirSync(de, { withFileTypes: true })) {
    const a = path.join(de, it.name), b = path.join(para, it.name);
    if (it.isDirectory()) { copiar(a, b); continue; }
    if (fs.existsSync(b)) { mantidos++; continue; }
    const txt = /\.(md|json|txt)$/.test(it.name);
    fs.writeFileSync(b, txt ? trocar(fs.readFileSync(a, 'utf8')) : fs.readFileSync(a));
    criados++;
  }
})(modelo, destino);
for (const d of ['raw/videos', '.fila-email']) fs.mkdirSync(path.join(destino, d), { recursive: true });
if (faltando.size) { console.error('marcador sem valor no modelo: ' + [...faltando].join(', ')); process.exit(3); }
console.log(`${criados} arquivos criados, ${mantidos} já existiam e ficaram como estavam`);
