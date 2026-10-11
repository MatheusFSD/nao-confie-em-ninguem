extends SceneTree

## Dia 0: a irmã acorda junto, pede a TV, a torneira, o trabalho, o
## mercadinho e a tranca, vai embora para a casa dela e some no dia 1.
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
	jogo.suprimentos = 0
	root.add_child(jogo)
	jogo.voltar_ao_menu_no_fim = false
	for i in 4: await process_frame
	await physics_frame
	return jogo

func fechar(jogo: Node) -> void:
	jogo.queue_free()
	await process_frame
	await process_frame

## Deixa a irmã falar tudo o que tem na fila.
func ouvir(jogo: Node) -> void:
	for i in 3: await process_frame
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	await process_frame

func rodar() -> void:
	var jogo: Node = await novo_jogo(0)
	var tut: Tutorial3D = jogo.tutorial
	checar(tut != null and tut.ativo, "dia 0 tem tutorial")
	checar(jogo.irma.visible and jogo.irma.seguindo == jogo.jogador, "a irmã acorda junto e vai atrás")
	checar(jogo.dialogo.visible and jogo.dialogo.caminho_do_retrato == jogo.RETRATO_DA_IRMA, "ela fala primeiro, com o retrato dela")
	await ouvir(jogo)
	checar(jogo.status.objetivo().contains("TV"), "objetivo: ligar a TV (%s)" % jogo.status.objetivo())
	jogo.ligar_a_tv()
	await process_frame
	checar(not jogo.dialogo.visible, "com a TV ligada ela espera")
	jogo.desligar_a_tv()
	await ouvir(jogo)
	checar(jogo.status.objetivo().contains("torneira"), "objetivo: torneira (%s)" % jogo.status.objetivo())
	jogo.responder_na_torneira("encher")
	await ouvir(jogo)
	checar(jogo.ciclo.suprimentos == 1, "encheu as garrafas: 1 suprimento")
	checar(jogo.status.objetivo().contains("trabalhar"), "objetivo: trabalho (%s)" % jogo.status.objetivo())
	jogo.ciclo.trabalhar()
	jogo.sair_para("trabalho")
	checar(jogo.expediente != null, "foi trabalhar")
	jogo.voltar_do_expediente()
	await ouvir(jogo)
	checar(jogo.status.objetivo().contains("mercadinho"), "objetivo: mercadinho (%s)" % jogo.status.objetivo())
	checar(jogo.irma.seguindo == jogo.jogador, "na volta do trabalho ela continua junto")
	jogo.evento.emit("comprou")
	await ouvir(jogo)
	checar(tut.indo_embora and jogo.irma.seguindo != jogo.jogador, "depois das compras ela vai para casa")
	checar(jogo.status.objetivo().contains("T"), "objetivo: trancar (%s)" % jogo.status.objetivo())
	checar(not jogo.ciclo.irma_em_casa, "o dia 0 não conta como resgate")
	jogo.evento.emit("trancou")
	await ouvir(jogo)
	checar(jogo.status.objetivo().contains("Dormir"), "objetivo: dormir (%s)" % jogo.status.objetivo())
	await jogo.dormir()
	checar(jogo.ciclo.dia == 1 and jogo.tutorial == null and not is_instance_valid(tut), "dormiu: dia 1, o tutorial sai de cena")
	checar(not jogo.irma.visible and not jogo.ciclo.irma_em_casa, "no dia 1 ela está na casa dela")
	checar(jogo.status.objetivo() == "", "sem objetivo no dia 1")
	await fechar(jogo)

	# Quem faz fora de ordem: ela não pede de novo o que já foi feito.
	jogo = await novo_jogo(0)
	tut = jogo.tutorial
	await ouvir(jogo)
	jogo.responder_na_torneira("encher")
	jogo.ligar_a_tv()
	jogo.desligar_a_tv()
	await ouvir(jogo)
	checar(jogo.status.objetivo().contains("trabalhar"), "pulou a torneira já feita (%s)" % jogo.status.objetivo())
	# Anoiteceu sem trabalhar: ela desiste e vai embora.
	jogo.ciclo.horas = 2
	jogo.ciclo.mudou.emit()
	await ouvir(jogo)
	checar(tut.indo_embora, "de noite, sem trabalho feito, ela vai embora")
	await fechar(jogo)

	# Dormir cedo: ela deixa recado e some.
	jogo = await novo_jogo(0)
	await ouvir(jogo)
	jogo.dormir()
	for i in 3: await process_frame
	checar(jogo.dialogo.visible and not jogo.dormindo and jogo.ciclo.dia == 0, "cama antes da hora: ela fala antes")
	checar(jogo.tutorial.indo_embora, "e vai para casa")
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	var limite := Time.get_ticks_msec() + 15000
	while jogo.ciclo.dia == 0 and Time.get_ticks_msec() < limite: await process_frame
	while jogo.dormindo and Time.get_ticks_msec() < limite: await process_frame
	checar(jogo.ciclo.dia == 1 and jogo.tutorial == null and not jogo.irma.visible, "acabada a fala, ele dorme e ela some")
	await fechar(jogo)

	# Fora de ordem: ela comenta num balão, sem travar o jogo.
	jogo = await novo_jogo(0)
	await ouvir(jogo)
	jogo.responder_na_torneira("encher")
	await process_frame
	for i in 3: await process_frame
	var comentou: bool = jogo.dialogo.visible and jogo.dialogo.caminho_do_retrato == jogo.RETRATO_DA_IRMA and str(jogo.dialogo.linhas[0]).begins_with("Encheu")
	checar(comentou, "encheu antes da hora: ela comenta na caixa, com o rosto")
	await fechar(jogo)

	# Nos outros dias não tem tutorial.
	jogo = await novo_jogo(1)
	checar(jogo.tutorial == null and not jogo.irma.visible, "dia 1 sem tutorial")
	await fechar(jogo)

	# A abertura termina e entrega o jogo no dia 0.
	var ab: Abertura3D = load("res://scenes/abertura.tscn").instantiate()
	root.add_child(ab)
	await process_frame
	checar(Abertura3D.duracao_total() > 40.0, "abertura contínua (%.0f s)" % Abertura3D.duracao_total())
	ab.terminar()
	await process_frame
	await process_frame
	var aberto: Node = current_scene
	checar(aberto != null and aberto.get("tutorial") != null and int(aberto.dia) == 0, "depois da abertura: dia 0 com a irmã")
	if aberto != null:
		checar(aberto.ciclo.suprimentos == 0 and aberto.ciclo.dinheiro == 30, "dia 0 começa sem comida e com R$ 30")
		aberto.voltar_ao_menu_no_fim = false
		aberto.queue_free()

	print("TUTORIAL: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
