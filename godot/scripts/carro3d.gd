class_name Carro3D
extends AnimatableBody3D

# Um carro passando na rua, com os modelos do pacote do artefato
# (res://modelos/carros): hatch, perua e sedã, todos de frente para +Z e com as rodas
# no chão.
#
# Ele anda no eixo X do mundo, numa faixa só, e reaparece na outra ponta quando
# sai do trecho — sempre dentro da névoa, para ninguém ver o pulo.
## Espaço que ele guarda do carro da frente, e o quanto freia e acelera por
## segundo. Sem isto um carro mais rápido entra dentro do outro.
const RESPIRO := 1.8
const FREIO := 14.0
const ACELERACAO := 4.0
const MODELOS := [
	"res://modelos/carros/hatch.glb",
	"res://modelos/carros/perua.glb",
	"res://modelos/carros/seda.glb",
]

## Qual modelo este carro usa. Vazio sorteia um.
var modelo := ""
var resolucao := Vector2(320, 213)
var linha_z := 25.2
var altura_da_pista := -0.15
## Para onde anda: +1 vai para o X crescente.
var sentido := 1.0
var velocidade := 8.0
## Onde reaparece do outro lado — bem além da barreira, lá na rua esticada,
## onde a névoa já comeu tudo.
var limites := Vector2(-120.0, 135.0)
## O quanto ele mede de ponta a ponta, lido do modelo.
var comprimento := 4.0
## A velocidade que ele faria com a pista livre. A de verdade (`velocidade`)
## cai quando tem alguém na frente.
var velocidade_alvo := 8.0

## No engarrafamento a faixa inteira anda colada, em ondas de anda-e-para.
## Cada carro só olha o da frente (`frente`, que nunca muda: ninguém
## ultrapassa); a varredura de verdade só roda perto do jogador. Assim a rua
## aguenta setenta carros.
var no_engarrafamento := false
var frente: Node3D
var jogador: Node3D
const PERTO_DO_JOGADOR := 16.0
## Período (s) e comprimento (rad/m) da onda de anda-e-para, que corre de trás
## pra frente pela fila, como num engarrafamento de verdade.
const ONDA_PERIODO := 9.0
const ONDA_PASSO := 0.08
## No engarrafamento, só parte dos carros acende o farol (setenta luzes
## pesariam no renderizador de compatibilidade).
var com_farol := true
## E só parte tem motor; esses só soam perto de quem joga: cada som 3D tocando
## custa por quadro, e setenta motores somavam mais de 20 ms.
var com_motor := true
const MOTOR_ATE := 30.0
## Longe do jogador (já na névoa), o carro anda a cada tantos quadros.
const LONGE_DO_JOGADOR := 70.0
const QUADROS_LONGE := 3
var _delta_guardado := 0.0

var farol: OmniLight3D
var _motor: AudioStreamPlayer3D
var _rodas: AudioStreamPlayer3D
var _corpo: Node3D
var _volume: BoxShape3D
var _centro := Vector3.ZERO

func _ready() -> void:
	add_to_group("carros3d")
	# O corpo é movido por script: sync_to_physics ligado engasga o jogador
	# quando ele encosta no carro.
	sync_to_physics = false
	# O jogador e os pedestres esbarram no veículo; a varredura abaixo impede
	# que o carro continue avançando para dentro deles.
	collision_layer = 32
	collision_mask = 2 | 4 | 32
	position.y = altura_da_pista
	position.z = linha_z
	# O modelo olha para o seu +Z local; girar põe esse nariz no rumo da faixa.
	rotation.y = PI / 2.0 if sentido > 0.0 else -PI / 2.0
	if modelo.is_empty(): modelo = MODELOS[randi() % MODELOS.size()]
	_corpo = (load(modelo) as PackedScene).instantiate()
	add_child(_corpo)
	# O motor, em laço; carro escondido (dia sem trânsito) fica mudo.
	var motor := AudioStreamPlayer3D.new()
	motor.name = "Motor"
	motor.stream = Sons3D.motor_carro()
	motor.unit_size = 7.0
	motor.max_distance = 50.0
	motor.volume_db = 0.0
	motor.pitch_scale = randf_range(0.85, 1.2)
	# O tom sobe chegando e cai indo embora (Doppler), como na rua de verdade.
	motor.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	add_child(motor)
	motor.play()
	_motor = motor
	var rodas := AudioStreamPlayer3D.new()
	rodas.name = "Pneus"
	rodas.stream = Sons3D.pneu()
	rodas.unit_size = 4.0
	rodas.max_distance = 30.0
	rodas.volume_db = -4.0
	rodas.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	add_child(rodas)
	rodas.play()
	_rodas = rodas
	visibility_changed.connect(func():
		motor.stream_paused = not is_visible_in_tree()
		rodas.stream_paused = not is_visible_in_tree())
	Modelos3D.separar_coladas(_corpo)
	RuaModelo.aplicar_ps1(_corpo, resolucao)
	var caixa := medir(_corpo)
	comprimento = caixa.size.z
	if velocidade_alvo <= 0.0: velocidade_alvo = velocidade
	var forma := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = caixa.size
	_volume = volume
	_centro = caixa.position + caixa.size / 2.0
	forma.shape = volume
	forma.position = _centro
	add_child(forma)
	# O farol só acende de noite, junto com os postes.
	farol = OmniLight3D.new()
	farol.name = "Farol"
	farol.position = Vector3(0.0, 0.55, caixa.end.z - 0.1)
	farol.light_color = Color("fff0c8")
	farol.light_energy = 2.2
	farol.omni_range = 9.0
	farol.light_specular = 0.0
	farol.visible = false
	add_child(farol)

