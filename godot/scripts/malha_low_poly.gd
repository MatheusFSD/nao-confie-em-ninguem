class_name MalhaLowPoly
extends RefCounted

# Construtor de malhas low poly: junta tudo em UMA malha, com textura de atlas e
# cor por vértice. Cada face é um triângulo de verdade e as faces internas (entre
# blocos colados) não são criadas, para o total de polígonos ficar baixo.
#
# Toda face declara para que lado ela olha (`fora`). A ordem dos vértices é
# corrigida sozinha a partir disso, então nunca se vê o interior das caixas, e a
# mesma direção vira a normal usada pela luz.
#
# UV guarda a repetição em metros (1 repetição por metro) e UV2 guarda a peça do
# atlas; o shader junta os dois, então o mundo inteiro usa uma textura só.
## Peças do atlas (sprites/atlas3d.png): 4 colunas × 5 linhas.
enum Peca { REBOCO, PINTADO, TIJOLO, TELHA, ASFALTO, CALCADA, CIMENTO, TERRA, TACO, AZULEJO, METAL, VIDRO, PORTA, TECIDO, FOLHA, LISO, ROSTO, CABELO, CAMISA, CALCA }
const COLUNAS := 4
## Lado máximo de uma face, em metros, antes de ela ser picada em pedaços.
const PEDACO := 2.0

var _vertices := PackedVector3Array()
var _cores := PackedColorArray()
var _normais := PackedVector3Array()
var _uvs := PackedVector2Array()
var _uvs2 := PackedVector2Array()

func total_triangulos() -> int:
	return _vertices.size() / 3

static func peca_uv(peca: int) -> Vector2:
	return Vector2(peca % COLUNAS, peca / COLUNAS)

## No Godot a face da frente é a de ordem horária vista de fora: o produto
## vetorial dos vértices aponta para DENTRO da peça.
func _ordem_correta(a: Vector3, b: Vector3, c: Vector3, fora: Vector3) -> bool:
	return (b - a).cross(c - a).dot(fora) <= 0.0

func _empurrar(p: Vector3, uv: Vector2, cor: Color, normal: Vector3, canto: Vector2) -> void:
	_vertices.append(p)
	_cores.append(cor)
	_normais.append(normal)
	_uvs.append(uv)
	_uvs2.append(canto)

## Triângulo com normal plana (visual facetado do PS1).
func triangulo(a: Vector3, b: Vector3, c: Vector3, cor: Color, peca := Peca.LISO, uv_a := Vector2.ZERO, uv_b := Vector2.ZERO, uv_c := Vector2.ZERO, fora := Vector3.ZERO) -> void:
	var normal := (c - a).cross(b - a)
	if normal.length_squared() < 0.000001: return
	if fora == Vector3.ZERO: fora = normal.normalized()
	else: fora = fora.normalized()
	var canto := peca_uv(peca)
	if _ordem_correta(a, b, c, fora):
		_empurrar(a, uv_a, cor, fora, canto)
		_empurrar(b, uv_b, cor, fora, canto)
		_empurrar(c, uv_c, cor, fora, canto)
	else:
		_empurrar(c, uv_c, cor, fora, canto)
		_empurrar(b, uv_b, cor, fora, canto)
		_empurrar(a, uv_a, cor, fora, canto)

## Quatro cantos de uma face plana; `fora` é o lado visível. A textura repete a
## cada metro. Faces grandes são picadas em pedaços de PEDACO metros: com a
## textura afim do PS1, um quadrilátero grande escorre a imagem na diagonal, que
## era o que entortava o chão e as paredes compridas.
func quadrilatero(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cor: Color, peca := Peca.LISO, fora := Vector3.ZERO) -> void:
	var largura := a.distance_to(b)
	var altura := b.distance_to(c)
	var colunas := maxi(1, int(ceil(largura / PEDACO)))
	var linhas := maxi(1, int(ceil(altura / PEDACO)))
	for i in colunas:
		for j in linhas:
			var u0 := float(i) / colunas
			var u1 := float(i + 1) / colunas
			var v0 := float(j) / linhas
			var v1 := float(j + 1) / linhas
			var p0 := _no_quadrilatero(a, b, c, d, u0, v0)
			var p1 := _no_quadrilatero(a, b, c, d, u1, v0)
			var p2 := _no_quadrilatero(a, b, c, d, u1, v1)
			var p3 := _no_quadrilatero(a, b, c, d, u0, v1)
			var uv0 := Vector2(largura * u0, altura * v0)
			var uv1 := Vector2(largura * u1, altura * v0)
			var uv2 := Vector2(largura * u1, altura * v1)
			var uv3 := Vector2(largura * u0, altura * v1)
			triangulo(p0, p1, p2, cor, peca, uv0, uv1, uv2, fora)
			triangulo(p0, p2, p3, cor, peca, uv0, uv2, uv3, fora)

## Ponto dentro do quadrilátero: u corre de a para b, v corre de a para d.
func _no_quadrilatero(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float, v: float) -> Vector3:
	return a.lerp(b, u).lerp(d.lerp(c, u), v)

## Placa visível dos dois lados (vegetação, chapas finas).
func quadrilatero_duplo(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cor: Color, peca := Peca.LISO, fora := Vector3.ZERO) -> void:
	var normal := fora if fora != Vector3.ZERO else (c - a).cross(b - a)
	quadrilatero(a, b, c, d, cor, peca, normal)
	quadrilatero(d, c, b, a, cor, peca, -normal)

