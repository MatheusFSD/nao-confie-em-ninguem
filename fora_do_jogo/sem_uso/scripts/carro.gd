extends AnimatableBody2D

# Carro visto de cima que anda numa faixa e freia diante de pessoas ou outro carro.
const CORES := ["8c4a3c", "5d7a8c", "c9c2a8", "3d4a44", "a69a7a", "6b5a7a", "2c3a4a", "9a8f3a"]
const TAMANHO := Vector2(52, 24)
var sentido := 1.0
var velocidade_max := 110.0
var velocidade := 110.0
var cor := Color("8c4a3c")
var _consulta := PhysicsShapeQueryParameters2D.new()
var _farol: PointLight2D

func _ready() -> void:
	add_to_group("carros")
	add_to_group("reage_a_noite")
	# Faróis iluminam o asfalto à frente quando escurece (sem sombra, para ficar leve).
	_farol = PointLight2D.new()
	_farol.texture = preload("res://scripts/luz.gd").textura_radial()
	_farol.texture_scale = 0.55
	_farol.position = Vector2(TAMANHO.x / 2 + 40, 0)
	_farol.color = Color(1.0, 0.92, 0.7)
	_farol.enabled = false
	add_child(_farol)
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 0
	z_index = 5
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = TAMANHO
	forma.shape = rect
	add_child(forma)
	var frente := RectangleShape2D.new()
	frente.size = Vector2(46, 18)
	_consulta.shape = frente
	_consulta.collision_mask = 1 | 8
	_consulta.exclude = [get_rid()]
	sortear()

func sortear() -> void:
	cor = Color(CORES.pick_random())
	velocidade_max = randf_range(80, 140)
	velocidade = velocidade_max
	rotation = 0.0 if sentido > 0 else PI
	queue_redraw()

func aplicar_noite(noite: float) -> void:
	var forca := smoothstep(0.45, 0.9, noite)
	_farol.enabled = forca > 0.01
	_farol.energy = forca * 0.9

func obstaculo_a_frente() -> bool:
	_consulta.transform = Transform2D(0, global_position + Vector2(sentido * (TAMANHO.x / 2 + 26), 0))
	for hit in get_world_2d().direct_space_state.intersect_shape(_consulta, 6):
		if hit.collider is CharacterBody2D or (hit.collider as Node).is_in_group("carros"):
			return true
	return false

func _physics_process(delta: float) -> void:
	var alvo := 0.0 if obstaculo_a_frente() else velocidade_max
	velocidade = move_toward(velocidade, alvo, delta * (420.0 if alvo < velocidade else 90.0))
	position.x += sentido * velocidade * delta

func _draw() -> void:
	var h := TAMANHO / 2
	# Faróis acesos na noite, sombra, carroceria, vidros e lanternas.
	draw_colored_polygon(PackedVector2Array([Vector2(h.x, -8), Vector2(h.x + 70, -22), Vector2(h.x + 70, 22), Vector2(h.x, 8)]), Color(0.95, 0.85, 0.55, 0.07))
	draw_rect(Rect2(-h + Vector2(3, 4), TAMANHO), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(-h.x + 3, -h.y, TAMANHO.x - 6, TAMANHO.y), cor)
	draw_rect(Rect2(-h.x, -h.y + 3, TAMANHO.x, TAMANHO.y - 6), cor)
	for canto in [Vector2(-h.x + 3, -h.y + 3), Vector2(h.x - 3, -h.y + 3), Vector2(-h.x + 3, h.y - 3), Vector2(h.x - 3, h.y - 3)]:
		draw_circle(canto, 3, cor)
	draw_rect(Rect2(8, -h.y + 2, 16, TAMANHO.y - 4), cor.lightened(0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(1, -9), Vector2(8, -10), Vector2(8, 10), Vector2(1, 9)]), Color("1f2a2a"))
	draw_rect(Rect2(-13, -9, 14, 18), cor.darkened(0.12))
	draw_rect(Rect2(-19, -8, 6, 16), Color("1f2a2a"))
	draw_line(Vector2(-12, -8), Vector2(0, -8), cor.lightened(0.2), 1)
	draw_rect(Rect2(5, -h.y - 2, 3, 2), cor.darkened(0.3))
	draw_rect(Rect2(5, h.y, 3, 2), cor.darkened(0.3))
	draw_rect(Rect2(h.x - 2, -9, 2, 4), Color("f4e7b0"))
	draw_rect(Rect2(h.x - 2, 5, 2, 4), Color("f4e7b0"))
	draw_rect(Rect2(-h.x, -9, 2, 4), Color("b0392e"))
	draw_rect(Rect2(-h.x, 5, 2, 4), Color("b0392e"))
