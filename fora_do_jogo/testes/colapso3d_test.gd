extends SceneTree

## O mundo desabando nas conversas: falas do breu e de depois do ataque, o
## vizinho que nunca virou amigo e agora chama as criaturas, o texto do roubo
## de madrugada e a escuta do som 3D.
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
	for i in 4: await process_frame
	return jogo

func rodar() -> void:
	var jogo: Node = await novo_jogo(6)
	checar((jogo.get_node("Tela/Render") as SubViewport).audio_listener_enable_3d, "a tela do mundo ouve o som 3D")
	# No breu, a primeira fala é sobre o breu.
	var morador: Vizinho3D = jogo.vizinhos[0]
	jogo.bater_na_porta(0)
	var primeira := str(jogo.dialogo.linhas[0])
	var do_breu: String = String(morador.dados.nos.breu.falas[0])
	checar(jogo.dialogo.visible and primeira == do_breu, "breu: o vizinho abre falando do breu (%s)" % primeira.left(40))
	jogo.encerrar_conversa()
	jogo.queue_free()
	await process_frame

	# Depois do ataque: quem nunca virou amigo está mudado e grita.
	jogo = await novo_jogo(9)
	morador = jogo.vizinhos[0]
	morador.historia.confianca = 0
	morador.historia.marcas = []
	jogo.bater_na_porta(0)
	checar(jogo.dialogo.visible and str(jogo.dialogo.linhas.back()) == jogo.GRITO_DO_MUDADO, "o vizinho mudado fala enigmático e termina gritando")
	while jogo.dialogo.visible: jogo.dialogo.avancar()
	await process_frame
	checar(not get_nodes_in_group("cacadores3d").is_empty(), "tem caçador na rua para atender o grito")
	checar(morador.historia.marcas.has("mudou"), "fica marcado como mudado")
	jogo.bater_na_porta(0)
	checar(not jogo.dialogo.visible and jogo.dica.recado.text.contains("Ninguém atende"), "da segunda vez a porta nem abre")
	# O amigo continua ele mesmo, falando do mundo.
	var amigo: Vizinho3D = jogo.vizinhos[1]
	amigo.historia.confianca = 2
	amigo.historia.marcas = ["ajudou"]
	jogo.bater_na_porta(1)
	checar(jogo.dialogo.visible and str(jogo.dialogo.linhas[0]) == String(amigo.dados.nos.depois.falas[0]), "o amigo segue ele mesmo, falando de depois do ataque")
	jogo.encerrar_conversa()
	jogo.queue_free()
	await process_frame

	# O roubo de madrugada, escrito direito.
	var ciclo := Ciclo3D.new()
	ciclo.suprimentos = 5
	var resumo := ciclo.dormir(["a porta da frente", "o portão"])
	checar(resumo.contains("A porta da frente e o portão ficaram sem tranca."), "roubo: frase certa (%s)" % resumo)
	ciclo.free()
	ciclo = Ciclo3D.new()
	ciclo.suprimentos = 5
	resumo = ciclo.dormir(["a porta dos fundos"])
	checar(resumo.contains("A porta dos fundos ficou sem tranca."), "roubo: uma porta só, no singular")
	ciclo.free()

	print("COLAPSO: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
