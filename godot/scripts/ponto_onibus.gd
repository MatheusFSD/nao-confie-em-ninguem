@tool
extends Node2D

# Abrigo de ônibus visto de cima. Coloque o nó no meio da calçada.
# No jogo, E perto do abrigo abre as opções de ir trabalhar ou ir ao mercado.
## Distância, em pixels, entre o abrigo e a faixa pintada no asfalto.
@export var distancia_faixa := 40.0:
	set(value):
		distancia_faixa = value
		if _faixa: _faixa.queue_redraw()
const LARGURA := 72.0
const PROFUNDIDADE := 22.0
var _faixa: Node2D

func _ready() -> void:
	add_to_group("ponto_onibus")
	# A cobertura fica acima de quem espera; a faixa fica no chão, sob os carros.
	z_index = 7
	_faixa = Node2D.new()
	_faixa.z_as_relative = false
	_faixa.z_index = 1
	_faixa.draw.connect(_desenhar_faixa)
	add_child(_faixa)
	if Engine.is_editor_hint(): return
	# Só os dois pés do abrigo e o poste da placa bloqueiam a passagem.
	var corpo := StaticBody2D.new()
	for p in [Vector2(-LARGURA / 2 + 4, -PROFUNDIDADE / 2 + 3), Vector2(LARGURA / 2 - 4, -PROFUNDIDADE / 2 + 3), Vector2(LARGURA / 2 + 10, 6)]:
		var forma := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(6, 6)
		forma.shape = rect
		forma.position = p
		corpo.add_child(forma)
	add_child(corpo)

## Área onde o jogador pode interagir, em coordenadas de `referencia`.
func area_de_espera(referencia: Node2D) -> Rect2:
	var tamanho := Vector2(LARGURA + 8, PROFUNDIDADE + 8)
	return Rect2(referencia.to_local(global_position) - tamanho / 2, tamanho)

func _desenhar_faixa() -> void:
	# Faixa amarela de parada no asfalto.
	var faixa := Rect2(-LARGURA / 2 - 12, distancia_faixa, LARGURA + 24, 34)
	_faixa.draw_rect(faixa, Color(0.85, 0.7, 0.25, 0.55), false, 2)
	for x in range(int(faixa.position.x) + 6, int(faixa.end.x) - 4, 10):
		_faixa.draw_line(Vector2(x, faixa.position.y + 2), Vector2(x + 8, faixa.end.y - 2), Color(0.85, 0.7, 0.25, 0.3), 1)

func _draw() -> void:
	var abrigo := Rect2(-LARGURA / 2, -PROFUNDIDADE / 2, LARGURA, PROFUNDIDADE)
	# Sombra, banco aparecendo pela borda e cobertura de policarbonato.
	draw_rect(Rect2(abrigo.position + Vector2(4, 5), abrigo.size), Color(0, 0, 0, 0.32))
	draw_rect(Rect2(abrigo.position.x + 6, abrigo.position.y + 2, LARGURA - 12, 5), Color("6b4f36"))
	draw_rect(abrigo, Color("35403e"))
	draw_rect(abrigo.grow(-2), Color("58706b"))
	for x in range(int(abrigo.position.x) + 8, int(abrigo.end.x) - 2, 12):
		draw_line(Vector2(x, abrigo.position.y + 2), Vector2(x, abrigo.end.y - 2), Color("41524f"), 2)
	draw_line(abrigo.position + Vector2(2, 3), Vector2(abrigo.end.x - 2, abrigo.position.y + 3), Color("8aa39c"), 1)
	# Poste com placa azul e pictograma de ônibus.
	var poste := Vector2(LARGURA / 2 + 10, 6)
	draw_circle(poste + Vector2(2, 3), 3, Color(0, 0, 0, 0.3))
	draw_circle(poste, 3, Color("2a2f2c"))
	var placa := Rect2(poste + Vector2(-8, -16), Vector2(16, 10))
	draw_rect(placa, Color("f2efe2"))
	draw_rect(placa.grow(-1), Color("2f5d8a"))
	draw_rect(Rect2(placa.position + Vector2(3, 3), Vector2(10, 4)), Color("f2efe2"))
	draw_rect(Rect2(placa.position + Vector2(4, 4), Vector2(2, 1)), Color("2f5d8a"))
	draw_rect(Rect2(placa.position + Vector2(8, 4), Vector2(2, 1)), Color("2f5d8a"))
