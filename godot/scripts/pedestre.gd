extends CharacterBody2D

# Pedestre que caminha pela calçada, desvia de obstáculos, às vezes para e conversa.
const SPRITES := preload("res://sprites/pessoas.png")
const QUADRO := 24
## Pedestres ficam numa camada própria: colidem com o mundo, o morador e os carros,
## mas não entre si (duas pessoas na mesma calçada se cruzam em vez de travar).
const CAMADA_PEDESTRES := 8
var pessoa := 0
var calcada_y := 624.0
## Direção do desvio quando algo bloqueia a calçada (+1 = para baixo).
var lado_desvio := 1.0
var x_min := -240.0
var x_max := 1300.0
var sentido := 1.0
var velocidade := 40.0
var parado := false
var _pausa := 0.0
var _desvio := 0.0
var _passo := 0.0
var _travado := 0.0
var _bloqueado := 0.0
var _olhar := Vector2.ZERO
var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("pedestres")
	collision_layer = CAMADA_PEDESTRES
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
	_sprite.frame = pessoa * 4
	add_child(_sprite)
	_virar(Vector2(sentido, 0))

## Para por alguns segundos olhando para `alvo` (usado ao conversar).
func conversar(alvo: Vector2, segundos: float) -> void:
	_pausa = maxf(_pausa, segundos)
	_olhar = alvo

func _physics_process(delta: float) -> void:
	if parado or _pausa > 0:
		_pausa -= delta
		velocity = Vector2.ZERO
		_sprite.frame = pessoa * 4
		if _olhar != Vector2.ZERO:
			_virar(_olhar - global_position)
			if _pausa <= 0: _olhar = Vector2.ZERO
		return
	if (sentido > 0 and position.x > x_max) or (sentido < 0 and position.x < x_min):
		sentido = -sentido
		_pausa = randf_range(0.5, 2.5)
	elif randf() < delta * 0.04:
		_pausa = randf_range(1.0, 4.0)
	# Mão direita: quem vem de frente passa pelo próprio lado, sem se esbarrar.
	var mao := sentido * 7.0 if _alguem_de_frente() else 0.0
	# Volta aos poucos para o meio da calçada depois de desviar.
	_desvio = move_toward(_desvio, mao, delta * 12.0) if _travado <= 0 else _desvio
	_travado -= delta
	var alvo := Vector2(position.x + sentido * 20, calcada_y + _desvio)
	var direcao := (alvo - position).normalized()
	velocity = direcao * velocidade
	var antes := position
	move_and_slide()
	var andou := position.distance_to(antes)
	if andou < velocidade * delta * 0.3:
		# Bloqueado: sai da linha da calçada; se não resolver, dá meia-volta.
		_desvio = clampf(_desvio + lado_desvio * 30 * delta * 4, -26, 26)
		_travado = 0.8
		_bloqueado += delta
		if _bloqueado > 1.5:
			sentido = -sentido
			_bloqueado = 0.0
			_pausa = randf_range(0.3, 1.0)
	else:
		_bloqueado = 0.0
	_passo += andou * 0.16
	_sprite.frame = pessoa * 4 + int(_passo) % 4
	_virar(direcao)

func _alguem_de_frente() -> bool:
	for outro in get_tree().get_nodes_in_group("pedestres"):
		if outro == self or not outro.visible: continue
		var d: Vector2 = outro.global_position - global_position
		if absf(d.y) < 14 and d.x * sentido > 0 and absf(d.x) < 60 and outro.sentido != sentido:
			return true
	return false

func _virar(direcao: Vector2) -> void:
	if direcao.length_squared() > 0.01:
		_sprite.rotation = lerp_angle(_sprite.rotation, direcao.angle() + PI / 2, 0.3)
	queue_redraw()

func _draw() -> void:
	# Sombra fixa no chão, fora do sprite para não girar junto.
	draw_set_transform(Vector2(2, 3), 0, Vector2(1.0, 0.75))
	draw_circle(Vector2.ZERO, 10, Color(0.025, 0.035, 0.025, 0.3))
	draw_set_transform(Vector2.ZERO)
