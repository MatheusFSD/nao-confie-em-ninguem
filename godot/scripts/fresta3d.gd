class_name Fresta3D
extends CanvasLayer

# Olhar pela fresta da janela: a cortina afasta só um pouco, a tela fecha em
# volta e sobra uma faixa estreita da rua. Serve para saber o que há lá fora
# antes de decidir se abre a porta — e, de noite, para não precisar abrir.
#
# A imagem da rua é do próprio mundo, por uma câmera posta na janela. O que esta
# camada faz é tapar o resto e escrever embaixo o que se nota.
signal fechou

const MASCARA := preload("res://shaders/fresta.gdshader")

var _nota: Label
var _aviso: Label

func _init() -> void:
	layer = 2
	var pano := ColorRect.new()
	pano.name = "Pano"
	pano.set_anchors_preset(Control.PRESET_FULL_RECT)
	pano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = MASCARA
	pano.material = material
	add_child(pano)
	_nota = escrever(19, Color("f3e6c8"))
	_nota.anchor_top = 1.0
	_nota.anchor_bottom = 1.0
	_nota.offset_top = -152.0
	_nota.offset_bottom = -62.0
	_aviso = escrever(16, Color(0.95, 0.9, 0.78, 0.65))
	_aviso.anchor_top = 1.0
	_aviso.anchor_bottom = 1.0
	_aviso.offset_top = -48.0
	_aviso.offset_bottom = -20.0
	_aviso.text = "E  sair da janela"

func escrever(tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.anchor_right = 1.0
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	rotulo.add_theme_constant_override("shadow_offset_x", 2)
	rotulo.add_theme_constant_override("shadow_offset_y", 2)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rotulo)
	return rotulo

## O que o morador nota lá fora, escrito embaixo da fresta.
func notar(texto: String) -> void:
	_nota.text = texto

## Um piscar de carência antes de aceitar tecla: a mesma tecla que abriu esta
## tela chega aqui no mesmo quadro em certas máquinas, e aí a tela abria e se
## confirmava sozinha. Dois décimos de segundo resolvem.
var _espera := 0.18

func _process(delta: float) -> void:
	_espera = maxf(0.0, _espera - delta)

func _unhandled_input(evento: InputEvent) -> void:
	if _espera > 0.0: return
	if not (evento is InputEventKey) or not evento.pressed or evento.echo: return
	match (evento as InputEventKey).physical_keycode:
		KEY_E, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: fechou.emit()
		_: return
	get_viewport().set_input_as_handled()
