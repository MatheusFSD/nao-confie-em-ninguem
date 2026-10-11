class_name Celular3D
extends CanvasLayer

# O celular: um tijolão de teclas, visor verde e nada mais. Não tem internet,
# não procura nada — é de propósito. O que ele faz é receber mensagens, e é
# por elas que a irmã e os vizinhos falam com você.
#
# Na tela aparece o aparelho em 3D (modelos/celular/celular.glb), na mão,
# balançando de leve. O visor dele é uma tela 2D de cristal líquido de 96 × 68
# pontos, desenhada à parte e colada no vidro: barra de sinal e bateria, a
# caixa de entrada com envelopes, a linha escolhida invertida e a tecla de
# função embaixo — como os aparelhos de antigamente.
#
# Setas andam pela lista (e rolam a mensagem aberta), E abre e volta, Esc
# guarda o aparelho no bolso.
signal guardou
## Uma mensagem foi aberta: quem chamou marca como lida.
signal leu(chave: String)

const MODELO := "res://modelos/celular/celular.glb"
const FONTE := "res://tv/PixelifySans.ttf"
## O visor de verdade, em pontos. Ele é ampliado na textura sem suavizar.
const PONTOS := Vector2i(96, 68)
const ESCALA := 4
## As cores do cristal líquido.
const FUNDO_LCD := Color("9ead6a")
const TINTA := Color("1f2a14")
const APAGADO := Color("8c9a5c")
## Linhas da lista que cabem no visor.
const LINHAS_NA_LISTA := 4

## Preenchidos por quem abre o aparelho.
var caixa: Array = []
var sinal := 3
var bateria := 3
var dia := 1
var hora := "08:00"

var escolha := 0
var aberta := -1
## Primeira linha visível da mensagem aberta (para rolar).
var rolagem := 0
var _tela: SubViewport
var _lcd: Control
var _mao: SubViewport
var _aparelho: Node3D
var _fonte: Font
var _tempo := 0.0
var _linhas_da_mensagem: PackedStringArray = []

func _init() -> void:
	layer = 3
	_fonte = load(FONTE) if ResourceLoader.exists(FONTE) else ThemeDB.fallback_font
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.02, 0.03, 0.82)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	# O visor: uma tela 2D pequena, desenhada ponto a ponto.
	_tela = SubViewport.new()
	_tela.size = PONTOS * ESCALA
	_tela.transparent_bg = false
	_tela.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_tela.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_tela)
	_lcd = Control.new()
	_lcd.size = Vector2(PONTOS * ESCALA)
	_lcd.draw.connect(desenhar_o_visor)
	_tela.add_child(_lcd)
	# A mão: o aparelho em 3D, num mundo só dele.
	_mao = SubViewport.new()
	_mao.size = Vector2i(480, 760)
	_mao.transparent_bg = true
	_mao.own_world_3d = true
	_mao.msaa_3d = Viewport.MSAA_DISABLED
	_mao.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_mao)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.02, 2.75)
	camera.fov = 32.0
	_mao.add_child(camera)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(deg_to_rad(-25), deg_to_rad(20), 0)
	luz.light_energy = 1.1
	_mao.add_child(luz)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("8a93a8")
	ambiente.environment.ambient_light_energy = 0.7
	_mao.add_child(ambiente)
	_aparelho = (load(MODELO) as PackedScene).instantiate()
	_aparelho.scale = Vector3.ONE * 1.7
	_mao.add_child(_aparelho)
	var vidro := _aparelho.find_child("Tela", true, false) as MeshInstance3D
	if vidro != null:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_texture = _tela.get_texture()
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		vidro.material_override = material
	var quadro := TextureRect.new()
	quadro.texture = _mao.get_texture()
	quadro.set_anchors_preset(Control.PRESET_FULL_RECT)
	quadro.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	quadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quadro.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quadro)
	var ajuda := Label.new()
	ajuda.text = "↑↓ escolher · E ler/voltar · Esc ou C guardar"
	ajuda.add_theme_font_size_override("font_size", 14)
	ajuda.add_theme_color_override("font_color", Color("a8a398"))
	ajuda.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ajuda.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ajuda.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ajuda.offset_bottom = -14
	ajuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ajuda)

## Liga o aparelho com a caixa de entrada de hoje.
func ligar(mensagens: Array, _nao_lidas := 0, no_dia := 1, agora := "08:00") -> void:
	caixa = mensagens
	dia = no_dia
	hora = agora
	escolha = 0
	aberta = -1
	pintar()

func novas() -> int:
	var quantas := 0
	for m: Dictionary in caixa:
		if not bool(m.get("lida", false)): quantas += 1
	return quantas

func pintar() -> void:
	if _lcd != null: _lcd.queue_redraw()

