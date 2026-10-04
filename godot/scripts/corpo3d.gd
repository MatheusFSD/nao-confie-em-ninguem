@tool
class_name Corpo3D
extends Node3D

# Usa a roupa e a malha do NPC original, mas aplica a pose uma única vez e
# congela os vértices em uma malha estática. Não há animação nem física móvel.
const PESSOA := preload("res://scripts/pessoa3d.gd")
const POSES := "res://data/poses_mortos.json"
static var _malhas := {}

@export_enum("marquinhos", "dona_celia", "seu_ze", "vanessa", "tania", "aline", "jessica", "rogerio", "anderson", "entregador") var personagem := "marquinhos":
	set(valor):
		personagem = valor
		if is_inside_tree(): montar()
@export_enum("costas", "frente") var pose := "costas":
	set(valor):
		pose = valor
		if is_inside_tree(): montar()
@export var resolucao := Vector2(320, 213)
@export var sangue := true:
	set(valor):
		sangue = valor
		if is_inside_tree(): montar()
var visual: Node3D
var poca: MeshInstance3D

func _ready() -> void:
	add_to_group("corpos3d")
	montar()

func montar() -> void:
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
	visual = Node3D.new()
	visual.name = "PoseEstatica"
	add_child(visual)
	var chave := personagem + ":" + pose
	if not _malhas.has(chave):
		var dados = JSON.parse_string(FileAccess.get_file_as_string(POSES))
		if not (dados is Dictionary) or not dados.has(pose) or not PESSOA.DA_RUA.has(personagem):
			push_error("Personagem ou pose de corpo inválidos: " + chave)
			return
		var modelo := (load(String(PESSOA.ELENCO[personagem].arquivo)) as PackedScene).instantiate()
		_malhas[chave] = congelar(modelo, dados[pose], personagem)
		modelo.free()
	for malha: ArrayMesh in _malhas[chave]:
		var instancia := MeshInstance3D.new()
		instancia.mesh = malha
		visual.add_child(instancia)
	RuaModelo.aplicar_ps1(visual, resolucao)
	montar_sangue()

## Polígono rente ao piso, com contorno irregular fixo para cada personagem.
## Fica fora da malha do corpo, para não acompanhar a altura dos membros.
func montar_sangue() -> void:
	if is_instance_valid(poca):
		remove_child(poca)
		poca.queue_free()
		poca = null
	if not sangue: return
	var acaso := RandomNumberGenerator.new()
	acaso.seed = personagem.hash()
	var sentido := -1.0 if pose == "costas" else 1.0
	var centro := Vector3(0.07, 0.004, 0.35 * sentido)
	var vertices := PackedVector3Array()
	var normais := PackedVector3Array()
	var cores := PackedColorArray()
	var borda := PackedVector3Array()
	var segmentos := 24
	var largura := acaso.randf_range(0.65, 0.82)
	var comprimento := acaso.randf_range(0.66, 0.82)
	for i in segmentos:
		var angulo := TAU * float(i) / segmentos
		var raio := acaso.randf_range(0.82, 1.12)
		borda.append(centro + Vector3(cos(angulo) * largura, 0, sin(angulo) * comprimento) * raio)
	for i in segmentos:
		vertices.append_array([centro, borda[(i + 1) % segmentos], borda[i]])
		normais.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
		cores.append_array([Color("4d080c"), Color("86131a"), Color("86131a")])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normais
	arrays[Mesh.ARRAY_COLOR] = cores
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.45
	material.metallic_specular = 0.25
	malha.surface_set_material(0, material)
	poca = MeshInstance3D.new()
	poca.name = "PocaDeSangue"
	poca.mesh = malha
	poca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(poca)

