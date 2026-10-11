extends SceneTree

## Sons: os sintetizados (motores, celular, letra), os gravados (bairro,
## cachorros, guerra, monstros, TV, rádio) no lugar certo de cada dia e hora, as
## letras surgindo nas falas com o tic, e a mesa de som (F9).
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

## Os tocadores 3D soltos no mundo que tocam um destes arquivos.
func tocando(jogo: Node, arquivos: Array) -> Array:
	return jogo.mundo.find_children("*", "AudioStreamPlayer3D", false, false).filter(func(s):
		return s.stream != null and arquivos.any(func(a): return s.stream.resource_path.ends_with(a)))

func rodar() -> void:
	var todos := Sons3D.todos()
	checar(todos.size() >= 42, "a mesa tem todos os sons (%d)" % todos.size())
	for par: Array in todos:
		checar(par[1] is AudioStream and (par[1] as AudioStream).get_length() > 0.02, "%s carrega" % par[0])
	checar(Sons3D.motor_carro().loop_mode == AudioStreamWAV.LOOP_FORWARD, "motor de carro em laço")

	# Camadas por dia e hora.
	var manha := AmbienteSonoro.alvos(1, 9)
	checar(manha.has("dia") and not manha.has("noite"), "manhã normal: pássaros e trânsito %s" % [manha])
	var noite := AmbienteSonoro.alvos(1, 21)
	checar(noite.has("noite") and not noite.has("dia") and not noite.has("beco"), "noite normal: só a praça calma %s" % [noite])
	checar(AmbienteSonoro.alvos(4, 9)["beco"] < manha["beco"], "cidade estranha: trânsito mais ralo")
	checar(AmbienteSonoro.alvos(6, 10).is_empty() and AmbienteSonoro.alvos(6, 21).is_empty(), "breu: nenhuma camada, silêncio")
	var guerra := AmbienteSonoro.alvos(7, 10)
	checar(guerra.has("guerra") and AmbienteSonoro.alvos(7, 20).has("guerra_perto"), "ataque: guerra longe de dia, perto de noite")
	checar(guerra.keys() == ["guerra"], "ataque: nada de pássaro nem inseto por baixo %s" % [guerra])
	var ruinas := AmbienteSonoro.alvos(9, 10)
	checar(ruinas.has("cidade_morta") and not ruinas.has("dia"), "cidade destruída: o coro de fundo %s" % [ruinas])

	var jogo: Node = await novo_jogo(2)
	checar(jogo.ambiente_sonoro != null, "o mundo tem o ambiente sonoro")
	for i in 30: await process_frame
	checar(jogo.ambiente_sonoro.get_node("Camada_dia").playing, "de manhã toca o bairro")
	var carros := get_nodes_in_group("carros3d")
	checar(not carros.is_empty() and carros[0].get_node_or_null("Motor") is AudioStreamPlayer3D, "carros com o motor de sempre")
	checar(carros[0].get_node_or_null("Pneus") is AudioStreamPlayer3D and carros[0].get_node("Motor").doppler_tracking != AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED, "carro passando: pneu e Doppler")
	jogo.ambiente_sonoro._proximo_latido = 0.0
	await process_frame
	await process_frame
	checar(not tocando(jogo, ["latido.ogg", "cachorro_grande.ogg", "cachorro_pequeno.ogg"]).is_empty(), "cachorro latindo (gravado)")

	# Fala: as letras surgem, E completa, E de novo avança.
	jogo.falar_como_irma("Irmã", ["Bom dia. Dormi mal.", "Liga a TV."])
	await process_frame
	checar(jogo.dialogo.escrevendo() and jogo.dialogo._texto.visible_characters < jogo.dialogo._texto.text.length(), "a fala começa surgindo")
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_E
	tecla.pressed = true
	jogo.dialogo._espera = 0.0
	jogo.dialogo._input(tecla)
	checar(not jogo.dialogo.escrevendo() and jogo.dialogo.indice == 0, "E no meio: mostra a fala inteira")
	jogo.dialogo._input(tecla)
	checar(jogo.dialogo.indice == 1 and jogo.dialogo.escrevendo(), "E de novo: próxima fala, surgindo")
	var limite := Time.get_ticks_msec() + 3000
	while jogo.dialogo.escrevendo() and Time.get_ticks_msec() < limite: await process_frame
	checar(not jogo.dialogo.escrevendo(), "sozinha, a fala termina de surgir")
	while jogo.dialogo.visible: jogo.dialogo.avancar()

	# Mesa de som.
	jogo.abrir_mesa_de_som()
	for i in 10: await physics_frame
	checar(jogo.mesa_de_som != null and not jogo.jogador.is_physics_processing(), "F9 abre a mesa e segura o jogador")
	jogo.mesa_de_som.tocar(20)
	checar(jogo.mesa_de_som._tocando != null, "a mesa toca um som gravado")
	jogo.abrir_mesa_de_som()
	checar(jogo.mesa_de_som == null and jogo.jogador.is_physics_processing(), "F9 de novo fecha")
	jogo.abrir_mesa_de_som()
	for i in 5: await physics_frame
	checar(jogo.mesa_de_som != null, "e abre de novo")
	jogo.mesa_de_som.fechou.emit()
	checar(jogo.mesa_de_som == null, "Esc dentro da mesa fecha")
	jogo.queue_free()
	await process_frame

	# O breu: sem cachorro, só o monstro à espreita, de longe.
	jogo = await novo_jogo(6)
	jogo.ambiente_sonoro._proximo_latido = 0.0
	jogo.ambiente_sonoro._proximo_monstro = 0.0
	await process_frame
	await process_frame
	checar(tocando(jogo, ["latido.ogg", "cachorro_grande.ogg", "cachorro_pequeno.ogg"]).is_empty(), "breu: nem cachorro")
	var no_breu := tocando(jogo, AmbienteSonoro.MONSTROS)
	checar(no_breu.size() == 1 and no_breu[0].stream.resource_path.ends_with("monstro_espreita.ogg"), "breu: só o monstro à espreita")
	jogo.queue_free()
	await process_frame

	# Dia do ataque: rádio da tropa, comboio roncando e disparos por cima.
	jogo = await novo_jogo(7)
	checar(jogo.radio_da_tropa != null and jogo.radio_da_tropa.playing, "dia 7: o rádio da tropa chia no caminhão")
	var comboio := get_nodes_in_group("militares3d")
	checar(not comboio.is_empty() and comboio.all(func(v): return v.get_node_or_null("Motor") is AudioStreamPlayer3D), "tanque e caminhões com motor")
	var tanque: Array = comboio.filter(func(v): return v.tipo == Militar3D.Tipo.TANQUE)
	checar(not tanque.is_empty() and tanque[0].get_node("Motor").stream == Sons3D.motor_tanque(), "o tanque com a esteira")
	var antes: int = jogo.mundo.get_child_count()
	jogo.ambiente_sonoro._proximo_disparo = 0.0
	for i in 40: await process_frame
	checar(jogo.mundo.find_children("*", "AudioStreamPlayer3D", false, false).size() > 0 and jogo.mundo.get_child_count() >= antes, "dia 7: disparos fortes por cima da guerra")
	jogo.queue_free()
	await process_frame

	# Cidade destruída: sem cachorro, com monstro no horizonte.
	jogo = await novo_jogo(9)
	jogo.ambiente_sonoro._proximo_latido = 0.0
	jogo.ambiente_sonoro._proximo_monstro = 0.0
	await process_frame
	await process_frame
	checar(tocando(jogo, ["latido.ogg", "cachorro_grande.ogg", "cachorro_pequeno.ogg"]).is_empty(), "depois do ataque, nem cachorro late")
	checar(not tocando(jogo, AmbienteSonoro.MONSTROS).is_empty(), "monstro ao fundo na cidade destruída")
	checar(jogo.radio_da_tropa == null or not jogo.radio_da_tropa.playing, "o rádio da tropa já foi embora")
	jogo.queue_free()
	await process_frame

	print("SONS: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
