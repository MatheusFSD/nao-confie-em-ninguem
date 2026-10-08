# Contexto — Não confie em ninguém

Atualizado em 2026-10-07. Resumo para retomar o projeto sem reler o histórico.

## Como retomar e atualizar

Leia primeiro este arquivo e depois somente o código necessário. Confira `git status` e preserve alterações existentes. Em divergências, confira o código e o pedido mais recente. Após cada tarefa, substitua os trechos desatualizados; não acumule histórico, logs ou código aqui.

Prompt para um novo chat:

> Leia CONTEXTO.md, consulte somente os arquivos necessários e execute: [tarefa]. Preserve as decisões registradas e atualize o contexto ao terminar.

## Projeto e decisões

- **Godot 4, somente 3D**, primeira pessoa, estética PS1/low poly, sobrevivência num subúrbio. Entrada: `godot/project.godot` → `scenes/menu_inicial.tscn` → `scenes/mundo3d.tscn`.
- 2D abandonado; arquivos mantidos. O bairro 3D usa os modelos/casario próprios, sem depender de `scenes/mapa.tscn`. `godot/README.md` depois do separador contém regras antigas.
- **Dia 0 e dano/combate dos caçadores continuam adiados.** IA de cegueira, proximidade, perseguição e caminhada aleatória autorizada; preservar calendário.
- Evitar modelagem nova. Becos devem usar os cinco GLBs fornecidos em `blocos_beco_godot.zip`, importados em `godot/modelos/blocos`, em vez de casas antigas para preencher os corredores. No dia 7 do ataque não há caçadores.
- Quatro ações/dia; gasto avança o período. Dormir consome comida/água; escassez reduz ações seguintes. Energia do HUD é disposição/pilhas, separada da rede elétrica.
- Lore e diálogos devem continuar editáveis em JSON, com escolhas que alteram respostas e relações.
- Corpos de bruços/barriga para cima, membros apoiados no solo e sangue no chão; posição fixa nos dias seguintes.
- Jogador deve colidir com NPCs e veículos; pedestres devem contornar obstáculos.

## Calendário atual

| Dia | O que acontece |
| --- | --- |
| 1–2 | Normalidade aparente; falhas e notícias de abastecimento. |
| 3–4 | Cidade estranha, falhas elétricas e menos movimento. |
| 5 | Fuga, engarrafamento e mercado caro/escasso. |
| 6 | **Único breu total**. Dois caçadores, corpos; pedestres/carros civis desaparecem. Ônibus para definitivamente; água ainda funciona. |
| 7 | Ataque, chamas, comboio militar. Água para; eletricidade e ônibus continuam cortados. Caçadores ausentes. |
| 8+ | Luz natural, ruínas, três caçadores; serviços cortados. Epílogo das conversas no dia 10+. |

Rede elétrica/ônibus: `dia < 6`; água: `dia < 7`, em `ciclo3d.gd`. SMS da irmã/vizinhos alinhados. Notícias não mudam regras. Não aplicar o antigo limite de dez dias do 2D.

## Onde mexer

Caminhos abaixo relativos a `godot/`:

