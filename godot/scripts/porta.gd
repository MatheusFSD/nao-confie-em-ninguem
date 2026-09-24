@tool
extends Node2D

# Porta ou portão num vão de parede de 16 px. Coloque o nó no CENTRO do vão.
# No jogo: E abre/fecha, T tranca/destranca (só com a porta fechada).
enum Tipo { PORTA, PORTAO }
@export var tipo: Tipo = Tipo.PORTA:
	set(value): tipo = value; queue_redraw()
## Largura do vão em pixels (32 = 2 células da grade de 16 px).
@export var largura := 32:
	set(value): largura = value; queue_redraw()
## Vão numa parede vertical (porta vista de lado no mapa).
@export var vertical := false:
	set(value): vertical = value; queue_redraw()
## -1 abre para cima/esquerda; 1 abre para baixo/direita.
@export_enum("Cima/Esquerda:-1", "Baixo/Direita:1") var abre_para := -1:
	set(value): abre_para = value; queue_redraw()
## Dobradiça no começo do vão (esquerda/topo). Desmarque para o fim. Portões usam as duas pontas.
@export var dobradica_no_inicio := true:
	set(value): dobradica_no_inicio = value; queue_redraw()
@export var aberta := false:
	set(value): aberta = value; _abertura = 1.0 if value else 0.0; _atualizar_colisao(); queue_redraw()
@export var trancada := false:
	set(value): trancada = value; queue_redraw()
## Dá para a rua ou para o quintal: se ficar sem tranca à noite, alguém entra.
@export var da_para_fora := false

const ESPESSURA := 16.0
var _abertura := 0.0
var _corpo: StaticBody2D
var _forma: CollisionShape2D
var _oclusor: LightOccluder2D

func _ready() -> void:
	add_to_group("portas")
	z_index = 1
	if Engine.is_editor_hint(): return
	_corpo = StaticBody2D.new()
	_forma = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(largura, ESPESSURA)
	_forma.shape = rect
	_forma.rotation = PI / 2 if vertical else 0.0
	_corpo.add_child(_forma)
	add_child(_corpo)
	# Porta fechada segura a luz do cômodo; o portão de grade deixa passar.
	if tipo == Tipo.PORTA:
		_oclusor = LightOccluder2D.new()
		var poligono := OccluderPolygon2D.new()
		var metade := Vector2(largura, ESPESSURA) / 2
		poligono.polygon = PackedVector2Array([-metade, Vector2(metade.x, -metade.y), metade, Vector2(-metade.x, metade.y)])
		_oclusor.occluder = poligono
		_oclusor.rotation = PI / 2 if vertical else 0.0
		add_child(_oclusor)
	_atualizar_colisao()

func _process(delta: float) -> void:
	var alvo := 1.0 if aberta else 0.0
	if not is_equal_approx(_abertura, alvo):
		_abertura = move_toward(_abertura, alvo, delta * 4.0)
		queue_redraw()

## Retângulo do vão em coordenadas de `referencia` (usado pela área de interação).
func area_do_vao(referencia: Node2D) -> Rect2:
	var tamanho := Vector2(ESPESSURA, largura) if vertical else Vector2(largura, ESPESSURA)
	return Rect2(referencia.to_local(global_position) - tamanho / 2, tamanho)

func descricao() -> String:
	var nome := "portão" if tipo == Tipo.PORTAO else "porta"
	if trancada: return "%s · T — destrancar" % ("Portão trancado" if tipo == Tipo.PORTAO else "Porta trancada")
	if aberta: return "E — Fechar %s" % nome
	return "E — Abrir %s · T — trancar" % nome

func alternar() -> String:
	if trancada: return "Está trancad%s. Pressione T para destrancar." % ("o" if tipo == Tipo.PORTAO else "a")
	if aberta:
		if _vao_ocupado(): return "Tem algo no caminho. Não dá para fechar %s." % ("o portão" if tipo == Tipo.PORTAO else "a porta")
		aberta = false
		return "Você fechou %s." % ("o portão" if tipo == Tipo.PORTAO else "a porta")
	aberta = true
	return "Você abriu %s." % ("o portão" if tipo == Tipo.PORTAO else "a porta")

