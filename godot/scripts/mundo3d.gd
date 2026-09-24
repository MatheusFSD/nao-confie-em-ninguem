extends Node

# Constrói o subúrbio em 3D low poly a partir do mesmo mapa 2D de scenes/mapa.tscn.
# Nada é empilhado com nós de formas prontas: tudo vira triângulos numa malha só
# (MalhaLowPoly), com faces internas descartadas e áreas iguais juntadas em
# retângulos maiores, do jeito que se fazia no PlayStation 1.
const MAPA := preload("res://scenes/mapa.tscn")
const PS1 := preload("res://shaders/ps1.gdshader")
const Pessoa3D := preload("res://scripts/pessoa3d.gd")
const Carro3D := preload("res://scripts/carro3d.gd")
## 32 pixels do mapa 2D = 1 metro.
const ESCALA := 1.0 / 32.0
const ALTURA_PAREDE := 2.6
const ALTURA_MURO := 2.15
## Paleta do subúrbio: reboco, cimento, asfalto e telha.
const CORES := {
	"cimento": Color("6b7263"), "calcada": Color("8d9184"), "asfalto": Color("3b4147"),
	"telha": Color("8c4a33"), "taco": Color("7b5433"), "ceramica_bege": Color("c3bda2"),
	"azulejo_banheiro": Color("9fb4ac"), "azulejo_verde": Color("8fae9e"), "ladrilho_floral": Color("bdb69a"),
	"grama_rala": Color("55663f"), "terra": Color("6a5540"), "sarjeta": Color("4a5049"),
	"parede": Color("b9b3a1"), "parede_lado": Color("a49d8b"), "muro": Color("9a9384"),
	"vidro": Color("6f8f96"), "madeira": Color("6d4c33"), "metal": Color("737a73"),
}
var malha_cenario := MalhaLowPoly.new()
var mundo: Node3D
var jogador: CharacterBody3D
var pessoas: Array[Node3D] = []
var carros: Array[Node3D] = []
var portas: Array[Dictionary] = []
var inicio := Vector3(8.5, 0, 14.7)

func _ready() -> void:
	mundo = get_node("Tela/Render/Mundo")
	jogador = get_node("Tela/Render/Jogador")
	var mapa := MAPA.instantiate()
	add_child(mapa)
	construir(mapa)
	remove_child(mapa)
	mapa.queue_free()
	jogador.global_position = inicio + Vector3(0, 0.1, 0)

func em_metros(px: Vector2) -> Vector3:
	return Vector3(px.x * ESCALA, 0.0, px.y * ESCALA)

func construir(mapa: Node2D) -> void:
	construir_pisos(mapa.get_node("Pisos"), 0.0)
	construir_pisos(mapa.get_node("PisosCasa"), 0.02)
	construir_meio_fio(mapa.get_node("Detalhes"))
	construir_paredes(mapa.get_node("Paredes"))
	construir_vizinhos(mapa.get_node("Limites"))
	construir_objetos(mapa.get_node("Objetos"))
	construir_portas(mapa.get_node_or_null("Portas"))
	var marcador := mapa.get_node_or_null("InicioMorador") as Node2D
	if marcador: inicio = em_metros(marcador.position)
	aplicar_malha()
	povoar(mapa.get_node_or_null("Transito"))

# ---------------------------------------------------------------- pisos e rua

## Junta células iguais em retângulos grandes: um quadrilátero cobre a área toda.
func retangulos(celulas: Dictionary) -> Array:
	var restantes := celulas.duplicate()
	var saida := []
	var chaves := restantes.keys()
	chaves.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for chave: Vector2i in chaves:
		if not restantes.has(chave): continue
		var largura := 1
		while restantes.has(chave + Vector2i(largura, 0)): largura += 1
		var altura := 1
		while true:
			var linha_inteira := true
			for i in largura:
				if not restantes.has(chave + Vector2i(i, altura)):
					linha_inteira = false
					break
			if not linha_inteira: break
			altura += 1
		for y in altura:
			for x in largura:
				restantes.erase(chave + Vector2i(x, y))
		saida.append(Rect2i(chave, Vector2i(largura, altura)))
	return saida

func nome_base(nome: String) -> String:
	return nome.rstrip("0123456789_")