## Transforma a malha de pele em geometria rígida, inclusive fora da árvore e
## sem renderizador. Isso também permite verificar o contato com o chão.
static func congelar(modelo: Node3D, dados: Dictionary, personagem_original := "") -> Array:
	var sk := Pose3D.esqueleto(modelo)
	if sk == null: return []
	sk.reset_bone_poses()
	for osso: String in dados.get("ossos", {}):
		var graus: Array = dados.ossos[osso]
		Pose3D.girar(sk, osso, Vector3(graus[0], graus[1], graus[2]))
	var ossos: Array[Transform3D] = []
	var r: Array = dados.get("rotacao", [0, 0, 0])
	var queda := Basis.from_euler(Vector3(deg_to_rad(r[0]), deg_to_rad(r[1]), deg_to_rad(r[2])))
	var soltar_bolsa := personagem_original == "dona_celia"
	var piso := apoiar_membros(modelo, sk, queda, soltar_bolsa)
	ossos = poses_globais(sk)
	var malhas := []
	var limites := AABB()
	var primeiro := true
	var limites_bolsa := AABB()
	var primeira_bolsa := true
	var soltos := []
	for instancia: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if instancia.mesh == null: continue
		var deformacoes: Array[Transform3D] = []
		if instancia.skin != null:
			for i in instancia.skin.get_bind_count():
				var indice := instancia.skin.get_bind_bone(i)
				if indice < 0: indice = sk.find_bone(instancia.skin.get_bind_name(i))
				if indice < 0:
					push_error("Osso de skin não encontrado")
					return []
				deformacoes.append(transformacao(sk, modelo) * ossos[indice] * instancia.skin.get_bind_pose(i))
		var nova := ArrayMesh.new()
		var soltos_da_malha := []
		for s in instancia.mesh.get_surface_count():
			var arrays := instancia.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normais: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var pesos = arrays[Mesh.ARRAY_WEIGHTS]
			var indices = arrays[Mesh.ARRAY_BONES]
			var por_vertice := int(indices.size() / vertices.size()) if indices != null and not vertices.is_empty() else 0
			var soltos_da_superficie := {}
			for v in vertices.size():
				var ponto := Vector3.ZERO
				var normal := Vector3.ZERO
				var bolsa := false
				if not deformacoes.is_empty() and por_vertice > 0:
					for j in por_vertice:
						var peso: float = pesos[v * por_vertice + j]
						if peso <= 0.0: continue
						var deformacao: Transform3D = deformacoes[indices[v * por_vertice + j]]
						ponto += (deformacao * vertices[v]) * peso
						normal += (deformacao.basis * normais[v]) * peso
						if soltar_bolsa and peso > 0.5:
							var bind: int = indices[v * por_vertice + j]
							var osso := instancia.skin.get_bind_bone(bind)
							if osso < 0: osso = sk.find_bone(instancia.skin.get_bind_name(bind))
							bolsa = sk.get_bone_name(osso) == "hand_R" and arrays[Mesh.ARRAY_TEX_UV][v].y > 0.7
				else:
					var t := transformacao(instancia, modelo)
					ponto = t * vertices[v]
					normal = t.basis * normais[v]
				if bolsa:
					# A sacola foi solta: conserva sua forma e cai ao lado da mão.
					ponto = transformacao(instancia, modelo) * vertices[v]
					normal = transformacao(instancia, modelo).basis * normais[v]
					soltos_da_superficie[v] = true
				var orientacao := Basis(Vector3.BACK, PI / 2.0) if bolsa else queda
				vertices[v] = orientacao * ponto
				normais[v] = (orientacao * normal).normalized()
				if bolsa:
					limites_bolsa = AABB(vertices[v], Vector3.ZERO) if primeira_bolsa else limites_bolsa.expand(vertices[v])
					primeira_bolsa = false
				else:
					# A roupa cede onde encosta no chão, sem erguer o restante do
					# corpo por causa da barra rígida da saia ou da sola do sapato.
					vertices[v].y = maxf(vertices[v].y, piso)
					limites = AABB(vertices[v], Vector3.ZERO) if primeiro else limites.expand(vertices[v])
					primeiro = false
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normais
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			arrays[Mesh.ARRAY_TANGENT] = null
			nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			nova.surface_set_material(s, instancia.mesh.surface_get_material(s))
			soltos_da_malha.append(soltos_da_superficie)
		malhas.append(nova)
		soltos.append(soltos_da_malha)
	# A posição da cena marca o centro do corpo. O ponto mais baixo encosta no
	# piso com 8 mm de folga, sem afundar a roupa ou deixar o modelo flutuando.
	var centro := limites.get_center()
	var ajuste := Vector3(-centro.x, -limites.position.y + 0.008, -centro.z)
	var centro_bolsa := limites_bolsa.get_center()
	var ajuste_bolsa := Vector3(-0.95 - centro_bolsa.x, -limites_bolsa.position.y + 0.008, 0.12 - centro_bolsa.z)
	var resultado := []
	for m in malhas.size():
		var malha: ArrayMesh = malhas[m]
		var pronta := ArrayMesh.new()
		for s in malha.get_surface_count():
			var arrays := malha.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v in vertices.size():
				vertices[v] += ajuste_bolsa if soltos[m][s].has(v) else ajuste
			arrays[Mesh.ARRAY_VERTEX] = vertices
			pronta.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			pronta.surface_set_material(s, malha.surface_get_material(s))
		resultado.append(pronta)
	return resultado

