class_name Becos3D
extends RefCounted

## Miolo do quarteirão do lado de lá da rua. Os blocos dos becos e as casas
## ficam em casario.tscn (nó BlocosBecos) e são editados à mão no Godot; aqui
## sai só o piso por baixo de tudo, a cerca invisível em volta e as bocas que a
## barreira da calçada (Z=37,6) deixa abertas para entrar.
const DADOS := "res://data/becos3d.json"

static func dados() -> Dictionary:
	var documento = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	return documento if documento is Dictionary else {}

## Retorna as bocas a recortar da barreira e o retângulo de piso.
## Deve ser chamado depois de construir_casario e antes de construir_limites.
static func construir(pai: Node3D, resolucao: Vector2) -> Dictionary:
	var conjunto := Node3D.new()
	conjunto.name = "Becos"
	pai.add_child(conjunto)
	var registro := dados()
	var r: Array = registro.get("piso", [0, 0, 0, 0])
	var piso := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var chaos: Array[Rect2] = []
	if piso.has_area():
		chaos.append(piso)
		# Topo 2 cm abaixo do zero: não briga com o piso das casas (y=0,004).
		caixa(conjunto, "Piso", Vector3(piso.get_center().x, -0.12, piso.get_center().y),
			Vector3(piso.size.x, 0.2, piso.size.y), false, resolucao)
		conjunto.add_child(cimentado(piso, -0.02, resolucao))
		# Cerca invisível nas laterais e no fundo; a frente é a barreira da calçada.
		for lado in 2:
			var x: float = piso.position.x if lado == 0 else piso.end.x
			caixa(conjunto, "Cerca%d" % lado, Vector3(x + (-0.2 if lado == 0 else 0.2), 3.0, piso.get_center().y),
				Vector3(0.4, 6.0, piso.size.y), false, resolucao)
		caixa(conjunto, "CercaFundo", Vector3(piso.get_center().x, 3.0, piso.end.y + 0.2),
			Vector3(piso.size.x + 0.8, 6.0, 0.4), false, resolucao)
	var entradas: Array[Vector2] = []
	for entrada: Array in registro.get("entradas", []):
		entradas.append(Vector2(float(entrada[0]), float(entrada[1])))
	# Rotas de conferência (testes): da calçada para dentro de cada boca.
	var rotas: Array[PackedVector3Array] = []
	for caminho: Array in registro.get("rotas", []):
		var rota := PackedVector3Array()
		for p: Array in caminho: rota.append(Vector3(float(p[0]), 0.0, float(p[1])))
		rotas.append(rota)
	return {"no": conjunto, "entradas": entradas, "chaos": chaos, "rotas": rotas}

## Segmentos restantes de uma barreira horizontal depois das bocas abertas.
static func segmentos_fechados(faixa: Vector2, entradas: Array) -> Array[Vector2]:
	var cortes: Array = entradas.duplicate()
	cortes.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
	var segmentos: Array[Vector2] = []
	var cursor := faixa.x
	for corte: Vector2 in cortes:
		var inicio := clampf(corte.x, faixa.x, faixa.y)
		var fim := clampf(corte.y, faixa.x, faixa.y)
		if inicio > cursor: segmentos.append(Vector2(cursor, inicio))
		cursor = maxf(cursor, fim)
	if cursor < faixa.y: segmentos.append(Vector2(cursor, faixa.y))
	return segmentos

static func caixa(pai: Node3D, nome: String, lugar: Vector3, tamanho: Vector3, visivel: bool, resolucao: Vector2) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = nome
	corpo.position = lugar
	var forma := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = tamanho
	forma.shape = volume
	corpo.add_child(forma)
	if visivel:
		var malha := MeshInstance3D.new()
		var cubo := BoxMesh.new()
		cubo.size = tamanho
		malha.mesh = cubo
		var origem := StandardMaterial3D.new()
		origem.albedo_color = Color("b4a38b")
		malha.material_override = RuaModelo.converter(origem, resolucao)
		corpo.add_child(malha)
	pai.add_child(corpo)

## Cimentado do beco: a mesma placa com juntas da calçada da rua, uma a cada
## TAMANHO_PLACA metros. A malha é picada em quadrados pequenos porque o shader
## PS1 usa textura afim, que entorta em triângulos grandes vistos de perto.
const TEXTURA_PISO := "res://modelos/rua_penha_3.png"
const TAMANHO_PLACA := 1.6
const PEDACO := 1.6

static func cimentado(piso: Rect2, altura: float, resolucao: Vector2) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var colunas := ceili(piso.size.x / PEDACO)
	var linhas := ceili(piso.size.y / PEDACO)
	for i in colunas:
		for j in linhas:
			var x0 := piso.position.x + i * PEDACO
			var z0 := piso.position.y + j * PEDACO
			var x1 := minf(x0 + PEDACO, piso.end.x)
			var z1 := minf(z0 + PEDACO, piso.end.y)
			var cantos := [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
			# Ordem horária vista de cima: a face aponta para o céu.
			for k: int in [0, 1, 2, 0, 2, 3]:
				var c: Vector2 = cantos[k]
				st.set_uv(c / TAMANHO_PLACA)
				st.add_vertex(Vector3(c.x, altura, c.y))
	var chao := MeshInstance3D.new()
	chao.name = "Cimentado"
	chao.mesh = st.commit()
	var origem := StandardMaterial3D.new()
	origem.albedo_texture = load(TEXTURA_PISO)
	chao.material_override = RuaModelo.converter(origem, resolucao)
	return chao
