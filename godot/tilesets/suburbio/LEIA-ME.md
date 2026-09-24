# Tileset — Subúrbio carioca

175 peças de cenário em pixel art, vista diretamente de cima. Base de **32 × 32 pixels**, transparência real e pixels inteiros. Sem personagens ou animais. Há casinha e potes como objetos do quintal.

## Paredes e perspectiva corrigidas

A projeção é zenital (90°): TV e rádio mostram as carcaças superiores, a geladeira mostra apenas o tampo, a lixeira mostra a tampa, o ventilador de pedestal mostra sua cabeça vertical pela aresta e o varal mostra as dobras superiores das roupas. Não há fachadas nos móveis nem entrada frontal na casinha. A geladeira passou de 1×2 para 1×1 tile; manteve o mesmo ID e a mesma coordenada do atlas.

Neste conjunto, **cada parede preenche os 32×32 pixels da célula**, com colisão de 32×32. Os 16 encaixes por material mudam o contorno exposto; não deixam faixas transparentes no interior da célula. Vinte e um móveis e equipamentos retangulares também preenchem seu retângulo completo, incluindo cama, sofá, armários, bancada, fogão, geladeira, aparadores e lixeira. Para encostar, pinte o objeto na célula imediatamente vizinha à parede, sem deixar uma célula vazia entre os dois.

