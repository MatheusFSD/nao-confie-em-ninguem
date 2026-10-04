extends SceneTree

var falhas := 0
var verificacoes := 0
const PESSOA := preload("res://scripts/pessoa3d.gd")

func _initialize() -> void:
	call_deferred("rodar")

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

## Mede a geometria final de cada membro. Só verificar a altura total do
## corpo não detectava mãos e pernas suspensas acima do piso.
func alturas_dos_membros(corpo: Corpo3D) -> Dictionary:
	var fonte := (load(String(PESSOA.ELENCO[corpo.personagem].arquivo)) as PackedScene).instantiate()
	var sk := Pose3D.esqueleto(fonte)
	var alturas := {}
	var m := 0
	for mi: MeshInstance3D in fonte.find_children("*", "MeshInstance3D", true, false):
		var pronta := corpo.visual.get_child(m) as MeshInstance3D
		m += 1
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = pronta.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var pesos: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var binds: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var n := int(pesos.size() / v.size())
			for i in v.size():
				var maior := -1.0
				var osso := -1
				for j in n:
					if pesos[i * n + j] > maior:
						maior = pesos[i * n + j]
						var bind := binds[i * n + j]
						osso = mi.skin.get_bind_bone(bind)
						if osso < 0: osso = sk.find_bone(mi.skin.get_bind_name(bind))
				var nome := sk.get_bone_name(osso)
				# A sacola no chão não pode mascarar uma mão suspensa.
				if corpo.personagem == "dona_celia" and nome == "hand_R" and a[Mesh.ARRAY_TEX_UV][i].y > 0.7: continue
				alturas[nome] = minf(float(alturas.get(nome, INF)), v[i].y)
	fonte.free()
	return alturas

func rodar() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/corpos3d.json"))
	for local: Dictionary in dados.corpos:
		var corpo := (load(String(local.cena)) as PackedScene).instantiate() as Corpo3D
		root.add_child(corpo)
		var caixa: AABB = RuaModelo.caixa_mundial(corpo.visual, Transform3D.IDENTITY)
		print("POSE ", corpo.personagem, " / ", corpo.pose, " dimensões=", caixa.size)
		checar(caixa.position.y >= 0.007 and caixa.position.y <= 0.009, "corpo encosta no chão: " + corpo.personagem)
		checar(caixa.size.y < 0.8, "pose deitada: " + corpo.personagem)
		checar(maxf(caixa.size.x, caixa.size.z) > 1.0, "corpo preserva escala: " + corpo.personagem)
		checar(corpo.find_children("*", "AnimationPlayer", true, false).is_empty(), "sem animação: " + corpo.personagem)
		checar(corpo.find_children("*", "PhysicsBody3D", true, false).is_empty(), "não pode ser empurrado: " + corpo.personagem)
		checar(corpo.pose in ["costas", "frente"], "somente bruços ou barriga para cima")
		var alturas := alturas_dos_membros(corpo)
		for membro in ["upperarm", "forearm", "hand", "thigh", "shin", "foot"]:
			for lado in ["L", "R"]:
				var nome: String = membro + "_" + lado
				checar(alturas.has(nome) and float(alturas[nome]) >= 0.007 and float(alturas[nome]) <= 0.020,
					"membro apoiado no piso: " + corpo.personagem + " / " + nome)
		checar(corpo.poca != null, "poça de sangue em cada corpo")
		var mancha := corpo.poca.mesh.get_aabb()
		checar(is_equal_approx(mancha.position.y, 0.004) and mancha.size.y < 0.0001, "sangue rente ao chão")
		checar(mancha.size.x > 0.9 and mancha.size.z > 0.9, "poça visível ao redor do corpo")
		var antes := corpo.transform
		await physics_frame
		checar(corpo.transform == antes, "corpo imóvel: " + corpo.personagem)
		corpo.free()
	var jogo := (load("res://scenes/mundo3d.tscn") as PackedScene).instantiate()
	root.add_child(jogo)
	current_scene = jogo
	await physics_frame
	jogo.ciclo.dia = 5
	jogo.virar_o_dia(5)
	checar(jogo.corpos == null, "nenhum corpo antes do breu")
	jogo.ciclo.dia = 6
	jogo.virar_o_dia(6)
	checar(jogo.corpos != null and jogo.corpos.get_child_count() == dados.corpos.size(), "corpos aparecem no dia 6")
	var registro := {}
	for corpo: Corpo3D in jogo.corpos.get_children():
		registro[String(corpo.name)] = {"id": corpo.get_instance_id(), "t": corpo.global_transform, "pose": corpo.pose,
			"sangue_id": corpo.poca.get_instance_id(), "sangue_t": corpo.poca.global_transform,
			"sangue_vertices": corpo.poca.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]}
		checar(corpo.is_visible_in_tree(), "visível no breu")
		var de := corpo.global_position + Vector3.UP * 2.0
		var consulta := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * 4.0, 1)
		consulta.exclude = [jogo.jogador.get_rid()]
		var piso: Dictionary = jogo.mundo.get_world_3d().direct_space_state.intersect_ray(consulta)
		checar(not piso.is_empty() and absf((piso.position as Vector3).y - corpo.global_position.y) < 0.01, "altura da pista/calçada correta")
	for dia in [7, 8, 9, 10, 15]:
		jogo.ciclo.dia = dia
		jogo.virar_o_dia(dia)
		for i in 3: await physics_frame
		checar(jogo.corpos.get_child_count() == registro.size(), "sem duplicar corpos no dia " + str(dia))
		for corpo: Corpo3D in jogo.corpos.get_children():
			var anterior: Dictionary = registro[String(corpo.name)]
			checar(corpo.get_instance_id() == anterior.id, "reutiliza mesmo corpo")
			checar(corpo.global_transform == anterior.t, "posição e rotação persistem no dia " + str(dia))
			checar(corpo.pose == anterior.pose and corpo.is_visible_in_tree(), "pose continua visível")
			checar(corpo.poca.get_instance_id() == anterior.sangue_id and corpo.poca.global_transform == anterior.sangue_t,
				"mesma poça no mesmo local no dia " + str(dia))
			checar(corpo.poca.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == anterior.sangue_vertices,
				"formato da poça preservado")
	checar(jogo.mundo.get_node("Irma").visible, "irmã permanece viva")
	checar(jogo.vizinhos.size() == 5, "vizinhos das conversas preservados")
	jogo.queue_free()
	await process_frame
	# Entrada direta após o breu também precisa montar os corpos.
	var tardio := (load("res://scenes/mundo3d.tscn") as PackedScene).instantiate()
	tardio.dia = 8
	root.add_child(tardio)
	current_scene = tardio
	await physics_frame
	checar(tardio.corpos != null and tardio.corpos.get_child_count() == registro.size(), "cena iniciada no dia 8 contém corpos")
	for corpo: Corpo3D in tardio.corpos.get_children():
		var anterior: Dictionary = registro[String(corpo.name)]
		checar(corpo.global_transform.is_equal_approx(anterior.t), "entrada direta mantém o local do corpo: " + corpo.personagem)
		checar(corpo.poca.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == anterior.sangue_vertices,
			"entrada direta mantém formato da poça")
	tardio.queue_free()
	await process_frame
	print("CORPOS: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
