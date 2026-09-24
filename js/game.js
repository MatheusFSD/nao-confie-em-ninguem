// Uma visita e uma decisão. Conteúdo e controle têm classes próprias.
class Visit {
  constructor() {
    this.name = 'Dona Celina';
    this.introduction = '“Meu bem… posso ficar aí um pouco? Tem alguém falando na minha cozinha. A voz é igual à do meu filho.”';
    this.question = 'Seu filho não mora em Minas?';
    this.answer = '“Mora. Eu liguei pra ele. Ele atendeu.”\nEla aperta as chaves na mão.\n“Mas a voz continuava na cozinha.”';
    this.outcomes = {
      open: {
        title: 'Mais uma xícara na mesa.',
        text: 'Celina entra e se senta perto de você. O rádio repete o aviso para não atender ninguém.\n“Pode abaixar isso?”, ela pede. Vocês esperam o dia nascer.'
      },
      refuse: {
        title: 'Os passos se afastam.',
        text: '“Tudo bem, meu bem.” Celina deixa uma sacola com pão junto à grade e vai embora.\nO rádio repete o aviso. Você passa a noite escutando o portão.'
      }
    };
  }
}

class Game {
  constructor(root) {
    this.root = root;
    this.visit = new Visit();
    this.phase = 'room';
    this.asked = false;
    this.title = root.querySelector('#scene-title');
    this.text = root.querySelector('#scene-text');
    this.label = root.querySelector('#scene-label');
    this.choices = root.querySelector('#choices');
    this.radio = root.querySelector('#radio-dialog');
    root.addEventListener('click', event => {
      const button = event.target.closest('button[data-action]');
      if (button) this.act(button.dataset.action);
    });
    root.querySelector('#close-radio').addEventListener('click', () => this.radio.close());
    this.render();
  }

  button(label, action, style = '') {
    const button = document.createElement('button');
    button.className = ('choice ' + style).trim();
    button.textContent = label;
    button.dataset.action = action;
    return button;
  }

  act(action) {
    if (action === 'radio' && this.phase !== 'end') {
      this.radio.showModal();
      return;
    }
    if (action === 'gate' && this.phase === 'room') this.phase = 'visit';
    else if (action === 'ask' && this.phase === 'visit') this.asked = true;
    else if (['open', 'refuse'].includes(action) && this.phase === 'visit') {
      this.outcome = this.visit.outcomes[action];
      this.phase = 'end';
    } else if (action === 'restart' && this.phase === 'end') {
      this.phase = 'room';
      this.asked = false;
      this.outcome = null;
    } else return;
    this.render();
    this.title.focus({ preventScroll: true });
  }

  render() {
    this.root.dataset.phase = this.phase;
    this.root.querySelector('#room-actions').hidden = this.phase !== 'room';
    this.root.querySelector('#visitor').hidden = this.phase !== 'visit';
    this.choices.replaceChildren();
    if (this.phase === 'room') {
      this.label.textContent = 'UMA NOITE EM CASA';
      this.title.textContent = 'Bateram no portão.';
      this.text.textContent = 'A rua está vazia desde cedo. Alguém chama você baixinho, do outro lado da grade.';
    } else if (this.phase === 'visit') {
      this.label.textContent = 'SUA VIZINHA ESTÁ DO LADO DE FORA';
      this.title.textContent = this.visit.name;
      this.text.textContent = this.asked ? this.visit.answer : this.visit.introduction;
      if (!this.asked) this.choices.append(this.button(this.visit.question, 'ask'));
      this.choices.append(
        this.button('Abrir o portão', 'open', 'choice-primary'),
        this.button('Não abrir', 'refuse'),
        this.button('Ouvir o rádio', 'radio', 'choice-quiet')
      );
    } else {
      this.label.textContent = 'FIM DESTA CENA';
      this.title.textContent = this.outcome.title;
      this.text.textContent = this.outcome.text;
      this.choices.append(this.button('Jogar a cena de novo', 'restart', 'choice-primary'));
    }
  }
}

new Game(document.querySelector('#game'));

