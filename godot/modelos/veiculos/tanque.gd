extends Node3D
## Carro de combate (inspirado no Leopard 1A5 do EB). Mova o nó pelo jogo e informe a velocidade:
## as rodas giram e as esteiras correm no mesmo ritmo. A torre gira pelo ângulo ou varrendo sozinha.

@export var velocidade := 0.0          ## m/s para a frente (negativo = ré)
@export var giro_torre := 0.0          ## graus
@export var torre_varrendo := false    ## varre a rua de um lado para o outro

var rodas: Array[MeshInstance3D] = []
var raios: Array[float] = []
var esteiras: Array[MeshInstance3D] = []
var torre: Node3D
var deslocamento := 0.0
var t := 0.0

func _ready() -> void:
	for n in find_children("roda_*", "MeshInstance3D", true, false):
		rodas.append(n); raios.append(maxf(0.05, (n as MeshInstance3D).get_aabb().size.y * 0.5))
	for n in find_children("esteira_*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.get_active_material(0)
		if m: mi.set_surface_override_material(0, m.duplicate())
		esteiras.append(mi)
	torre = find_child("torre", true, false)

func _process(delta: float) -> void:
	t += delta
	deslocamento += velocidade * delta
	for i in rodas.size():
		rodas[i].rotate_object_local(Vector3.RIGHT, velocidade * delta / raios[i])
	for e in esteiras:
		var m := e.get_surface_override_material(0)
		if m is StandardMaterial3D: (m as StandardMaterial3D).uv1_offset.y = -deslocamento / 0.5
		elif m is ShaderMaterial: (m as ShaderMaterial).set_shader_parameter("uv_offset", Vector2(0, -deslocamento / 0.5))
	if torre:
		torre.rotation.y = deg_to_rad(giro_torre + (40.0 * sin(t * 0.35) if torre_varrendo else 0.0))
