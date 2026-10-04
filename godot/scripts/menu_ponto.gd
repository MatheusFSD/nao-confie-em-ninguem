class_name MenuPonto
extends CanvasLayer

# O menu do ponto de ônibus: trabalhar, ir ao mercado ou deixar para depois.
# Desenhado na tela pequena do jogo, com as setas para escolher e E ou Enter
# para confirmar — as mesmas teclas que abrem a porta, para não inventar
# controle novo no meio do caminho.
signal escolheu(destino: String)

const OPCOES := [
	{"chave": "trabalho", "texto": "Ir trabalhar", "abaixo": "Linha 950 · Centro"},
	{"chave": "mercado", "texto": "Ir ao mercado", "abaixo": "Linha 950 · Madureira"},
	{"chave": "", "texto": "Ficar por aqui", "abaixo": ""},
]

var escolha := 0
var _linhas: Array = []
var _detalhe: Label

func _init() -> void:
	layer = 3
	var fundo := ColorRect.new()
	fundo.color = Color(0.05, 0.05, 0.07, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 10)
	caixa.anchor_left = 0.5
	caixa.anchor_right = 0.5
	caixa.anchor_top = 0.5
	caixa.anchor_bottom = 0.5
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	caixa.offset_left = -180
	caixa.offset_right = 180
	caixa.offset_top = -90
	add_child(caixa)
	var titulo := escrever(caixa, "PONTO DE ÔNIBUS", 19, Color("f0b541"))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for opcao: Dictionary in OPCOES:
		var linha := escrever(caixa, String(opcao.texto), 22, Color("f3e6c8"))
		linha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_linhas.append(linha)
	_detalhe = escrever(caixa, "", 16, Color(1, 1, 1, 0.6))
	_detalhe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pintar()

func escrever(pai: Node, texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_shadow_color", Color.BLACK)
	rotulo.add_theme_constant_override("shadow_offset_x", 1)
	rotulo.add_theme_constant_override("shadow_offset_y", 1)
	pai.add_child(rotulo)
	return rotulo

func pintar() -> void:
	for i in _linhas.size():
		var marcada := i == escolha
		_linhas[i].text = ("› %s ‹" % OPCOES[i].texto) if marcada else String(OPCOES[i].texto)
		_linhas[i].add_theme_color_override("font_color", Color("ffd35a") if marcada else Color(0.95, 0.9, 0.78, 0.65))
	_detalhe.text = String(OPCOES[escolha].abaixo)

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
		KEY_UP, KEY_W:
			escolha = (escolha - 1 + OPCOES.size()) % OPCOES.size()
			pintar()
		KEY_DOWN, KEY_S:
			escolha = (escolha + 1) % OPCOES.size()
			pintar()
		KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			escolheu.emit(String(OPCOES[escolha].chave))
		KEY_ESCAPE:
			escolheu.emit("")
	get_viewport().set_input_as_handled()
