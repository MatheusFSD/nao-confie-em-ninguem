class_name Casa3D
extends RefCounted

# A casa do protagonista em 3D: um modelo só (modelos/casa/casa.glb), com a
# estrutura, os móveis já arrumados nos cômodos, a varanda, o quintal, a escada
# externa e a laje. As portas são nós com a origem na dobradiça — girar em Y
# abre. A colisão não vem do modelo: vem de data/casa3d.json, que traz as caixas
# de paredes, móveis e muros, e o ângulo de abertura de cada porta.
#
# No modelo, +Z é a rua: o portão fica em z = 9,6 e a porta da frente em z = 6.
const MODELO := preload("res://modelos/casa/casa.glb")
## O cadeado que aparece na porta trancada, no mesmo desenho dos ícones do HUD.
const CADEADO := preload("res://ui/hud/cadeado.webp")
const DADOS := "res://data/casa3d.json"
## Medidas do modelo, em metros.
const PISO := 0.12       # o piso da casa é 12 cm acima do quintal
const PAREDE := 2.9      # altura das paredes
const LAJE := 3.08       # topo da laje
## Quanto a porta anda por segundo ao abrir ou fechar.
const VELOCIDADE := 3.5
## A pilha de tijolos vinha no corredor lateral, que tem 1,6 m de largura, e
## entupia a passagem. Vai para o fundo do quintal, encostada no muro.
## As janelas da frente, medidas no vão de verdade da parede: a da sala e a do
## quarto, as duas dando para a rua. É por elas que se olha sem abrir a porta.
const FRESTAS := [
	{"nome": "sala", "x": -1.1, "largura": 1.3},
	{"nome": "quarto", "x": 3.03, "largura": 1.55},
]
## Onde fica a parede da frente e a altura do peitoril, no modelo.
const PAREDE_DA_FRENTE := 5.93
const PEITORIL := 1.05
const TIJOLOS_ANTES := Vector3(-5.8, 0.0, -1.5)
const TIJOLOS_DEPOIS := Vector3(-5.4, 0.0, -7.4)

var raiz: Node3D
var corpo: StaticBody3D
## Cada porta: { no, corpo, alvo, aberta, nome }.
var portas: Array = []
## Onde ficam as caixas dos móveis com corpo próprio, para elas não entrarem
## também no corpo do resto da casa.
var colisoes_separadas: Array = []
## O corpo da cama, que é onde o dia termina.
var cama: StaticBody3D
## O corpo da TV de tubo da sala.
var tv: StaticBody3D
## As janelas da frente: { nome, corpo, olhar } — `olhar` é de onde se espia.
var frestas: Array = []
## As lâmpadas dos cômodos, que só acendem quando escurece.
var lampadas: Array = []
## O vidro por cima da tela da TV de tubo (apagada no jogo, chiando no menu).
var tela_da_tv: MeshInstance3D

