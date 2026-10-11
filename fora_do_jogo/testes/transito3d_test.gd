extends SceneTree

const PESSOA := preload("res://scripts/pessoa3d.gd")
const JOGADOR := preload("res://scripts/jogador3d.gd")
var falhas := 0
var verificacoes := 0
var fixture: Node3D

func _initialize() -> void:
	# Acelera a execução mantendo o mesmo passo de física do jogo (1/60 s).
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	call_deferred("rodar")

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

func quadros(n: int) -> void:
	for i in n: await physics_frame

func novo() -> void:
	fixture = Node3D.new()
	root.add_child(fixture)
	caixa(Vector3(0, -0.1, 0), Vector3(80, 0.2, 12))

func limpar() -> void:
	fixture.queue_free()
	await process_frame
	await process_frame

func caixa(p: Vector3, tamanho: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = tamanho
	forma.shape = volume
	corpo.add_child(forma)
	corpo.position = p
	fixture.add_child(corpo)
	return corpo

func pessoa(p: Vector3, sentido := 1.0, parada := false) -> CharacterBody3D:
	var npc := PESSOA.new()
	npc.quem = "marquinhos"
	npc.linha_z = 0.0
	npc.limites = Vector2(-15, 15)
	npc.sentido = sentido
	npc.parada = parada
	npc.position = p
	fixture.add_child(npc)
	return npc

func jogador(p: Vector3) -> CharacterBody3D:
	var ator := JOGADOR.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	ator.add_child(camera)
	ator.position = p
	fixture.add_child(ator)
	ator.prender_mouse(false)
	return ator

func carro(p: Vector3, velocidade := 8.0) -> Carro3D:
	var veiculo := Carro3D.new()
	veiculo.modelo = Carro3D.MODELOS[0]
	veiculo.altura_da_pista = 0.0
	veiculo.linha_z = 0.0
	veiculo.limites = Vector2(-100, 100)
	veiculo.velocidade = velocidade
	veiculo.velocidade_alvo = velocidade
	veiculo.position = p
	fixture.add_child(veiculo)
	return veiculo

func perto_caixa(p: Vector3, centro: Vector3, tamanho: Vector3) -> float:
	return Vector2(maxf(absf(p.x - centro.x) - tamanho.x * 0.5, 0.0), maxf(absf(p.z - centro.z) - tamanho.z * 0.5, 0.0)).length()

func rodar() -> void:
	novo()
	print("TRÂNSITO: banco, mesa e parede lateral")
	var banco_pos := Vector3(0, 0.45, 0)
	var banco_tam := Vector3(1.8, 0.9, 1.6)
	var mesa_pos := Vector3(3.2, 0.5, 0)
	var mesa_tam := Vector3(1.0, 1.0, 1.1)
	caixa(banco_pos, banco_tam)
	caixa(mesa_pos, mesa_tam)
	# O vão entre banco e parede é menor que o diâmetro da cápsula: só o
	# outro lado permite passagem. Não basta preferir um lado por convenção.
	caixa(Vector3(1, 1, -1.4), Vector3(16, 2, 0.3))
	var npc := pessoa(Vector3(-5, 0, 0))
	await quadros(3)
	var lateral := 0.0
	var distancia := INF
	for i in 780:
		await physics_frame
		lateral = maxf(lateral, npc.position.z)
		distancia = minf(distancia, perto_caixa(npc.position, banco_pos, banco_tam))
		distancia = minf(distancia, perto_caixa(npc.position, mesa_pos, mesa_tam))
	checar(npc.position.x > 6.0, "passa pelo banco e pela mesa")
	checar(lateral > banco_tam.z * 0.5 + 0.24 and lateral <= 2.1, "contorna pelo lado livre da calçada")
	checar(distancia >= 0.25, "não atravessa os móveis")
	checar(absf(npc.position.z) < 0.35, "retorna à linha depois do contorno")
	await limpar()

	novo()
	print("TRÂNSITO: cruzamento de pedestres")
	var a := pessoa(Vector3(-3.5, 0, 0), 1.0)
	var b := pessoa(Vector3(3.5, 0, 0), -1.0)
	await quadros(3)
	var separacao := INF
	for i in 600:
		await physics_frame
		separacao = minf(separacao, Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length())
	checar(a.position.x > 3.0 and b.position.x < -3.0, "pedestres cruzam e continuam andando")
	print("CRUZAMENTO a=", a.position, " rumo=", a.sentido, " b=", b.position, " rumo=", b.sentido)
	checar(separacao >= 0.50, "pedestres não se atravessam")
	await limpar()

	novo()
	print("TRÂNSITO: jogador bloqueado pelo NPC")
	npc = pessoa(Vector3.ZERO, 1.0, true)
	var ator := jogador(Vector3(-2, 0, 0))
	await quadros(3)
	Input.action_press("andar_direita")
	await quadros(90)
	Input.action_release("andar_direita")
	checar(ator.position.x < -0.50 and ator.position.x > -0.8, "jogador esbarra no NPC")
	checar(absf(npc.position.x) < 0.02, "NPC parado não é arrastado")
	npc.aparecer(false)
	Input.action_press("andar_direita")
	await quadros(70)
	Input.action_release("andar_direita")
	checar(ator.position.x > 1.0, "NPC oculto não deixa colisão invisível")
	await limpar()

	novo()
	print("TRÂNSITO: jogador bloqueado pelo carro")
	var veiculo := carro(Vector3.ZERO, 0.0)
	ator = jogador(Vector3(-5.0, 0, 0))
	await quadros(3)
	Input.action_press("andar_direita")
	await quadros(150)
	Input.action_release("andar_direita")
	var corpo_carro: AABB = veiculo.global_transform * AABB(veiculo._centro - veiculo._volume.size / 2.0, veiculo._volume.size)
	checar(ator.position.x <= corpo_carro.position.x - 0.25, "jogador não entra no carro")
	checar(ator.position.x >= corpo_carro.position.x - 0.6, "colisão corresponde ao modelo do carro")
	await limpar()

	novo()
	print("TRÂNSITO: carro freia diante do jogador e volta a andar")
	veiculo = carro(Vector3(-7, 0, 0), 9.0)
	ator = jogador(Vector3(4.0, 0, 0))
	ator.set_physics_process(false)
	await quadros(3)
	var invasao := false
	for i in 480:
		await physics_frame
		corpo_carro = veiculo.global_transform * AABB(veiculo._centro - veiculo._volume.size / 2.0, veiculo._volume.size)
		if corpo_carro.end.x > ator.position.x - 0.27: invasao = true
	checar(not invasao, "carro não atravessa nem empurra o jogador")
	checar(veiculo.velocidade < 0.15, "carro freia até parar")
	ator.position.z = 3.0
	await quadros(300)
	print("RETOMADA carro=", veiculo.position, " velocidade=", veiculo.velocidade, " jogador=", ator.position)
	checar(veiculo.position.x > 7.0, "carro retoma a viagem quando a faixa libera")
	await limpar()

	novo()
	print("TRÂNSITO: carro freia diante do pedestre")
	veiculo = carro(Vector3(-7, 0, 0), 9.0)
	npc = pessoa(Vector3(4, 0, 0), 1.0, true)
	await quadros(480)
	corpo_carro = veiculo.global_transform * AABB(veiculo._centro - veiculo._volume.size / 2.0, veiculo._volume.size)
	checar(corpo_carro.end.x < npc.position.x - 0.27, "carro respeita o pedestre na faixa")
	checar(veiculo.velocidade < 0.15, "carro para diante do NPC")
	npc.aparecer(false)
	await quadros(300)
	checar(veiculo.position.x > 7.0, "trânsito libera quando o NPC sai")
	await limpar()

	novo()
	print("TRÂNSITO: veículos do comboio também respeitam colisões")
	var militar := Militar3D.new()
	militar.tipo = Militar3D.Tipo.CAMINHAO
	militar.altura_da_pista = 0.0
	militar.linha_z = 0.0
	militar.limites = Vector2(-100, 100)
	militar.velocidade_alvo = 6.0
	militar.velocidade = 6.0
	militar.position.x = -10
	fixture.add_child(militar)
	ator = jogador(Vector3(4, 0, 0))
	ator.set_physics_process(false)
	await quadros(600)
	var volume_militar: AABB = militar.global_transform * AABB(militar._centro - militar._volume.size / 2.0, militar._volume.size)
	checar(volume_militar.end.x < ator.position.x - 0.27, "comboio não atravessa o jogador")
	checar(militar.velocidade < 0.2, "comboio para diante do jogador")
	ator.position.z = 4.0
	await quadros(420)
	checar(militar.position.x > 7.0, "comboio retoma quando a faixa libera")
	await limpar()

	novo()
	print("TRÂNSITO: pedestre contorna o jogador")
	npc = pessoa(Vector3(-4, 0, 0))
	ator = jogador(Vector3.ZERO)
	ator.set_physics_process(false)
	await quadros(570)
	checar(npc.position.x > 4.0, "pedestre passa pelo jogador parado")
	await limpar()

	print("TRÂNSITO: calçada fechada")
	novo()
	caixa(Vector3(0, 1, 0), Vector3(0.4, 2, 5))
	npc = pessoa(Vector3(-3, 0, 0))
	await quadros(420)
	checar(npc.position.x < -2.0 and npc.sentido < 0.0, "volta pelo trecho livre quando não existe passagem")
	await limpar()

	print("TRÂNSITO: bairro real e calendário")
	var jogo := (load("res://scenes/mundo3d.tscn") as PackedScene).instantiate()
	root.add_child(jogo)
	current_scene = jogo
	await quadros(4)
	var na_calcada := Transform3D(Basis.IDENTITY, Vector3(-0.6, 0.01, 21.8))
	checar(not jogo.jogador.test_move(na_calcada, Vector3(2, 0, 0)), "área de interação do ônibus não bloqueia a calçada")
	var mira := PhysicsRayQueryParameters3D.create(Vector3(1, 1, 22.5), Vector3(1, 1, 21.0))
	var achado: Dictionary = jogo.mundo.get_world_3d().direct_space_state.intersect_ray(mira)
	checar(not achado.is_empty() and achado.collider.has_meta("ponto"), "ponto de ônibus continua acessível à interação")
	var pedestres := []
	var percurso := {}
	var anterior := {}
	for pessoa_atual in get_nodes_in_group("pessoas3d"):
		if pessoa_atual.name == "Irma": continue
		pedestres.append(pessoa_atual)
		percurso[pessoa_atual] = 0.0
		anterior[pessoa_atual] = pessoa_atual.global_position
	for i in 1200:
		await physics_frame
		for pessoa_atual: CharacterBody3D in pedestres:
			var antes: Vector3 = anterior[pessoa_atual]
			percurso[pessoa_atual] += Vector2(pessoa_atual.global_position.x - antes.x, pessoa_atual.global_position.z - antes.z).length()
			anterior[pessoa_atual] = pessoa_atual.global_position
	for pessoa_atual in pedestres:
		checar(float(percurso[pessoa_atual]) > 6.0, "pedestre progride no bairro: " + String(pessoa_atual.name))
		checar(pessoa_atual.collision_mask & 2 != 0 and jogo.jogador.collision_mask & 4 != 0, "colisão recíproca com jogador")
	jogo.ciclo.dia = 6
	jogo.virar_o_dia(6)
	await quadros(3)
	for pessoa_atual in pedestres:
		checar(not pessoa_atual.visible and pessoa_atual.collision_layer == 0, "breu retira colisões de pedestres ausentes")
	checar(jogo.corpos.get_child_count() == 10, "corpos do breu preservados")
	jogo.queue_free()
	await process_frame
	print("TRÂNSITO: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
