/* Conteúdo narrativo: editar este arquivo não exige alterar a lógica do jogo. */
window.NCN = window.NCN || {};
(() => {
  const nights = [
    {
      title: 'A primeira voz', time: '21:08',
      opening: 'O ventilador parou faz uma hora. Lá fora, nem o bar da esquina está aberto.\nTrês batidas de unha no portão.',
      caption: 'O rádio chia. Alguém chama baixinho do outro lado do portão.',
      broadcasts: [
        { frequency: '88.3', source: 'RÁDIO DA ASSOCIAÇÃO', text: '“Aqui é o Davi, da oficina. A Celina tá procurando um lugar pra passar a noite. A casa dela começou a chamar pelo filho. O filho mora em Minas.\nSe vierem conferir seu medidor, não fui eu que mandei.”', note: 'Davi avisou: Celina procura abrigo. A associação não enviou ninguém para verificar medidores.' },
        { frequency: '104.1', source: 'FAIXA DE EMERGÊNCIA', text: '“A chuva continua em toda a região. Nossas equipes trabalham para que você durma tranquilo.\nAbra a porta para quem cuida de você.”\n\nNão chove em Bento Ribeiro há onze dias.', note: 'O boletim fala de chuva. A rua continua seca há onze dias.' }
      ],
      dawn: 'O dia nasce sem barulho de trem. No rádio, entre dois chiados, alguém repete uma frase dita ontem no seu portão. Com a sua voz.'
    },
    {
      title: 'Duas vezes Lúcia', time: '23:16',
      opening: 'Ontem o rádio repetiu sua voz. Hoje alguém assobia no portão.\nA música que Lúcia inventou quando vocês eram crianças.',
      caption: 'O assobio começa de novo. Sempre no mesmo ponto.',
      broadcasts: [
        { frequency: '88.3', source: 'RÁDIO DA ASSOCIAÇÃO', text: '“Davi de novo. Achei a Lúcia perto da linha. Ela cortou a sobrancelha passando pelo muro da oficina. Saiu pela viela.\nE uma coisa: esse rádio repete o que a gente fala. Não deem mais nomes.”', note: 'Davi encontrou Lúcia. Ela machucou a sobrancelha no muro da oficina e seguiu pela viela.' },
        { frequency: '104.1', source: 'FAIXA DE EMERGÊNCIA', text: 'Uma voz infantil atravessa a estática:\n“Se der medo, a gente se esconde na barriga da baleia.”\n\nEra como vocês chamavam o guarda-roupa. Há três dias, você contou essa história no rádio, pedindo notícias de Lúcia.', note: 'O apelido do guarda-roupa foi transmitido no meu pedido de ajuda. Essa lembrança já não é um segredo.' }
      ],
      dawn: 'Às quatro da manhã, todos os rádios da rua dizem “bom dia” juntos. O sol ainda demora duas horas. Você tira o seu da tomada. O chiado continua.'
    },
    {
      title: 'A casa que responde', time: '02:43',
      opening: 'Um ônibus está parado na esquina, de faróis apagados.\nNo rádio, sua irmã pede para você sair. A gravação é de seis dias atrás.',
      caption: 'A porta do ônibus abre. Ninguém desce. Seu portão volta a bater.',
      broadcasts: [
        { frequency: '88.3', source: 'RÁDIO DA ASSOCIAÇÃO', text: '“É o Davi. Quem tiver ouvindo: a voz só devolve o que a gente entrega. Quando desligamos o transmissor da oficina, ela perdeu a nossa rua por uns minutos.\nDá pra falar com a casa ao lado batendo nos canos. Isso ela ainda não repetiu.”', note: 'Desligar o transmissor interrompeu a voz. Davi propôs conversar pelos canos, fora da transmissão.' },
        { frequency: '104.1', source: 'FAIXA DE EMERGÊNCIA', text: '“A evacuação é segura. Todos os seus familiares já estão aqui.”\n\nDepois, na voz de Lúcia:\n“Se der medo, a gente se esconde na barriga da baleia.”\n\nAté a respiração se repete igual.', note: 'A evacuação usa a mesma gravação da lembrança de Lúcia, com a mesma respiração.' }
      ]
    }
  ];

  const visitors = [
    {
      id: 'celina', name: 'Dona Celina', portrait: 'celina', time: '21:08', kicker: 'A VIZINHA DO NÚMERO 19', human: true,
      line: '“Meu bem… deixa eu ficar aí até amanhecer? Tem alguém falando na minha cozinha. Fala igual ao meu filho. Mas só sabe dizer a mesma coisa.”',
      observation: 'Chinelo empoeirado. Uma sacola com café e dois pães. Ela segura as chaves com tanta força que marcaram a palma da mão.',
      questions: [
        { label: 'O que a voz está dizendo?', answer: '“Mãe, abre. Sou eu. Mãe, abre. Sou eu.” Ela engole seco. “Meu filho nunca me chama de mãe. É mãinha. Até quando tá zangado.”', note: 'A voz na cozinha de Celina repete uma frase e erra a forma como o filho a chama.' },
        { label: 'Você falou com alguém no rádio?', answer: '“Pedi pro Davi avisar que eu vinha. Depois desliguei tudo. A voz continuou na cozinha.” Ela olha pra sua sala. “O seu também faz isso?”', note: 'Celina diz que Davi anunciou sua visita. É possível conferir no rádio da associação.' }
      ],
      outcomes: {
        admit: { title: 'Mais uma xícara na mesa.', text: 'Celina entra de lado, como quem pede licença até ao chão. Põe o café no móvel. “Amanhã eu lavo essas xícaras.” Pela primeira vez em dias, você pensa em amanhã.' },
        refuse: { title: 'O café fica do lado de fora.', text: 'Você diz que não pode. Celina deixa a sacola junto ao portão. “Então come alguma coisa, meu bem.” Os chinelos se afastam na direção da igreja.' }
      }
    },
    {
      id: 'augusto', name: 'O homem do medidor', portrait: 'augusto', time: '00:32', kicker: 'UMA CAMISA DE SERVIÇO. NENHUM CRACHÁ.', human: false,
      line: '“Boa noite. Augusto, manutenção. A associação solicitou uma vistoria. Com essa chuva, o medidor pode dar retorno. Preciso entrar um instante.”',
      observation: 'A camisa, o cabelo e os sapatos estão secos. Ele olha para o rádio atrás de você. Ainda não olhou para o medidor, ao lado do próprio ombro.',
      questions: [
        { label: 'Que chuva?', answer: 'Ele espera. O sorriso não muda. “A chuva continua em toda a região. Nossas equipes trabalham para que você durma tranquilo.”', note: 'Augusto respondeu com as mesmas palavras do boletim sobre uma chuva que não existe.' },
        { label: 'Quem pediu a vistoria?', answer: '“A associação solicitou uma vistoria.” Você pede um nome. “A associação solicitou uma vistoria.” Ao fundo, um cachorro começa a ganir.', note: 'O homem não consegue dizer quem o enviou. Repete a apresentação ao ser questionado.' }
      ],
      outcomes: {
        admit: { title: 'Ele passa pelo medidor.', text: 'O homem entra sem encostar na caixa de luz. Para diante do rádio. “É aqui.” Você ouve a frase uma segunda vez, saindo da cozinha.' },
        refuse: { title: 'A rua inteira ouve o “boa noite”.', text: 'Você mantém o trinco. “Boa noite”, ele diz. A mesma voz responde de três casas vazias. O homem se afasta sem mover os braços.' }
      }
    },
    {
      id: 'echo', name: 'A voz da sua irmã', portrait: 'echo', time: '23:16', kicker: 'VOCÊ CONHECE ESSE ASSOBIO.', human: false,
      line: '“Sou eu. Abre logo. Se der medo, a gente se esconde na barriga da baleia. Lembra? Ninguém além da gente sabe disso.”',
      observation: 'O rosto parece o de Lúcia. Sem um arranhão. A camiseta está limpa. Ela assobia os mesmos quatro segundos, sem continuar a música.',
      questions: [
        { label: 'Por onde você veio?', answer: '“Pela rua de sempre.” Você pergunta da oficina. “Se der medo, a gente se esconde na barriga da baleia.” A voz tem a mesma pausa que saiu do rádio.', note: 'A primeira Lúcia não explica o caminho. Volta à lembrança já transmitida no rádio.' },
        { label: 'O que aconteceu com sua sobrancelha?', answer: 'Ela passa o dedo pelo lado errado do rosto. “Não aconteceu nada. Ninguém além da gente sabe disso.” O sorriso demora um pouco para acabar.', note: 'A primeira Lúcia não tem o corte descrito por Davi e não entende a pergunta sobre a sobrancelha.' }
      ],
      outcomes: {
        admit: { title: 'O abraço está no lugar errado.', text: 'Ela abraça você antes de cruzar o portão, como se houvesse alguém um passo à sua frente. Vai até o quarto sem perguntar por ninguém. Lá de dentro vem o mesmo assobio.' },
        refuse: { title: 'A música para no quarto segundo.', text: '“Ninguém além da gente sabe disso.” Você não abre. Ela fica imóvel até a lâmpada do poste apagar. Quando a luz volta, o portão está vazio.' }
      }
    },
    {
      id: 'lucia', name: 'Outra Lúcia', portrait: 'lucia', time: '01:51', kicker: 'DUAS BATIDAS. DEPOIS, UM PALAVRÃO.', human: true,
      line: '“Essa merda desse trinco ainda emperra? Sou eu. Não vou contar história de infância. Qualquer coisa nessa rua sabe as nossas agora.”',
      observation: 'Um corte recente atravessa a sobrancelha esquerda. A camiseta está suja de cal. Ela pressiona o portão para cima, justamente onde o trinco costuma prender.',
      questions: [
        { label: 'Como você chegou aqui?', answer: '“Pulei o muro da oficina, rasguei a testa. O Davi queria avisar pelo rádio. Mandei ele não falar seu nome. Vim pela viela, o ônibus tá fechando a rua.”', note: 'A segunda Lúcia tem o corte, a cal na roupa e descreve a rota mencionada por Davi.' },
        { label: 'Já esteve aqui outra pessoa igual a você.', answer: 'Ela fica pálida. “Na oficina, meu celular tocou. Era você. Pediu pra eu ir pro ônibus.” Olha para o seu bolso. O telefone está sem bateria desde ontem.', note: 'Alguém usou minha voz para chamar Lúcia ao ônibus. Meu telefone estava sem bateria.' }
      ],
      outcomes: {
        admit: { title: 'Desta vez, o trinco emperra.', text: 'Vocês erguem o portão juntos, como sempre fizeram. Lúcia entra e senta no chão. Não abraça você ainda. “Primeiro, tira as pilhas desse rádio.”' },
        refuse: { title: 'Ela não insiste na lembrança.', text: 'Lúcia respira fundo. “Eu entendo.” Arranca um pedaço da camiseta e amarra na própria testa. “Vou voltar pro Davi. Se mudar de ideia, bate no cano. A oficina escuta.”' }
      }
    },
    {
      id: 'davi', name: 'Davi, da oficina', portrait: 'davi', time: '02:43', kicker: 'A VOZ AGORA TEM UM ROSTO.', human: true,
      line: '“A antena da oficina tá desligada. Mesmo assim, a transmissão continua saindo daqui. Tem alguma coisa usando a sua casa de repetidora.”',
      observation: 'Graxa nas mãos, uma chave de boca no bolso. Ele bate duas vezes no cano junto ao muro. Da casa ao lado, alguém responde três.',
      questions: [
        { label: 'Como a gente faz isso parar?', answer: '“Não adianta só tirar da tomada. Tira as pilhas também. Sem microfone, sem antena. A gente combina as coisas nos canos, de casa em casa. Sem dar voz pra ela.”', note: 'Davi diz para cortar também as pilhas. Propõe combinar sinais nos canos com as casas vizinhas.' },
        { label: 'O que tem dentro do ônibus?', answer: '“O rádio chamou a Sônia com a voz do marido. Eu vi ela entrar. Dez minutos depois, chamou outra mulher com a mesma voz. O marido da Sônia morreu em junho.”', note: 'O ônibus atraiu duas pessoas com a mesma voz. Uma delas reconheceu alguém que morreu.' }
      ],
      outcomes: {
        admit: { title: 'Duas batidas. Três respostas.', text: 'Davi encosta a chave de boca no cano da cozinha. Do outro lado da parede, alguém responde. “Tá vendo? Não precisa saber o nome de todo mundo pra não deixar ninguém sozinho.”' },
        refuse: { title: 'Ele deixa a chave de boca.', text: '“Pode desconfiar de mim. Só não entra naquele ônibus.” Davi passa a ferramenta pela grade e volta à oficina, respondendo às batidas que vêm dos muros.' }
      }
    },
    {
      id: 'caller', name: 'Alguém com a sua voz', portrait: 'caller', time: '03:17', kicker: 'A ÚLTIMA VISITA', human: false,
      line: '“Todos os seus familiares já estão aqui.” A pessoa do lado de fora tem a sua altura. Quando fala de novo, usa a sua voz: “Abre. Eu sei que você tá aí.”',
      observation: 'Nenhum rosto fica nítido. No intervalo entre as palavras, o rádio da sala estala. O som do aparelho chega uma fração de segundo antes da voz no portão.',
      questions: [
        { label: 'O que você quer?', answer: '“Abre. Eu sei que você tá aí.” Foi o que você disse na porta do quarto de Lúcia, na noite em que ela desapareceu. Depois contou tudo no rádio.', note: 'A pessoa no portão repete outra frase que contei no rádio. O aparelho fala antes dela.' },
        { label: 'Ficar em silêncio e escutar.', answer: 'Sem uma resposta sua, a pessoa espera. O rádio percorre vozes conhecidas, procurando uma que faça você tocar no trinco.', note: 'Quando fico em silêncio, a voz não conversa: procura outra gravação que me convença.' }
      ],
      outcomes: {
        admit: { title: 'Sua voz entra primeiro.', text: 'Antes de a pessoa atravessar, cada cômodo diz seu nome. O rádio fica mudo. A casa aprendeu a falar sem ele. Ainda dá tempo de cortar o sinal.' },
        refuse: { title: 'Você tira a mão do trinco.', text: 'A pessoa continua esperando. Na cozinha, o rádio troca a sua voz pela de Lúcia. Na esquina, a porta do ônibus continua aberta.' }
      }
    }
  ];

  window.NCN.Story = Object.freeze({ nights, visitors });
})();
