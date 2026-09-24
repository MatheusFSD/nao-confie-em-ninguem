# Não confie em ninguém

Um protótipo de terror doméstico em Bento Ribeiro, no subúrbio do Rio de Janeiro. Três noites, seis visitas e um rádio que devolve vozes que não deveria conhecer.

## Jogar

Abra **index.html** no navegador. Não precisa instalar dependências nem ter conexão com a internet. Para uma prévia em servidor local, execute `node server.cjs` e abra <http://127.0.0.1:4173>.

O arquivo **index(2).html** é o protótipo original, preservado para comparação.

## O que mudou

- A sala ocupa a tela: rádio e portão são os pontos de interação, com retratos durante as visitas.
- Os protocolos, contadores de recursos e leitura obrigatória foram removidos.
- O ciclo é escutar, observar, perguntar e decidir se abre o portão. Sem cronômetro, inventário ou combinações obrigatórias.
- As pistas entram no caderno somente quando são encontradas. O caderno diferencia observações, relatos e decisões; não certifica que um relato é verdadeiro.
- Seis desfechos dependem da decisão final e de quem você acolheu. Entradas indevidas alteram acontecimentos e o final de isolamento; cortar o sinal permite conter as imitações.
- Som ambiente e efeitos sintetizados, opcionais. Todas as informações sonoras relevantes também aparecem em texto.
- Progresso automático no armazenamento do navegador, quando disponível. O menu permite continuar ou recomeçar.

## Arquivos

| Arquivo | Responsabilidade |
| --- | --- |
| `index.html` | Estrutura sem CSS ou JavaScript embutido |
| `css/game.css` | Visual, estados, acessibilidade e adaptação de tela |
| `js/story.js` | Noites, visitantes, perguntas, pistas e consequências |
| `js/state.js` | Classe `GameState`: decisões, progressão, salvamento e finais |
| `js/audio.js` | Classe `Soundscape`: contexto único de áudio e efeitos |
| `js/view.js` | Classe `GameView`: cena, diálogos, rádio e caderno |
| `js/game.js` | Classe `Game`: eventos, atalhos e coordenação |
| `assets/` | Cenário e retratos originais gerados para este protótipo |

Scripts clássicos carregados com `defer` permitem abrir o jogo diretamente por arquivo. As classes ficam no namespace `window.NCN`. Não há bibliotecas externas, fontes remotas ou build obrigatório.

## Atalhos

`R`: rádio · `P`: portão · `C`: caderno · `M`: som · `F`: tela cheia · `Esc`: fechar diálogo. Também funciona com mouse ou toque. O diálogo mantém a navegação por teclado dentro dele. A preferência do sistema por movimento reduzido é respeitada.

## Direção narrativa (contém spoilers)

O fenômeno imita gravações transmitidas pelo rádio; por isso, uma memória compartilhada já não autentica uma pessoa. A primeira Lúcia usa uma história que o protagonista divulgou procurando a irmã. A segunda traz fatos recentes que podem ser comparados com Davi. Não é uma simulação médica nem um teste de aparência: o horror vem da informação fora de contexto e do custo de se isolar.

O mistério se resolve no comportamento da voz, sem explicar sua origem. Cortar o circuito (tomada, pilhas e antena) a silencia. Os canos oferecem uma forma de reconstruir ajuda entre vizinhos. É possível terminar sem descobrir essa saída e também sobreviver recusando todo mundo, mas o final reconhece o custo dessas decisões.

## Verificação

Execute `node --test tests/state.test.cjs` para verificar percursos completos, condições dos finais, registro de pistas e recuperação do salvamento. O servidor local é opcional e deve ser usado apenas para desenvolvimento.

Créditos da arte e prompts: `assets/ART-DIRECTION.md`.