func construir_pisos(camada: TileMapLayer, altura: float) -> void:
	var por_material := {}
	var celula: int = camada.tile_set.tile_size.x
	for cel: Vector2i in camada.get_used_cells():
		var dados := camada.get_cell_tile_data(cel)
		if dados == null: continue
		var base := nome_base(String(dados.get_custom_data("nome")))
		if not CORES.has(base): continue
		if not por_material.has(base): por_material[base] = {}
		por_material[base][cel] = true
	for material: String in por_material:
		var cor: Color = CORES[material]
		for r: Rect2i in retangulos(por_material[material]):
			var origem := Vector2(r.position) * celula + camada.position
			var tamanho := Vector2(r.size) * celula
			malha_cenario.piso(origem * ESCALA, tamanho * ESCALA, altura, cor)

## Meio-fio: fita de concreto um pouco acima do asfalto.
func construir_meio_fio(detalhes: TileMapLayer) -> void:
	var celula: int = detalhes.tile_set.tile_size.x
	var alto := {}
	var baixo := {}
	for cel: Vector2i in detalhes.get_used_cells():
		var dados := detalhes.get_cell_tile_data(cel)
		if dados == null: continue
		var nome := String(dados.get_custom_data("nome"))
		if nome == "meio_fio_cima": alto[cel] = true
		elif nome == "meio_fio_baixo": baixo[cel] = true
	for lado in [[alto, float(celula) - 6.0], [baixo, 0.0]]:
		for r: Rect2i in retangulos(lado[0]):
			var origem := Vector2(r.position) * celula + Vector2(0, lado[1])
			malha_cenario.caixa(Vector3(origem.x * ESCALA, 0.0, origem.y * ESCALA), Vector3(r.size.x * celula * ESCALA, 0.14, 6.0 * ESCALA), CORES.calcada, CORES.calcada.darkened(0.2))

# ------------------------------------------------------------------- paredes

func construir_paredes(camada: TileMapLayer) -> void:
	var celula: int = camada.tile_set.tile_size.x
	var solidas := {}
	var janelas := {}
	for cel: Vector2i in camada.get_used_cells():
		var dados := camada.get_cell_tile_data(cel)
		if dados == null: continue
		var nome := String(dados.get_custom_data("nome"))
		if nome == "parede": solidas[cel] = true
		elif nome.begins_with("janela"): janelas[cel] = true
	# O muro do lote é mais baixo que as paredes da casa.
	var interno := Rect2i(6, 12, 28, 22)
	var grupos := {"casa": {}, "muro": {}}
	for cel: Vector2i in solidas:
		grupos["casa" if interno.has_point(cel) else "muro"][cel] = true
	for grupo: String in grupos:
		var altura: float = ALTURA_PAREDE if grupo == "casa" else ALTURA_MURO
		var cor_topo: Color = CORES.parede if grupo == "casa" else CORES.muro
		for r: Rect2i in retangulos(grupos[grupo]):
			var origem := Vector3(r.position.x * celula * ESCALA, 0.0, r.position.y * celula * ESCALA)
			var tamanho := Vector3(r.size.x * celula * ESCALA, altura, r.size.y * celula * ESCALA)
			malha_cenario.caixa(origem, tamanho, cor_topo, CORES.parede_lado)
	# Peitoril, verga e vidro: o vão da janela fica aberto no meio.
	for cel: Vector2i in janelas:
		var origem := Vector3(cel.x * celula * ESCALA, 0.0, cel.y * celula * ESCALA)
		var lado := celula * ESCALA
		malha_cenario.caixa(origem, Vector3(lado, 1.0, lado), CORES.parede, CORES.parede_lado)
		malha_cenario.caixa(origem + Vector3(0, 2.0, 0), Vector3(lado, 0.6, lado), CORES.parede, CORES.parede_lado)
		malha_cenario.caixa(origem + Vector3(0.12, 1.0, 0.12), Vector3(lado - 0.24, 1.0, lado - 0.24), CORES.vidro, CORES.vidro)

