window.NCN = window.NCN || {};
(() => {
  class Game {
    constructor() {
      this.state = null;
      this.saved = window.NCN.GameState.load();
      this.view = new window.NCN.GameView();
      this.audio = new window.NCN.Soundscape();
      this.view.showMenu(this.saved);
      this.bindEvents();
    }
    bindEvents() {
      document.getElementById('start-game').addEventListener('click', () => this.saved ? this.view.showRestart() : this.start());
      document.getElementById('continue-game').addEventListener('click', () => { if (this.saved) { this.state = this.saved; this.view.render(this.state, true); } });
      document.getElementById('close-detail').addEventListener('click', () => this.view.closeDialog());
      this.view.dialog.addEventListener('close', () => {
        this.view.dialogKind = null;
        // Ao ouvir a pista final, a escolha dos canos pode ter sido liberada.
        if (this.state?.data.phase === 'finale') this.view.render(this.state);
      });
      document.getElementById('sound-toggle').addEventListener('click', () => this.toggleSound());
      const full = document.getElementById('fullscreen-toggle');
      if (!document.fullscreenEnabled) full.hidden = true;
      full.addEventListener('click', () => this.toggleFullscreen());
      document.addEventListener('fullscreenchange', () => {
        const label = document.fullscreenElement ? 'Sair da tela cheia' : 'Entrar em tela cheia'; full.setAttribute('aria-label',label); full.title = label;
      });
      document.getElementById('game').addEventListener('click', event => {
        const button = event.target.closest('button[data-action]');
        if (button && !button.disabled) this.act(button.dataset.action);
      });
      document.addEventListener('keydown', event => {
        if (event.repeat || event.ctrlKey || event.altKey || event.metaKey || this.view.dialog.open || event.target.closest('input,textarea,select')) return;
        const key = event.key.toLowerCase();
        if (!['r','p','c','m','f'].includes(key)) return;
        if (key === 'm') this.toggleSound();
        else if (key === 'f') this.toggleFullscreen();
        else if (this.state) this.act({r:'radio',p:'gate',c:'journal'}[key]);
        event.preventDefault();
      });
      document.addEventListener('visibilitychange', () => this.audio.visibility(document.hidden));
      window.addEventListener('pagehide', () => { this.state?.save(); this.audio.visibility(true); });
      window.addEventListener('pageshow', () => this.audio.visibility(false));
    }
    start() {
      if (this.view.dialog.open) this.view.closeDialog();
      this.state = new window.NCN.GameState(); this.saved = this.state;
      this.state.save(); this.view.render(this.state, true);
    }
    async toggleSound() {
      const enabled = await this.audio.toggle(); this.view.setSound(enabled);
      this.view.announce(enabled ? 'Som ambiente ligado.' : 'Som ambiente desligado.');
    }
    async toggleFullscreen() {
      try {
        if (document.fullscreenElement) await document.exitFullscreen();
        else if (document.fullscreenEnabled) await document.getElementById('game').requestFullscreen();
      } catch { this.view.announce('A tela cheia não está disponível neste navegador.'); }
    }
    listen(channel) {
      if (!this.state || this.state.data.phase === 'ending') return;
      this.state.listen(channel); this.audio.radio(); this.view.updateNotes(this.state); this.view.showRadio(this.state,channel);
    }
    act(action) {
      if (action === 'help') { this.view.showHelp(); return; }
      if (action === 'restart') { this.view.showRestart(); return; }
      if (action === 'cancel-restart') { this.view.closeDialog(); return; }
      if (action === 'confirm-restart') { this.start(); return; }
      if (!this.state) return;
      if (action === 'radio') { this.listen(0); return; }
      if (action.startsWith('tune-')) { this.listen(Number(action.slice(5))); return; }
      if (action === 'journal') { this.view.showJournal(this.state); return; }
      if (action === 'explore') { this.state.beginExploring(); this.audio.knock(); }
      else if (action === 'gate') { if (!this.state.openGate()) return; this.audio.latch(); }
      else if (action === 'inspect') { if (!this.state.inspect()) return; }
      else if (action.startsWith('ask-')) { if (!this.state.ask(Number(action.slice(4)))) return; }
      else if (['admit','refuse'].includes(action)) { if (!this.state.decide(action)) return; this.audio.latch(); }
      else if (action === 'advance') { if (!this.state.advance()) return; if (this.state.data.phase === 'explore') this.audio.knock(); }
      else if (action.startsWith('end-')) { if (!this.state.finish(action.slice(4))) return; this.audio.latch(); }
      else return;
      this.view.render(this.state, true);
      if (action === 'inspect' || action.startsWith('ask-')) this.view.announce(action === 'inspect' ? this.state.visitor.observation : this.state.visitor.questions[Number(action.slice(4))].answer);
    }
  }
  // Exposto somente como ponto de entrada. Conteúdo, estado, som e DOM têm classes próprias.
  window.NCN.game = new Game();
})();
