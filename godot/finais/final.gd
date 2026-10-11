class_name Final3D
extends Control
## Os finais do jogo, no jeito de "No, I'm Not a Human": tela preta, uma
## ilustração emoldurada e frases aparecendo uma a uma embaixo. Aqui a
## ilustração é uma cena 3D low poly montada com as peças do próprio jogo, e
## tudo (imagem e texto) passa pelo filtro de fita da tela (shaders/tela.gdshader).
##
## Os textos ficam em data/finais.json. Para abrir um final:
##   get_tree().change_scene_to_file("res://finais/final_morte.tscn")
##   get_tree().change_scene_to_file("res://finais/final_sobrevivencia.tscn")
##   get_tree().change_scene_to_file("res://finais/final_abrigo.tscn")
##   get_tree().change_scene_to_file("res://finais/final_confiar.tscn")

signal terminou

@export_enum("morte", "sobrevivencia", "abrigo", "confiar") var tipo := "morte"
## Para onde ir quando o jogador confirma na última tela. Vazio = só emite "terminou".
@export var cena_ao_terminar := "res://scenes/menu_inicial.tscn"
@export var resolucao := Vector2i(320, 213)
## Quanto de fita: 1 é o máximo do filtro.
@export_range(0.0, 1.0) var fita := 1.0

const TEXTOS := "res://data/finais.json"
const POSES := "res://data/poses_mortos.json"
const FONTE_ARQUIVO := preload("res://tv/PixelifySans.ttf")
const TELA := preload("res://shaders/tela.gdshader")
const CHUVISCO := preload("res://finais/chuvisco_3d.gdshader")
const RUA := "res://modelos/rua/rua_penha.glb"
const PROTAGONISTA := "res://modelos/personagens/protagonista.glb"
const CACADOR := "res://modelos/cacador/cacador.tscn"
const TV := "res://modelos/objetos/tv_de_tubo_no_rack.glb"
const SOFA := "res://modelos/objetos/sofa.glb"
const RADIO := "res://modelos/objetos/radio_no_movel.glb"
const CAMINHAO := "res://modelos/veiculos/caminhao.tscn"
const TANQUE := "res://modelos/veiculos/tanque.tscn"
const MONSTRO := "res://modelos/monstro/monstro_cena.tscn"
const PERUA := "res://modelos/carros/perua.tscn"
const PESSOAS := ["dona_celia", "seu_ze", "vanessa", "tania", "aline", "jessica", "rogerio", "anderson", "entregador", "marquinhos"]
## Onde a ilustração aparece na tela pequena; o resto é preto.
const JANELA := Rect2(36, 12, 248, 140)
const ESCREVE := 30.0          # letras por segundo
const ENTRE_LINHAS := 2.4      # segundos entre o começo de uma linha e o da próxima
const FADE := 0.9

var dados: Dictionary
var cartoes: Array
var indice := -1
var t := 0.0
var t_fim := 0.0
var no_fim := false
var render: SubViewport
var imagem: TextureRect
var arte: Control
var letras: Control
var palco: Node3D
var camera: Camera3D
var ambiente: Environment
var mover_camera: Callable
var animar: Callable
var com_ilustracao := true
## A fonte sem ligaduras: a Pixelify junta "fi" num desenho só, e "fim" virava "Am".
var FONTE: FontVariation

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	FONTE = FontVariation.new()
	FONTE.base_font = FONTE_ARQUIVO
	FONTE.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("liga"): 0}
	var todos = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	dados = todos[tipo]
	cartoes = dados["cartoes"]
	# O mundo é desenhado pequeno e esticado em blocos, como no jogo.
	render = SubViewport.new()
	render.size = resolucao
	render.own_world_3d = true
	render.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(render)
	imagem = TextureRect.new()
	imagem.set_anchors_preset(PRESET_FULL_RECT)
	imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.texture = render.get_texture()
	var filtro := ShaderMaterial.new()
	filtro.shader = TELA
	filtro.set_shader_parameter("vhs", fita)
	filtro.set_shader_parameter("sangria", 1.6)
	filtro.set_shader_parameter("rastro", 3.0)
	filtro.set_shader_parameter("tremor", 1.3)
	filtro.set_shader_parameter("chuvisco", 0.1)
	filtro.set_shader_parameter("risco", 0.16)
	filtro.set_shader_parameter("tons", 20.0)
	imagem.material = filtro
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_preset(PRESET_FULL_RECT)
	add_child(fundo)
	add_child(imagem)
	# O texto fica DENTRO da tela pequena, para passar pela fita junto com a imagem.
	arte = Control.new()
	arte.size = Vector2(resolucao)
	arte.draw.connect(_desenhar)
	render.add_child(arte)
	# As letras ficam por cima, na resolução da janela: a fita borraria demais
	# um texto de 9 pixels. Elas ganham um efeito de fita só delas.
	letras = Control.new()
	letras.set_anchors_preset(PRESET_FULL_RECT)
	letras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letras.draw.connect(_desenhar_letras)
	add_child(letras)
	iniciar_cartao(0)

# ---------------------------------------------------------------- cartões
func iniciar_cartao(i: int) -> void:
	indice = i
	t = 0.0
	if is_instance_valid(palco):
		palco.queue_free()
	palco = Node3D.new()
	render.add_child(palco)
	render.move_child(arte, -1)
	camera = Camera3D.new()
	camera.fov = 50.0
	palco.add_child(camera)
	camera.current = true
	ambiente = Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color.BLACK
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color("30323a")
	ambiente.ambient_light_energy = 0.4
	var mundo := WorldEnvironment.new()
	mundo.environment = ambiente
	palco.add_child(mundo)
	mover_camera = func(_k: float) -> void: pass
	animar = func(_t: float, _d: float) -> void: pass
	com_ilustracao = true
	match String(cartoes[i]["cena"]):
		"corpo_rua": _cena_corpo_rua()
		"sala_vazia": _cena_sala_vazia()
		"lista", "preto": com_ilustracao = false
		"laje_amanhecer": _cena_laje_amanhecer()
		"cidade_chamas": _cena_cidade("chamas")
		"radio_chiando": _cena_radio()
		"cidade_final": _cena_cidade("destruida", true)
		"comboio": _cena_comboio()
		"abrigo_portao": _cena_abrigo_portao()
		"fila": _cena_fila()
		"oferenda": _cena_oferenda()
		"mensagem": _cena_mensagem()
		"encontro": _cena_encontro()
		"estrada": _cena_estrada()
		"interior": _cena_interior()
	RuaModelo.aplicar_ps1(palco, Vector2(resolucao))
	mover_camera.call(0.0)

func ir_para_o_fim() -> void:
	no_fim = true
	t_fim = 0.0
	if is_instance_valid(palco):
		palco.queue_free()

func _process(delta: float) -> void:
	if no_fim:
		t_fim += delta
	else:
		t += delta
		var duracao := float(cartoes[indice]["duracao"])
		mover_camera.call(clampf(t / duracao, 0.0, 1.0))
		animar.call(t, delta)
		if t >= duracao:
			if indice + 1 < cartoes.size(): iniciar_cartao(indice + 1)
			else: ir_para_o_fim()
	arte.queue_redraw()
	letras.queue_redraw()

