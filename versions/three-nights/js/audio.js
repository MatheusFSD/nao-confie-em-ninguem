window.NCN = window.NCN || {};
(() => {
  class Soundscape {
    constructor() { this.context = null; this.master = null; this.enabled = false; this.sources = []; }
    async toggle() {
      if (this.enabled) { this.enabled = false; await this.context?.suspend(); return false; }
      try {
        if (!this.context) this.create();
        await this.context.resume(); this.enabled = true; return true;
      } catch { this.enabled = false; return false; }
    }
    create() {
      const Audio = window.AudioContext || window.webkitAudioContext;
      if (!Audio) throw new Error('Audio indisponível');
      this.context = new Audio();
      const ctx = this.context;
      this.master = ctx.createGain(); this.master.gain.value = .18; this.master.connect(ctx.destination);
      const noise = ctx.createBuffer(1, ctx.sampleRate * 4, ctx.sampleRate);
      const samples = noise.getChannelData(0);
      let last = 0;
      for (let i = 0; i < samples.length; i++) { last = (last + (Math.random() * 2 - 1) * .02) / 1.02; samples[i] = last * 3; }
      const source = ctx.createBufferSource(); source.buffer = noise; source.loop = true;
      const filter = ctx.createBiquadFilter(); filter.type = 'lowpass'; filter.frequency.value = 380;
      const gain = ctx.createGain(); gain.gain.value = .13;
      source.connect(filter); filter.connect(gain); gain.connect(this.master); source.start(); this.sources.push(source);
      const hum = ctx.createOscillator(); hum.type = 'sine'; hum.frequency.value = 60;
      const humGain = ctx.createGain(); humGain.gain.value = .035; hum.connect(humGain); humGain.connect(this.master); hum.start(); this.sources.push(hum);
    }
    tone(frequency, duration, volume, offset = 0, type = 'sine') {
      if (!this.enabled || this.context?.state !== 'running') return;
      const ctx = this.context, start = ctx.currentTime + offset;
      const oscillator = ctx.createOscillator(), gain = ctx.createGain();
      oscillator.type = type; oscillator.frequency.setValueAtTime(frequency, start);
      gain.gain.setValueAtTime(.0001, start); gain.gain.exponentialRampToValueAtTime(volume, start + .008); gain.gain.exponentialRampToValueAtTime(.0001, start + duration);
      oscillator.connect(gain); gain.connect(this.master); oscillator.start(start); oscillator.stop(start + duration + .02);
      oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); };
    }
    knock() { [0,.27,.61].forEach(t => this.tone(125, .15, .55, t, 'triangle')); }
    radio() { this.tone(730,.16,.065,0,'sawtooth'); this.tone(210,.23,.09,.07,'triangle'); }
    latch() { this.tone(190,.18,.2,0,'triangle'); this.tone(75,.2,.28,.12,'sine'); }
    async visibility(hidden) { try { if (this.enabled && this.context) await (hidden ? this.context.suspend() : this.context.resume()); } catch { /* Navegadores podem pedir outro gesto para retomar. */ } }
    close() { this.sources.forEach(source => { try { source.stop(); } catch {} }); this.context?.close().catch(() => {}); }
  }
  window.NCN.Soundscape = Soundscape;
})();
