class_name Abertura3D
extends Control

# A abertura do jogo: a TV da sala na noite antes do dia 0, numa sequência só.
# O tubo acende no pronunciamento do Presidente (tudo normal, mas começa o
# racionamento), alguém troca de canal, o jornal fala dos desaparecidos e mostra
# imagens de celular — luzes paradas sobre uma vila na Índia, uma figura à beira
# da estrada no interior da Austrália —, a imagem cai e a TV desliga. Daí o
# jogo começa no dia 0, com a irmã.
#
# Os programas são as mesmas cenas da TV do jogo (res://tv); as filmagens são
# montadas aqui, em 3D, e passam por um filtro de imagem de celular.
# Esc pula.

## Para os testes: chamado no fim em vez de abrir o jogo.
var ao_terminar := Callable()

const TUBO := preload("res://shaders/tubo.gdshader")
const CHUVISCO := preload("res://shaders/chuvisco.gdshader")
const FILMAGEM := preload("res://shaders/filmagem.gdshader")
const LARGURA := 640
const ALTURA := 480
const BASE_DA_LEGENDA := ALTURA - 42

const RODAPE := "DESAPARECIDOS: FAMÍLIAS COBRAM RESPOSTA  •  RACIONAMENTO DE ALIMENTOS COMEÇA NA SEGUNDA  •  QUEDAS DE ENERGIA EM VÁRIOS BAIRROS  •  SECRETARIA PEDE CALMA  •  "

## A sequência. As falas viram legenda com tempo calculado pelo tamanho.
const SEQUENCIA := [
	{"tipo": "ligar", "dur": 1.1},
	{"tipo": "programa", "cena": "res://tv/pronunciamento.tscn", "canal": 2, "falas": [
		"Boa noite, brasileiras e brasileiros.",
		"Quero tranquilizar todo mundo: está tudo normal. Normalíssimo.",
		"Essas quedas de luz são transformador velho, herança de quem governou antes de mim.",
		"Por precaução, a partir de segunda começa um racionamento de alimentos.",
		"Racionamento não é falta. É organização. Cada família leva o necessário, e o necessário quem define somos nós.",
		"Não estoquem. Quem estoca é que causa a falta. Boa noite, e bom apetite.",
	]},
	{"tipo": "zapping", "dur": 0.9},
	{"tipo": "programa", "cena": "res://tv/telejornal.tscn", "canal": 7, "telao": "desaparecidos", "falas": [
		"Boa noite. O número de desaparecidos no estado triplicou em três semanas.",
		"São trabalhadores, estudantes, aposentados. A maioria saiu de casa à noite e não voltou.",
		"A Secretaria de Segurança afirma que os casos não têm relação entre si.",
		"Hoje, famílias se reuniram na porta da delegacia do centro com fotos e cartazes.",
		"E imagens estranhas continuam chegando de outras partes do mundo.",
	]},
	{"tipo": "filmagem", "lugar": "india", "tarja": ["RAJASTÃO, ÍNDIA", "IMAGENS: REDES SOCIAIS"], "falas": [
		"No Rajastão, na Índia, moradores de uma vila filmaram luzes paradas sobre o deserto por quase uma hora.",
		"Ninguém ouviu motor. As autoridades locais falam em balões meteorológicos.",
	]},
	{"tipo": "filmagem", "lugar": "australia", "tarja": ["INTERIOR DA AUSTRÁLIA", "IMAGENS: CAMINHONEIRO"], "falas": [
		"No interior da Austrália, um caminhoneiro filmou uma figura parada à beira da estrada.",
		"Especialistas dizem que o calor distorce a imagem. O motorista não foi encontrado para comentar.",
	]},
	{"tipo": "desligar", "dur": 1.3},
	{"tipo": "preto", "dur": 0.9},
]

