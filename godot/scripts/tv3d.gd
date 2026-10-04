class_name Tv3D
extends CanvasLayer

# A televisão de tubo da sala. Ligada, o programa ocupa o meio da tela no
# formato de tubo (4:3), com o resto escuro: é o morador sentado na frente dela.
#
# Os programas são as cenas do artefato (res://tv/*.tscn), que já trazem
# cenário, apresentador, arte de emissora e legendas. O que o jogo põe por
# dentro é a notícia do dia, vinda de data/dias.json — por isso a TV vai
# contando o mistério no ritmo dos dias.
#
# Os canais trocam com as setas (ou A e D); E ou Esc desliga.
signal desligou
signal mudou_de_canal(chave: String)

const CANAIS := [
	{"chave": "pronunciamento", "nome": "CADEIA NACIONAL", "cena": "res://tv/pronunciamento.tscn"},
	{"chave": "telejornal", "nome": "JORNAL DA REDE 7", "cena": "res://tv/telejornal.tscn"},
	{"chave": "chuvisco", "nome": "SEM SINAL", "cena": ""},
]
const CHUVISCO := preload("res://shaders/chuvisco.gdshader")
const TUBO := preload("res://shaders/tubo.gdshader")
## A imagem do programa, no formato do tubo.
const LARGURA := 640
const ALTURA := 480
## Quanto tempo o aviso do canal fica na tela.
const AVISO := 2.4

## O mundo preenche antes de ligar: as falas de hoje e o letreiro do rodapé.
var falas_do_dia := {}
var rodape := ""
## Quem cobra a energia. Recebe a chave do canal e diz se dá para assistir.
var cobrar := Callable()

var canal := 0
var _quadro: Control
var _programa: Node
## O nó do programa que está no ar, de onde saem o relógio e as falas.
var _no_ar: Node
var _legenda: Label
var _aviso: Label
var _recado: Label
var _tempo_do_aviso := 0.0
## Carência antes de aceitar tecla, para a tecla que abriu não trocar o canal.
var _espera := 0.18

func _init() -> void:
	layer = 3
	var escuro := ColorRect.new()
	escuro.color = Color(0.02, 0.02, 0.03)
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(escuro)
	_quadro = Control.new()
	_quadro.name = "Quadro"
	_quadro.size = Vector2(LARGURA, ALTURA)
	_quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quadro)
	# A legenda é nossa, desenhada por cima do vidro: a das cenas do artefato
	# fica desligada, senão a mesma fala apareceria duas vezes.
	_legenda = Label.new()
	_legenda.name = "Legenda"
	_legenda.add_theme_font_size_override("font_size", 19)
	_legenda.add_theme_color_override("font_color", Color("f6f1e4"))
	_legenda.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_legenda.add_theme_constant_override("shadow_offset_x", 2)
	_legenda.add_theme_constant_override("shadow_offset_y", 2)
	_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Acima do rodapé do telejornal, para uma coisa não comer a outra.
	_legenda.position = Vector2(28, ALTURA - 160)
	_legenda.size = Vector2(LARGURA - 56, 118)
	_quadro.add_child(_legenda)
	_aviso = escrever(22, Color("ffd35a"))
	_recado = escrever(17, Color(0.95, 0.9, 0.78, 0.7))
	_recado.text = "← →  trocar de canal          E  desligar"

