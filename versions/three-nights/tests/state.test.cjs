const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function environment(storageFailure = false) {
  const storage = new Map();
  const context = vm.createContext({ window: {}, localStorage: {
    getItem(key) { if (storageFailure) throw new Error('blocked'); return storage.get(key) || null; },
    setItem(key,value) { if (storageFailure) throw new Error('blocked'); storage.set(key,value); }
  }});
  for (const file of ['story.js','state.js']) vm.runInContext(fs.readFileSync(path.join(__dirname,'../js',file),'utf8'),context);
  return { State: context.window.NCN.GameState, storage };
}

function toFinale(State, decisions, investigate = false) {
  let state = new State();
  for (let visitor = 0; visitor < 6; visitor++) {
    if (state.data.phase === 'opening') state.beginExploring();
    assert.equal(state.data.visitor,visitor);
    assert.equal(state.data.night,Math.floor(visitor / 2));
    assert.equal(state.openGate(),true);
    if (investigate) { state.listen(0); state.listen(1); state.inspect(); state.ask(0); state.ask(1); }
    assert.equal(state.decide(decisions[visitor]),true);
    assert.equal(state.decide('admit'),false,'duplo clique não substitui a decisão');
    const loaded = State.load(); assert.ok(loaded,'progresso pode ser retomado após cada decisão');
    state = loaded;
    state.advance();
    if (state.data.phase === 'dawn') state.advance();
  }
  assert.equal(state.data.phase,'finale');
  return state;
}

test('64 combinações de visitas chegam ao final; todos os seis desfechos são alcançáveis', () => {
  const endings = new Set();
  for (let mask = 0; mask < 64; mask++) {
    for (const choice of ['connect','silence','bus']) {
      const { State } = environment();
      const decisions = Array.from({length:6},(_,i) => (mask & (1 << i)) ? 'admit' : 'refuse');
      const state = toFinale(State,decisions,true);
      assert.equal(state.finish(choice),true);
      assert.equal(state.data.phase,'ending');
      const result = state.ending(); endings.add(result.id);
      assert.ok(result.title.length > 5 && result.text.length > 100);
      assert.equal(State.load().ending().id,result.id);
      assert.equal(state.finish('bus'),false,'final não muda com clique duplicado');
      assert.equal(state.advance(),false,'não ultrapassa a última noite');
    }
  }
  assert.deepEqual([...endings].sort(),['alone','bus','home','inside','street','wall']);
});

test('nenhuma leitura é obrigatória para decidir; pistas só aparecem depois da investigação', () => {
  const { State } = environment();
  const state = new State();
  assert.equal(state.openGate(),false);
  assert.equal(state.decide('admit'),false);
  state.beginExploring(); state.openGate();
  assert.equal(state.data.notes.length,0);
  state.inspect(); state.inspect();
  assert.equal(state.data.notes.length,1);
  state.ask(1); state.ask(1);
  assert.equal(state.data.notes.length,2);
  assert.equal(state.data.notes.some(note => note.id === 'question-celina-0'),false);
  state.listen(0); state.listen(0);
  assert.equal(state.data.notes.length,3);
  assert.equal(state.data.heard.length,1);
  assert.equal(state.decide('refuse'),true);
});

test('ajuda pelo cano pode ser descoberta na última decisão; recusar todos continua jogável', () => {
  const { State } = environment();
  const state = toFinale(State,['refuse','refuse','refuse','admit','refuse','refuse']);
  assert.equal(state.canConnect(),false);
  assert.equal(state.finish('connect'),false);
  state.listen(0);
  assert.equal(state.canConnect(),true);
  assert.equal(state.finish('connect'),true);
  assert.equal(state.ending().id,'wall');
  const isolated = toFinale(State,Array(6).fill('refuse'));
  isolated.finish('silence');
  assert.equal(isolated.ending().id,'alone');
});

test('acolher aliados muda o final coletivo; admitir imitações muda o final isolado', () => {
  const { State } = environment();
  const community = toFinale(State,['admit','refuse','refuse','admit','admit','refuse']);
  community.finish('connect'); assert.equal(community.ending().id,'street');
  const invasion = toFinale(State,['refuse','admit','admit','refuse','refuse','admit']);
  invasion.finish('silence'); assert.equal(invasion.ending().id,'inside');
});

test('salvamento corrompido é descartado; armazenamento bloqueado não impede jogar', () => {
  const { State,storage } = environment();
  for (const broken of ['bad json','null','{}',JSON.stringify({version:1,night:7})]) { storage.set('ncn-save-v1',broken); assert.equal(State.load(),null); }
  const state = new State(); state.save();
  const valid = JSON.parse(storage.get('ncn-save-v1'));
  for (const change of [{visitor:5},{notes:[null]},{phase:'ending'},{asked:42},{decisions:{celina:'wrong'}},{lastAnswer:{kind:'question',index:99}}]) {
    storage.set('ncn-save-v1',JSON.stringify({...valid,...change})); assert.equal(State.load(),null);
  }
  const blocked = environment(true); const offline = new blocked.State();
  assert.equal(offline.save(),false); assert.equal(blocked.State.load(),null);
  offline.beginExploring(); offline.openGate(); assert.equal(offline.decide('admit'),true);
});
