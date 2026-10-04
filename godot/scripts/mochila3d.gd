class_name Mochila3D
extends CanvasLayer

# A mochila: o que o morador carrega e pode usar. Abre com I, as setas escolhem,
# E usa e Esc fecha.
#
# Ela não inventa itens: pergunta ao ciclo o que existe (lanterna comprada,
# celular no bolso) e mostra também o que só serve de conta — comida, água,
# dinheiro — para a pessoa saber onde está sem abrir outra tela.
signal usou(item: String)
signal fechou

var itens: Array = []
var escolha := 0
var _linhas: Array = []
var _detalhe: Label
var _caixa: VBoxContainer

func _init() -> void:
	layer = 3
	var fundo := ColorRect.new()
	fundo.color = Color(0.05, 0.05, 0.07, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	_caixa = VBoxContainer.new()
	_caixa.add_theme_constant_override("separation", 8)
	_caixa.anchor_left = 0.5
	_caixa.anchor_right = 0.5
	_caixa.anchor_top = 0.5
	_caixa.anchor_bottom = 0.5
	_caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	_caixa.offset_left = -200
	_caixa.offset_right = 200
	_caixa.offset_top = -120
	add_child(_caixa)
	var titulo := escrever("MOCHILA", 20, Color("f0b541"))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

## Monta a lista: [{ "chave", "texto", "abaixo" }].
func mostrar(lista: Array) -> void:
	itens = lista
	escolha = 0
	for velha: Label in _linhas:
		_caixa.remove_child(velha)
		velha.queue_free()
	_linhas.clear()
	if _detalhe != null:
		_caixa.remove_child(_detalhe)
		_detalhe.queue_free()
	for item: Dictionary in itens:
		var linha := escrever(String(item.texto), 21, Color("f3e6c8"))
		linha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_linhas.append(linha)
	_detalhe = escrever("", 16, Color(1, 1, 1, 0.6))
	_detalhe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pintar()

func escrever(texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_shadow_color", Color.BLACK)
	rotulo.add_theme_constant_override("shadow_offset_x", 1)
	rotulo.add_theme_constant_override("shadow_offset_y", 1)
	_caixa.add_child(rotulo)
	return rotulo

func pintar() -> void:
	for i in _linhas.size():
		var marcada := i == escolha
		_linhas[i].text = ("› %s ‹" % itens[i].texto) if marcada else String(itens[i].texto)
		_linhas[i].add_theme_color_override("font_color", Color("ffd35a") if marcada else Color(0.95, 0.9, 0.78, 0.6))
	_detalhe.text = String(itens[escolha].get("abaixo", "")) if not itens.is_empty() else "A mochila está vazia."

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
			if not itens.is_empty():
				escolha = (escolha - 1 + itens.size()) % itens.size()
				pintar()
		KEY_DOWN, KEY_S:
			if not itens.is_empty():
				escolha = (escolha + 1) % itens.size()
				pintar()
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			if not itens.is_empty(): usou.emit(String(itens[escolha].chave))
		KEY_I, KEY_ESCAPE:
			fechou.emit()
		_: return
	get_viewport().set_input_as_handled()
