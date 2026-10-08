class_name Militar3D
extends AnimatableBody3D

# Comboio do Exército passando na rua no dia do ataque: o carro de combate
# abrindo caminho e os caminhões de tropa atrás. Os modelos são os do artefato
# (modelos/tanque.tscn e modelos/caminhao.tscn), que já sabem girar roda,
# esteira e torre — basta dizer a eles a velocidade.
#
# Andam como os carros civis: numa faixa só, guardando distância de quem está
# na frente, e reaparecendo na outra ponta da rua esticada.
enum Tipo { TANQUE, CAMINHAO }

const CENAS := {
	Tipo.TANQUE: "res://modelos/tanque.tscn",
	Tipo.CAMINHAO: "res://modelos/caminhao.tscn",
}

## Preenchidos por quem cria.
var tipo := Tipo.CAMINHAO
var resolucao := Vector2(320, 213)
var linha_z := 25.2
var altura_da_pista := -0.15
var sentido := 1.0
var velocidade := 5.0
var limites := Vector2(-120.0, 135.0)
## Medidas e passo, como nos carros: o comboio também anda em fila.
var comprimento := 7.0
var velocidade_alvo := 5.0

var _modelo: Node3D
var _volume: BoxShape3D
var _centro := Vector3.ZERO

func _ready() -> void:
	add_to_group("militares3d")
	add_to_group("carros3d")
	sync_to_physics = false
	# Usa as mesmas colisões e a frenagem dos carros civis.
	collision_layer = 32
	collision_mask = 2 | 4 | 32
	position.y = altura_da_pista
	position.z = linha_z
	# A frente destes modelos é o +Z, como a dos carros.
	rotation.y = PI / 2.0 if sentido > 0.0 else -PI / 2.0
	_modelo = (load(String(CENAS[tipo])) as PackedScene).instantiate()
	add_child(_modelo)
	RuaModelo.aplicar_ps1(_modelo, resolucao)
	# A torre varre a rua enquanto o comboio passa.
	if tipo == Tipo.TANQUE and "torre_varrendo" in _modelo: _modelo.torre_varrendo = true
	var caixa := medir(_modelo)
	comprimento = caixa.size.z
	if velocidade_alvo <= 0.0: velocidade_alvo = velocidade
	var forma := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(caixa.size.x, caixa.size.y, caixa.size.z)
	_volume = volume
	_centro = caixa.position + caixa.size / 2.0
	forma.shape = volume
	forma.position = _centro
	add_child(forma)

## O tamanho do modelo, lido dele mesmo.
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
	if primeiro: return AABB(Vector3(-1.5, 0.0, -3.5), Vector3(3.0, 2.9, 7.0))
	return total

func _physics_process(delta: float) -> void:
	# O comboio também guarda distância: blindado na frente, caminhões atrás.
	var folga := Carro3D.espaco_livre(self, comprimento, get_tree().get_nodes_in_group("carros3d"))
	var adiante := maxf(Carro3D.RESPIRO + 10.0, velocidade * velocidade / (2.0 * Carro3D.FREIO) + Carro3D.RESPIRO + 2.0)
	var espaco := get_world_3d().direct_space_state
	var consulta := Carro3D.consultar_corpo(self, _volume, _centro, global_transform)
	consulta.motion = Vector3(sentido * adiante, 0.0, 0.0)
	folga = minf(folga, espaco.cast_motion(consulta)[0] * adiante)
	if not espaco.intersect_shape(Carro3D.consultar_corpo(self, _volume, _centro, global_transform), 1).is_empty(): folga = 0.0
	var alvo := velocidade_alvo
	if folga < Carro3D.RESPIRO + 1.0: alvo = 0.0
	elif folga < Carro3D.RESPIRO + 8.0: alvo = velocidade_alvo * (folga - Carro3D.RESPIRO - 1.0) / 7.0
	velocidade = move_toward(velocidade, alvo, (Carro3D.FREIO if alvo < velocidade else Carro3D.ACELERACAO) * delta)
	var passo := minf(velocidade * delta, maxf(0.0, folga - 0.06))
	if passo < velocidade * delta: velocidade = 0.0
	position.x += sentido * passo
	# O modelo gira roda e esteira conforme o que anda de verdade.
	if _modelo != null and "velocidade" in _modelo: _modelo.velocidade = velocidade
	if sentido > 0.0 and position.x > limites.y or sentido < 0.0 and position.x < limites.x:
		var chegada := global_transform
		chegada.origin.x = limites.x if sentido > 0.0 else limites.y
		if espaco.intersect_shape(Carro3D.consultar_corpo(self, _volume, _centro, chegada), 1).is_empty():
			global_transform = chegada
		else:
			velocidade = 0.0

## Os faróis do comboio acompanham a noite, como os dos carros.
func acender(_ligado: bool) -> void:
	pass