## Casas vizinhas: blocos fechados com telhado de duas águas nos limites do mapa.
func construir_vizinhos(limites: Node2D) -> void:
	for forma: CollisionShape2D in limites.get_children():
		var rect := forma.shape as RectangleShape2D
		if rect == null: continue
		var canto := (forma.position - rect.size / 2.0) * ESCALA
		var tamanho := rect.size * ESCALA
		if tamanho.x < 1.0 or tamanho.y < 1.0: continue
		# Corta o bloco em casas de ~7 m para o quarteirão não virar uma caixa só.
		var ao_longo_de_x := tamanho.x >= tamanho.y
		var passos := maxi(1, int(round(maxf(tamanho.x, tamanho.y) / 7.0)))
		for i in passos:
			var fatia := Vector2(tamanho.x / passos, tamanho.y) if ao_longo_de_x else Vector2(tamanho.x, tamanho.y / passos)
			var origem := canto + (Vector2(fatia.x * i, 0.0) if ao_longo_de_x else Vector2(0.0, fatia.y * i))
			var altura := 3.0 + float(i % 3) * 0.45
			malha_cenario.caixa(Vector3(origem.x, 0.0, origem.y), Vector3(fatia.x, altura, fatia.y), CORES.muro, CORES.parede_lado.darkened(0.1))
			malha_cenario.telhado(origem, fatia, altura, 0.9 + float(i % 2) * 0.3, CORES.telha, CORES.telha.darkened(0.25))

# -------------------------------------------------------------------- objetos

func construir_objetos(camada: TileMapLayer) -> void:
	var celula: int = camada.tile_set.tile_size.x
	for cel: Vector2i in camada.get_used_cells():
		var dados := camada.get_cell_tile_data(cel)
		if dados == null: continue
		var nome := String(dados.get_custom_data("nome"))
		var canto := Vector3(cel.x * celula * ESCALA, 0.0, cel.y * celula * ESCALA) + Vector3(camada.position.x, 0.0, camada.position.y) * ESCALA
		objeto(nome, canto)

