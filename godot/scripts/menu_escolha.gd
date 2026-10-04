class_name MenuEscolha
extends VBoxContainer

# Respostas dentro da caixa de conversa. O mundo e o retrato continuam à vista.
signal escolheu(chave: String)

var opcoes: Array = []
var escolha := 0
var _botoes: Array[Button] = []
var _numeros: Array[Label] = []
var _textos: Array[Label] = []
var _aviso: Label
var _lista: VBoxContainer
var _rolagem: ScrollContainer
var _espera := 0.18
var _confirmada := false
var altura_maxima := 280.0:
	set(valor):
		altura_maxima = maxf(80.0, valor)
		if _rolagem != null: _ajustar_altura()

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	var separador := HSeparator.new()
	var risco := StyleBoxLine.new()
	risco.color = Color("39443f")
	risco.thickness = 1
	separador.add_theme_stylebox_override("separator", risco)
	add_child(separador)
	var rotulo := escrever("Sua resposta", 12, Color("a6b09e"))
	add_child(rotulo)
	_aviso = escrever("", 13, Color("edb99a"))
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.hide()
	add_child(_aviso)
	_rolagem = ScrollContainer.new()
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_rolagem)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 5)
	_rolagem.add_child(_lista)
	_lista.minimum_size_changed.connect(_ajustar_altura)

func escrever(texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rotulo

## [{chave, texto, abaixo}]. O primeiro argumento é um aviso opcional de custo.
func perguntar(aviso: String, lista: Array) -> void:
	opcoes = lista
	_aviso.text = aviso
	_aviso.visible = not aviso.is_empty()
	for i in opcoes.size():
		var opcao: Dictionary = opcoes[i]
		var botao := Button.new()
		botao.name = "Resposta%d" % (i + 1)
		botao.custom_minimum_size.y = 44
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		botao.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		botao.pressed.connect(_confirmar.bind(i))
		botao.mouse_entered.connect(_selecionar.bind(i, false))
		botao.focus_entered.connect(_selecionar.bind(i, false))
		_lista.add_child(botao)
		_botoes.append(botao)
		var linha := HBoxContainer.new()
		linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		linha.offset_left = 14
		linha.offset_right = -14
		linha.offset_top = 8
		linha.offset_bottom = -8
		linha.add_theme_constant_override("separation", 10)
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		botao.add_child(linha)
		var numero := escrever(str(i + 1), 13, Color("8c978b"))
		numero.custom_minimum_size.x = 16
		numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		linha.add_child(numero)
		_numeros.append(numero)
		var conteudo := VBoxContainer.new()
		conteudo.add_theme_constant_override("separation", 2)
		conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_child(conteudo)
		var texto := escrever(String(opcao.texto), 17, Color("e6e0cf"))
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		conteudo.add_child(texto)
		_textos.append(texto)
		var detalhe := String(opcao.get("abaixo", ""))
		if not detalhe.is_empty():
			var custo := escrever(detalhe, 12, Color("aaa48c"))
			custo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			conteudo.add_child(custo)
		linha.minimum_size_changed.connect(func():
			botao.custom_minimum_size.y = maxf(44.0, linha.get_combined_minimum_size().y + 16.0))
	pintar()
	call_deferred("_focar_primeira")

func _focar_primeira() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if not _botoes.is_empty(): _botoes[0].grab_focus()
	_ajustar_altura()

func _ajustar_altura() -> void:
	_rolagem.custom_minimum_size.y = minf(altura_maxima, _lista.get_combined_minimum_size().y)

func estilo(marcado: bool, pressionado := false) -> StyleBoxFlat:
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("303024") if pressionado else (Color("282a22") if marcado else Color("151d1c"))
	fundo.border_color = Color("8f7950") if marcado else Color("2b3732")
	fundo.set_border_width_all(1)
	fundo.border_width_left = 3 if marcado else 1
	fundo.set_corner_radius_all(3)
	return fundo

func pintar() -> void:
	for i in _botoes.size():
		var marcada := i == escolha
		_botoes[i].add_theme_stylebox_override("normal", estilo(marcada))
		_botoes[i].add_theme_stylebox_override("hover", estilo(true))
		_botoes[i].add_theme_stylebox_override("pressed", estilo(true, true))
		_textos[i].add_theme_color_override("font_color", Color("fff0c8") if marcada else Color("d6d9cc"))
		_numeros[i].add_theme_color_override("font_color", Color("dfbe79") if marcada else Color("849184"))

func _selecionar(indice: int, focar: bool) -> void:
	if _confirmada or indice < 0 or indice >= opcoes.size(): return
	escolha = indice
	pintar()
	if focar:
		_botoes[indice].grab_focus()
		_rolagem.ensure_control_visible(_botoes[indice])

func _confirmar(indice: int) -> void:
	if _confirmada or _espera > 0.0 or indice < 0 or indice >= opcoes.size(): return
	_confirmada = true
	escolheu.emit(String(opcoes[indice].chave))

func _process(delta: float) -> void:
	_espera = maxf(0.0, _espera - delta)

func _input(evento: InputEvent) -> void:
	if _confirmada or not is_visible_in_tree() or opcoes.is_empty(): return
	if not (evento is InputEventKey) or not evento.pressed or evento.echo: return
	var tecla := (evento as InputEventKey).physical_keycode
	if tecla == 0: tecla = (evento as InputEventKey).keycode
	if tecla not in [KEY_UP, KEY_W, KEY_DOWN, KEY_S, KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE] and not (tecla >= KEY_1 and tecla <= KEY_9): return
	# Consome a tecla que abriu a conversa, inclusive antes do tempo de carência.
	get_viewport().set_input_as_handled()
	if _espera > 0.0: return
	match tecla:
		KEY_UP, KEY_W: _selecionar((escolha - 1 + opcoes.size()) % opcoes.size(), true)
		KEY_DOWN, KEY_S: _selecionar((escolha + 1) % opcoes.size(), true)
		KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _confirmar(escolha)
		KEY_ESCAPE:
			_confirmada = true
			escolheu.emit("")
		_:
			var indice := tecla - KEY_1
			if indice < opcoes.size(): _confirmar(indice)