## O tamanho do carro, lido do próprio modelo: cada um dos três é de um jeito.
func medir(no: Node3D) -> AABB:
	var total := AABB()
	var primeiro := true
	for m in no.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null: continue
		var caixa: AABB = mi.mesh.get_aabb()
		caixa.position += mi.position
		total = caixa if primeiro else total.merge(caixa)
		primeiro = false
	if primeiro: return AABB(Vector3(-0.9, 0.0, -2.0), Vector3(1.8, 1.35, 4.0))
	return total

func _physics_process(delta: float) -> void:
	if no_engarrafamento:
		andar_no_engarrafamento(delta)
		return
	# Ninguém entra dentro de ninguém: olha quem está na frente, na mesma faixa,
	# e acerta o passo. Com a frente livre, volta à velocidade dele.
	var folga := espaco_livre(self, comprimento, get_tree().get_nodes_in_group("carros3d"))
	var adiante := maxf(RESPIRO + 6.0, velocidade * velocidade / (2.0 * FREIO) + RESPIRO + 1.0)
	var consulta := consultar_volume(global_transform)
	consulta.motion = Vector3(sentido * adiante, 0.0, 0.0)
	var espaco := get_world_3d().direct_space_state
	var varredura := espaco.cast_motion(consulta)
	folga = minf(folga, varredura[0] * adiante)
	# cast_motion ignora sobreposições iniciais; uma pessoa encostada na
	# carroceria também deve impedir o próximo avanço.
	if not espaco.intersect_shape(consultar_volume(global_transform), 1).is_empty(): folga = 0.0
	var alvo := velocidade_alvo
	if folga < RESPIRO: alvo = 0.0
	elif folga < RESPIRO + 6.0: alvo = velocidade_alvo * (folga - RESPIRO) / 6.0
	velocidade = move_toward(velocidade, alvo, (FREIO if alvo < velocidade else ACELERACAO) * delta)
	# Também limita o passo físico quando alguém entra na faixa de repente.
	# A frenagem sozinha demoraria alguns quadros e atravessaria o personagem.
	var passo := minf(velocidade * delta, maxf(0.0, folga - 0.06))
	if passo < velocidade * delta: velocidade = 0.0
	position.x += sentido * passo
	if sentido > 0.0 and position.x > limites.y or sentido < 0.0 and position.x < limites.x:
		var chegada := global_transform
		chegada.origin.x = limites.x if sentido > 0.0 else limites.y
		if espaco.intersect_shape(consultar_volume(chegada), 1).is_empty():
			global_transform = chegada
		else:
			velocidade = 0.0

func consultar_volume(onde: Transform3D) -> PhysicsShapeQueryParameters3D:
	return consultar_corpo(self, _volume, _centro, onde)

static func consultar_corpo(quem: PhysicsBody3D, volume: Shape3D, centro: Vector3, onde: Transform3D) -> PhysicsShapeQueryParameters3D:
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = volume
	consulta.transform = onde * Transform3D(Basis.IDENTITY, centro)
	consulta.collision_mask = quem.collision_mask
	consulta.exclude = [quem.get_rid()]
	return consulta

