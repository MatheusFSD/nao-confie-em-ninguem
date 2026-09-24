extends AnimatableBody3D

# Carro low poly: capô, teto e vidros em poucas faces, rodas de 5 lados.
# Anda na faixa e reaparece do outro lado ao sair do trecho.
const PS1 := preload("res://shaders/ps1.gdshader")
const ATLAS := preload("res://sprites/atlas3d.png")
## Material do mundo, passado pelo gerador para tudo usar a mesma textura.
var material_compartilhado: ShaderMaterial
const CORES := ["8c4a3c", "5d7a8c", "c9c2a8", "3d4a44", "a69a7a", "2c3a4a"]
var linha_z := 21.25
var limites := Vector2(-12.0, 46.0)
var sentido := 1.0
var velocidade := 4.5

func _ready() -> void:
	add_to_group("carros3d")
	sync_to_physics = false
	velocidade = randf_range(3.4, 6.2)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(4.0, 1.3, 1.7)
	forma.shape = caixa
	forma.position.y = 0.65
	add_child(forma)
	montar(Color(CORES.pick_random()))
	rotation.y = 0.0 if sentido > 0 else PI

func montar(cor: Color) -> void:
	var malha := MalhaLowPoly.new()
	var vidro := Color("2a3538")
	# Carroceria em duas caixas (base e cabine) e um capô inclinado à frente.
	malha.caixa(Vector3(-2.0, 0.28, -0.85), Vector3(4.0, 0.62, 1.7), cor.lightened(0.05), cor, MalhaLowPoly.Peca.LISO, MalhaLowPoly.Peca.LISO, [true, true, true, true, true, true])
	malha.caixa(Vector3(-0.95, 0.9, -0.75), Vector3(1.9, 0.62, 1.5), cor.lightened(0.05), Color("cfe0e4"), MalhaLowPoly.Peca.LISO, MalhaLowPoly.Peca.VIDRO, [true, true, true, true, true, false])
	malha.quadrilatero(Vector3(1.05, 0.9, -0.75), Vector3(1.05, 0.9, 0.75), Vector3(2.0, 0.6, 0.85), Vector3(2.0, 0.6, -0.85), cor.lightened(0.1))
	malha.quadrilatero(Vector3(-0.95, 0.9, 0.75), Vector3(-0.95, 0.9, -0.75), Vector3(-2.0, 0.6, -0.85), Vector3(-2.0, 0.6, 0.85), cor.lightened(0.02))
	# Faróis e lanternas.
	malha.caixa(Vector3(1.96, 0.5, -0.62), Vector3(0.08, 0.18, 0.34), Color("f4e7b0"), Color("f4e7b0"))
	malha.caixa(Vector3(1.96, 0.5, 0.28), Vector3(0.08, 0.18, 0.34), Color("f4e7b0"), Color("f4e7b0"))
	malha.caixa(Vector3(-2.04, 0.5, -0.62), Vector3(0.08, 0.18, 0.34), Color("b0392e"), Color("b0392e"))
	malha.caixa(Vector3(-2.04, 0.5, 0.28), Vector3(0.08, 0.18, 0.34), Color("b0392e"), Color("b0392e"))
	for x: float in [1.25, -1.25]:
		for z: float in [-0.88, 0.72]:
			malha.cilindro(Vector3(x, 0.32, z), 0.32, 0.16, 5, Color("1d1f1e"), Color("6d716c"))
	var instancia := MeshInstance3D.new()
	instancia.mesh = malha.gerar()
	if material_compartilhado == null:
		material_compartilhado = ShaderMaterial.new()
		material_compartilhado.shader = PS1
		material_compartilhado.set_shader_parameter("atlas", ATLAS)
	instancia.material_override = material_compartilhado
	add_child(instancia)

func _physics_process(delta: float) -> void:
	position.x += sentido * velocidade * delta
	position.z = linha_z
	if position.x > limites.y and sentido > 0: position.x = limites.x
	elif position.x < limites.x and sentido < 0: position.x = limites.y
