window.NCN = window.NCN || {};
(() => {
  const $ = id => document.getElementById(id);
  class GameView {
    constructor() { this.dialog = $('detail-dialog'); this.dialogKind = null; }
    button(label, action, style = '', hint = '') {
      const button = document.createElement('button');
      button.className = `action-button ${style}`.trim(); button.dataset.action = action;
      const arrow = document.createElement('span'); arrow.className = 'action-arrow'; arrow.textContent = '↳'; arrow.setAttribute('aria-hidden','true');
      button.append(arrow, document.createTextNode(label));
      if (hint) { const small = document.createElement('small'); small.textContent = hint; button.append(small); }
      return button;
    }
    showMenu(saved) {
      $('game').className = 'game is-menu'; $('menu').hidden = false;
      for (const id of ['night-clock','room-controls','narrative','room-caption','play-tools','visitor-figure']) $(id).hidden = true;
      $('menu-footer').hidden = false;
      $('continue-game').hidden = !saved;
      $('start-game').replaceChildren(Object.assign(document.createElement('span'), {textContent:'↳'}), document.createTextNode(saved ? ' Começar de novo' : ' Apagar a luz. Escutar.'));
    }
    render(state, focus = false) {
      const d = state.data;
      $('game').className = `game is-${d.phase}`;
      $('menu').hidden = true; $('menu-footer').hidden = true; $('night-clock').hidden = false; $('play-tools').hidden = false;
      $('night-label').textContent = `NOITE 0${d.night + 1}`;
      $('time-label').textContent = ['dawn','ending'].includes(d.phase) ? '05:42' : d.phase === 'finale' ? '03:33' : state.visitor.time;
      $('room-controls').hidden = d.phase !== 'explore'; $('room-caption').hidden = d.phase !== 'explore';
      $('narrative').hidden = d.phase === 'explore'; $('visitor-figure').hidden = d.phase !== 'encounter';
      this.updateNotes(state);
      const people = Object.values(d.decisions).filter(value => value === 'admit').length;
      // A interface conta entradas, sem revelar quem é uma imitação.
      $('house-status').textContent = people ? `${people + 1} pessoas dentro de casa.` : 'Só você dentro de casa.';
      const heard = d.heard.filter(id => id.startsWith(`radio-${d.night}-`)).length;
      $('radio-status').textContent = heard === 2 ? 'as duas frequências ouvidas' : 'tem alguma coisa no chiado';
      const actions = $('narrative-actions'); actions.replaceChildren();
      $('inspection').hidden = true;
      if (d.phase === 'opening') {
        this.copy(`NOITE 0${d.night + 1} / 03`, state.night.title, state.night.opening);
        actions.append(this.button('Escutar a casa', 'explore', 'primary', 'O rádio e o portão estão ao seu alcance.'));
      } else if (d.phase === 'explore') {
        $('room-caption').textContent = d.visitor % 2 === 0 ? state.night.caption : 'Os passos anteriores sumiram. Outra pessoa parou junto à grade.';
        const hint = document.createElement('small'); hint.textContent = 'ESCUTE O RÁDIO OU VÁ ATÉ O PORTÃO. A DECISÃO É SUA.'; $('room-caption').append(hint);
      } else if (d.phase === 'encounter') this.renderEncounter(state, actions);
      else if (d.phase === 'aftermath') {
        const result = state.visitor.outcomes[d.decisions[state.visitor.id]];
        this.copy('O TRINCO VOLTA AO LUGAR', result.title, result.text);
        actions.append(this.button(d.visitor === 5 ? 'Voltar para o rádio' : d.visitor % 2 === 1 ? 'Esperar amanhecer' : 'Continuar escutando', 'advance', 'primary'));
      } else if (d.phase === 'dawn') {
        this.copy(`AMANHECER / DEPOIS DA NOITE 0${d.night + 1}`, 'O dia não explica nada.', state.night.dawn);
        actions.append(this.button('Atravessar o dia', 'advance', 'primary', 'A próxima visita vem quando escurecer.'));
      } else if (d.phase === 'finale') {
        this.copy('03:33 / A ÚLTIMA DECISÃO', 'A voz precisa de uma resposta.', 'O rádio está desligado da tomada. As pilhas ainda estão dentro.\nDo lado de fora, o ônibus espera. Do outro lado da parede, duas batidas. Pela primeira vez, nada vem depois. A próxima frase pode ser sua.');
        actions.append(this.button('Cortar o sinal e responder pelos canos', 'end-connect', 'primary', state.canConnect() ? 'Combinar ajuda com as casas ao lado.' : 'Você ainda não sabe como. Escute a faixa 88.3.'));
        actions.lastChild.disabled = !state.canConnect();
        actions.append(this.button('Desligar tudo. Não responder a ninguém.', 'end-silence'), this.button('Sair e entrar no ônibus', 'end-bus', 'danger'), this.button('Ouvir o rádio mais uma vez', 'radio'));
      } else if (d.phase === 'ending') {
        const ending = state.ending();
        this.copy('AMANHECER / FIM DA TRANSMISSÃO', ending.title, ending.text);
        const facts = document.createElement('p'); facts.className = 'ending-facts';
        facts.textContent = `${ending.epilogue}\n\n${state.allies.length} ${state.allies.length === 1 ? 'pessoa acolhida' : 'pessoas acolhidas'} · ${d.notes.filter(note => !note.id.startsWith('decision-')).length} pistas anotadas`;
        actions.append(facts, this.button('Ler o que ficou no caderno', 'journal'), this.button('Voltar à primeira noite', 'restart', 'primary'));
      }
      if (focus && d.phase !== 'explore') $('narrative-title').focus({ preventScroll: true });
      if (focus && d.phase === 'explore') document.querySelector('[data-action="gate"]').focus({ preventScroll: true });
    }
    copy(kicker, title, text) { $('narrative-kicker').textContent = kicker; $('narrative-title').textContent = title; $('narrative-text').textContent = text; }
    updateNotes(state) { $('note-count').textContent = String(state.data.notes.length); }
    renderEncounter(state, actions) {
      const v = state.visitor, d = state.data;
      $('visitor-figure').className = `visitor-figure portrait-${v.portrait}`;
      $('visitor-figure').setAttribute('aria-label', `Retrato de ${v.name}`);
      const answer = d.lastAnswer;
      this.copy(v.kicker, v.name, answer?.kind === 'question' ? v.questions[answer.index].answer : v.line);
      if (answer?.kind === 'observation') { $('inspection').hidden = false; $('inspection').textContent = v.observation; }
      actions.append(this.button(d.observed.includes(v.id) ? 'Olhar de novo' : 'Olhar com atenção', 'inspect'));
      v.questions.forEach((question, i) => {
        const button = this.button(question.label, `ask-${i}`);
        if (d.asked.includes(`${v.id}-${i}`)) { const mark = document.createElement('span'); mark.textContent = ' ✓'; mark.setAttribute('aria-label',' já perguntado'); button.append(mark); }
        actions.append(button);
      });
      const decisions = document.createElement('div'); decisions.className = 'decision-row';
      decisions.append(this.button('Deixar entrar', 'admit', 'primary'), this.button('Não abrir', 'refuse', 'danger'));
      actions.append(decisions);
      const radio = document.createElement('button'); radio.className = 'text-button'; radio.dataset.action = 'radio'; radio.textContent = 'Escutar o rádio antes de decidir [R]'; actions.append(radio);
    }
    openDialog(kind, kicker, title) {
      this.dialogKind = kind;
      this.dialog.className = `detail-dialog is-${kind}`;
      $('detail-kicker').textContent = kicker; $('detail-title').textContent = title; $('detail-content').replaceChildren();
      if (!this.dialog.open) this.dialog.showModal();
      return $('detail-content');
    }
    showRadio(state, channel = 0) {
      const broadcast = state.night.broadcasts[channel];
      const content = this.openDialog('radio', 'RÁDIO DE PILHA / O SINAL AINDA CHEGA', 'Tem alguém na frequência.');
      const frequency = document.createElement('div'); frequency.className = 'radio-frequency'; frequency.textContent = broadcast.frequency;
      const source = document.createElement('small'); source.textContent = 'FM / ' + broadcast.source; frequency.append(source);
      const scale = document.createElement('div'); scale.className = 'radio-scale'; scale.setAttribute('aria-hidden','true');
      const text = document.createElement('p'); text.className = 'radio-broadcast'; text.textContent = broadcast.text;
      const tabs = document.createElement('div'); tabs.className = 'radio-tabs'; tabs.setAttribute('role','group'); tabs.setAttribute('aria-label','Frequência do rádio');
      ['88.3 · Associação', '104.1 · Emergência'].forEach((label, i) => { const button = this.button(label, `tune-${i}`); button.setAttribute('aria-pressed', String(i === channel)); tabs.append(button); });
      const hint = document.createElement('p'); hint.className = 'dialog-hint'; hint.textContent = 'Você anotou o que ouviu no caderno. Uma transmissão também pode mentir.';
      content.append(frequency,scale,text,tabs,hint);
    }
    showJournal(state) {
      const content = this.openDialog('journal', 'CADERNO DA COZINHA', 'Para não esquecer.');
      const intro = document.createElement('p'); intro.className = 'journal-intro'; intro.textContent = 'O que eu vi. O que me disseram. Não é a mesma coisa.'; content.append(intro);
      const list = document.createElement('ol'); list.className = 'journal-notes';
      if (!state.data.notes.length) { const empty = document.createElement('p'); empty.textContent = 'Ainda não escrevi nada. O rádio está no móvel. Alguém espera no portão.'; content.append(empty); }
      for (const note of [...state.data.notes].reverse()) {
        const item = document.createElement('li'), label = document.createElement('small'), text = document.createElement('p');
        label.textContent = `NOITE 0${note.night} / ${note.id.startsWith('radio') ? 'OUVI NO RÁDIO' : note.id.startsWith('decision') ? 'O QUE EU FIZ' : note.id.startsWith('observe') ? 'O QUE EU VI' : 'O QUE ME DISSERAM'}`;
        text.textContent = note.text; item.append(label,text); list.append(item);
      }
      content.append(list);
    }
    showHelp() {
      const content = this.openDialog('help', 'A CASA É TUDO O QUE VOCÊ TEM', 'Antes de tocar no trinco.');
      const steps = document.createElement('ol'); steps.className = 'help-steps';
      for (const [title, text] of [['Escute.', 'O rádio tem duas frequências. Compare o que dizem com a rua e com as visitas.'],['Converse.', 'No portão, observe e faça perguntas. Você pode voltar ao rádio ou ao caderno antes de decidir.'],['Decida.', 'Deixe a pessoa entrar ou mantenha o portão fechado. As escolhas ficam com você até o amanhecer.']]) {
        const item = document.createElement('li'), strong = document.createElement('strong'); strong.textContent = title + ' '; item.append(strong,document.createTextNode(text)); steps.append(item);
      }
      const note = document.createElement('p'); note.textContent = 'Não há cronômetro. O silêncio também é uma escolha. São três noites, seis visitas e uma última decisão.';
      const keys = document.createElement('p'); keys.className = 'help-keys'; keys.textContent = 'R · rádio   P · portão   C · caderno\nEsc · fechar   M · som   F · tela cheia';
      const save = document.createElement('p'); save.className = 'dialog-hint'; save.textContent = 'O progresso é salvo neste navegador quando o armazenamento está disponível. O som é opcional; todas as pistas aparecem por escrito.';
      content.append(steps,note,keys,save);
    }
    showRestart() {
      const content = this.openDialog('restart', 'VOLTAR À PRIMEIRA NOITE', 'Começar de novo?');
      const text = document.createElement('p'); text.textContent = 'A nova partida substitui o progresso salvo neste navegador.';
      const actions = document.createElement('div'); actions.className = 'restart-actions'; actions.append(this.button('Continuar esta partida', 'cancel-restart'),this.button('Começar de novo', 'confirm-restart', 'primary')); content.append(text,actions);
    }
    closeDialog() { this.dialog.close(); this.dialogKind = null; }
    setSound(enabled) { $('sound-toggle').setAttribute('aria-pressed',String(enabled)); $('sound-toggle').setAttribute('aria-label',enabled ? 'Desativar som ambiente' : 'Ativar som ambiente'); $('sound-label').textContent = enabled ? 'Som ligado' : 'Som desligado'; }
    announce(text) { $('announcement').textContent = text; }
  }
  window.NCN.GameView = GameView;
})();
