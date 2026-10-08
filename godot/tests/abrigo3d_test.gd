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

func tem_convite() -> bool:
	if jogo.escolha == null: return false
	for opcao: Dictionary in jogo.escolha.opcoes:
		if opcao.chave == "__abrigo": return true
	return false

func tecla(codigo: int) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.pressed = true
	root.push_input(evento)
	evento = InputEventKey.new()
	evento.physical_keycode = codigo
	evento.pressed = false
	root.push_input(evento)

func rodar() -> void:
	jogo = load("res://scenes/mundo3d.tscn").instantiate()
	root.add_child(jogo)
	current_scene = jogo
	await process_frame
	await physics_frame
	var amigo: Vizinho3D = jogo.vizinhos[0]
	for estado: Dictionary in [
		{"confianca": 0, "marcas": []},
		{"confianca": 2, "marcas": []},
		{"confianca": 1, "marcas": ["ajudou"]}]:
		amigo.historia.confianca = estado.confianca
		amigo.historia.marcas = estado.marcas
		jogo.bater_na_porta(0)
		fechar_falas()
		checar(not tem_convite(), "estranho ou amizade incompleta não recebe convite")
		jogo.responder_ao_vizinho("__abrigo")
		checar(jogo.abrigo == null and jogo.ciclo.acoes == 4, "confirmação inválida não entra nem cobra")
		jogo.encerrar_conversa()
	amigo.historia.confianca = 2
	amigo.historia.marcas = ["ajudou"]
	jogo.bater_na_porta(0)
	fechar_falas()
	checar(tem_convite(), "amigo recebe opção genérica sem editar diálogo")
	checar(jogo.escolha.opcoes.back().abaixo.contains("1 ação") and jogo.escolha.opcoes.back().abaixo.contains("0 energia"), "entrada anuncia custo")
	var lore_antes := amigo.no_atual
	jogo.escolha._espera = 0
	tecla(KEY_ESCAPE)
	checar(jogo.abrigo == null and jogo.ciclo.acoes == 4 and amigo.no_atual == lore_antes, "cancelar conversa não cobra nem altera lore")
	jogo.bater_na_porta(0)
	fechar_falas()
	amigo.historia.confianca = 1
	jogo.responder_ao_vizinho("__abrigo")
	checar(jogo.abrigo == null and jogo.ciclo.acoes == 4, "amizade revalidada após mostrar opção")
	jogo.encerrar_conversa()
	amigo.historia.confianca = 2
	jogo.jogador.global_position = amigo.porta.global_position + Vector3(0, 0.3, 2)
	var saida: Transform3D = jogo.jogador.global_transform
	jogo.ciclo.energia = 29
	jogo.ciclo.comida = 4
	jogo.ciclo.agua = 4
	jogo.bater_na_porta(0)
	fechar_falas()
	jogo.responder_ao_vizinho("__abrigo")
	checar(jogo.abrigo != null and jogo.abrigado_em == 0, "confirmação entra no abrigo amigo")
	checar(jogo.ciclo.acoes == 3 and jogo.ciclo.energia == 29 and jogo.ciclo.comida == 4 and jogo.ciclo.agua == 4, "entrada cobra uma ação e somente tempo")
	checar(jogo.abrigo._titulo.text.contains("Casa de " + amigo.nome), "local contextualizado")
	checar(not jogo.mundo.visible and jogo.mundo.process_mode == Node.PROCESS_MODE_DISABLED, "abrigo abstrato suspende rua")
	await physics_frame
	checar(not jogo.jogador.is_physics_processing(), "rede de destravar mantém jogador protegido")
	jogo.abrir_a_mochila()
	checar(jogo.mochila == null, "mochila não invade janela de abrigo")
	for i in 3:
		jogo.abrigo.menu._espera = 0
		tecla(KEY_1)
	checar(jogo.ciclo.acoes == 0 and jogo.abrigo != null and jogo.ciclo.dia == 1, "esperas avançam períodos e mantêm abrigo até noite")
	checar(jogo.abrigo.menu.opcoes[0].texto == "Esperar até amanhã" and jogo.abrigo.menu.opcoes[0].abaixo.contains("1 comida e 1 água"), "noite avisa consumo antes de confirmar")
	jogo.responder_no_abrigo("esperar")
	checar(jogo.ciclo.dia == 2 and jogo.ciclo.comida == 3 and jogo.ciclo.agua == 3 and jogo.ciclo.energia == 29, "noite consome reservas uma vez sem roubo ou recuperar energia")
	checar(jogo.abrigo != null and jogo.abrigado_em == 0 and not jogo.jogador.is_physics_processing(), "manhã permanece abrigada")
	var acoes: int = jogo.ciclo.acoes
	jogo.abrigo.menu._espera = 0
	tecla(KEY_ESCAPE)
	checar(jogo.abrigo == null and jogo.abrigado_em == -1 and jogo.ciclo.acoes == acoes, "Esc sai sem cobrança extra")
	checar(jogo.jogador.global_transform.is_equal_approx(saida) and jogo.jogador.velocity == Vector3.ZERO, "saída devolve posição salva na mesma porta")
	checar(jogo.mundo.visible and jogo.jogador.is_physics_processing(), "sair restaura rua e controle")
	jogo.ciclo.acoes = 0
	jogo.bater_na_porta(0)
	fechar_falas()
	checar(jogo.escolha.opcoes.back().abaixo.contains("Esperar até amanhã"), "entrada zerada anuncia manhã e consumo")
	jogo.responder_ao_vizinho("__abrigo")
	checar(jogo.ciclo.dia == 3 and jogo.ciclo.comida == 2 and jogo.ciclo.agua == 2 and jogo.abrigo != null, "entrada noturna consome uma única diária e fica abrigada")
	jogo.responder_no_abrigo("sair")
	var ciclo := Ciclo3D.new()
	ciclo.energia = 0
	ciclo.comida = 0
	ciclo.agua = 0
	ciclo.esperar_no_abrigo()
	checar(ciclo.acoes == 3 and ciclo.energia == 0, "energia zero não impede espera nem recebe energia extra")
	ciclo.acoes = 0
	ciclo.esperar_no_abrigo()
	checar(ciclo.dia == 2 and ciclo.acoes == 2 and ciclo.comida == 0 and ciclo.agua == 0 and ciclo.energia == 0, "noite sem reservas mantém penalidades normais sem gerar recursos")
	ciclo.free()
	print("ABRIGO: %d verificações; %d falhas" % [verificacoes, falhas])
	jogo.queue_free()
	await process_frame
	quit(1 if falhas > 0 else 0)
