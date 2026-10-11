extends SceneTree

## Comércio da rua: balcão com o dono, fechamento escalonado, arrombamento
## (minigame) e o barulho que atrai os caçadores.
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

func nome_do_predio(tipo: String) -> String:
	for predio in jogo.mundo.get_node("Casario").get_children():
		var nome := String(predio.name)
		if nome.begins_with(tipo + "_") and (predio as Node3D).global_position.z < jogo.RUA_EIXO_Z: return nome
	return ""

## Põe o jogador na calçada, de frente para a porta da loja.
func olhar_para(tipo: String) -> void:
	var porta: Node3D = jogo.portas_das_lojas[tipo]
	var onde: Vector3 = jogo.onde_fica_a_porta(tipo)
	jogo.jogador.global_position = onde + Vector3(0, 0.05, 0)
	var rumo := porta.global_position - onde
	jogo.jogador.rotation.y = atan2(-rumo.x, -rumo.z)
	jogo.camera.rotation.x = -0.15

func mudar_para(dia: int, periodo: int) -> void:
	jogo.ciclo.dia = dia
	jogo.virar_o_dia(dia)
	# O relógio no começo do período pedido.
	jogo.ciclo.horas = Ciclo3D.DORME - int(Ciclo3D.COMECO_DOS_PERIODOS[periodo])
	jogo.ciclo.mudou.emit()
	await physics_frame
	await physics_frame

