extends SceneTree

## Os becos são montados à mão em casario.tscn (BlocosBecos). Aqui confere-se
## o que sai de data/becos3d.json: piso por baixo de tudo, bocas na barreira da
## calçada e a cápsula do jogador entrando por cada uma no bairro completo.
const BECOS := preload("res://scripts/becos3d.gd")
var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	call_deferred("rodar")

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

func rodar() -> void:
	var dados := BECOS.dados()
	checar(dados.has("piso") and dados.has("entradas"), "dados com piso e entradas")
	var jogo: Node = load("res://scenes/mundo3d.tscn").instantiate()
	root.add_child(jogo)
	current_scene = jogo
	await physics_frame
	await physics_frame
	var casario: Node3D = jogo.mundo.get_node("Casario")
	checar(casario.get_node_or_null("BlocosBecos") != null, "blocos dos becos ficam no jogo")
	checar(casario.get_node_or_null("GuiaRua") == null, "guia da rua sai do jogo")
	checar(jogo.vizinhos.size() == 5, "mundo mantém cinco portas de vizinhos")
	var bairro: PhysicsDirectSpaceState3D = jogo.mundo.get_world_3d().direct_space_state
	var piso: Rect2 = jogo.becos["chaos"][0]
	# Piso contínuo: amostra a cada metro dentro do retângulo.
	var buracos := 0
	var x := piso.position.x + 0.5
	while x < piso.end.x:
		var z := piso.position.y + 0.5
		while z < piso.end.y:
			if bairro.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 0.3, z), Vector3(x, -0.4, z), 1)).is_empty():
				buracos += 1
			z += 1.0
		x += 1.0
	checar(buracos == 0, "piso sem buracos atrás das fachadas (%d)" % buracos)
	var capsula := CapsuleShape3D.new()
	capsula.height = 1.7
	capsula.radius = 0.28
	checar(jogo.becos["rotas"].size() == jogo.becos["entradas"].size(), "uma rota de conferência por entrada")
	for _vez in 2:
		for rota: PackedVector3Array in jogo.becos["rotas"]:
			for j in rota.size() - 1:
				var consulta := PhysicsShapeQueryParameters3D.new()
				consulta.shape = capsula
				consulta.collision_mask = 1
				consulta.transform.origin = rota[j] + Vector3(0, 0.89, 0)
				consulta.motion = rota[j + 1] - rota[j]
				checar(bairro.cast_motion(consulta)[0] >= 0.999, "jogador entra no beco por x=%.1f" % rota[j].x)
			var fim := rota[rota.size() - 1]
			checar(not bairro.intersect_ray(PhysicsRayQueryParameters3D.create(fim + Vector3(0, 0.3, 0), fim - Vector3(0, 0.4, 0), 1)).is_empty(), "apoio dentro do beco em x=%.1f" % fim.x)
		# Segunda volta: com o comércio fechado as passagens continuam.
		jogo.fechar_comercio(true)
		await physics_frame
		await physics_frame
	# Fora das bocas a barreira segura a calçada.
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = capsula
	consulta.collision_mask = 1
	consulta.transform.origin = Vector3(-30.0, 0.89, 36.8)
	consulta.motion = Vector3(0, 0, 3.0)
	checar(bairro.cast_motion(consulta)[0] < 0.999, "calçada fechada fora das entradas")
	print("BECOS: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