func _unhandled_input(evento: InputEvent) -> void:
	var confirmou := false
	if evento is InputEventKey and evento.pressed and not evento.echo:
		var k := (evento as InputEventKey).keycode
		if k == KEY_ESCAPE and not no_fim:
			ir_para_o_fim()
			return
		confirmou = k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	elif evento is InputEventMouseButton and evento.pressed:
		confirmou = true
	if confirmou and no_fim and t_fim > 3.5:
		terminou.emit()
		if cena_ao_terminar != "" and ResourceLoader.exists(cena_ao_terminar):
			get_tree().change_scene_to_file(cena_ao_terminar)

# ---------------------------------------------------------------- peças
func _carregar(caminho: String) -> Node3D:
	var recurso = load(caminho)
	if recurso is PackedScene: return (recurso as PackedScene).instantiate()
	return Node3D.new()

func _luz(direcao: Vector3, cor: Color, energia: float) -> DirectionalLight3D:
	var luz := DirectionalLight3D.new()
	palco.add_child(luz)
	luz.light_color = cor
	luz.light_energy = energia
	luz.look_at_from_position(direcao.normalized() * 10.0, Vector3.ZERO)
	return luz

func _caixa(tamanho: Vector3, cor: Color, onde: Vector3) -> MeshInstance3D:
	var malha := BoxMesh.new()
	malha.size = tamanho
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	malha.material = material
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.position = onde
	palco.add_child(mi)
	return mi

func _ceu(topo: Color, horizonte: Color, chao: Color) -> void:
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = topo
	material.sky_horizon_color = horizonte
	material.ground_horizon_color = horizonte.darkened(0.3)
	material.ground_bottom_color = chao
	material.sun_angle_max = 0.0
	var ceu := Sky.new()
	ceu.sky_material = material
	ambiente.background_mode = Environment.BG_SKY
	ambiente.sky = ceu

func _parado(modelo: Node3D, animacao := "parado") -> void:
	for p in modelo.find_children("*", "AnimationPlayer", true, false):
		var player := p as AnimationPlayer
		if player.has_animation(animacao):
			player.get_animation(animacao).loop_mode = Animation.LOOP_LINEAR
			player.play(animacao)

## O protagonista caído, com a mesma pose e o mesmo congelamento dos corpos da rua.
func _corpo(onde: Vector3, giro: float, pose := "costas") -> Node3D:
	var corpo := Node3D.new()
	corpo.position = onde
	corpo.rotation.y = deg_to_rad(giro)
	palco.add_child(corpo)
	var poses = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	var modelo := _carregar(PROTAGONISTA)
	for malha: ArrayMesh in Corpo3D.congelar(modelo, poses[pose], "protagonista"):
		var mi := MeshInstance3D.new()
		mi.mesh = malha
		corpo.add_child(mi)
	modelo.free()
	# A poça, rente ao chão, sob a cabeça e o tronco.
	var acaso := RandomNumberGenerator.new()
	acaso.seed = 4471
	var centro := Vector3(0.07, 0.004, -0.35 if pose == "costas" else 0.35)
	var borda := PackedVector3Array()
	for k in 24:
		var a := TAU * k / 24.0
		borda.append(centro + Vector3(cos(a) * 0.78, 0, sin(a) * 0.8) * acaso.randf_range(0.8, 1.15))
	var vertices := PackedVector3Array()
	var cores := PackedColorArray()
	for k in 24:
		vertices.append_array([centro, borda[(k + 1) % 24], borda[k]])
		cores.append_array([Color("3a0609"), Color("6e1016"), Color("6e1016")])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = cores
	var poca := ArrayMesh.new()
	poca.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.4
	poca.surface_set_material(0, material)
	var mp := MeshInstance3D.new()
	mp.mesh = poca
	corpo.add_child(mp)
	return corpo

## Laje de onde se vê a cidade: em cima de uma das casas da rua, à esquerda.
func _laje() -> Vector3:
	var base := Vector3(-11.6, 3.75, 0.0)
	_caixa(Vector3(6.0, 0.25, 6.4), Color("8d8a84"), base)
	_caixa(Vector3(0.18, 0.55, 6.4), Color("b5643e"), base + Vector3(-3.0, 0.4, 0))
	_caixa(Vector3(6.0, 0.55, 0.18), Color("b5643e"), base + Vector3(0, 0.4, 3.2))
	var caixa := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 0.55; cilindro.bottom_radius = 0.5; cilindro.height = 0.8; cilindro.radial_segments = 6
	var azul := StandardMaterial3D.new(); azul.albedo_color = Color("2d6fb8"); cilindro.material = azul
	caixa.mesh = cilindro
	caixa.position = base + Vector3(-2.0, 0.53, 2.2)
	palco.add_child(caixa)
	_caixa(Vector3(0.05, 1.6, 0.05), Color("6b6b6b"), base + Vector3(1.8, 0.9, 2.6))
	_caixa(Vector3(0.05, 1.6, 0.05), Color("6b6b6b"), base + Vector3(1.8, 0.9, -0.6))
	_caixa(Vector3(0.01, 0.01, 3.2), Color("dddddd"), base + Vector3(1.8, 1.68, 1.0))
	_caixa(Vector3(0.02, 0.5, 0.45), Color("c7362f"), base + Vector3(1.8, 1.4, 1.6))
	_caixa(Vector3(0.02, 0.62, 0.7), Color("e9e5dc"), base + Vector3(1.8, 1.35, 0.6))
	return base + Vector3(0, 0.125, 0)

# ---------------------------------------------------------------- cenas
func _cena_corpo_rua() -> void:
	palco.add_child(_carregar(RUA))
	ambiente.background_color = Color("05060a")
	ambiente.ambient_light_color = Color("1c2433")
	ambiente.ambient_light_energy = 0.5
	ambiente.fog_enabled = true
	ambiente.fog_light_color = Color("0a0c12")
	ambiente.fog_density = 0.045
	var poste := OmniLight3D.new()
	poste.position = Vector3(4.6, 6.2, -1.0)
	poste.light_color = Color("ffcf8a")
	poste.light_energy = 2.6
	poste.omni_range = 15.0
	palco.add_child(poste)
	_corpo(Vector3(5.6, 0.15, 0.6), 28.0)
	var cacador := _carregar(CACADOR)
	cacador.position = Vector3(1.4, 0.0, -5.0)
	cacador.rotation.y = PI
	palco.add_child(cacador)
	mover_camera = func(k: float) -> void:
		camera.position = Vector3(8.0, 2.6, 3.3).lerp(Vector3(7.5, 3.6, 3.9), k)
		camera.look_at(Vector3(4.9, 0.25, -0.6))
	animar = func(tempo: float, _d: float) -> void:
		cacador.position.z = -5.0 - tempo * 1.25
		poste.light_energy = 2.6 if sin(tempo * 13.0) * sin(tempo * 2.3) > -0.55 else 0.4

