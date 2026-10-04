class_name Cidade3D
extends Node3D

# A cidade no horizonte, vista da laje, nos quatro estados do artefato. Cada
# estado é uma cena já podada (scenes/cidade_<estado>.scn): só o que fica a mais
# de 70 m do centro, que é onde a rua do jogo acaba.
#
# Junto com a cidade muda o ar: céu e cor da névoa acompanham o estado, então o
# bairro inteiro vai escurecendo conforme os dias passam.
#
# O calendário: 1 e 2 normais; de 3 a 6 a cidade fica estranha (o dia 6 é o
# breu, que é escuridão e não muda a cidade); o dia 7 é o ataque, com o céu
# vermelho; do 8 em diante é o que sobrou.
const ESTADOS := {
	"normal": {
		"ceu_topo": Color("27305a"), "ceu_baixo": Color("f2b27a"),
		"ar": Color("c98a74"), "distancia": 0.42, "luz": Color("b9b4ac"),
	},
	"estranha": {
		"ceu_topo": Color("1f2a26"), "ceu_baixo": Color("b8b27a"),
		"ar": Color("7d8466"), "distancia": 0.46, "luz": Color("9aa088"),
	},
	"chamas": {
		"ceu_topo": Color("2a0a10"), "ceu_baixo": Color("e02a16"),
		"ar": Color("8f2a1c"), "distancia": 0.38,
		# O céu é vermelho, mas a luz que chega no chão é só quente: se o ambiente
		# fosse vermelho puro, o bairro inteiro virava uma mancha de uma cor só.
		"luz": Color("c07a58"),
	},
	"destruida": {
		"ceu_topo": Color("3d3b3a"), "ceu_baixo": Color("6b635a"),
		"ar": Color("5e5750"), "distancia": 0.50, "luz": Color("8b857c"),
	},
}
const SHADER := preload("res://shaders/cidade.gdshader")
## A criatura e os helicópteros do pacote do artefato. No horizonte ela aparece
## inteira: a cena sabe se comportar como cenário (sem câmera e sem céu).
const MONSTRO := preload("res://monstro/monstro_cena.tscn")
const CORPO_DA_CRIATURA := preload("res://monstro/criatura_corpo.glb")
## Quantos focos de incêndio a mais, espalhados, quando a cidade queima.
const FOGOS_A_MAIS := 54
## Os vultos de criaturas que ficam no fundo da cidade destruída.
const VULTOS := 3
## O rumo para onde se olha da laje, e a que distância as coisas grandes ficam.
## O rumo é medido no plano do bairro, com 0 no +X. O centro da cidade — o anel
## de prédios altos, a uns 400 m — fica no −Z, que é para onde a laje dá, por
## cima do quintal. É lá que a criatura ataca.
const RUMO_DO_HORIZONTE := -PI / 2.0
const VULTO_LONGE := Vector2(760.0, 1250.0)
## Onde a criatura ataca: no meio do bairro de prédios altos que se vê da laje,
## e não num descampado atrás dele. No modelo ela vem a 430 m da origem da
## cena, por isso a cena inteira anda para encaixar aqui.
const RUMO_DA_CRIATURA := -PI / 2.0 + 0.18
const CRIATURA_LONGE := 400.0
const CRIATURA_NO_MODELO := 430.0
## Focos de incêndio extras bem em volta dela: é o rastro do ataque.
const FOGOS_NO_ATAQUE := 18

var estado := ""
var ambiente: Environment
var _corpo: Node3D
var _fogos: Array = []
var _fumacas: Array = []
var _piscas: Array = []
## A criatura em ataque e os vultos do fundo, filhos diretos deste nó.
var _criatura: Node3D
var _vultos: Array = []
var _tempo := 0.0
## Os materiais já montados, para mudar o ar deles quando a noite cai.
var _vestidos: Array = []

## Qual estado cabe no dia.
static func estado_do_dia(dia: int) -> String:
	if dia < 3: return "normal"
	if dia < 7: return "estranha"
	if dia == 7: return "chamas"
	return "destruida"

func mostrar_o_dia(dia: int) -> void:
	mostrar(estado_do_dia(dia))

