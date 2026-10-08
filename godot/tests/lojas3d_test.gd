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
	# A hora segue as ações gastas: 4 de manhã, nenhuma à noite.
	jogo.ciclo.acoes_do_dia = 4
	jogo.ciclo.acoes = 4 - periodo
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
	checar(jogo.portas_das_lojas.size() == 3 and jogo.portas_das_lojas.has("mercadinho") and jogo.portas_das_lojas.has("padaria") and jogo.portas_das_lojas.has("bar_do_ze"), "três lojas de compras do nosso lado")

	# Dia 1, manhã: o mercadinho atende no balcão.
	await mudar_para(1, 0)
	olhar_para("mercadinho")
	await physics_frame
	var alvo: Dictionary = jogo.na_mira()
	checar(alvo.get("o_que", "") == "loja" and alvo.get("tipo", "") == "mercadinho", "mira encontra a porta do mercadinho")
	checar(jogo.dica_da_loja("mercadinho").begins_with("Entrar no mercadinho"), "dica oferece entrar")
	jogo.ciclo.dinheiro = 80
	var comida: int = jogo.ciclo.comida
	jogo.usar_o_que_estiver_na_mira()
	checar(jogo.na_loja == "mercadinho" and jogo.dialogo.visible and jogo.ciclo.acoes == 3, "entrar custa 1 ação e o dono atende")
	checar(jogo.dialogo.caminho_do_retrato == "res://sprites/lojas/mercadinho.png", "retrato do dono do mercadinho")
	fechar_falas()
	checar(jogo.escolha != null and jogo.escolha.name == "Balcao", "falas do dono abrem o balcão")
	var chaves: Array = jogo.escolha.opcoes.map(func(o): return o.chave)
	checar(chaves.has("arroz") and chaves.has("lanterna") and chaves.back() == "", "balcão lista produtos e a saída")
	jogo.responder_no_balcao("arroz")
	checar(jogo.ciclo.comida == comida + 5 and jogo.ciclo.dinheiro == 58, "arroz rende 5 comidas por R$ 22")
	checar(jogo.escolha != null and jogo.escolha.name == "Balcao", "balcão continua aberto depois da compra")
	jogo.ciclo.dinheiro = 3
	jogo.responder_no_balcao("arroz")
	checar(jogo.ciclo.dinheiro == 3 and jogo.ciclo.comida == comida + 5, "sem dinheiro não compra")
	jogo.responder_no_balcao("")
	checar(jogo.na_loja == "" and jogo.escolha == null and not jogo.dialogo.visible, "ir embora encerra o atendimento")

	# De noite, fechado só até de manhã: nada de arrombar.
	await mudar_para(1, 4)
	checar(nome_do_predio("mercadinho").contains("_fechado"), "de noite a porta de aço baixa")
	var acoes: int = jogo.ciclo.acoes
	jogo.entrar_na_loja("mercadinho")
	checar(jogo.arrombando == null and jogo.na_loja == "" and jogo.ciclo.acoes == acoes, "fechado à noite não abre nem deixa arrombar")

	# Dia 4: a padaria fechou de vez; mercadinho e bar seguem abertos de dia.
	await mudar_para(4, 0)
	checar(nome_do_predio("padaria").contains("_fechado") and nome_do_predio("mercadinho").contains("_aberto") and nome_do_predio("bar_do_ze").contains("_aberto"), "fechamento escalonado no dia 4")
	checar(jogo.dica_da_loja("padaria").begins_with("Arrombar a porta da padaria"), "padaria fechada oferece arrombar")
	await mudar_para(5, 0)
	checar(nome_do_predio("bar_do_ze").contains("_fechado") and nome_do_predio("mercadinho").contains("_aberto"), "bar fecha de vez no dia 5")
	await mudar_para(6, 0)
	checar(nome_do_predio("mercadinho").contains("_fechado"), "mercadinho fecha de vez no breu")

	# Arrombar a padaria: três golpes na faixa abrem e saqueiam.
	await mudar_para(4, 0)
	comida = jogo.ciclo.comida
	jogo.entrar_na_loja("padaria")
	checar(jogo.arrombando != null and jogo.ciclo.acoes == 3, "arrombar abre o minigame e custa 1 ação")
	for golpe in 3:
		var a: Arrombar3D = jogo.arrombando
		if a == null: break
		a.ponteiro = a.faixa_inicio + a.faixa_largura / 2.0
		a.golpear()
	checar(jogo.arrombando == null and jogo.lojas.saqueadas.has("padaria") and jogo.ciclo.comida == comida + 4, "três acertos abrem a padaria e levam o saque")
	acoes = jogo.ciclo.acoes
	jogo.entrar_na_loja("padaria")
	checar(jogo.arrombando == null and jogo.ciclo.acoes == acoes, "loja saqueada não abre de novo")

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

	# Dia 8: o estalo de um arrombamento errado puxa os caçadores até a porta.
	await mudar_para(8, 0)
	await physics_frame
	var bichos := get_nodes_in_group("cacadores3d")
	checar(bichos.size() == 3, "três caçadores no dia 8")
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

	print("LOJAS: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