## Põe a casa no mundo, com a origem do modelo em `lugar`.
func montar(pai: Node3D, lugar: Vector3, resolucao: Vector2) -> void:
	raiz = MODELO.instantiate()
	raiz.name = "Casa"
	raiz.position = lugar
	pai.add_child(raiz)
	Modelos3D.separar_coladas(raiz)
	RuaModelo.aplicar_ps1(raiz, resolucao)
	mudar_tijolos()
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	corpo = StaticBody3D.new()
	corpo.name = "ColisaoCasa"
	corpo.position = lugar
	pai.add_child(corpo)
	# Dois móveis ganham corpo próprio, marcado, porque dá para usá-los.
	cama = separar_movel(dados, "Movel_Camadecasal", "cama", 1.2)
	tv = separar_movel(dados, "Movel_TVdetubonorack", "tv", 0.9)
	separar_movel(dados, "Movel_Bancadacompia", "torneira", 0.9)
	separar_movel(dados, "Movel_Piadebanheiro", "torneira", 0.65)
	# O sofá da sala é onde o tempo passa de propósito.
	separar_movel(dados, "Movel_Sof", "sofa", 1.1)
	# O rádio da sala: notícia enquanto houver luz.
	separar_movel(dados, "Movel_Rdionomvel", "radio", 0.5)
	abrir_as_frestas(lugar)
	# Paredes, móveis, muros e a mureta da laje, como vieram do modelo.
	for c: Array in dados.colisoes:
		var a := Vector3(c[0], c[4], c[2])
		var b := Vector3(c[1], c[5], c[3])
		# Os móveis com corpo próprio são pulados aqui.
		if e_separada((a + b) / 2.0): continue
		# A pilha de tijolos anda junto com a sua caixa de colisão.
		var meio := (a + b) / 2.0
		if Vector2(meio.x - TIJOLOS_ANTES.x, meio.z - TIJOLOS_ANTES.z).length() < 0.8 and b.y < 0.5:
			a += TIJOLOS_DEPOIS - TIJOLOS_ANTES
			b += TIJOLOS_DEPOIS - TIJOLOS_ANTES
		caixa(a, b)
	# Os pisos: casa, varanda, laje e patamar da escada. O quintal e a rua ficam
	# por conta do terreno do bairro, que já passa por baixo.
	caixa(Vector3(-5, 0, -6), Vector3(5, PISO, 6))
	caixa(Vector3(-5.175, 0, 6.075), Vector3(1.075, PISO, 7.875))
	caixa(Vector3(-5.15, PAREDE, -6.15), Vector3(5.15, LAJE, 6.15))
	caixa(Vector3(5.15, 0, -5.92), Vector3(6.27, LAJE, -3.5))
	# A escada externa é uma rampa invisível, do pé até o patamar.
	var rampa := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(1.1, 0.1, Vector2(7.0, LAJE).length())
	rampa.shape = forma
	rampa.position = Vector3(5.7, LAJE / 2.0 - 0.05, 0.0)
	rampa.rotation.x = atan2(LAJE, 7.0)
	corpo.add_child(rampa)
	# Corrimão do lado de fora da escada.
	caixa(Vector3(6.25, 0, -5.92), Vector3(6.35, LAJE + 1.0, 3.5))
	# Guarda-corpo na ponta do patamar: sem ele, quem chegava ao fim do patamar
	# caía para fora do lote. Tem corpo e tem desenho (grade de ferro).
	caixa(Vector3(5.0, LAJE, -6.15), Vector3(6.35, LAJE + 1.0, -5.92))
	por_o_guarda_corpo(lugar, resolucao)
	# Duas rampinhas de 12 cm: entrada da varanda e porta dos fundos.
	rampinha(-3.55, -2.35, 7.875, 8.4)
	rampinha(-3.45, -2.45, -6.075, -6.6)
	# Chão do lote: sem desenho, só colisão. O quintal quem mostra é o modelo,
	# e duas superfícies no mesmo nível brigariam pelo pixel.
	caixa(Vector3(-7.0, -0.5, -9.0), Vector3(7.5, 0.0, 10.0))

	for p: Dictionary in dados.portas:
		armar_porta(String(p.nome), float(p.alvo))
	acender()