| Arquivo/pasta | Responsabilidade |
| --- | --- |
| `scripts/mundo3d.gd` | Construção do bairro, interação, calendário visual, população, corpos e trânsito. |
| `scripts/ciclo3d.gd` | Dias, ações, recursos, custos e disponibilidade dos serviços. |
| `scripts/abrigo3d.gd` | Tela de espera na casa amiga; integração em `mundo3d.gd`. |
| `scenes/casario.tscn` (nó `BlocosBecos`), `data/becos3d.json`, `scripts/becos3d.gd`, `modelos/blocos/` | Casas reais e blocos dos becos, editados à mão em casario.tscn. JSON: `piso` único, `entradas` na barreira e `rotas` de conferência. |
| `scripts/cacador3d.gd`, `scripts/caminho_cacador3d.gd` | Proximidade, estados e navegação local dos caçadores; valores exportados ajustam alcance/memória. |
| `data/dias.json`, `data/mensagens.json`, `scripts/mensagens3d.gd` | Notícias/eventos, SMS da irmã e entrega de mensagens. |
| `data/vizinhos/*.json`, `scripts/vizinho3d.gd` | Lore, ramos, confiança, pedidos e SMS dos vizinhos. Guia: [vizinhos](godot/data/vizinhos/LEIA-ME.md). |
| `scripts/menu_escolha.gd`, `ui/dialogo.gd` | Respostas dentro da caixa de conversa, com retrato e última fala; clique, números, setas e E/Enter. |
| `scripts/corpo3d.gd`, `scenes/corpos/`, `data/corpos3d.json`, `data/poses_mortos.json` | Modelos mortos, posições e poses. Guia: [corpos](godot/scenes/corpos/LEIA-ME.md). |
| `scripts/pessoa3d.gd`, `scripts/caminho_pedestre3d.gd` | Pedestres, gravidade e desvio local por AStarGrid2D/consultas de colisão. |
| `scripts/jogador3d.gd`, `scripts/carro3d.gd`, `scripts/militar3d.gd` | Colisões do jogador e frenagem dos veículos. |

## Estado implementado

**Vizinhos:** cinco entre onze; um mentiroso sorteado. Personagens das portas/retratos, distintos dos dez pedestres 3D. JSON: `lore`, `entradas`, `nos`, `falas`, `opcoes`, `variantes`, condições/efeitos. Confiança −3..5, efeito por opção aplicado uma vez. Primeira visita adia pedido; ajuda custa recursos/ação; confiança ≥2 libera contato. Escolhas afetam visitas/SMS. Relações persistem apenas durante a partida.

**Abrigo:** marca `ajudou` + confiança ≥2 libera convite genérico na conversa da porta (revalidado ao confirmar). Entrar já espera um período: 1 ação, 0 energia. Tela opaca, sem interior novo; rua suspensa enquanto abrigado. Sem ações, esperar vira o dia, consome 1 comida/água e mantém penalidades normais; reservas acompanham o jogador, sem roubo por portas da própria casa. Permanece até escolher sair/Esc; retorna ao transform salvo na mesma porta. Texto opcional `abrigo.convite` no JSON do vizinho.

**Becos:** layout feito pelo usuário no editor: blocos do ZIP em `casario.tscn/BlocosBecos` (ficam no jogo; colisão `paredes-col` dos GLBs) e casas reposicionadas no lado oposto da rua. `becos3d.gd` cria um piso único x −46..62, z 37,4..68,4 (cimentado com a textura da calçada `modelos/rua_penha_3.png`, placa de 1,6 m, malha picada por causa da textura afim) sob tudo e uma cerca invisível nas laterais/fundo. GLBs `sobrado_azul_com_escada` e `casa_amarela_de_telhado_colonial` receberam fecho no fundo do muro lateral; o muro de `casa_branca_com_garagem` foi aparado até o fundo da casa (Blender 5.2 em `C:/Program Files/Blender Foundation/Blender 5.2`, por script; originais no git). Bocas na barreira Z37,6 em `entradas` (hoje x −17,75..−14,1; 7,7..9,25; 45,85..46,75; 52,85..54,1). Ao mover casas/blocos na frente, recalcular as bocas (scripts de apoio `output/godot-validation/_bocas_becos.gd` e `_alcance_becos.gd`, que gera `alcance-becos.png`). `modelos/blocos/LEIAME.txt` descreve dimensões e colisões.

