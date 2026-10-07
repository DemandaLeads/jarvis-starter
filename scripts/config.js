// Grava o jarvis.config.json juntando o que já existe com o que o instalador decidiu.
// Uso: node config.js <arquivo> chave=valor [chave=valor...]   (voz.motor=piper vira {voz:{motor:'piper'}})
const fs = require('fs');
const [arquivo, ...pares] = process.argv.slice(2);
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(arquivo, 'utf8')); } catch {}
for (const par of pares) {
  const i = par.indexOf('='); if (i < 1) continue;
  const chaves = par.slice(0, i).split('.'), bruto = par.slice(i + 1);
  const valor = bruto === 'true' ? true : bruto === 'false' ? false : bruto;
  let alvo = cfg;
  chaves.slice(0, -1).forEach(k => { if (typeof alvo[k] !== 'object' || !alvo[k]) alvo[k] = {}; alvo = alvo[k]; });
  alvo[chaves[chaves.length - 1]] = valor;
}
fs.writeFileSync(arquivo, JSON.stringify(cfg, null, 2) + '\n');
