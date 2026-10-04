# Vizinhos: histórias e conversas editáveis

O jogo 3D sorteia cinco dos onze personagens e um mentiroso entre eles. Cada arquivo JSON contém a lore, os diálogos, as opções do jogador, as consequências e os SMS de um personagem. **Edite os JSONs diretamente e reinicie a partida no Godot. Não é necessário alterar GDScript para escrever uma conversa.**

| Arquivo | História |
| --- | --- |
| [neide.json](neide.json) | A costureira que transforma vigilância em cuidado com a neta Lia; teme repetir uma demora em abrir o portão durante uma enchente. |
| [beto.json](beto.json) | O mecânico guarda a chave de um cliente desaparecido e precisa aceitar que nem tudo tem conserto. |
| [sueli.json](sueli.json) | A cozinheira distribuiu seu estoque e tem vergonha de admitir que também precisa comer. |
| [claudia.json](claudia.json) | A ex-atendente reconhece roteiros nos avisos oficiais e aprende a preservar as dúvidas em vez de fabricar uma explicação. |
| [rita.json](rita.json) | A mãe espera André voltar do turno e tenta separar o filho real das vozes e das interpretações de uma mensagem incompleta. |
| [jorge.json](jorge.json) | O porteiro aposentado carrega a culpa de ter confundido aparência com autorização e investiga uma ordem sem destino. |
| [nilton.json](nilton.json) | O técnico de rádio ouve uma faixa que parece completar a gravação da mulher falecida, Célia. |
| [emerson.json](emerson.json) | O entregador pede um álibi antes de admitir uma visita ao irmão no hospital e o desaparecimento da van de trabalho. |
| [valdo.json](valdo.json) | O intermediário continua vendendo informação depois que o cunhado motorista, sua fonte, para de responder. |
| [fabinho.json](fabinho.json) | O rapaz dos atalhos deixa de reconhecer o caminho e precisa parar de andar para provar que ainda é útil. |
| [kaio.json](kaio.json) | O estudante guarda fotos defeituosas e aprende que registrar uma crise não autoriza expor ou arriscar pessoas. |

As histórias preservam dúvidas: uma voz familiar ou um relato não confirma a identidade de quem está fora, a causa da crise ou o destino de uma pessoa desaparecida. O mentiroso é um papel sorteado, não uma identidade fixa. Sua confissão ao ser confrontado combina com a motivação do personagem.

## Calendário do 3D

| Dia | Mundo | Entrada da conversa |
| --- | --- | --- |
| 1 | Normalidade e primeiras falhas. | `inicio` |
| 2 | Problemas de abastecimento; água ainda disponível. | `abastecimento` |
| 3–4 | Cidade estranha, falhas elétricas, menos pessoas e carros. | `estranho` |
| 5 | Engarrafamento e produtos caros/escassos. | `fuga` |
| 6 | Breu total; caçadores na rua. Água e ônibus ainda disponíveis. | `breu` |
| 7 | Ataque, comboio e cidade em chamas. Água e energia da rede cortadas; ônibus suspensos. | `ataque` |
| 8–9 | Ruínas e retorno dos caçadores. A luz natural retorna; os serviços continuam cortados. | `depois` |
| 10+ | Mesmo mundo destruído; consequências das relações. | `epilogo` |

O dia 0 histórico não foi ligado ao 3D. Os caçadores continuam com o comportamento anterior. As combinações de ajuda nas conversas são narrativas: não acrescentam escolta, resgate ou transferência automática de recursos. A energia numérica do HUD continua representando disposição/pilhas, separada da rede elétrica. Pias da casa guardam +2 águas por 1 ação até o dia 6.

## Como uma conversa funciona

As respostas aparecem abaixo da fala, na mesma caixa e com o retrato à vista. Clique na opção, use os números ou selecione com ↑/↓ e confirme com E/Enter. Esc encerra a visita. O custo aparece junto da opção de ajudar; numa janela pequena a lista pode ser rolada.

- `lore`: notas de autoria; não são exibidas como um bloco de exposição.
- `entradas`: lista ordenada de regras que escolhem o primeiro nó da visita. A primeira regra que satisfaz `se` vence. As fases mais recentes vêm antes das antigas, para uma primeira visita no dia 8 falar das ruínas.
- `nos`: mapa de identificadores para falas e opções. Um nó sem opções encerra a visita depois da fala.
- `falas`: lista de textos; cada texto aparece em uma tela de diálogo.
- `opcoes`: respostas/perguntas do jogador. `id` identifica a opção dentro daquele nó, `texto` é o botão e `destino` aponta para o próximo nó. `destino: ""` encerra a conversa.
- `variantes`: substituições das falas por condições, avaliadas em ordem. A primeira que satisfaz `se` vence; sem nenhuma, usa `falas`.
- `avisos`: informação verdadeira e falsa por dia. `{aviso}` dentro de uma fala usa o aviso correspondente ao papel sorteado do morador.
- `mensagens`: SMS desse personagem, entregues somente após obter o contato.