## Cada peça do mapa vira um móvel simples, com poucas faces.
func objeto(nome: String, canto: Vector3) -> void:
	var madeira: Color = CORES.madeira
	var metal: Color = CORES.metal
	match nome:
		"cama_verde", "cama_terracota":
			malha_cenario.caixa(canto + Vector3(0.1, 0, 0.1), Vector3(1.8, 0.45, 2.8), Color("4f6b58"), madeira)
			malha_cenario.caixa(canto + Vector3(0.2, 0.45, 0.2), Vector3(1.6, 0.12, 0.7), Color("cfc7ab"), Color("cfc7ab"))
		"sofa_vertical", "sofa_horizontal", "poltrona":
			var deitado := nome == "sofa_horizontal"
			var tam := Vector3(2.8, 0.45, 1.7) if deitado else Vector3(1.7, 0.45, 2.8)
			malha_cenario.caixa(canto + Vector3(0.1, 0, 0.1), tam, Color("4c6350"), Color("3d5142"))
			var encosto := Vector3(tam.x, 0.45, 0.35) if deitado else Vector3(0.35, 0.45, tam.z)
			malha_cenario.caixa(canto + Vector3(0.1, 0.45, 0.1), encosto, Color("5a7360"), Color("40563f"))
		"guarda_roupa", "armario_cozinha", "estante":
			malha_cenario.caixa(canto + Vector3(0.05, 0, 0.05), Vector3(2.8, 2.0, 0.9), madeira.lightened(0.1), madeira)
		"comoda", "rack", "tv_aparador", "radio_aparador":
			malha_cenario.caixa(canto + Vector3(0.05, 0, 0.05), Vector3(1.8, 0.75, 0.85), madeira.lightened(0.08), madeira)
			if nome == "tv_aparador":
				malha_cenario.caixa(canto + Vector3(0.35, 0.75, 0.25), Vector3(1.0, 0.8, 0.75), Color("30383a"), Color("22282a"))
				malha_cenario.caixa(canto + Vector3(0.42, 0.9, 0.2), Vector3(0.86, 0.6, 0.08), Color("7f9aa0"), Color("7f9aa0"))
			elif nome == "radio_aparador":
				malha_cenario.caixa(canto + Vector3(0.4, 0.75, 0.3), Vector3(0.9, 0.3, 0.35), Color("3a3a36"), Color("2b2b28"))
		"mesa_redonda", "mesa_cozinha", "mesa_retangular":
			malha_cenario.cilindro(canto + Vector3(0.9, 0.0, 0.9), 0.18, 0.7, 5, madeira.darkened(0.2), madeira)
			malha_cenario.caixa(canto + Vector3(0.1, 0.7, 0.1), Vector3(1.7, 0.12, 1.7), madeira.lightened(0.15), madeira)
		"cadeira_madeira", "cadeira_plastica":
			malha_cenario.caixa(canto + Vector3(0.25, 0, 0.25), Vector3(0.55, 0.45, 0.55), madeira, madeira.darkened(0.15))
			malha_cenario.caixa(canto + Vector3(0.25, 0.45, 0.25), Vector3(0.55, 0.5, 0.12), madeira.lightened(0.1), madeira)
		"fogao":
			malha_cenario.caixa(canto + Vector3(0.1, 0, 0.1), Vector3(0.85, 0.9, 0.85), Color("b6b6ad"), Color("9a9a92"))
			for p: Vector3 in [Vector3(0.28, 0.91, 0.3), Vector3(0.62, 0.91, 0.3), Vector3(0.28, 0.91, 0.62), Vector3(0.62, 0.91, 0.62)]:
				malha_cenario.cilindro(canto + p, 0.1, 0.02, 5, Color("2c3231"), Color("2c3231"))
		"geladeira":
			malha_cenario.caixa(canto + Vector3(0.08, 0, 0.08), Vector3(0.85, 1.75, 0.8), Color("c6c9bd"), Color("aeb1a6"))
		"pia_bancada", "pia_banheiro", "tanque", "maquina_lavar":
			var largura := 2.8 if nome == "pia_bancada" else 1.0
			malha_cenario.caixa(canto + Vector3(0.05, 0, 0.05), Vector3(largura, 0.9, 0.85), Color("b9b5a4"), Color("9d9a8c"))
			malha_cenario.caixa(canto + Vector3(0.2, 0.78, 0.2), Vector3(minf(largura, 0.9) - 0.1, 0.14, 0.5), Color("6d8b8c"), Color("5b7476"))
		"vaso_sanitario":
			malha_cenario.caixa(canto + Vector3(0.25, 0, 0.3), Vector3(0.5, 0.42, 0.7), Color("d3d6cb"), Color("bcbfb5"))
			malha_cenario.caixa(canto + Vector3(0.25, 0.42, 0.3), Vector3(0.5, 0.45, 0.22), Color("d3d6cb"), Color("bcbfb5"))
		"filtro_barro", "potes", "balde", "lixeira", "saco_lixo", "tijolos_empilhados":
			var cor := Color("8a5f3f") if nome == "filtro_barro" else Color("55606a")
			malha_cenario.cilindro(canto + Vector3(0.5, 0, 0.5), 0.3, 0.6, 5, cor, cor.lightened(0.15))
		"casinha_cachorro":
			malha_cenario.caixa(canto + Vector3(0.1, 0, 0.1), Vector3(1.8, 0.9, 1.8), madeira, madeira.darkened(0.2))
			malha_cenario.telhado(Vector2(canto.x + 0.05, canto.z + 0.05), Vector2(1.9, 1.9), 0.9, 0.5, CORES.telha, CORES.telha.darkened(0.2))
		"caixa_agua":
			malha_cenario.cilindro(canto + Vector3(1.0, 0.0, 1.0), 0.8, 1.2, 6, Color("4b6b70"), Color("5e8086"))
		"poste":
			malha_cenario.cilindro(canto + Vector3(0.5, 0, 0.5), 0.12, 6.0, 5, Color("9a9a92"), Color("9a9a92"))
			malha_cenario.caixa(canto + Vector3(0.5, 5.7, 0.4), Vector3(1.4, 0.12, 0.2), Color("9a9a92"), Color("8a8a82"))
			malha_cenario.caixa(canto + Vector3(1.7, 5.45, 0.35), Vector3(0.45, 0.25, 0.3), Color("d9c98a"), Color("b8a874"))
		"varal":
			for dx: float in [0.2, 3.6]:
				malha_cenario.cilindro(canto + Vector3(dx, 0, 0.9), 0.07, 1.8, 4, metal, metal)
			malha_cenario.caixa(canto + Vector3(0.2, 1.75, 0.85), Vector3(3.4, 0.04, 0.05), metal, metal)
		"canteiro":
			malha_cenario.caixa(canto + Vector3(0.05, 0, 0.05), Vector3(2.9, 0.35, 0.9), Color("6a5540"), Color("55432f"))
			folhagem(canto + Vector3(1.5, 0.35, 0.5), 0.8)
		"bananeira", "espada_sao_jorge", "samambaia", "mato":
			folhagem(canto + Vector3(0.5, 0.0, 0.5), 1.6 if nome == "bananeira" else 0.7)
		"portao_aberto", "portao_fechado":
			malha_cenario.caixa(canto + Vector3(0.0, 0, 0.2), Vector3(0.12, 2.0, 2.6), metal, metal.darkened(0.15))

