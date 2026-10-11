extends SceneTree

## O cara do beco: aborda, leva 1 suprimento, manda vazar; quem insiste leva
## tiro. Denunciado ao sargento, vira saco preto e o suprimento volta.
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
	await process_frame
	await physics_frame
	return jogo

func fechar(jogo: Node) -> void:
	jogo.queue_free()
	await process_frame
	await process_frame

## Põe o jogador a `metros` do bandido, do lado da rua, e roda a física.
func chegar(jogo: Node, metros: float) -> void:
	jogo.jogador.global_position = jogo.BANDIDO_ONDE + Vector3(0, 0.1, -metros)
	await physics_frame
	await physics_frame

func rodar() -> void:
	var jogo: Node = await novo_jogo(1)
	checar(jogo.bandido != null and jogo.bandido.visible, "dia 1: o bandido já está no beco")
	checar(not jogo.saco_preto.visible, "sem saco preto enquanto ele está vivo")
	jogo.ciclo.suprimentos = 3
	await chegar(jogo, 8.0)
	checar(not jogo.dialogo.visible, "de longe ele só olha")
	await chegar(jogo, 3.5)
	checar(jogo.dialogo.visible and jogo.dialogo.caminho_do_retrato == jogo.RETRATO_DO_BANDIDO, "de perto ele aborda, com o retrato dele")
	checar(jogo.ciclo.suprimentos == 2 and jogo.suprimentos_roubados == 1, "levou 1 suprimento")
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	await physics_frame
	checar(jogo.ultimo_final == "" and not jogo.pego, "depois do assalto, quem fica onde está não morre")
	await chegar(jogo, 6.0)
	await chegar(jogo, 3.5)
	checar(jogo.ciclo.suprimentos == 2, "no mesmo dia ele não rouba duas vezes")
	checar(jogo.dialogo.visible and jogo.bandido_avisou, "chegando de novo: o último aviso, falado")
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	await chegar(jogo, 2.0)
	await create_timer(1.0).timeout
	checar(jogo.pego and jogo.ultimo_final == "MORTO NO BECO", "insistir no mesmo dia: tiro (%s)" % jogo.ultimo_final)
	checar(ResourceLoader.exists(jogo.CENA_DO_FINAL["MORTO NO BECO"]), "morto no beco tem cena de final")
	await fechar(jogo)

	# --- Denúncia ao sargento (dia 2).
	jogo = await novo_jogo(2)
	jogo.ciclo.suprimentos = 3
	await chegar(jogo, 3.5)
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	checar(jogo.ciclo.suprimentos == 2 and jogo.pode_denunciar(), "roubado, dá para denunciar")
	jogo.jogador.global_position = Vector3(0, 0.2, 30)
	await physics_frame
	jogo.falar_com_o_pm()
	while jogo.dialogo.visible and not jogo.dialogo.aguardando_resposta: jogo.dialogo.avancar()
	var chaves: Array = jogo.escolha.opcoes.map(func(o): return o.chave)
	checar(chaves.has("denunciar") and chaves.has("vi"), "o sargento ouve a denúncia %s" % [chaves])
	jogo.responder_ao_embarque("denunciar")
	checar(jogo.dialogo.caminho_do_retrato == jogo.RETRATO_DO_SARGENTO, "o sargento promete resolver")
	checar(jogo.bandido.visible and not jogo.bandido_morto and jogo.ciclo.suprimentos == 2, "no mesmo dia nada muda")
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	# Dia 3 não é dia de sargento, mas ele está lá para devolver.
	jogo.ciclo.dia = 3
	jogo.virar_o_dia(3)
	checar(jogo.bandido_morto and not jogo.bandido.visible and jogo.saco_preto.visible, "na madrugada: no lugar dele, um saco preto")
	checar(jogo.sargento.visible, "no dia seguinte o sargento espera na calçada")
	jogo.falar_com_o_pm()
	checar(jogo.ciclo.suprimentos == 3 and jogo.suprimentos_roubados == 0, "na conversa seguinte ele devolve o suprimento")
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	checar(jogo.escolha == null, "devolvido, sem mais perguntas")
	await chegar(jogo, 1.0)
	for i in 10: await process_frame
	checar(not jogo.pego and not jogo.dialogo.visible, "o saco preto não rouba ninguém")
	jogo.ciclo.dia = 4
	jogo.virar_o_dia(4)
	jogo.falar_com_o_pm()
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	checar(jogo.ciclo.suprimentos == 3, "não devolve duas vezes")
	await fechar(jogo)

	# No dia do ataque não tem denúncia: o sargento só pensa no caminhão.
	jogo = await novo_jogo(7)
	jogo.bandido_roubou_no_dia = 6
	checar(not jogo.pode_denunciar(), "dia 7: sem denúncia")
	await fechar(jogo)

	# Sem assalto, não há o que denunciar; e depois do ataque o beco é dos caçadores.
	jogo = await novo_jogo(4)
	checar(not jogo.pode_denunciar(), "sem assalto, sem denúncia")
	jogo.falar_com_o_pm()
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	checar(jogo.escolha == null, "dia 4 sem assalto: o sargento só fala")
	await fechar(jogo)
	# Vivo até o breu: do breu em diante, caído no beco, onde ficava.
	jogo = await novo_jogo(5)
	checar(jogo.bandido.visible and (jogo.corpo_do_bandido == null or not jogo.corpo_do_bandido.visible), "dia 5: ainda de pé")
	jogo.ciclo.dia = 6
	jogo.virar_o_dia(6)
	checar(not jogo.bandido.visible and jogo.corpo_do_bandido != null and jogo.corpo_do_bandido.visible, "breu: o bandido caído no beco")
	checar(jogo.corpo_do_bandido.global_position.distance_to(jogo.BANDIDO_ONDE) < 0.1 and not jogo.saco_preto.visible, "caído onde ficava, sem saco preto")
	checar(not jogo.pode_denunciar(), "morto não se denuncia")
	await fechar(jogo)
	jogo = await novo_jogo(8)
	checar(not jogo.bandido.visible and jogo.corpo_do_bandido != null and jogo.corpo_do_bandido.visible, "dia 8: o corpo continua lá")
	await fechar(jogo)

	print("BANDIDO: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
