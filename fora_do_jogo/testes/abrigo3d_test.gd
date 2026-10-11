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
		checar(not jogo.passando_a_noite_fora and jogo.ciclo.horas == 14, "confirmação inválida não entra nem cobra")
		jogo.encerrar_conversa()
	amigo.historia.confianca = 2
	amigo.historia.marcas = ["ajudou"]
	jogo.bater_na_porta(0)
	fechar_falas()
	checar(tem_convite(), "amigo recebe opção genérica sem editar diálogo")
	checar(jogo.escolha.opcoes.back().abaixo.contains("Passar a noite"), "a opção diz que é a noite inteira")
	var lore_antes := amigo.no_atual
	jogo.escolha._espera = 0
	tecla(KEY_ESCAPE)
	checar(not jogo.passando_a_noite_fora and jogo.ciclo.horas == 14 and amigo.no_atual == lore_antes, "cancelar conversa não cobra nem altera lore")
	jogo.bater_na_porta(0)
	fechar_falas()
	amigo.historia.confianca = 1
	jogo.responder_ao_vizinho("__abrigo")
	checar(not jogo.passando_a_noite_fora and jogo.ciclo.horas == 14, "amizade revalidada após mostrar opção")
	jogo.encerrar_conversa()
	amigo.historia.confianca = 2
	jogo.jogador.global_position = amigo.porta.global_position + Vector3(0, 0.3, 2)
	var saida: Transform3D = jogo.jogador.global_transform
	jogo.ciclo.suprimentos = 8
	jogo.bater_na_porta(0)
	fechar_falas()
	jogo.responder_ao_vizinho("__abrigo")
	await process_frame
	checar(jogo.passando_a_noite_fora and jogo.dialogo.visible and jogo.dialogo.caminho_do_retrato == amigo.retrato(), "ele confirma, falando")
	checar(jogo.escolha == null and jogo.abrigo == null, "sem menu de espera")
	fechar_falas()
	var limite := Time.get_ticks_msec() + 15000
	while jogo.passando_a_noite_fora and Time.get_ticks_msec() < limite: await process_frame
	checar(jogo.ciclo.dia == 2 and jogo.ciclo.suprimentos == 7, "a noite inteira passa lá: dia seguinte, uma diária")
	# Antes de entrar ele ainda cai os 0,3 m até o chão; o que conta é a porta.
	checar(jogo.jogador.global_transform.origin.distance_to(saida.origin) < 0.5 and jogo.jogador.is_physics_processing(), "acorda na mesma porta, com controle")
	checar(jogo.mundo.visible and jogo.abrigado_em == -1, "a rua continua lá")
	# Com a irmã junto: ela entra, entrega o rádio e passa a morar com ele.
	jogo.irma.global_position = jogo.jogador.global_position + Vector3(1, 0, 0)
	jogo.irma.seguir(jogo.jogador, jogo.camera)
	jogo.bater_na_porta(0)
	fechar_falas()
	jogo.responder_ao_vizinho("__abrigo")
	await process_frame
	checar(jogo.dialogo.linhas.size() == 2, "o vizinho também chama a irmã para entrar")
	jogo.dialogo.avancar()
	jogo.dialogo.avancar()
	await process_frame
	checar(jogo.dialogo.visible and jogo.dialogo.caminho_do_retrato == jogo.RETRATO_DA_IRMA, "lá dentro, ela entrega o rádio")
	checar(jogo.ciclo.irma_em_casa and jogo.ciclo.tem_radio and jogo.irma.seguindo == null, "e conta como resgatada")
	fechar_falas()
	limite = Time.get_ticks_msec() + 15000
	while jogo.passando_a_noite_fora and Time.get_ticks_msec() < limite: await process_frame
	checar(jogo.ciclo.dia == 3, "e a noite passa")
	var ciclo := Ciclo3D.new()
	ciclo.suprimentos = 0
	ciclo.esperar_no_abrigo()
	checar(ciclo.hora() == 12, "esperar abrigado pula para o próximo período")
	ciclo.horas = 0
	ciclo.esperar_no_abrigo()
	checar(ciclo.dia == 2 and ciclo.hora() == 11 and ciclo.suprimentos == 0 and ciclo.fraqueza == 1, "noite sem reservas enfraquece sem gerar recursos")
	ciclo.free()
	print("ABRIGO: %d verificações; %d falhas" % [verificacoes, falhas])
	jogo.queue_free()
	await process_frame
	quit(1 if falhas > 0 else 0)
