class_name Helicoptero3D
extends Node3D

# Helicóptero do exército cruzando o céu do bairro. Enquanto a cidade queima,
# eles passam de vez em quando por cima da rua: é o barulho da guerra chegando
# perto sem precisar descer.
#
# O modelo é o mesmo que acompanha a criatura (res://monstro/helicoptero.glb),
# de frente para o próprio −Z, com os rotores em nós separados.
const MODELO := preload("res://monstro/helicoptero.glb")
## A que altura passam, e quanto do bairro cada passagem cobre.
const ALTURA := Vector2(28.0, 54.0)
const TRECHO := 320.0

## O rumo do voo, em radianos no plano (0 é o +X).
var rumo := 0.0
var altura := 55.0
var velocidade := 24.0
var centro := Vector3.ZERO
## De onde ele começa a travessia, de 0 a 1.
var fase := 0.0
var resolucao := Vector2(320, 213)

var _rotor: Node3D
var _cauda: Node3D
var _andado := 0.0

func _ready() -> void:
	add_to_group("helicopteros3d")
	var corpo: Node3D = MODELO.instantiate()
	add_child(corpo)
	RuaModelo.aplicar_ps1(corpo, resolucao)
	_rotor = corpo.find_child("rotor", true, false)
	_cauda = corpo.find_child("rotor_cauda", true, false)
	_andado = fase * TRECHO
	# O nariz do modelo fica no +Z (a cauda vai até −10,8 m); o giro põe esse
	# nariz no rumo do voo. Com a conta errada ele voava de ré.
	var para_onde := Vector3(cos(rumo), 0.0, sin(rumo))
	rotation.y = atan2(para_onde.x, para_onde.z)
	posicionar()

func posicionar() -> void:
	var para_onde := Vector3(cos(rumo), 0.0, sin(rumo))
	position = centro + para_onde * (_andado - TRECHO / 2.0) + Vector3(0.0, altura, 0.0)
	# Uma inclinação de quem está com pressa.
	rotation.x = -0.12
	rotation.z = sin(_andado * 0.01) * 0.1

func _process(delta: float) -> void:
	_andado += velocidade * delta
	if _andado > TRECHO: _andado = 0.0
	posicionar()
	if _rotor != null: _rotor.rotation.y += delta * 42.0
	if _cauda != null: _cauda.rotation.x += delta * 56.0