## Planta: duas folhas cruzadas, do jeito que o PS1 fazia vegetação.
func folhagem(base: Vector3, altura: float) -> void:
	var cor := Color("54754a")
	var largura := altura * 0.55
	# Normal para cima: a folha pega a mesma luz do chão e não fica preta de lado.
	malha_cenario.quadrilatero_duplo(base + Vector3(-largura, 0, 0), base + Vector3(largura, 0, 0), base + Vector3(largura, altura, 0), base + Vector3(-largura, altura, 0), cor, Vector3.UP)
	malha_cenario.quadrilatero_duplo(base + Vector3(0, 0, -largura), base + Vector3(0, 0, largura), base + Vector3(0, altura, largura), base + Vector3(0, altura, -largura), cor.darkened(0.1), Vector3.UP)

## Folhas de porta: ficam abertas, encostadas no batente; o vão é livre.
func construir_portas(grupo: Node2D) -> void:
	if grupo == null: return
	for porta: Node2D in grupo.get_children():
		var centro := em_metros(porta.position)
		var largura: float = porta.largura * ESCALA
		var painel := Vector3(largura, 2.05, 0.09) if porta.vertical else Vector3(0.09, 2.05, largura)
		malha_cenario.caixa(centro - painel / 2.0 + Vector3(0, painel.y / 2.0, 0), painel, CORES.madeira.lightened(0.12), CORES.madeira)
		portas.append({"nome": porta.name, "centro": centro})

# ---------------------------------------------------------------- montagem

func aplicar_malha() -> void:
	var instancia := MeshInstance3D.new()
	instancia.name = "Cenario"
	instancia.mesh = malha_cenario.gerar()
	var material := ShaderMaterial.new()
	material.shader = PS1
	instancia.material_override = material
	mundo.add_child(instancia)
	var corpo := StaticBody3D.new()
	corpo.name = "ColisaoCenario"
	var forma := CollisionShape3D.new()
	forma.shape = instancia.mesh.create_trimesh_shape()
	corpo.add_child(forma)
	mundo.add_child(corpo)

## Pedestres nas calçadas, a irmã perto de casa e carros nas duas faixas.
func povoar(transito: Node2D) -> void:
	var calcadas := [19.5, 24.5]
	var faixas := [21.25, 23.0]
	if transito:
		calcadas = [transito.calcada_casa_y * ESCALA, transito.calcada_oposta_y * ESCALA]
		faixas = [transito.faixa_oeste_y * ESCALA, transito.faixa_leste_y * ESCALA]
	for i in 6:
		var pessoa := Pessoa3D.new()
		pessoa.linha_z = calcadas[i % 2]
		pessoa.limites = Vector2(-6.0, 38.0)
		pessoa.sentido = 1.0 if i % 2 == 0 else -1.0
		pessoa.position = Vector3(2.0 + i * 5.5, 0.0, pessoa.linha_z)
		mundo.add_child(pessoa)
		pessoas.append(pessoa)
	var irma := Pessoa3D.new()
	irma.name = "Irma"
	irma.parada = true
	irma.cor_roupa = Color("23211f")
	irma.cor_pele = Color("c98a58")
	irma.position = inicio + Vector3(1.2, 0.0, 0.6)
	mundo.add_child(irma)
	pessoas.append(irma)
	for i in 4:
		var carro := Carro3D.new()
		carro.sentido = 1.0 if i % 2 == 0 else -1.0
		carro.linha_z = faixas[i % 2]
		carro.limites = Vector2(-12.0, 46.0)
		carro.position = Vector3(-8.0 + i * 11.0, 0.0, carro.linha_z)
		mundo.add_child(carro)
		carros.append(carro)
