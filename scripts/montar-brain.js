// Copia o modelo-brain para a pasta do Brain, trocando {{NOME}}, {{BRAIN}}, {{DATA}} e {{IDIOMA}}.
// NUNCA sobrescreve: arquivo que já existe no Brain fica como está (pode ser um cofre antigo).
// Uso: node montar-brain.js <modelo> <destino> <nome> <pt|en>
const fs = require('fs');
const path = require('path');
const [modelo, destino, nome, lang] = process.argv.slice(2);
if (!modelo || !destino || !nome) { console.error('uso: montar-brain.js <modelo> <destino> <nome> <idioma>'); process.exit(2); }
const vars = {
  NOME: nome,
  BRAIN: destino,
  DATA: new Date().toLocaleDateString('sv-SE'),
  IDIOMA: lang === 'en' ? 'inglês' : 'português do Brasil',
};
const trocar = t => t.replace(/\{\{(NOME|BRAIN|DATA|IDIOMA)\}\}/g, (m, k) => vars[k]);
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
console.log(`${criados} arquivos criados, ${mantidos} já existiam e ficaram como estavam`);
