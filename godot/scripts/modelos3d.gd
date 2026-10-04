class_name Modelos3D
extends RefCounted

# Conserto de malha para os modelos do artefato. Eles trazem detalhes desenhados
# exatamente em cima de outra face — o vidro no espelho, a tampa na privada, o
# balcão do bar sobre o piso da loja. Duas faces no mesmo plano disputam o mesmo
# pixel e a peça fica coberta de chuvisco. Aqui o detalhe é afastado 1,5 mm na
# direção para onde olha: não muda nada no olho e acaba com a briga.
#
# Conta como detalhe o triângulo que cobre o mesmo pedaço de plano que outro sem
# ser pedaço da mesma superfície. As duas metades de um quadrilátero dividem uma
# aresta e ficam como estão, senão apareceria um degrau na emenda.
const AFASTAMENTO := 0.0015
## Quantos triângulos no mesmo plano ainda valem a comparação de todos contra
## todos. Acima disso o custo cresce ao quadrado e trava o carregamento.
const LIMITE_DO_GRUPO := 120
## Malhas já consertadas, guardadas pela malha de origem. Sem isto a mesma casa
## seria refeita uma vez por instância — 49 vezes, na rua inteira.
static var _consertadas := {}

## Afasta as faces coladas de todas as malhas abaixo do nó. Devolve quantas.
static func separar_coladas(no: Node) -> int:
	var mexidas := 0
	if no is MeshInstance3D and (no as MeshInstance3D).mesh:
		mexidas += consertar(no as MeshInstance3D)
	for filho in no.get_children(): mexidas += separar_coladas(filho)
	return mexidas

static func consertar(instancia: MeshInstance3D) -> int:
	var origem := instancia.mesh
	var chave := origem.get_instance_id()
	if _consertadas.has(chave):
		var pronta = _consertadas[chave]
		if pronta != null: instancia.mesh = pronta
		return 0
	var nova := ArrayMesh.new()
	var mexidas := 0
	for s in origem.get_surface_count():
		var arrays := expandir(origem.surface_get_arrays(s))
		mexidas += afastar(arrays)
		nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		nova.surface_set_material(nova.get_surface_count() - 1, origem.surface_get_material(s))
	_consertadas[chave] = nova if mexidas > 0 else null
	if mexidas > 0: instancia.mesh = nova
	return mexidas

