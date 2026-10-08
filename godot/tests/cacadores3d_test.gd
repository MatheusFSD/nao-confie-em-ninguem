extends SceneTree

const CACADOR := preload("res://scripts/cacador3d.gd")
const MUNDO := preload("res://scripts/mundo3d.gd")
const BECOS := preload("res://scripts/becos3d.gd")
var fixture: Node3D
var falhas := 0
var verificacoes := 0

func _initialize() -> void:
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

func novo(com_piso := true) -> void:
	fixture = Node3D.new()
	root.add_child(fixture)
	if com_piso: caixa(Vector3(0, -0.1, 0), Vector3(30, 0.2, 20))

func limpar() -> void:
	fixture.queue_free()
	CACADOR.CAMINHO.esquecer()
	await process_frame
	await process_frame

func alvo(p: Vector3) -> CharacterBody3D:
	var ator := CharacterBody3D.new()
	ator.collision_layer = 2
	ator.collision_mask = 1 | 64
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.28
	capsula.height = 1.7
	forma.shape = capsula
	forma.position.y = 0.85
	ator.add_child(forma)
	ator.position = p
	fixture.add_child(ator)
	return ator

func cacador(p: Vector3, player: CharacterBody3D = null) -> Cacador3D:
	var ator := CACADOR.new()
	ator.area_caminhada = Rect2(-14, -9, 28, 18)
	ator.jogador = player
	ator.position = p
	fixture.add_child(ator)
	ator._sorte.seed = 4261
	return ator

func validar_becos_reais() -> void:
	print("CAÇADORES: quatro percursos estreitos com os modelos reais")
	novo(false)
	var casario := load("res://scenes/casario.tscn").instantiate() as Node3D
	fixture.add_child(casario)
	var guia := casario.get_node("GuiaRua")
	casario.remove_child(guia)
	guia.free()
	var rua := RuaModelo.instanciar(fixture, 28.2, 8.62, -0.15, Vector2(320, 213))
	RuaModelo.tirar_casario(rua, Vector2(-90, 106))
	RuaModelo.tirar_tampas(rua, 0)
	var resultado := BECOS.construir(fixture, Vector2(320, 213))
	for segmento: Vector2 in BECOS.segmentos_fechados(Vector2(-46, 62), resultado["entradas"]):
		BECOS.caixa(fixture, "LimiteCalcada", Vector3((segmento.x + segmento.y) / 2, 3, 37.6), Vector3(segmento.y - segmento.x, 6, 0.4), false, Vector2(320, 213))
	await quadros(3)
	checar(resultado["rotas"].size() >= 1, "rotas de becos disponíveis para caçadores")
	for i in resultado["rotas"].size():
		var rota: PackedVector3Array = resultado["rotas"][i]
		var bicho := cacador(rota[0])
		bicho.area_caminhada = Rect2(-46, 19, 108, 33)
		bicho.set_physics_process(false)
		await quadros(3)
		for j in rota.size() - 1:
			checar(bicho._guia.livre(bicho, rota[j], rota[j + 1], bicho.area_caminhada), "cápsula tem piso e passagem no beco %d trecho %d" % [i, j])
			bicho._destino = rota[j + 1]
			bicho._caminho = bicho._guia.calcular(bicho, rota[j + 1], bicho.area_caminhada)
			bicho._pausa = 0.0
			bicho.set_physics_process(true)
			var chegou := false
			var caiu := false
			for quadro in 720:
				await physics_frame
				caiu = caiu or bicho.position.y < -0.25
				if Vector2(bicho.position.x - rota[j + 1].x, bicho.position.z - rota[j + 1].z).length() < 0.22:
					chegou = true
					break
			bicho.set_physics_process(false)
			checar(chegou, "caçador atravessa fisicamente beco %d trecho %d e vira a esquina" % [i, j])
			checar(not caiu, "caçador mantém apoio ao contornar beco %d trecho %d" % [i, j])
		bicho.queue_free()
		await quadros(3)
	await limpar()

