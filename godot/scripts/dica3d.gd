class_name Dica3D
extends CanvasLayer

# O aviso que aparece quando o jogador encosta o olhar numa porta ou no ponto de
# ônibus: a tecla desenhada como tampa de teclado e, ao lado, o que ela faz.
#
## A dica é desenhada fora da tela pequena do jogo, na resolução da janela, para
## o texto sair nítido. Por isso os tamanhos aqui são de pixel de janela.
const LARGURA_TECLA := 26
const ALTURA_TECLA := 26

var tampa: Panel
var letra: Label
var texto: Label
## A segunda tecla, para quando a porta também pode ser trancada.
var segunda_tampa: Panel
var segunda_letra: Label
var segundo_texto: Label
## A fileira da tecla, escondida sozinha para o recado poder ficar na tela.
var linha: HBoxContainer
## O recado do dia: o que o jogo precisa dizer sem parar o jogo.
var recado: Label
## O pontinho do meio da tela, que acende quando há o que usar na frente.
var mira: Panel
var _apagar: Tween

func _init() -> void:
	layer = 1
	linha = HBoxContainer.new()
	linha.name = "Dica"
	linha.add_theme_constant_override("separation", 8)
	# Ancorada embaixo, no meio: é onde o olho já está, sem tapar a mira.
	linha.anchor_left = 0.5
	linha.anchor_right = 0.5
	linha.anchor_top = 1.0
	linha.anchor_bottom = 1.0
	linha.grow_horizontal = Control.GROW_DIRECTION_BOTH
	linha.grow_vertical = Control.GROW_DIRECTION_BEGIN
	linha.offset_top = -64
	linha.offset_bottom = -32
	add_child(linha)
	tampa = tecla("E")
	letra = tampa.get_child(0)
	texto = dizer()
	segunda_tampa = tecla("T")
	segunda_letra = segunda_tampa.get_child(0)
	segundo_texto = dizer()
	# O recado fica acima da tecla, no mesmo eixo do olhar.
	recado = Label.new()
	recado.name = "Recado"
	recado.anchor_right = 1.0
	recado.anchor_top = 1.0
	recado.anchor_bottom = 1.0
	recado.grow_vertical = Control.GROW_DIRECTION_BEGIN
	recado.offset_top = -148
	recado.offset_bottom = -72
	recado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recado.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	recado.add_theme_font_size_override("font_size", 18)
	recado.add_theme_color_override("font_color", Color("f3e6c8"))
	recado.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	recado.add_theme_constant_override("shadow_offset_x", 2)
	recado.add_theme_constant_override("shadow_offset_y", 2)
	recado.modulate.a = 0.0
	add_child(recado)
	# A mira: um ponto pequeno no meio, para saber para onde se está olhando.
	# Ela acende quando o que está na frente dá para usar.
	mira = Panel.new()
	mira.name = "Mira"
	mira.custom_minimum_size = Vector2(6, 6)
	mira.size = Vector2(6, 6)
	mira.anchor_left = 0.5
	mira.anchor_right = 0.5
	mira.anchor_top = 0.5
	mira.anchor_bottom = 0.5
	mira.offset_left = -3
	mira.offset_top = -3
	mira.offset_right = 3
	mira.offset_bottom = 3
	mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mira)
	apontar(false)
	esconder()

## Uma tampa de teclado com a letra dentro.
func tecla(qual: String) -> Panel:
	var nova := Panel.new()
	nova.custom_minimum_size = Vector2(LARGURA_TECLA, ALTURA_TECLA)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.93, 0.92, 0.88, 0.92)
	estilo.border_color = Color(0.18, 0.17, 0.16, 0.95)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(4)
	# Sombra embaixo, para a tecla parecer tecla.
	estilo.shadow_color = Color(0, 0, 0, 0.35)
	estilo.shadow_size = 2
	estilo.shadow_offset = Vector2(0, 2)
	nova.add_theme_stylebox_override("panel", estilo)
	linha.add_child(nova)
	var escrita := Label.new()
	escrita.text = qual
	escrita.add_theme_font_size_override("font_size", 18)
	escrita.add_theme_color_override("font_color", Color(0.12, 0.11, 0.1))
	escrita.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escrita.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	escrita.set_anchors_preset(Control.PRESET_FULL_RECT)
	nova.add_child(escrita)
	return nova

## O que a tecla faz, escrito ao lado dela.
func dizer() -> Label:
	var rotulo := Label.new()
	rotulo.add_theme_font_size_override("font_size", 18)
	rotulo.add_theme_color_override("font_color", Color(0.96, 0.95, 0.9))
	rotulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	rotulo.add_theme_constant_override("shadow_offset_x", 1)
	rotulo.add_theme_constant_override("shadow_offset_y", 1)
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(rotulo)
	return rotulo

## A cor da mira: apagada quando não há nada, acesa quando há.
func apontar(tem_coisa: bool) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("ffd35a") if tem_coisa else Color(1, 1, 1, 0.45)
	estilo.border_color = Color(0, 0, 0, 0.6)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(3)
	mira.add_theme_stylebox_override("panel", estilo)

func mostrar(acao: String) -> void:
	texto.text = acao
	segunda_tampa.visible = false
	segundo_texto.visible = false
	linha.visible = true

## Duas teclas de uma vez: abrir com E e trancar com T, lado a lado.
func mostrar_duas(com_e: String, com_t: String) -> void:
	texto.text = com_e
	segundo_texto.text = com_t
	segunda_tampa.visible = true
	segundo_texto.visible = true
	linha.visible = true

func esconder() -> void:
	linha.visible = false

## Um recado que aparece e some sozinho: quanto recebeu, que faltou energia,
## o que a noite cobrou. Nao para o jogo.
func avisar(o_que: String) -> void:
	if o_que.is_empty(): return
	recado.text = o_que
	if _apagar != null and _apagar.is_valid(): _apagar.kill()
	_apagar = create_tween()
	_apagar.tween_property(recado, "modulate:a", 1.0, 0.18)
	_apagar.tween_interval(2.8)
	_apagar.tween_property(recado, "modulate:a", 0.0, 0.6)
