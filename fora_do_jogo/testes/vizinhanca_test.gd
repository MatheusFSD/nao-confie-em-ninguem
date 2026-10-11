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
		checar(not v.aviso().is_empty(), chave + " tem dica do dia")
		checar(not v.dados.get("avisos", {}).values().any(func(a): return a.has("mentira")), chave + " sem dica falsa")
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
		checar(ciclo.tem_agua_da_rede() == (dia < 5), "água dia " + str(dia))
		checar(ciclo.tem_energia_da_rede() == (dia < 6), "eletricidade dia " + str(dia))
		checar(ciclo.onibus_funciona() == (dia < 6), "ônibus dia " + str(dia))
	ciclo.dia = 4
	var acoes := ciclo.horas
	var suprimentos := ciclo.suprimentos
	checar(ciclo.guardar_agua() and ciclo.suprimentos == suprimentos + 1, "água ainda vira suprimento no dia 4")
	checar(ciclo.horas == acoes - 1, "encher as garrafas custa uma hora")
	checar(not ciclo.guardar_agua() and ciclo.suprimentos == suprimentos + 1, "garrafas só uma vez por dia")
	ciclo.dia = 6
	var reservas_do_breu := [ciclo.horas, ciclo.suprimentos, ciclo.dinheiro]
	checar(not ciclo.guardar_agua(), "sem água no breu")
	checar(not ciclo.trabalhar() and not ciclo.ir_ao_mercado(), "viagens bloqueadas já no dia do breu")
	checar([ciclo.horas, ciclo.suprimentos, ciclo.dinheiro] == reservas_do_breu, "viagens no breu não gastam reservas")
	ciclo.dia = 7
	acoes = ciclo.horas
	suprimentos = ciclo.suprimentos
	var dinheiro := ciclo.dinheiro
	checar(not ciclo.guardar_agua(), "torneira cortada no ataque")
	checar(not ciclo.trabalhar() and not ciclo.ir_ao_mercado(), "viagens bloqueadas após breu")
	checar(not ciclo.assistir_tv("telejornal"), "TV bloqueada sem rede")
	checar(ciclo.horas == acoes and ciclo.suprimentos == suprimentos and ciclo.dinheiro == dinheiro, "bloqueios não gastam reservas")
	ciclo.suprimentos = 0
	checar(not ciclo.pagar_escolha({"acoes":1,"item":"comida","quanto":1}), "ajuda sem recurso recusada")
	checar(ciclo.horas == acoes, "tentativa falha não gasta tempo")
	ciclo.suprimentos = 2
	checar(ciclo.pagar_escolha({"acoes":1,"item":"comida","quanto":1}), "ajuda válida")
	checar(ciclo.suprimentos == 1 and ciclo.horas == acoes - 1, "custos descontados juntos")
	ciclo.free()
	# Cinco vizinhos por partida, sem repetir; instâncias não compartilham estado.
	var sorteados := Vizinho3D.sortear(5)
	var chaves := []
	for v: Vizinho3D in sorteados:
		checar(not chaves.has(v.chave), "sorteio sem repetir")
		chaves.append(v.chave)
	checar(sorteados.size() == 5, "cinco vizinhos sorteados")
	var neide := Vizinho3D.new(Vizinho3D.carregar("neide"))
	var outra := Vizinho3D.new(Vizinho3D.carregar("neide"))
	neide.iniciar(1)
	neide.escolher("ouvir")
	checar(outra.historia.marcas.is_empty(), "estado de vizinhos isolado")
	var mensagens := Mensagens3D.new()
	var contatos := {"neide":2}
	var caixa := mensagens.caixa(5, contatos, "Irmã", [neide])
	checar(tem_mensagem(caixa, "neide:breu_real") and not tem_mensagem(caixa, "neide:breu_falso"), "SMS verdadeiro do vizinho")
	caixa = mensagens.caixa(8, contatos, "Irmã", [neide])
	checar(tem_mensagem(caixa, "neide:breu_real"), "SMS recebido permanece")
	var tardias := Mensagens3D.new()
	caixa = tardias.caixa(8, {"neide":8}, "Irmã", [neide])
	checar(not tem_mensagem(caixa, "neide:breu_real"), "contato tardio não recebe aviso vencido")
	var todas := Mensagens3D.new()
	caixa = todas.caixa(6, contatos, "Irmã", [neide])
	checar(not tem_mensagem(caixa, "neide:corte_falso"), "nenhum SMS falso")
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
