extends SceneTree

## Resgate da irmã (portão, ela segue até em casa, efeitos), água contaminada
## sorteada (ferver ou passar mal, notícia que diz a verdade) e os rádios.
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

func mudar_para(dia: int, periodo: int) -> void:
	if jogo.ciclo.dia != dia:
		jogo.ciclo.dia = dia
		jogo.virar_o_dia(dia)
	jogo.ciclo.horas = Ciclo3D.DORME - int(Ciclo3D.COMECO_DOS_PERIODOS[periodo])
	jogo.ciclo.mudou.emit()
	await physics_frame

func rodar() -> void:
	jogo = load("res://scenes/mundo3d.tscn").instantiate()
	root.add_child(jogo)
	current_scene = jogo
	await process_frame
	await physics_frame

	# --- A casa e o portão.
	checar(jogo.porta_da_irma != null and jogo.casa_da_irma != null, "casa da irmã com portão marcado")
	checar(jogo.casa_da_irma != null and jogo.casa_da_irma.global_position.x < -30, "casa amarela no fim da rua, depois do mercadinho")
	checar(jogo.irma != null and not jogo.irma.visible, "antes do resgate ela não está na sua casa")

	# Visita antes do breu: fala e encerra, sem levar ninguém.
	await mudar_para(2, 0)
	jogo.chamar_a_irma()
	checar(jogo.dialogo.visible and jogo.dialogo.caminho_do_retrato == jogo.RETRATO_DA_IRMA, "visita: ela atende no portão")
	fechar_falas()
	checar(not jogo.dialogo.visible and jogo.irma.seguindo == null, "visita termina sem resgate")

	# Mensagens: o pedido chega no breu.
	var textos: Array = jogo.mensagens.caixa(6, {}, "Irmã", []).map(func(m): return String(m.texto))
	checar(textos.any(func(t): return t.contains("vem me buscar")), "no breu ela pede para ser buscada")

	# --- Resgate no breu.
	await mudar_para(6, 4)
	jogo.jogador.global_position = jogo.porta_da_irma.global_position + Vector3(0, 0.1, 1.2)
	jogo.chamar_a_irma()
	fechar_falas()
	checar(jogo.escolha != null and jogo.escolha.name == "RespostaDaIrma", "no breu ela pergunta se vai junto")
	jogo.responder_a_irma("vem")
	checar(jogo.irma.seguindo == jogo.jogador and jogo.irma.visible, "ela segue o jogador")
	# Caminhando de volta: o jogador vai até a frente de casa em passos.
	var destino := Vector3(12.5, 0.1, 21.5)
	var de: Vector3 = jogo.jogador.global_position
	# Uns 5 m/s, o passo de quem corre.
	var quadros := int(de.distance_to(destino) / 5.0 * 60.0)
	for i in quadros:
		jogo.jogador.global_position = de.lerp(destino, float(i) / quadros)
		await physics_frame
	checar(jogo.irma.global_position.distance_to(jogo.jogador.global_position) < 6.0, "ela acompanhou até a frente de casa (%.1f m)" % jogo.irma.global_position.distance_to(jogo.jogador.global_position))
	# No portão ainda não conta: só quando ela atravessa a porta de casa.
	jogo.jogador.global_position = Vector3(12.5, 0.1, 18.5)
	for i in 20: await physics_frame
	checar(not jogo.ciclo.irma_em_casa, "no portão, ela ainda vem atrás (sem pular para dentro)")
	jogo.jogador.global_position = jogo.CASA_LUGAR + Vector3(0.0, 0.3, 2.5)
	jogo.irma.global_position = jogo.CASA_LUGAR + Vector3(1.2, 0.2, 3.5)
	await physics_frame
	await physics_frame
	checar(jogo.ciclo.irma_em_casa and jogo.ciclo.tem_radio, "atravessou a porta: ela fica e traz o rádio")
	checar(jogo.irma_indo_pro_lugar and jogo.irma.seguindo != jogo.jogador, "e vai andando para o lugar dela, sem teletransporte")
	var limite := Time.get_ticks_msec() + 12000
	while jogo.irma_indo_pro_lugar and Time.get_ticks_msec() < limite: await physics_frame
	checar(jogo.irma.seguindo == null and jogo.irma.visible, "ela para no lugar dela, na sala")
	checar(jogo.irma.global_position.distance_to(jogo.lugar_da_irma_em_casa()) < 2.0, "perto do sofá (%.1f m)" % jogo.irma.global_position.distance_to(jogo.lugar_da_irma_em_casa()))
	jogo.jogador.global_position = jogo.irma.global_position + Vector3(1.5, 0.1, 0)
	for i in 3: await physics_frame
	checar(jogo.dialogo.visible and jogo.dialogo.caminho_do_retrato == jogo.RETRATO_DA_IRMA, "em casa, ela entrega o rádio falando")
	fechar_falas()
	jogo.conversar_com_a_irma()
	checar(jogo.dialogo.visible, "na sala, ela tem o que dizer no dia")
	fechar_falas()
	jogo.conversar_com_a_irma()
	checar(not jogo.dialogo.visible, "no mesmo dia, de novo, só um comentário no balão")
	checar(jogo.ciclo.consumo_da_noite() == 4, "com ela, o breu consome 4")
	var depois: Array = jogo.mensagens.caixa(8, {}, "Irmã", []).map(func(m): return String(m.texto))
	checar(not depois.has("..."), "com ela em casa, as mensagens de longe não chegam")
	# Rádio a pilha funciona sem luz.
	jogo.ouvir_o_radio(true)
	checar(jogo.dialogo.visible and jogo.dialogo._nome.text == "Rádio a pilha", "rádio a pilha toca no breu")
	fechar_falas()
	jogo.ouvir_o_radio(false)
	checar(not jogo.dialogo.visible, "rádio da sala não liga sem luz")

	# --- Sem resgate: depois do ataque ela some.
	var outro: Node = load("res://scenes/mundo3d.tscn").instantiate()
	root.add_child(outro)
	await process_frame
	outro.ciclo.dia = 6
	outro.virar_o_dia(6)
	checar(not outro.irma_sumiu, "no breu ela ainda espera")
	outro.ciclo.dia = 7
	outro.virar_o_dia(7)
	checar(outro.irma_sumiu, "passou o breu sem resgate: no dia 7 ela sumiu")
	outro.chamar_a_irma()
	checar(not outro.dialogo.visible or outro.dialogo._nome.text != "Irmã", "no dia 7 ninguém atende o portão")
	outro.ciclo.suprimentos = 0
	outro.casa_da_irma_revirada = false
	var antes: int = outro.ciclo.suprimentos
	outro.chamar_a_irma()
	checar(outro.ciclo.suprimentos == antes and outro.dica.recado.text.contains("Ninguém atende"), "sem resgate, ninguém atende no portão dela")
	outro.queue_free()
	await process_frame

	# --- Água: sorteio por partida, ferver ou passar mal.
	var ciclo := Ciclo3D.new()
	var contaminadas := 0
	for semente in 200:
		ciclo.sortear_a_agua(semente)
		if ciclo.agua_vai_contaminar: contaminadas += 1
	checar(contaminadas > 60 and contaminadas < 140, "metade das partidas com água contaminada (%d/200)" % contaminadas)
	ciclo.agua_vai_contaminar = true
	ciclo.dia = 2
	checar(not ciclo.agua_contaminada(), "antes do dia 3 a água é boa")
	ciclo.dia = 3
	ciclo.suprimentos = 5
	checar(ciclo.agua_contaminada() and ciclo.guardar_agua(false) and ciclo.passou_mal, "sem ferver: vai passar mal")
	ciclo.dormir([])
	checar(ciclo.fraqueza == 1 and ciclo.hora() == 11, "a água fez mal: acorda fraco")
	ciclo.dia = 4
	ciclo.fraqueza = 0
	var horas_antes := ciclo.horas
	checar(ciclo.guardar_agua(true) and ciclo.horas == horas_antes - 2, "ferver custa 2h")
	checar(not ciclo.passou_mal, "fervida não adoece")
	ciclo.free()
	# O noticiário conta a verdade da partida.
	var noticias := Noticias3D.new()
	noticias.estado = {"agua_vai_contaminar": true}
	var tv: Array = noticias.do_dia(3).telejornal.map(func(f): return String(f[2]))
	checar(tv.any(func(t): return t.contains("contaminadas")) and not tv.any(func(t): return t.contains("vieram limpas")), "água ruim: a TV diz contaminada")
	noticias.estado = {"agua_vai_contaminar": false}
	tv = noticias.do_dia(3).telejornal.map(func(f): return String(f[2]))
	checar(tv.any(func(t): return t.contains("vieram limpas")) and not tv.any(func(t): return t.contains("contaminadas")), "água boa: a TV diz limpa")

	print("IRMÃ: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
