extends CharacterBody2D

const SPEED := 91.0
var facing := Vector2.UP
var stride := 0.0
var drawing_angle := 0.0
@onready var camera: Camera2D = $Camera2D
# Folha em sprites/protagonista.png: colunas = quadros de caminhada, linhas = 8 direções
# (cima e depois horário, de 45° em 45°). Troque a textura no nó Sprite do Morador.
@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	collider.shape = circle
	add_child(collider)
	# Esbarra também nos pedestres (camada 8), que não colidem entre si.
	collision_mask = 1 | 8
	z_index = 6

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	velocity = direction * SPEED
	move_and_slide()
	if direction.length_squared() > 0.0:
		facing = direction.normalized()
		stride += get_position_delta().length() * 0.17
	else:
		# Parado: volta na hora ao quadro em pé (não termina a passada).
		stride = 0.0
	drawing_angle = lerp_angle(drawing_angle, facing.angle() + PI / 2.0, 1.0 - exp(-delta * 17.0))
	camera.position = camera.position.lerp(facing * 13.0, 1.0 - exp(-delta * 3.0))
	# Direção mais próxima entre as 8 linhas; quadro pela fase da passada.
	var row := posmod(roundi(drawing_angle / (PI / 4)), sprite.vframes)
	var walk := posmod(roundi(stride / (PI / 2)), sprite.hframes)
	sprite.frame = row * sprite.hframes + walk

func _draw() -> void:
	# Sombra no chão; o corpo é o sprite.
	draw_set_transform(Vector2(2, 3), 0, Vector2(1.0, 0.75))
	draw_circle(Vector2.ZERO, 12, Color(0.025, 0.035, 0.025, 0.33))
	draw_set_transform(Vector2.ZERO)
