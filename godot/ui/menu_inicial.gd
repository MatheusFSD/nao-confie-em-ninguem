extends Control

@onready var iniciar: Button = $Centro/Coluna/Iniciar
@onready var aviso: Label = $Centro/Coluna/Aviso

func _ready() -> void:
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
	var erro := get_tree().change_scene_to_file("res://scenes/mundo3d.tscn")
	if erro != OK:
		aviso.text = "Não foi possível iniciar o jogo."
		aviso.show()
		iniciar.disabled = false
		iniciar.grab_focus()
