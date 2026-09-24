class_name MalhaLowPoly
extends RefCounted

# Construtor de malhas low poly: junta tudo em UMA malha com cor por vértice,
# sem empilhar nós de formas prontas. Cada face é um triângulo de verdade e as
# faces internas (entre blocos colados) nunca são criadas, para o total ficar baixo.
var _vertices := PackedVector3Array()
var _cores := PackedColorArray()
var _normais := PackedVector3Array()

func total_triangulos() -> int:
	return _vertices.size() / 3

## Triângulo com normal plana (visual facetado do PS1).
## `normal_forcada` serve para folhagem, que precisa receber luz como se fosse chão.
func triangulo(a: Vector3, b: Vector3, c: Vector3, cor: Color, normal_forcada := Vector3.ZERO) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 0.000001: return
	normal = normal_forcada.normalized() if normal_forcada != Vector3.ZERO else normal.normalized()
	for v in [a, b, c]:
		_vertices.append(v)
		_cores.append(cor)
		_normais.append(normal)

## Quatro cantos em ordem (horário visto de fora) viram dois triângulos.
func quadrilatero(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cor: Color, normal_forcada := Vector3.ZERO) -> void:
	triangulo(a, b, c, cor, normal_forcada)
	triangulo(a, c, d, cor, normal_forcada)

## Placa visível dos dois lados (vegetação, chapas finas).
func quadrilatero_duplo(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cor: Color, normal_forcada := Vector3.ZERO) -> void:
	quadrilatero(a, b, c, d, cor, normal_forcada)
	quadrilatero(d, c, b, a, cor, normal_forcada)

## Caixa sem tampa embaixo (chão nunca é visto) e com faces escolhidas.
## `lados` liga/desliga cada face: [cima, norte(-z), sul(+z), oeste(-x), leste(+x), baixo]
func caixa(origem: Vector3, tamanho: Vector3, cor_topo: Color, cor_lado: Color, lados := [true, true, true, true, true, false]) -> void:
	var o := origem
	var t := tamanho
	var x0 := o.x
	var x1 := o.x + t.x
	var y0 := o.y
	var y1 := o.y + t.y
	var z0 := o.z
	var z1 := o.z + t.z
	if lados[0]: quadrilatero(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), cor_topo)
	if lados[1]: quadrilatero(Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y0, z0), cor_lado)
	if lados[2]: quadrilatero(Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y0, z1), cor_lado)
	if lados[3]: quadrilatero(Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(x0, y0, z0), cor_lado)
	if lados[4]: quadrilatero(Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1), cor_lado)
	if lados[5]: quadrilatero(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x0, y0, z0), cor_lado)

## Chão plano (um quadrilátero só, por maior que seja a área).
func piso(origem: Vector2, tamanho: Vector2, altura: float, cor: Color) -> void:
	var x0 := origem.x
	var z0 := origem.y
	var x1 := origem.x + tamanho.x
	var z1 := origem.y + tamanho.y
	quadrilatero(Vector3(x0, altura, z0), Vector3(x1, altura, z0), Vector3(x1, altura, z1), Vector3(x0, altura, z1), cor)

## Telhado de duas águas sobre uma base retangular: 2 triângulos por água + 2 oitões.
func telhado(origem: Vector2, tamanho: Vector2, base: float, altura: float, cor: Color, cor_oitao: Color) -> void:
	var x0 := origem.x
	var z0 := origem.y
	var x1 := origem.x + tamanho.x
	var z1 := origem.y + tamanho.y
	var meio := (z0 + z1) * 0.5
	var topo := base + altura
	quadrilatero(Vector3(x0, base, z0), Vector3(x1, base, z0), Vector3(x1, topo, meio), Vector3(x0, topo, meio), cor)
	quadrilatero(Vector3(x1, base, z1), Vector3(x0, base, z1), Vector3(x0, topo, meio), Vector3(x1, topo, meio), cor.darkened(0.12))
	triangulo(Vector3(x0, base, z1), Vector3(x0, base, z0), Vector3(x0, topo, meio), cor_oitao)
	triangulo(Vector3(x1, base, z0), Vector3(x1, base, z1), Vector3(x1, topo, meio), cor_oitao)

## Cilindro de poucos lados (postes, potes, rodas). `lados` costuma ser 5 ou 6.
func cilindro(centro: Vector3, raio: float, altura: float, lados: int, cor: Color, cor_topo: Color) -> void:
	var anterior := Vector3(centro.x + raio, centro.y, centro.z)
	for i in range(1, lados + 1):
		var a := TAU * i / lados
		var atual := Vector3(centro.x + cos(a) * raio, centro.y, centro.z + sin(a) * raio)
		quadrilatero(anterior, anterior + Vector3(0, altura, 0), atual + Vector3(0, altura, 0), atual, cor)
		triangulo(Vector3(centro.x, centro.y + altura, centro.z), anterior + Vector3(0, altura, 0), atual + Vector3(0, altura, 0), cor_topo)
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
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malha
