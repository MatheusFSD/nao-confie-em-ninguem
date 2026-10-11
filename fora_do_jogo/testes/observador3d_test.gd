extends SceneTree

## Observador: só surge longe e fora da vista, segue o roteiro de dias e
## períodos, some ao ser visto e desviado (ou foge quando o jogador chega
## perto), um por vez, e nunca no breu nem no ataque.
var falhas := 0
var verificacoes := 0
var jogo: Node
var obs: Observadores3D

func _initialize() -> void:
	call_deferred("rodar")

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

func mudar_para(dia: int, periodo: int) -> void:
	if jogo.ciclo.dia != dia:
		jogo.ciclo.dia = dia
		jogo.virar_o_dia(dia)
	jogo.ciclo.horas = Ciclo3D.DORME - int(Ciclo3D.COMECO_DOS_PERIODOS[periodo])
	jogo.ciclo.mudou.emit()
	await physics_frame

func olhar(para: Vector3) -> void:
	var rumo: Vector3 = para - jogo.jogador.global_position
	jogo.jogador.rotation.y = atan2(-rumo.x, -rumo.z)
	jogo.camera.rotation.x = 0.0

func esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim: await process_frame

func rodar() -> void:
	jogo = load("res://scenes/mundo3d.tscn").instantiate()
	root.add_child(jogo)
	current_scene = jogo
	await process_frame
	await physics_frame
	obs = jogo.observadores
	checar(obs != null and obs.dados.get("aparicoes", []).size() > 0, "roteiro do Observador carregado")
	# No meio da rua, em frente de casa, de costas para a ponta leste.
	jogo.jogador.global_position = Vector3(12.0, 0.1, 28.2)
	olhar(Vector3(-40, 1.6, 28.2))

	await mudar_para(1, 0)
	await esperar(1.2)
	checar(obs.atual == null, "de manhã no dia 1 ele não aparece")

	await mudar_para(1, 3)
	await esperar(1.2)
	checar(obs.atual != null and obs.atual.global_position.x > 62, "anoitecer do dia 1: surge no fim da rua, longe")
	checar(not obs.a_vista(obs.atual.global_position), "surgiu fora da vista do jogador")
	var onde: Vector3 = obs.atual.global_position
	olhar(onde + Vector3.UP * 1.9)
	await esperar(0.5)
	checar(obs._visto and obs.atual != null, "visto, ele continua lá")
	olhar(Vector3(-40, 1.6, 28.2))
	await esperar(1.0)
	checar(obs.atual == null, "desviou o olhar: ele não está mais lá")
	await esperar(1.2)
	checar(obs.atual == null, "a mesma aparição não volta no mesmo dia")

	# Breu e ataque: nunca.
	for dia in [6, 7]:
		for periodo in [0, 2, 4]:
			await mudar_para(dia, periodo)
			await esperar(0.6)
			checar(obs.atual == null, "dia %d período %d sem Observador" % [dia, periodo])
	checar(obs.possiveis(6, 4).is_empty() and obs.possiveis(7, 3).is_empty(), "roteiro vazio no breu e no ataque")

	# Noite do dia 2: na boca de um beco; chegando perto ele foge e some.
	jogo.jogador.global_position = Vector3(30.0, 0.1, 23.0)
	olhar(Vector3(30, 1.6, 0))
	await mudar_para(2, 4)
	await esperar(1.2)
	checar(obs.atual != null and obs.atual.global_position.z > 40, "noite do dia 2: surge dentro de um beco")
	if obs.atual != null:
		var lugar: Vector3 = obs.atual.global_position
		jogo.jogador.global_position = lugar + Vector3(0, 0.1, -5.0)
		await esperar(2.5)
		checar(obs.atual == null, "chegou perto: ele foge e some")

	# Mais comum com os dias: o dia 5 tem mais aparições que o dia 1.
	var por_dia := func(dia: int) -> int:
		var n := 0
		for periodo in 5: n += obs.possiveis(dia, periodo).size()
		return n
	checar(por_dia.call(5) > por_dia.call(1) and por_dia.call(10) >= por_dia.call(8), "aparições aumentam com os dias")
	checar(por_dia.call(8) > 0, "volta na cidade destruída")

	print("OBSERVADOR: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
