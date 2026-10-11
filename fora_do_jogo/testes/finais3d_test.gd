extends SceneTree

## Finais: O Último Dia (fome), Em casa (passou o dia 10), Sobreviventes
## (portão da barricada no dia 10, antes de escurecer). E as notícias: cada
## fonte fala pelo menos três frases, e o rádio do dia 9 conta da barricada.
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

func rodar() -> void:
	# --- O Último Dia: terceira noite de fraqueza.
	var jogo: Node = await novo_jogo(4)
	jogo.ciclo.suprimentos = 0
	jogo.ciclo.fraqueza = 2
	await jogo.dormir()
	checar(jogo.ultimo_final == "O ÚLTIMO DIA", "fome demais: O Último Dia (%s)" % jogo.ultimo_final)
	await fechar(jogo)

	# --- Em casa: dormir vivo na noite do dia 10.
	jogo = await novo_jogo(10)
	jogo.ciclo.suprimentos = 20
	await jogo.dormir()
	checar(jogo.ultimo_final == "EM CASA", "noite do dia 10 em casa: final Em casa (%s)" % jogo.ultimo_final)
	checar(ResourceLoader.exists(jogo.CENA_DO_FINAL[jogo.ultimo_final]), "Em casa tem cena animada")
	await fechar(jogo)

	# Antes do dia 10, dormir não acaba nada.
	jogo = await novo_jogo(9)
	jogo.ciclo.suprimentos = 20
	# A irmã sumida já bateu na porta (isso tem teste próprio, volta3d).
	jogo.irma_bateu_na_porta = true
	await jogo.dormir()
	checar(jogo.ultimo_final == "" and jogo.ciclo.dia == 10, "dia 9 vira dia 10 sem final")

	# --- Barricada dos sobreviventes.
	checar(jogo.barricada != null and jogo.barricada.visible, "barricada de pé no fim da rua a partir do dia 9")
	await fechar(jogo)
	jogo = await novo_jogo(5)
	checar(jogo.barricada != null and not jogo.barricada.visible, "antes do dia 9 não tem barricada")
	await fechar(jogo)

	jogo = await novo_jogo(9)
	jogo.bater_na_barricada()
	checar(jogo.ultimo_final == "", "dia 9: do outro lado mandam voltar amanhã")
	jogo.ciclo.dia = 10
	jogo.virar_o_dia(10)
	jogo.ciclo.horas = Ciclo3D.DORME - Ciclo3D.COMECO_DOS_PERIODOS[4]
	jogo.bater_na_barricada()
	checar(jogo.ultimo_final == "", "dia 10 de noite: portão fechado")
	jogo.ciclo.horas = Ciclo3D.DORME - 14
	await jogo.bater_na_barricada()
	checar(jogo.ultimo_final == "SOBREVIVENTES", "dia 10 antes de escurecer: final Sobreviventes")
	# A mira encontra o portão.
	jogo.ultimo_final = ""
	var portao: Node3D = jogo.portao_da_barricada
	jogo.jogador.global_position = portao.global_position + Vector3(-1.6, 0.1, 0)
	jogo.jogador.rotation.y = -PI / 2.0
	jogo.camera.rotation.x = -0.1
	await physics_frame
	await physics_frame
	checar(jogo.na_mira().get("o_que", "") == "refugio", "mira encontra o portão da barricada")
	await fechar(jogo)

	# --- O Sargento Holanda: aparece nos dias 2, 4 e 5 antes de oferecer a vaga.
	jogo = await novo_jogo(2)
	checar(jogo.sargento.visible and not jogo.posto_de_embarque.visible, "dia 2: sargento na calçada, sem caminhão")
	jogo.falar_com_o_pm()
	checar(jogo.dialogo.caminho_do_retrato == jogo.RETRATO_DO_SARGENTO, "sargento fala com o retrato dele")
	while jogo.dialogo.visible and not jogo.dialogo.aguardando_resposta: jogo.dialogo.avancar()
	checar(jogo.escolha != null and jogo.escolha.name == "Embarque", "dia 2: ele pergunta se você viu o meliante")
	jogo.responder_ao_embarque("vi")
	checar(jogo.dialogo.visible and jogo.ultimo_final == "", "ele responde e a vida segue")
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	jogo.falar_com_o_pm()
	checar(not jogo.dialogo.visible, "no mesmo dia, ele não repete o discurso")
	await fechar(jogo)
	for dia in [3, 6]:
		jogo = await novo_jogo(dia)
		checar(not jogo.sargento.visible, "dia %d: sem sargento" % dia)
		await fechar(jogo)
	for dia in [4, 5]:
		jogo = await novo_jogo(dia)
		checar(jogo.sargento.visible, "dia %d: sargento na calçada" % dia)
		jogo.falar_com_o_pm()
		while jogo.dialogo.visible: jogo.dialogo.avancar()
		checar(jogo.escolha == null and jogo.ultimo_final == "", "dia %d: só fala, não pergunta" % dia)
		await fechar(jogo)

	# --- O Abrigo: embarcar no caminhão do Exército, no dia do ataque.
	jogo = await novo_jogo(6)
	checar(jogo.posto_de_embarque != null and not jogo.posto_de_embarque.visible, "sem posto de embarque antes do ataque")
	await fechar(jogo)
	jogo = await novo_jogo(7)
	checar(jogo.posto_de_embarque.visible and jogo.sargento.visible, "no dia 7 tem caminhão e o sargento perto do ponto")
	checar(jogo.posto_de_embarque.get_node_or_null("CacadorMorto") != null, "um caçador morto aos pés do sargento")
	jogo.falar_com_o_pm()
	while jogo.dialogo.visible and not jogo.dialogo.aguardando_resposta: jogo.dialogo.avancar()
	checar(jogo.escolha != null and jogo.escolha.name == "Embarque", "o PM oferece o embarque")
	jogo.responder_ao_embarque("")
	checar(jogo.ultimo_final == "", "dizer que vai pensar não acaba o jogo")
	await jogo.responder_ao_embarque("embarcar")
	checar(jogo.ultimo_final == "O ABRIGO", "subir no caminhão: final O Abrigo")
	await fechar(jogo)
	jogo = await novo_jogo(7)
	jogo.ciclo.horas = 2
	jogo.falar_com_o_pm()
	checar(not jogo.dialogo.visible, "de noite o caminhão já foi, lotado")
	await fechar(jogo)

	# --- Atalhos de teste: F1–F4 só no modo deus.
	jogo = await novo_jogo(2)
	jogo.ver_um_final(2)
	checar(jogo.ultimo_final == "", "sem modo deus o atalho não mostra final")
	jogo.ciclo.virar_deus(true)
	var nomes := []
	for qual in 4:
		jogo.ultimo_final = ""
		await jogo.ver_um_final(qual)
		nomes.append(jogo.ultimo_final)
	checar(nomes == ["PEGO NO ESCURO", "EM CASA", "O ABRIGO", "SOBREVIVENTES"], "F1–F4 abrem as quatro animações %s" % [nomes])
	await fechar(jogo)

	# --- Notícias: pelo menos três frases por fonte, nos dias 1 a 10.
	var noticias := Noticias3D.new()
	var curtas := []
	for dia in range(1, 11):
		for canal in ["tv", "radio"]:
			for item: Dictionary in noticias.dias.get(str(dia), {}).get(canal, []):
				if Noticias3D.frases(String(item.texto)).size() < 3: curtas.append("%d/%s/%s" % [dia, canal, item.fonte])
	checar(curtas.is_empty(), "toda notícia tem 3 frases ou mais %s" % [curtas])
	var radio9: Array = noticias.radio_do_dia(9).map(func(f): return String(f[1]))
	checar(radio9.any(func(t): return t.contains("barricada")), "rádio do dia 9 fala da barricada")
	var tv1: Dictionary = noticias.do_dia(1)
	checar(tv1.pronunciamento.size() >= 3 and tv1.telejornal.size() >= 3, "TV mostra frase por frase")

	print("FINAIS: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
