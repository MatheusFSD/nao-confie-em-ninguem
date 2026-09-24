extends CharacterBody3D

# Primeira pessoa: WASD anda, mouse olha, Shift corre, Esc solta o mouse.
const VELOCIDADE := 3.2
const CORRIDA := 5.4
const GRAVIDADE := 18.0
const ALTURA_OLHOS := 1.62
## Quanto o mouse gira a câmera por pixel.
@export var sensibilidade := 0.0022
var balanco := 0.0
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	configurar_controles()
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.28
	capsula.height = 1.7
	forma.shape = capsula
	forma.position.y = 0.85
	add_child(forma)
	camera.position.y = ALTURA_OLHOS
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func configurar_controles() -> void:
	var teclas := {"andar_frente": [KEY_W, KEY_UP], "andar_tras": [KEY_S, KEY_DOWN], "andar_esquerda": [KEY_A, KEY_LEFT], "andar_direita": [KEY_D, KEY_RIGHT], "correr": [KEY_SHIFT]}
	for acao: String in teclas:
		if not InputMap.has_action(acao): InputMap.add_action(acao)
		for tecla: int in teclas[acao]:
			var evento := InputEventKey.new()
			evento.physical_keycode = tecla
			if not InputMap.action_has_event(acao, evento): InputMap.action_add_event(acao, evento)

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-evento.relative.x * sensibilidade)
		camera.rotation.x = clampf(camera.rotation.x - evento.relative.y * sensibilidade, -1.4, 1.4)
	elif evento is InputEventKey and evento.pressed and evento.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif evento is InputEventMouseButton and evento.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var direcao := Input.get_vector("andar_esquerda", "andar_direita", "andar_frente", "andar_tras")
	var passo := (transform.basis * Vector3(direcao.x, 0, direcao.y)).normalized()
	var velocidade_alvo := CORRIDA if Input.is_action_pressed("correr") else VELOCIDADE
	velocity.x = passo.x * velocidade_alvo
	velocity.z = passo.z * velocidade_alvo
	velocity.y -= GRAVIDADE * delta
	move_and_slide()
	if is_on_floor(): velocity.y = 0.0
	# Balanço curto da cabeça, como nos jogos da época.
	if passo.length() > 0.1 and is_on_floor():
		balanco += delta * velocidade_alvo * 2.4
		camera.position.y = ALTURA_OLHOS + sin(balanco) * 0.035
	else:
		camera.position.y = lerpf(camera.position.y, ALTURA_OLHOS, 1.0 - exp(-delta * 8.0))