var _quadro: Control
var _legenda: Label
var _canal: Label
var _rec: Label
var _tarja: Label
var _pular: Label
var _tela: ColorRect
var _no_ar: Control
var _filme: Dictionary = {}
var _indice := -1
var _t := 0.0
var _dur := 0.0
var _falas: Array = []
var _tempo_do_canal := 0.0
var _acabou := false
var _fonte: Font
## O zumbido do tubo, do acender ao apagar.
var _zumbido: AudioStreamPlayer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fonte = load("res://tv/PixelifySans.ttf")
	var escuro := ColorRect.new()
	escuro.color = Color(0.02, 0.02, 0.03)
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(escuro)
	_quadro = Control.new()
	_quadro.name = "Quadro"
	_quadro.size = Vector2(LARGURA, ALTURA)
	_quadro.clip_contents = true
	add_child(_quadro)
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.size = Vector2(LARGURA, ALTURA)
	_quadro.add_child(fundo)
	_tela = ColorRect.new()
	_tela.name = "Tubo"
	_tela.color = Color(1, 1, 1, 0)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legenda = LegendaTV.criar(LARGURA - 56)
	_canal = rotulo(26, Color("7dff6a"))
	_canal.position = Vector2(30, 22)
	_rec = rotulo(18, Color("ff4a3a"))
	_rec.position = Vector2(26, 22)
	_tarja = rotulo(15, Color("f6f1e4"))
	var faixa := StyleBoxFlat.new()
	faixa.bg_color = Color(0.05, 0.08, 0.2, 0.82)
	faixa.border_color = Color("f2c62a")
	faixa.border_width_left = 4
	faixa.content_margin_left = 10
	faixa.content_margin_right = 10
	faixa.content_margin_top = 4
	faixa.content_margin_bottom = 4
	_tarja.add_theme_stylebox_override("normal", faixa)
	_pular = Label.new()
	_pular.text = "Esc  pular"
	_pular.add_theme_font_size_override("font_size", 14)
	_pular.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78, 0.45))
	add_child(_pular)
	arrumar()
	get_viewport().size_changed.connect(arrumar)
	proximo()

