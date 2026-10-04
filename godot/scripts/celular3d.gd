class_name Celular3D
extends CanvasLayer

# O celular: um tijolo de teclas, visor verde e nada mais. Não tem internet,
# não procura nada, não abre nenhuma página — é de propósito. O que ele faz é
# receber mensagens, e é por elas que a irmã e os vizinhos falam com você.
#
# Setas andam pela caixa de entrada, E abre e fecha a mensagem, Esc guarda o
# aparelho no bolso.
signal guardou

const FONTE := "res://tv/PixelifySans.ttf"
## Medidas do aparelho, em pixels da tela do jogo.
const CORPO := Vector2(300, 470)
const VISOR := Vector2(236, 170)
## As cores do visor de cristal líquido e da carcaça.
const TELA := Color("9ead6a")
const TINTA := Color("1f2a14")
const CARCACA := Color("2b3340")
const TECLA := Color("3f4a5c")

## Preenchidos por quem abre o aparelho.
var caixa: Array = []
var sinal := 3
var bateria := 4

var escolha := 0
var aberta := -1
var _visor: VBoxContainer
var _titulo: Label
var _linhas: Array = []
var _texto: Label
var _rodape: Label
var _fonte: Font

func _init() -> void:
	layer = 3
	_fonte = load(FONTE) if ResourceLoader.exists(FONTE) else ThemeDB.fallback_font
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.03, 0.04, 0.8)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var corpo := Panel.new()
	corpo.name = "Corpo"
	corpo.custom_minimum_size = CORPO
	corpo.size = CORPO
	corpo.anchor_left = 0.5
	corpo.anchor_right = 0.5
	corpo.anchor_top = 0.5
	corpo.anchor_bottom = 0.5
	corpo.offset_left = -CORPO.x / 2.0
	corpo.offset_right = CORPO.x / 2.0
	corpo.offset_top = -CORPO.y / 2.0
	corpo.offset_bottom = CORPO.y / 2.0
	corpo.add_theme_stylebox_override("panel", caixa_de_cor(CARCACA, 14, Color(0.1, 0.12, 0.15)))
	add_child(corpo)
	# O visor, encaixado em cima.
	var vidro := Panel.new()
	vidro.custom_minimum_size = VISOR
	vidro.position = Vector2((CORPO.x - VISOR.x) / 2.0, 26)
	vidro.size = VISOR
	vidro.add_theme_stylebox_override("panel", caixa_de_cor(TELA, 4, Color(0.12, 0.15, 0.08)))
	corpo.add_child(vidro)
	_visor = VBoxContainer.new()
	_visor.position = Vector2(8, 6)
	_visor.custom_minimum_size = VISOR - Vector2(16, 12)
	_visor.size = VISOR - Vector2(16, 12)
	_visor.add_theme_constant_override("separation", 2)
	vidro.add_child(_visor)
	_titulo = escrever(_visor, 13)
	_texto = escrever(_visor, 13)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_texto.visible = false
	_rodape = escrever(_visor, 11)
	_rodape.modulate.a = 0.75
	# O teclado, só de enfeite: este aparelho não digita nada.
	var teclado := GridContainer.new()
	teclado.columns = 3
	teclado.position = Vector2(42, VISOR.y + 56)
	teclado.add_theme_constant_override("h_separation", 10)
	teclado.add_theme_constant_override("v_separation", 8)
	corpo.add_child(teclado)
	for i in 12:
		var tecla := Panel.new()
		tecla.custom_minimum_size = Vector2(62, 30)
		tecla.add_theme_stylebox_override("panel", caixa_de_cor(TECLA, 6, Color(0.12, 0.14, 0.18)))
		teclado.add_child(tecla)

func caixa_de_cor(cor: Color, canto: int, borda: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.border_color = borda
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(canto)
	return estilo

func escrever(pai: Node, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.add_theme_font_override("font", _fonte)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", TINTA)
	pai.add_child(rotulo)
	return rotulo

## Liga o aparelho com a caixa de entrada de hoje.
func ligar(mensagens: Array, nao_lidas: int) -> void:
	caixa = mensagens
	escolha = 0
	aberta = -1
	_titulo.text = "%s  %s   %d nova(s)" % ["▮".repeat(sinal), "▰".repeat(bateria), nao_lidas]
	montar_lista()

func montar_lista() -> void:
	for velha: Label in _linhas:
		_visor.remove_child(velha)
		velha.queue_free()
	_linhas.clear()
	_texto.visible = false
	if caixa.is_empty():
		var vazio := escrever(_visor, 13)
		vazio.text = "Nenhuma mensagem."
		_visor.move_child(vazio, 1)
		_linhas.append(vazio)
	for i in mini(caixa.size(), 6):
		var m: Dictionary = caixa[i]
		var linha := escrever(_visor, 13)
		linha.clip_text = true
		_visor.move_child(linha, 1 + i)
		_linhas.append(linha)
	pintar()

func pintar() -> void:
	for i in _linhas.size():
		if i >= caixa.size(): continue
		var m: Dictionary = caixa[i]
		var marca := "›" if i == escolha else " "
		var nova := "*" if not bool(m.get("lida", false)) else " "
		_linhas[i].text = "%s%s%s: %s" % [marca, nova, String(m["de"]), String(m["texto"]).left(16)]
		_linhas[i].modulate.a = 1.0 if i == escolha else 0.75
	_rodape.text = "↑↓ escolher   E ler   Esc guardar" if aberta < 0 else "E voltar"

## Abre a mensagem escolhida no visor.
func abrir() -> void:
	if caixa.is_empty(): return
	aberta = escolha
	var m: Dictionary = caixa[aberta]
	for linha: Label in _linhas: linha.visible = false
	_texto.visible = true
	_texto.text = "%s:\n\n%s" % [String(m["de"]), String(m["texto"])]
	_rodape.text = "E voltar"

func fechar_mensagem() -> void:
	aberta = -1
	for linha: Label in _linhas: linha.visible = true
	_texto.visible = false
	pintar()

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
			if aberta < 0 and not caixa.is_empty():
				escolha = (escolha - 1 + caixa.size()) % caixa.size()
				pintar()
		KEY_DOWN, KEY_S:
			if aberta < 0 and not caixa.is_empty():
				escolha = (escolha + 1) % caixa.size()
				pintar()
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			if aberta < 0: abrir()
			else: fechar_mensagem()
		KEY_ESCAPE:
			guardou.emit()
		_: return
	get_viewport().set_input_as_handled()
