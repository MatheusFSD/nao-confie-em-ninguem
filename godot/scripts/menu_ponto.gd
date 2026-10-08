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
var ciclo: Ciclo3D
var _linhas: Array = []
var _detalhe: Label
var _saldo: Label

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
	caixa.offset_left = -210
	caixa.offset_right = 210
	caixa.offset_top = -145
	add_child(caixa)
	var titulo := escrever(caixa, "PONTO DE ÔNIBUS", 19, Color("f0b541"))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_saldo = escrever(caixa, "", 15, Color("c9c4b8"))
	_saldo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for opcao: Dictionary in OPCOES:
		var linha := escrever(caixa, String(opcao.texto), 22, Color("f3e6c8"))
		linha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_linhas.append(linha)
	_detalhe = escrever(caixa, "", 16, Color(1, 1, 1, 0.6))
	_detalhe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	escrever(caixa, "↑↓ escolher · E/Enter confirmar · Esc voltar", 14, Color("a8a398")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pintar()

func configurar(estado: Ciclo3D) -> void:
	ciclo = estado
	pintar()

func custo_da_opcao(indice: int) -> Dictionary:
	match String(OPCOES[indice].chave):
		"trabalho": return Ciclo3D.TRABALHO
		"mercado": return Ciclo3D.MERCADO
	return {"acoes": 0, "energia": 0}

func pode_ir(indice: int) -> bool:
	if ciclo == null or String(OPCOES[indice].chave).is_empty(): return true
	if not ciclo.onibus_funciona(): return false
	if ciclo.modo_deus: return true
	var custo := custo_da_opcao(indice)
	return ciclo.acoes >= int(custo.acoes) and ciclo.energia >= int(custo.energia)

func descricao_opcao(indice: int) -> String:
	var destino := String(OPCOES[indice].chave)
	if destino.is_empty(): return "Sem custo de ações ou energia."
	var custo := custo_da_opcao(indice)
	var tempo := "%d %s" % [custo.acoes, "ação" if int(custo.acoes) == 1 else "ações"]
	var descricao := "%s\n%s · %d de energia" % [OPCOES[indice].abaixo, tempo, custo.energia]
	if ciclo != null and ciclo.modo_deus:
		descricao = String(OPCOES[indice].abaixo) + "\nModo deus: sem custo de ações ou energia"
	descricao += "\nRecebe R$ %d" % Ciclo3D.TRABALHO.paga if destino == "trabalho" else "\nCompras cobradas à parte, no caixa."
	if ciclo != null and not pode_ir(indice):
		if not ciclo.onibus_funciona(): descricao += "\nIndisponível: ônibus fora de serviço."
		elif ciclo.acoes < int(custo.acoes): descricao += "\nIndisponível: faltam ações."
		else: descricao += "\nIndisponível: falta energia."
	return descricao

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
	_saldo.text = "Hoje: %d ações · %d de energia · R$ %d" % [ciclo.acoes, ciclo.energia, ciclo.dinheiro] if ciclo != null else ""
	for i in _linhas.size():
		var marcada := i == escolha
		_linhas[i].text = ("› %s ‹" % OPCOES[i].texto) if marcada else String(OPCOES[i].texto)
		_linhas[i].add_theme_color_override("font_color", (Color("ffd35a") if marcada else Color(0.95, 0.9, 0.78, 0.65)) if pode_ir(i) else Color("9d8982"))
	_detalhe.text = descricao_opcao(escolha)

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
			if pode_ir(escolha): escolheu.emit(String(OPCOES[escolha].chave))
		KEY_ESCAPE:
			escolheu.emit("")
	get_viewport().set_input_as_handled()
