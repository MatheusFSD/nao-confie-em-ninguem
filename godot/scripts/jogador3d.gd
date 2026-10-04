extends CharacterBody3D

# Primeira pessoa: WASD anda, mouse olha, Shift corre, E usa o que estiver na
# mira, Esc solta o mouse.
signal interagiu
## A tranca tem tecla própria, como no jogo 2D: T.
signal trancou
## F10: a chave do modo deus, para testar o jogo sem jogar.
signal pediu_modo_deus
## I abre a mochila, onde estão a lanterna e o celular.
signal abriu_a_mochila
## F6 e F7 andam com o relógio do dia, no modo deus.
signal mexeu_na_hora(passo: int)
const VELOCIDADE := 3.2
const CORRIDA := 5.4
const GRAVIDADE := 18.0
const ALTURA_OLHOS := 1.62
## Altura que o corpo vence sozinho: o meio-fio da rua tem 15 cm.
const DEGRAU := 0.3
## Quanto o mouse gira a câmera por pixel.
@export var sensibilidade := 0.0022
var balanco := 0.0
## O próprio jogo guarda se o mouse está preso, em vez de perguntar ao sistema:
## assim o Esc e o clique mandam de verdade, mesmo quando a janela não permite
## prender o cursor (nos testes, por exemplo).
var mouse_preso := true
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
	prender_mouse(true)

func configurar_controles() -> void:
	var teclas := {"andar_frente": [KEY_W, KEY_UP], "andar_tras": [KEY_S, KEY_DOWN], "andar_esquerda": [KEY_A, KEY_LEFT], "andar_direita": [KEY_D, KEY_RIGHT], "correr": [KEY_SHIFT]}
	for acao: String in teclas:
		if not InputMap.has_action(acao): InputMap.add_action(acao)
		for tecla: int in teclas[acao]:
			var evento := InputEventKey.new()
			evento.physical_keycode = tecla
			if not InputMap.action_has_event(acao, evento): InputMap.action_add_event(acao, evento)

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and mouse_preso:
		rotate_y(-evento.relative.x * sensibilidade)
		camera.rotation.x = clampf(camera.rotation.x - evento.relative.y * sensibilidade, -1.4, 1.4)
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_E:
		interagiu.emit()
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_T:
		trancou.emit()
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_F10:
		pediu_modo_deus.emit()
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_I:
		abriu_a_mochila.emit()
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_F6:
		mexeu_na_hora.emit(-1)
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_F7:
		mexeu_na_hora.emit(1)
	elif evento is InputEventKey and evento.pressed and evento.physical_keycode == KEY_ESCAPE:
		prender_mouse(false)
	elif evento is InputEventMouseButton and evento.pressed:
		prender_mouse(true)

## Sobe degraus baixos, como o meio-fio. Se o passo ficou barrado, tenta de novo
## com o corpo erguido; dando certo, assenta na primeira superfície abaixo. Em
## parede de verdade nada acontece, porque erguido o caminho continua fechado.
func vencer_degrau(passo: Vector3, delta: float) -> void:
	var avanco := passo * maxf(0.25, VELOCIDADE * delta * 2.0)
	var aqui := global_transform
	if not test_move(aqui, avanco): return
	var erguido := aqui.translated(Vector3(0, DEGRAU, 0))
	if test_move(erguido, avanco): return
	var pousada := KinematicCollision3D.new()
	var adiante := erguido.translated(avanco)
	if not test_move(adiante, Vector3(0, -DEGRAU * 1.1, 0), pousada): return
	global_position = adiante.origin + pousada.get_travel()
	velocity.y = 0.0

func _physics_process(delta: float) -> void:
	var direcao := Input.get_vector("andar_esquerda", "andar_direita", "andar_frente", "andar_tras")
	var passo := (transform.basis * Vector3(direcao.x, 0, direcao.y)).normalized()
	var velocidade_alvo := CORRIDA if Input.is_action_pressed("correr") else VELOCIDADE
	velocity.x = passo.x * velocidade_alvo
	velocity.z = passo.z * velocidade_alvo
	velocity.y -= GRAVIDADE * delta
	move_and_slide()
	if is_on_floor(): velocity.y = 0.0
	if passo.length() > 0.1: vencer_degrau(passo, delta)
	# Balanço curto da cabeça, como nos jogos da época.
	if passo.length() > 0.1 and is_on_floor():
		balanco += delta * velocidade_alvo * 2.4
		camera.position.y = ALTURA_OLHOS + sin(balanco) * 0.035
	else:
		camera.position.y = lerpf(camera.position.y, ALTURA_OLHOS, 1.0 - exp(-delta * 8.0))

## Prende ou solta o cursor. O estado fica no jogo; o sistema é avisado depois.
func prender_mouse(preso: bool) -> void:
	mouse_preso = preso
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if preso else Input.MOUSE_MODE_VISIBLE
