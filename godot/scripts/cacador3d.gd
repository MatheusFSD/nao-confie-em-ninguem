class_name Cacador3D
extends CharacterBody3D

# O Caçador: o bicho sem cabeça que aparece quando a luz acaba. Ele anda pela
# rua, para, farreja e volta a andar — e os poros no lugar da cabeça brilham no
# escuro, que é a única coisa que se vê dele no breu.
#
# O modelo e as animações são do artefato (modelos/cacador.tscn). Por enquanto
# ele não encosta em ninguém: é presença, não é luta. Quando a caçada entrar de
# verdade, é aqui que ela mora.
const CENA := "res://modelos/cacador.tscn"
## Quanto ele anda e quanto ele corre, em metros por segundo.
const PASSO := 1.4
const CORRIDA := 4.2
## Quanto tempo ele fica parado cheirando o ar, e quanto tempo corre.
const PARADO := Vector2(1.5, 4.0)
const ANDANDO := Vector2(4.0, 9.0)

var resolucao := Vector2(320, 213)
var linha_z := 26.0
var limites := Vector2(-44.0, 60.0)
var sentido := 1.0

var _modelo: Node3D
var _estado := "andar"
var _troca := 0.0

func _ready() -> void:
	add_to_group("cacadores3d")
	# Ele não empurra nem é empurrado: por enquanto é vulto, não obstáculo.
	collision_layer = 64
	collision_mask = 0
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.5
	capsula.height = 1.8
	forma.shape = capsula
	forma.position.y = 0.9
	add_child(forma)
	_modelo = (load(CENA) as PackedScene).instantiate()
	# O corpo entra no estilo do jogo antes de a cena acordar: os poros, que o
	# script dele acende no _ready, continuam brilhando por conta própria.
	RuaModelo.aplicar_ps1(_modelo, resolucao)
	add_child(_modelo)
	position.z = linha_z
	rotation.y = PI / 2.0 if sentido > 0.0 else -PI / 2.0
	escolher_estado("andar")

func escolher_estado(qual: String) -> void:
	_estado = qual
	if _modelo != null and "estado" in _modelo: _modelo.estado = qual
	_troca = randf_range(PARADO.x, PARADO.y) if qual == "parado" else randf_range(ANDANDO.x, ANDANDO.y)

func _physics_process(delta: float) -> void:
	_troca -= delta
	if _troca <= 0.0:
		# Ele alterna entre farejar parado, andar e sair correndo sem motivo.
		var sorte := randf()
		escolher_estado("parado" if sorte < 0.35 else ("correr" if sorte > 0.85 else "andar"))
	var passo := 0.0
	if _estado == "andar": passo = PASSO
	elif _estado == "correr": passo = CORRIDA
	position.x += sentido * passo * delta
	if position.x > limites.y:
		sentido = -1.0
		rotation.y = -PI / 2.0
	elif position.x < limites.x:
		sentido = 1.0
		rotation.y = PI / 2.0
	position.z = linha_z
