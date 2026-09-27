const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync(process.argv[2], 'utf8');
assert(!html.includes('onclick="print()"'));
const embedded = html.match(/<script id="data" type="application\/json">([\s\S]*?)<\/script>/)[1];
const nodes = new Map();
const document = {
 getElementById(id) {
  if (!nodes.has(id)) nodes.set(id, {value:['face','tone'].includes(id)?'all':'', textContent:id==='data'?embedded:'',innerHTML:'',addEventListener(){},querySelectorAll(){return []}});
  return nodes.get(id);
 },
 querySelectorAll(){return [];}
};
const context = vm.createContext({document});
const script = html.match(/<\/script><script>([\s\S]*?)<\/script>/)[1];
vm.runInContext(script, context);
assert(document.getElementById('decks').innerHTML.includes('린코의 기본 덱'));
assert(document.getElementById('decks').innerHTML.includes('웃는 잔상의 덱'));
assert.equal((document.getElementById('rows').innerHTML.match(/<tr /g)||[]).length,12);
vm.runInContext("activeDeck='starter';render()",context);
assert.equal(vm.runInContext("copies(cards.find(c=>c.id==='strike'))",context),5);
vm.runInContext("activeDeck='remnant';render()",context);
assert.equal(vm.runInContext("copies(cards.find(c=>c.id==='strike_reverse'))",context),4);
document.getElementById('search').value='없는카드';
vm.runInContext('render()',context);
assert.equal(document.getElementById('empty').hidden,false);
assert.equal(document.getElementById('detail').innerHTML,'');
console.log('HTML unit PASS: print removal, deck tabs, counts, reverse membership, empty search');
