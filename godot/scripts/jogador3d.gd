extends CharacterBody3D

# Primeira pessoa: WASD anda, mouse olha, Shift corre, Ctrl agacha (devagar e
# quieto: os caçadores e o Observador demoram mais a notar), E usa o que estiver
# na mira, Esc solta o mouse.
#
# F5 a F8 ficam de fora de propósito: rodando pelo editor do Godot, são os
# atalhos dele (F8 para o jogo, F7 pausa).
signal interagiu
## A tranca tem tecla própria, como no jogo 2D: T.
signal trancou
## F10: a chave do modo deus, para testar o jogo sem jogar.
signal pediu_modo_deus
## I abre a mochila, onde estão a lanterna e o celular.
signal abriu_a_mochila
signal abriu_o_celular
## Page Down e Page Up andam com o relógio do dia, no modo deus.
signal mexeu_na_hora(passo: int)
## F1 a F4: ver um final (só vale no modo deus).
signal pediu_final(qual: int)
## F9: a mesa de som, com todos os sons do jogo.
signal pediu_mesa_de_som
## Esc: o menu de pausa.
signal pediu_pausa
const VELOCIDADE := 3.2
const CORRIDA := 5.4
## Agachado: devagar, olhos baixos e passos quase sem som.
const AGACHADO := 1.5
const OLHOS_AGACHADO := 1.05
const GRAVIDADE := 18.0
const ALTURA_OLHOS := 1.62
## Altura que o corpo vence sozinho: o meio-fio da rua tem 15 cm.
const DEGRAU := 0.3
## Quanto o mouse gira a câmera por pixel.
@export var sensibilidade := 0.0022
var balanco := 0.0
## Segurando Ctrl. Os caçadores e o Observador leem isto.
var agachado := false
## Altura dos olhos sem o balanço: desce e sobe devagar ao agachar.
var _olhos := ALTURA_OLHOS
## Passos: um a cada tantos metros andados no chão.
var _passos: AudioStreamPlayer
var _andado := 0.0
## O próprio jogo guarda se o mouse está preso, em vez de perguntar ao sistema:
## assim o Esc e o clique mandam de verdade, mesmo quando a janela não permite
## prender o cursor (nos testes, por exemplo).
var mouse_preso := true
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	configurar_controles()
	sensibilidade = float(Configuracoes.carregar().sensibilidade)
	camera.doppler_tracking = Camera3D.DOPPLER_TRACKING_PHYSICS_STEP
	# Cenário = 1, jogador = 2, pedestres = 4, veículos = 32, caçadores = 64.
	collision_layer = 2
	collision_mask = 1 | 4 | 32 | 64
	# Encostar em um veículo não transporta o jogador como numa plataforma.
	platform_floor_layers = 1
	platform_wall_layers = 0
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
	var teclas := {"andar_frente": [KEY_W, KEY_UP], "andar_tras": [KEY_S, KEY_DOWN], "andar_esquerda": [KEY_A, KEY_LEFT], "andar_direita": [KEY_D, KEY_RIGHT], "correr": [KEY_SHIFT], "agachar": [KEY_CTRL]}
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
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_C:
		abriu_o_celular.emit()
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode in [KEY_F1, KEY_F2, KEY_F3, KEY_F4]:
		pediu_final.emit([KEY_F1, KEY_F2, KEY_F3, KEY_F4].find(evento.physical_keycode))
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_F9:
		pediu_mesa_de_som.emit()
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_PAGEDOWN:
		mexeu_na_hora.emit(-1)
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_PAGEUP:
		mexeu_na_hora.emit(1)
	elif evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_ESCAPE:
		prender_mouse(false)
		pediu_pausa.emit()
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
	agachado = Input.is_action_pressed("agachar")
	var velocidade_alvo := AGACHADO if agachado else (CORRIDA if Input.is_action_pressed("correr") else VELOCIDADE)
	_olhos = lerpf(_olhos, OLHOS_AGACHADO if agachado else ALTURA_OLHOS, 1.0 - exp(-delta * 10.0))
	velocity.x = passo.x * velocidade_alvo
	velocity.z = passo.z * velocidade_alvo
	velocity.y -= GRAVIDADE * delta
	move_and_slide()
	if is_on_floor(): velocity.y = 0.0
	if passo.length() > 0.1: vencer_degrau(passo, delta)
	# Balanço curto da cabeça, como nos jogos da época.
	if passo.length() > 0.1 and is_on_floor():
		balanco += delta * velocidade_alvo * 2.4
		camera.position.y = _olhos + sin(balanco) * 0.035
		pisar(Vector2(velocity.x, velocity.z).length() * delta, velocidade_alvo == CORRIDA)
	else:
		camera.position.y = lerpf(camera.position.y, _olhos, 1.0 - exp(-delta * 8.0))

## O chinelo no chão: correndo, passos mais largos e mais altos.
func pisar(metros: float, correndo: bool) -> void:
	_andado += metros
	if _andado < (1.05 if correndo else 0.72): return
	_andado = 0.0
	if _passos == null:
		_passos = AudioStreamPlayer.new()
		_passos.name = "Passos"
		_passos.stream = Sons3D.passo_jogador()
		add_child(_passos)
	_passos.volume_db = -9.0 if correndo else (-24.0 if agachado else -14.0)
	_passos.pitch_scale = randf_range(0.88, 1.12)
	_passos.play()

## Prende ou solta o cursor. O estado fica no jogo; o sistema é avisado depois.
func prender_mouse(preso: bool) -> void:
	mouse_preso = preso
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if preso else Input.MOUSE_MODE_VISIBLE
