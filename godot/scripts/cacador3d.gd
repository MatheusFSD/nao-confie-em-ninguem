class_name Cacador3D
extends CharacterBody3D

# Cego: contato próximo omnidirecional, sem visão, audição, dano ou combate.
const CENA := "res://modelos/cacador.tscn"
const CAMINHO := preload("res://scripts/caminho_cacador3d.gd")
const PASSO := 1.4
const CORRIDA := 4.2
const RAIO_CORPO := 0.32
const GRAVIDADE := 18.0
@export_range(0.5, 8.0, 0.1) var raio_proximidade := 2.4
@export_range(0.1, 10.0, 0.1) var memoria_proximidade := 2.0
var resolucao := Vector2(320, 213)
var linha_z := 26.0
var limites := Vector2(-44.0, 60.0)
var sentido := 1.0
var area_caminhada := Rect2(-44, 19, 104, 33)
var jogador: CharacterBody3D
var _modelo: Node3D
var _estado := "vagar"
var _guia := CAMINHO.new()
var _sorte := RandomNumberGenerator.new()
var _caminho := PackedVector3Array()
var _destino := Vector3.ZERO
var _ultima_proximidade := Vector3.ZERO
var _sem_contato := 0.0
var _tempo_rota := 0.0
var _pausa := 0.0
var _sem_avanco := 0.0

func _ready() -> void:
	add_to_group("cacadores3d")
	collision_layer = 64
	collision_mask = 1 | 2 | 4 | 32 | 64
	platform_floor_layers = 1
	platform_wall_layers = 0
	floor_snap_length = 0.3
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = RAIO_CORPO
	capsula.height = 1.8
	forma.shape = capsula
	forma.position.y = 0.9
	add_child(forma)
	_modelo = (load(CENA) as PackedScene).instantiate()
	RuaModelo.aplicar_ps1(_modelo, resolucao)
	add_child(_modelo)
	_sorte.randomize()
	_destino = global_position
	_pausa = _sorte.randf_range(0.4, 1.4)
	rotation.y = PI / 2.0 if sentido > 0 else -PI / 2.0

func jogador_disponivel() -> bool:
	return is_instance_valid(jogador) and jogador.is_inside_tree() and jogador.is_visible_in_tree() and jogador.can_process()

func percebe_jogador() -> bool:
	if not jogador_disponivel(): return false
	if global_position.distance_to(jogador.global_position) > raio_proximidade: return false
	# Varredura física do alcance, sem cone nem orientação dos olhos.
	# A parede separando os corpos impede contato através da casa.
	return _guia.alcance_desimpedido(self, jogador.global_position)

func atualizar_percepcao(delta: float) -> void:
	if percebe_jogador():
		if _estado != "perseguir": _tempo_rota = 0.0
		_estado = "perseguir"
		_ultima_proximidade = jogador.global_position
		_sem_contato = 0.0
		_pausa = 0.0
	elif _estado != "vagar":
		_sem_contato += delta
		_estado = "buscar"
		if not jogador_disponivel() or _sem_contato >= memoria_proximidade:
			_estado = "vagar"
			_caminho.clear()
			_pausa = _sorte.randf_range(0.6, 1.6)
			_tempo_rota = 0.0

func escolher_destino() -> void:
	_caminho.clear()
	# Destinos variados sobre piso, dentro do bairro, com caminho alcançável.
	for tentativa in 12:
		var angulo := _sorte.randf_range(-PI, PI)
		var distancia := _sorte.randf_range(2.0, 8.0)
		var ponto := global_position + Vector3(cos(angulo), 0, sin(angulo)) * distancia
		if not _guia.apoiado(self, ponto, area_caminhada): continue
		var rota := _guia.calcular(self, ponto, area_caminhada)
		if rota.is_empty():
			# Uma rota por quadro no máximo: a próxima tentativa fica para o
			# quadro seguinte, em vez de travar o jogo procurando de uma vez.
			_pausa = 0.05
			return
		_destino = rota[-1]
		_caminho = rota
		return
	_pausa = _sorte.randf_range(0.8, 1.6)

func seguir_caminho(delta: float) -> Vector3:
	_tempo_rota -= delta
	if _estado == "vagar":
		_pausa -= delta
		if _pausa > 0.0: return Vector3.ZERO
		if _caminho.is_empty():
			escolher_destino()
			_tempo_rota = 0.6
	else:
		# Ao perder contato usa somente o local lembrado, sem ler posição atual.
		var alvo := _ultima_proximidade
		var para_alvo := alvo - global_position
		para_alvo.y = 0.0
		if para_alvo.length() < 0.9 and _guia.alcance_desimpedido(self, alvo): return Vector3.ZERO
		if _tempo_rota <= 0.0 and (_destino.distance_to(alvo) > 0.65 or _caminho.is_empty() or _sem_avanco > 0.4):
			_destino = alvo
			_caminho = _guia.calcular(self, alvo, area_caminhada)
			_tempo_rota = 0.45
	while not _caminho.is_empty() and Vector2(_caminho[0].x - global_position.x, _caminho[0].z - global_position.z).length() < 0.14:
		_caminho.remove_at(0)
	if _caminho.is_empty():
		if _estado == "vagar": _pausa = _sorte.randf_range(0.8, 2.5)
		return Vector3.ZERO
	# Remove escadas da grade somente onde cápsula e piso permitem.
	for i in range(_caminho.size() - 1, 0, -1):
		if _guia.livre(self, global_position, _caminho[i], area_caminhada):
			for j in i: _caminho.remove_at(0)
			break
	var rumo := _caminho[0] - global_position
	rumo.y = 0.0
	var adiante := global_position + rumo.normalized() * minf(0.18, rumo.length())
	if not _guia.livre(self, global_position, adiante, area_caminhada):
		if _tempo_rota <= 0.0:
			_caminho = _guia.calcular(self, _destino, area_caminhada)
			_tempo_rota = 0.6
			if _estado == "vagar" and _sem_avanco > 1.2: _caminho.clear()
		return Vector3.ZERO
	return rumo.normalized()

func vencer_degrau(passo: Vector3) -> void:
	if not test_move(global_transform, passo): return
	var erguido := global_transform.translated(Vector3.UP * 0.25)
	if test_move(erguido, passo): return
	var pousada := KinematicCollision3D.new()
	var adiante := erguido.translated(passo)
	if not test_move(adiante, Vector3.DOWN * 0.3, pousada): return
	if pousada.get_normal().y < 0.7: return
	global_position = adiante.origin + pousada.get_travel()
	velocity.y = 0.0

func _physics_process(delta: float) -> void:
	atualizar_percepcao(delta)
	var rumo := seguir_caminho(delta)
	var velocidade := CORRIDA if _estado == "perseguir" else PASSO
	var antes := global_position
	velocity = Vector3(rumo.x * velocidade, velocity.y - GRAVIDADE * delta, rumo.z * velocidade)
	if rumo.length_squared() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(rumo.x, rumo.z), 1.0 - exp(-delta * 10.0))
		vencer_degrau(rumo * velocidade * delta)
	move_and_slide()
	if is_on_floor(): velocity.y = 0.0
	var avancou := Vector2(global_position.x - antes.x, global_position.z - antes.z).length()
	_sem_avanco = _sem_avanco + delta if avancou < velocidade * delta * 0.15 else 0.0
	var animacao := "parado" if avancou < velocidade * delta * 0.15 else ("correr" if _estado == "perseguir" else "andar")
	if _modelo != null and "estado" in _modelo and _modelo.estado != animacao:
		_modelo.estado = animacao
