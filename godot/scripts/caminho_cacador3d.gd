extends RefCounted

# Navegação local sobre os colisores reais; independente dos pedestres.
const PASSO := 0.35
const MASCARA := 1 | 2 | 4 | 32 | 64
var _capsula := CapsuleShape3D.new()

func _init() -> void:
	_capsula.radius = 0.34
	# O fundo da consulta fica acima do degrau máximo. A cápsula física tem
	# altura completa e vencer_degrau só assenta em piso baixo e caminhável.
	_capsula.height = 1.54

func consulta(corpo: CharacterBody3D, ponto: Vector3, mascara := MASCARA) -> PhysicsShapeQueryParameters3D:
	var teste := PhysicsShapeQueryParameters3D.new()
	teste.shape = _capsula
	teste.transform = Transform3D(Basis.IDENTITY, ponto + Vector3.UP * 1.04)
	teste.collision_mask = mascara
	var exclusoes: Array[RID] = [corpo.get_rid()]
	# O destino perto do jogador não é obstáculo do planejamento.
	# move_and_slide continua colidindo com seu corpo.
	if "jogador" in corpo and is_instance_valid(corpo.jogador): exclusoes.append(corpo.jogador.get_rid())
	teste.exclude = exclusoes
	return teste

func piso(corpo: CharacterBody3D, ponto: Vector3) -> Dictionary:
	var raio := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 0.3, ponto + Vector3.DOWN * 0.45, 1)
	return corpo.get_world_3d().direct_space_state.intersect_ray(raio)

func apoiado(corpo: CharacterBody3D, ponto: Vector3, area: Rect2) -> bool:
	if not area.grow(-0.34).has_point(Vector2(ponto.x, ponto.z)): return false
	var apoio := piso(corpo, ponto)
	if apoio.is_empty() or (apoio.normal as Vector3).y < 0.7: return false
	if absf((apoio.position as Vector3).y - ponto.y) > 0.25: return false
	var assentado := Vector3(ponto.x, (apoio.position as Vector3).y, ponto.z)
	return corpo.get_world_3d().direct_space_state.intersect_shape(consulta(corpo, assentado), 1).is_empty()

func alcance_desimpedido(corpo: CharacterBody3D, ponto: Vector3) -> bool:
	var teste := consulta(corpo, corpo.global_position, 1)
	teste.motion = ponto - corpo.global_position
	return corpo.get_world_3d().direct_space_state.cast_motion(teste)[0] > 0.999

func livre(corpo: CharacterBody3D, de: Vector3, para: Vector3, area: Rect2) -> bool:
	var espaco := corpo.get_world_3d().direct_space_state
	# O fundo da consulta já ignora apenas os degraus baixos.
	var teste := consulta(corpo, de)
	teste.motion = Vector3(para.x - de.x, 0, para.z - de.z)
	if espaco.cast_motion(teste)[0] < 0.999: return false
	var passos := maxi(1, ceili(Vector2(para.x - de.x, para.z - de.z).length() / 0.25))
	for i in range(1, passos + 1):
		if not apoiado(corpo, de.lerp(para, float(i) / passos), area): return false
	return true

## Cenário fixo por célula da grade do mundo: altura do piso caminhável e se a
## cápsula cabe ali sem contar os corpos que andam (INF = sem lugar). É a parte
## cara do planejamento; os corpos móveis são conferidos à parte, só quando há
## algum por perto. A memória vence sozinha (o comércio fecha, o dia muda) e
## esquecer() a limpa na hora.
static var _cenario := {}
static var _cenario_desde := 0
const VALIDADE_CENARIO := 600
const MOVEIS := 4 | 32 | 64

static func esquecer() -> void:
	_cenario.clear()

func cenario(corpo: CharacterBody3D, celula: Vector2i) -> float:
	if _cenario.has(celula): return _cenario[celula]
	var ponto := Vector3(celula.x * PASSO, 0.0, celula.y * PASSO)
	var espaco := corpo.get_world_3d().direct_space_state
	var raio := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 0.55, ponto + Vector3.DOWN * 0.45, 1)
	var apoio := espaco.intersect_ray(raio)
	var altura := INF
	if not apoio.is_empty() and (apoio.normal as Vector3).y >= 0.7:
		var assentado := Vector3(ponto.x, (apoio.position as Vector3).y, ponto.z)
		if espaco.intersect_shape(consulta(corpo, assentado, 1), 1).is_empty():
			altura = assentado.y
	_cenario[celula] = altura
	return altura

func calcular(corpo: CharacterBody3D, destino: Vector3, area: Rect2) -> PackedVector3Array:
	var origem := corpo.global_position
	if livre(corpo, origem, destino, area): return PackedVector3Array([destino])
	if Engine.get_physics_frames() - _cenario_desde > VALIDADE_CENARIO or Engine.get_physics_frames() < _cenario_desde:
		_cenario.clear()
		_cenario_desde = Engine.get_physics_frames()
	var faixa := Rect2(Vector2(minf(origem.x, destino.x), minf(origem.z, destino.z)), Vector2(absf(destino.x - origem.x), absf(destino.z - origem.z))).grow(3.5).intersection(area.grow(-0.34))
	if faixa.size.x <= 0 or faixa.size.y <= 0: return PackedVector3Array()
	# A grade fica presa às linhas do mundo, para as células se repetirem entre
	# um cálculo e outro e a memória do cenário servir.
	var canto := Vector2i(ceili(faixa.position.x / PASSO), ceili(faixa.position.y / PASSO))
	var ponta := Vector2i(floori(faixa.end.x / PASSO), floori(faixa.end.y / PASSO))
	if ponta.x <= canto.x or ponta.y <= canto.y: return PackedVector3Array()
	var grade := AStarGrid2D.new()
	grade.region = Rect2i(Vector2i.ZERO, ponta - canto + Vector2i.ONE)
	grade.cell_size = Vector2(PASSO, PASSO)
	grade.offset = Vector2(canto) * PASSO
	grade.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grade.update()
	var espaco := corpo.get_world_3d().direct_space_state
	# Só confere célula a célula os corpos que andam se houver algum na faixa.
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(faixa.size.x + 1.0, 2.0, faixa.size.y + 1.0)
	var varredura := PhysicsShapeQueryParameters3D.new()
	varredura.shape = caixa
	varredura.transform = Transform3D(Basis.IDENTITY, Vector3(faixa.get_center().x, origem.y + 1.0, faixa.get_center().y))
	varredura.collision_mask = MOVEIS
	varredura.exclude = consulta(corpo, origem).exclude
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
			var altura := cenario(corpo, canto + id)
			var bloqueado := altura == INF or absf(altura - origem.y) > 0.25
			if not bloqueado and com_moveis:
				bloqueado = not espaco.intersect_shape(consulta(corpo, Vector3(p.x, altura, p.y), MOVEIS), 1).is_empty()
			grade.set_point_solid(id, bloqueado)
			if bloqueado: continue
			alturas[id] = altura
			var a := Vector2(origem.x, origem.z).distance_squared_to(p)
			if a < perto_inicio:
				perto_inicio = a
				inicio = id
			var b := Vector2(destino.x, destino.z).distance_squared_to(p)
			if b < perto_fim:
				perto_fim = b
				fim = id
	if alturas.is_empty() or perto_inicio > 0.4 or perto_fim > 0.4: return PackedVector3Array()
	var rota := PackedVector3Array()
	for id: Vector2i in grade.get_id_path(inicio, fim):
		var p := grade.get_point_position(id)
		rota.append(Vector3(p.x, float(alturas[id]), p.y))
	return rota
