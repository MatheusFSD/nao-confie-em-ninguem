extends Node3D
## Caminhão 4×4 militar com lona. Mova o nó pelo jogo e informe a velocidade: as rodas giram junto.

@export var velocidade := 0.0          ## m/s para a frente (negativo = ré)

var rodas: Array[MeshInstance3D] = []
var raios: Array[float] = []

func _ready() -> void:
	for n in find_children("roda_*", "MeshInstance3D", true, false):
		rodas.append(n); raios.append(maxf(0.05, (n as MeshInstance3D).get_aabb().size.y * 0.5))

func _process(delta: float) -> void:
	for i in rodas.size():
		rodas[i].rotate_object_local(Vector3.RIGHT, velocidade * delta / raios[i])