## Caixa com faces escolhidas: [cima, norte(-z), sul(+z), oeste(-x), leste(+x), baixo].
func caixa(origem: Vector3, tamanho: Vector3, cor_topo: Color, cor_lado: Color, peca_topo := Peca.LISO, peca_lado := Peca.LISO, lados := [true, true, true, true, true, false]) -> void:
	var x0 := origem.x
	var x1 := origem.x + tamanho.x
	var y0 := origem.y
	var y1 := origem.y + tamanho.y
	var z0 := origem.z
	var z1 := origem.z + tamanho.z
	if lados[0]: quadrilatero(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), cor_topo, peca_topo, Vector3.UP)
	if lados[1]: quadrilatero(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), cor_lado, peca_lado, Vector3.FORWARD)
	if lados[2]: quadrilatero(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), cor_lado, peca_lado, Vector3.BACK)
	if lados[3]: quadrilatero(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), cor_lado, peca_lado, Vector3.LEFT)
	if lados[4]: quadrilatero(Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), cor_lado, peca_lado, Vector3.RIGHT)
	if lados[5]: quadrilatero(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), cor_lado, peca_lado, Vector3.DOWN)

## Chão plano: um quadrilátero só, por maior que seja a área.
func piso(origem: Vector2, tamanho: Vector2, altura: float, cor: Color, peca := Peca.LISO) -> void:
	var x0 := origem.x
	var z0 := origem.y
	var x1 := origem.x + tamanho.x
	var z1 := origem.y + tamanho.y
	quadrilatero(Vector3(x0, altura, z0), Vector3(x1, altura, z0), Vector3(x1, altura, z1), Vector3(x0, altura, z1), cor, peca, Vector3.UP)

## Telhado de duas águas: 2 águas + 2 oitões.
func telhado(origem: Vector2, tamanho: Vector2, base: float, altura: float, cor: Color, cor_oitao: Color, peca := Peca.TELHA, peca_oitao := Peca.REBOCO) -> void:
	var x0 := origem.x
	var z0 := origem.y
	var x1 := origem.x + tamanho.x
	var z1 := origem.y + tamanho.y
	var meio := (z0 + z1) * 0.5
	var topo := base + altura
	var caida := (z1 - z0) * 0.5
	var inclinacao := Vector3(0, caida, -altura).normalized()
	quadrilatero(Vector3(x0, base, z0), Vector3(x1, base, z0), Vector3(x1, topo, meio), Vector3(x0, topo, meio), cor, peca, inclinacao)
	quadrilatero(Vector3(x0, base, z1), Vector3(x1, base, z1), Vector3(x1, topo, meio), Vector3(x0, topo, meio), cor.darkened(0.1), peca, Vector3(0, caida, altura).normalized())
	triangulo(Vector3(x0, base, z0), Vector3(x0, base, z1), Vector3(x0, topo, meio), cor_oitao, peca_oitao, Vector2(0, 0), Vector2(tamanho.y, 0), Vector2(tamanho.y * 0.5, altura), Vector3.LEFT)
	triangulo(Vector3(x1, base, z0), Vector3(x1, base, z1), Vector3(x1, topo, meio), cor_oitao, peca_oitao, Vector2(0, 0), Vector2(tamanho.y, 0), Vector2(tamanho.y * 0.5, altura), Vector3.RIGHT)

## Cilindro de poucos lados (postes, potes, rodas).
func cilindro(centro: Vector3, raio: float, altura: float, lados: int, cor: Color, cor_topo: Color, peca := Peca.LISO) -> void:
	var anterior := Vector3(centro.x + raio, centro.y, centro.z)
	for i in range(1, lados + 1):
		var a := TAU * i / lados
		var atual := Vector3(centro.x + cos(a) * raio, centro.y, centro.z + sin(a) * raio)
		var meio := (anterior + atual) * 0.5
		var fora := (meio - centro)
		fora.y = 0.0
		quadrilatero(anterior, atual, atual + Vector3(0, altura, 0), anterior + Vector3(0, altura, 0), cor, peca, fora)
		triangulo(Vector3(centro.x, centro.y + altura, centro.z), anterior + Vector3(0, altura, 0), atual + Vector3(0, altura, 0), cor_topo, peca, Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0), Vector3.UP)
		anterior = atual

## Roda: cilindro deitado, girando em torno do eixo X (largura no eixo Z).
func roda(centro: Vector3, raio: float, largura: float, lados: int, cor: Color, cor_aro: Color) -> void:
	var meia := largura * 0.5
	var anterior := Vector3(0, raio, 0)
	for i in range(1, lados + 1):
		var a := TAU * i / lados
		var atual := Vector3(0, cos(a) * raio, sin(a) * raio)
		var fora := (anterior + atual) * 0.5
		var p1 := centro + anterior + Vector3(-meia, 0, 0)
		var p2 := centro + atual + Vector3(-meia, 0, 0)
		var p3 := centro + atual + Vector3(meia, 0, 0)
		var p4 := centro + anterior + Vector3(meia, 0, 0)
		quadrilatero(p1, p2, p3, p4, cor, Peca.LISO, fora)
		# Tampas dos dois lados, com a cor do aro.
		triangulo(centro + Vector3(-meia, 0, 0), p1, p2, cor_aro, Peca.METAL, Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0), Vector3.LEFT)
		triangulo(centro + Vector3(meia, 0, 0), p4, p3, cor_aro, Peca.METAL, Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0), Vector3.RIGHT)
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
