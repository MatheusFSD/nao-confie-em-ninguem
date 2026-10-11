class_name Status3D
extends CanvasLayer

# O estado do morador na tela: uma caixa por suprimento guardado, o dinheiro
# em R$, o relógio e o período do dia. Sem retângulo de fundo —
# só os ícones sobre o mundo, como foi pedido.
#
# Os desenhos são os mesmos do jogo 2D (ui/hud/icones.webp, quatro peças de
# 12 × 12 px), ampliados sem suavização para continuarem duros.
const ICONES := preload("res://ui/hud/icones.webp")
const PECA := 12
const COMIDA := 0
const AGUA := 1
const ENERGIA := 2
const ACAO := 3
const SUPRIMENTOS := 4
const MENSAGEM := 5
const FRAQUEZA := 6
const BORDAS := preload("res://shaders/bordas_fraqueza.gdshader")
## Tamanho do ícone na tela, em pixels da janela.
const TAMANHO := 26
## Acima disto a fileira vira "ícone × n", para não atravessar a tela.
const MAXIMO := 8

var suprimentos := 0
var dinheiro := 0
var _fila_suprimentos: HBoxContainer
var _dinheiro: Label
var _relogio: Label
var _mensagens: Control
var _novas: Label
var _piscar := 0.0
var _fraqueza: HBoxContainer
var _texto_fraqueza: Label
var _bordas: ColorRect
var _forca_alvo := 0.0
var _forca := 0.0
var _tempo := 0.0
var _periodo: Label
## Aviso de que o jogo está no modo de teste.
var _deus: Label
## O que fazer agora, no dia 0 com a irmã. Vazio, some.
var _objetivo: Label
var hora := "08:00"
var periodo := "Manhã"

func _init() -> void:
	layer = 1
	var linha := HBoxContainer.new()
	linha.name = "Status"
	linha.add_theme_constant_override("separation", 22)
	linha.position = Vector2(24, 18)
	add_child(linha)
	_fila_suprimentos = fileira(linha)
	_dinheiro = escrever(linha)
	_deus = escrever(linha)
	_deus.add_theme_color_override("font_color", Color("ff6b5a"))
	_deus.visible = false
	# Bordas vermelhas por baixo de tudo do HUD: aparecem com a fraqueza.
	_bordas = ColorRect.new()
	_bordas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bordas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = BORDAS
	_bordas.material = material
	_bordas.visible = false
	add_child(_bordas)
	move_child(_bordas, 0)
	# Estômago com o nível da fraqueza: só aparece quando você está fraco.
	_fraqueza = fileira(linha)
	_fraqueza.add_child(desenhar(FRAQUEZA))
	_texto_fraqueza = escrever(_fraqueza)
	_fraqueza.visible = false
	# Envelope com as não lidas: só aparece quando tem alguma.
	# O envelope, com o número das não lidas numa bolinha vermelha por cima.
	_mensagens = Control.new()
	_mensagens.custom_minimum_size = Vector2(TAMANHO + 8, TAMANHO)
	linha.add_child(_mensagens)
	_mensagens.add_child(desenhar(MENSAGEM))
	var bola := Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("d42a20")
	estilo.set_corner_radius_all(9)
	estilo.border_color = Color(0, 0, 0, 0.6)
	estilo.set_border_width_all(1)
	bola.add_theme_stylebox_override("panel", estilo)
	bola.position = Vector2(TAMANHO - 9, -7)
	bola.size = Vector2(18, 18)
	_mensagens.add_child(bola)
	_novas = Label.new()
	_novas.add_theme_font_size_override("font_size", 12)
	_novas.add_theme_color_override("font_color", Color.WHITE)
	_novas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_novas.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_novas.set_anchors_preset(Control.PRESET_FULL_RECT)
	bola.add_child(_novas)
	_mensagens.visible = false
	# À direita, o relógio e o período.
	_relogio = escrever(linha)
	_periodo = escrever(linha)
	_objetivo = Label.new()
	_objetivo.name = "Objetivo"
	_objetivo.position = Vector2(26, 58)
	_objetivo.add_theme_font_size_override("font_size", 16)
	_objetivo.add_theme_color_override("font_color", Color("ffe7a3"))
	_objetivo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_objetivo.add_theme_constant_override("shadow_offset_x", 2)
	_objetivo.add_theme_constant_override("shadow_offset_y", 2)
	_objetivo.visible = false
	add_child(_objetivo)

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

## Troca os valores mostrados. É por aqui que o jogo avisa que a despensa
## mudou, que gastou energia ou recebeu.
func mostrar(novos_suprimentos: int, novo_dinheiro: int, nova_hora := "", novo_periodo := "") -> void:
	suprimentos = novos_suprimentos
	dinheiro = novo_dinheiro
	if not nova_hora.is_empty(): hora = nova_hora
	if not novo_periodo.is_empty(): periodo = novo_periodo
	_relogio.text = hora
	_periodo.text = periodo
	encher(_fila_suprimentos, SUPRIMENTOS, suprimentos)
	_dinheiro.text = "R$ %d" % dinheiro

## Quantas mensagens não lidas. Se o número subiu, o envelope pisca.
func mostrar_objetivo(texto: String) -> void:
	_objetivo.text = "▸ " + texto
	_objetivo.visible = not texto.is_empty()

func objetivo() -> String:
	return _objetivo.text.trim_prefix("▸ ") if _objetivo.visible else ""

func mostrar_mensagens(novas: int) -> void:
	var subiu := novas > int(_novas.text.trim_suffix("+")) if _mensagens.visible else novas > 0
	_mensagens.visible = novas > 0
	_novas.text = str(novas) if novas < 10 else "9+"
	if subiu: _piscar = 3.0

## Fraqueza 0 some tudo; 1 "fraco" e bordas leves; 2 "muito fraco", em
## vermelho, com as bordas fechando a tela.
func mostrar_fraqueza(nivel: int) -> void:
	_fraqueza.visible = nivel > 0
	_texto_fraqueza.text = "fraco" if nivel <= 1 else "muito fraco"
	_texto_fraqueza.add_theme_color_override("font_color", Color("f3e6c8") if nivel <= 1 else Color("ff6b5a"))
	_forca_alvo = [0.0, 0.7, 1.0][clampi(nivel, 0, 2)]

func _process(delta: float) -> void:
	_tempo += delta
	_forca = move_toward(_forca, _forca_alvo, delta * 0.6)
	if _bordas != null:
		_bordas.visible = _forca > 0.01
		(_bordas.material as ShaderMaterial).set_shader_parameter("forca", _forca)
		(_bordas.material as ShaderMaterial).set_shader_parameter("tempo", _tempo)
	if _piscar <= 0.0 or _mensagens == null: return
	_piscar = maxf(0.0, _piscar - delta)
	_mensagens.modulate.a = 1.0 if _piscar == 0.0 or fmod(_piscar, 0.5) > 0.2 else 0.25

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
