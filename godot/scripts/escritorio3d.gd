class_name Escritorio3D
extends Node3D

# Um dia no call center, portado do projeto do artefato (escritorio.gd):
# colegas digitando, o supervisor andando no corredor, o relógio correndo das
# 9h às 18h e o protagonista afundando na cadeira conforme o dia passa.
signal terminou

const CORTE := 6.0
## O supervisor anda de ponta a ponta do corredor.
const CORREDOR := 6.0
const PASSO := 1.4

var resolucao := Vector2(320, 213)
## Onde pendurar a interface: fora da tela pequena, para o texto sair nítido.
var camada_da_interface: Node
var hud: Hud3D
var _tempo := 0.0
var _camera: Camera3D
var _colegas: Array = []
var _protagonista: Skeleton3D
var _supervisor: Node3D
var _ponteiro_hora: Node3D
var _ponteiro_minuto: Node3D
var _onde := -CORREDOR
var _rumo := 1.0
var _tomadas := [
	{"nome": "CALL CENTER", "de": func(t): return Vector3(7.4 - t * 0.35, 2.35, 5.6), "para": func(_t): return Vector3(0.5, 0.9, -0.6)},
	{"nome": "BAIA", "de": func(t): return Vector3(1.25 - t * 0.02, 1.55, 0.95), "para": func(_t): return Vector3(0.75, 0.95, -0.8)},
	{"nome": "CORREDOR", "de": func(_t): return Vector3(-7.4, 1.25, 1.3), "para": func(_t): return Vector3(0, 1.1, 1.2)},
	{"nome": "O RELÓGIO", "de": func(t): return Vector3(-5.6 + t * 0.08, 1.8, -0.4), "para": func(_t): return Vector3(-8.0, 2.1, -1.5)},
]

func _ready() -> void:
	var cena: Node3D = load("res://modelos/cutscene/escritorio.glb").instantiate()
	add_child(cena)
	# Sem o conserto de faces coladas: estes modelos são grandes e passam em
	# seis segundos de câmera, longe demais para valer o custo.
	RuaModelo.aplicar_ps1(cena, resolucao)
	Ceu3D.criar(self, Color("6d8fc0"), Color("e9e3d0"), Color("dcd8c8"), 0.004, Vector3(0.3, 0.9, 0.4))
	for no in cena.find_children("Colega_*", "", true, false):
		_colegas.append([Pose3D.esqueleto(no), randf() * TAU])
	_protagonista = Pose3D.esqueleto(cena.find_child("Protagonista", true, false))
	_ponteiro_hora = cena.find_child("PonteiroHora", true, false)
	_ponteiro_minuto = cena.find_child("PonteiroMinuto", true, false)
	# O supervisor é o mesmo modelo de gente da rua, em silhueta, andando.
	_supervisor = load("res://modelos/marquinhos_ps1.glb").instantiate()
	add_child(_supervisor)
	RuaModelo.silhueta(_supervisor, Color("2a2330"))
	var animacao: AnimationPlayer = _supervisor.find_child("AnimationPlayer", true, false)
	if animacao:
		for nome in animacao.get_animation_list():
			animacao.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
		animacao.play("andar")
	_camera = Camera3D.new()
	_camera.near = 0.1
	add_child(_camera)
	_camera.make_current()
	hud = Hud3D.new()
	(camada_da_interface if camada_da_interface != null else self).add_child(hud)
	hud.linha.text = "CALL CENTER · CENTRO"
	hud.dica.text = "Enter: pular"

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_accept"): terminou.emit()

func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= CORTE * 4:
		set_process(false)
		terminou.emit()
		return
	# O expediente inteiro, das 9 às 18, espremido nos 24 segundos da cena.
	var hora := 9.0 + fmod(_tempo, 24.0) / 24.0 * 9.0
	if _ponteiro_minuto: _ponteiro_minuto.rotation.z = -fmod(hora, 1.0) * TAU
	if _ponteiro_hora: _ponteiro_hora.rotation.z = -(hora / 12.0) * TAU
	for colega: Array in _colegas:
		var fase: float = colega[1]
		Pose3D.girar(colega[0], "forearm_L", Vector3(-52 + sin(_tempo * 17.0 + fase) * 5, 0, 0))
		Pose3D.girar(colega[0], "forearm_R", Vector3(-52 + sin(_tempo * 19.0 + fase * 2.0) * 5, 0, 0))
		Pose3D.girar(colega[0], "head", Vector3(6 + sin(_tempo * 0.7 + fase) * 4, sin(_tempo * 0.3 + fase) * 10, 0))
	var cansaco: float = minf(1.0, (hora - 9.0) / 9.0)
	Pose3D.girar(_protagonista, "forearm_L", Vector3(-52 + sin(_tempo * 16.0) * 6, 0, 0))
	Pose3D.girar(_protagonista, "forearm_R", Vector3(-52 + sin(_tempo * 18.5) * 6, 0, 0))
	Pose3D.girar(_protagonista, "spine", Vector3(8 + cansaco * 10, 0, 0))
	Pose3D.girar(_protagonista, "head", Vector3(6 + cansaco * 12 + sin(_tempo * 0.9) * 2, -35.0 if sin(_tempo * 0.25) > 0.85 else 0.0, 0))
	_onde += _rumo * PASSO * delta
	if _onde > CORREDOR:
		_onde = CORREDOR
		_rumo = -1.0
	if _onde < -CORREDOR:
		_onde = -CORREDOR
		_rumo = 1.0
	_supervisor.position = Vector3(_onde, 0, 1.25)
	_supervisor.rotation.y = PI / 2.0 if _rumo > 0.0 else -PI / 2.0
	var tomada: Dictionary = _tomadas[int(_tempo / CORTE) % _tomadas.size()]
	var t := fmod(_tempo, CORTE)
	_camera.fov = 50.0
	_camera.look_at_from_position(tomada.de.call(t), tomada.para.call(t), Vector3.UP)
	hud.tomada.text = tomada.nome
	hud.relogio.text = "%02d:%02d" % [int(hora), int(fmod(hora, 1.0) * 60.0)]

## A interface está pendurada fora desta cena, então ela não some junto: aqui
## ela é recolhida quando a cena sai.
func _exit_tree() -> void:
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
		hud = null