## Desfaz a indexação: cada triângulo passa a ter vértices só seus, para um
## poder andar sem arrastar os vizinhos.
static func expandir(a: Array) -> Array:
	var saida := []
	saida.resize(Mesh.ARRAY_MAX)
	var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if a[Mesh.ARRAY_INDEX] != null: indices = a[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size(): indices.append(i)
	var normais = a[Mesh.ARRAY_NORMAL]
	var cores = a[Mesh.ARRAY_COLOR]
	var uvs = a[Mesh.ARRAY_TEX_UV]
	var uvs2 = a[Mesh.ARRAY_TEX_UV2]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for i in indices:
		v.append(vertices[i])
		if normais != null: n.append(normais[i])
		if cores != null: c.append(cores[i])
		if uvs != null: uv.append(uvs[i])
		if uvs2 != null: uv2.append(uvs2[i])
	saida[Mesh.ARRAY_VERTEX] = v
	if normais != null: saida[Mesh.ARRAY_NORMAL] = n
	if cores != null: saida[Mesh.ARRAY_COLOR] = c
	if uvs != null: saida[Mesh.ARRAY_TEX_UV] = uv
	if uvs2 != null: saida[Mesh.ARRAY_TEX_UV2] = uv2
	return saida

static func afastar(arrays: Array) -> int:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var quantos := v.size() / 3
	var areas := PackedFloat32Array()
	var normais := PackedVector3Array()
	var eixos := PackedInt32Array()
	var grupos := {}
	for t in quantos:
		var a := v[t * 3]
		var cruz := (v[t * 3 + 1] - a).cross(v[t * 3 + 2] - a)
		var area := cruz.length() * 0.5
		var normal := cruz.normalized() if area > 0.000001 else Vector3.UP
		areas.append(area)
		normais.append(normal)
		# Eixo em que a normal é mais forte: é por ele que o plano é achatado
		# para comparar as áreas em duas dimensões.
		var absoluta := normal.abs()
		var eixo := 0
		if absoluta.y >= absoluta.x and absoluta.y >= absoluta.z: eixo = 1
		elif absoluta.z >= absoluta.x: eixo = 2
		eixos.append(eixo)
		# O plano é guardado sem direção: faces de costas uma para a outra caem
		# no mesmo grupo, que é justamente o caso que interessa.
		var m := normal
		var d := m.dot(a)
		if m.x + m.y + m.z < 0.0:
			m = -m
			d = -d
		# Grade grossa de propósito: faces que o exportador deixou a décimos de
		# milímetro uma da outra brigam igual e precisam cair no mesmo grupo.
		var chave := "%.2f,%.2f,%.2f|%.3f" % [m.x, m.y, m.z, snappedf(d, 0.002)]
		if not grupos.has(chave): grupos[chave] = []
		grupos[chave].append(t)
	var mexidas := 0
	var mexido := {}
	for chave: String in grupos:
		var lista: Array = grupos[chave]
		if lista.size() < 2: continue
		# A comparação é de todos contra todos. Num plano com centenas de
		# triângulos — o chão de uma cidade inteira, por exemplo — isso não
		# termina nunca. Acima do limite, o plano fica como está.
		if lista.size() > LIMITE_DO_GRUPO: continue
		for i in lista.size():
			for j in range(i + 1, lista.size()):
				var a: int = lista[i]
				var b: int = lista[j]
				# Duas metades de um mesmo quadrilátero dividem uma aresta e
				# não brigam: cada uma cobre a sua parte.
				if divide_aresta(v, a, b): continue
				if not se_cobrem(v, a, b, eixos[a]): continue
				# Sai da frente o menor, que é o detalhe posto por cima.
				var detalhe: int = a if areas[a] <= areas[b] else b
				if mexido.has(detalhe): continue
				for k in 3: v[detalhe * 3 + k] += normais[detalhe] * AFASTAMENTO
				mexido[detalhe] = true
				mexidas += 1
	arrays[Mesh.ARRAY_VERTEX] = v
	return mexidas

## Dois triângulos com dois vértices em comum são pedaços da mesma superfície.
static func divide_aresta(v: PackedVector3Array, a: int, b: int) -> bool:
	var iguais := 0
	for i in 3:
		for j in 3:
			if v[a * 3 + i].distance_to(v[b * 3 + j]) < 0.0005: iguais += 1
	return iguais >= 2

## Os dois ocupam o mesmo pedaço do plano? A comparação é feita no plano, sem o
## eixo da normal: nele a caixa tem espessura zero e não dá para encolher.
static func se_cobrem(v: PackedVector3Array, a: int, b: int, eixo: int) -> bool:
	var ca := caixa_no_plano(v, a, eixo)
	var cb := caixa_no_plano(v, b, eixo)
	return ca.intersects(cb)

static func caixa_no_plano(v: PackedVector3Array, t: int, eixo: int) -> Rect2:
	var p := achatar(v[t * 3], eixo)
	var caixa := Rect2(p, Vector2.ZERO)
	caixa = caixa.expand(achatar(v[t * 3 + 1], eixo))
	caixa = caixa.expand(achatar(v[t * 3 + 2], eixo))
	# Encolhida um tico: encostar de lado não conta como cobrir.
	return caixa.grow(-0.002)

static func achatar(p: Vector3, eixo: int) -> Vector2:
	if eixo == 0: return Vector2(p.y, p.z)
	if eixo == 1: return Vector2(p.x, p.z)
	return Vector2(p.x, p.y)
