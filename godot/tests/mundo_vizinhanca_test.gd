extends SceneTree

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

func tecla(codigo: int) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.pressed = true
	root.push_input(evento)
	evento = InputEventKey.new()
	evento.physical_keycode = codigo
	evento.pressed = false
	root.push_input(evento)

func clique(botao: Button) -> void:
	var posicao := botao.get_global_rect().get_center()
	var movimento := InputEventMouseMotion.new()
	movimento.position = posicao
	root.push_input(movimento, true)
	var evento := InputEventMouseButton.new()
	evento.position = posicao
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	root.push_input(evento, true)
	evento = InputEventMouseButton.new()
	evento.position = posicao
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = false
	root.push_input(evento, true)

func rodar() -> void:
	jogo = load("res://scenes/mundo3d.tscn").instantiate()
	root.add_child(jogo)
	current_scene = jogo
	await process_frame
	await physics_frame
	checar(jogo.ciclo.dia == 1, "começa no dia 1")
	checar(jogo.vizinhos.size() == 5, "cinco vizinhos na cena")
	for v: Vizinho3D in jogo.vizinhos:
		checar(v.porta != null and v.casa != null, "vizinho associado a casa e porta")
	var torneiras := []
	for no: Node in jogo.mundo.get_children():
		if no.has_meta("torneira"): torneiras.append(no)
	checar(torneiras.size() == 2, "duas pias interativas")
	for torneira: Node in torneiras:
		checar(torneira.get_child_count() > 0, "pia possui colisão interativa")
	jogo.bater_na_porta(0)
	checar(jogo.dialogo.visible and not jogo.jogador.is_physics_processing(), "conversa prende jogador")
	checar(jogo.vizinhos[0].adiado_ate == 2, "pedido só depois da primeira visita")
	fechar_falas()
	checar(jogo.escolha != null and jogo.dialogo.visible, "respostas preservam a fala e o retrato")
	jogo.responder_ao_vizinho("ouvir")
	checar(jogo.dialogo.visible and jogo.escolha != null, "resposta continua na mesma caixa de conversa")
	fechar_falas()
	jogo.responder_ao_vizinho("sair")
	checar(jogo.na_porta == -1 and jogo.jogador.is_physics_processing(), "encerrar devolve controle")
	# Teclado e clique percorrem o diálogo real, sem chamar o controlador.
	jogo.bater_na_porta(0)
	for i in 6: await process_frame
	checar(jogo.escolha.get_parent() == jogo.dialogo._coluna, "respostas dentro da caixa de conversa")
	checar(jogo.dialogo.retrato != null, "retrato preservado ao responder")
	jogo.escolha._espera = 0
	tecla(KEY_DOWN)
	checar(jogo.escolha.escolha == 1, "seta seleciona segunda resposta")
	tecla(KEY_UP)
	checar(jogo.escolha.escolha == 0, "seta retorna à primeira resposta")
	tecla(KEY_1)
	checar(jogo.vizinhos[0].no_atual == "inicio_ouvir", "atalho numérico responde")
	for i in 6: await process_frame
	jogo.escolha._espera = 0
	clique(jogo.escolha._botoes[0])
	checar(jogo.vizinhos[0].no_atual == "inicio", "clique escolhe resposta e retorna à conversa")
	for i in 6: await process_frame
	jogo.escolha._espera = 0
	tecla(KEY_ESCAPE)
	checar(jogo.na_porta == -1 and not jogo.dialogo.visible, "Esc encerra com mouse e teclado funcionando")
	jogo.ciclo.dia = 2
	jogo.virar_o_dia(2)
	jogo.bater_na_porta(0)
	fechar_falas()
	jogo.responder_ao_vizinho("pedido")
	fechar_falas()
	var acoes: int = jogo.ciclo.acoes
	jogo.ciclo.comida = 99
	jogo.ciclo.agua = 99
	jogo.ciclo.energia = 100
	jogo.ciclo.dinheiro = 99
	jogo.responder_ao_vizinho("ajudar")
	checar(jogo.ciclo.acoes == acoes - 1, "ajuda cobra uma ação na cena")
	checar(jogo.ciclo.contatos.has(jogo.vizinhos[0].chave), "ajuda libera contato depois de ouvir")
	fechar_falas()
	checar(jogo.na_porta == -1, "agradecimento encerra sem repetir pedido")
	# O menu anuncia o custo real e impede confirmar uma viagem indisponível.
	jogo.ciclo.dia = 5
	jogo.ciclo.acoes = 4
	jogo.ciclo.energia = 100
	jogo.abrir_menu_do_ponto()
	checar(jogo.menu != null, "ônibus disponível no último dia antes do breu")
	checar(jogo.menu._detalhe.text.contains("2 ações") and jogo.menu._detalhe.text.contains("10 de energia") and jogo.menu._detalhe.text.contains("R$ 40"), "menu anuncia custo e recompensa do trabalho")
	jogo.menu.escolha = 1
	jogo.menu.pintar()
	checar(jogo.menu._detalhe.text.contains("1 ação") and jogo.menu._detalhe.text.contains("2 de energia") and jogo.menu._detalhe.text.contains("Compras cobradas à parte"), "menu anuncia custo do mercado e pagamento separado")
	jogo.ciclo.acoes = 1
	jogo.menu.escolha = 0
	jogo.menu.pintar()
	checar(not jogo.menu.pode_ir(0) and jogo.menu._detalhe.text.contains("faltam ações"), "trabalho indisponível explicado antes de confirmar")
	jogo.menu._espera = 0
	tecla(KEY_ENTER)
	checar(jogo.menu != null and jogo.expediente == null and jogo.ciclo.acoes == 1, "confirmar sem ações mantém menu e reservas")
	jogo.ciclo.acoes = 4
	jogo.ciclo.energia = 1
	jogo.menu.escolha = 1
	jogo.menu.pintar()
	checar(not jogo.menu.pode_ir(1) and jogo.menu._detalhe.text.contains("falta energia"), "mercado indisponível por energia")
	jogo.ciclo.energia = 100
	jogo.fechar_menu_do_ponto("")
	for dia in [6, 7, 8]:
		jogo.ciclo.dia = dia
		jogo.ciclo.acoes = 0
		jogo.virar_o_dia(dia)
		await process_frame
		checar(jogo.e_dia_de_breu() == (dia == 6), "breu só no dia 6")
		checar(jogo.cidade.estado == ("estranha" if dia == 6 else ("chamas" if dia == 7 else "destruida")), "cidade segue calendário")
		for lampada: OmniLight3D in jogo.casa.lampadas:
			checar(not lampada.visible, "luz elétrica não volta após o breu")
		for poste: OmniLight3D in jogo.postes:
			checar(not poste.visible, "poste desligado")
		jogo.ligar_a_tv()
		checar(jogo.tv == null, "TV não abre sem energia")
		jogo.abrir_menu_do_ponto()
		checar(jogo.menu == null and jogo.expediente == null, "ponto inativo no breu e nos dias seguintes")
		checar((jogo.get_node("Tela/Render/Sol") as DirectionalLight3D).light_energy > 0.0 if dia > 6 else (jogo.get_node("Tela/Render/Sol") as DirectionalLight3D).light_energy == 0.0, "luz natural volta depois do breu")
	jogo.ciclo.acoes = 4
	jogo.bater_na_porta(0)
	fechar_falas()
	checar(jogo.vizinhos[0].no_atual == "depois", "visita pós-ataque usa nova fase")
	jogo.responder_ao_vizinho("")
	checar(jogo.na_porta == -1 and jogo.jogador.is_physics_processing(), "Esc encerra sem recusa forçada")
	print("INTEGRAÇÃO: %d verificações; %d falhas" % [verificacoes, falhas])
	jogo.queue_free()
	await process_frame
	quit(1 if falhas > 0 else 0)