func rodar() -> void:
	jogo = load("res://scenes/mundo3d.tscn").instantiate()
	root.add_child(jogo)
	current_scene = jogo
	await process_frame
	await physics_frame
	await physics_frame
	checar(MenuPonto.OPCOES.all(func(o): return o.chave != "mercado"), "ponto de ônibus sem ida ao mercado")
	checar(jogo.portas_das_lojas.size() == 5 and jogo.portas_das_lojas.has("mercadinho") and jogo.portas_das_lojas.has("padaria") and jogo.portas_das_lojas.has("bar_do_ze"), "cinco lojas de compras, dos dois lados")
	checar(jogo.portas_das_lojas.has("bar_do_tiao") and jogo.portas_das_lojas.has("padaria_gemea"), "o bar do Tião e a padaria do Lauro, do outro lado")
	checar(jogo.lojas.tipo_do_predio("padaria_gemea_aberto") == "padaria_gemea" and jogo.lojas.tipo_do_predio("padaria_aberto") == "padaria", "o prédio certo para cada padaria")
	checar(jogo.lojas.loja("padaria_gemea").retrato == jogo.lojas.loja("padaria").retrato, "gêmeos: o mesmo rosto")

	# Dia 1, manhã: o mercadinho atende no balcão.
	await mudar_para(1, 0)
	olhar_para("mercadinho")
	await physics_frame
	var alvo: Dictionary = jogo.na_mira()
	checar(alvo.get("o_que", "") == "loja" and alvo.get("tipo", "") == "mercadinho", "mira encontra a porta do mercadinho")
	checar(jogo.dica_da_loja("mercadinho").begins_with("Entrar no mercadinho"), "dica oferece entrar")
	jogo.ciclo.dinheiro = 80
	var comida: int = jogo.ciclo.suprimentos
	jogo.usar_o_que_estiver_na_mira()
	checar(jogo.na_loja == "mercadinho" and jogo.dialogo.visible and jogo.ciclo.horas == 13, "entrar custa 1 hora e o dono atende")
	checar(jogo.dialogo.caminho_do_retrato == "res://ui/retratos/lojas/mercadinho.webp", "retrato do dono do mercadinho")
	fechar_falas()
	checar(jogo.escolha != null and jogo.escolha.name == "Balcao", "falas do dono abrem o balcão")
	var chaves: Array = jogo.escolha.opcoes.map(func(o): return o.chave)
	checar(chaves.has("arroz") and chaves.has("lanterna") and chaves.back() == "", "balcão lista produtos e a saída")
	jogo.responder_no_balcao("arroz")
	checar(jogo.ciclo.suprimentos == comida + 3 and jogo.ciclo.dinheiro == 54, "arroz rende 3 suprimentos por R$ 26")
	checar(jogo.escolha != null and jogo.escolha.name == "Balcao", "balcão continua aberto depois da compra")
	jogo.ciclo.dinheiro = 3
	jogo.responder_no_balcao("arroz")
	checar(jogo.ciclo.dinheiro == 3 and jogo.ciclo.suprimentos == comida + 3, "sem dinheiro não compra")
	jogo.responder_no_balcao("")
	checar(jogo.na_loja == "" and jogo.escolha == null and not jogo.dialogo.visible, "ir embora encerra o atendimento")

	# De noite, fechado só até de manhã: nada de arrombar.
	await mudar_para(1, 4)
	checar(nome_do_predio("mercadinho").contains("_fechado"), "de noite a porta de aço baixa")
	var acoes: int = jogo.ciclo.horas
	jogo.entrar_na_loja("mercadinho")
	checar(jogo.arrombando == null and jogo.na_loja == "" and jogo.ciclo.horas == acoes, "fechado à noite não abre nem deixa arrombar")

	# Dia 4: a padaria fechou de vez; mercadinho e bar seguem abertos de dia.
	await mudar_para(4, 0)
	checar(nome_do_predio("padaria").contains("_fechado") and nome_do_predio("mercadinho").contains("_aberto") and nome_do_predio("bar_do_ze").contains("_aberto"), "fechamento escalonado no dia 4")
	checar(jogo.dica_da_loja("padaria").begins_with("Arrombar a porta da padaria"), "padaria fechada oferece arrombar")
	await mudar_para(5, 0)
	checar(nome_do_predio("bar_do_ze").contains("_fechado") and nome_do_predio("mercadinho").contains("_aberto"), "bar fecha de vez no dia 5")
	await mudar_para(6, 0)
	checar(nome_do_predio("mercadinho").contains("_fechado"), "mercadinho fecha de vez no breu")

	# Antes do breu, o sargento aparece e não deixa arrombar.
	await mudar_para(4, 0)
	acoes = jogo.ciclo.horas
	jogo.entrar_na_loja("padaria")
	checar(jogo.arrombando == null and jogo.dialogo.visible and jogo.dialogo.caminho_do_retrato == jogo.RETRATO_DO_SARGENTO and jogo.ciclo.horas == acoes, "antes do breu: o sargento flagra e não deixa")
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	# No breu, a rua não tem mais dono: arrombar a padaria, três golpes na faixa.
	await mudar_para(6, 0)
	comida = jogo.ciclo.suprimentos
	# Saque fixo para o teste: 2 suprimentos na padaria; 0 no mercadinho (já levaram).
	jogo.lojas.saques_sorteados["padaria"] = 2
	jogo.lojas.saques_sorteados["mercadinho"] = 0
	jogo.entrar_na_loja("padaria")
	checar(jogo.arrombando != null and jogo.ciclo.horas == 12, "arrombar abre o minigame e custa 2 horas")
	for golpe in 3:
		var a: Arrombar3D = jogo.arrombando
		if a == null: break
		a.ponteiro = a.faixa_inicio + a.faixa_largura / 2.0
		a.golpear()
	checar(jogo.arrombando == null and jogo.lojas.saqueadas.has("padaria") and jogo.ciclo.suprimentos == comida + 2, "três acertos abrem a padaria e levam o saque sorteado")
	acoes = jogo.ciclo.horas
	jogo.entrar_na_loja("padaria")
	checar(jogo.arrombando == null and jogo.ciclo.horas == acoes, "loja saqueada não abre de novo")

	# Minigame: faixa encolhe e ponteiro acelera; golpe fora da faixa falha.
	var teste := Arrombar3D.new()
	root.add_child(teste)
	var largura := teste.faixa_largura
	var velocidade := teste.velocidade
	var resultado := [""]
	teste.terminou.connect(func(r): resultado[0] = r)
	teste.ponteiro = teste.faixa_inicio + teste.faixa_largura / 2.0
	teste.golpear()
	checar(teste.acertos == 1 and teste.faixa_largura < largura and teste.velocidade > velocidade, "acerto encolhe a faixa e acelera")
	teste.ponteiro = fmod(teste.faixa_inicio + teste.faixa_largura + 0.05, 1.0) if teste.faixa_inicio + teste.faixa_largura + 0.05 <= 1.0 else teste.faixa_inicio - 0.05
	teste.golpear()
	checar(resultado[0] == "falhou", "golpe fora da faixa falha")
	teste.queue_free()

	# Dia 7: com o Exército na rua, ninguém arromba.
	await mudar_para(7, 0)
	acoes = jogo.ciclo.horas
	jogo.entrar_na_loja("mercadinho")
	checar(jogo.arrombando == null and jogo.ciclo.horas == acoes and jogo.dica_da_loja("mercadinho").contains("tropa"), "no dia do ataque não dá pra arrombar")

	# Dia 8: o estalo de um arrombamento errado puxa os caçadores até a porta.
	await mudar_para(8, 0)
	await physics_frame
	var bichos := get_nodes_in_group("cacadores3d")
	checar(bichos.size() == jogo.CACADORES_DEPOIS, "dia 8, de dia: a rua cheia de caçadores (%d)" % bichos.size())
	var porta: Vector3 = jogo.onde_fica_a_porta("mercadinho")
	var bicho: Node3D = bichos[0]
	bicho.global_position = porta + Vector3(12, 0.05, 2.5)
	await physics_frame
	var antes := Vector2(bicho.global_position.x - porta.x, bicho.global_position.z - porta.z).length()
	jogo.jogador.global_position = Vector3(12, 0.1, 10)
	jogo.entrar_na_loja("mercadinho")
	checar(jogo.arrombando != null, "mercadinho fechado no dia 8 pode ser arrombado")
	var a2: Arrombar3D = jogo.arrombando
	a2.ponteiro = a2.faixa_inicio - 0.05 if a2.faixa_inicio > 0.06 else a2.faixa_inicio + a2.faixa_largura + 0.05
	a2.golpear()
	checar(jogo.arrombando == null and not jogo.lojas.saqueadas.has("mercadinho"), "falha não abre a loja")
	checar(bicho._estado == "buscar" and bicho._ao_barulho, "caçador ao alcance ouve o barulho")
	for i in 240: await physics_frame
	var depois := Vector2(bicho.global_position.x - porta.x, bicho.global_position.z - porta.z).length()
	checar(depois < antes - 4.0, "caçador corre até a porta (%.1f → %.1f m)" % [antes, depois])
	checar(jogo.fazer_barulho(porta + Vector3(500, 0, 0)) == 0, "barulho longe demais não chega")

	# O que sobra numa loja é sorteado por partida: pouco ou nada.
	var vazias := 0
	var dentro_da_faixa := true
	for semente in 200:
		var sorteio := Lojas3D.new()
		sorteio.sortear_saques(semente)
		var achou := sorteio.saque_da_partida("mercadinho")
		if achou == 0: vazias += 1
		dentro_da_faixa = dentro_da_faixa and achou >= 0 and achou <= 4
	checar(dentro_da_faixa and vazias > 30 and vazias < 120, "saque sorteado entre 0 e 4, às vezes vazio (%d de 200 vazias)" % vazias)
	# Consumo cresce com o colapso: 1 com água e luz, 2 sem água, 3 sem luz.
	var ciclo := Ciclo3D.new()
	var consumo := []
	for d in [1, 4, 5, 6, 9]:
		ciclo.dia = d
		consumo.append(ciclo.consumo_da_noite())
	checar(consumo == [1, 1, 2, 3, 3], "consumo por dia 1/1/2/3/3: %s" % [consumo])
	ciclo.dia = 6
	ciclo.irma_em_casa = true
	checar(ciclo.consumo_da_noite() == 4, "irmã em casa: um a mais")
	ciclo.suprimentos = 10
	ciclo.dormir(["frente"])
	checar(ciclo.suprimentos == 6 and ciclo.horas == 16 and ciclo.hora() == 6, "irmã: ninguém entra de madrugada e o dia começa às 6h")
	ciclo.irma_em_casa = false
	ciclo.dia = 1
	ciclo.suprimentos = 1
	ciclo.dormir([])
	checar(ciclo.suprimentos == 0 and ciclo.fraqueza == 0 and ciclo.hora() == 8, "noite com o bastante: acorda às 8h")
	ciclo.dormir([])
	checar(ciclo.fraqueza == 1 and ciclo.hora() == 11 and not ciclo.morto, "faltou: acorda fraco às 11h")
	ciclo.dormir([])
	checar(ciclo.fraqueza == 2 and ciclo.hora() == 14 and not ciclo.morto, "segunda noite sem: acorda às 14h")
	var motivo := [""]
	ciclo.morreu.connect(func(m): motivo[0] = m)
	ciclo.dormir([])
	checar(ciclo.morto and not motivo[0].is_empty(), "terceira noite seguida sem suprimento: não acorda")
	ciclo.free()
	# Fraqueza só melhora comendo reforçado (1 a mais que o consumo).
	var forte := Ciclo3D.new()
	forte.fraqueza = 1
	forte.suprimentos = 1
	forte.dormir([])
	checar(forte.fraqueza == 1 and forte.suprimentos == 0, "comeu só o mínimo: continua fraco")
	forte.suprimentos = 2
	forte.dormir([])
	checar(forte.fraqueza == 0 and forte.suprimentos == 0, "comeu reforçado: gasta 1 a mais e melhora")
	forte.free()
	# Racionamento: 2 por loja no dia 1, 1 do dia 2 em diante.
	var racao := Lojas3D.new()
	checar(racao.limite_do_dia(1) == 2 and racao.limite_do_dia(2) == 1 and racao.limite_do_dia(5) == 1, "racionamento por dia")
	racao.registrar_compra("mercadinho", 1)
	racao.registrar_compra("mercadinho", 1)
	checar(racao.restam_hoje("mercadinho", 1) == 0 and racao.restam_hoje("mercadinho", 2) == 1, "limite zera a cada dia")
	# O sofá passa o tempo até o período escolhido.
	var relogio := Ciclo3D.new()
	checar(relogio.passar_ate(18) and relogio.hora() == 18 and relogio.periodo() == "Anoitecer", "sofá leva até o anoitecer")
	checar(not relogio.passar_ate(12), "o tempo não volta")
	relogio.free()
	print("LOJAS: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