func mostrar(novo: String) -> void:
	if novo == estado or not ESTADOS.has(novo): return
	estado = novo
	_vestidos.clear()
	if _criatura != null:
		remove_child(_criatura)
		_criatura.queue_free()
		_criatura = null
	for velho: Node3D in _vultos:
		remove_child(velho)
		velho.queue_free()
	_vultos.clear()
	if _corpo != null:
		remove_child(_corpo)
		_corpo.queue_free()
	var cena: PackedScene = load("res://scenes/cidade_%s.scn" % estado)
	if cena == null: return
	_corpo = cena.instantiate()
	add_child(_corpo)
	var dados: Dictionary = ESTADOS[estado]
	vestir(_corpo, dados["ar"], float(dados["distancia"]))
	# A guerra: a cidade pegando fogo em mais lugares e a criatura no meio dela,
	# com os helicópteros em volta.
	if estado == "chamas":
		espalhar_fogo(FOGOS_A_MAIS)
		por_a_criatura()
		fogo_em_volta(onde_a_criatura_ataca(), FOGOS_NO_ATAQUE)
	# Depois do ataque sobra o que eles deixaram — e eles, parados no fundo.
	if estado == "destruida": por_os_vultos(dados["ar"])
	# O que se mexe: chama tremendo, fumaça subindo, luz falhando.
	_fogos = _corpo.find_children("Fogo*", "", true, false)
	_piscas = _corpo.find_children("LuzPisca*", "", true, false)
	_fumacas.clear()
	for grupo in _corpo.find_children("Fumaca*", "", true, false):
		var quantos := grupo.get_child_count()
		if quantos < 2: continue
		var passo: float = (grupo.get_child(quantos - 1).position.y - grupo.get_child(0).position.y) / float(quantos - 1)
		_fumacas.append([grupo, passo * quantos])

## Mais focos de incêndio, copiados dos que o modelo já traz e espalhados em
## volta. O sorteio tem semente fixa: o incêndio é sempre o mesmo, como o resto
## do cenário.
func espalhar_fogo(quantos: int) -> void:
	var fogos := _corpo.find_children("Fogo*", "", true, false)
	if fogos.is_empty(): return
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 20261001
	for i in quantos:
		var molde := fogos[sorte.randi() % fogos.size()] as Node3D
		var copia := molde.duplicate() as Node3D
		copia.name = "FogoEspalhado%d" % (i + 1)
		var volta := sorte.randf_range(0.0, TAU)
		var longe := sorte.randf_range(25.0, 110.0)
		copia.position = molde.position + Vector3(cos(volta) * longe, sorte.randf_range(-6.0, 14.0), sin(volta) * longe)
		copia.scale = molde.scale * sorte.randf_range(0.7, 1.7)
		molde.get_parent().add_child(copia)

## Onde a criatura pisa, em coordenadas do bairro.
func onde_a_criatura_ataca() -> Vector3:
	return Vector3(cos(RUMO_DA_CRIATURA), 0.0, sin(RUMO_DA_CRIATURA)) * CRIATURA_LONGE

## Fogo em volta de um ponto: o quarteirão que a criatura está pisando agora.
func fogo_em_volta(onde: Vector3, quantos: int) -> void:
	var fogos := _corpo.find_children("Fogo*", "", true, false)
	if fogos.is_empty(): return
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 7102026
	for i in quantos:
		var molde := fogos[sorte.randi() % fogos.size()] as Node3D
		var copia := molde.duplicate() as Node3D
		copia.name = "FogoDoAtaque%d" % (i + 1)
		var volta := sorte.randf_range(0.0, TAU)
		var longe := sorte.randf_range(18.0, 120.0)
		copia.position = Vector3(onde.x + cos(volta) * longe, molde.position.y, onde.z + sin(volta) * longe)
		copia.scale = molde.scale * sorte.randf_range(1.0, 2.2)
		_corpo.add_child(copia)

## A criatura atacando, com os helicópteros respondendo. Ela vem da cena do
## artefato, que no modelo deixa o bicho 430 m no −Z; girar põe esse rumo na
## direção em que se olha da laje.
func por_a_criatura() -> void:
	_criatura = MONSTRO.instantiate()
	_criatura.name = "Criatura"
	_criatura.so_a_criatura = true
	# A cidade em ruínas que vem na cena fica de fora: a nossa já está aqui.
	var ruinas := _criatura.get_node_or_null("Cidade")
	if ruinas != null:
		_criatura.remove_child(ruinas)
		ruinas.queue_free()
	# A cena olha para o próprio −Z; girar põe esse rumo no do ataque, e depois a
	# cena inteira recua os 430 m que o modelo já tem, para a criatura cair onde
	# se quer.
	var para_onde := Vector3(cos(RUMO_DA_CRIATURA), 0.0, sin(RUMO_DA_CRIATURA))
	_criatura.rotation.y = atan2(-para_onde.x, -para_onde.z)
	_criatura.position = para_onde * (CRIATURA_LONGE - CRIATURA_NO_MODELO)
	add_child(_criatura)

