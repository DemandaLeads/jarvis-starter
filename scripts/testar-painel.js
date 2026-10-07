// Testa o md2h do painel contra XSS e confere que o markdown normal continua formatando.
// Uso: node scripts/testar-painel.js
const vm = require('vm'), fs = require('fs');
const h = fs.readFileSync(process.argv[2] || require("path").join(__dirname, "../public/index.html"), "utf8");
const trecho = (de, ate) => h.slice(h.indexOf(de), h.indexOf(ate, h.indexOf(de)));
const ctx = { wiki: { vendas: [] } }; vm.createContext(ctx);
vm.runInContext(trecho('function escH', '/* RELÓGIO */') + '\n' + trecho('function md2h', '/* SKILLS'), ctx);
const ataques = ['<img src=x onerror=alert(1)>', '![x](a" onerror="alert(1))', '[clique](javascript:alert(1))', '> <script>alert(1)</script>', '```\n</pre><script>alert(1)</script>\n```', '| a | b |\n|---|---|\n| <svg onload=alert(1)> | x |', '[[vendas" onclick="alert(1)]]', '[[x|<img src=x onerror=alert(1)>]]', '*<b onmouseover=alert(1)>oi</b>*'];
let seguro = true;
for (const a of ataques) {
  const o = ctx.md2h(a);
  const vazou = /<(img|svg)[^>]*\son\w+=|<script|href="javascript/i.test(o);
  if (vazou) seguro = false;
  console.log((vazou ? '  ✗ VAZOU   ' : '  ✓ contido ') + JSON.stringify(a).slice(0, 48).padEnd(50) + ' → ' + o.replace(/\n/g, ' ').slice(0, 70));
}
const bom = ctx.md2h('**negrito** e [link](https://exemplo.com)\n\n| A | B |\n|---|---|\n| 1 | 2 |');
const it = ctx.md2h('Peça: *"cria a ficha"* e [[vendas/sobre]] e 2 * 3 * 4');
console.log('  itálico/wikilink → ' + it);
const formatou = it.includes('<em>&quot;cria a ficha&quot;</em>') && it.includes('data-p="vendas"') && it.includes('2 * 3 * 4') && bom.includes('<strong>negrito</strong>') && bom.includes('href="https://exemplo.com"') && bom.includes('<table>');
console.log(formatou ? '  ✓ markdown normal continua formatando' : '  ✗ quebrou a formatação: ' + bom);
process.exit(seguro && formatou ? 0 : 1);