func alternar_tranca() -> String:
	var artigo := "o portão" if tipo == Tipo.PORTAO else "a porta"
	if aberta: return "Feche %s antes de trancar." % artigo
	trancada = not trancada
	return ("Você trancou %s." if trancada else "Você destrancou %s.") % artigo

func _atualizar_colisao() -> void:
	if _forma: _forma.set_deferred("disabled", aberta)
	if _oclusor: _oclusor.visible = not aberta

func _vao_ocupado() -> bool:
	var consulta := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(largura, ESPESSURA)
	consulta.shape = rect
	consulta.transform = Transform2D(PI / 2 if vertical else 0.0, global_position)
	consulta.collision_mask = 1 | 2 | 8
	for hit in get_world_2d().direct_space_state.intersect_shape(consulta, 8):
		if hit.collider is CharacterBody2D: return true
	return false

func _draw() -> void:
	# Desenha no eixo horizontal; paredes verticais giram 90°.
	draw_set_transform(Vector2.ZERO, PI / 2 if vertical else 0.0)
	# Em parede vertical, o lado "local" invertido mantém Cima/Esquerda = -1.
	var lado := float(-abre_para if vertical else abre_para)
	var angulo := _abertura * PI / 2
	var metade := largura / 2.0
	if tipo == Tipo.PORTAO:
		for ponta in [-1.0, 1.0]:
			var dobradica := Vector2(ponta * metade, 0)
			var folha := metade
			var fim := dobradica + Vector2(-ponta * cos(angulo), lado * sin(angulo)) * folha
			_arco(dobradica, folha, -ponta, lado, angulo)
			_folha(dobradica, fim, 4.0, Color("5f6a61"), Color("8d978a"))
			for i in range(1, 6):
				var p := dobradica.lerp(fim, i / 6.0)
				draw_circle(p, 1.2, Color("2a302b"))
	else:
		var inicio := -1.0 if dobradica_no_inicio else 1.0
		var dobradica := Vector2(inicio * metade, 0)
		var fim := dobradica + Vector2(-inicio * cos(angulo), lado * sin(angulo)) * largura
		_arco(dobradica, largura, -inicio, lado, angulo)
		_folha(dobradica, fim, 4.0, Color("6d4c33"), Color("94704c"))
		# Maçaneta perto da ponta livre.
		draw_circle(dobradica.lerp(fim, 0.82), 1.3, Color("c9a54a"))
	if trancada:
		# Ferrolho vermelho sobre o batente do lado da maçaneta.
		var ponta_livre := Vector2(metade if dobradica_no_inicio or tipo == Tipo.PORTAO else -metade, 0)
		if tipo == Tipo.PORTAO: ponta_livre = Vector2.ZERO
		draw_rect(Rect2(ponta_livre + Vector2(-3, -6), Vector2(6, 12)), Color("b04a3a"))
		draw_rect(Rect2(ponta_livre + Vector2(-1, -2), Vector2(2, 4)), Color("f0d98a"))
	draw_set_transform(Vector2.ZERO)

func _folha(a: Vector2, b: Vector2, espessura: float, cor: Color, brilho: Color) -> void:
	draw_line(a, b, Color("1b1410"), espessura + 2)
	draw_line(a, b, cor, espessura)
	draw_line(a, b, brilho, 1)

func _arco(dobradica: Vector2, raio: float, sentido_x: float, lado: float, angulo: float) -> void:
	if angulo < 0.05: return
	var pontos := PackedVector2Array()
	for i in range(13):
		var t := angulo * i / 12.0
		pontos.append(dobradica + Vector2(sentido_x * cos(t), lado * sin(t)) * raio)
	draw_polyline(pontos, Color(0.1, 0.11, 0.1, 0.55), 1)