## Abre a mensagem escolhida no visor.
func abrir() -> void:
	if caixa.is_empty(): return
	aberta = escolha
	rolagem = 0
	var m: Dictionary = caixa[aberta]
	if not bool(m.get("lida", false)):
		m["lida"] = true
		leu.emit(String(m.get("chave", "")))
	_linhas_da_mensagem = quebrar(String(m.get("texto", "")), PONTOS.x - 6)
	pintar()

func fechar_mensagem() -> void:
	aberta = -1
	pintar()

# ------------------------------------------------------------------ desenho

## Quebra o texto em linhas que cabem na largura do visor, em pontos.
func quebrar(texto: String, largura: int) -> PackedStringArray:
	var linhas := PackedStringArray()
	var atual := ""
	for palavra in texto.split(" ", false):
		var teste := palavra if atual.is_empty() else atual + " " + palavra
		if medir(teste) > largura and not atual.is_empty():
			linhas.append(atual)
			atual = palavra
		else:
			atual = teste
	if not atual.is_empty(): linhas.append(atual)
	return linhas

func medir(texto: String) -> float:
	return _fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * ESCALA).x / ESCALA

## Escreve em pontos do visor (a textura é 4× maior; tudo vem multiplicado).
func escrever(texto: String, onde: Vector2, cor := TINTA) -> void:
	_lcd.draw_string(_fonte, (onde + Vector2(0, 7)) * ESCALA, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * ESCALA, cor)

func ponto(onde: Vector2, tamanho: Vector2, cor := TINTA) -> void:
	_lcd.draw_rect(Rect2(onde * ESCALA, tamanho * ESCALA), cor)

func desenhar_o_visor() -> void:
	ponto(Vector2.ZERO, Vector2(PONTOS), FUNDO_LCD)
	# Barra de cima: sinal à esquerda, dia e hora no meio, bateria à direita.
	for i in 4:
		ponto(Vector2(1 + i * 3, 7 - (i + 1) * 1.5), Vector2(2, (i + 1) * 1.5), TINTA if i < sinal else APAGADO)
	var cabecalho := "Dia %d  %s" % [dia, hora]
	escrever(cabecalho, Vector2((PONTOS.x - medir(cabecalho)) / 2.0, -1))
	ponto(Vector2(PONTOS.x - 12, 2), Vector2(10, 5))
	ponto(Vector2(PONTOS.x - 2, 3), Vector2(1, 3))
	for i in 3:
		ponto(Vector2(PONTOS.x - 11 + i * 3, 3), Vector2(2, 3), FUNDO_LCD if i < bateria else TINTA)
	ponto(Vector2(0, 9), Vector2(PONTOS.x, 1))
	if aberta < 0: desenhar_a_lista()
	else: desenhar_a_mensagem()

func desenhar_a_lista() -> void:
	var titulo := "Mensagens"
	if novas() > 0: titulo += " (%d)" % novas()
	escrever(titulo, Vector2((PONTOS.x - medir(titulo)) / 2.0, 10))
	if caixa.is_empty():
		escrever("Nenhuma", Vector2((PONTOS.x - medir("Nenhuma")) / 2.0, 30))
		escrever("mensagem.", Vector2((PONTOS.x - medir("mensagem.")) / 2.0, 39))
		tecla_de_funcao("Sair")
		return
	var primeira := clampi(escolha - LINHAS_NA_LISTA + 1, 0, maxi(0, caixa.size() - LINHAS_NA_LISTA))
	for i in mini(LINHAS_NA_LISTA, caixa.size() - primeira):
		var indice := primeira + i
		var m: Dictionary = caixa[indice]
		var y := 20 + i * 10
		var marcada := indice == escolha
		var tinta := FUNDO_LCD if marcada else TINTA
		if marcada: ponto(Vector2(1, y - 1), Vector2(PONTOS.x - 6, 10))
		envelope(Vector2(3, y + 1), bool(m.get("lida", false)), tinta)
		var nome := String(m.get("de", ""))
		while medir(nome) > 58 and nome.length() > 3: nome = nome.left(nome.length() - 1)
		escrever(nome, Vector2(14, y - 1), tinta)
		var quando := "D%d" % int(m.get("dia", dia))
		escrever(quando, Vector2(PONTOS.x - 7 - medir(quando), y - 1), tinta)
	# Barra de rolagem à direita.
	if caixa.size() > LINHAS_NA_LISTA:
		ponto(Vector2(PONTOS.x - 3, 19), Vector2(1, 40))
		var passo := 40.0 / caixa.size()
		ponto(Vector2(PONTOS.x - 4, 19 + escolha * passo), Vector2(3, maxf(3.0, passo)))
	tecla_de_funcao("Ler")