func rotulo(tamanho: int, cor: Color) -> Label:
	var r := Label.new()
	if _fonte != null: r.add_theme_font_override("font", _fonte)
	r.add_theme_font_size_override("font_size", tamanho)
	r.add_theme_color_override("font_color", cor)
	r.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	r.add_theme_constant_override("shadow_offset_x", 2)
	r.add_theme_constant_override("shadow_offset_y", 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	return r

## O quadro de tubo fica centrado e ampliado em número inteiro de vezes, como
## na TV do jogo.
func arrumar() -> void:
	var janela := get_viewport().get_visible_rect().size
	var vezes := maxi(1, mini(int(janela.x / LARGURA), int(janela.y / ALTURA)))
	_quadro.scale = Vector2(vezes, vezes)
	var tamanho := Vector2(LARGURA, ALTURA) * float(vezes)
	_quadro.position = ((janela - tamanho) / 2.0).floor()
	_pular.position = Vector2(janela.x - 110, janela.y - 30)

## As falas com tempo: cada frase fica na tela conforme o tamanho.
static func cronometrar(frases: Array, inicio := 0.5) -> Array:
	var tempos := []
	var agora := inicio
	for frase: String in frases:
		var dura := clampf(1.0 + frase.length() * 0.058, 2.4, 6.8)
		tempos.append([agora, agora + dura, frase])
		agora += dura + 0.3
	return tempos

## Quanto dura a abertura inteira, em segundos.
static func duracao_total() -> float:
	var soma := 0.0
	for parte: Dictionary in SEQUENCIA: soma += duracao_de(parte)
	return soma

static func duracao_de(parte: Dictionary) -> float:
	if parte.has("falas"):
		var tempos := cronometrar(parte.falas)
		return float(tempos[tempos.size() - 1][1]) + 0.9
	return float(parte.get("dur", 1.0))

# ------------------------------------------------------------------ sequência

func proximo() -> void:
	_indice += 1
	if _indice >= SEQUENCIA.size():
		terminar()
		return
	var parte: Dictionary = SEQUENCIA[_indice]
	_t = 0.0
	_dur = duracao_de(parte)
	_falas = cronometrar(parte.falas) if parte.has("falas") else []
	_rec.visible = false
	_tarja.visible = false
	LegendaTV.escrever(_legenda, "", LARGURA / 2.0, BASE_DA_LEGENDA)
	match String(parte.tipo):
		"ligar":
			trocar_no_ar(null)
			_zumbido = AudioStreamPlayer.new()
			var zumbido := AmbienteSonoro.carregar("tv_zumbido.ogg")
			if "loop" in zumbido: zumbido.set("loop", true)
			_zumbido.stream = zumbido
			_zumbido.volume_db = 4.0
			add_child(_zumbido)
			_zumbido.play()
			Sons3D.tocar_trecho(self, AmbienteSonoro.carregar("tv_chiado.ogg"), 0.0, 0.5, -8.0)
		"programa":
			trocar_no_ar(programa(parte))
			mostrar_canal(int(parte.get("canal", 1)))
		"zapping":
			trocar_no_ar(chiado())
			Sons3D.tocar_trecho(self, AmbienteSonoro.carregar("tv_chiado.ogg"), 1.0, float(parte.dur), -2.0)
		"filmagem":
			trocar_no_ar(filmagem(String(parte.lugar)))
			_tarja.text = "\n".join(parte.tarja)
			_tarja.visible = true
			_tarja.reset_size()
			_tarja.position = Vector2(LARGURA - 24 - _tarja.size.x, 20)
			_rec.text = "● REC"
		"desligar":
			Sons3D.tocar_trecho(self, AmbienteSonoro.carregar("tv_desligar.ogg"), 0.0, 0.9, 0.0)
			if _zumbido != null: _zumbido.stop()
		"preto":
			pass
	# A ordem por cima do programa: legenda, letreiros, o clarão do tubo.
	for no: Control in [_legenda, _canal, _rec, _tarja, _tela]:
		if no.get_parent() != _quadro: _quadro.add_child(no)
		_quadro.move_child(no, -1)

func trocar_no_ar(novo: Control) -> void:
	if _no_ar != null:
		_no_ar.queue_free()
	_no_ar = novo
	_filme = {} if novo == null or not novo.has_meta("filme") else novo.get_meta("filme")
	if novo != null: _quadro.add_child(novo)

func mostrar_canal(numero: int) -> void:
	_canal.text = "CANAL %02d" % numero
	_canal.visible = true
	_tempo_do_canal = 2.6

func _process(delta: float) -> void:
	if _acabou or _indice >= SEQUENCIA.size(): return
	_t += delta
	var parte: Dictionary = SEQUENCIA[_indice]
	var texto := ""
	for fala: Array in _falas:
		if _t >= float(fala[0]) and _t <= float(fala[1]): texto = String(fala[2])
	LegendaTV.escrever(_legenda, texto, LARGURA / 2.0, BASE_DA_LEGENDA)
	if _tempo_do_canal > 0.0:
		_tempo_do_canal -= delta
		_canal.visible = _tempo_do_canal > 0.0
	match String(parte.tipo):
		"ligar": animar_ligar(_t / _dur)
		"desligar": animar_desligar(_t / _dur)
		"filmagem":
			_rec.visible = int(_t * 1.6) % 2 == 0
			animar_filme(String(parte.lugar), _t, _dur)
		_: _tela.color.a = 0.0
	if _t >= _dur: proximo()

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and (evento as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		terminar()

## Fim da abertura: o jogo começa no dia 0, com a casa vazia de comida.
func terminar() -> void:
	if _acabou: return
	_acabou = true
	if ao_terminar.is_valid():
		ao_terminar.call()
		return
	var arvore := get_tree()
	var jogo: Node = load("res://scenes/mundo3d.tscn").instantiate()
	jogo.dia = 0
	jogo.suprimentos = 0
	jogo.dinheiro = 30
	arvore.root.add_child(jogo)
	arvore.current_scene = jogo
	queue_free()

# ------------------------------------------------------------------ o tubo

## O tubo acendendo: um risco branco que abre em tela.
func animar_ligar(k: float) -> void:
	var abre := clampf(k / 0.45, 0.0, 1.0)
	var alto := clampf((k - 0.35) / 0.4, 0.0, 1.0)
	var largura := lerpf(8.0, LARGURA, abre)
	var altura := lerpf(3.0, ALTURA, alto * alto)
	_tela.size = Vector2(largura, altura)
	_tela.position = Vector2((LARGURA - largura) / 2.0, (ALTURA - altura) / 2.0)
	_tela.color = Color(0.92, 0.95, 1.0, 1.0 - clampf((k - 0.7) / 0.3, 0.0, 1.0))

## O tubo apagando: a imagem achata numa linha, a linha num ponto, e escuro.
func animar_desligar(k: float) -> void:
	if k > 0.15 and _no_ar != null: trocar_no_ar(null)
	var achata := clampf(k / 0.45, 0.0, 1.0)
	var fecha := clampf((k - 0.45) / 0.35, 0.0, 1.0)
	var altura := lerpf(ALTURA, 3.0, sqrt(achata))
	var largura := lerpf(LARGURA, 4.0, fecha * fecha)
	_tela.size = Vector2(largura, altura)
	_tela.position = Vector2((LARGURA - largura) / 2.0, (ALTURA - altura) / 2.0)
	_tela.color = Color(0.92, 0.95, 1.0, 1.0 - clampf((k - 0.8) / 0.2, 0.0, 1.0))

# ------------------------------------------------------------------ programas

## Um programa da TV do jogo, com as falas da abertura.
func programa(parte: Dictionary) -> Control:
	var cena: SubViewportContainer = (load(String(parte.cena)) as PackedScene).instantiate()
	# Solta das âncoras da cena: o tamanho é o do quadro, 640 × 480, que com
	# redução 2 dá os 320 × 240 em que o programa desenha.
	cena.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cena.position = Vector2.ZERO
	cena.size = Vector2(LARGURA, ALTURA)
	cena.stretch_shrink = 2
	var no_ar: Node = cena.get_node("SubViewport/Programa")
	var tempos := cronometrar(parte.falas)
	no_ar.falas_de_fora = tempos
	no_ar.loop_de_fora = duracao_de(parte) + 30.0
	no_ar.legendas = false
	if parte.has("telao"): no_ar.telao = String(parte.telao)
	no_ar.rodape = RODAPE
	var vidro := ShaderMaterial.new()
	vidro.shader = TUBO
	cena.material = vidro
	return cena

func chiado() -> Control:
	var tela := ColorRect.new()
	tela.name = "Chuvisco"
	tela.size = Vector2(LARGURA, ALTURA)
	var material := ShaderMaterial.new()
	material.shader = CHUVISCO
	tela.material = material
	return tela

# ------------------------------------------------------------------ filmagens

## Uma filmagem de celular: um palco 3D pequeno, renderizado em 320 × 240 e
## passado pelo filtro de imagem tremida.
func filmagem(lugar: String) -> Control:
	var caixa := SubViewportContainer.new()
	caixa.name = "Filmagem"
	caixa.size = Vector2(LARGURA, ALTURA)
	caixa.stretch = true
	caixa.stretch_shrink = 2
	caixa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var vista := SubViewport.new()
	vista.size = Vector2i(320, 240)
	vista.own_world_3d = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	caixa.add_child(vista)
	var filtro := ShaderMaterial.new()
	filtro.shader = FILMAGEM
	caixa.material = filtro
	var palco := Node3D.new()
	vista.add_child(palco)
	var camera := Camera3D.new()
	camera.current = true
	palco.add_child(camera)
	var filme := {"palco": palco, "camera": camera, "filtro": filtro}
	if lugar == "india": montar_india(palco, filme)
	else: montar_australia(palco, filme)
	caixa.set_meta("filme", filme)
	return caixa

func cor(c: Color, brilha := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if brilha: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func bloco(pai: Node3D, malha: Mesh, onde: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = material
	mi.position = onde
	pai.add_child(mi)
	return mi

func caixa_de(tamanho: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = tamanho
	return b

func bola(raio: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = raio
	s.height = raio * 2.0
	s.radial_segments = 8
	s.rings = 4
	return s

func ambiente(pai: Node3D, fundo: Color, luz_ambiente: Color, energia: float, nevoa := 0.0) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = fundo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = luz_ambiente
	env.ambient_light_energy = energia
	if nevoa > 0.0:
		env.fog_enabled = true
		env.fog_light_color = fundo
		env.fog_density = nevoa
		env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	pai.add_child(we)

## Noite numa vila do Rajastão: casas baixas de taipa, duas janelas acesas e,
## lá em cima, três luzes paradas que ninguém sabe dizer o que são.
func montar_india(palco: Node3D, filme: Dictionary) -> void:
	ambiente(palco, Color(0.02, 0.025, 0.06), Color(0.35, 0.4, 0.6), 0.35)
	var chao := PlaneMesh.new()
	chao.size = Vector2(900, 900)
	bloco(palco, chao, Vector3.ZERO, cor(Color(0.1, 0.08, 0.06)))
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 1947
	var taipa := cor(Color(0.2, 0.15, 0.11))
	var janela := cor(Color(1.0, 0.62, 0.25), true)
	for i in 9:
		var x := sorte.randf_range(-40.0, 40.0)
		var z := -sorte.randf_range(18.0, 70.0)
		var tamanho := Vector3(sorte.randf_range(4.0, 8.0), sorte.randf_range(2.6, 3.6), sorte.randf_range(4.0, 7.0))
		bloco(palco, caixa_de(tamanho), Vector3(x, tamanho.y / 2.0, z), taipa)
		if i % 3 == 0: bloco(palco, caixa_de(Vector3(0.7, 0.8, 0.05)), Vector3(x + 0.8, 1.6, z + tamanho.z / 2.0 + 0.03), janela)
	var estrela := cor(Color(0.8, 0.82, 0.9), true)
	for i in 50:
		var rumo := sorte.randf_range(-1.2, 1.2)
		var alto := sorte.randf_range(0.25, 1.1)
		bloco(palco, bola(0.5), Vector3(sin(rumo) * 380.0, sin(alto) * 380.0, -cos(rumo) * 380.0), estrela)
	var luzes: Array = []
	for i in 3:
		var luz := bloco(palco, bola(2.2), Vector3.ZERO, cor(Color(1.0, 0.86, 0.6), true))
		luzes.append(luz)
	filme["luzes"] = luzes

func animar_filme(lugar: String, t: float, dur: float) -> void:
	if _filme.is_empty(): return
	var camera: Camera3D = _filme.camera
	var filtro: ShaderMaterial = _filme.filtro
	# Mão de quem filma: tremor miúdo e um balanço mais lento.
	var mao := Vector3(sin(t * 7.3) * 0.012 + sin(t * 2.1) * 0.02, sin(t * 8.9) * 0.01 + sin(t * 1.7) * 0.015, 0.0)
	if lugar == "india":
		var luzes: Array = _filme.luzes
		var centro := Vector3(18.0 + t * 0.6, 58.0, -190.0)
		for i in luzes.size():
			var luz: MeshInstance3D = luzes[i]
			var canto := TAU * i / 3.0 + 0.4
			luz.position = centro + Vector3(cos(canto) * 9.0, sin(canto) * 6.0, 0.0)
			# No fim elas se apagam, uma de cada vez.
			luz.visible = t < dur - 2.6 + i * 0.5
			if i == 2 and t > 2.0 and t < 2.4: luz.visible = false
		# Aponta, tenta dar zoom, o foco caça e se perde; no fim a câmera desce.
		var zoom := clampf((t - 2.5) / 1.5, 0.0, 1.0) * (1.0 - clampf((t - dur + 2.2) / 1.2, 0.0, 1.0))
		camera.fov = lerpf(62.0, 26.0, zoom)
		camera.position = Vector3(0, 1.6, 0)
		var olhar := centro.lerp(Vector3(10, 1.0, -40), clampf((t - dur + 1.4) / 1.0, 0.0, 1.0))
		camera.look_at(olhar + Vector3(sin(t * 0.7) * 3.0, cos(t * 0.5) * 2.0, 0))
		camera.rotation += mao * (1.0 + zoom * 2.0)
		var caca := 0.0
		if t > 3.4 and t < 4.6: caca = 3.5 * absf(sin((t - 3.4) * 5.0))
		filtro.set_shader_parameter("desfoque", caca + zoom * 0.8)
		filtro.set_shader_parameter("granulado", 0.18 + zoom * 0.1)
		filtro.set_shader_parameter("tremor", 0.35)
		filtro.set_shader_parameter("apagar", clampf((t - dur + 0.35) / 0.35, 0.0, 1.0))
	else:
		var figura: Node3D = _filme.figura
		camera.position = Vector3(-1.8 + sin(t * 0.8) * 0.05, 1.9 + sin(t * 11.0) * 0.015, -t * 11.0)
		camera.fov = 48.0
		var tranco := clampf(1.0 - absf(t - dur * 0.62) / 0.35, 0.0, 1.0)
		camera.look_at(Vector3(4.0, 1.8, camera.position.z - 120.0))
		camera.rotation += mao * 1.5 + Vector3(sin(t * 40.0), cos(t * 33.0), 0) * 0.05 * tranco
		# Depois do solavanco, a beira da estrada está vazia.
		figura.visible = t < dur * 0.62
		filtro.set_shader_parameter("calor", 0.9)
		filtro.set_shader_parameter("desfoque", 0.6 + tranco * 4.0)
		filtro.set_shader_parameter("granulado", 0.1)
		filtro.set_shader_parameter("tremor", 0.25 + tranco * 0.7)
		filtro.set_shader_parameter("apagar", clampf((t - dur + 0.5) / 0.5, 0.0, 1.0))

## Meio-dia no interior australiano, de dentro da boleia: estrada reta, terra
## vermelha, ar fervendo e, lá na frente, alguém alto demais parado na beira.
func montar_australia(palco: Node3D, filme: Dictionary) -> void:
	ambiente(palco, Color(0.86, 0.72, 0.55), Color(1.0, 0.9, 0.78), 0.7, 0.0035)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color(1.0, 0.9, 0.75)
	sol.rotation = Vector3(-1.0, 0.4, 0)
	palco.add_child(sol)
	var chao := PlaneMesh.new()
	chao.size = Vector2(1200, 1200)
	bloco(palco, chao, Vector3(0, 0, -300), cor(Color(0.6, 0.27, 0.12)))
	bloco(palco, caixa_de(Vector3(7.5, 0.04, 1200)), Vector3(0, 0.02, -300), cor(Color(0.2, 0.19, 0.18)))
	var faixa := cor(Color(0.85, 0.82, 0.7))
	for i in 90:
		bloco(palco, caixa_de(Vector3(0.18, 0.05, 3.0)), Vector3(0, 0.03, 20.0 - i * 12.0), faixa)
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 1788
	var mato := cor(Color(0.32, 0.3, 0.14))
	for i in 140:
		var lado := -1.0 if i % 2 == 0 else 1.0
		var x := lado * sorte.randf_range(6.0, 70.0)
		var mi := bloco(palco, bola(sorte.randf_range(0.3, 0.8)), Vector3(x, 0.15, -sorte.randf_range(0.0, 700.0)), mato)
		mi.scale.y = 0.5
	# A figura: comprida, magra, escura contra o ar quente. Sem rosto.
	var figura := Node3D.new()
	figura.position = Vector3(8.5, 0, -150)
	figura.rotation.z = 0.04
	palco.add_child(figura)
	var sombra := cor(Color(0.05, 0.04, 0.04))
	var corpo := CylinderMesh.new()
	corpo.top_radius = 0.13
	corpo.bottom_radius = 0.2
	corpo.height = 3.3
	corpo.radial_segments = 6
	bloco(figura, corpo, Vector3(0, 1.65, 0), sombra)
	bloco(figura, bola(0.2), Vector3(0, 3.45, 0), sombra)
	for lado in [-1.0, 1.0]:
		var braco := CylinderMesh.new()
		braco.top_radius = 0.05
		braco.bottom_radius = 0.04
		braco.height = 2.2
		braco.radial_segments = 4
		bloco(figura, braco, Vector3(0.24 * lado, 2.0, 0), sombra).rotation.z = 0.06 * lado
	filme["figura"] = figura
	# O painel da boleia, embaixo da imagem.
	var camera: Camera3D = filme.camera
	bloco(camera, caixa_de(Vector3(3.0, 0.5, 0.4)), Vector3(0, -0.62, -0.9), cor(Color(0.08, 0.07, 0.07)))