func _cena_sala_vazia() -> void:
	_caixa(Vector3(5.0, 0.05, 5.0), Color("6b4a2e"), Vector3(0, -0.025, 0))
	_caixa(Vector3(5.0, 2.8, 0.1), Color("8e7d62"), Vector3(0, 1.4, -1.75))
	_caixa(Vector3(0.1, 2.8, 5.0), Color("7f6f57"), Vector3(-2.2, 1.4, 0))
	var tv := _carregar(TV)
	tv.position = Vector3(0, 0, -1.45)
	palco.add_child(tv)
	var sofa := _carregar(SOFA)
	sofa.position = Vector3(0.1, 0, 1.3)
	sofa.rotation.y = PI
	palco.add_child(sofa)
	var tela := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.46, 0.34)
	tela.mesh = quad
	var chuvisco := ShaderMaterial.new()
	chuvisco.shader = CHUVISCO
	tela.material_override = chuvisco
	tela.position = tv.position + Vector3(-0.05, 0.866, 0.166)
	palco.add_child(tela)
	var brilho := OmniLight3D.new()
	brilho.position = tela.position + Vector3(0, 0, 0.5)
	brilho.light_color = Color("c8d8ff")
	brilho.omni_range = 4.5
	palco.add_child(brilho)
	ambiente.ambient_light_energy = 0.12
	mover_camera = func(k: float) -> void:
		camera.position = Vector3(0.9, 1.4, 3.0).lerp(Vector3(0.45, 1.15, 2.0), k)
		camera.look_at(Vector3(-0.05, 0.85, -1.35))
	animar = func(tempo: float, _d: float) -> void:
		brilho.light_energy = 1.3 + 0.5 * absf(sin(tempo * 17.0) * sin(tempo * 5.3))

func _cena_laje_amanhecer() -> void:
	palco.add_child(_carregar(RUA))
	var cidade := Cidade3D.new()
	cidade.ambiente = ambiente
	palco.add_child(cidade)
	cidade.mostrar("destruida")
	_ceu(Color("3a4a6a"), Color("e8a070"), Color("2a2420"))
	ambiente.ambient_light_color = Color("c9b8a8")
	ambiente.ambient_light_energy = 0.55
	_luz(Vector3(0.4, 0.35, -1.0), Color("ffc89a"), 1.1)
	var chao := _laje()
	var vivo := _carregar(PROTAGONISTA)
	vivo.position = chao + Vector3(0.2, 0, -2.4)
	vivo.rotation.y = PI
	palco.add_child(vivo)
	_parado(vivo)
	mover_camera = func(k: float) -> void:
		camera.position = (chao + Vector3(1.0, 1.75, 2.0)).lerp(chao + Vector3(0.5, 1.6, 0.2), k)
		camera.look_at(chao + Vector3(-0.6, 1.2, -60.0))

func _cena_cidade(estado: String, final := false) -> void:
	palco.add_child(_carregar(RUA))
	var cidade := Cidade3D.new()
	cidade.ambiente = ambiente
	palco.add_child(cidade)
	cidade.mostrar(estado)
	var ar: Dictionary = Cidade3D.ESTADOS[estado]
	_ceu(ar["ceu_topo"], ar["ceu_baixo"], Color("140c0c"))
	ambiente.ambient_light_color = ar["luz"]
	ambiente.ambient_light_energy = 0.45
	_luz(Vector3(-0.3, 0.6, 0.5), ar["luz"], 0.6)
	var chao := _laje()
	if final:
		# Fim de tarde sobre o que sobrou: um giro lento pelo horizonte inteiro.
		mover_camera = func(k: float) -> void:
			camera.fov = 58.0
			camera.position = chao + Vector3(1.2, 2.6, 2.4)
			var rumo := deg_to_rad(lerpf(-28.0, 24.0, k))
			camera.look_at(camera.position + Vector3(sin(rumo), 0.02, -cos(rumo)))
	else:
		# Teleobjetiva na direção da criatura, no meio do fogo.
		var rumo := Cidade3D.RUMO_DA_CRIATURA
		var alvo := Vector3(cos(rumo), 0.0, sin(rumo)) * Cidade3D.CRIATURA_LONGE + Vector3(0, 70.0, 0)
		mover_camera = func(k: float) -> void:
			camera.fov = lerpf(26.0, 18.0, k)
			camera.position = chao + Vector3(0.0, 1.7, 1.0)
			camera.look_at(alvo + Vector3(lerpf(-30.0, 30.0, k), 0, 0))

func _cena_radio() -> void:
	_caixa(Vector3(4.0, 0.05, 4.0), Color("8c7a62"), Vector3(0, -0.025, 0))
	_caixa(Vector3(4.0, 2.8, 0.1), Color("a9d3c6").darkened(0.35), Vector3(0, 1.4, -1.55))
	var radio := _carregar(RADIO)
	radio.position = Vector3(0, 0, -1.28)
	palco.add_child(radio)
	ambiente.ambient_light_color = Color("8a8f9a")
	ambiente.ambient_light_energy = 0.35
	_luz(Vector3(1.0, 0.6, 0.6), Color("ffd9a8"), 0.9)
	mover_camera = func(k: float) -> void:
		camera.position = Vector3(0.7, 1.3, 1.1).lerp(Vector3(0.25, 1.0, -0.2), k)
		camera.look_at(Vector3(-0.05, 0.8, -1.25))

# ---------------------------------------------------------------- final do abrigo
func _pessoa(quem: String, onde: Vector3, giro := 0.0, animacao := "parado", ritmo := 1.0) -> Node3D:
	var elenco: Dictionary = load("res://scripts/pessoa3d.gd").ELENCO
	var caminho := String(elenco[quem].arquivo)
	var p := _carregar(caminho)
	p.position = onde
	p.rotation.y = giro
	palco.add_child(p)
	for a in p.find_children("*", "AnimationPlayer", true, false):
		var player := a as AnimationPlayer
		if player.has_animation(animacao):
			player.get_animation(animacao).loop_mode = Animation.LOOP_LINEAR
			player.play(animacao)
			player.speed_scale = ritmo
			player.seek(randf() * 1.0, true)
	return p

## Soldado: o policial militar do pacote, parado, contra a luz dos holofotes.
func _soldado(onde: Vector3, giro := 0.0) -> Node3D:
	var s := _carregar("res://modelos/pm/pm.tscn")
	s.position = onde
	s.rotation.y = giro
	s.scale = Vector3(1.04, 1.04, 1.04)
	palco.add_child(s)
	return s

func _pintar_silhuetas() -> void:
	for n in palco.get_children():
		if n.has_meta("silhueta"): RuaModelo.silhueta(n, Color("0b0d0c"))

