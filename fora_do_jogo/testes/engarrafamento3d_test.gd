extends SceneTree

## O dia 5: a rua inteira tomada de carros nas duas faixas, andando devagar
## em anda-e-para, sem um entrar no outro, parando para quem está na frente, e
## sem pesar no quadro.
var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	call_deferred("rodar")

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

func civis(jogo: Node) -> Array:
	return get_nodes_in_group("carros3d").filter(func(c): return not (c as Node).is_in_group("militares3d"))

## O maior buraco entre dois carros seguidos da faixa, dentro do trecho da rua
## que se vê (RUA_LIMITE), contando as pontas.
func maior_buraco(jogo: Node, faixa: Array) -> float:
	var xs: Array = faixa.map(func(c): return (c as Node3D).position.x)
	xs = xs.filter(func(x): return x > jogo.RUA_LIMITE.x - 10.0 and x < jogo.RUA_LIMITE.y + 10.0)
	xs.sort()
	var maior := 0.0
	var antes: float = jogo.RUA_LIMITE.x - 10.0
	for x: float in xs:
		maior = maxf(maior, x - antes)
		antes = x
	return maxf(maior, jogo.RUA_LIMITE.y + 10.0 - antes)

## A menor folga entre para-choques na faixa (a faixa é um laço).
func menor_folga(faixa: Array, volta: float) -> float:
	var menor := 9999.0
	for carro: Carro3D in faixa:
		var frente := carro.frente as Carro3D
		var adiante := fposmod((frente.position.x - carro.position.x) * carro.sentido, volta)
		menor = minf(menor, adiante - (carro.comprimento + frente.comprimento) / 2.0)
	return menor

func rodar() -> void:
	var jogo: Node = load("res://scenes/mundo3d.tscn").instantiate()
	jogo.dia = 5
	root.add_child(jogo)
	jogo.voltar_ao_menu_no_fim = false
	for i in 4: await process_frame
	# Ninguém na rua atrapalhando a conta: o jogador fica em casa.
	jogo.jogador.global_position = jogo.CASA_LUGAR + Vector3(0, 0.3, 0)
	var carros := civis(jogo)
	checar(carros.size() == jogo.CARROS_NO_ENGARRAFAMENTO, "a rua tem %d carros (%d)" % [jogo.CARROS_NO_ENGARRAFAMENTO, carros.size()])
	var de_ca: Array = carros.filter(func(c): return absf((c as Node3D).position.z - jogo.FAIXA_DE_CA) < 0.1)
	var de_la: Array = carros.filter(func(c): return absf((c as Node3D).position.z - jogo.FAIXA_DE_LA) < 0.1)
	checar(de_ca.size() == de_la.size() and de_ca.size() + de_la.size() == carros.size(), "metade em cada faixa (%d/%d)" % [de_ca.size(), de_la.size()])
	checar(carros.all(func(c): return (c as Carro3D).no_engarrafamento), "todos no modo engarrafamento")
	checar(maior_buraco(jogo, de_ca) < 9.0 and maior_buraco(jogo, de_la) < 9.0, "a rua inteira tomada, sem trecho vazio (%.1f / %.1f m)" % [maior_buraco(jogo, de_ca), maior_buraco(jogo, de_la)])
	var volta: float = (carros[0] as Carro3D).limites.y - (carros[0] as Carro3D).limites.x
	checar(menor_folga(de_ca, volta) > 1.0 and menor_folga(de_la, volta) > 1.0, "ninguém começa colado em ninguém")

	# Uns segundos de engarrafamento.
	var antes := {}
	for c in carros: antes[c] = (c as Node3D).position.x
	var tempos := []
	var fim := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < fim:
		await physics_frame
		tempos.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var andou := 0.0
	for c in carros:
		andou += absf(fposmod((c as Node3D).position.x - float(antes[c]) + volta / 2.0, volta) - volta / 2.0)
	andou /= carros.size()
	checar(andou > 1.0 and andou < 20.0, "andam devagar: %.1f m em 12 s, em média" % andou)
	checar(menor_folga(de_ca, volta) > 0.5 and menor_folga(de_la, volta) > 0.5, "ninguém entrou em ninguém (%.2f / %.2f m)" % [menor_folga(de_ca, volta), menor_folga(de_la, volta)])
	checar(maior_buraco(jogo, de_ca) < 14.0 and maior_buraco(jogo, de_la) < 14.0, "a rua continua cheia (%.1f / %.1f m)" % [maior_buraco(jogo, de_ca), maior_buraco(jogo, de_la)])
	tempos.sort()
	var mediana: float = tempos[tempos.size() / 2]
	# Sem o corte dos motores longe, setenta sons 3D passavam de 20 ms.
	checar(mediana < 8.0, "a rua cheia não pesa no quadro (%.2f ms de process, mediana)" % mediana)
	var tocando := 0
	var longe_tocando := 0
	for c in carros:
		var longe := absf((c as Node3D).global_position.x - jogo.jogador.global_position.x) > Carro3D.MOTOR_ATE + 1.0
		for s in (c as Node).find_children("*", "AudioStreamPlayer3D", false, false):
			if (s as AudioStreamPlayer3D).playing:
				tocando += 1
				if longe: longe_tocando += 1
	checar(tocando > 0 and longe_tocando == 0, "motor só soa perto do jogador (%d tocando, %d longe)" % [tocando, longe_tocando])

	# O jogador parado na frente de um carro: o carro espera.
	var alvo: Carro3D = null
	for c: Carro3D in de_ca:
		if absf(c.position.x - 5.0) < 4.0: alvo = c
	checar(alvo != null, "tem carro na faixa de cá perto do meio da rua")
	if alvo != null:
		var na_frente := alvo.global_position + Vector3(alvo.sentido * (alvo.comprimento / 2.0 + 1.2), 0.3, 0.0)
		jogo.jogador.global_position = na_frente
		for i in 20: await physics_frame
		var parado_em := alvo.position.x
		fim = Time.get_ticks_msec() + 4000
		while Time.get_ticks_msec() < fim:
			jogo.jogador.global_position.x = na_frente.x
			jogo.jogador.global_position.z = na_frente.z
			await physics_frame
		checar(absf(alvo.position.x - parado_em) < 0.3, "parado na frente do carro, ele espera (andou %.2f m)" % absf(alvo.position.x - parado_em))

	# No breu a rua esvazia.
	jogo.ciclo.dia = 6
	jogo.virar_o_dia(6)
	await process_frame
	checar(civis(jogo).filter(func(c): return is_instance_valid(c) and not (c as Node).is_queued_for_deletion()).is_empty(), "no breu não sobra carro")

	print("ENGARRAFAMENTO: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
