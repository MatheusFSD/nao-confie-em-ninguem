extends SceneTree

## Uma partida inteira jogada pelas ações do próprio jogo, do menu ao final.
##
## Caminho A: menu → abertura → dia 0 com a irmã → dias 1–5 trabalhando,
## comprando, enchendo água, conversando com vizinhos, a irmã e o sargento,
## sendo assaltado no beco e denunciando → breu com o resgate da irmã → ataque
## (sem embarcar) → ruínas com o amigo, o vizinho mudado e o rádio → barricada
## no dia 10 (final SOBREVIVENTES, com a troca de cena de verdade).
## Caminho B: breu sem resgate → a irmã volta no dia 9 e é negada três vezes →
## dormir no dia 10 (final EM CASA).
##
## Com janela (sem --headless), tira uma foto de cada manhã em
## output/godot-validation/fotos/partida-*.png.
var falhas := 0
var verificacoes := 0
var jogo: Node
var com_janela := false
var diario: Array[String] = []

func _initialize() -> void:
	com_janela = DisplayServer.get_name() != "headless"
	call_deferred("rodar")

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

func anotar(texto: String) -> void:
	diario.append(texto)
	print("  · ", texto)

func quadros(n: int) -> void:
	for i in n: await process_frame

## Passa as falas até acabar a conversa ou aparecer uma escolha.
func falar() -> void:
	for i in 600:
		await process_frame
		if jogo.escolha != null and jogo.escolha.visible: return
		if not jogo.dialogo.visible: return
		if jogo.dialogo.aguardando_resposta: continue
		jogo.dialogo.avancar()

func responder(chave: String) -> void:
	if jogo.escolha == null:
		checar(false, "[%s] esperava uma escolha para responder %s" % [jogo.ciclo.dia, chave])
		return
	jogo.escolha.escolheu.emit(chave)
	await falar()

func chaves() -> Array:
	return [] if jogo.escolha == null else jogo.escolha.opcoes.map(func(o): return String(o.chave))

func foto(nome: String) -> void:
	if not com_janela: return
	await quadros(10)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/godot-validation/fotos/partida-%s.png" % nome))

func manha(nome: String) -> void:
	jogo.jogador.global_position = jogo.saida_de_casa() + Vector3(0, 1.0, 0)
	jogo.jogador.rotation.y = 0.0
	await quadros(4)
	await foto(nome)

## O jogador anda (um passo por quadro de física) até `ate`.
func andar(ate: Vector3) -> void:
	var de: Vector3 = jogo.jogador.global_position
	var n := maxi(1, int(de.distance_to(ate) / 4.5 * 60.0))
	for i in n + 1:
		jogo.jogador.global_position = de.lerp(ate, float(i) / n)
		jogo.jogador.velocity = Vector3.ZERO
		await physics_frame

func comprar(tipo: String, quantas: int) -> int:
	var antes: int = jogo.ciclo.suprimentos
	jogo.entrar_na_loja(tipo)
	await falar()
	if jogo.escolha == null or jogo.escolha.name != "Balcao":
		anotar("%s fechado ou sem tempo" % tipo)
		jogo.encerrar_conversa()
		return 0
	for k in quantas:
		for chave: String in chaves():
			if chave.is_empty() or chave == "lanterna": continue
			var dinheiro: int = jogo.ciclo.dinheiro
			jogo.responder_no_balcao(chave)
			await process_frame
			if jogo.ciclo.dinheiro < dinheiro: break
	jogo.responder_no_balcao("")
	await falar()
	return jogo.ciclo.suprimentos - antes

## Depois do breu, loja fechada de vez é despensa: arromba (o minijogo tem
## teste próprio; aqui ele acerta os três golpes).
func saquear_o_que_der() -> void:
	for tipo in ["padaria", "padaria_gemea", "bar_do_ze", "bar_do_tiao", "mercadinho"]:
		if jogo.lojas.saqueadas.has(tipo) or jogo.ciclo.horas < 3: continue
		var antes: int = jogo.ciclo.suprimentos
		jogo.entrar_na_loja(tipo)
		await process_frame
		if jogo.arrombando == null:
			await falar()
			jogo.encerrar_conversa()
			continue
		jogo.arrombando.terminou.emit("abriu")
		await process_frame
		anotar("dia %d: arrombou %s (+%d)" % [jogo.ciclo.dia, tipo, jogo.ciclo.suprimentos - antes])

func trabalhar() -> void:
	if not jogo.ciclo.trabalhar():
		anotar("sem trabalho hoje (%s)" % jogo.ciclo.recado)
		return
	jogo.sair_para("trabalho")
	await quadros(10)
	jogo.voltar_do_expediente()
	await falar()

