class_name Hud3D
extends CanvasLayer

# A interface das cutscenes: tarjas de cinema em cima e embaixo, nome da tomada,
# relógio e a linha do ônibus. Desenhada fora da tela pequena do jogo, na
# resolução da janela, para o texto sair nítido. Veio do projeto
# do artefato (scripts/hud.gd), enxuta para o que as cenas daqui usam.
var tomada: Label
var relogio: Label
var linha: Label
var dica: Label
var dinheiro: Label
var mensagem: Label
var _quanto_falta := 0.0

func _init() -> void:
	layer = 2
	for lado in [0.0, 1.0]:
		var tarja := ColorRect.new()
		tarja.name = "Tarja"
		tarja.color = Color.BLACK
		tarja.anchor_left = 0.0
		tarja.anchor_right = 1.0
		tarja.anchor_top = lado - (0.125 if lado > 0.0 else 0.0)
		tarja.anchor_bottom = lado + (0.0 if lado > 0.0 else 0.125)
		add_child(tarja)
	tomada = escrever(Vector2(26, 16), 17, Color(1, 1, 1, 0.7))
	relogio = escrever(Vector2(26, 572), 21, Color("f3e6c8"))
	linha = escrever(Vector2(0, 578), 17, Color("f0b541"))
	linha.anchor_left = 1.0
	linha.anchor_right = 1.0
	linha.offset_left = -520
	linha.offset_right = -24
	linha.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dica = escrever(Vector2(0, 16), 16, Color(1, 1, 1, 0.55))
	dica.anchor_left = 1.0
	dica.anchor_right = 1.0
	dica.offset_left = -420
	dica.offset_right = -24
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func escrever(onde: Vector2, tamanho: int, cor: Color) -> Label:
	var texto := Label.new()
	texto.position = onde
	texto.add_theme_font_size_override("font_size", tamanho)
	texto.add_theme_color_override("font_color", cor)
	texto.add_theme_color_override("font_shadow_color", Color.BLACK)
	texto.add_theme_constant_override("shadow_offset_x", 1)
	texto.add_theme_constant_override("shadow_offset_y", 1)
	add_child(texto)
	return texto

## O mercado é jogável, não é cutscene: tira as tarjas de cinema e acende os
## dois rótulos que só ele usa — a carteira e a mensagem rápida.
func virar_jogo() -> void:
	for filho in get_children():
		if filho is ColorRect: (filho as ColorRect).visible = false
	if dinheiro == null:
		# Uma linha abaixo da dica, que também mora no canto de cima à direita.
		dinheiro = escrever(Vector2(0, 46), 18, Color("f3e6c8"))
		dinheiro.anchor_left = 1.0
		dinheiro.anchor_right = 1.0
		dinheiro.offset_left = -420
		dinheiro.offset_right = -24
		dinheiro.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mensagem = escrever(Vector2(0, 100), 20, Color("ffd35a"))
		mensagem.anchor_left = 0.0
		mensagem.anchor_right = 1.0
		mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

## Mensagem que aparece e some sozinha.
func avisar(texto: String) -> void:
	if mensagem == null: return
	mensagem.text = texto
	_quanto_falta = 2.2

func _process(delta: float) -> void:
	if _quanto_falta <= 0.0: return
	_quanto_falta -= delta
	if _quanto_falta <= 0.0 and mensagem != null: mensagem.text = ""