## Uma lâmpada por cômodo, no teto. Com a casa fechada, é a luz elétrica que
## deixa ver lá dentro — o sol só entra pelas janelas e pela porta.
func acender() -> void:
	var comodos := {
		"Sala": Vector2(-2.5, 3.0), "Quarto": Vector2(2.5, 3.5),
		"Banheiro": Vector2(3.5, 0.0), "AreaDeServico": Vector2(2.5, -3.5),
		"Corredor": Vector2(1.5, 0.0), "Cozinha": Vector2(-2.5, -3.0),
	}
	for nome: String in comodos:
		var lugar: Vector2 = comodos[nome]
		var lampada := OmniLight3D.new()
		lampada.name = nome
		lampada.position = Vector3(lugar.x, PAREDE - 0.35, lugar.y)
		lampada.light_color = Color("ffd7a4")
		lampada.light_energy = 1.5
		lampada.omni_range = 6.0
		lampada.light_specular = 0.0
		raiz.add_child(lampada)
		lampadas.append(lampada)
	# A da varanda é mais fraca e mais fria, como lâmpada de fora.
	var varanda := OmniLight3D.new()
	varanda.name = "Varanda"
	varanda.position = Vector3(-2.2, 2.4, 6.9)
	varanda.light_color = Color("ffe2b0")
	varanda.light_energy = 1.1
	varanda.omni_range = 4.5
	varanda.light_specular = 0.0
	raiz.add_child(varanda)
	lampadas.append(varanda)
	acender_luzes(false)

## Tira a pilha de tijolos do corredor lateral e põe no fundo do quintal.
func mudar_tijolos() -> void:
	var pilha: Node3D = raiz.find_child("Movel_Pilhadetijolos", true, false)
	if pilha == null: return
	pilha.position = TIJOLOS_DEPOIS
	pilha.rotation.y = PI / 2.0

## Cada janela da frente ganha uma caixa marcada, rente ao vão, por dentro da
## casa. Mirar nela é encostar na cortina; o jogo cuida do resto.
func abrir_as_frestas(lugar: Vector3) -> void:
	for i in FRESTAS.size():
		var dados: Dictionary = FRESTAS[i]
		var corpo := StaticBody3D.new()
		corpo.name = "Janela%s" % String(dados.nome).capitalize()
		corpo.position = lugar + Vector3(float(dados.x), PEITORIL + 0.5, PAREDE_DA_FRENTE - 0.12)
		corpo.set_meta("janela", i)
		# Fora da camada do morador: a cortina não é parede.
		corpo.collision_layer = 16
		corpo.collision_mask = 0
		var forma := CollisionShape3D.new()
		var caixa_da_janela := BoxShape3D.new()
		caixa_da_janela.size = Vector3(float(dados.largura), 1.0, 0.16)
		forma.shape = caixa_da_janela
		corpo.add_child(forma)
		self.raiz.get_parent().add_child(corpo)
		frestas.append({
			"nome": String(dados.nome),
			"corpo": corpo,
			# A câmera passa do vidro e da cortina: é o que o olho alcança quando o
			# pano é afastado. Atrás do vidro só se vê o próprio pano.
			"olhar": lugar + Vector3(float(dados.x), PEITORIL + 0.62, PAREDE_DA_FRENTE + 0.14),
		})

## Um móvel ganha corpo próprio, marcado, para o jogo saber quando o olhar está
## nele — é assim que se vai dormir na cama e ligar a TV. As caixas em volta do
## móvel saem do corpo geral da casa e vêm para este.
func separar_movel(dados: Dictionary, no_modelo: String, marca: String, raio: float) -> StaticBody3D:
	var movel: Node3D = raiz.find_child(no_modelo, true, false)
	if movel == null: return null
	var proprio := StaticBody3D.new()
	proprio.name = marca.capitalize()
	proprio.position = corpo.position
	proprio.set_meta(marca, true)
	corpo.get_parent().add_child(proprio)
	for c: Array in dados.colisoes:
		var meio := Vector3((c[0] + c[1]) / 2.0, (c[4] + c[5]) / 2.0, (c[2] + c[3]) / 2.0)
		# Só as caixas em volta do móvel: o resto continua no corpo da casa.
		if Vector2(meio.x - movel.position.x, meio.z - movel.position.z).length() > raio: continue
		if meio.y > 1.6: continue
		if e_separada(meio): continue
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(absf(c[1] - c[0]), 0.02), maxf(absf(c[5] - c[4]), 0.02), maxf(absf(c[3] - c[2]), 0.02))
		forma.shape = box
		forma.position = meio
		proprio.add_child(forma)
		colisoes_separadas.append(meio)
	return proprio
