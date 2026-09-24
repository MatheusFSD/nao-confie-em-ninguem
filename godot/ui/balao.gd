extends Control

# Balão de fala que acompanha um personagem do mundo na tela.
# Some ao acabar o tempo, se a pessoa sair de cena ou se o morador se afastar.
const LARGURA := 230.0
const COR := Color("f2ead2")
const BORDA := Color("1a1d1b")
var alvo: Node2D
var ouvinte: Node2D
var _tempo := 0.0
var _texto: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size.x = LARGURA - 24
	_texto.position = Vector2(12, 9)
	_texto.add_theme_font_size_override("font_size", 15)
	_texto.add_theme_color_override("font_color", Color("1f2322"))
	add_child(_texto)
	hide()

func falar(quem: Node2D, quem_ouve: Node2D, frase: String, segundos: float) -> void:
	alvo = quem
	ouvinte = quem_ouve
	_texto.text = frase
	_texto.size = Vector2(LARGURA - 24, 0)
	_tempo = segundos
	show()
	_seguir()

func _process(delta: float) -> void:
	if not visible: return
	_tempo -= delta
	var valido := is_instance_valid(alvo) and alvo.visible and alvo.modulate.a > 0.5
	var longe := valido and ouvinte != null and ouvinte.global_position.distance_to(alvo.global_position) > 120.0
	if _tempo <= 0 or not valido or longe or not _na_tela():
		hide()
		return
	_seguir()

# O balão fica sempre preso acima da cabeça de quem fala, nunca à tela.
func _seguir() -> void:
	var altura := _texto.get_combined_minimum_size().y + 18
	size = Vector2(LARGURA, altura)
	var tela := alvo.get_global_transform_with_canvas().origin
	position = Vector2(tela.x - LARGURA / 2, tela.y - altura - 30)
	queue_redraw()

func _na_tela() -> bool:
	return get_viewport_rect().grow(-4).has_point(alvo.get_global_transform_with_canvas().origin)

func _draw() -> void:
	var tela := alvo.get_global_transform_with_canvas().origin - position if is_instance_valid(alvo) else Vector2(LARGURA / 2, size.y + 20)
	var ponta_x := clampf(tela.x, 20, LARGURA - 20)
	# Com o balão centrado na pessoa, o rabicho fica no meio, logo acima da cabeça.
	var caixa := Rect2(Vector2.ZERO, size)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR
	estilo.border_color = BORDA
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.shadow_color = Color(0, 0, 0, 0.35)
	estilo.shadow_size = 4
	estilo.shadow_offset = Vector2(2, 3)
	draw_style_box(estilo, caixa)
	# Rabicho apontando para quem fala.
	var base := size.y - 2
	draw_colored_polygon(PackedVector2Array([Vector2(ponta_x - 9, base), Vector2(ponta_x + 9, base), Vector2(ponta_x, base + 14)]), BORDA)
	draw_colored_polygon(PackedVector2Array([Vector2(ponta_x - 6, base - 1), Vector2(ponta_x + 6, base - 1), Vector2(ponta_x, base + 10)]), COR)
