extends Control

@onready var iniciar: Button = $Centro/Coluna/Iniciar
@onready var aviso: Label = $Centro/Coluna/Aviso

func _ready() -> void:
	Configuracoes.aplicar()
	var visual := Theme.new()
	visual.set_color("font_color", "Button", Color("e6e0cf"))
	visual.set_color("font_hover_color", "Button", Color("fff4d8"))
	visual.set_color("font_pressed_color", "Button", Color("fff4d8"))
	visual.set_color("font_focus_color", "Button", Color("fff4d8"))
	visual.set_constant("h_separation", "Button", 12)
	visual.set_stylebox("normal", "Button", _estilo("15231f", "3c5146"))
	visual.set_stylebox("hover", "Button", _estilo("23382f", "85947a"))
	visual.set_stylebox("pressed", "Button", _estilo("304637", "c5b680"))
	visual.set_stylebox("hover_pressed", "Button", _estilo("3c5340", "dacf9f"))
	var foco := _estilo("00000000", "dacf9f")
	foco.set_border_width_all(2)
	visual.set_stylebox("focus", "Button", foco)
	theme = visual
	iniciar.pressed.connect(_iniciar)
	iniciar.grab_focus()
	# PT/ENG usam somente o ButtonGroup da cena: seleção visual, sem tradução.
	montar_a_sala()

## Ao fundo, a sala escura com a TV chiando; o menu vai para a esquerda, numa
## sombra, e a TV fica à mostra à direita.
func montar_a_sala() -> void:
	var sala := SalaDoMenu.new()
	sala.name = "Sala"
	add_child(sala)
	move_child(sala, 1)
	var sombra := TextureRect.new()
	var degrade := GradientTexture2D.new()
	degrade.gradient = Gradient.new()
	degrade.gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.82))
	degrade.gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	degrade.fill_from = Vector2(0.0, 0.0)
	degrade.fill_to = Vector2(1.0, 0.0)
	sombra.texture = degrade
	sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sombra.anchor_right = 0.62
	sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sombra.stretch_mode = TextureRect.STRETCH_SCALE
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sombra)
	move_child(sombra, 2)
	var centro := get_node("Centro") as Control
	centro.anchor_left = 0.03
	centro.anchor_right = 0.45

func _estilo(fundo: String, borda: String) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(fundo)
	estilo.border_color = Color(borda)
	estilo.set_border_width_all(1)
	estilo.content_margin_left = 18
	estilo.content_margin_right = 18
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	return estilo

func _iniciar() -> void:
	iniciar.disabled = true
	# Antes do dia 0, a abertura na TV da sala; ela mesma abre o jogo no fim.
	var erro := get_tree().change_scene_to_file("res://scenes/abertura.tscn")
	if erro != OK:
		aviso.text = "Não foi possível iniciar o jogo."
		aviso.show()
		iniciar.disabled = false
		iniciar.grab_focus()
