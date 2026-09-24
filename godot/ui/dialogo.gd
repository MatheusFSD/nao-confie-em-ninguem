extends Control

# Caixa de diálogo com retrato: mostra uma fala por vez e avança com E, Espaço ou Enter.
# O retrato só é carregado enquanto a conversa está na tela.
signal terminou

const RETRATO := "res://ui/personagens/irma.webp"
var linhas: Array = []
var indice := 0
var retrato: Texture2D
var _nome: Label
var _texto: Label
var _aviso: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var caixa := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.045, 0.05, 0.92)
	estilo.border_color = Color(0.85, 0.65, 0.3, 0.45)
	estilo.border_width_top = 3
	estilo.set_corner_radius_all(6)
	estilo.set_content_margin_all(16)
	caixa.add_theme_stylebox_override("panel", estilo)
	caixa.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caixa.offset_left = 24
	caixa.offset_right = -300
	caixa.offset_top = -172
	caixa.offset_bottom = -24
	caixa.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(caixa)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	caixa.add_child(coluna)
	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", 20)
	_nome.add_theme_color_override("font_color", Color("e8c16a"))
	coluna.add_child(_nome)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 19)
	_texto.add_theme_color_override("font_color", Color("e6e0cf"))
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(_texto)
	_aviso = Label.new()
	_aviso.text = "E / Espaço — continuar"
	_aviso.add_theme_font_size_override("font_size", 13)
	_aviso.add_theme_color_override("font_color", Color("8c978b"))
	coluna.add_child(_aviso)
	hide()

func mostrar(nome: String, falas: Array) -> void:
	if falas.is_empty():
		terminou.emit()
		return
	retrato = load(RETRATO)
	linhas = falas
	indice = 0
	_nome.text = nome
	_texto.text = str(linhas[0])
	show()
	queue_redraw()

func avancar() -> void:
	indice += 1
	if indice >= linhas.size():
		fechar()
		terminou.emit()
		return
	_texto.text = str(linhas[indice])
	_aviso.text = "E / Espaço — continuar" if indice < linhas.size() - 1 else "E / Espaço — fechar"
	queue_redraw()

func fechar() -> void:
	hide()
	retrato = null

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		avancar()
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