## A tela da TV de tubo: no modelo, dois triângulos com um jogo de futebol
## pintado na textura (o verde do gramado). Acha os dois pela cor e põe por cima
## um vidro do mesmo tamanho, com o material pedido. Devolve o vidro.
func cobrir_a_tela(material: Material) -> MeshInstance3D:
	var movel := raiz.find_child("Movel_TVdetubonorack", true, false) as MeshInstance3D
	if movel == null or movel.mesh == null: return null
	var pontos := PackedVector3Array()
	var normal := Vector3.ZERO
	for s in movel.mesh.get_surface_count():
		var mat := movel.get_active_material(s)
		var tex: Texture2D = null
		if mat is ShaderMaterial: tex = (mat as ShaderMaterial).get_shader_parameter("albedo_tex")
		elif mat is StandardMaterial3D: tex = (mat as StandardMaterial3D).albedo_texture
		if tex == null: continue
		var img := tex.get_image()
		if img.is_compressed(): img.decompress()
		var arrays := movel.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var n: int = idx.size() / 3 if idx != null and idx.size() > 0 else vs.size() / 3
		for t in n:
			var trio := [t * 3, t * 3 + 1, t * 3 + 2]
			if idx != null and idx.size() > 0: trio = [idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]]
			var uv: Vector2 = (uvs[trio[0]] + uvs[trio[1]] + uvs[trio[2]]) / 3.0
			var cor := img.get_pixel(clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1), clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1))
			if not (cor.g > cor.r + 0.1 and cor.g > cor.b + 0.05): continue
			var a: Vector3 = movel.global_transform * vs[trio[0]]
			var b: Vector3 = movel.global_transform * vs[trio[1]]
			var c: Vector3 = movel.global_transform * vs[trio[2]]
			pontos.append_array([a, b, c])
			normal += (b - a).cross(c - a)
	if pontos.is_empty(): return null
	normal = normal.normalized()
	# A tela olha para a sala: o lado oposto ao do móvel.
	if normal.dot(pontos[0] - movel.global_position) < 0.0: normal = -normal
	var direita := Vector3.UP.cross(normal).normalized()
	var cima := normal.cross(direita).normalized()
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	var origem := pontos[0]
	for p in pontos:
		var d := p - origem
		var plano := Vector2(d.dot(direita), d.dot(cima))
		minimo = minimo.min(plano)
		maximo = maximo.max(plano)
	var meio := (minimo + maximo) / 2.0
	var vidro := MeshInstance3D.new()
	vidro.name = "TelaDaTV"
	var quad := QuadMesh.new()
	quad.size = maximo - minimo
	vidro.mesh = quad
	vidro.material_override = material
	raiz.get_parent().add_child(vidro)
	vidro.global_transform = Transform3D(Basis(direita, cima, normal), origem + direita * meio.x + cima * meio.y + normal * 0.008)
	tela_da_tv = vidro
	return vidro

## A grade de ferro na ponta do patamar da escada: três pilares, o corrimão em
## cima e uma travessa no meio, pintados de cinza-escuro.
func por_o_guarda_corpo(lugar: Vector3, resolucao: Vector2) -> void:
	var ferro := StandardMaterial3D.new()
	ferro.albedo_color = Color(0.16, 0.16, 0.17)
	ferro.roughness = 0.6
	var material := RuaModelo.converter(ferro, resolucao)
	var grade := Node3D.new()
	grade.name = "GuardaCorpo"
	grade.position = lugar
	raiz.get_parent().add_child(grade)
	var z := -6.03
	var pecas := [
		[Vector3(5.67, LAJE + 0.97, z), Vector3(1.3, 0.06, 0.06)],
		[Vector3(5.67, LAJE + 0.5, z), Vector3(1.3, 0.04, 0.04)],
	]
	for x in [5.05, 5.67, 6.3]:
		pecas.append([Vector3(x, LAJE + 0.5, z), Vector3(0.05, 1.0, 0.05)])
	for x in [5.3, 5.48, 5.86, 6.05]:
		pecas.append([Vector3(x, LAJE + 0.5, z), Vector3(0.025, 0.94, 0.025)])
	for peca: Array in pecas:
		var barra := MeshInstance3D.new()
		var caixa_malha := BoxMesh.new()
		caixa_malha.size = peca[1]
		barra.mesh = caixa_malha
		barra.material_override = material
		barra.position = peca[0]
		grade.add_child(barra)

