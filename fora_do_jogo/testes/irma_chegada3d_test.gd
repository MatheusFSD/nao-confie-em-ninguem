extends SceneTree

## A irmã chegando em casa numa partida que começou no dia 0 (com tutorial),
## andando atrás do jogador de verdade, sem teletransporte: passa o portão, a
## porta da frente, deixa de segui-lo e fica no lugar dela.
var falhas := 0
var verificacoes := 0
var jogo: Node

func _initialize() -> void:
	call_deferred("rodar")

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

func fechar_falas() -> void:
	while jogo.dialogo.visible and not jogo.dialogo.aguardando_resposta: jogo.dialogo.avancar()

## O jogador anda de `de` até `ate` a uns 4 m/s, um passo por quadro de física.
func andar(de: Vector3, ate: Vector3) -> void:
	var quadros := maxi(1, int(de.distance_to(ate) / 4.0 * 60.0))
	for i in quadros + 1:
		jogo.jogador.global_position = de.lerp(ate, float(i) / quadros)
		jogo.jogador.velocity = Vector3.ZERO
		await physics_frame

func rodar() -> void:
	jogo = load("res://scenes/mundo3d.tscn").instantiate()
	jogo.dia = 0
	root.add_child(jogo)
	current_scene = jogo
	jogo.voltar_ao_menu_no_fim = false
	for i in 4: await process_frame
	checar(jogo.tutorial != null, "a partida começa no dia 0, com o tutorial")
	fechar_falas()

	# Passa para o breu como passaria dormindo.
	jogo.ciclo.dia = 6
	jogo.virar_o_dia(6)
	jogo.ciclo.horas = Ciclo3D.DORME - int(Ciclo3D.COMECO_DOS_PERIODOS[0])
	jogo.ciclo.mudou.emit()
	await physics_frame
	checar(jogo.tutorial == null, "passado o dia 0, o tutorial sai de cena")
	for bicho in get_nodes_in_group("cacadores3d"):
		bicho.process_mode = Node.PROCESS_MODE_DISABLED
	checar(get_nodes_in_group("cacadores3d").size() == 3, "três caçadores no breu")

	# Resgate no portão dela.
	jogo.jogador.global_position = jogo.porta_da_irma.global_position + Vector3(0, 0.1, 1.2)
	jogo.chamar_a_irma()
	fechar_falas()
	jogo.responder_a_irma("vem")
	checar(jogo.irma.seguindo == jogo.jogador, "ela segue o jogador")

	# A porta da frente aberta, como o jogador deixaria ao entrar.
	var frente := -1
	for i in jogo.casa.portas.size():
		if String(jogo.casa.portas[i].nome) == "frente": frente = i
	if not jogo.casa.esta_aberta(frente): jogo.casa.acionar(frente)
	for i in 30: await physics_frame

	# Pela calçada até o portão, o quintal, a porta da frente e a sala.
	var rota := [
		jogo.jogador.global_position,
		Vector3(8.6, 0.1, 21.6),
		Vector3(8.6, 0.1, 18.2),
		Vector3(8.85, 0.1, 16.4),
		Vector3(8.85, 0.1, 14.2),
		Vector3(11.0, 0.1, 12.6),
	]
	for i in rota.size() - 1:
		await andar(rota[i], rota[i + 1])
	var limite := Time.get_ticks_msec() + 6000
	while not jogo.ciclo.irma_em_casa and Time.get_ticks_msec() < limite: await physics_frame
	checar(jogo.ciclo.irma_em_casa, "ela entrou atrás dele e chegou (%s)" % jogo.irma.global_position)
	checar(jogo.irma.seguindo != jogo.jogador, "dentro de casa, ela larga o jogador")

	# Ele vai para o quarto e ela não vai atrás.
	await andar(Vector3(11.0, 0.1, 12.6), Vector3(13.6, 0.1, 12.4))
	limite = Time.get_ticks_msec() + 12000
	while jogo.irma_indo_pro_lugar and Time.get_ticks_msec() < limite: await physics_frame
	checar(jogo.irma.seguindo == null, "ela para no lugar dela")
	var parada: Vector3 = jogo.irma.global_position
	checar(parada.distance_to(jogo.lugar_da_irma_em_casa()) < 2.0, "perto do sofá (%.1f m)" % parada.distance_to(jogo.lugar_da_irma_em_casa()))
	fechar_falas()
	await andar(Vector3(13.6, 0.1, 12.4), Vector3(10.0, 0.1, 6.0))
	for i in 60: await physics_frame
	checar(jogo.irma.global_position.distance_to(parada) < 0.3, "e fica lá quando ele anda pela casa")

	print("CHEGADA DA IRMÃ: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