func rodar() -> void:
	novo()
	print("CAÇADORES: proximidade cega e memória limitada")
	var player := alvo(Vector3(8, 0, 0))
	var bicho := cacador(Vector3.ZERO, player)
	bicho.set_physics_process(false)
	await quadros(3)
	checar(not bicho.percebe_jogador(), "não percebe jogador distante no campo aberto")
	player.position = Vector3(-2, 0, 0)
	bicho.rotation.y = PI / 2.0
	await quadros(2)
	checar(bicho.percebe_jogador(), "percebe proximidade por trás, sem cone visual")
	bicho.atualizar_percepcao(0.1)
	checar(bicho._estado == "perseguir", "contato inicia perseguição")
	var lembrado := bicho._ultima_proximidade
	player.position = Vector3(-8, 0, 4)
	await quadros(2)
	bicho.atualizar_percepcao(0.5)
	checar(bicho._estado == "buscar", "fora do alcance busca local lembrado")
	checar(bicho._ultima_proximidade == lembrado, "não rastreia jogador distante")
	bicho.atualizar_percepcao(1.6)
	checar(bicho._estado == "vagar", "perde contato após dois segundos")
	player.position = Vector3(1.7, 0, 0)
	var parede := caixa(Vector3(0.85, 1, 0), Vector3(0.2, 2, 6))
	await quadros(3)
	checar(not bicho.percebe_jogador(), "parede sólida bloqueia proximidade através da casa")
	player.position = Vector3(8, 0, 0)
	await quadros(2)
	checar(not bicho.percebe_jogador(), "jogador distante atrás de parede não é percebido")
	parede.queue_free()
	await quadros(3)
	player.position = Vector3(2.2, 0, 0)
	await quadros(2)
	bicho.set_physics_process(true)
	var distancia_inicial := bicho.position.distance_to(player.position)
	await quadros(150)
	checar(bicho.position.distance_to(player.position) < distancia_inicial - 0.7, "perseguição aproxima fisicamente")
	checar(bicho.position.distance_to(player.position) >= 0.59, "não atravessa corpo do jogador")
	player.hide()
	await quadros(3)
	checar(bicho._estado == "vagar", "jogador oculto deixa de ser alvo imediatamente")
	player.show()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await quadros(3)
	checar(not bicho.percebe_jogador(), "jogador suspenso no abrigo não é alvo")
	await limpar()

	novo()
	print("CAÇADORES: desvio de obstáculos e piso")
	caixa(Vector3(0, 1, 0), Vector3(2.2, 2, 2.4))
	bicho = cacador(Vector3(-4, 0, 0))
	bicho.set_physics_process(false)
	await quadros(3)
	var destino := Vector3(4, 0, 0)
	var rota: PackedVector3Array = bicho._guia.calcular(bicho, destino, bicho.area_caminhada)
	checar(not rota.is_empty(), "encontra rota em torno de parede")
	bicho._caminho = rota
	bicho._destino = destino
	bicho._pausa = 0.0
	bicho.set_physics_process(true)
	var lateral := 0.0
	var distancia_obstaculo := INF
	for i in 560:
		await physics_frame
		lateral = maxf(lateral, absf(bicho.position.z))
		var fora := Vector2(maxf(absf(bicho.position.x) - 1.1, 0), maxf(absf(bicho.position.z) - 1.2, 0)).length()
		distancia_obstaculo = minf(distancia_obstaculo, fora)
		if bicho.position.x > 3.6: break
	checar(bicho.position.x > 3.6, "contorna obstáculo e alcança outro lado")
	checar(lateral > 1.5, "movimento desvia lateralmente da linha original")
	checar(distancia_obstaculo >= 0.31, "cápsula não atravessa parede")
	await limpar()

	novo()
	print("CAÇADORES: corredor estreito e quina")
	caixa(Vector3(-0.85, 1, 0), Vector3(0.2, 2, 8))
	caixa(Vector3(0.85, 1, 0), Vector3(0.2, 2, 8))
	bicho = cacador(Vector3(0, 0, -3))
	bicho.set_physics_process(false)
	await quadros(3)
	destino = Vector3(0, 0, 3)
	bicho._caminho = bicho._guia.calcular(bicho, destino, bicho.area_caminhada)
	bicho._destino = destino
	bicho._pausa = 0
	bicho.set_physics_process(true)
	await quadros(260)
	checar(bicho.position.z > 2.6, "atravessa corredor útil de 1,5m")
	checar(absf(bicho.position.x) < 0.44, "corpo permanece entre paredes do beco")
	await limpar()

	novo()
	print("CAÇADORES: perseguição contorna quina sem rastrear através de parede")
	player = alvo(Vector3(0.7, 0, -0.8))
	bicho = cacador(Vector3(-1.2, 0, 0.6), player)
	bicho.set_physics_process(false)
	await quadros(3)
	bicho.atualizar_percepcao(0.1)
	checar(bicho._estado == "perseguir", "aproximação perto da quina inicia perseguição")
	var ultimo := player.position
	# Contato termina: caça somente a posição que efetivamente percebeu.
	player.position = Vector3(8, 0, 8)
	caixa(Vector3(0, 1, -1.2), Vector3(0.3, 2, 2.4))
	await quadros(2)
	# Obstáculo novo fecha o caminho: desvia rumo à posição que percebeu.
	bicho.set_physics_process(true)
	var nao_atravessou := true
	for i in 115:
		await physics_frame
		nao_atravessou = nao_atravessou and not (absf(bicho.position.x) < 0.45 and bicho.position.z < -0.05)
	checar(nao_atravessou, "busca não atravessa parede ao contornar a quina")
	checar(bicho._estado == "buscar", "busca permanece limitada ao tempo de memória")
	checar(bicho.position.x > 0.1, "busca encontra o lado oposto contornando a ponta da parede")
	await quadros(30)
	checar(bicho._estado == "vagar", "busca na quina encerra sem rastrear alvo distante")
	checar(ultimo != player.position, "alvo fugiu do local inicialmente percebido")
	await limpar()

	novo()
	print("CAÇADORES: meio-fio e suspensão do mundo")
	caixa(Vector3(3, -0.025, 0), Vector3(6, 0.25, 4))
	bicho = cacador(Vector3(-2, 0, 0))
	bicho.set_physics_process(false)
	await quadros(3)
	destino = Vector3(3, 0.1, 0)
	bicho._destino = destino
	bicho._caminho = bicho._guia.calcular(bicho, destino, bicho.area_caminhada)
	bicho._pausa = 0.0
	bicho.set_physics_process(true)
	await quadros(230)
	checar(bicho.position.x > 2.6, "sobe meio-fio para chegar à calçada")
	checar(bicho.position.y > 0.09, "assenta no piso elevado sem atravessar")
	var antes_suspender := bicho.global_position
	fixture.process_mode = Node.PROCESS_MODE_DISABLED
	fixture.hide()
	await quadros(90)
	checar(bicho.global_position == antes_suspender, "mundo suspenso no abrigo congela o caçador")
	fixture.process_mode = Node.PROCESS_MODE_INHERIT
	fixture.show()
	await limpar()

	novo(false)
	caixa(Vector3(0, -0.1, 0), Vector3(4, 0.2, 4))
	bicho = cacador(Vector3.ZERO)
	bicho.set_physics_process(false)
	await quadros(3)
	checar(not bicho._guia.apoiado(bicho, Vector3(3, 0, 0), bicho.area_caminhada), "destino no vazio é rejeitado")
	checar(bicho._guia.calcular(bicho, Vector3(3, 0, 0), bicho.area_caminhada).is_empty(), "não planeja rota para fora do piso")
	var destinos := PackedVector3Array()
	for i in 30:
		bicho.escolher_destino()
		if not bicho._caminho.is_empty(): destinos.append(bicho._destino)
	checar(destinos.size() > 8, "vagar encontra destinos sobre piso pequeno")
	var x_varia := false
	var z_varia := false
	for p in destinos:
		x_varia = x_varia or absf(p.x) > 0.6
		z_varia = z_varia or absf(p.z) > 0.6
		checar(absf(p.x) < 2 and absf(p.z) < 2, "destino aleatório mantém piso de apoio")
	checar(x_varia and z_varia, "destinos aleatórios variam nos dois eixos")
	bicho.set_physics_process(true)
	var minimo_y := 0.0
	for i in 600:
		await physics_frame
		minimo_y = minf(minimo_y, bicho.position.y)
	checar(minimo_y > -0.05, "vagar não cai no vazio")
	checar(absf(bicho.position.x) < 2 and absf(bicho.position.z) < 2, "vagar permanece em área com piso")
	await limpar()

	var jogo := MUNDO.new()
	jogo.ciclo = Ciclo3D.new()
	for registro in [[5, 0], [6, 2], [7, 0], [8, 3], [12, 3]]:
		jogo.ciclo.dia = registro[0]
		checar(jogo.quantos_cacadores_hoje() == registro[1], "calendário de caçadores dia %d" % registro[0])
	jogo.ciclo.free()
	jogo.free()
	await validar_becos_reais()
	print("CAÇADORES: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas else 0)