func trancar_tudo() -> void:
	for i: int in jogo.casa.externas():
		if jogo.casa.esta_aberta(i): jogo.casa.acionar(i)
		if not jogo.casa.esta_trancada(i): jogo.casa.trancar(i)
	jogo.evento.emit("trancou")
	await falar()

func dormir() -> void:
	await trancar_tudo()
	jogo.jogador.global_position = jogo.CASA_LUGAR + Vector3(0, 0.3, 0)
	var dia: int = jogo.ciclo.dia
	await jogo.dormir()
	await falar()
	checar(jogo.ciclo.dia == dia + 1 or jogo.ultimo_final != "", "dormiu no dia %d e acordou no %d" % [dia, jogo.ciclo.dia])
	checar(not jogo.ciclo.morto, "vivo no dia %d (fraqueza %d, %d suprimentos)" % [jogo.ciclo.dia, jogo.ciclo.fraqueza, jogo.ciclo.suprimentos])
	if jogo.ultimo_final != "" and jogo.ultimo_final != "EM CASA": anotar("FINAL INESPERADO no dia %d: %s" % [dia, jogo.ultimo_final])

func conversar_com_vizinho(qual: int, respostas: Array) -> void:
	jogo.bater_na_porta(qual)
	await falar()
	for r: String in respostas:
		if not chaves().has(r):
			anotar("%s: sem a resposta %s (%s)" % [jogo.vizinhos[qual].nome, r, chaves()])
			break
		await responder(r)
	if jogo.escolha != null and chaves().has("sair"): await responder("sair")
	jogo.encerrar_conversa()
	await process_frame

func sargento(resposta := "") -> void:
	jogo.falar_com_o_pm()
	await falar()
	if jogo.escolha != null:
		var lista := chaves()
		var r := resposta if lista.has(resposta) else ("" if lista.has("") else String(lista[0]))
		await responder(r)
	jogo.encerrar_conversa()
	await process_frame

## Os caçadores têm teste próprio; nos trechos de rua a partida não quer
## morrer por azar de sorteio.
func pausar_cacadores(pausar: bool) -> void:
	for bicho in get_nodes_in_group("cacadores3d"):
		(bicho as Node).process_mode = Node.PROCESS_MODE_DISABLED if pausar else Node.PROCESS_MODE_INHERIT

