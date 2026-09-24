window.NCN = window.NCN || {};
(() => {
  const SAVE_KEY = 'ncn-save-v1';
  const PHASES = ['opening', 'explore', 'encounter', 'aftermath', 'dawn', 'finale', 'ending'];
  class GameState {
    constructor(data) {
      this.data = data || { version: 1, night: 0, visitor: 0, phase: 'opening', decisions: {}, heard: [], notes: [], asked: [], observed: [], lastAnswer: null, ending: null };
    }
    get night() { return window.NCN.Story.nights[this.data.night]; }
    get visitor() { return window.NCN.Story.visitors[this.data.visitor]; }
    get allies() { return window.NCN.Story.visitors.filter(v => v.human && this.data.decisions[v.id] === 'admit'); }
    get intruders() { return window.NCN.Story.visitors.filter(v => !v.human && this.data.decisions[v.id] === 'admit'); }
    addNote(id, text) {
      if (!this.data.notes.some(note => note.id === id)) this.data.notes.push({ id, text, night: this.data.night + 1 });
    }
    beginExploring() { if (this.data.phase === 'opening') { this.data.phase = 'explore'; this.save(); } }
    openGate() { if (this.data.phase === 'explore') { this.data.phase = 'encounter'; this.data.lastAnswer = null; this.save(); return true; } return false; }
    listen(channel) {
      if (![0, 1].includes(channel) || this.data.phase === 'ending') return false;
      const id = `radio-${this.data.night}-${channel}`;
      if (!this.data.heard.includes(id)) this.data.heard.push(id);
      this.addNote(id, this.night.broadcasts[channel].note);
      this.save(); return true;
    }
    inspect() {
      if (this.data.phase !== 'encounter') return false;
      if (!this.data.observed.includes(this.visitor.id)) this.data.observed.push(this.visitor.id);
      this.addNote(`observe-${this.visitor.id}`, this.visitor.observation);
      this.data.lastAnswer = { kind: 'observation' }; this.save(); return true;
    }
    ask(index) {
      if (this.data.phase !== 'encounter' || !this.visitor.questions[index]) return false;
      const id = `${this.visitor.id}-${index}`;
      if (!this.data.asked.includes(id)) this.data.asked.push(id);
      this.addNote(`question-${id}`, this.visitor.questions[index].note);
      this.data.lastAnswer = { kind: 'question', index }; this.save(); return true;
    }
    decide(choice) {
      if (this.data.phase !== 'encounter' || !['admit', 'refuse'].includes(choice)) return false;
      this.data.decisions[this.visitor.id] = choice;
      this.addNote(`decision-${this.visitor.id}`, `${this.visitor.name}: ${choice === 'admit' ? 'deixei entrar.' : 'mantive do lado de fora.'}`);
      this.data.phase = 'aftermath'; this.data.lastAnswer = null; this.save(); return true;
    }
    advance() {
      const d = this.data;
      if (d.phase === 'aftermath') {
        if (d.visitor === 5) d.phase = 'finale';
        else if (d.visitor % 2 === 1) d.phase = 'dawn';
        else { d.visitor++; d.phase = 'explore'; }
      } else if (d.phase === 'dawn') { d.night++; d.visitor++; d.phase = 'opening'; }
      else return false;
      d.lastAnswer = null; this.save(); return true;
    }
    canConnect() {
      return this.data.heard.includes('radio-2-0') || this.data.asked.includes('davi-0') || this.data.decisions.davi === 'admit' || this.data.decisions.lucia === 'refuse';
    }
    finish(choice) {
      if (this.data.phase !== 'finale' || !['connect', 'silence', 'bus'].includes(choice)) return false;
      if (choice === 'connect' && !this.canConnect()) return false;
      this.data.ending = choice; this.data.phase = 'ending'; this.save(); return true;
    }
    ending() {
      const d = this.data;
      if (d.ending === 'bus') return { id: 'bus', title: 'Próxima parada: a sua voz.', text: 'Você entra no ônibus. Os bancos estão vazios, mas todas as vozes ocupam um lugar. Quando as portas fecham, a sua começa a chamar alguém que ficou na rua.\nO ônibus não parte. Ainda falta gente.', epilogue: 'Na manhã seguinte, alguém ouve você no rádio.' };
      if (d.ending === 'connect') {
        if (this.allies.length >= 2) return { id: 'street', title: 'A rua responde.', text: 'Você tira as pilhas, arranca o fio da antena e espera. As vozes dentro da casa falham no meio de uma sílaba.\nDuas batidas no cano. Três do outro lado. Em poucos minutos, a rua inventa um jeito de conversar que não entrega a voz de ninguém. Quando clareia, vocês levantam o portão juntos.', epilogue: 'A confiança voltou pequena. De uma parede até a outra.' };
        return { id: 'wall', title: 'Do outro lado da parede.', text: 'Você corta o sinal e bate no cano. Por um tempo, nada. Então alguém responde. Pode ser Davi. Pode ser uma pessoa que você nunca deixou chegar perto.\nVocês combinam duas batidas para água, três para comida. Você ainda tem medo. Mas já consegue responder.', epilogue: 'Não saber tudo sobre alguém deixou de ser motivo para abandoná-lo.' };
      }
      if (this.intruders.length > 0) return { id: 'inside', title: 'O silêncio tem companhia.', text: 'Você retira as pilhas e quebra a antena. Quem entrou com uma voz emprestada fica imóvel. Ao amanhecer, só restam roupas vazias.\nA casa está quieta. Você encosta o ouvido na parede. Há gente batendo do outro lado. Desta vez, você escolhe não responder.', epilogue: 'O sinal acabou. O isolamento, não.' };
      if (this.allies.length > 0) return { id: 'home', title: 'Uma casa ainda é uma casa.', text: 'O rádio morre quando a última pilha cai no chão. Você e quem acolheu passam o resto da noite conversando baixo, sem antena, sem gravação.\nQuando o sol aparece na grade, há mais de uma xícara sobre a mesa. Vocês sobreviveram. O resto da rua continua longe.', epilogue: 'Você protegeu quem estava perto. Lá fora, o silêncio continua.' };
      return { id: 'alone', title: 'Ninguém entrou.', text: 'Nenhuma voz atravessou seu portão. Você desliga tudo e sobrevive à última noite.\nDe manhã, encontra café, pão e uma chave de boca junto à grade. Você ficou em segurança. Alguém, mesmo do lado de fora, cuidou de você.', epilogue: 'A casa está intacta. Há uma única xícara na mesa.' };
    }
    save() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(this.data)); return true; } catch { return false; } }
    static load() {
      try {
        const d = JSON.parse(localStorage.getItem(SAVE_KEY));
        if (!d || d.version !== 1 || !Number.isInteger(d.night) || d.night < 0 || d.night > 2 || !Number.isInteger(d.visitor) || d.visitor < 0 || d.visitor > 5 || Math.floor(d.visitor / 2) !== d.night || !PHASES.includes(d.phase)) return null;
        if (!d.decisions || typeof d.decisions !== 'object' || Array.isArray(d.decisions)) return null;
        const visitors = window.NCN.Story.visitors;
        if (Object.entries(d.decisions).some(([id, value]) => !visitors.some(v => v.id === id) || !['admit', 'refuse'].includes(value))) return null;
        if (!['heard', 'notes', 'asked', 'observed'].every(key => Array.isArray(d[key]) && d[key].length <= 100)) return null;
        if (!['heard', 'asked', 'observed'].every(key => d[key].every(value => typeof value === 'string'))) return null;
        if (!d.notes.every(n => n && typeof n.id === 'string' && typeof n.text === 'string' && n.text.length <= 2000 && [1,2,3].includes(n.night))) return null;
        if (d.lastAnswer !== null && (!d.lastAnswer || !['question','observation'].includes(d.lastAnswer.kind) || (d.lastAnswer.kind === 'question' && ![0,1].includes(d.lastAnswer.index)))) return null;
        if (['aftermath','dawn','finale','ending'].includes(d.phase) && !d.decisions[visitors[d.visitor].id]) return null;
        if (d.phase === 'dawn' && (d.visitor % 2 !== 1 || d.night === 2)) return null;
        if (['finale','ending'].includes(d.phase) && d.visitor !== 5) return null;
        if (d.phase === 'ending' ? !['connect','silence','bus'].includes(d.ending) : d.ending !== null) return null;
        return new GameState(d);
      } catch { return null; }
    }
  }
  window.NCN.GameState = GameState;
})();
