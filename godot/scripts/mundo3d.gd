extends Node

# Constrói o subúrbio em 3D low poly a partir do mesmo mapa 2D de scenes/mapa.tscn.
# Nada é empilhado com nós de formas prontas: tudo vira triângulos numa malha só
# (MalhaLowPoly), com faces internas descartadas, áreas iguais juntadas em
# retângulos maiores e uma textura de atlas de 128 × 128 para o cenário inteiro.
const MAPA := preload("res://scenes/mapa.tscn")
const PS1 := preload("res://shaders/ps1.gdshader")
const ATLAS := preload("res://sprites/atlas3d.png")
const Pessoa3D := preload("res://scripts/pessoa3d.gd")
const Carro3D := preload("res://scripts/carro3d.gd")
## 32 pixels do mapa 2D = 1 metro.
const ESCALA := 1.0 / 32.0
const ALTURA_PAREDE := 2.6
const ALTURA_MURO := 2.15
const P := MalhaLowPoly.Peca
## Cada piso do mapa 2D vira uma peça do atlas com um leve tom por cima.
const PISOS := {
	"cimento": [P.CIMENTO, Color("cfd0c6")], "calcada": [P.CALCADA, Color("d8d8cf")],
	"asfalto": [P.ASFALTO, Color("f0f2f4")], "sarjeta": [P.ASFALTO, Color("d8dcdf")],
	"telha": [P.TELHA, Color("d6cdc4")], "taco": [P.TACO, Color("d9cbb6")],
	"ceramica_bege": [P.AZULEJO, Color("dcd6c2")], "azulejo_banheiro": [P.AZULEJO, Color("cfe0dc")],
	"azulejo_verde": [P.AZULEJO, Color("c6ddd0")], "ladrilho_floral": [P.AZULEJO, Color("ded7c4")],
	"grama_rala": [P.FOLHA, Color("bdd0ae")], "terra": [P.TERRA, Color("d3c4ae")],
}
var malha_cenario := MalhaLowPoly.new()
## Adornos (folhas de porta, plantas): aparecem, mas não barram a passagem.
var malha_adornos := MalhaLowPoly.new()
var material_ps1: ShaderMaterial
var mundo: Node3D
var jogador: CharacterBody3D
var pessoas: Array[Node3D] = []
var carros: Array[Node3D] = []
var inicio := Vector3(8.5, 0, 14.7)

func _ready() -> void:
	mundo = get_node("Tela/Render/Mundo")
	jogador = get_node("Tela/Render/Jogador")
	material_ps1 = ShaderMaterial.new()
	material_ps1.shader = PS1
	material_ps1.set_shader_parameter("atlas", ATLAS)
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
		if not PISOS.has(base): continue
		if not por_material.has(base): por_material[base] = {}
		por_material[base][cel] = true
	for material: String in por_material:
		var acabamento: Array = PISOS[material]
		for r: Rect2i in retangulos(por_material[material]):
			var origem := Vector2(r.position) * celula + camada.position
			var tamanho := Vector2(r.size) * celula
			malha_cenario.piso(origem * ESCALA, tamanho * ESCALA, altura, acabamento[1], acabamento[0])

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
			malha_cenario.caixa(Vector3(origem.x * ESCALA, 0.0, origem.y * ESCALA), Vector3(r.size.x * celula * ESCALA, 0.14, 6.0 * ESCALA), Color("d5d5cb"), Color("c2c2b8"), P.CALCADA, P.CALCADA)

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
		var da_casa := grupo == "casa"
		var altura: float = ALTURA_PAREDE if da_casa else ALTURA_MURO
		var peca: int = P.REBOCO if da_casa else P.PINTADO
		var tom := Color("efe8da") if da_casa else Color("dfe6d6")
		for r: Rect2i in retangulos(grupos[grupo]):
			var origem := Vector3(r.position.x * celula * ESCALA, 0.0, r.position.y * celula * ESCALA)
			var tamanho := Vector3(r.size.x * celula * ESCALA, altura, r.size.y * celula * ESCALA)
			malha_cenario.caixa(origem, tamanho, tom.darkened(0.1), tom, P.CIMENTO, peca)
	# Peitoril, verga e vidro: o vão da janela fica aberto no meio.
	for cel: Vector2i in janelas:
		var origem := Vector3(cel.x * celula * ESCALA, 0.0, cel.y * celula * ESCALA)
		var lado := celula * ESCALA
		malha_cenario.caixa(origem, Vector3(lado, 1.0, lado), Color("e4dccb"), Color("efe8da"), P.CIMENTO, P.REBOCO)
		malha_cenario.caixa(origem + Vector3(0, 2.0, 0), Vector3(lado, 0.6, lado), Color("e4dccb"), Color("efe8da"), P.CIMENTO, P.REBOCO)
		malha_cenario.caixa(origem + Vector3(0.1, 1.0, 0.1), Vector3(lado - 0.2, 1.0, lado - 0.2), Color("cfe0e4"), Color("cfe0e4"), P.VIDRO, P.VIDRO)