func rodar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../output/godot-validation/fotos"))
	await caminho_a()
	await caminho_b()
	print("--- diário ---")
	for linha in diario: print(linha)
	print("PARTIDA INTEIRA: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)

func caminho_a() -> void:
	print("=== Caminho A: do menu aos sobreviventes")
	# Menu → abertura → dia 0, como quem clica em Iniciar e pula a abertura.
	change_scene_to_file("res://scenes/menu_inicial.tscn")
	await quadros(30)
	checar(current_scene != null and current_scene.scene_file_path.ends_with("menu_inicial.tscn"), "abre o menu inicial")
	await foto("00-menu")
	current_scene._iniciar()
	await quadros(30)
	checar(current_scene != null and current_scene.scene_file_path.ends_with("abertura.tscn"), "Iniciar abre a abertura")
	await quadros(90)
	await foto("00-abertura")
	current_scene.terminar()
	await quadros(30)
	jogo = current_scene
	checar(jogo != null and jogo.has_method("dormir") and jogo.ciclo.dia == 0, "a abertura termina no dia 0")
	# A troca de cena do final só no dia 10, de propósito; antes, um final
	# inesperado (fome, bote) fica registrado e o roteiro para.
	jogo.voltar_ao_menu_no_fim = false

	# --- Dia 0: o tutorial com a irmã.
	await falar()
	await manha("d00")
	jogo.ligar_a_tv()
	await quadros(5)
	jogo.desligar_a_tv()
	await falar()
	jogo.responder_na_torneira("encher")
	await falar()
	await trabalhar()
	anotar("dia 0: R$ %d depois do trabalho" % jogo.ciclo.dinheiro)
	var ganhou := await comprar("mercadinho", 1)
	checar(ganhou > 0, "dia 0: comprou no mercadinho (+%d)" % ganhou)
	await falar()
	await dormir()
	checar(jogo.tutorial == null, "dia 1 sem tutorial")

	# --- Dias 1 a 5: a vida antes do breu.
	var amigo := 0
	var conhecido := 1
	for dia in range(1, 6):
		await manha("d%02d" % dia)
		checar(jogo.ciclo.dia == dia, "manhã do dia %d" % dia)
		if dia <= 4:
			jogo.responder_na_torneira("ferver" if dia >= 3 else "encher")
			await falar()
		if dia in [1, 2, 4] and jogo.ciclo.onibus_funciona(): await trabalhar()
		# Vizinhos: um vira amigo (escuta e ajuda); o outro só é ouvido.
		if dia == 1:
			await conversar_com_vizinho(amigo, ["ouvir"])
			await conversar_com_vizinho(conhecido, ["ouvir"])
		elif dia == 2:
			await conversar_com_vizinho(amigo, ["pedido", "ajudar"])
			checar(jogo.vizinhos[amigo].pode_passar_numero(), "dia 2: %s virou amigo e passou o número" % jogo.vizinhos[amigo].nome)
		else:
			await conversar_com_vizinho(amigo, ["ouvir"])
		# A irmã, no portão dela.
		jogo.chamar_a_irma()
		await falar()
		jogo.encerrar_conversa()
		# O sargento nos dias dele; no 3, o assalto no beco; no 4, a denúncia.
		if dia == 2: await sargento("vi")
		if dia == 3:
			var antes: int = jogo.ciclo.suprimentos
			jogo.jogador.global_position = jogo.BANDIDO_ONDE + Vector3(3.0, 0.3, 0.0)
			for i in 20: await physics_frame
			await falar()
			jogo.encerrar_conversa()
			checar(jogo.ciclo.suprimentos == antes - 1 or antes == 0, "dia 3: o cara do beco levou um suprimento")
			jogo.jogador.global_position = jogo.saida_de_casa() + Vector3(0, 1.0, 0)
			for i in 5: await physics_frame
		if dia == 4:
			await sargento("denunciar")
			checar(jogo.denuncia_no_dia == 4, "dia 4: denunciou o cara do beco")
		if dia == 5:
			var antes: int = jogo.ciclo.suprimentos
			await sargento()
			checar(jogo.ciclo.suprimentos > antes, "dia 5: o sargento devolveu o que foi roubado")
		# Compras: o que estiver aberto, enquanto tiver dinheiro.
		for loja in ["mercadinho", "padaria", "bar_do_ze", "bar_do_tiao", "padaria_gemea"]:
			if jogo.ciclo.dinheiro >= 10 and jogo.ciclo.horas >= 2: await comprar(loja, 2)
		jogo.ouvir_o_radio(false)
		await falar()
		jogo.encerrar_conversa()
		anotar("dia %d: %d suprimentos, R$ %d, fraqueza %d" % [dia, jogo.ciclo.suprimentos, jogo.ciclo.dinheiro, jogo.ciclo.fraqueza])
		await dormir()

	# --- Dia 6: o breu e o resgate da irmã.
	await manha("d06")
	checar(jogo.ciclo.dia == 6 and not jogo.ciclo.tem_energia_da_rede(), "dia 6: breu")
	checar(jogo.bandido_morto, "dia 6: no lugar do cara do beco, o saco preto")
	pausar_cacadores(true)  # os caçadores têm teste próprio; aqui só o caminho
	jogo.jogador.global_position = jogo.porta_da_irma.global_position + Vector3(0, 0.3, 1.2)
	await physics_frame
	jogo.chamar_a_irma()
	await falar()
	checar(chaves().has("vem"), "breu: a irmã pergunta se vai junto")
	await responder("vem")
	var frente := -1
	for i in jogo.casa.portas.size():
		if String(jogo.casa.portas[i].nome) == "frente": frente = i
		if String(jogo.casa.portas[i].nome) in ["frente", "portao"] and not jogo.casa.esta_aberta(i):
			if jogo.casa.esta_trancada(i): jogo.casa.trancar(i)
			jogo.casa.acionar(i)
	for ponto in [Vector3(-20.0, 0.1, 21.6), Vector3(8.6, 0.1, 21.6), Vector3(8.6, 0.1, 18.2), Vector3(8.85, 0.1, 16.4), Vector3(8.85, 0.1, 14.2), Vector3(11.0, 0.1, 12.6)]:
		await andar(ponto)
	var limite := Time.get_ticks_msec() + 8000
	while not jogo.ciclo.irma_em_casa and Time.get_ticks_msec() < limite: await physics_frame
	checar(jogo.ciclo.irma_em_casa, "breu: a irmã chegou em casa")
	limite = Time.get_ticks_msec() + 12000
	while not jogo.dialogo.visible and Time.get_ticks_msec() < limite: await physics_frame
	await falar()
	checar(jogo.ciclo.tem_radio, "breu: ela trouxe o rádio")
	await saquear_o_que_der()
	pausar_cacadores(false)
	await foto("d06-irma")
	await dormir()

	# --- Dia 7: o ataque. O sargento oferece a vaga; ninguém embarca.
	await manha("d07")
	jogo.falar_com_o_pm()
	await falar()
	checar(chaves().has("embarcar"), "dia 7: o sargento oferece o caminhão")
	await responder("")
	checar(jogo.ultimo_final == "", "dia 7: recusou o embarque")
	await conversar_com_vizinho(amigo, ["ouvir"])
	jogo.conversar_com_a_irma()
	await falar()
	await dormir()

	# --- Dias 8 e 9: as ruínas.
	for dia in [8, 9]:
		await manha("d%02d" % dia)
		checar(not jogo.dialogo.visible or jogo.dialogo.caminho_do_retrato != jogo.RETRATO_DA_QUE_VOLTOU, "dia %d: com a irmã em casa, ninguém bate na porta" % dia)
		await conversar_com_vizinho(amigo, ["ouvir", "rede"])
		jogo.conversar_com_a_irma()
		await falar()
		jogo.ouvir_o_radio(true)
		await falar()
		jogo.encerrar_conversa()
		if dia == 8:
			pausar_cacadores(true)
			jogo.bater_na_porta(conhecido)
			await falar()
			checar(jogo.vizinhos[conhecido].historia.marcas.has("mudou"), "dia 8: quem não virou amigo atende mudado")
			jogo.jogador.global_position = jogo.CASA_LUGAR + Vector3(0, 0.3, 0)
			for i in 30: await physics_frame
			pausar_cacadores(false)
		if dia == 8: await saquear_o_que_der()
		if dia == 9:
			jogo.bater_na_barricada()
			await process_frame
			checar(jogo.ultimo_final == "", "dia 9: a barricada manda voltar amanhã")
		anotar("dia %d: %d suprimentos, fraqueza %d" % [dia, jogo.ciclo.suprimentos, jogo.ciclo.fraqueza])
		await dormir()

	# --- Dia 10: a barricada abre até escurecer. Troca de cena de verdade.
	await manha("d10")
	checar(jogo.ciclo.dia == 10 and not jogo.ciclo.morto, "chegou vivo ao dia 10")
	jogo.voltar_ao_menu_no_fim = true
	jogo.bater_na_barricada()
	limite = Time.get_ticks_msec() + 10000
	while is_instance_valid(jogo) and current_scene == jogo and Time.get_ticks_msec() < limite: await process_frame
	await quadros(30)
	checar(current_scene != null and current_scene.scene_file_path.ends_with("final_confiar.tscn"), "dia 10: final dos sobreviventes (%s)" % (current_scene.scene_file_path if current_scene else "?"))
	await foto("final-sobreviventes")
	current_scene.queue_free()
	current_scene = null
	await quadros(5)

func caminho_b() -> void:
	print("=== Caminho B: sem resgate, a volta da irmã")
	jogo = load("res://scenes/mundo3d.tscn").instantiate()
	jogo.dia = 6
	jogo.suprimentos = 30
	root.add_child(jogo)
	current_scene = jogo
	jogo.voltar_ao_menu_no_fim = false
	await quadros(6)
	await dormir()
	checar(jogo.irma_sumiu, "dia 7: sem resgate, a irmã sumiu")
	jogo.jogador.global_position = jogo.porta_da_irma.global_position + Vector3(0, 0.3, 1.2)
	jogo.chamar_a_irma()
	await process_frame
	checar(jogo.dica.recado.text.contains("Ninguém atende"), "dia 7: ninguém atende no portão dela")
	await dormir()
	# Dorme no 8 e acorda no 9 com ela batendo na porta.
	await trancar_tudo()
	jogo.dormir()
	var negou := 0
	var limite := Time.get_ticks_msec() + 30000
	while jogo.irma_bateu_na_porta == false and Time.get_ticks_msec() < limite: await process_frame
	checar(jogo.irma_bateu_na_porta, "dia 9: ela bate na porta ao acordar")
	while negou < 3 and Time.get_ticks_msec() < limite:
		await falar()
		if jogo.escolha != null and chaves().has("abrir"):
			if negou == 0: await foto("volta-da-irma")
			jogo.escolha.escolheu.emit("")
			negou += 1
		await process_frame
	await falar()
	checar(negou == 3 and jogo.ultimo_final == "", "negou três vezes e continua vivo")
	await dormir()
	checar(jogo.ciclo.dia == 10, "dia 10")
	await dormir()
	checar(jogo.ultimo_final == "EM CASA", "dormir vivo na noite do dia 10: final em casa (%s)" % jogo.ultimo_final)
	jogo.queue_free()
	await quadros(5)
