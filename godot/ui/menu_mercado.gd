extends Control

# Tela cheia do mercado: ilustração ao fundo e painel de compras por cima do corredor.
# A imagem só é carregada ao abrir e sai da memória ao fechar.
signal buy_requested(kind: String)
signal close_requested

const IMAGE_PATH := "res://ui/cenas/mercado.webp"
const ITEMS := {
	"comida": {"nome": "Comida", "efeito": "+2 comida"},
	"agua": {"nome": "Água", "efeito": "+2 água"},
	"pilhas": {"nome": "Pilhas", "efeito": "+20 energia (máx. 100)"},
}
var texture: Texture2D
var _title: Label
var _status: Label
var _feedback: Label
var _buttons := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.05, 0.86)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	style.border_color = Color(0.85, 0.65, 0.3, 0.5)
	style.border_width_top = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.94
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_title = _label(column, 24, Color("f2ead2"))
	_status = _label(column, 15, Color("b9c2b6"))
	for kind: String in ITEMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)
		var info := _label(row, 17, Color("e6e0cf"))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text = "%s\n%s" % [ITEMS[kind].nome, ITEMS[kind].efeito]
		var button := Button.new()
		button.custom_minimum_size = Vector2(120, 40)
		button.pressed.connect(func(): buy_requested.emit(kind))
		row.add_child(button)
		_buttons[kind] = button
	_feedback = _label(column, 14, Color("d9b25a"))
	var close := Button.new()
	close.text = "Voltar para casa [Esc]"
	close.pressed.connect(func(): close_requested.emit())
	column.add_child(close)
	hide()

## state: dia, dinheiro, comida, agua, energia; prices: PURCHASES do survival.
func open(state: Dictionary, prices: Dictionary, feedback := "") -> void:
	if texture == null: texture = load(IMAGE_PATH)
	_title.text = "Mercado do bairro · Dia %d" % state.dia
	_status.text = "Dinheiro: R$ %d\nEm casa: %d comida · %d água · %d energia" % [state.dinheiro, state.comida, state.agua, state.energia]
	for kind: String in _buttons:
		var cost := int(prices[kind].cost)
		var button: Button = _buttons[kind]
		button.text = "R$ %d" % cost
		button.disabled = state.dinheiro < cost or (kind == "pilhas" and state.energia >= 100)
	_feedback.text = feedback
	show()
	queue_redraw()

func close() -> void:
	hide()
	texture = null

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if texture == null: return
	# Cobre a tela inteira sem distorcer, centralizando o corredor.
	var scale := maxf(size.x / texture.get_width(), size.y / texture.get_height())
	var drawn := texture.get_size() * scale
	draw_texture_rect(texture, Rect2((size - drawn) / 2.0, drawn), false)

func _label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
