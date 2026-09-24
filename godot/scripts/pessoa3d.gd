extends CharacterBody3D

# Pessoa low poly no estilo PS1: caixas simples, poucas faces, pernas e braços
# que giram na caminhada. O mesmo modelo serve para os pedestres e para a irmã.
const PS1 := preload("res://shaders/ps1.gdshader")
const VELOCIDADE := 1.25
## Linha da calçada (eixo Z) e intervalo que ela percorre no eixo X.
var linha_z := 19.5
var limites := Vector2(-6.0, 38.0)
var sentido := 1.0
var parada := false
var cor_roupa := Color("4f6f8f")
var cor_pele := Color("c69a6c")
var cor_calca := Color("39414a")
var _passo := 0.0
var _coxa_esquerda: MeshInstance3D
var _coxa_direita: MeshInstance3D
var _braco_esquerdo: MeshInstance3D
var _braco_direito: MeshInstance3D

func _ready() -> void:
	add_to_group("pessoas3d")
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.25
	capsula.height = 1.6
	forma.shape = capsula
	forma.position.y = 0.8
	add_child(forma)
	collision_layer = 4
	collision_mask = 1
	montar()

func material_ps1() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1
	return material

## Uma peça do corpo: caixa com cor por vértice, já com o pivô no topo (ombro/quadril).
func peca(tamanho: Vector3, cor: Color, pivo_no_topo := false) -> MeshInstance3D:
	var malha := MalhaLowPoly.new()
	var origem := Vector3(-tamanho.x / 2.0, -tamanho.y if pivo_no_topo else 0.0, -tamanho.z / 2.0)
	malha.caixa(origem, tamanho, cor.lightened(0.07), cor, [true, true, true, true, true, true])
	var instancia := MeshInstance3D.new()
	instancia.mesh = malha.gerar()
	instancia.material_override = material_ps1()
	return instancia

func montar() -> void:
	var tronco := peca(Vector3(0.44, 0.62, 0.24), cor_roupa)
	tronco.position.y = 0.78
	add_child(tronco)
	var cabeca := peca(Vector3(0.26, 0.28, 0.26), cor_pele)
	cabeca.position.y = 1.40
	add_child(cabeca)
	var cabelo := peca(Vector3(0.28, 0.1, 0.28), Color("241d19"))
	cabelo.position.y = 1.66
	add_child(cabelo)
	_coxa_esquerda = peca(Vector3(0.16, 0.78, 0.18), cor_calca, true)
	_coxa_esquerda.position = Vector3(-0.11, 0.78, 0)
	add_child(_coxa_esquerda)
	_coxa_direita = peca(Vector3(0.16, 0.78, 0.18), cor_calca, true)
	_coxa_direita.position = Vector3(0.11, 0.78, 0)
	add_child(_coxa_direita)
	_braco_esquerdo = peca(Vector3(0.12, 0.58, 0.14), cor_roupa.darkened(0.12), true)
	_braco_esquerdo.position = Vector3(-0.28, 1.36, 0)
	add_child(_braco_esquerdo)
	_braco_direito = peca(Vector3(0.12, 0.58, 0.14), cor_roupa.darkened(0.12), true)
	_braco_direito.position = Vector3(0.28, 1.36, 0)
	add_child(_braco_direito)

func _physics_process(delta: float) -> void:
	var andando := not parada
	if andando:
		if position.x > limites.y: sentido = -1.0
		elif position.x < limites.x: sentido = 1.0
		velocity = Vector3(sentido * VELOCIDADE, 0, (linha_z - position.z) * 2.0)
		rotation.y = PI / 2.0 if sentido > 0 else -PI / 2.0
		move_and_slide()
		_passo += delta * 7.0
	else:
		_passo = move_toward(_passo, 0.0, delta * 6.0)
	var balanco := sin(_passo) * (0.6 if andando else 0.0)
	_coxa_esquerda.rotation.x = balanco
	_coxa_direita.rotation.x = -balanco
	_braco_esquerdo.rotation.x = -balanco * 0.7
	_braco_direito.rotation.x = balanco * 0.7
