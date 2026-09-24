class_name MalhaLowPoly
extends RefCounted

# Construtor de malhas low poly: junta tudo em UMA malha, com textura de atlas e
# cor por vértice. Cada face é um triângulo de verdade e as faces internas (entre
# blocos colados) não são criadas, para o total de polígonos ficar baixo.
#
# UV guarda a repetição em metros (1 repetição por metro) e UV2 guarda a peça do
# atlas; o shader junta os dois, então o mundo inteiro usa uma textura só.
## Peças do atlas (sprites/atlas3d.png), 4 × 4.
enum Peca { REBOCO, PINTADO, TIJOLO, TELHA, ASFALTO, CALCADA, CIMENTO, TERRA, TACO, AZULEJO, METAL, VIDRO, PORTA, TECIDO, FOLHA, LISO, ROSTO, CABELO, CAMISA, CALCA }
const GRADE := 4

var _vertices := PackedVector3Array()
var _cores := PackedColorArray()
var _normais := PackedVector3Array()
var _uvs := PackedVector2Array()
var _uvs2 := PackedVector2Array()

func total_triangulos() -> int:
	return _vertices.size() / 3

static func peca_uv(peca: int) -> Vector2:
	return Vector2(peca % GRADE, peca / GRADE)

## Triângulo com normal plana (visual facetado do PS1).
func triangulo(a: Vector3, b: Vector3, c: Vector3, cor: Color, peca := Peca.LISO, uv_a := Vector2.ZERO, uv_b := Vector2.ZERO, uv_c := Vector2.ZERO, normal_forcada := Vector3.ZERO) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 0.000001: return
	normal = normal_forcada.normalized() if normal_forcada != Vector3.ZERO else normal.normalized()
	var canto := peca_uv(peca)
	for item in [[a, uv_a], [b, uv_b], [c, uv_c]]:
		_vertices.append(item[0])
		_cores.append(cor)
		_normais.append(normal)
		_uvs.append(item[1])
		_uvs2.append(canto)

## Quatro cantos em ordem (horário visto de fora). A textura repete a cada metro.
func quadrilatero(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cor: Color, peca := Peca.LISO, normal_forcada := Vector3.ZERO) -> void:
	var largura := a.distance_to(b)
	var altura := b.distance_to(c)
	var ua := Vector2(0, 0)
	var ub := Vector2(largura, 0)
	var uc := Vector2(largura, altura)
	var ud := Vector2(0, altura)
	triangulo(a, b, c, cor, peca, ua, ub, uc, normal_forcada)
	triangulo(a, c, d, cor, peca, ua, uc, ud, normal_forcada)

## Placa visível dos dois lados (vegetação, chapas finas).
func quadrilatero_duplo(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cor: Color, peca := Peca.LISO, normal_forcada := Vector3.ZERO) -> void:
	quadrilatero(a, b, c, d, cor, peca, normal_forcada)
	quadrilatero(d, c, b, a, cor, peca, normal_forcada)

## Caixa com faces escolhidas: [cima, norte(-z), sul(+z), oeste(-x), leste(+x), baixo].
func caixa(origem: Vector3, tamanho: Vector3, cor_topo: Color, cor_lado: Color, peca_topo := Peca.LISO, peca_lado := Peca.LISO, lados := [true, true, true, true, true, false]) -> void:
	var x0 := origem.x
	var x1 := origem.x + tamanho.x
	var y0 := origem.y
	var y1 := origem.y + tamanho.y
	var z0 := origem.z
	var z1 := origem.z + tamanho.z
	if lados[0]: quadrilatero(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), cor_topo, peca_topo)
	if lados[1]: quadrilatero(Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y0, z0), cor_lado, peca_lado)
	if lados[2]: quadrilatero(Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y0, z1), cor_lado, peca_lado)
	if lados[3]: quadrilatero(Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(x0, y0, z0), cor_lado, peca_lado)
	if lados[4]: quadrilatero(Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1), cor_lado, peca_lado)
	if lados[5]: quadrilatero(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x0, y0, z0), cor_lado, peca_lado)

## Chão plano: um quadrilátero só, por maior que seja a área.
func piso(origem: Vector2, tamanho: Vector2, altura: float, cor: Color, peca := Peca.LISO) -> void:
	var x0 := origem.x
	var z0 := origem.y
	var x1 := origem.x + tamanho.x
	var z1 := origem.y + tamanho.y
	quadrilatero(Vector3(x0, altura, z0), Vector3(x1, altura, z0), Vector3(x1, altura, z1), Vector3(x0, altura, z1), cor, peca)

## Telhado de duas águas: 2 águas + 2 oitões.
func telhado(origem: Vector2, tamanho: Vector2, base: float, altura: float, cor: Color, cor_oitao: Color, peca := Peca.TELHA, peca_oitao := Peca.REBOCO) -> void:
	var x0 := origem.x
	var z0 := origem.y
	var x1 := origem.x + tamanho.x
	var z1 := origem.y + tamanho.y
	var meio := (z0 + z1) * 0.5
	var topo := base + altura
	quadrilatero(Vector3(x0, base, z0), Vector3(x1, base, z0), Vector3(x1, topo, meio), Vector3(x0, topo, meio), cor, peca)
	quadrilatero(Vector3(x1, base, z1), Vector3(x0, base, z1), Vector3(x0, topo, meio), Vector3(x1, topo, meio), cor.darkened(0.12), peca)
	triangulo(Vector3(x0, base, z1), Vector3(x0, base, z0), Vector3(x0, topo, meio), cor_oitao, peca_oitao, Vector2(0, 0), Vector2(tamanho.y, 0), Vector2(tamanho.y * 0.5, altura))
	triangulo(Vector3(x1, base, z0), Vector3(x1, base, z1), Vector3(x1, topo, meio), cor_oitao, peca_oitao, Vector2(0, 0), Vector2(tamanho.y, 0), Vector2(tamanho.y * 0.5, altura))

## Cilindro de poucos lados (postes, potes, rodas).
func cilindro(centro: Vector3, raio: float, altura: float, lados: int, cor: Color, cor_topo: Color, peca := Peca.LISO) -> void:
	var anterior := Vector3(centro.x + raio, centro.y, centro.z)
	for i in range(1, lados + 1):
		var a := TAU * i / lados
		var atual := Vector3(centro.x + cos(a) * raio, centro.y, centro.z + sin(a) * raio)
		quadrilatero(anterior, anterior + Vector3(0, altura, 0), atual + Vector3(0, altura, 0), atual, cor, peca)
		triangulo(Vector3(centro.x, centro.y + altura, centro.z), anterior + Vector3(0, altura, 0), atual + Vector3(0, altura, 0), cor_topo, peca, Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0))
		anterior = atual

## Fecha a malha. Uma superfície só: uma chamada de desenho para o cenário inteiro.
func gerar() -> ArrayMesh:
	var malha := ArrayMesh.new()
	if _vertices.is_empty(): return malha
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normais
	arrays[Mesh.ARRAY_COLOR] = _cores
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_TEX_UV2] = _uvs2
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malha
