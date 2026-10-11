class_name MenuPausa
extends CanvasLayer

# O menu do Esc: o jogo para (a árvore pausa) e aparecem as opções. Esc de
# novo ou "Continuar" volta. Volume, sensibilidade e tela cheia ficam guardados
# (Configuracoes).
signal continuou
signal foi_ao_menu

var _primeiro: Button

func _init() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	Configuracoes.carregar()
	var fundo := ColorRect.new()
	fundo.color = Color(0.0, 0.0, 0.0, 0.62)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var coluna := VBoxContainer.new()
	coluna.custom_minimum_size = Vector2(380, 0)
	coluna.add_theme_constant_override("separation", 14)
	coluna.theme = tema()
	centro.add_child(coluna)
	_primeiro = botao(coluna, "Continuar", func(): continuou.emit())
	coluna.add_child(HSeparator.new())
	deslizante(coluna, "Volume", 0.0, 1.0, 0.05, float(Configuracoes.valores.volume), func(v: float): Configuracoes.mudar("volume", v))
	deslizante(coluna, "Sensibilidade do mouse", 0.0008, 0.0050, 0.0002, float(Configuracoes.valores.sensibilidade), func(v: float): Configuracoes.mudar("sensibilidade", v))
	var cheia := CheckButton.new()
	cheia.text = "Tela cheia"
	cheia.button_pressed = bool(Configuracoes.valores.tela_cheia)
	cheia.toggled.connect(func(ligada: bool): Configuracoes.mudar("tela_cheia", ligada))
	coluna.add_child(cheia)
	coluna.add_child(HSeparator.new())
	botao(coluna, "Menu inicial", func(): foi_ao_menu.emit())
	botao(coluna, "Sair do jogo", func(): get_tree().quit())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_primeiro.grab_focus()

func botao(pai: Control, texto: String, ao_apertar: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(ao_apertar)
	pai.add_child(b)
	return b

func deslizante(pai: Control, texto: String, de: float, ate: float, passo: float, valor: float, ao_mudar: Callable) -> HSlider:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_color_override("font_color", Color("b8b39c"))
	rotulo.add_theme_font_size_override("font_size", 15)
	pai.add_child(rotulo)
	var barra := HSlider.new()
	barra.min_value = de
	barra.max_value = ate
	barra.step = passo
	barra.value = valor
	barra.custom_minimum_size = Vector2(0, 24)
	barra.value_changed.connect(ao_mudar)
	pai.add_child(barra)
	return barra

## O mesmo visual dos botões do menu inicial.
func tema() -> Theme:
	var visual := Theme.new()
	visual.set_color("font_color", "Button", Color("e6e0cf"))
	visual.set_color("font_hover_color", "Button", Color("fff4d8"))
	visual.set_color("font_focus_color", "Button", Color("fff4d8"))
	visual.set_color("font_color", "CheckButton", Color("e6e0cf"))
	visual.set_font_size("font_size", "Button", 20)
	visual.set_stylebox("normal", "Button", estilo("15231f", "3c5146"))
	visual.set_stylebox("hover", "Button", estilo("23382f", "85947a"))
	visual.set_stylebox("pressed", "Button", estilo("304637", "c5b680"))
	var foco := estilo("00000000", "dacf9f")
	foco.set_border_width_all(2)
	visual.set_stylebox("focus", "Button", foco)
	return visual

func estilo(fundo: String, borda: String) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = Color(fundo)
	e.border_color = Color(borda)
	e.set_border_width_all(1)
	e.content_margin_left = 18
	e.content_margin_right = 18
	e.content_margin_top = 8
	e.content_margin_bottom = 8
	return e

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and (evento as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		continuou.emit()