Exemplo completo de uma ramificação, para acrescentar dentro de `nos`:

```json
"pergunta_nova": {
  "falas": ["Você também ouviu os passos?"],
  "opcoes": [
    {
      "id": "ouvi",
      "texto": "Ouvi, mas não vi quem era.",
      "destino": "comparar_relato",
      "efeitos": {"confianca": 1, "marcas": ["comparou_passos"]}
    },
    {
      "id": "nao_ouvi",
      "texto": "Não ouvi nada.",
      "destino": "sem_relato"
    }
  ]
},
"comparar_relato": {"falas": ["Então vamos separar o som do que imaginamos que era."]},
"sem_relato": {"falas": ["Tudo bem. Não precisa concordar comigo."]}
```

Depois ligue uma opção de outro nó a `"destino": "pergunta_nova"`. Não esqueça das vírgulas entre os nós: JSON não aceita comentários ou vírgula depois do último item.

## Condições e consequências

`se` aceita estas condições; quando usadas juntas, todas precisam valer:

| Campo | Exemplo | Regra |
| --- | --- | --- |
| `dia_min` / `dia_max` | `{"dia_min": 5, "dia_max": 6}` | Faixa inclusiva de dias. |
| `confianca_min` / `confianca_max` | `{"confianca_min": 2}` | Confiança exigida. |
| `marcas` | `{"marcas": ["ajudou"]}` | Todas essas escolhas precisam ter sido registradas. |
| `sem_marcas` | `{"sem_marcas": ["ajudou"]}` | Nenhuma dessas marcas pode existir. |
| `mente` | `{"mente": true}` | Papel sorteado do personagem. |
| `pedido_disponivel` | `{"pedido_disponivel": true}` | Respeita o adiamento após apresentação ou recusa. |

Uma opção pode ter `efeitos`:

```json
"efeitos": {
  "confianca": 1,
  "marcas": ["rede"],
  "tirar_marcas": ["isolou"],
  "adiar": 1
}
```

A confiança fica entre −3 e 5. O ganho ou a perda de confiança de cada opção é aplicado uma vez por partida, para uma pergunta repetida não gerar confiança infinita. Marcas são aplicadas a cada escolha; `tirar_marcas` permite mudar de intenção. `adiar` impede um novo pedido até a data indicada, sem impedir perguntas gratuitas.

Uma opção com custo usa:

```json
"custo": {"acoes": 1, "item": "agua", "quanto": 1}
```

Itens: `comida`, `agua`, `energia`, `dinheiro`, ou `""` para custar apenas tempo. Uma unidade de `energia` corresponde a um pacote de pilhas, ou 20 pontos. O jogo confere todos os custos antes de descontar qualquer valor; uma tentativa impossível mantém a conversa aberta e não cobra ação. Nesta versão os pedidos usam 1 ação. Os demais diálogos são gratuitos.

A primeira visita apresenta o vizinho e deixa o pedido para o dia seguinte. Recusar permite tentar amanhã. Ajudar registra `ajudou`; confiança ≥2 libera o número. Se a ajuda ainda não for suficiente, uma conversa posterior pode recuperar a relação. Os avisos exigem confiança ≥2, mas confiança não impede o mentiroso de mentir.

`rede` e `isolou` guardam a decisão de cooperar ou manter distância depois do ataque e alteram visitas e SMS posteriores.

## SMS e edição

```json
{
  "id": "aviso_exemplo",
  "dia_min": 5,
  "dia_max": 5,
  "se": {"mente": false, "marcas": ["ajudou"]},
  "texto": "confere a lanterna enquanto o ônibus passa"
}
```

`dia_min` é o calendário do mundo. `dia_max` impede entregar um aviso vencido a quem só conseguiu o contato depois. Uma mensagem recebida permanece na caixa mesmo depois do prazo ou de uma mudança de relação. Para uma mensagem contada a partir da troca de número, use `dia_relativo` no lugar de `dia_min`, como na apresentação do contato. `dia_relativo: 0` significa o momento da troca de número, não o dia 0 do jogo.

As mensagens da irmã ficam em `../mensagens.json`; os textos de notícias e eventos em `../dias.json`. Os cortes mecânicos usam `DIA_DO_BREU` e `DIA_DO_CORTE` em `scripts/ciclo3d.gd`. Mudar só o texto de uma notícia não altera uma regra do mundo.

Mudanças de texto, nós, condições e efeitos nos JSONs são lidas ao iniciar uma nova partida. O estado das relações dura a partida atual; não foi acrescentado salvamento persistente.

Para validar os ramos e o calendário, execute na pasta do projeto:

```powershell
godot --headless --path godot --script res://tests/vizinhanca_test.gd
godot --headless --path godot --script res://tests/mundo_vizinhanca_test.gd
```

Substitua `godot` pelo caminho do executável instalado, se ele não estiver no PATH.