func escrever(tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	rotulo.add_theme_constant_override("shadow_offset_x", 2)
	rotulo.add_theme_constant_override("shadow_offset_y", 2)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(rotulo)
	return rotulo

func _ready() -> void:
	arrumar()
	get_viewport().size_changed.connect(arrumar)
	sintonizar(canal)

## A imagem fica centrada e ampliada em número inteiro de vezes: meio pixel de
## aumento borraria o desenho, que é o contrário do que esta TV quer.
func arrumar() -> void:
	# O jogo desenha numa tela de tamanho fixo que a janela estica (canvas_items);
	# por isso a conta é com a tela, e não com a janela.
	var janela := get_viewport().get_visible_rect().size
	var vezes := maxi(1, mini(int(janela.x / LARGURA), int(janela.y / ALTURA)))
	_quadro.scale = Vector2(vezes, vezes)
	var tamanho := Vector2(LARGURA, ALTURA) * float(vezes)
	_quadro.position = ((janela - tamanho) / 2.0).floor()
	for rotulo: Label in [_aviso, _recado]:
		rotulo.size.x = janela.x
		rotulo.position.x = 0.0
	_aviso.position.y = maxf(8.0, _quadro.position.y - 34.0)
	_recado.position.y = minf(janela.y - 30.0, _quadro.position.y + tamanho.y + 8.0)

## Troca de canal: monta o programa, manda o aviso para a tela e avisa o mundo,
## que é quem cobra a energia.
func sintonizar(qual: int) -> void:
	canal = posmod(qual, CANAIS.size())
	var dados: Dictionary = CANAIS[canal]
	var chave := String(dados.chave)
	var cena := String(dados.cena)
	var pode := true
	if not cena.is_empty() and cobrar.is_valid(): pode = bool(cobrar.call(chave))
	if _programa != null:
		_quadro.remove_child(_programa)
		_programa.queue_free()
		_programa = null
	_no_ar = null
	_legenda.text = ""
	_aviso.text = "CANAL %d · %s" % [canal + 1, dados.nome if pode else "SEM SINAL"]
	_tempo_do_aviso = AVISO
	_aviso.modulate.a = 1.0
	mudou_de_canal.emit(chave)
	if cena.is_empty() or not pode:
		_programa = chiado()
	else:
		_programa = programa(cena, chave)
	_quadro.add_child(_programa)
	# A legenda é a última a ser desenhada: o programa entrou depois dela.
	_quadro.move_child(_legenda, -1)

## O programa do artefato, com a fala do dia posta por dentro.
func programa(caminho: String, chave: String) -> Control:
	var cena: Control = (load(caminho) as PackedScene).instantiate()
	cena.set_anchors_preset(Control.PRESET_FULL_RECT)
	# O artefato desenha em 320 × 240; dividindo por 2 a moldura de 640 × 480
	# cai justo nessa medida.
	(cena as SubViewportContainer).stretch_shrink = 2
	var programa_do_canal: Node = cena.get_node("SubViewport/Programa")
	var falas: Array = falas_do_dia.get(chave, [])
	if not falas.is_empty(): programa_do_canal.falas_de_fora = falas
	if not rodape.is_empty(): programa_do_canal.rodape = rodape
	programa_do_canal.legendas = false
	var vidro := ShaderMaterial.new()
	vidro.shader = TUBO
	cena.material = vidro
	_no_ar = programa_do_canal
	return cena

func chiado() -> Control:
	var tela := ColorRect.new()
	tela.name = "Chuvisco"
	tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = CHUVISCO
	tela.material = material
	return tela

func _process(delta: float) -> void:
	_espera = maxf(0.0, _espera - delta)
	if _no_ar != null: _legenda.text = falando_agora(float(_no_ar.tq))
	if _tempo_do_aviso <= 0.0: return
	_tempo_do_aviso -= delta
	if _tempo_do_aviso < 0.6: _aviso.modulate.a = maxf(0.0, _tempo_do_aviso / 0.6)

## A fala que está no ar neste instante do programa, ou nada entre uma e outra.
func falando_agora(quando: float) -> String:
	if _no_ar == null: return ""
	for fala: Array in _no_ar.P["falas"]:
		if quando >= float(fala[0]) and quando <= float(fala[1]): return String(fala[2])
	return ""

func _unhandled_input(evento: InputEvent) -> void:
	if _espera > 0.0: return
	if not (evento is InputEventKey) or not evento.pressed or evento.echo: return
	match (evento as InputEventKey).physical_keycode:
		KEY_RIGHT, KEY_D: sintonizar(canal + 1)
		KEY_LEFT, KEY_A: sintonizar(canal - 1)
		KEY_E, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER: desligou.emit()
		_: return
	get_viewport().set_input_as_handled()
