extends CharacterBody3D

# Pessoa low poly no estilo PS1: o rosto e a roupa estão na textura, não na
# geometria. Ombros, quadril, braços e pernas giram na caminhada.
# O mesmo modelo serve para os pedestres e para a irmã.
const PS1 := preload("res://shaders/ps1.gdshader")
const ATLAS := preload("res://sprites/atlas3d.png")
const P := MalhaLowPoly.Peca
const VELOCIDADE := 1.25
## Material do mundo, passado pelo gerador para tudo usar a mesma textura.
var material_compartilhado: ShaderMaterial
## Linha da calçada (eixo Z) e intervalo que ela percorre no eixo X.
var linha_z := 19.5
var limites := Vector2(-6.0, 38.0)
var sentido := 1.0
var parada := false
var cor_roupa := Color("c9d3dd")
var cor_pele := Color("e0c3a3")
var cor_calca := Color("b9c0c9")
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
	if material_compartilhado: return material_compartilhado
	var material := ShaderMaterial.new()
	material.shader = PS1
	material.set_shader_parameter("atlas", ATLAS)
	material_compartilhado = material
	return material

func instancia(malha: MalhaLowPoly) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	no.mesh = malha.gerar()
	no.material_override = material_ps1()
	return no

## Peça do corpo: caixa com o pivô no topo (ombro/quadril) quando preciso.
func peca(tamanho: Vector3, cor: Color, textura: int, pivo_no_topo := false) -> MeshInstance3D:
	var malha := MalhaLowPoly.new()
	var origem := Vector3(-tamanho.x / 2.0, -tamanho.y if pivo_no_topo else 0.0, -tamanho.z / 2.0)
	malha.caixa(origem, tamanho, cor, cor, textura, textura, [true, true, true, true, true, true])
	return instancia(malha)

## Cabeça: rosto pintado na frente, cabelo nos outros lados.
func cabeca(tamanho: Vector3, pele: Color, cabelo: Color) -> MeshInstance3D:
	var malha := MalhaLowPoly.new()
	var h := tamanho / 2.0
	var a := Vector3(-h.x, -h.y, -h.z)
	var b := Vector3(h.x, -h.y, -h.z)
	var c := Vector3(h.x, h.y, -h.z)
	var d := Vector3(-h.x, h.y, -h.z)
	var e := Vector3(-h.x, -h.y, h.z)
	var f := Vector3(h.x, -h.y, h.z)
	var g := Vector3(h.x, h.y, h.z)
	var i := Vector3(-h.x, h.y, h.z)
	# O personagem olha para -Z, então o rosto fica nessa face.
	malha.quadrilatero(a, d, c, b, pele, P.ROSTO)
	malha.quadrilatero(f, g, i, e, cabelo, P.CABELO)
	malha.quadrilatero(e, i, d, a, cabelo, P.CABELO)
	malha.quadrilatero(b, c, g, f, cabelo, P.CABELO)
	malha.quadrilatero(d, i, g, c, cabelo, P.CABELO)
	malha.quadrilatero(e, a, b, f, cabelo.darkened(0.2), P.CABELO)
	return instancia(malha)

func montar() -> void:
	# Tronco com ombros um pouco mais largos que o quadril.
	var tronco := peca(Vector3(0.46, 0.64, 0.25), cor_roupa, P.CAMISA)
	tronco.position.y = 0.76
	add_child(tronco)
	var quadril := peca(Vector3(0.38, 0.18, 0.24), cor_calca, P.CALCA)
	quadril.position.y = 0.74
	add_child(quadril)
	var pescoco := peca(Vector3(0.14, 0.08, 0.14), cor_pele, P.LISO)
	pescoco.position.y = 1.40
	add_child(pescoco)
	var rosto := cabeca(Vector3(0.28, 0.3, 0.26), cor_pele, Color("6d6157"))
	rosto.position.y = 1.62
	add_child(rosto)
	_coxa_esquerda = peca(Vector3(0.17, 0.76, 0.19), cor_calca, P.CALCA, true)
	_coxa_esquerda.position = Vector3(-0.11, 0.76, 0)
	add_child(_coxa_esquerda)
	_coxa_direita = peca(Vector3(0.17, 0.76, 0.19), cor_calca, P.CALCA, true)
	_coxa_direita.position = Vector3(0.11, 0.76, 0)
	add_child(_coxa_direita)
	for pe: float in [-0.11, 0.11]:
		var sapato := peca(Vector3(0.19, 0.1, 0.27), Color("8c8880"), P.LISO)
		sapato.position = Vector3(pe, 0.0, -0.03)
		add_child(sapato)
	_braco_esquerdo = peca(Vector3(0.13, 0.56, 0.15), cor_roupa.darkened(0.08), P.CAMISA, true)
	_braco_esquerdo.position = Vector3(-0.29, 1.34, 0)
	add_child(_braco_esquerdo)
	_braco_direito = peca(Vector3(0.13, 0.56, 0.15), cor_roupa.darkened(0.08), P.CAMISA, true)
	_braco_direito.position = Vector3(0.29, 1.34, 0)
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
