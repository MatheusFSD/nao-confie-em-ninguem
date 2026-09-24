extends Control

# Tela cheia de TV ou rádio: ilustração ao fundo, notícia ao lado e uma camada
# animada por cima da arte (canal na tela da TV; ponteiro e som no rádio).
# Uma arte serve para qualquer notícia. A imagem só é carregada ao abrir e sai da memória ao fechar.
signal close_requested

const MEDIA := {
	"tv": {"image": "res://ui/cenas/tv.webp", "title": "TV / Jornal"},
	"radio": {"image": "res://ui/cenas/radio.webp", "title": "Rádio"},
}
## Áreas na imagem de 1280 × 720.
const TV_SCREEN := Rect2(896, 160, 210, 226)
const RADIO_DIAL := Rect2(858, 284, 162, 28)
const RADIO_SPEAKERS := [Vector2(785, 367), Vector2(1118, 379)]
const SOURCE_COLORS := {"Governo": Color("2f5d8a"), "Cientistas": Color("2f7a5a"), "Conspiracionistas": Color("8a3a2f")}
## Estação de cada fonte: posição no mostrador (0 a 1) e frequência exibida.
const STATIONS := {"Governo": [0.18, "FM 88,7"], "Cientistas": [0.55, "FM 97,3"], "Conspiracionistas": [0.9, "AM 1440"]}

var kind := "tv"
var messages: Array = []
var index := 0
var day := 1
var texture: Texture2D
var _time := 0.0
var _needle := 0.0
var _title: Label
var _source: Label
var _text: Label
var _counter: Label
var _previous: Button
var _next: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Pintura digital: filtro linear (o projeto usa Nearest para a pixel art).
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var column := VBoxContainer.new()
	column.anchor_left = 0.05
	column.anchor_right = 0.5
	column.anchor_top = 0.5
	column.anchor_bottom = 0.5
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	_title = _label(column, 16, Color("a9b4a8"))
	_source = _label(column, 30, Color("f2ead2"))
	_text = _label(column, 21, Color("e6e0cf"))
	_text.custom_minimum_size.x = 380
	_counter = _label(column, 14, Color("8c978b"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	_previous = _button(row, "◀ Anterior", func(): show_message(index - 1))
	_next = _button(row, "Próxima ▶", func(): show_message(index + 1))
	_button(row, "Fechar [Esc]", func(): close_requested.emit())
	hide()

func open(media: String, current_day: int, day_messages: Array) -> void:
	kind = media
	texture = load(MEDIA[kind].image)
	day = current_day
	messages = day_messages
	_needle = 0.0
	show()
	show_message(0)

func close() -> void:
	hide()
	texture = null

func show_message(i: int) -> void:
	index = clampi(i, 0, maxi(messages.size() - 1, 0))
	_title.text = "%s · Dia %d" % [MEDIA[kind].title, day]
	if messages.is_empty():
		_source.text = "Fora do ar"
		_text.text = "Nenhuma notícia cadastrada para este dia."
	else:
		var source: String = messages[index].fonte
		_source.text = "%s · %s" % [STATIONS[source][1], source] if kind == "radio" and STATIONS.has(source) else source
		_text.text = "“%s”" % messages[index].texto
	_counter.text = "Notícia %d de %d · ← → para trocar" % [index + 1, messages.size()] if messages.size() > 1 else ""
	_previous.visible = messages.size() > 1
	_next.visible = messages.size() > 1
	_previous.disabled = index == 0
	_next.disabled = index >= messages.size() - 1
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed: return
	if event.physical_keycode in [KEY_RIGHT, KEY_D]: show_message(index + 1)
	elif event.physical_keycode in [KEY_LEFT, KEY_A]: show_message(index - 1)
	else: return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible: return
	_time += delta
	if kind == "radio":
		# O ponteiro desliza até a estação da fonte atual.
		_needle = lerpf(_needle, _station(), 1.0 - exp(-delta * 4.0))
	queue_redraw()

func _station() -> float:
	if messages.is_empty(): return 0.0
	return STATIONS.get(messages[index].fonte, [0.5])[0]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if texture == null: return
	# Altura cheia, alinhada à direita: em telas estreitas corta a parede, nunca o aparelho.
	var scale := size.y / texture.get_height()
	var drawn := texture.get_size() * scale
	var offset := Vector2(size.x - drawn.x if drawn.x >= size.x else (size.x - drawn.x) / 2.0, 0)
	draw_texture_rect(texture, Rect2(offset, drawn), false)
	# Escurece a esquerda para o texto ler bem.
	var fade := size.x * 0.62
	var dark := Color(0, 0, 0, 0.8)
	var mid := Color(0, 0, 0, 0.45)
	var clear := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(fade * 0.5, 0), Vector2(fade * 0.5, size.y), Vector2(0, size.y)]), PackedColorArray([dark, mid, mid, dark]))
	draw_polygon(PackedVector2Array([Vector2(fade * 0.5, 0), Vector2(fade, 0), Vector2(fade, size.y), Vector2(fade * 0.5, size.y)]), PackedColorArray([mid, clear, clear, mid]))
	if kind == "tv":
		_draw_tv(Rect2(offset + TV_SCREEN.position * scale, TV_SCREEN.size * scale))
	else:
		_draw_radio(Rect2(offset + RADIO_DIAL.position * scale, RADIO_DIAL.size * scale), offset, scale)

