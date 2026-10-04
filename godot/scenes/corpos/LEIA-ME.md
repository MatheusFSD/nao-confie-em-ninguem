# Corpos dos NPCs da rua

Os dez modelos de pedestres têm cenas próprias nesta pasta, com duas poses: de barriga para cima (`costas`) e de bruços (`frente`). Abra a cena de um NPC no Godot e selecione o nó principal para mudar `Personagem`, `Pose` e `Sangue` no Inspetor. A prévia usa o mesmo modelo e as mesmas roupas do pedestre.

Os corpos aparecem no **dia 6, o dia do breu**, e continuam nos dias seguintes. Cada corpo é criado uma única vez, sem animação ou física móvel: avançar o calendário mantém sua posição, rotação e pose.

As poças de sangue têm contorno irregular e ficam rentes ao piso, sob a cabeça e o tronco. O formato é fixo por personagem e acompanha o corpo nos dias seguintes. Desmarque `Sangue` na cena para retirar a poça daquele NPC.

## Editar os locais

Em [`../../data/corpos3d.json`](../../data/corpos3d.json), cada entrada define:

- `id`: identificador único do corpo.
- `cena`: caminho da cena do NPC morto.
- `posicao`: coordenadas `[x, y, z]` no bairro. `y` é a altura inicial; na criação, o jogo ajusta o corpo ao piso abaixo dele.
- `giro`: direção do corpo em graus, em torno do eixo vertical.

Para acrescentar outro corpo, duplique uma entrada, use outro `id` e altere a posição. Reinicie a partida depois de editar o arquivo.

## Editar as poses

[`../../data/poses_mortos.json`](../../data/poses_mortos.json) contém as duas poses. `rotacao` deita o modelo inteiro; `ossos` ajusta cabeça, coluna, braços e pernas com ângulos `[x, y, z]` em graus. Mudar uma pose afeta todas as cenas que a usam.

O script [`../../scripts/corpo3d.gd`](../../scripts/corpo3d.gd) usa a espessura de cada modelo para apoiar braços, mãos, joelhos e pés no piso antes de congelar a malha. A roupa cede no contato com o solo. A sacola de Dona Célia fica caída ao lado dela. As malhas ficam em cache: após alterar os ângulos no JSON, reabra o projeto para atualizar também as prévias do editor.
