extends CharacterBody2D

# A irmã do morador: acompanha o protagonista no dia 0 e vai embora à noite.
# Mesma folha de 8 direções do protagonista (sprites/irma.png).
const SPRITES := preload("res://sprites/irma.png")
const QUADRO := 32
const VELOCIDADE := 96.0
## Distância em que ela para de seguir e fica esperando.
const PERTO := 34.0
enum Modo { PARADA, SEGUINDO, INDO }
var modo: Modo = Modo.PARADA
var alvo: Node2D
var destino := Vector2.ZERO
var _passo := 0.0
var _preso := 0.0
var _angulo := 0.0
var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("irma")
	# Mesma camada dos pedestres: o morador esbarra nela, ela não trava os outros.
	collision_layer = 8
	collision_mask = 1
	z_index = 6
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 7
	forma.shape = circulo
	add_child(forma)
	_sprite = Sprite2D.new()
	_sprite.texture = SPRITES
	_sprite.hframes = 4
	_sprite.vframes = SPRITES.get_height() / QUADRO
	add_child(_sprite)

func seguir(quem: Node2D) -> void:
	alvo = quem
	modo = Modo.SEGUINDO

func ir_para(ponto: Vector2) -> void:
	destino = ponto
	modo = Modo.INDO

func esperar() -> void:
	modo = Modo.PARADA

## Reaparece ao lado de alguém (usada depois das viagens de ônibus).
func aparecer_perto(ponto: Vector2) -> void:
	global_position = ponto + Vector2(-26, 10)
	modulate.a = 1.0
	show()

func ir_embora(saida: Vector2) -> void:
	ir_para(saida)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(self, "modulate:a", 0.0, 1.6)
	tween.tween_callback(hide)

func chegou() -> bool:
	return modo == Modo.INDO and global_position.distance_to(destino) < 18.0

func _physics_process(delta: float) -> void:
	var caminho := Vector2.ZERO
	if modo == Modo.SEGUINDO and is_instance_valid(alvo):
		var distancia := global_position.distance_to(alvo.global_position)
		if distancia > PERTO: caminho = (alvo.global_position - global_position).normalized()
		elif distancia < PERTO * 0.6: caminho = (global_position - alvo.global_position).normalized() * 0.4
	elif modo == Modo.INDO and not chegou():
		caminho = (destino - global_position).normalized()
	velocity = caminho * VELOCIDADE
	var antes := global_position
	move_and_slide()
	var andou := global_position.distance_to(antes)
	# Sem rotas prontas, ela pode encostar numa parede: se travar ou ficar longe demais,
	# reaparece ao lado do morador (como se tivesse dado a volta).
	if modo == Modo.SEGUINDO and is_instance_valid(alvo):
		var distante := global_position.distance_to(alvo.global_position)
		_preso = _preso + delta if caminho != Vector2.ZERO and andou < VELOCIDADE * delta * 0.25 else 0.0
		if distante > 260.0 or _preso > 3.0:
			aparecer_perto(alvo.global_position)
			_preso = 0.0
	_passo += andou * 0.17
	var olhar := caminho
	if olhar == Vector2.ZERO and modo == Modo.SEGUINDO and is_instance_valid(alvo):
		olhar = (alvo.global_position - global_position).normalized()
	if olhar != Vector2.ZERO:
		_angulo = lerp_angle(_angulo, olhar.angle() + PI / 2.0, 1.0 - exp(-delta * 14.0))
	var linha := posmod(roundi(_angulo / (PI / 4)), _sprite.vframes)
	var quadro := posmod(roundi(_passo / (PI / 2)), _sprite.hframes) if andou > 0.2 else 0
	_sprite.frame = linha * _sprite.hframes + quadro
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(2, 3), 0, Vector2(1.0, 0.75))
	draw_circle(Vector2.ZERO, 11, Color(0.025, 0.035, 0.025, 0.3))
	draw_set_transform(Vector2.ZERO)