**Caçadores:** cegos; percepção próxima de 2,4 m em todas as direções, bloqueada fisicamente por paredes. Correm para o jogador enquanto há contato; ao perdê-lo, procuram somente o último ponto percebido por até 2 s e voltam a vagar/pausar. Destinos aleatórios alcançáveis sobre piso; AStar local + cápsula/gravidade para contornar obstáculos, sem navmesh. Desempenho: grade presa ao mundo (0,35 m) com cache estático das células (`_cenario`, vence em 600 quadros; `esquecer()` em `construir` e `fechar_comercio`), corpos móveis só conferidos se houver algum na faixa; `escolher_destino` faz no máximo uma rota por quadro. Área de caminhada z 19..69 (cobre os becos). Cápsula raio 0,32 m; colisão com jogador e mundo. Rua/IA suspensas no abrigo. Sem dano/morte. Calendário 6:2, 7:0, 8+:3.

**Menus/economia/visual:** ônibus mostra ações, energia, recompensa e indisponibilidade antes de confirmar. Mercado mostra preço/benefício; `rende` em `data/mercado3d.json` define rendimento por embalagem: arroz 5 comidas, feijão/café 2, outros alimentos 1. Preço é por embalagem. Filtro PS1 suavizado: 16 tons, pontilhado 0,55 e VHS 0,18; baixa resolução mantida.

**Corpos:** dez modelos originais, malhas estáticas criadas uma vez no dia 6; pose/posição/poças fixas. Irmã e vizinhos de diálogo não viram esses corpos. Poses: `costas`/`frente`. Reinicie após editar dados; reabra o projeto para atualizar prévias em cache.

**Pedestres/colisões:** NPCs contornam obstáculos/pessoas, retomam a rota e voltam quando bloqueados. Rotas locais: passo 0,45 m, alcance 8 m, meia largura 2 m; sem navmesh. Desempenho: colunas da grade presas ao mundo e cache estático das células (como nos caçadores; `esquecer()` em `construir`/`fechar_comercio`), móveis conferidos só se houver algum na faixa (rota ~0,8 ms, antes ~4 ms). NPCs ocultos retiram colisões. Carros/comboio freiam e retomam com a faixa livre. Interação invisível do ônibus não bloqueia a calçada.

Camadas (valores de máscara): mundo `1`, jogador `2`, NPC `4`, interação `16`, veículo `32`, caçador `64`. Máscaras: jogador `1|4|32|64`, NPC `1|2|4|32`, veículos `2|4|32`, caçador `1|2|4|32|64`. Mudanças em `_ready` exigem reiniciar.

## Validação e estado de trabalho

Há alterações não commitadas de IA/colisões, menus/economia/calendário/filtro, abrigo, becos e assets do ZIP; preserve esse trabalho.

Últimos registros (08/10, após piso texturizado e cache de rotas): caçadores **64**, becos **23**, abrigo **27**, trânsito **43**, integração **186**, sem falhas. Ramos **2509**, mercado **10**, corpos **520** são resultados anteriores. Testes em `godot/tests/`. Logs/capturas: `output/godot-validation/` (ignorado). Erros de certificados/material podem aparecer no headless apesar das verificações aprovadas.

Capturas OpenGL conferidas: becos ZIP `beco-estreito-N-entrada/curva.png`; menus/mercado/filtro `ajustes-*.png` e abrigo `abrigo-amigo-*.png`.

Executável local: `output/godot-validation/Godot_v4.7.2-stable_win64_console.exe`. Exemplo PowerShell, na raiz:

```powershell
& './output/godot-validation/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --script res://tests/transito3d_test.gd --log-file (Join-Path (Get-Location) 'output/godot-validation/transito3d-test.log')
```

Execute o teste pertinente; conferência visual pelo F5 em `godot/project.godot`. Próxima tarefa depende do novo pedido.

## Planejado para depois

- Irmã com casa fixa no final da rua e pedido de resgate; após o breu não envia SMS. Resgatada, mora com o protagonista, conversa e aumenta o consumo de comida/água; não buscá-la leva a final ruim. Ainda não implementado.
- Obstáculos por dia (ideias): lixo/lixeiras, carros abandonados, caminhão/tanque bloqueando parcialmente no ataque, pilhas de tijolos e móveis nas ruínas. Preservar passagens e portas de abrigo; não alterar cadáveres.
