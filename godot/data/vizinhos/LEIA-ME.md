# Vizinhos: histórias e conversas editáveis

O jogo 3D sorteia cinco dos onze personagens. Eles existem para dar clima e mistério: relatos, dicas de boa-fé e histórias pessoais. Ninguém mente de propósito — no máximo não sabe. Cada arquivo JSON contém a lore, os diálogos, as opções do jogador, as consequências e os SMS de um personagem. **Edite os JSONs diretamente e reinicie a partida no Godot. Não é necessário alterar GDScript para escrever uma conversa.**

| Arquivo | História |
| --- | --- |
| [neide.json](neide.json) | A costureira que vê tudo da janela. Uma voz no quintal oferece à neta Lia "o cobertor" de uma história que ninguém conhece; depois do ataque, a mãe da Lia volta de madrugada pedindo pra entrar. |
| [beto.json](beto.json) | O mecânico guarda a perua azul do Seu Arlindo, que sumiu. A perua buzina sozinha; depois do ataque, o "Arlindo" volta descalço pedindo a chave. |
| [sueli.json](sueli.json) | A cozinheira da quentinha dividiu o estoque até ficar sem. No breu, a voz da mãe falecida pede a panela pela janela, e volta toda noite. |
| [claudia.json](claudia.json) | A ex-atendente de telemarketing reconhece roteiro nos SMS do governo, que acabam pedindo quem dorme em cada casa. Faz a lista de quem sumiu e voltou. |
| [rita.json](rita.json) | A mãe espera o André voltar do turno. O telefone toca às 3h17, alguém chama "mãe" no breu; depois do ataque, "André" passa a noite na porta. |
| [jorge.json](jorge.json) | O porteiro aposentado não confia em farda nem em terno. Desconfia do sargento e da lista desde o primeiro dia e não sobe no caminhão. |
| [nilton.json](nilton.json) | O técnico de rádio ouve, às 3h17, a voz da falecida Célia cantando o verso que ele não gravou; depois ela pede pra entrar. |
| [emerson.json](emerson.json) | O entregador pede um álibi e descobre que tem outro "Emerson" andando pelo bairro com a cara dele, sem piscar. |
| [valdo.json](valdo.json) | O cambista vende informação velha do cunhado sumido; depois do ataque, o "Zezinho" liga sabendo um endereço que nunca soube e esquecendo a dívida que nunca esquecia. |
| [fabinho.json](fabinho.json) | O rapaz dos atalhos avisa do cara de cordão que cobra pedágio no beco e do alto de olho aceso; depois do ataque, refaz o mapa e descobre que de noite a rua é mais segura. |
| [kaio.json](kaio.json) | O estudante filma o céu e só sai preto; do homem alto, só os olhos. Grava o breu por baixo da porta e, depois, a voz da tia sumida chamando a mãe dele. |

Fio comum: quem sumiu volta, de madrugada, com a voz e as lembranças de quem era, pedindo pra entrar. Os amigos avisam o jogador a não abrir (prepara a volta da irmã no dia 9). Todo o resto acompanha o calendário: racionamento, sargento e a lista, Observador, bandido do beco, padarias, breu, ataque, bichos de dia e poucos de noite, barricada.

As histórias preservam dúvidas: uma voz familiar ou um relato não confirma a identidade de quem está fora, a causa da crise ou o destino de uma pessoa desaparecida.

## Calendário do 3D

| Dia | Mundo | Entrada da conversa |
| --- | --- | --- |
| 0–1 | Racionamento começa; desaparecidos no jornal; luz piscando. | `inicio` |
| 2 | Falta de produto, preço subindo; chega o sargento Holanda; bandido no beco (dias 1–5). | `abastecimento` |
| 3–4 | Água pode vir contaminada; o Observador aparece de noite; a padaria do Lúcio fecha no 4. | `estranho` |
| 5 | Água cortada; engarrafamento e fuga; o sargento fala da lista. | `fuga` |
| 6 | Breu total: sem luz, sem ônibus, sem água; caçadores cegos na rua. | `breu` |
| 7 | Ataque: o gigante no centro, comboio, fogo; caminhão do sargento no ponto; nenhum caçador na rua. | `ataque` |
| 8–9 | Ruínas; muitos caçadores de dia e poucos de noite; o Observador grita; quem sumiu volta pedindo pra entrar. | `depois` |
| 10 | A barricada do fim da rua abre até escurecer. | `epilogo` |

No dia 0 os vizinhos usam as falas do dia 1. As combinações de ajuda nas conversas são narrativas: não acrescentam escolta, resgate ou transferência automática de recursos. Todo custo (comida, água, pilhas) sai dos suprimentos. Depois do ataque, quem não virou amigo atende "mudado" (falas em `mundo3d.gd`); por isso `depois` e `epilogo` só são lidos por amigos.

## Como uma conversa funciona

As respostas aparecem abaixo da fala, na mesma caixa e com o retrato à vista. Clique na opção, use os números ou selecione com ↑/↓ e confirme com E/Enter. Esc encerra a visita. O custo aparece junto da opção de ajudar; numa janela pequena a lista pode ser rolada.

- `lore`: notas de autoria; não são exibidas como um bloco de exposição.
- `entradas`: lista ordenada de regras que escolhem o primeiro nó da visita. A primeira regra que satisfaz `se` vence. As fases mais recentes vêm antes das antigas, para uma primeira visita no dia 8 falar das ruínas.
- `nos`: mapa de identificadores para falas e opções. Um nó sem opções encerra a visita depois da fala.
- `falas`: lista de textos; cada texto aparece em uma tela de diálogo.
- `opcoes`: respostas/perguntas do jogador. `id` identifica a opção dentro daquele nó, `texto` é o botão e `destino` aponta para o próximo nó. `destino: ""` encerra a conversa.
- `variantes`: substituições das falas por condições, avaliadas em ordem. A primeira que satisfaz `se` vence; sem nenhuma, usa `falas`.
- `avisos`: a dica do dia (`verdade`), sempre de boa-fé. `{aviso}` dentro de uma fala usa essa dica.
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

## Esperar na casa amiga

A marca `ajudou` e confiança ≥2 liberam uma opção genérica de abrigo na conversa da porta, sem acrescentar um ramo a cada história. A amizade é conferida novamente ao confirmar. Depois de um agradecimento que encerra a conversa, volte à porta para ver as opções.

Entrar já espera um período: 1 ação e 0 energia. Você continua abrigado até escolher sair ou Esc, retornando à posição da mesma porta. Sem ações, esperar até amanhã consome 1 comida e 1 água das reservas, com as penalidades normais de escassez. O custo aparece antes de confirmar. O abrigo usa uma tela abstrata, sem interior modelado.

Cada morador tem a própria fala ao aceitar (`abrigo.confirma`). Para personalizar também o convite, acrescente:

```json
"abrigo": {"confirma": "Entra. Amanhã cedo você vai.", "convite": "Posso esperar aqui até a rua acalmar?"}
```

O texto padrão é “Pedir abrigo e esperar aqui”. A implementação fica em `scripts/abrigo3d.gd`, `mundo3d.gd` e `ciclo3d.gd`; o teste é `../fora_do_jogo/testes/abrigo3d_test.gd`.

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
godot --headless --path godot --script res://../fora_do_jogo/testes/vizinhanca_test.gd
godot --headless --path godot --script res://../fora_do_jogo/testes/mundo_vizinhanca_test.gd
```

Substitua `godot` pelo caminho do executável instalado, se ele não estiver no PATH.