## Casas vizinhas: blocos fechados com telhado de duas águas nos limites do mapa.
func construir_vizinhos(limites: Node2D) -> void:
	var indice := 0
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
			indice += 1
			var fatia := Vector2(tamanho.x / passos, tamanho.y) if ao_longo_de_x else Vector2(tamanho.x, tamanho.y / passos)
			var origem := canto + (Vector2(fatia.x * i, 0.0) if ao_longo_de_x else Vector2(0.0, fatia.y * i))
			var altura := 3.0 + float(indice % 3) * 0.45
			# Alterna casa pintada e casa de tijolo sem reboco, como no subúrbio.
			var tijolo := indice % 3 == 0
			var peca: int = P.TIJOLO if tijolo else P.PINTADO
			var tons := [Color("e7e2d2"), Color("dbe3d2"), Color("e8dcc6"), Color("d8dde6")]
			var tom: Color = Color("e3d7c8") if tijolo else tons[indice % tons.size()]
			malha_cenario.caixa(Vector3(origem.x, 0.0, origem.y), Vector3(fatia.x, altura, fatia.y), tom.darkened(0.12), tom, P.CIMENTO, peca)
			malha_cenario.telhado(origem, fatia, altura, 0.9 + float(indice % 2) * 0.3, Color("dcc8bc"), tom, P.TELHA, peca)

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
	var madeira := Color("d6c3a8")
	var claro := Color("e8e4d8")
	match nome:
		"cama_verde", "cama_terracota":
			malha_cenario.caixa(canto + Vector3(0.1, 0, 0.1), Vector3(1.8, 0.45, 2.8), Color("b9c9bd"), madeira, P.TECIDO, P.TACO)
			malha_cenario.caixa(canto + Vector3(0.2, 0.45, 0.2), Vector3(1.6, 0.14, 0.7), claro, claro, P.LISO, P.LISO)
		"sofa_vertical", "sofa_horizontal", "poltrona":
			var deitado := nome == "sofa_horizontal"
			var tam := Vector3(2.8, 0.45, 1.7) if deitado else Vector3(1.7, 0.45, 2.8)
			malha_cenario.caixa(canto + Vector3(0.1, 0, 0.1), tam, Color("d2ddd4"), Color("c4d0c6"), P.TECIDO, P.TECIDO)
			var encosto := Vector3(tam.x, 0.45, 0.35) if deitado else Vector3(0.35, 0.45, tam.z)
			malha_cenario.caixa(canto + Vector3(0.1, 0.45, 0.1), encosto, Color("dae4dc"), Color("cdd8cf"), P.TECIDO, P.TECIDO)
		"guarda_roupa", "armario_cozinha", "estante":
			malha_cenario.caixa(canto + Vector3(0.05, 0, 0.05), Vector3(2.8, 2.0, 0.9), madeira.darkened(0.08), madeira, P.PORTA, P.PORTA)
		"comoda", "rack", "tv_aparador", "radio_aparador":
			malha_cenario.caixa(canto + Vector3(0.05, 0, 0.05), Vector3(1.8, 0.75, 0.85), madeira, madeira.darkened(0.06), P.TACO, P.PORTA)
			if nome == "tv_aparador":
				malha_cenario.caixa(canto + Vector3(0.35, 0.75, 0.25), Vector3(1.0, 0.8, 0.75), Color("8c8f8a"), Color("7b7f7a"), P.METAL, P.METAL)
				malha_cenario.caixa(canto + Vector3(0.42, 0.9, 0.18), Vector3(0.86, 0.58, 0.08), Color("b9ccd0"), Color("b9ccd0"), P.VIDRO, P.VIDRO)
			elif nome == "radio_aparador":
				malha_cenario.caixa(canto + Vector3(0.4, 0.75, 0.3), Vector3(0.9, 0.3, 0.35), Color("9a9a92"), Color("86867e"), P.METAL, P.METAL)
		"mesa_redonda", "mesa_cozinha", "mesa_retangular":
			malha_cenario.cilindro(canto + Vector3(0.9, 0.0, 0.9), 0.18, 0.7, 5, madeira.darkened(0.15), madeira, P.PORTA)
			malha_cenario.caixa(canto + Vector3(0.1, 0.7, 0.1), Vector3(1.7, 0.12, 1.7), madeira, madeira.darkened(0.08), P.TACO, P.TACO)
		"cadeira_madeira", "cadeira_plastica":
			malha_cenario.caixa(canto + Vector3(0.25, 0, 0.25), Vector3(0.55, 0.45, 0.55), madeira, madeira.darkened(0.1), P.TACO, P.PORTA)
			malha_cenario.caixa(canto + Vector3(0.25, 0.45, 0.25), Vector3(0.55, 0.5, 0.12), madeira, madeira.darkened(0.1), P.TACO, P.PORTA)
		"fogao":
			malha_cenario.caixa(canto + Vector3(0.1, 0, 0.1), Vector3(0.85, 0.9, 0.85), Color("dfe2dc"), Color("cfd2cc"), P.METAL, P.METAL)
			for p: Vector3 in [Vector3(0.28, 0.91, 0.3), Vector3(0.62, 0.91, 0.3), Vector3(0.28, 0.91, 0.62), Vector3(0.62, 0.91, 0.62)]:
				malha_cenario.cilindro(canto + p, 0.1, 0.02, 5, Color("3a3f3c"), Color("3a3f3c"), P.METAL)
		"geladeira":
			malha_cenario.caixa(canto + Vector3(0.08, 0, 0.08), Vector3(0.85, 1.75, 0.8), Color("e9ece2"), Color("dde0d6"), P.METAL, P.METAL)
		"pia_bancada", "pia_banheiro", "tanque", "maquina_lavar":
			var largura := 2.8 if nome == "pia_bancada" else 1.0
			malha_cenario.caixa(canto + Vector3(0.05, 0, 0.05), Vector3(largura, 0.9, 0.85), Color("e2e6e0"), Color("d4d8d2"), P.AZULEJO, P.AZULEJO)
			malha_cenario.caixa(canto + Vector3(0.2, 0.78, 0.2), Vector3(minf(largura, 0.9) - 0.1, 0.14, 0.5), Color("b8c6c4"), Color("aab8b6"), P.METAL, P.METAL)
		"vaso_sanitario":
			malha_cenario.caixa(canto + Vector3(0.25, 0, 0.3), Vector3(0.5, 0.42, 0.7), claro, claro, P.AZULEJO, P.AZULEJO)
			malha_cenario.caixa(canto + Vector3(0.25, 0.42, 0.3), Vector3(0.5, 0.45, 0.22), claro, claro, P.AZULEJO, P.AZULEJO)
		"filtro_barro", "potes", "balde", "lixeira", "saco_lixo", "tijolos_empilhados":
			var barro := nome == "filtro_barro" or nome == "potes"
			var cor := Color("d9b391") if barro else Color("aab0b4")
			malha_cenario.cilindro(canto + Vector3(0.5, 0, 0.5), 0.3, 0.6, 5, cor, cor.lightened(0.1), P.TIJOLO if barro else P.METAL)
		"casinha_cachorro":
			malha_cenario.caixa(canto + Vector3(0.1, 0, 0.1), Vector3(1.8, 0.9, 1.8), madeira, madeira.darkened(0.1), P.PORTA, P.PORTA)
			malha_cenario.telhado(Vector2(canto.x + 0.05, canto.z + 0.05), Vector2(1.9, 1.9), 0.9, 0.5, Color("d8c2b4"), madeira, P.TELHA, P.PORTA)
		"caixa_agua":
			malha_cenario.cilindro(canto + Vector3(1.0, 0.0, 1.0), 0.8, 1.2, 6, Color("9fc0c4"), Color("b2d0d4"), P.METAL)
		"poste":
			malha_cenario.cilindro(canto + Vector3(0.5, 0, 0.5), 0.12, 6.0, 5, Color("c9ccc6"), Color("c9ccc6"), P.CIMENTO)
			malha_cenario.caixa(canto + Vector3(0.5, 5.7, 0.4), Vector3(1.4, 0.12, 0.2), Color("c9ccc6"), Color("bcbfb9"), P.CIMENTO, P.CIMENTO)
			malha_cenario.caixa(canto + Vector3(1.7, 5.45, 0.35), Vector3(0.45, 0.25, 0.3), Color("f0e3b4"), Color("e2d4a4"), P.LISO, P.LISO)
		"varal":
			for dx: float in [0.2, 3.6]:
				malha_cenario.cilindro(canto + Vector3(dx, 0, 0.9), 0.07, 1.8, 4, Color("c8ccc6"), Color("c8ccc6"), P.METAL)
			malha_cenario.caixa(canto + Vector3(0.2, 1.75, 0.85), Vector3(3.4, 0.04, 0.05), Color("c8ccc6"), Color("c8ccc6"), P.METAL, P.METAL)
		"canteiro":
			malha_cenario.caixa(canto + Vector3(0.05, 0, 0.05), Vector3(2.9, 0.35, 0.9), Color("d2bfa4"), Color("c6b298"), P.TERRA, P.TIJOLO)
			folhagem(canto + Vector3(1.5, 0.35, 0.5), 0.8)
		"bananeira", "espada_sao_jorge", "samambaia", "mato":
			folhagem(canto + Vector3(0.5, 0.0, 0.5), 1.6 if nome == "bananeira" else 0.7)
		"portao_aberto", "portao_fechado":
			malha_cenario.caixa(canto + Vector3(0.0, 0, 0.2), Vector3(0.12, 2.0, 2.6), Color("b6bcb4"), Color("a8aea6"), P.METAL, P.METAL)