Um fluxo de produção define primeiro a projeção, a grade e a espessura das paredes; depois cria retas, quinas, junções em T/cruz e aberturas com bordas compatíveis. Parede centralizada não é um erro por si só, mas exige encaixes ou uma grade de posicionamento compatíveis com os móveis. Aqui foi escolhida a célula cheia para tornar o encaixe direto. Para espessuras menores, uma alternativa é construir paredes numa grade menor (por exemplo 16 px), mantendo suas bordas nas linhas dessa grade. O Godot permite separar pisos, paredes e objetos em camadas e definir colisões por peça: [TileMaps](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html) e [TileSets](https://docs.godotengine.org/en/4.7/tutorials/2d/using_tilesets.html).

As posições e os IDs das peças do mapa jogável foram preservados. Esta correção atualiza a arte e o recurso compartilhado, sem reconstruir `scenes/mapa.tscn` ou alterar movimento, câmera, interações e sobrevivência. Uma cópia anterior dos atlas e mapas está em `output/overhead-revision/antes-da-correcao.zip`, na raiz do workspace.

## Paredes em corte (jogo)

O mapa jogável `scenes/mapa.tscn` usa `paredes_corte.tres` na camada **Paredes**: grade de 16 px, parede preta chapada de meio tile, colada às bordas da grade de 32 px dos pisos. Peças: `parede`, `janela_h` (2×1), `janela_v` (1×2) e `porta_giro` (2×2, sem colisão). A arte e o recurso são recriados por `fontes/paredes_corte.gd` (instruções no topo do arquivo). Os terrenos de parede de 32 px continuam disponíveis em `suburbio.tres` para outros mapas.

## Montar o mapa

1. Abra o projeto Godot existente e abra `res://tilesets/suburbio/mapa_editavel.tscn` para alterar o exemplo, ou `mapa_novo.tscn` para começar vazio. Salve a cena com outro nome para guardar sua versão.
2. Selecione uma camada `TileMapLayer` na árvore. No painel **TileMap**, escolha um dos quatro atlas e pinte as peças. Os móveis grandes são uma peça única, mesmo ocupando várias células.
3. Para paredes, selecione a camada **Paredes**, entre em **Terrains/Terrenos**, escolha **Reboco verde**, **Muro de cimento** ou **Tijolo aparente** e pinte em modo **Connect/Conectar**. As retas, quinas, pontas, cruzes e junções em T se ajustam aos vizinhos. Cada material tem as 16 combinações de lados.
4. Deixe células vazias para portas. As soleiras não bloqueiam a passagem. Coloque janelas sobre uma parede reta na camada **Acima**. Portas fechadas, grades e janelas têm colisão; a folha da porta aberta bloqueia apenas a sua borda.
5. **F6** executa somente a cena de edição. Ela é estática e contém apenas cenário. O projeto principal continua abrindo o protótipo jogável em **F5**.

| Camada | Uso |
| --- | --- |
| Pisos | Cimento do quintal, calçada, asfalto e telhados vizinhos |
| PisosCasa | Pisos internos; a cena vazia nova usa a mesma grade das outras camadas |
| Detalhes | Tapetes, rachaduras, sujeira, poças e soleiras |
| Objetos | Móveis, plantas, tanque, portões e poste |
| Paredes | Pintura por terrenos e estrutura sólida |
| Acima | Janelas sobre a estrutura e fios suspensos |

Para encostar os móveis, mantenha **Objetos** e **Paredes** com a mesma posição e escala. No mapa existente, o deslocamento antigo de 16 px de `PisosCasa` foi preservado para não mover os pisos pintados; ele não desloca paredes ou objetos e não é necessário em mapas novos. O TileSet é compartilhado entre as cenas; para mudar colisões sem afetar outras cenas, faça uma cópia de `suburbio.tres` e atribua-a às camadas do novo mapa.

## Arquivos para editar a arte

| PNG | Conteúdo | Tamanho |
| --- | --- | --- |
| `pisos.png` | 48 variantes: cerâmica, azulejos, taco, ladrilho, cimento, terra, grama, asfalto, calçada, sarjeta e telha | 256 × 192 |
| `paredes.png` | 48 encaixes de parede + 16 peças de portas, janelas, grades, soleiras e colunas | 256 × 256 |
| `moveis.png` | 31 peças: camas, sofás, mesas, TV, rádio, cozinha, banheiro, tapetes e plantas | 512 × 256 |
| `quintal_rua.png` | 32 peças: varal, tanque, casinha, potes, caixa-d'água, mangueira, bueiros, poste, fios e detalhes da rua | 512 × 288 |

Abra os PNGs num editor de pixel art, ative a grade de **32 px**, mantenha as dimensões e a posição das peças e salve. O Godot reimporta a arte nos mesmos tiles, preservando o mapa. As áreas transparentes vazias entre móveis maiores não são peças. `catalogo.json` lista nome, coordenadas de atlas, dimensões e colisões de cada peça; `paleta.gpl` contém a paleta. `previa_tileset.png` é somente o catálogo visual e não deve ser usado como atlas.

`suburbio.tres` já contém recortes, colisões na camada física 1 e terrenos de parede. Tapetes, pisos, poças e pequenos detalhes não têm colisão. O poste tem colisão somente na base. Não há sombras longas gravadas nas paredes, para evitar escurecimento acumulado nas junções. A textura usa filtragem **Nearest** no projeto e nas camadas.

## Fontes e recriação opcional

Os PNGs e recursos já estão prontos: **não é necessário executar os scripts para editar o mapa**. A arte foi desenhada por código, sem serviço de geração de imagens. Os scripts em `fontes/` são fontes de autoria e não executam com o jogo.

- `fontes/desenhar_tileset.py`: recria os quatro PNGs, a paleta e o catálogo; requer Python com Pillow.
- `fontes/montar_recursos.gd`: depois da importação dos PNGs pelo editor, recria o `.tres`. Use `godot --headless --path CAMINHO_DO_PROJETO --script res://tilesets/suburbio/fontes/montar_recursos.gd -- --tiles-only` para preservar todas as cenas existentes. Sem `--tiles-only`, o script também recria as duas cenas de exemplo.

Recriar esses arquivos substitui as edições feitas neles. Use os scripts somente quando quiser reconstruir a versão original; guarde suas próprias cenas e atlas com outro nome.

Validado no Godot **4.7.2**, incluindo importação, renderização, 48 combinações de terreno, colisões, ancoragem dos móveis e cena vazia. As cenas foram salvas no formato do Godot 4.7. Documentação de referência: [pintura com TileMaps](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html) e [dados de cada tile](https://docs.godotengine.org/en/stable/classes/class_tiledata.html).
