extends SceneTree

## A irmã que não foi buscada no breu volta sozinha, antes do fim: bate na
## porta de madrugada e implora. Negar três vezes: ela vai embora. Abrir: não é
## ela, e é o fim.
var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	call_deferred("rodar")

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

func novo_jogo(dia: int) -> Node:
	var jogo: Node = load("res://scenes/mundo3d.tscn").instantiate()
	jogo.dia = dia
	root.add_child(jogo)
	jogo.voltar_ao_menu_no_fim = false
	for i in 4: await process_frame
	return jogo

## Espera a fala mostrar as respostas (ou acabar).
func ate_as_respostas(jogo: Node) -> void:
	var limite := Time.get_ticks_msec() + 15000
	while jogo.escolha == null and Time.get_ticks_msec() < limite:
		if jogo.dialogo.visible and not jogo.dialogo.aguardando_resposta: jogo.dialogo.avancar()
		await process_frame

func rodar() -> void:
	# No dia do ataque, sem resgate, ninguém atende no portão dela.
	var jogo: Node = await novo_jogo(7)
	jogo.irma_sumiu = true
	jogo.chamar_a_irma()
	checar(not jogo.dialogo.visible and jogo.dica.recado.text.contains("Ninguém atende"), "dia 7: ela não atende")
	jogo.queue_free()
	await process_frame

	# Negar três vezes.
	jogo = await novo_jogo(8)
	jogo.irma_sumiu = true
	jogo.ciclo.suprimentos = 20
	jogo.dormir()
	await ate_as_respostas(jogo)
	checar(jogo.ciclo.dia == 9 and jogo.escolha != null and jogo.escolha.name == "AVolta", "dia 9: ela bate na porta e pede pra entrar")
	checar(jogo.dialogo.caminho_do_retrato == jogo.RETRATO_DA_IRMA, "com o rosto dela de sempre")
	var pedidos := []
	for vez in 3:
		pedidos.append(str(jogo.dialogo.linhas[0]))
		jogo.escolha.escolheu.emit("")
		await process_frame
		if vez < 2: await ate_as_respostas(jogo)
	checar(pedidos[0] != pedidos[1] and pedidos[1] != pedidos[2], "cada vez ela implora diferente")
	checar(jogo.dialogo.visible and str(jogo.dialogo.linhas.back()) == "Eu volto outro dia.", "negou três vezes: ela desiste")
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	await process_frame
	checar(jogo.ultimo_final == "" and jogo.jogador.is_physics_processing(), "e a vida segue")
	jogo.queue_free()
	await process_frame

	# Abrir: não é ela.
	jogo = await novo_jogo(8)
	jogo.irma_sumiu = true
	jogo.ciclo.suprimentos = 20
	jogo.dormir()
	await ate_as_respostas(jogo)
	jogo.escolha.escolheu.emit("")
	await process_frame
	await ate_as_respostas(jogo)
	jogo.escolha.escolheu.emit("abrir")
	await process_frame
	checar(jogo.dialogo.visible and jogo.dialogo.caminho_do_retrato == jogo.RETRATO_DA_QUE_VOLTOU, "abriu: o rosto já não é o dela")
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	var limite := Time.get_ticks_msec() + 5000
	while jogo.ultimo_final == "" and Time.get_ticks_msec() < limite: await process_frame
	checar(jogo.ultimo_final == "ELA VOLTOU", "e é o fim (%s)" % jogo.ultimo_final)
	checar(ResourceLoader.exists(jogo.CENA_DO_FINAL["ELA VOLTOU"]), "o final tem cena")
	jogo.queue_free()
	await process_frame

	# Resgatada, ela nunca bate: está em casa.
	jogo = await novo_jogo(8)
	jogo.ciclo.irma_em_casa = true
	jogo.ciclo.suprimentos = 20
	await jogo.dormir()
	checar(jogo.escolha == null and not jogo.irma_bateu_na_porta, "resgatada, ninguém bate na porta")
	jogo.queue_free()
	await process_frame

	print("VOLTA: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
