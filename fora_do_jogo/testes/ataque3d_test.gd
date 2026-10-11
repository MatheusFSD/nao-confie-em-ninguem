extends SceneTree

## Caçadores atacam: percebem pelo barulho (parado, andando, correndo), dão o
## bote e matam (menos no modo deus); não têm luz própria; fazem passos. O
## Observador, depois do ataque, grita ao ver o jogador na rua e põe os
## caçadores na caça.
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

func esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim: await physics_frame

func rodar() -> void:
	jogo = load("res://scenes/mundo3d.tscn").instantiate()
	jogo.dia = 8
	root.add_child(jogo)
	current_scene = jogo
	jogo.voltar_ao_menu_no_fim = false
	await process_frame
	await physics_frame
	var bichos := get_nodes_in_group("cacadores3d")
	checar(bichos.size() == jogo.CACADORES_DEPOIS, "dia 8, de dia: a rua cheia de caçadores (%d)" % bichos.size())
	var bicho: Cacador3D = bichos[0]
	for outro in bichos.slice(1): (outro as Node).process_mode = Node.PROCESS_MODE_DISABLED

	# Sem luz própria: surpresa na lanterna.
	checar(bicho.find_children("*", "OmniLight3D", true, false).is_empty(), "caçador sem luz no rosto")
	# Sons de passo gerados.
	checar(Sons3D.passo_pesado().data.size() > 1000 and Sons3D.passo_corrida().data.size() > 500 and Sons3D.grito().data.size() > 10000, "passos e grito sintetizados")
	checar(bicho.get_node_or_null("Passos") is AudioStreamPlayer3D, "caçador com som de passos")

	# Ouvido: parado quase encostado, andando perto, correndo longe.
	jogo.jogador.velocity = Vector3.ZERO
	var parado: float = bicho.alcance_do_ouvido()
	jogo.jogador.velocity = Vector3(2.5, 0, 0)
	var andando: float = bicho.alcance_do_ouvido()
	jogo.jogador.velocity = Vector3(5.4, 0, 0)
	var correndo: float = bicho.alcance_do_ouvido()
	checar(parado < andando and andando < correndo and correndo >= 6.0 and parado <= 2.0, "ouvido: parado %.1f, andando %.1f, correndo %.1f m" % [parado, andando, correndo])
	jogo.jogador.velocity = Vector3.ZERO

	# Longe e parado: não percebe.
	var rua := Vector3(30.0, 0.1, 28.2)
	jogo.jogador.global_position = rua
	jogo.jogador.set_physics_process(false)
	bicho.global_position = rua + Vector3(4.0, 0, 0)
	await esperar(0.4)
	checar(not bicho.percebe_jogador(), "a 4 m, parado: ele não percebe")

	# Modo deus: só cheira e vai embora.
	jogo.ciclo.virar_deus(true)
	bicho.global_position = rua + Vector3(1.2, 0, 0)
	await esperar(1.5)
	checar(not jogo.pego, "modo deus: o bote não mata")
	jogo.ciclo.virar_deus(false)
	bicho.soltar()

	# Bote: perto demais, é o fim.
	bicho.global_position = rua + Vector3(1.2, 0, 0)
	await esperar(2.5)
	checar(jogo.pego and jogo.ultimo_final == "PEGO NO ESCURO", "chegou perto: o bote, final Pego no escuro")

	# Observador: depois do ataque, vê o jogador na rua, grita e chama a caça.
	jogo.pego = false
	for c in bichos: (c as Node).process_mode = Node.PROCESS_MODE_INHERIT
	for c in bichos: (c as Cacador3D).global_position = Vector3(-30, 0.1, 25)
	var obs: Observadores3D = jogo.observadores
	# Fim de tarde: o horário dessa aparição no roteiro.
	jogo.ciclo.horas = Ciclo3D.DORME - 16
	obs.set_process(true)
	jogo.jogador.global_position = Vector3(40.0, 0.1, 28.2)
	var aparicao: Dictionary = {}
	for a in obs.dados.aparicoes:
		if a.id == "ruinas_no_fim_da_rua": aparicao = a
	obs.surgir(aparicao, Vector3(60.0, 0.0, 28.2))
	await esperar(1.0)
	checar(obs._gritou, "o Observador viu o jogador na rua e gritou")
	checar(bichos.all(func(c): return c._cacando > 0.0), "os caçadores estão na caça")
	# Dentro do lote de casa, ninguém vê.
	obs.retirar()
	jogo.jogador.global_position = Vector3(12.5, 0.1, 12.0)
	obs.surgir(aparicao, Vector3(12.5, 0.0, 26.0))
	await esperar(1.0)
	checar(not obs._gritou, "em casa: o Observador não grita")
	# Antes do ataque ele não é olho de ninguém.
	obs.retirar()
	jogo.ciclo.dia = 3
	jogo.jogador.global_position = Vector3(40.0, 0.1, 28.2)
	obs.surgir(aparicao, Vector3(60.0, 0.0, 28.2))
	await esperar(1.0)
	checar(not obs._gritou, "antes do dia 8 ele só observa")

	print("ATAQUE: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