func _draw_tv(screen: Rect2) -> void:
	if messages.is_empty():
		# Chuvisco quando não há notícia.
		for i in 900:
			var p := screen.position + Vector2(randf() * screen.size.x, randf() * screen.size.y)
			draw_rect(Rect2(p, Vector2(2, 2)), Color(0, 0, 0, randf() * 0.5))
		return
	var source: String = messages[index].fonte
	var color: Color = SOURCE_COLORS.get(source, Color("555555"))
	var font := ThemeDB.fallback_font
	# Fundo do canal, faixa de plantão e nome da fonte.
	draw_rect(screen, Color(color, 0.55))
	var band := Rect2(screen.position.x, screen.end.y - screen.size.y * 0.3, screen.size.x, screen.size.y * 0.16)
	draw_rect(band, Color("e9e4d6"))
	var small := int(band.size.y * 0.5)
	var live_width := font.get_string_size("AO VIVO", HORIZONTAL_ALIGNMENT_LEFT, -1, small).x + 10
	draw_rect(Rect2(band.position, Vector2(live_width, band.size.y)), Color("b0392e"))
	draw_string(font, band.position + Vector2(5, band.size.y * 0.7), "AO VIVO", HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color.WHITE)
	draw_string(font, band.position + Vector2(live_width + 6, band.size.y * 0.7), "PLANTÃO", HORIZONTAL_ALIGNMENT_LEFT, band.size.x - live_width - 8, small, Color("222222"))
	var font_size := 34
	while font_size > 12 and font.get_string_size(source.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > screen.size.x * 0.86:
		font_size -= 1
	draw_string(font, Vector2(screen.position.x, screen.position.y + screen.size.y * 0.42), source.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, screen.size.x, font_size, Color(1, 1, 1, 0.95))
	# Linhas de varredura e leve cintilação de tubo.
	var y := screen.position.y
	while y < screen.end.y:
		draw_line(Vector2(screen.position.x, y), Vector2(screen.end.x, y), Color(0, 0, 0, 0.08), 1)
		y += 3
	draw_rect(screen, Color(1, 1, 1, 0.03 + 0.03 * sin(_time * 23.0)))

func _draw_radio(dial: Rect2, offset: Vector2, scale: float) -> void:
	# Luz âmbar do mostrador, mais forte quando sintonizado.
	var tuned := 1.0 - clampf(absf(_needle - _station()) * 8.0, 0.0, 1.0)
	draw_rect(dial.grow(3 * scale), Color(1.0, 0.62, 0.25, 0.10 + 0.05 * tuned))
	draw_rect(dial, Color(1.0, 0.78, 0.45, 0.10 + 0.04 * sin(_time * 3.0)))
	# Ponteiro vermelho com pequena oscilação de sintonia.
	var x := dial.position.x + dial.size.x * (_needle + sin(_time * 7.0) * 0.002)
	draw_line(Vector2(x + 1, dial.position.y - 2 * scale), Vector2(x + 1, dial.end.y + 2 * scale), Color(0, 0, 0, 0.45), 3 * scale)
	draw_line(Vector2(x, dial.position.y - 2 * scale), Vector2(x, dial.end.y + 2 * scale), Color("e0463a"), 2.2 * scale)
	draw_circle(Vector2(x, dial.position.y + dial.size.y * 0.5), 5 * scale * tuned, Color(1, 0.4, 0.3, 0.18))
	if messages.is_empty(): return
	# Ondas de som saindo dos dois alto-falantes, na cor da fonte.
	var color: Color = SOURCE_COLORS.get(messages[index].fonte, Color("d8c79a")).lightened(0.35)
	for side in 2:
		var speaker: Vector2 = offset + RADIO_SPEAKERS[side] * scale
		var facing := PI if side == 0 else 0.0
		for i in 3:
			var t := fmod(_time * 0.7 + i / 3.0, 1.0)
			var radius := (40.0 + 90.0 * t) * scale
			draw_arc(speaker, radius, facing - 0.9, facing + 0.9, 24, Color(color, 0.35 * (1.0 - t) * tuned), 2.0)

func _label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