## Vultos de criaturas no fundo da cidade destruída: mesmas formas, pintadas de
## sombra, longe demais para se ver mais do que o contorno.
func por_os_vultos(ar: Color) -> void:
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 972026
	for i in VULTOS:
		# É a mesma criatura da guerra, de corpo inteiro e mexendo as pernas —
		# só que sem helicóptero, sem fogo e pintada de sombra.
		var vulto: Node3D = MONSTRO.instantiate()
		vulto.name = "VultoGigante%d" % (i + 1)
		vulto.so_a_criatura = true
		vulto.numero_de_helicopteros = 0
		vulto.aplicar_ps1 = false
		var ruinas := vulto.get_node_or_null("Cidade")
		if ruinas != null:
			vulto.remove_child(ruinas)
			ruinas.queue_free()
		var rumo := RUMO_DO_HORIZONTE + sorte.randf_range(-1.15, 1.15)
		var longe := sorte.randf_range(VULTO_LONGE.x, VULTO_LONGE.y)
		var tamanho := sorte.randf_range(0.7, 1.05)
		var para_onde := Vector3(cos(rumo), 0.0, sin(rumo))
		vulto.scale = Vector3.ONE * tamanho
		# A cena deixa a criatura 430 m no próprio −Z; a conta leva ela ao lugar.
		vulto.rotation.y = atan2(-para_onde.x, -para_onde.z) + sorte.randf_range(-0.4, 0.4)
		vulto.position = para_onde * (longe - CRIATURA_NO_MODELO * tamanho)
		add_child(vulto)
		# O que a cena cria para fogo, fumaça e tiro fica de fora: aqui é só o vulto.
		for filho in vulto.get_children():
			if filho is MeshInstance3D: (filho as MeshInstance3D).visible = false
		pintar_de_sombra(vulto.get_node("Criatura"), ar.darkened(0.68))
		_vultos.append(vulto)

## Silhueta chapada: sem luz, sem névoa e sem textura. É o que se enxerga de um
## quilômetro.
func pintar_de_sombra(no: Node, cor: Color) -> void:
	var sombra := StandardMaterial3D.new()
	sombra.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sombra.albedo_color = cor
	sombra.disable_fog = true
	for m in no.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = sombra

## Troca os materiais pelo shader da cidade, guardando a textura de cada peça.
func vestir(no: Node, ar: Color, distancia: float) -> void:
	var prontos := {}
	for m in no.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null: continue
		for i in mi.mesh.get_surface_count():
			var origem := mi.get_active_material(i)
			if not (origem is BaseMaterial3D): continue
			var base := origem as BaseMaterial3D
			var chave := base.get_instance_id()
			if not prontos.has(chave):
				var material := ShaderMaterial.new()
				material.shader = SHADER
				material.set_shader_parameter("albedo_tex", base.albedo_texture)
				material.set_shader_parameter("tint", base.albedo_color.srgb_to_linear() if base.albedo_texture == null else Color.WHITE)
				material.set_shader_parameter("ar", ar)
				material.set_shader_parameter("distancia", distancia)
				prontos[chave] = material
				_vestidos.append(material)
			mi.set_surface_override_material(i, prontos[chave])


func _process(delta: float) -> void:
	if _corpo == null: return
	_tempo += delta
	for i in _fogos.size():
		var grupo: Node3D = _fogos[i]
		for k in grupo.get_child_count():
			var lingua: Node3D = grupo.get_child(k)
			var largura := 0.9 + sin(_tempo * 5.0 + k + i) * 0.12
			lingua.scale = Vector3(largura, 0.75 + absf(sin(_tempo * (7.0 + k) + i * 3.0)) * 0.5, largura)
	for i in _fumacas.size():
		var grupo: Node3D = _fumacas[i][0]
		var altura: float = _fumacas[i][1]
		for k in grupo.get_child_count():
			var bola: Node3D = grupo.get_child(k)
			bola.position.y += delta * 3.0 * (1.0 + k * 0.1)
			if bola.position.y > altura: bola.position.y = 0.0
			var subiu := bola.position.y / altura
			bola.scale = Vector3.ONE * (0.6 + subiu * 1.6)
			bola.position.x = sin(_tempo * 0.3 + i + k) * subiu * altura * 0.15 + subiu * altura * 0.3
	for i in _vultos.size():
		var vulto: Node3D = _vultos[i]
		vulto.rotation.y += sin(_tempo * 0.07 + i) * 0.0004
		vulto.position.y = sin(_tempo * 0.21 + i * 2.0) * 1.6
	for i in _piscas.size():
		_piscas[i].visible = sin(_tempo * (3.0 + i % 5) + i * 1.7) * sin(_tempo * 0.9 + i) > -0.2

## As cores do ar no estado de hoje. O mundo mistura a noite por cima delas.
## Muda a cor do ar da cidade inteira. É assim que a noite — e o breu — chegam
## no horizonte: a silhueta se dissolve na mesma cor do resto do céu.
func ajustar_ar(cor: Color, distancia: float) -> void:
	for material: ShaderMaterial in _vestidos:
		material.set_shader_parameter("ar", cor)
		material.set_shader_parameter("distancia", distancia)

func ar_do_estado() -> Dictionary:
	return ESTADOS.get(estado, ESTADOS["normal"])