## A TV desligada: vidro de tubo escuro, sem imagem nenhuma.
func apagar_a_tela(resolucao: Vector2) -> void:
	var vidro := StandardMaterial3D.new()
	vidro.albedo_color = Color(0.07, 0.085, 0.08)
	vidro.roughness = 0.2
	cobrir_a_tela(RuaModelo.converter(vidro, resolucao))

## Caixa de colisão, em coordenadas do modelo.
func caixa(a: Vector3, b: Vector3) -> void:
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var tamanho := (b - a).abs()
	box.size = Vector3(maxf(tamanho.x, 0.02), maxf(tamanho.y, 0.02), maxf(tamanho.z, 0.02))
	forma.shape = box
	forma.position = (a + b) / 2.0
	corpo.add_child(forma)

## Rampa rasa para vencer o degrau de 12 cm sem depender do passo do jogador.
func rampinha(x0: float, x1: float, z_alto: float, z_baixo: float) -> void:
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, 0.04, Vector2(z_baixo - z_alto, PISO).length())
	forma.shape = box
	forma.position = Vector3((x0 + x1) / 2.0, PISO / 2.0 - 0.02, (z_alto + z_baixo) / 2.0)
	forma.rotation.x = atan2(PISO, z_baixo - z_alto)
	corpo.add_child(forma)

## Cada porta ganha um corpo que gira junto com a folha: fechada ela barra,
## aberta deixa passar. O corpo carrega o índice da porta, que é como o jogo
## sabe qual porta está na mira.
func armar_porta(nome: String, alvo: float) -> void:
	var no: Node3D = raiz.find_child("Porta_" + nome, true, false)
	if no == null: return
	var limites := caixa_local(no)
	var folha := AnimatableBody3D.new()
	folha.sync_to_physics = false
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(limites.size.x, 0.06), maxf(limites.size.y, 0.06), maxf(limites.size.z, 0.06))
	forma.shape = box
	forma.position = limites.get_center()
	folha.add_child(forma)
	folha.set_meta("porta", portas.size())
	no.add_child(folha)
	# `trancada` só vale para as portas que dão para a rua; por elas é que alguém
	# entra de madrugada.
	# O cadeado aparece na altura da maçaneta quando a porta está trancada. São
	# dois, um em cada face da folha: senão ele some de quem está do outro lado.
	var cadeados: Array = []
	var fino := 0
	if limites.size.y < limites.size[fino]: fino = 1
	if limites.size.z < limites.size[fino]: fino = 2
	for lado in [1.0, -1.0]:
		var cadeado := Sprite3D.new()
		cadeado.name = "Cadeado%s" % ("Fora" if lado > 0.0 else "Dentro")
		cadeado.texture = CADEADO
		cadeado.pixel_size = 0.018
		cadeado.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cadeado.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		cadeado.position = limites.get_center()
		cadeado.position.y = limites.position.y + limites.size.y * 0.52
		cadeado.position[fino] += lado * (limites.size[fino] * 0.5 + 0.05)
		cadeado.visible = false
		no.add_child(cadeado)
		cadeados.append(cadeado)
	portas.append({"no": no, "corpo": folha, "alvo": alvo, "aberta": false, "trancada": false, "nome": nome, "cadeados": cadeados})

