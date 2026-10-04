class_name Status3D
extends CanvasLayer

# O estado do morador na tela: um ícone por unidade de comida e de água, o raio
# da energia com o número ao lado e o dinheiro em R$. Sem retângulo de fundo —
# só os ícones sobre o mundo, como foi pedido.
#
# Os desenhos são os mesmos do jogo 2D (ui/hud/icones.png, quatro peças de
# 12 × 12 px), ampliados sem suavização para continuarem duros.
const ICONES := preload("res://ui/hud/icones.png")
const PECA := 12
const COMIDA := 0
const AGUA := 1
const ENERGIA := 2
const ACAO := 3
## Tamanho do ícone na tela, em pixels da janela.
const TAMANHO := 26
## Acima disto a fileira vira "ícone × n", para não atravessar a tela.
const MAXIMO := 8

var comida := 0
var agua := 0
var energia := 0
var dinheiro := 0
var _fila_comida: HBoxContainer
var _fila_agua: HBoxContainer
var _energia: Label
var _dinheiro: Label
var _fila_acoes: HBoxContainer
var _periodo: Label
## Aviso de que o jogo está no modo de teste.
var _deus: Label
var acoes := 4
var periodo := "Manhã"

func _init() -> void:
	layer = 1
	var linha := HBoxContainer.new()
	linha.name = "Status"
	linha.add_theme_constant_override("separation", 22)
	linha.position = Vector2(24, 18)
	add_child(linha)
	_fila_comida = fileira(linha)
	_fila_agua = fileira(linha)
	var caixa_energia := fileira(linha)
	caixa_energia.add_child(desenhar(ENERGIA))
	_energia = escrever(caixa_energia)
	_dinheiro = escrever(linha)
	_deus = escrever(linha)
	_deus.add_theme_color_override("font_color", Color("ff6b5a"))
	_deus.visible = false
	# À direita, as ampulhetas do que ainda dá para fazer hoje e o período.
	_fila_acoes = fileira(linha)
	_periodo = escrever(linha)

func fileira(pai: Node) -> HBoxContainer:
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 3)
	pai.add_child(caixa)
	return caixa

func escrever(pai: Node) -> Label:
	var rotulo := Label.new()
	rotulo.add_theme_font_size_override("font_size", 20)
	rotulo.add_theme_color_override("font_color", Color("f3e6c8"))
	rotulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	rotulo.add_theme_constant_override("shadow_offset_x", 2)
	rotulo.add_theme_constant_override("shadow_offset_y", 2)
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pai.add_child(rotulo)
	return rotulo

## Um ícone da folha, recortado e ampliado sem suavização.
func desenhar(qual: int) -> TextureRect:
	var recorte := AtlasTexture.new()
	recorte.atlas = ICONES
	recorte.region = Rect2(qual * PECA, 0, PECA, PECA)
	var imagem := TextureRect.new()
	imagem.texture = recorte
	imagem.custom_minimum_size = Vector2(TAMANHO, TAMANHO)
	imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return imagem

## Troca os valores mostrados. É por aqui que o jogo avisa que comeu, bebeu,
## gastou energia ou recebeu.
func mostrar(nova_comida: int, nova_agua: int, nova_energia: int, novo_dinheiro: int, novas_acoes := -1, novo_periodo := "") -> void:
	comida = nova_comida
	agua = nova_agua
	energia = nova_energia
	dinheiro = novo_dinheiro
	if novas_acoes >= 0: acoes = novas_acoes
	if not novo_periodo.is_empty(): periodo = novo_periodo
	encher(_fila_acoes, ACAO, acoes)
	_periodo.text = periodo
	encher(_fila_comida, COMIDA, comida)
	encher(_fila_agua, AGUA, agua)
	_energia.text = str(energia)
	_dinheiro.text = "R$ %d" % dinheiro

## Mostra ou esconde o aviso do modo deus.
func avisar_modo_deus(ligado: bool) -> void:
	_deus.text = "MODO DEUS"
	_deus.visible = ligado

func encher(fila: HBoxContainer, qual: int, quantos: int) -> void:
	for velho in fila.get_children():
		fila.remove_child(velho)
		velho.queue_free()
	if quantos <= 0:
		# Vazio não some: fica um ícone apagado, senão a fileira some da tela e
		# o jogador não sabe que aquilo existe.
		var apagado := desenhar(qual)
		apagado.modulate = Color(1, 1, 1, 0.28)
		fila.add_child(apagado)
		return
	if quantos > MAXIMO:
		fila.add_child(desenhar(qual))
		var conta := escrever(fila)
		conta.text = "× %d" % quantos
		return
	for i in quantos: fila.add_child(desenhar(qual))
