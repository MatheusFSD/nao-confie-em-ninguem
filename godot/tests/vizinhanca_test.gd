extends SceneTree

var falhas := 0
var verificacoes := 0

func checar(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		printerr("FAIL: ", texto)

func _initialize() -> void:
	call_deferred("rodar")

func rodar() -> void:
	var fases := {1: "inicio", 2: "abastecimento", 3: "estranho", 4: "estranho", 5: "fuga", 6: "breu", 7: "ataque", 8: "depois", 9: "depois", 10: "epilogo", 11: "epilogo"}
	for chave: String in Vizinho3D.CHAVES:
		var v := Vizinho3D.new(Vizinho3D.carregar(chave))
		checar(not v.dados.get("lore", {}).is_empty(), chave + " possui lore")
		checar(ResourceLoader.exists(v.retrato()), chave + " possui retrato")
		for dia: int in fases:
			v.iniciar(dia)
			checar(v.no_atual == fases[dia], chave + " fase do dia " + str(dia))
			checar(not v.falas().is_empty(), chave + " fala inicial")
			checar(v.opcoes().size() >= 3, chave + " respostas ramificadas")
		# Todas as referências do grafo e todas as condições conhecidas.
		for id: String in v.dados.nos:
			var no: Dictionary = v.dados.nos[id]
			for opcao: Dictionary in no.get("opcoes", []):
				var alvo := String(opcao.get("destino", ""))
				checar(alvo.is_empty() or v.dados.nos.has(alvo), chave + " referência " + alvo)
				checar(not String(opcao.get("texto", "")).is_empty(), chave + " opção com texto")
		v = Vizinho3D.new(Vizinho3D.carregar(chave))
		v.iniciar(1)
		checar(v.escolher("ouvir"), chave + " pergunta inicial")
		var primeira := v.falas()
		var confianca := int(v.historia.confianca)
		v.iniciar(1)
		v.escolher("ouvir")
		checar(int(v.historia.confianca) == confianca, chave + " sem ganhar confiança repetindo")
		v.iniciar(1)
		v.escolher("questionar")
		checar(v.falas() != primeira, chave + " respostas diferentes")
		v.iniciar(2)
		v.escolher("pedido")
		v.escolher("recusar")
		checar(v.adiado_ate == 3, chave + " recusa adia até amanhã")
		v.iniciar(2)
		checar(not tem_opcao(v, "pedido"), chave + " sem repetir pedido recusado no mesmo dia")
		v.iniciar(3)
		checar(tem_opcao(v, "pedido"), chave + " pedido volta")
		v.escolher("pedido")
		v.escolher("ajudar")
		checar(v.historia.marcas.has("ajudou"), chave + " ajuda lembrada")
		checar(v.falas().size() == 2, chave + " lembra a recusa antes da ajuda")
		v.iniciar(5)
		v.escolher("ouvir")
		checar(v.pode_passar_numero(), chave + " relação pode se recuperar")
		v.iniciar(6)
		v.mente = false
		var verdade := v.aviso()
		v.mente = true
		checar(v.aviso() != verdade, chave + " mentiroso dá outro aviso")
		v.escolher("aviso")
		v.escolher("cobrar")
		checar(v.falas()[0] == v.dados.nos.cobrado.variantes[0].falas[0], chave + " confrontação do mentiroso")
		v.iniciar(8)
		v.escolher("ouvir")
		v.escolher("rede")
		checar(v.historia.marcas.has("rede"), chave + " caminho de cooperação")
		v.iniciar(8)
		v.escolher("ouvir")
		v.escolher("isolou")
		checar(not v.historia.marcas.has("rede") and v.historia.marcas.has("isolou"), chave + " distância substitui acordo")
		v.iniciar(8)
		v.escolher("ouvir")
		v.escolher("rede")
		checar(not v.historia.marcas.has("isolou"), chave + " pode mudar de ideia sem finais simultâneos")
	var ciclo := Ciclo3D.new()
	for dia in range(1, 12):
		ciclo.dia = dia
		checar(ciclo.tem_agua_da_rede() == (dia < 7), "água dia " + str(dia))
		checar(ciclo.tem_energia_da_rede() == (dia < 6), "eletricidade dia " + str(dia))
		checar(ciclo.onibus_funciona() == (dia < 7), "ônibus dia " + str(dia))
	ciclo.dia = 6
	var acoes := ciclo.acoes
	var agua := ciclo.agua
	checar(ciclo.guardar_agua() and ciclo.agua == agua + 2, "água disponível no breu")
	checar(ciclo.acoes == acoes - 1, "guardar água custa ação")
	ciclo.dia = 7
	acoes = ciclo.acoes
	agua = ciclo.agua
	var energia := ciclo.energia
	var dinheiro := ciclo.dinheiro
	checar(not ciclo.guardar_agua(), "torneira cortada no ataque")
	checar(not ciclo.trabalhar() and not ciclo.ir_ao_mercado(), "viagens bloqueadas após breu")
	checar(not ciclo.assistir_tv("telejornal"), "TV bloqueada sem rede")
	checar(ciclo.acoes == acoes and ciclo.agua == agua and ciclo.energia == energia and ciclo.dinheiro == dinheiro, "bloqueios não gastam reservas")
	ciclo.comida = 0
	checar(not ciclo.pagar_escolha({"acoes":1,"item":"comida","quanto":1}), "ajuda sem recurso recusada")
	checar(ciclo.acoes == acoes, "tentativa falha não gasta ação")
	ciclo.comida = 2
	checar(ciclo.pagar_escolha({"acoes":1,"item":"comida","quanto":1}), "ajuda válida")
	checar(ciclo.comida == 1 and ciclo.acoes == acoes - 1, "custos descontados juntos")
	ciclo.free()
	# Um mentiroso por partida; instâncias não compartilham estado.
	var sorteados := Vizinho3D.sortear(5)
	var mentirosos := 0
	var chaves := []
	for v: Vizinho3D in sorteados:
		if v.mente: mentirosos += 1
		checar(not chaves.has(v.chave), "sorteio sem repetir")
		chaves.append(v.chave)
	checar(mentirosos == 1, "um mentiroso sorteado")
	var neide := Vizinho3D.new(Vizinho3D.carregar("neide"))
	var outra := Vizinho3D.new(Vizinho3D.carregar("neide"))
	neide.iniciar(1)
	neide.escolher("ouvir")
	checar(outra.historia.marcas.is_empty(), "estado de vizinhos isolado")
	var mensagens := Mensagens3D.new()
	var contatos := {"neide":2}
	neide.mente = false
	var caixa := mensagens.caixa(5, contatos, "Irmã", [neide])
	checar(tem_mensagem(caixa, "neide:breu_real") and not tem_mensagem(caixa, "neide:breu_falso"), "SMS condiz com papel do vizinho")
	caixa = mensagens.caixa(8, contatos, "Irmã", [neide])
	checar(tem_mensagem(caixa, "neide:breu_real"), "SMS recebido permanece")
	var tardias := Mensagens3D.new()
	caixa = tardias.caixa(8, {"neide":8}, "Irmã", [neide])
	checar(not tem_mensagem(caixa, "neide:breu_real"), "contato tardio não recebe aviso vencido")
	var falsas := Mensagens3D.new()
	neide.mente = true
	caixa = falsas.caixa(6, contatos, "Irmã", [neide])
	checar(tem_mensagem(caixa, "neide:corte_falso") and not tem_mensagem(caixa, "neide:corte_real"), "mentiroso também mente no SMS")
	print("VERIFICAÇÕES: %d; FALHAS: %d" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)

func tem_opcao(v: Vizinho3D, id: String) -> bool:
	for opcao: Dictionary in v.opcoes():
		if String(opcao.id) == id: return true
	return false

func tem_mensagem(caixa: Array, id: String) -> bool:
	for m: Dictionary in caixa:
		if String(m.chave) == id: return true
	return false