## Quantos metros de pista livre há na frente deste veículo até o próximo da
## mesma faixa e do mesmo rumo. Serve para carro e para comboio.
static func espaco_livre(quem: Node3D, meu_comprimento: float, na_rua: Array) -> float:
	var folga := 9999.0
	for outro in na_rua:
		if outro == quem: continue
		var ele := outro as Node3D
		if ele == null or not is_instance_valid(ele): continue
		if absf(ele.position.z - quem.position.z) > 1.6: continue
		if signf(ele.sentido) != signf(quem.sentido): continue
		var adiante := (ele.position.x - quem.position.x) * signf(quem.sentido)
		if adiante <= 0.0: continue
		var dele: float = ele.comprimento if "comprimento" in ele else 4.0
		folga = minf(folga, adiante - (meu_comprimento + dele) / 2.0)
	return folga

## Acende ou apaga o farol. Quem manda é o relógio do mundo.
func acender(ligado: bool) -> void:
	if farol != null: farol.visible = ligado and com_farol

## Entra na fila do engarrafamento atrás de `quem_vai_na_frente`. Pneu
## cantando a 2 km/h não existe; motor, só em parte da fila.
func entrar_no_engarrafamento(quem_vai_na_frente: Node3D, quem_joga: Node3D, motor_ligado: bool, farol_ligado: bool) -> void:
	no_engarrafamento = true
	frente = quem_vai_na_frente
	jogador = quem_joga
	com_farol = farol_ligado
	com_motor = motor_ligado
	if farol != null and not com_farol: farol.visible = false
	if _rodas != null: _rodas.stop()
	if _motor != null: _motor.stop()

## Um passo na fila: segue o da frente (distância medida em volta, porque a
## faixa é um laço) e a onda de anda-e-para.
func andar_no_engarrafamento(delta: float) -> void:
	var distancia := 9999.0
	if jogador != null and is_instance_valid(jogador): distancia = absf(jogador.global_position.x - global_position.x)
	# Motor ligado só perto; longe, o carro anda de vez em quando, com o tempo somado.
	if _motor != null and com_motor and (distancia < MOTOR_ATE) != _motor.playing:
		if _motor.playing: _motor.stop()
		else: _motor.play(randf() * 0.5)
	_delta_guardado += delta
	if distancia > LONGE_DO_JOGADOR and (Engine.get_physics_frames() + get_instance_id()) % QUADROS_LONGE != 0: return
	delta = _delta_guardado
	_delta_guardado = 0.0
	var volta := limites.y - limites.x
	var folga := 9999.0
	if frente != null and is_instance_valid(frente):
		var adiante := fposmod((frente.position.x - position.x) * sentido, volta)
		folga = adiante - (comprimento + float(frente.get("comprimento"))) / 2.0
	# Perto de quem joga, a pista de verdade: gente parada na frente segura o carro.
	if distancia < PERTO_DO_JOGADOR:
		var espaco := get_world_3d().direct_space_state
		var alcance := RESPIRO + 6.0
		var consulta := consultar_volume(global_transform)
		consulta.motion = Vector3(sentido * alcance, 0.0, 0.0)
		folga = minf(folga, espaco.cast_motion(consulta)[0] * alcance)
		if not espaco.intersect_shape(consultar_volume(global_transform), 1).is_empty(): folga = 0.0
	var fase := Time.get_ticks_msec() / 1000.0 * TAU / ONDA_PERIODO + position.x * ONDA_PASSO * sentido
	var alvo := velocidade_alvo * clampf(0.35 + 0.9 * sin(fase), 0.0, 1.0)
	if folga < RESPIRO: alvo = 0.0
	elif folga < RESPIRO + 3.0: alvo = minf(alvo, velocidade_alvo * (folga - RESPIRO) / 3.0)
	velocidade = move_toward(velocidade, alvo, (FREIO if alvo < velocidade else ACELERACAO * 0.5) * delta)
	var passo := minf(velocidade * delta, maxf(0.0, folga - 0.06))
	position.x += sentido * passo
	# A faixa é um laço: quem sai por uma ponta, lá na névoa, volta pela outra.
	if sentido > 0.0 and position.x > limites.y: position.x -= volta
	elif sentido < 0.0 and position.x < limites.x: position.x += volta