func caixa_local(no: Node3D) -> AABB:
	var total := AABB()
	var primeiro := true
	for m in no.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := no.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		total = b if primeiro else total.merge(b)
		primeiro = false
	return total

## Abre ou fecha a porta de índice `i`. Devolve o que ela passou a ser. Porta
## trancada não abre: primeiro se destranca.
func acionar(i: int) -> bool:
	var p: Dictionary = portas[i]
	if p.trancada and not p.aberta: return false
	p.aberta = not p.aberta
	var giro: float = p.alvo if p.aberta else 0.0
	var no: Node3D = p.no
	var volta := no.create_tween()
	volta.tween_property(no, "rotation:y", giro, absf(giro - no.rotation.y) / VELOCIDADE + 0.1).set_trans(Tween.TRANS_SINE)
	return p.aberta

## O ponto da porta no mundo, para o som sair dela.
func onde_fica_a_porta(i: int) -> Vector3:
	return (portas[i].no as Node3D).global_position + Vector3(0.0, 1.0, 0.0)

## Índice da porta que o corpo pertence, ou -1.
func porta_de(colisor: Object) -> int:
	if colisor != null and colisor.has_meta("porta"): return colisor.get_meta("porta")
	return -1

## "a porta da frente", "a porta dos fundos", "o portão": para as frases.
func nome_completo(i: int) -> String:
	match String(portas[i].nome):
		"frente": return "a porta da frente"
		"fundos": return "a porta dos fundos"
		"portao": return "o portão"
	return "a porta"

func nome_da_porta(i: int) -> String:
	return "portão" if String(portas[i].nome) == "portao" else "porta"

func esta_aberta(i: int) -> bool:
	return portas[i].aberta

func esta_trancada(i: int) -> bool:
	return portas[i].trancada

## Só as portas para a rua têm tranca.
func tem_tranca(i: int) -> bool:
	return String(portas[i].nome) in ["frente", "fundos", "portao"]

## Tranca ou destranca, com a mesma regra do jogo 2D: porta aberta não tranca.
## Devolve o que dizer ao jogador.
func trancar(i: int) -> String:
	var artigo := "o portão" if String(portas[i].nome) == "portao" else "a porta"
	if not tem_tranca(i): return "Essa %s não tem tranca." % nome_da_porta(i)
	if portas[i].aberta: return "Feche %s antes de trancar." % artigo
	portas[i].trancada = not portas[i].trancada
	for cadeado: Sprite3D in portas[i].get("cadeados", []):
		cadeado.visible = portas[i].trancada
	return ("Você trancou %s." if portas[i].trancada else "Você destrancou %s.") % artigo

## As portas que dão para fora. É por elas que o ladrão entra, de noite.
func externas() -> Array:
	var saida := []
	for i in portas.size():
		if String(portas[i].nome) in ["frente", "fundos", "portao"]: saida.append(i)
	return saida

## A caixa já foi para o corpo de um móvel? Comparado pelo centro, com folga de
## um milímetro.
func e_separada(meio: Vector3) -> bool:
	for lugar: Vector3 in colisoes_separadas:
		if meio.distance_to(lugar) < 0.001: return true
	return false

## As portas que dão para a rua e ficaram abertas: por elas alguém entra de
## madrugada. Devolve os nomes, como o jogo 2D mostra.
## As portas para a rua que passaram a noite sem tranca — abertas ou só
## encostadas. É por elas que alguém entra de madrugada, como no jogo 2D.
func portas_abertas_para_a_rua() -> Array:
	var soltas := []
	for i in externas():
		if esta_aberta(i) or not esta_trancada(i): soltas.append(nome_completo(i))
	return soltas

## Acende ou apaga a casa inteira. De dia o sol e as janelas bastam; de noite é
## a luz elétrica que mostra os cômodos.
func acender_luzes(ligadas: bool) -> void:
	for lampada: OmniLight3D in lampadas:
		lampada.visible = ligadas
