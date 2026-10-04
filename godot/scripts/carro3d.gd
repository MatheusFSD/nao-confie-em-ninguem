class_name Carro3D
extends AnimatableBody3D

# Um carro passando na rua, com os modelos do pacote do artefato
# (res://carros): hatch, perua e sedã, todos de frente para +Z e com as rodas
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
	"res://carros/hatch.glb",
	"res://carros/perua.glb",
	"res://carros/seda.glb",
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

var farol: OmniLight3D
var _corpo: Node3D

func _ready() -> void:
	add_to_group("carros3d")
	# O corpo é movido por script: sync_to_physics ligado engasga o jogador
	# quando ele encosta no carro.
	sync_to_physics = false
	# Fora da camada do morador: um carro que empurra acaba arrastando ele para
	# fora do mundo, e isso é pior do que atravessar um carro.
	collision_layer = 32
	collision_mask = 0
	position.y = altura_da_pista
	position.z = linha_z
	# O modelo olha para o seu +Z local; girar põe esse nariz no rumo da faixa.
	rotation.y = PI / 2.0 if sentido > 0.0 else -PI / 2.0
	if modelo.is_empty(): modelo = MODELOS[randi() % MODELOS.size()]
	_corpo = (load(modelo) as PackedScene).instantiate()
	add_child(_corpo)
	Modelos3D.separar_coladas(_corpo)
	RuaModelo.aplicar_ps1(_corpo, resolucao)
	var caixa := medir(_corpo)
	comprimento = caixa.size.z
	if velocidade_alvo <= 0.0: velocidade_alvo = velocidade
	var forma := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = caixa.size
	forma.shape = volume
	forma.position = caixa.position + caixa.size / 2.0
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
	# Ninguém entra dentro de ninguém: olha quem está na frente, na mesma faixa,
	# e acerta o passo. Com a frente livre, volta à velocidade dele.
	var folga := espaco_livre(self, comprimento, get_tree().get_nodes_in_group("carros3d"))
	var alvo := velocidade_alvo
	if folga < RESPIRO: alvo = 0.0
	elif folga < RESPIRO + 6.0: alvo = velocidade_alvo * (folga - RESPIRO) / 6.0
	velocidade = move_toward(velocidade, alvo, (FREIO if alvo < velocidade else ACELERACAO) * delta)
	position.x += sentido * velocidade * delta
	if sentido > 0.0 and position.x > limites.y: position.x = limites.x
	elif sentido < 0.0 and position.x < limites.x: position.x = limites.y

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
	if farol != null: farol.visible = ligado
