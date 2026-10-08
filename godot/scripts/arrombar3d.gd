class_name Arrombar3D
extends CanvasLayer

# Arrombar o cadeado da porta de aço com o pé de cabra: um ponteiro corre de um
# lado para o outro da barra e o golpe (E, Espaço ou Enter) tem de cair dentro
# da faixa marcada. Três golpes certos abrem a porta; a cada acerto a faixa
# encolhe e o ponteiro acelera. Um golpe fora da faixa faz o cadeado estalar
# alto — quem decide o que esse barulho atrai é o mundo. Esc desiste.
signal terminou(resultado: String)

const ACERTOS := 3
const FAIXA_INICIAL := 0.24
const ENCOLHE := 0.72
const VELOCIDADE_INICIAL := 0.85
const ACELERA := 1.3

var titulo := "ARROMBANDO A PORTA"
var acertos := 0
## Posição do ponteiro na barra, de 0 a 1.
var ponteiro := 0.0
var faixa_inicio := 0.0
var faixa_largura := FAIXA_INICIAL
var velocidade := VELOCIDADE_INICIAL
var _rumo := 1.0
var _acabou := false
var _sorte := RandomNumberGenerator.new()
var _desenho: Control
var _placar: Label
var _ajuda: Label
## Carência: a tecla que abriu o minigame não pode valer como golpe.
var _espera := 0.3

func _init() -> void:
	layer = 3
	_sorte.randomize()
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.03, 0.05, 0.78)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 14)
	caixa.set_anchors_preset(Control.PRESET_CENTER)
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	caixa.custom_minimum_size = Vector2(460, 0)
	add_child(caixa)
	_placar = escrever(caixa, "", 19, Color("f0b541"))
	_desenho = Control.new()
	_desenho.custom_minimum_size = Vector2(460, 54)
	_desenho.draw.connect(desenhar)
	caixa.add_child(_desenho)
	_ajuda = escrever(caixa, "E / Espaço quando o ponteiro estiver na faixa · Esc desistir", 14, Color("a8a398"))
	sortear_faixa()
	pintar()

func escrever(pai: Node, texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_shadow_color", Color.BLACK)
	rotulo.add_theme_constant_override("shadow_offset_x", 1)
	rotulo.add_theme_constant_override("shadow_offset_y", 1)
	pai.add_child(rotulo)
	return rotulo

## A faixa nova nunca nasce colada nas pontas, onde o ponteiro só vira.
func sortear_faixa() -> void:
	faixa_inicio = _sorte.randf_range(0.08, 0.92 - faixa_largura)

func na_faixa() -> bool:
	return ponteiro >= faixa_inicio and ponteiro <= faixa_inicio + faixa_largura

func pintar() -> void:
	var marcas := ""
	for i in ACERTOS: marcas += " ●" if i < acertos else " ○"
	_placar.text = titulo + "  " + marcas
	_desenho.queue_redraw()

func desenhar() -> void:
	var area := Rect2(Vector2(0, 14), Vector2(_desenho.size.x, 22))
	_desenho.draw_rect(area, Color("2b2925"))
	_desenho.draw_rect(Rect2(area.position + Vector2(area.size.x * faixa_inicio, 0), Vector2(area.size.x * faixa_largura, area.size.y)), Color("c9a13b"))
	_desenho.draw_rect(area, Color("8c8577"), false, 2.0)
	var x := area.position.x + area.size.x * ponteiro
	_desenho.draw_rect(Rect2(x - 2, area.position.y - 8, 4, area.size.y + 16), Color("f3e6c8"))

func _process(delta: float) -> void:
	_espera = maxf(0.0, _espera - delta)
	if _acabou: return
	ponteiro += _rumo * velocidade * delta
	if ponteiro >= 1.0:
		ponteiro = 1.0
		_rumo = -1.0
	elif ponteiro <= 0.0:
		ponteiro = 0.0
		_rumo = 1.0
	_desenho.queue_redraw()

## Um golpe: acerta dentro da faixa ou estala o cadeado.
func golpear() -> void:
	if _acabou: return
	if not na_faixa():
		encerrar("falhou")
		return
	acertos += 1
	if acertos >= ACERTOS:
		pintar()
		encerrar("abriu")
		return
	faixa_largura *= ENCOLHE
	velocidade *= ACELERA
	sortear_faixa()
	pintar()

func encerrar(resultado: String) -> void:
	if _acabou: return
	_acabou = true
	terminou.emit(resultado)

func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo: return
	get_viewport().set_input_as_handled()
	if _espera > 0.0: return
	match (evento as InputEventKey).physical_keycode:
		KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: golpear()
		KEY_ESCAPE: encerrar("desistiu")