## Planta: duas folhas cruzadas com recorte na textura, como o PS1 fazia.
func folhagem(base: Vector3, altura: float) -> void:
	var cor := Color("cfe0b8")
	var largura := altura * 0.55
	malha_adornos.quadrilatero_duplo(base + Vector3(-largura, 0, 0), base + Vector3(largura, 0, 0), base + Vector3(largura, altura, 0), base + Vector3(-largura, altura, 0), cor, P.FOLHA, Vector3.UP)
	malha_adornos.quadrilatero_duplo(base + Vector3(0, 0, -largura), base + Vector3(0, 0, largura), base + Vector3(0, altura, largura), base + Vector3(0, altura, -largura), cor.darkened(0.08), P.FOLHA, Vector3.UP)

## Folhas de porta: abertas, encostadas na parede ao lado do vão, que fica livre.
func construir_portas(grupo: Node2D) -> void:
	if grupo == null: return
	for porta: Node2D in grupo.get_children():
		var centro := em_metros(porta.position)
		var largura: float = porta.largura * ESCALA
		var cor := Color("d9c4a6")
		if porta.vertical:
			# Vão no eixo Z: a folha abre para dentro, ao lado do batente.
			malha_adornos.caixa(centro + Vector3(-largura, 0.0, largura / 2.0 - 0.05), Vector3(largura, 2.05, 0.09), cor, cor.darkened(0.08), P.PORTA, P.PORTA)
		else:
			malha_adornos.caixa(centro + Vector3(largura / 2.0 - 0.05, 0.0, -largura), Vector3(0.09, 2.05, largura), cor, cor.darkened(0.08), P.PORTA, P.PORTA)

