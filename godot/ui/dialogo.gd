extends Control

# Caixa de diálogo com retrato: mostra uma fala por vez e avança com E, Espaço ou Enter.
# O retrato só é carregado enquanto a conversa está na tela.
#
# As letras surgem uma a uma, com um "tic" a cada duas, como nos RPGs japoneses
# antigos. O tom do tic muda com quem fala. E/Espaço no meio da fala mostra o
# resto de uma vez; com a fala inteira, passa para a próxima.
signal terminou

const RETRATO := "res://ui/retratos/irma.webp"
## Quem fala pode trazer o próprio retrato; sem isso, é o da irmã.
var caminho_do_retrato := RETRATO
var linhas: Array = []
var indice := 0
var retrato: Texture2D
var _nome: Label
var _texto: Label
var _aviso: Label
var _caixa: PanelContainer
var _coluna: VBoxContainer
var _respostas: Control
## Só os vizinhos usam respostas. O tutorial antigo mantém o fluxo de falas.
var respostas_ao_final := false
var aguardando_resposta := false
## Carência antes de aceitar tecla: a tecla que abre não pode avançar a fala.
var _espera := 0.0
## Letras por segundo.
const RITMO := 48.0
var _letras := 0.0
var _tic: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_caixa = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.045, 0.064, 0.059, 0.97)
	estilo.border_color = Color("455047")
	estilo.set_border_width_all(1)
	estilo.border_width_top = 2
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(18)
	_caixa.add_theme_stylebox_override("panel", estilo)
	_caixa.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caixa.offset_left = 24
	_caixa.offset_right = -300
	_caixa.offset_top = -172
	_caixa.offset_bottom = -24
	_caixa.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_caixa)
	_coluna = VBoxContainer.new()
	_coluna.add_theme_constant_override("separation", 10)
	_caixa.add_child(_coluna)
	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", 20)
	_nome.add_theme_color_override("font_color", Color("e8c16a"))
	_coluna.add_child(_nome)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 19)
	_texto.add_theme_color_override("font_color", Color("e6e0cf"))
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A quebra de linha é feita com o texto inteiro: a palavra não pula de linha
	# no meio da letra surgindo.
	_texto.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_coluna.add_child(_texto)
	_aviso = Label.new()
	_aviso.text = "E / Espaço — continuar"
	_aviso.add_theme_font_size_override("font_size", 13)
	_aviso.add_theme_color_override("font_color", Color("8c978b"))
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coluna.add_child(_aviso)
	_tic = AudioStreamPlayer.new()
	_tic.stream = Sons3D.letra()
	_tic.volume_db = -8.0
	add_child(_tic)
	resized.connect(_ajustar_layout)
	_texto.minimum_size_changed.connect(_ajustar_layout)
	_ajustar_layout()
	hide()

func mostrar(nome: String, falas: Array) -> void:
	limpar_respostas()
	if falas.is_empty():
		terminou.emit()
		return
	# Sem caminho, a fala sai sem retrato (o sofá, por exemplo).
	retrato = load(caminho_do_retrato) if not caminho_do_retrato.is_empty() else null
	linhas = falas
	indice = 0
	_nome.text = nome
	# Cada voz no seu tom: o mesmo nome, o mesmo tic.
	_tic.pitch_scale = 0.8 + float(abs(nome.hash()) % 50) / 100.0
	_texto.text = str(linhas[0])
	comecar_letras()
	_aviso.text = "E / Espaço — continuar" if linhas.size() > 1 else "E / Espaço — fechar"
	_espera = 0.18
	show()
	queue_redraw()
	if respostas_ao_final and linhas.size() == 1: terminou.emit()

func avancar() -> void:
	if aguardando_resposta: return
	indice += 1
	if indice >= linhas.size():
		fechar()
		terminou.emit()
		return
	_texto.text = str(linhas[indice])
	comecar_letras()
	_aviso.text = "E / Espaço — continuar" if indice < linhas.size() - 1 else "E / Espaço — fechar"
	queue_redraw()
	if respostas_ao_final and indice == linhas.size() - 1: terminou.emit()

func mostrar_respostas(respostas: Control) -> void:
	limpar_respostas()
	aguardando_resposta = true
	_respostas = respostas
	_coluna.add_child(respostas)
	_coluna.move_child(respostas, 2)
	var quantas: int = mini(9, respostas.opcoes.size()) if "opcoes" in respostas else 5
	_aviso.text = "Clique ou use 1–%d · ↑ ↓ escolher · Enter responder · Esc encerrar" % quantas
	_ajustar_layout()
	call_deferred("_ajustar_layout")

func limpar_respostas() -> void:
	if is_instance_valid(_respostas):
		_respostas.hide()
		if _respostas.get_parent() == _coluna: _coluna.remove_child(_respostas)
		_respostas.queue_free()
	_respostas = null
	aguardando_resposta = false

func _ajustar_layout() -> void:
	if _caixa == null: return
	_caixa.offset_right = -clampf(size.x * 0.30, 220.0, 300.0) if size.x >= 760.0 else -24.0
	# Ao fechar as opções, a caixa volta à altura de uma fala.
	_caixa.offset_top = -172
	if is_instance_valid(_respostas):
		var texto_alto := _texto.get_combined_minimum_size().y
		_respostas.altura_maxima = maxf(100.0, size.y - texto_alto - 180.0)

func fechar() -> void:
	limpar_respostas()
	hide()
	retrato = null

## A fala começa vazia e vai aparecendo.
func comecar_letras() -> void:
	_letras = 0.0
	_texto.visible_characters = 0

## Ainda tem letra por aparecer?
func escrevendo() -> bool:
	return _texto.visible_characters >= 0 and _texto.visible_characters < _texto.get_total_character_count()

## Mostra a fala inteira de uma vez.
func completar() -> void:
	_texto.visible_characters = -1

func _process(delta: float) -> void:
	_espera = maxf(0.0, _espera - delta)
	if not visible or not escrevendo(): return
	var antes := _texto.visible_characters
	_letras += delta * RITMO
	var agora := mini(int(_letras), _texto.get_total_character_count())
	_texto.visible_characters = agora
	# Um tic a cada duas letras novas (espaço não conta).
	for i in range(antes, agora):
		var letra := _texto.text.substr(i, 1)
		if letra != " " and i % 2 == 0:
			_tic.play()
			break
	if agora >= _texto.get_total_character_count(): _texto.visible_characters = -1

func _input(event: InputEvent) -> void:
	if _espera > 0.0: return
	if aguardando_resposta or not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		if escrevendo(): completar()
		else: avancar()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	# Escurece a cena e encosta o retrato no canto direito, atrás da caixa.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	if retrato == null: return
	var altura := minf(size.y * 0.78, retrato.get_height())
	var escala := altura / retrato.get_height()
	var largura := retrato.get_width() * escala
	var canto := Vector2(size.x - largura - 10, size.y - altura)
	draw_texture_rect(retrato, Rect2(canto + Vector2(6, 0), Vector2(largura, altura)), false, Color(0, 0, 0, 0.35))
	draw_texture_rect(retrato, Rect2(canto, Vector2(largura, altura)), false)