func _holofote(base: Vector3, alvo: Vector3, cor := Color("fff2d0"), energia := 6.0) -> SpotLight3D:
	_caixa(Vector3(0.18, base.y, 0.18), Color("3a3d38"), Vector3(base.x, base.y / 2.0, base.z))
	var lampada := _caixa(Vector3(0.7, 0.45, 0.4), cor, base + Vector3(0, 0.2, 0))
	(lampada.mesh.material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var luz := SpotLight3D.new()
	palco.add_child(luz)
	luz.position = base
	luz.look_at(alvo)
	luz.light_color = cor
	luz.light_energy = energia
	luz.spot_range = 40.0
	luz.spot_angle = 38.0
	return luz

func _placa(texto: String, onde: Vector3, tamanho := 48, cor := Color("f2efe6")) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font = FONTE
	l.font_size = tamanho
	l.modulate = cor
	l.outline_size = 0
	l.pixel_size = 0.01
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = onde
	palco.add_child(l)
	return l

func _noite(cor_ar: Color, densidade: float, ambiente_cor: Color, energia: float) -> void:
	ambiente.background_color = cor_ar
	ambiente.ambient_light_color = ambiente_cor
	ambiente.ambient_light_energy = energia
	ambiente.fog_enabled = true
	ambiente.fog_light_color = cor_ar
	ambiente.fog_density = densidade
	# Um pouco de lua: sem ela, no Godot, o que fica fora dos holofotes some no preto.
	_luz(Vector3(-0.4, 0.8, 0.5), Color("9aa6d8"), 0.55)

## A estrada à noite: o tanque na frente, o caminhão com a lona aberta atrás.
func _cena_comboio() -> void:
	_noite(Color("0c0e14"), 0.022, Color("56607a"), 1.0)
	_caixa(Vector3(9.0, 0.05, 260.0), Color("2b2a28"), Vector3(0, -0.025, 60))
	_caixa(Vector3(60.0, 0.04, 260.0), Color("1f2219"), Vector3(0, -0.06, 60))
	for k in 22:
		var z := -20.0 + k * 12.0
		_caixa(Vector3(0.18, 0.02, 3.0), Color("8a7a3a"), Vector3(0, 0.01, z))
		_caixa(Vector3(0.2, 6.0, 0.2), Color("4a4842"), Vector3(-5.8, 3.0, z + 4.0))
	var tanque := _carregar(TANQUE)
	palco.add_child(tanque)
	var caminhao := _carregar(CAMINHAO)
	palco.add_child(caminhao)
	if "velocidade" in tanque: tanque.velocidade = 6.0
	if "velocidade" in caminhao: caminhao.velocidade = 6.0
	for s in [-1.0, 1.0]:
		var farol := SpotLight3D.new()
		caminhao.add_child(farol)
		farol.position = Vector3(s * 0.85, 1.0, 3.6)
		farol.rotation_degrees = Vector3(-6, 180, 0)
		farol.light_color = Color("fff0c0"); farol.light_energy = 4.0; farol.spot_range = 30.0; farol.spot_angle = 30.0
	var lanterna := OmniLight3D.new()
	caminhao.add_child(lanterna)
	lanterna.position = Vector3(0, 0.9, -3.7)
	lanterna.light_color = Color("ff2a1a"); lanterna.light_energy = 1.4; lanterna.omni_range = 4.0
	# Quem vai na carroceria: só os rostos, iluminados de vermelho pela lanterna de trás.
	var gente: Array[Node3D] = []
	for i in 3:
		var p := _pessoa(PESSOAS[i * 3], Vector3(-0.6 + i * 0.6, 0.55, -2.9 - (i % 2) * 0.4), PI)
		palco.remove_child(p)
		caminhao.add_child(p)
		gente.append(p)
	mover_camera = func(k: float) -> void:
		var z := k * 66.0
		caminhao.position = Vector3(0.6, 0, z)
		tanque.position = Vector3(-0.4, 0, z + 16.0)
		camera.fov = 50.0
		camera.position = Vector3(8.5 - k * 2.0, 4.0, z - 12.0 + k * 4.0)
		camera.look_at(Vector3(0.0, 1.2, z + 6.0))
	animar = func(tempo: float, _d: float) -> void:
		caminhao.position.y = 0.025 * absf(sin(tempo * 9.0))
		lanterna.light_energy = 1.4 + 0.3 * sin(tempo * 3.0)

## O portão do abrigo: muro alto, holofotes, soldados parados e luz quente lá dentro.
func _cena_abrigo_portao() -> void:
	_noite(Color("0e0f12"), 0.012, Color("62646c"), 1.1)
	_caixa(Vector3(120.0, 0.05, 120.0), Color("3a3833"), Vector3(0, -0.025, 0))
	for s in [-1.0, 1.0]:
		_caixa(Vector3(30.0, 6.0, 0.8), Color("8e8a80"), Vector3(s * 19.0, 3.0, 0))
		_caixa(Vector3(30.0, 0.3, 1.0), Color("6e6a62"), Vector3(s * 19.0, 6.15, 0))
		_caixa(Vector3(0.6, 7.4, 0.9), Color("6e6a62"), Vector3(s * 4.2, 3.7, 0))
		_holofote(Vector3(s * 9.0, 9.0, 1.2), Vector3(s * 3.0, 0, 9.0))
		for k in 4: _caixa(Vector3(0.06, 0.06, 0.06), Color("c8c2b0"), Vector3(s * (6.0 + k * 6.0), 6.5, 0))
	_caixa(Vector3(8.8, 0.9, 0.9), Color("6e6a62"), Vector3(0, 7.85, 0))
	_placa("ABRIGO 3", Vector3(0, 7.85, 0.5), 64, Color("f2efe6"))
	_placa("ENTRADA  ·  TRIAGEM", Vector3(0, 7.25, 0.5), 28, Color("c7c0aa"))
	# Lá dentro: luz amarela, barracas e um caminhão estacionado.
	var dentro := OmniLight3D.new()
	palco.add_child(dentro)
	dentro.position = Vector3(0, 4.0, -8.0)
	dentro.light_color = Color("ffcf86"); dentro.light_energy = 5.0; dentro.omni_range = 22.0
	var frente := OmniLight3D.new()
	palco.add_child(frente)
	frente.position = Vector3(0, 6.0, 5.0)
	frente.light_color = Color("fff0d0"); frente.light_energy = 3.0; frente.omni_range = 16.0
	for i in 3: _caixa(Vector3(4.0, 2.4, 3.0), Color("5c6040"), Vector3(-6.0 + i * 6.0, 1.2, -9.0))
	var parado := _carregar(CAMINHAO)
	parado.position = Vector3(5.2, 0, -5.0); parado.rotation.y = 0.35
	palco.add_child(parado)
	for s in [-1.0, 1.0]:
		_soldado(Vector3(s * 3.4, 0, 1.4), 0.0)
	_soldado(Vector3(-2.0, 0, -3.0), 0.3)
	var gente: Array[Node3D] = []
	for i in 5:
		gente.append(_pessoa(PESSOAS[(i * 2 + 1) % PESSOAS.size()], Vector3(-0.8 + (i % 2) * 1.2, 0, 7.0 + i * 1.4), PI, "andar", 0.6))
	_pintar_silhuetas()
	mover_camera = func(k: float) -> void:
		camera.fov = 50.0
		camera.position = Vector3(2.4, 1.7, 19.0).lerp(Vector3(1.2, 1.6, 13.5), k)
		camera.look_at(Vector3(0, 3.6, 0))
	animar = func(_tempo: float, d: float) -> void:
		for p in gente: p.position.z -= d * 0.55

## A fila: um corredor de holofotes até um portão aberto para o escuro.
func _cena_fila() -> void:
	_noite(Color("08080a"), 0.03, Color("464a54"), 1.0)
	_caixa(Vector3(14.0, 0.05, 90.0), Color("4a4842"), Vector3(0, -0.025, -30.0))
	for s in [-1.0, 1.0]:
		for k in 9:
			var z := 6.0 - k * 7.0
			_caixa(Vector3(0.08, 2.2, 0.08), Color("6a6a62"), Vector3(s * 3.0, 1.1, z))
			_caixa(Vector3(0.04, 0.04, 7.0), Color("8a8a80"), Vector3(s * 3.0, 2.15, z - 3.5))
			_caixa(Vector3(0.04, 0.04, 7.0), Color("8a8a80"), Vector3(s * 3.0, 1.1, z - 3.5))
		for k in 4:
			var luz := _holofote(Vector3(s * 4.2, 6.0, 4.0 - k * 14.0), Vector3(0, 0, 4.0 - k * 14.0 - 4.0), Color("e8eeff"), 4.5)
			luz.spot_range = 22.0
	for k in 5:
		var poca := OmniLight3D.new()
		palco.add_child(poca)
		poca.position = Vector3(0, 3.5, -2.0 - k * 11.0)
		poca.light_color = Color("dfe6ff"); poca.light_energy = 2.2; poca.omni_range = 8.0
	# O fim do corredor: um portão de aço aberto e nada do outro lado.
	_caixa(Vector3(16.0, 9.0, 1.0), Color("2a2c2a"), Vector3(-11.0, 4.5, -60.0))
	_caixa(Vector3(16.0, 9.0, 1.0), Color("2a2c2a"), Vector3(11.0, 4.5, -60.0))
	_caixa(Vector3(6.0, 2.0, 1.0), Color("2a2c2a"), Vector3(0, 8.0, -60.0))
	var escuro := _caixa(Vector3(6.0, 7.0, 0.2), Color("000000"), Vector3(0, 3.5, -60.6))
	(escuro.mesh.material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var olhos: Array[MeshInstance3D] = []
	for s in [-1.0, 1.0]:
		var o := _caixa(Vector3(0.22, 0.09, 0.05), Color("f4d24a"), Vector3(s * 0.55, 5.6, -60.45))
		(o.mesh.material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		olhos.append(o)
	var fila: Array[Node3D] = []
	for i in 11:
		fila.append(_pessoa(PESSOAS[i % PESSOAS.size()], Vector3(0.25 * sin(i * 1.7), 0, -1.0 - i * 1.6), PI, "andar", 0.45))
	var eu := _pessoa("protagonista", Vector3(0.1, 0, 1.0), PI, "andar", 0.45)
	_soldado(Vector3(2.3, 0, -8.0), -PI / 2.0)
	_soldado(Vector3(-2.3, 0, -26.0), PI / 2.0)
	_soldado(Vector3(2.3, 0, -44.0), -PI / 2.0)
	_pintar_silhuetas()
	mover_camera = func(k: float) -> void:
		var z := 1.0 - k * 6.0
		eu.position.z = z
		camera.fov = 50.0
		camera.position = Vector3(1.4, 2.4, z + 4.5)
		camera.look_at(Vector3(0.0, 1.0, -26.0))
	animar = func(tempo: float, d: float) -> void:
		for p in fila: p.position.z -= d * 0.5
		# Os olhos no escuro só aparecem de vez em quando, como se a luz enganasse.
		var aceso := sin(tempo * 0.9) > 0.55
		for o in olhos: o.visible = aceso

## A oferenda: a fila de lanternas atravessando o campo na direção da coisa.
func _cena_oferenda() -> void:
	_noite(Color("100f15"), 0.0035, Color("4a4a60"), 1.0)
	_caixa(Vector3(900.0, 0.05, 900.0), Color("26261f"), Vector3(0, -0.025, -300.0))
	var monstro: Node3D = load(MONSTRO).instantiate()
	monstro.so_a_criatura = true
	monstro.numero_de_helicopteros = 0
	var ruinas := monstro.get_node_or_null("Cidade")
	if ruinas != null:
		monstro.remove_child(ruinas)
		ruinas.queue_free()
	monstro.position = Vector3(0, -10.0, 430.0 - 260.0)
	palco.add_child(monstro)
	# O abrigo ficou para trás: a borda do muro e um holofote apontado para o campo.
	_caixa(Vector3(80.0, 6.0, 0.8), Color("5e5a52"), Vector3(0, 3.0, 14.0))
	_holofote(Vector3(-7.0, 9.0, 13.0), Vector3(0, 0, -30.0), Color("f2f0e0"), 3.0)
	var fila: Array[Node3D] = []
	var lanternas: Array[OmniLight3D] = []
	for i in 14:
		var p := _pessoa(PESSOAS[i % PESSOAS.size()], Vector3(sin(i * 0.9) * 0.6, 0, -6.0 - i * 4.5), PI, "andar", 0.4)
		fila.append(p)
		var luz := OmniLight3D.new()
		p.add_child(luz)
		luz.position = Vector3(0.3, 1.0, 0.25)
		luz.light_color = Color("ffc070"); luz.light_energy = 2.0; luz.omni_range = 4.0
		var chama := MeshInstance3D.new()
		var b := BoxMesh.new(); b.size = Vector3(0.2, 0.26, 0.2)
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color("ffd48a")
		b.material = m; chama.mesh = b; chama.position = luz.position
		p.add_child(chama)
		lanternas.append(luz)
	var eu := _pessoa("protagonista", Vector3(0.3, 0, -1.5), PI, "andar", 0.4)
	mover_camera = func(k: float) -> void:
		camera.fov = lerpf(56.0, 50.0, k)
		camera.far = 2000.0
		camera.position = Vector3(2.2, 2.4 + k * 0.6, 6.0 - k * 2.0)
		camera.look_at(Vector3(0, lerpf(8.0, 22.0, k), -200.0))
	animar = func(tempo: float, d: float) -> void:
		eu.position.z -= d * 0.42
		for p in fila: p.position.z -= d * 0.42
		for i in lanternas.size(): lanternas[i].light_energy = 1.1 + 0.25 * sin(tempo * 9.0 + i * 1.3)

# ---------------------------------------------------------------- final de confiar

## A sala no escuro e o rádio aceso na cômoda: a voz chega de madrugada.
## A fala do locutor fica só na legenda.
func _cena_mensagem() -> void:
	_noite(Color("050507"), 0.0, Color("22252e"), 0.5)
	_caixa(Vector3(4.0, 0.05, 4.0), Color("5a3a24"), Vector3(0, -0.025, 0))
	_caixa(Vector3(4.0, 2.8, 0.1), Color("6f8f86"), Vector3(0, 1.4, -1.6))
	_caixa(Vector3(0.1, 2.8, 4.0), Color("63807a"), Vector3(-1.9, 1.4, 0))
	var radio := _carregar(RADIO)
	radio.position = Vector3(0, 0, -1.28)
	palco.add_child(radio)
	var dial := _caixa(Vector3(0.11, 0.07, 0.01), Color("ffcf6a"), Vector3(0.046, 0.842, -1.175))
	(dial.mesh.material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var brilho := OmniLight3D.new()
	palco.add_child(brilho)
	brilho.position = Vector3(0.0, 0.95, -0.95)
	brilho.light_color = Color("ffc070"); brilho.light_energy = 1.4; brilho.omni_range = 3.2
	# Quem ouve: o protagonista diante do rádio, de costas para nós.
	_pessoa("protagonista", Vector3(-0.8, 0.0, -0.5), 2.34)
	mover_camera = func(k: float) -> void:
		camera.fov = lerpf(50.0, 38.0, k)
		camera.position = Vector3(1.6, 1.6, 1.5).lerp(Vector3(0.9, 1.3, 0.45), k)
		camera.look_at(Vector3(-0.3, 0.95, -1.0))
	animar = func(tempo: float, _d: float) -> void:
		# A luz do dial tremendo junto com a voz.
		var fala := 1.0 if tempo > 2.0 else 0.3
		brilho.light_energy = 1.3 + fala * 0.35 * absf(sin(tempo * 11.0) * sin(tempo * 3.7))

## O viaduto ao amanhecer: a perua parada e os outros esperando.
func _cena_encontro() -> void:
	palco.add_child(_carregar(RUA))
	_ceu(Color("3a4f7a"), Color("f0b07a"), Color("2a2420"))
	ambiente.ambient_light_color = Color("c8b4a4"); ambiente.ambient_light_energy = 0.6
	ambiente.fog_enabled = true; ambiente.fog_light_color = Color("d9a37a"); ambiente.fog_density = 0.02
	_luz(Vector3(0.6, 0.25, -1.0), Color("ffc890"), 1.0)
	# O viaduto: um tabuleiro de concreto sobre pilares, cruzando a rua.
	_caixa(Vector3(40.0, 1.2, 9.0), Color("8a867e"), Vector3(0, 6.6, -6.0))
	_caixa(Vector3(40.0, 0.9, 0.4), Color("9a968c"), Vector3(0, 7.65, -1.7))
	for x in [-9.0, 9.0]: _caixa(Vector3(1.4, 6.0, 1.4), Color("7a766e"), Vector3(x, 3.0, -6.0))
	var perua := _carregar(PERUA)
	perua.position = Vector3(1.6, 0, -5.0); perua.rotation.y = 0.4
	palco.add_child(perua)
	var grupo: Array[Node3D] = []
	var lugares := [[-1.4, -3.2, 0.9], [-0.4, -4.3, 0.3], [3.4, -3.2, -0.8], [0.4, -2.4, 0.4], [-2.3, -4.6, 1.2], [2.6, -6.6, -0.4]]
	var quem := ["seu_ze", "vanessa", "rogerio", "dona_celia", "anderson", "jessica"]
	for i in lugares.size():
		var l: Array = lugares[i]
		grupo.append(_pessoa(quem[i], Vector3(l[0], 0, l[1]), l[2]))
	var eu := _pessoa("protagonista", Vector3(0.4, 0, 5.0), PI, "andar", 0.8)
	mover_camera = func(k: float) -> void:
		camera.fov = 52.0
		camera.position = Vector3(1.4, 1.75, 9.5).lerp(Vector3(0.9, 1.7, 6.5), k)
		camera.look_at(Vector3(0.4, 1.5, -4.0))
	animar = func(_tempo: float, d: float) -> void:
		if eu.position.z > 0.6: eu.position.z -= d * 0.55

## A estrada de terra: a perua indo para o interior, a cidade fumegando para trás.
func _cena_estrada() -> void:
	_ceu(Color("4f78b8"), Color("f6c98a"), Color("3a3020"))
	ambiente.ambient_light_color = Color("d9cbb4"); ambiente.ambient_light_energy = 0.7
	ambiente.fog_enabled = true; ambiente.fog_light_color = Color("e7c49a"); ambiente.fog_density = 0.006
	_luz(Vector3(0.5, 0.35, 0.8), Color("ffdcae"), 1.1)
	_caixa(Vector3(600.0, 0.05, 600.0), Color("6f8a3a"), Vector3(0, -0.04, 0))
	_caixa(Vector3(5.0, 0.05, 600.0), Color("a8743f"), Vector3(0, -0.01, 0))
	var acaso := RandomNumberGenerator.new(); acaso.seed = 77
	for i in 70:   # morrinhos, cupinzeiros e árvores de cerrado
		var lado := -1.0 if i % 2 == 0 else 1.0
		var x: float = lado * acaso.randf_range(5.0, 70.0)
		var z := acaso.randf_range(-220.0, 140.0)
		if acaso.randf() < 0.55:
			_caixa(Vector3(0.25, 2.2, 0.25), Color("4a3524"), Vector3(x, 1.1, z))
			_caixa(Vector3(2.6, 1.3, 2.6), Color("4f6e2c").lerp(Color("6f8a3a"), acaso.randf()), Vector3(x, 2.6, z))
		else:
			_caixa(Vector3(0.6, 0.9, 0.6), Color("9a6a3e"), Vector3(x, 0.45, z))
	for k in 3:
		var morro := _caixa(Vector3(140.0, 30.0, 40.0), Color("5c7a34").darkened(k * 0.1), Vector3(-120.0 + k * 120.0, 0.0, -260.0))
		morro.rotation.z = 0.06 * (k - 1)
	# A cidade lá atrás: fumaça subindo no horizonte.
	for k in 6:
		_caixa(Vector3(8.0 + k * 2.0, 60.0 + k * 10.0, 8.0), Color("4a4448"), Vector3(-30.0 + k * 9.0, 30.0, 260.0))
	var perua := _carregar(PERUA)
	palco.add_child(perua)
	mover_camera = func(k: float) -> void:
		var z := -k * 70.0
		perua.position = Vector3(0.6, 0.02 * absf(sin(k * 90.0)), z)
		perua.rotation.y = PI
		camera.fov = 52.0
		camera.position = Vector3(5.5 - k * 2.0, 2.6 + k * 0.8, z + 9.0 - k * 2.0)
		camera.look_at(Vector3(0.0, 1.0, z - 6.0))

## O sítio no interior: casa simples, roça, gente trabalhando e o céu limpo.
func _cena_interior() -> void:
	_ceu(Color("3f78d0"), Color("cfe4f2"), Color("4a5a2a"))
	ambiente.ambient_light_color = Color("e2dccc"); ambiente.ambient_light_energy = 0.8
	ambiente.fog_enabled = true; ambiente.fog_light_color = Color("cfe0ea"); ambiente.fog_density = 0.004
	_luz(Vector3(-0.5, 0.75, 0.4), Color("fff2d8"), 1.2)
	_caixa(Vector3(500.0, 0.05, 500.0), Color("6f9a3c"), Vector3(0, -0.04, 0))
	for k in 4:
		var morro := _caixa(Vector3(160.0, 40.0, 60.0), Color("5f8a34").lerp(Color("8aa0b8"), 0.25 + k * 0.12), Vector3(-200.0 + k * 130.0, 0.0, -170.0 - k * 25.0))
		morro.rotation.z = 0.08 * ((k % 2) * 2 - 1)
	# A casa: paredes caiadas, telhado de telha e uma varanda.
	_caixa(Vector3(8.0, 3.0, 6.0), Color("eee8d8"), Vector3(-6.0, 1.5, -14.0))
	_caixa(Vector3(8.0, 0.25, 6.0), Color("c9b89a"), Vector3(-6.0, 0.12, -14.0))
	_telhado(Vector3(-6.0, 3.0, -14.0), 8.0, 6.0, 1.5, 0.45, Color("b5562e"), Color("eee8d8"))
	_caixa(Vector3(1.0, 2.0, 0.08), Color("4a7a9a"), Vector3(-6.0, 1.0, -10.96))
	_caixa(Vector3(1.0, 0.9, 0.08), Color("4a7a9a"), Vector3(-8.4, 1.7, -10.96))
	_caixa(Vector3(1.0, 0.9, 0.08), Color("4a7a9a"), Vector3(-3.6, 1.7, -10.96))
	var fumaca := _caixa(Vector3(0.5, 1.6, 0.5), Color("b8b2a8"), Vector3(-3.6, 4.6, -15.0))
	# Roça: fileiras de plantação e uma cerca.
	for r in 9:
		for c in 10:
			_caixa(Vector3(0.5, 0.7, 0.5), Color("3f7d2c"), Vector3(3.0 + c * 1.1, 0.35, -16.0 + r * 1.2))
	for k in 14: _caixa(Vector3(0.12, 1.1, 0.12), Color("6a4a2a"), Vector3(1.6, 0.55, -18.0 + k * 1.6))
	_caixa(Vector3(0.06, 0.06, 22.0), Color("6a4a2a"), Vector3(1.6, 0.9, -7.6))
	# A caixa d'água e o varal: a vida voltando.
	_caixa(Vector3(0.2, 4.0, 0.2), Color("6b4a2e"), Vector3(-11.5, 2.0, -11.0))
	_caixa(Vector3(1.4, 1.0, 1.4), Color("2d6fb8"), Vector3(-11.5, 4.5, -11.0))
	_caixa(Vector3(0.05, 1.7, 0.05), Color("6b6b6b"), Vector3(-3.0, 0.85, -8.0))
	_caixa(Vector3(0.05, 1.7, 0.05), Color("6b6b6b"), Vector3(1.0, 0.85, -8.0))
	_caixa(Vector3(4.0, 0.01, 0.01), Color("dddddd"), Vector3(-1.0, 1.68, -8.0))
	for i in 4: _caixa(Vector3(0.6, 0.7, 0.02), [Color("c7362f"), Color("f2efe6"), Color("2f64b3"), Color("e0b43a")][i], Vector3(-2.4 + i * 0.9, 1.3, -8.0))
	var perua := _carregar(PERUA)
	perua.position = Vector3(-10.0, 0, -7.0); perua.rotation.y = 1.2
	palco.add_child(perua)
	var gente: Array[Node3D] = []
	gente.append(_pessoa("seu_ze", Vector3(4.2, 0, -12.0), 0.5))
	gente.append(_pessoa("vanessa", Vector3(7.0, 0, -9.0), -0.6))
	gente.append(_pessoa("dona_celia", Vector3(-6.4, 0.25, -10.4), 0.2))
	gente.append(_pessoa("anderson", Vector3(-1.5, 0, -7.4), 2.6))
	gente.append(_pessoa("jessica", Vector3(-4.5, 0, -6.0), PI, "andar", 0.6))
	gente.append(_pessoa("rogerio", Vector3(9.0, 0, -14.0), -1.2))
	var eu := _pessoa("protagonista", Vector3(0.8, 0, -1.5), PI)
	mover_camera = func(k: float) -> void:
		camera.fov = 54.0
		camera.position = Vector3(3.2, 2.0, 5.0).lerp(Vector3(2.4, 3.6, 7.5), k)
		camera.look_at(Vector3(-1.5, lerpf(1.6, 3.0, k), -14.0))
	animar = func(tempo: float, d: float) -> void:
		gente[4].position.z -= d * 0.45
		fumaca.position.y = 4.6 + fmod(tempo * 0.4, 1.0) * 0.6
		fumaca.scale = Vector3.ONE * (1.0 + fmod(tempo * 0.4, 1.0) * 0.6)

# ---------------------------------------------------------------- moldura (dentro da fita)
func _desenhar() -> void:
	var w := float(resolucao.x)
	var h := float(resolucao.y)
	if no_fim:
		arte.draw_rect(Rect2(0, 0, w, h), Color.BLACK)
		return
	var cartao: Dictionary = cartoes[indice]
	var luz := _luz_do_cartao()
	# Tudo fora da moldura é preto; a ilustração acende e apaga junto com o cartão.
	if com_ilustracao:
		var j := JANELA
		arte.draw_rect(Rect2(0, 0, w, j.position.y), Color.BLACK)
		arte.draw_rect(Rect2(0, j.end.y, w, h - j.end.y), Color.BLACK)
		arte.draw_rect(Rect2(0, j.position.y, j.position.x, j.size.y), Color.BLACK)
		arte.draw_rect(Rect2(j.end.x, j.position.y, w - j.end.x, j.size.y), Color.BLACK)
		arte.draw_rect(j, Color(0, 0, 0, 1.0 - luz))
		arte.draw_rect(j.grow(1), Color(0.25, 0.24, 0.22, luz * 0.8), false, 1.0)
	else:
		arte.draw_rect(Rect2(0, 0, w, h), Color.BLACK)
	if String(cartao["cena"]) == "lista":
		var j := JANELA
		arte.draw_rect(j, Color(0.04, 0.06, 0.07, luz))
		arte.draw_rect(Rect2(j.position.x, j.position.y, j.size.x, 13), Color(0.12, 0.14, 0.15, luz))
		var i := _linha_do_destaque()
		if i.x >= 0.0 and int(t * 2.0) % 2 == 0:
			arte.draw_rect(Rect2(j.position.x + 6, i.y - 1, j.size.x - 12, 10), Color(0.5, 0.08, 0.08, luz))

func _luz_do_cartao() -> float:
	var duracao := float(cartoes[indice]["duracao"])
	return clampf(t / FADE, 0.0, 1.0) * clampf((duracao - t) / FADE, 0.0, 1.0)

func _y_da_lista(i: int) -> float:
	return JANELA.position.y + 18.0 + i * 10.0 - t / float(cartoes[indice]["duracao"]) * 60.0

## Linha do nome em destaque na lista: (índice, y), ou (-1, 0) se não estiver à vista.
func _linha_do_destaque() -> Vector2:
	var nomes: Array = dados.get("lista", [])
	var i := nomes.find(String(dados.get("destaque", "")))
	if i < 0: return Vector2(-1, 0)
	var y := _y_da_lista(i)
	if y < JANELA.position.y + 14.0 or y > JANELA.end.y - 9.0: return Vector2(-1, 0)
	return Vector2(i, y)

# ---------------------------------------------------------------- letras (nítidas, com fita própria)
var _escala := 1.0
var _origem := Vector2.ZERO

func _ruido(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)

func _texto(s: String, x: float, y: float, tamanho: int, cor: Color, centro := true) -> void:
	# x, y e tamanho são da tela pequena; aqui viram pixels da janela.
	var px := int(roundf(tamanho * _escala))
	var largura := FONTE.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := _origem + Vector2(x, y) * _escala
	if centro: p.x -= largura / 2.0
	p.y += FONTE.get_ascent(px)
	# A fita nas letras: a linha às vezes escorrega, as cores se separam e o brilho oscila.
	var semente := floorf(Time.get_ticks_msec() / 70.0) + y * 3.1
	var escorrega := (_ruido(semente) - 0.5) * 2.0 * _escala if _ruido(semente + 7.0) > 0.86 else 0.0
	var separa := 0.6 * _escala
	var oscila := 0.9 + 0.1 * _ruido(semente + 3.0)
	var a := cor.a * oscila
	letras.draw_string(FONTE, p + Vector2(escorrega - separa, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1.0, 0.25, 0.2, a * 0.45))
	letras.draw_string(FONTE, p + Vector2(escorrega + separa, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.2, 0.6, 1.0, a * 0.45))
	letras.draw_string(FONTE, p + Vector2(escorrega, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(cor.r, cor.g, cor.b, a))

func _quebrar(s: String, largura: float, tamanho: int) -> Array[String]:
	var linhas: Array[String] = []
	var atual := ""
	for p in s.split(" "):
		var teste := (atual + " " + p) if atual != "" else p
		if FONTE.get_string_size(teste, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x > largura and atual != "":
			linhas.append(atual)
			atual = p
		else:
			atual = teste
	linhas.append(atual)
	return linhas

func _desenhar_letras() -> void:
	var w := float(resolucao.x)
	var h := float(resolucao.y)
	_escala = minf(size.x / w, size.y / h)
	_origem = (size - Vector2(w, h) * _escala) / 2.0
	if no_fim:
		var a1 := clampf((t_fim - 0.6) / 1.2, 0.0, 1.0)
		var a2 := clampf((t_fim - 2.2) / 1.2, 0.0, 1.0)
		_texto(String(dados["titulo"]), w / 2.0, h / 2.0 - 20.0, 14, Color(0.93, 0.9, 0.84, a1))
		_texto(String(dados["subtitulo"]), w / 2.0, h / 2.0 + 2.0, 9, Color(0.75, 0.72, 0.66, a2))
		if t_fim > 3.5 and int(t_fim * 1.6) % 2 == 0:
			_texto("aperte E para continuar", w / 2.0, h - 26.0, 7, Color(0.6, 0.58, 0.54))
		return
	var cartao: Dictionary = cartoes[indice]
	var luz := _luz_do_cartao()
	var cena := String(cartao["cena"])
	if cena == "lista":
		var j := JANELA
		_texto("RELAÇÃO DE DESAPARECIDOS · ZONA NORTE", j.position.x + j.size.x / 2.0, j.position.y + 2.5, 7, Color(0.8, 0.8, 0.75, luz))
		var nomes: Array = dados.get("lista", [])
		var destaque := String(dados.get("destaque", ""))
		for i in nomes.size():
			var y := _y_da_lista(i)
			if y < j.position.y + 14.0 or y > j.end.y - 9.0: continue
			var nome := String(nomes[i])
			var cor := Color(1, 0.95, 0.9, luz) if nome == destaque else Color(0.7, 0.77, 0.7, luz)
			_texto(nome, j.position.x + 10.0, y, 7, cor, false)
	# As frases, uma depois da outra, letra por letra.
	var linhas: Array = cartao["linhas"]
	var y := JANELA.end.y + 10.0 if (com_ilustracao or cena == "lista") else h / 2.0 - linhas.size() * 7.0
	for i in linhas.size():
		var inicio := 1.0 + i * ENTRE_LINHAS
		if t < inicio: break
		var visivel := String(linhas[i]).substr(0, int((t - inicio) * ESCREVE))
		for parte in _quebrar(visivel, (w - 40.0) * _escala, int(roundf(9 * _escala))):
			_texto(parte, w / 2.0, y, 9, Color(0.92, 0.89, 0.83, luz))
			y += 11.0
		y += 3.0



## Telhado de duas águas com a cumeeira no eixo X: as duas águas com beiral e os
## oitões (os triângulos de parede nas pontas). centro = meio do topo das paredes.
func _telhado(centro: Vector3, largura: float, fundo: float, altura: float, beiral: float, cor: Color, cor_parede: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -largura / 2.0 - beiral
	var x1 := largura / 2.0 + beiral
	var zb := fundo / 2.0 + beiral
	var queda := altura * beiral / (fundo / 2.0)
	for lado in [1.0, -1.0]:
		var a: Vector3 = Vector3(x0, -queda, lado * zb)
		var b: Vector3 = Vector3(x1, -queda, lado * zb)
		var c := Vector3(x1, altura, 0)
		var d := Vector3(x0, altura, 0)
		var n: Vector3 = Vector3(0, fundo / 2.0, lado * altura).normalized()
		for tri in [[a, b, c], [a, c, d]]:
			for v in tri:
				st.set_normal(n); st.add_vertex(centro + v)
			for v in [tri[0], tri[2], tri[1]]:
				st.set_normal(-n); st.add_vertex(centro + v)
	var malha := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	malha.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	palco.add_child(mi)
	var oit := SurfaceTool.new()
	oit.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lado in [1.0, -1.0]:
		var x: float = lado * largura / 2.0
		var tri: Array = [Vector3(x, 0, fundo / 2.0), Vector3(x, 0, -fundo / 2.0), Vector3(x, altura, 0)]
		for v in tri:
			oit.set_normal(Vector3(lado, 0, 0)); oit.add_vertex(centro + v)
		for v in [tri[0], tri[2], tri[1]]:
			oit.set_normal(Vector3(lado, 0, 0)); oit.add_vertex(centro + v)
	var malha2 := oit.commit()
	var mat2 := StandardMaterial3D.new()
	mat2.albedo_color = cor_parede
	malha2.surface_set_material(0, mat2)
	var mi2 := MeshInstance3D.new()
	mi2.mesh = malha2
	palco.add_child(mi2)
	_caixa(Vector3(largura + beiral * 2.0, 0.14, 0.22), cor.darkened(0.2), centro + Vector3(0, altura + 0.03, 0))
