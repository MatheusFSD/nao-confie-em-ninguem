extends SceneTree

## O menu do Esc (pausa e opções guardadas), as luzes acendendo no fim de tarde
## e o guarda-corpo na ponta do patamar da escada da laje.
var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	call_deferred("rodar")

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

func rodar() -> void:
	var jogo: Node = load("res://scenes/mundo3d.tscn").instantiate()
	jogo.dia = 2
	root.add_child(jogo)
	jogo.voltar_ao_menu_no_fim = false
	for i in 4: await process_frame

	# Esc: o jogo para e o menu aparece.
	jogo.jogador.pediu_pausa.emit()
	checar(jogo.pausa != null and paused, "Esc abre a pausa e congela o jogo")
	checar(not jogo.jogador.is_physics_processing(), "pausado, o morador não anda")
	var antigo: float = Configuracoes.carregar().volume
	Configuracoes.mudar("volume", 0.4)
	checar(absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.4) < 0.01, "volume vai para o barramento")
	var lido := ConfigFile.new()
	checar(lido.load(Configuracoes.ARQUIVO) == OK and absf(float(lido.get_value("opcoes", "volume", 0.0)) - 0.4) < 0.01, "volume fica guardado")
	Configuracoes.mudar("volume", antigo)
	Configuracoes.mudar("sensibilidade", 0.003)
	jogo.pausa.continuou.emit()
	checar(jogo.pausa == null and not paused and jogo.jogador.is_physics_processing(), "Continuar volta ao jogo")
	checar(absf(jogo.jogador.sensibilidade - 0.003) < 0.0001, "a sensibilidade nova vale na volta")
	Configuracoes.mudar("sensibilidade", Configuracoes.PADRAO.sensibilidade)
	# Com outra tela aberta, o Esc é dela, não da pausa.
	jogo.ligar_a_tv()
	jogo.abrir_pausa()
	checar(jogo.pausa == null, "com a TV ligada, sem pausa")
	jogo.desligar_a_tv()

	# Luzes: acesas no fim de tarde, apagadas de manhã.
	jogo.ciclo.horas = 22 - 9
	jogo.ciclo.mudou.emit()
	var acesos: Array = jogo.postes.filter(func(p): return p.visible)
	checar(acesos.is_empty(), "de manhã, postes apagados")
	jogo.ciclo.horas = 22 - 16
	jogo.ciclo.mudou.emit()
	acesos = jogo.postes.filter(func(p): return p.visible)
	checar(not acesos.is_empty(), "fim de tarde: postes acesos (%d)" % acesos.size())

	# Guarda-corpo: da ponta do patamar não se cai mais para fora.
	var espaco: PhysicsDirectSpaceState3D = jogo.mundo.get_world_3d().direct_space_state
	var lugar: Vector3 = jogo.CASA_LUGAR
	var de := lugar + Vector3(5.7, Casa3D.LAJE + 0.6, -5.3)
	var para := lugar + Vector3(5.7, Casa3D.LAJE + 0.6, -7.0)
	var bateu := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(de, para, 1))
	checar(not bateu.is_empty() and (bateu.position as Vector3).z > lugar.z - 6.2, "guarda-corpo na ponta do patamar")
	checar(jogo.mundo.find_child("GuardaCorpo", true, false) != null, "a grade aparece")
	jogo.queue_free()
	await process_frame

	print("PAUSA: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