## Envelope de 8 × 6 pontos. Não lida: cheio, com a aba desenhada no avesso e
## um ponto ao lado. Lida: só o contorno, com a aba aberta para cima.
func envelope(onde: Vector2, lida: bool, cor: Color) -> void:
	var fundo := FUNDO_LCD if cor == TINTA else TINTA
	if not lida:
		ponto(onde, Vector2(8, 6), cor)
		for i in 3:
			ponto(onde + Vector2(1 + i, 1 + i), Vector2(1, 1), fundo)
			ponto(onde + Vector2(6 - i, 1 + i), Vector2(1, 1), fundo)
		ponto(onde + Vector2(-2, 2), Vector2(1, 2), cor)
		return
	ponto(onde + Vector2(0, 2), Vector2(8, 1), cor)
	ponto(onde + Vector2(0, 5), Vector2(8, 1), cor)
	ponto(onde + Vector2(0, 2), Vector2(1, 4), cor)
	ponto(onde + Vector2(7, 2), Vector2(1, 4), cor)
	ponto(onde + Vector2(1, 1), Vector2(2, 1), cor)
	ponto(onde + Vector2(5, 1), Vector2(2, 1), cor)
	ponto(onde + Vector2(3, 0), Vector2(2, 1), cor)

func desenhar_a_mensagem() -> void:
	var m: Dictionary = caixa[aberta]
	ponto(Vector2(0, 10), Vector2(PONTOS.x, 10))
	escrever("%s  D%d" % [String(m.get("de", "")), int(m.get("dia", dia))], Vector2(3, 10), FUNDO_LCD)
	var cabem := 4
	for i in mini(cabem, _linhas_da_mensagem.size() - rolagem):
		escrever(_linhas_da_mensagem[rolagem + i], Vector2(3, 21 + i * 9))
	if _linhas_da_mensagem.size() > cabem:
		ponto(Vector2(PONTOS.x - 3, 21), Vector2(1, 36))
		var passo := 36.0 / _linhas_da_mensagem.size()
		ponto(Vector2(PONTOS.x - 4, 21 + rolagem * passo), Vector2(3, maxf(3.0, passo * cabem)))
	tecla_de_funcao("Voltar")

## A tecla de função embaixo, centralizada, como nos aparelhos antigos.
func tecla_de_funcao(texto: String) -> void:
	escrever(texto, Vector2((PONTOS.x - medir(texto)) / 2.0, PONTOS.y - 10))

# ------------------------------------------------------------------ entrada

## Um piscar de carência antes de aceitar tecla: a mesma tecla que abriu esta
## tela chega aqui no mesmo quadro em certas máquinas, e aí a tela abria e se
## confirmava sozinha. Dois décimos de segundo resolvem.
var _espera := 0.18

func _process(delta: float) -> void:
	_espera = maxf(0.0, _espera - delta)
	_tempo += delta
	# A mão não fica parada: um balanço lento, quase nada.
	if _aparelho != null:
		_aparelho.rotation = Vector3(deg_to_rad(-6 + sin(_tempo * 0.9) * 1.2), deg_to_rad(-8 + sin(_tempo * 0.6) * 2.0), deg_to_rad(sin(_tempo * 0.7) * 1.0))
		_aparelho.position = Vector3(0, -0.42 + sin(_tempo * 1.3) * 0.008, 0)

func _unhandled_input(evento: InputEvent) -> void:
	if _espera > 0.0: return
	if not (evento is InputEventKey) or not evento.pressed or evento.echo: return
	var tecla := (evento as InputEventKey).physical_keycode
	# Toda tecla do aparelho bipa; guardar tem o próprio som, tocado pelo mundo.
	if tecla in [KEY_UP, KEY_W, KEY_DOWN, KEY_S, KEY_E, KEY_ENTER, KEY_KP_ENTER] or (tecla in [KEY_ESCAPE, KEY_TAB, KEY_C] and aberta >= 0):
		Sons3D.tocar(self, Sons3D.celular_tecla(), -10.0)
	match tecla:
		KEY_UP, KEY_W:
			if aberta >= 0: rolagem = maxi(0, rolagem - 1)
			elif not caixa.is_empty(): escolha = (escolha - 1 + caixa.size()) % caixa.size()
			pintar()
		KEY_DOWN, KEY_S:
			if aberta >= 0: rolagem = clampi(rolagem + 1, 0, maxi(0, _linhas_da_mensagem.size() - 4))
			elif not caixa.is_empty(): escolha = (escolha + 1) % caixa.size()
			pintar()
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			if caixa.is_empty(): guardou.emit()
			elif aberta < 0: abrir()
			else: fechar_mensagem()
		KEY_ESCAPE, KEY_TAB, KEY_C:
			if aberta >= 0: fechar_mensagem()
			else: guardou.emit()
		_: return
	get_viewport().set_input_as_handled()