## Usa a espessura real de cada modelo para apoiar cotovelos, mãos, joelhos
## e pés no mesmo plano do tronco. A pose fica pronta antes de congelar a
## malha; não há simulação que possa mover os corpos nos próximos dias.
static func apoiar_membros(modelo: Node3D, sk: Skeleton3D, queda: Basis, soltar_bolsa := false) -> float:
	var apoio := pontos_dos_ossos(modelo, sk, soltar_bolsa)
	var ossos := poses_globais(sk)
	var piso := INF
	for nome in ["hips", "spine", "chest", "head"]:
		var i := sk.find_bone(nome)
		for ponto: Vector3 in apoio.get(i, []):
			piso = minf(piso, (queda * (ossos[i] * ponto)).y)
	encostar_osso(sk, queda, apoio, "spine", "chest", "chest", piso)
	var de_costas := (queda * Vector3.BACK).y > 0.0
	for lado in ["L", "R"]:
		encostar_osso(sk, queda, apoio, "upperarm_" + lado, "upperarm_" + lado, "forearm_" + lado, piso, true)
		encostar_osso(sk, queda, apoio, "forearm_" + lado, "hand_" + lado, "hand_" + lado, piso)
		encostar_osso(sk, queda, apoio, "thigh_" + lado, "thigh_" + lado, "shin_" + lado, piso, true)
		if de_costas:
			encostar_osso(sk, queda, apoio, "shin_" + lado, "shin_" + lado, "foot_" + lado, piso, true)
		else:
			encostar_osso(sk, queda, apoio, "shin_" + lado, "foot_" + lado, "foot_" + lado, piso)
	encostar_osso(sk, queda, apoio, "neck", "head", "head", piso)
	return piso

static func poses_globais(sk: Skeleton3D) -> Array[Transform3D]:
	var resultado: Array[Transform3D] = []
	resultado.resize(sk.get_bone_count())
	for i in resultado.size():
		var pai := sk.get_bone_parent(i)
		resultado[i] = sk.get_bone_pose(i) if pai < 0 else resultado[pai] * sk.get_bone_pose(i)
	return resultado

## Vértices no espaço de cada osso, preservando a escala e a roupa do NPC.
static func pontos_dos_ossos(modelo: Node3D, sk: Skeleton3D, soltar_bolsa := false) -> Dictionary:
	var resultado := {}
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null: continue
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var pesos: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var binds: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var quantidade := int(pesos.size() / v.size())
			for i in v.size():
				var maior := -1.0
				var bind := -1
				for j in quantidade:
					if pesos[i * quantidade + j] > maior:
						maior = pesos[i * quantidade + j]
						bind = binds[i * quantidade + j]
				var osso := mi.skin.get_bind_bone(bind)
				if osso < 0: osso = sk.find_bone(mi.skin.get_bind_name(bind))
				if soltar_bolsa and sk.get_bone_name(osso) == "hand_R" and a[Mesh.ARRAY_TEX_UV][i].y > 0.7: continue
				if not resultado.has(osso): resultado[osso] = []
				resultado[osso].append(mi.skin.get_bind_pose(bind) * v[i])
	return resultado

static func encostar_osso(sk: Skeleton3D, queda: Basis, apoio: Dictionary, nome: String, contato: String, ponta: String, piso: float, distal := false) -> void:
	var i := sk.find_bone(nome)
	var j := sk.find_bone(contato)
	var fim := sk.find_bone(ponta)
	var ossos := poses_globais(sk)
	var centro := queda * ossos[i].origin
	var rumo := queda * (ossos[fim].origin - ossos[i].origin)
	var eixo := rumo.cross(Vector3.DOWN).normalized()
	if eixo.length_squared() < 0.1: return
	var pontos: Array[Vector3] = []
	for ponto: Vector3 in apoio.get(j, []):
		# A metade perto do ombro/quadril permanece ligada ao tronco. O apoio
		# que interessa aqui é a extremidade perto do cotovelo/joelho.
		if distal and ponto.y > sk.get_bone_rest(fim).origin.y * 0.6: continue
		pontos.append(queda * (ossos[j] * ponto) - centro)
	if pontos.is_empty(): return
	var melhor := 0.0
	var erro := INF
	# Uma correção pequena em torno da pose desenhada, sem alterar comprimentos.
	for passo in range(-80, 81):
		var angulo := deg_to_rad(float(passo) * 0.5)
		var giro := Basis(eixo, angulo)
		var altura := INF
		for ponto: Vector3 in pontos: altura = minf(altura, (giro * ponto).y + centro.y)
		var diferenca := absf(altura - piso) + absf(angulo) * 0.0001
		if diferenca < erro:
			erro = diferenca
			melhor = angulo
	var pai := sk.get_bone_parent(i)
	var base := queda * ossos[pai].basis if pai >= 0 else queda
	var local := base.inverse() * Basis(eixo, melhor) * queda * ossos[i].basis
	sk.set_bone_pose_rotation(i, local.get_rotation_quaternion())

static func transformacao(no: Node3D, raiz: Node3D) -> Transform3D:
	var resultado := Transform3D.IDENTITY
	var atual: Node = no
	while atual != null and atual != raiz:
		if atual is Node3D: resultado = (atual as Node3D).transform * resultado
		atual = atual.get_parent()
	return resultado