# ---------------------------------------------------------------- montagem

func aplicar_malha() -> void:
	var instancia := MeshInstance3D.new()
	instancia.name = "Cenario"
	instancia.mesh = malha_cenario.gerar()
	instancia.material_override = material_ps1
	mundo.add_child(instancia)
	# Só o cenário tem colisão: adornos não podem fechar passagem.
	var corpo := StaticBody3D.new()
	corpo.name = "ColisaoCenario"
	var forma := CollisionShape3D.new()
	forma.shape = instancia.mesh.create_trimesh_shape()
	corpo.add_child(forma)
	mundo.add_child(corpo)
	var adornos := MeshInstance3D.new()
	adornos.name = "Adornos"
	adornos.mesh = malha_adornos.gerar()
	adornos.material_override = material_ps1
	mundo.add_child(adornos)

## Pedestres nas calçadas, a irmã perto de casa e carros nas duas faixas.
func povoar(transito: Node2D) -> void:
	var calcadas := [19.5, 24.5]
	var faixas := [21.25, 23.0]
	if transito:
		calcadas = [transito.calcada_casa_y * ESCALA, transito.calcada_oposta_y * ESCALA]
		faixas = [transito.faixa_oeste_y * ESCALA, transito.faixa_leste_y * ESCALA]
	for i in 6:
		var pessoa := Pessoa3D.new()
		pessoa.material_compartilhado = material_ps1
		pessoa.linha_z = calcadas[i % 2]
		pessoa.limites = Vector2(-6.0, 38.0)
		pessoa.sentido = 1.0 if i % 2 == 0 else -1.0
		pessoa.position = Vector3(2.0 + i * 5.5, 0.0, pessoa.linha_z)
		mundo.add_child(pessoa)
		pessoas.append(pessoa)
	var irma := Pessoa3D.new()
	irma.name = "Irma"
	irma.material_compartilhado = material_ps1
	irma.parada = true
	irma.cor_roupa = Color("6b6a66")
	irma.cor_pele = Color("c98a58")
	irma.position = inicio + Vector3(1.2, 0.0, 0.6)
	mundo.add_child(irma)
	pessoas.append(irma)
	for i in 4:
		var carro := Carro3D.new()
		carro.material_compartilhado = material_ps1
		carro.sentido = 1.0 if i % 2 == 0 else -1.0
		carro.linha_z = faixas[i % 2]
		carro.limites = Vector2(-12.0, 46.0)
		carro.position = Vector3(-8.0 + i * 11.0, 0.0, carro.linha_z)
		mundo.add_child(carro)
		carros.append(carro)
