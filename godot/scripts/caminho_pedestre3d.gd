extends RefCounted

# Rotas curtas sobre a calçada real: consulta os colisores do mundo, incluindo
# bancos, mesas, postes, o jogador e os outros pedestres. Não depende de uma
# malha de navegação separada que ficaria desatualizada ao editar o bairro.
const PASSO := 0.45
const ALCANCE := 8.0
const MEIA_CALCADA := 2.0
const MASCARA := 1 | 2 | 4 | 32
var _capsula := CapsuleShape3D.new()

func _init() -> void:
	# Um pouco mais larga que o corpo, para deixar folga nos cantos dos móveis.
	# O fundo fica acima do piso: o chão não é um obstáculo horizontal.
	_capsula.radius = 0.30
	_capsula.height = 1.58

func consulta(corpo: CharacterBody3D, posicao: Vector3) -> PhysicsShapeQueryParameters3D:
	var teste := PhysicsShapeQueryParameters3D.new()
	teste.shape = _capsula
	teste.transform = Transform3D(Basis.IDENTITY, posicao + Vector3.UP * 0.86)
	teste.collision_mask = MASCARA
	teste.exclude = [corpo.get_rid()]
	return teste

func livre(corpo: CharacterBody3D, de: Vector3, para: Vector3) -> bool:
	var teste := consulta(corpo, de)
	teste.motion = para - de
	var espaco := corpo.get_world_3d().direct_space_state
	return espaco.cast_motion(teste)[0] > 0.999 and espaco.intersect_shape(consulta(corpo, para), 1).is_empty()

## Cenário fixo (piso e colisores do mundo) por ponto da grade, guardado entre
## um cálculo e outro: as casas e os móveis não andam, e consultá-los célula a
## célula era o que travava o jogo quando vários pedestres desviavam juntos.
## Pessoas, jogador e carros são conferidos à parte, só se houver algum perto.
static var _cenario := {}
static var _cenario_desde := 0
const VALIDADE_CENARIO := 600
const MOVEIS := 2 | 4 | 32

static func esquecer() -> void:
	_cenario.clear()

func cenario(corpo: CharacterBody3D, ponto: Vector3, espaco: PhysicsDirectSpaceState3D) -> float:
	var chave := Vector3i(roundi(ponto.x * 100.0), roundi(ponto.y * 20.0), roundi(ponto.z * 100.0))
	if _cenario.has(chave): return _cenario[chave]
	var altura := INF
	var raio := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 0.32, ponto + Vector3.DOWN * 0.65, 1)
	var piso := espaco.intersect_ray(raio)
	if not piso.is_empty() and (piso.normal as Vector3).y >= 0.7:
		var teste := consulta(corpo, ponto)
		teste.collision_mask = 1
		if espaco.intersect_shape(teste, 1).is_empty(): altura = (piso.position as Vector3).y
	_cenario[chave] = altura
	return altura

func calcular(corpo: CharacterBody3D, sentido: float, linha_z: float, limites: Vector2) -> PackedVector3Array:
	var origem := corpo.global_position
	var destino := Vector3(clampf(origem.x + sentido * ALCANCE, limites.x, limites.y), origem.y, linha_z)
	if livre(corpo, origem, destino): return PackedVector3Array([destino])
	if Engine.get_physics_frames() - _cenario_desde > VALIDADE_CENARIO or Engine.get_physics_frames() < _cenario_desde:
		_cenario.clear()
		_cenario_desde = Engine.get_physics_frames()
	# Colunas presas às linhas do mundo, para a memória do cenário servir.
	var x_min := ceilf(maxf(limites.x, minf(origem.x, destino.x) - 2.0) / PASSO) * PASSO
	var x_max := maxf(floorf(minf(limites.y, maxf(origem.x, destino.x) + 2.0) / PASSO) * PASSO, x_min + PASSO)
	var grade := AStarGrid2D.new()
	var tamanho := Vector2i(maxi(2, roundi((x_max - x_min) / PASSO) + 1), ceili(MEIA_CALCADA * 2.0 / PASSO) + 1)
	grade.region = Rect2i(Vector2i.ZERO, tamanho)
	# Distribui as linhas até as duas bordas, sem perder uma faixa de calçada
	# pelo arredondamento da grade.
	grade.cell_size = Vector2(PASSO, MEIA_CALCADA * 2.0 / (tamanho.y - 1))
	grade.offset = Vector2(x_min, linha_z - MEIA_CALCADA)
	grade.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grade.update()
	var espaco := corpo.get_world_3d().direct_space_state
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(x_max - x_min + 1.0, 2.0, MEIA_CALCADA * 2.0 + 1.0)
	var varredura := PhysicsShapeQueryParameters3D.new()
	varredura.shape = caixa
	varredura.transform = Transform3D(Basis.IDENTITY, Vector3((x_min + x_max) / 2.0, origem.y + 1.0, linha_z))
	varredura.collision_mask = MOVEIS
	varredura.exclude = [corpo.get_rid()]
	var com_moveis := not espaco.intersect_shape(varredura, 1).is_empty()
	var alturas := {}
	var inicio := Vector2i.ZERO
	var fim := Vector2i.ZERO
	var perto_inicio := INF
	var perto_fim := INF
	for x in grade.region.size.x:
		for z in grade.region.size.y:
			var id := Vector2i(x, z)
			var p := grade.get_point_position(id)
			var ponto := Vector3(p.x, origem.y, p.y)
			var altura := cenario(corpo, ponto, espaco)
			var bloqueado := altura == INF or absf(altura - origem.y) > 0.22
			if not bloqueado and com_moveis:
				var teste := consulta(corpo, ponto)
				teste.collision_mask = MOVEIS
				bloqueado = not espaco.intersect_shape(teste, 1).is_empty()
			grade.set_point_solid(id, bloqueado)
			if bloqueado: continue
			alturas[id] = altura
			# Cada um prefere sua direita ao se cruzar com outra pessoa. A rota
			# escolhida permanece até o obstáculo passar, sem oscilar de lado.
			var lateral := p.y - linha_z
			grade.set_point_weight_scale(id, 1.0 + absf(lateral) * 0.12 + (0.6 if lateral * sentido > 0.0 else 0.0))
			var a := Vector2(origem.x, origem.z).distance_squared_to(p)
			if a < perto_inicio:
				perto_inicio = a
				inicio = id
			var b := Vector2(destino.x, destino.z).distance_squared_to(p)
			if b < perto_fim:
				perto_fim = b
				fim = id
	if alturas.is_empty() or perto_inicio > 1.0: return PackedVector3Array()
	var rota := PackedVector3Array()
	for id: Vector2i in grade.get_id_path(inicio, fim):
		var p := grade.get_point_position(id)
		rota.append(Vector3(p.x, float(alturas[id]), p.y))
	return rota
