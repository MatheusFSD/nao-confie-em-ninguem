class_name Ciclo3D
extends Node

# O dia do morador. O relógio vai das 8h às 22h e só anda quando se faz alguma
# coisa: cada tarefa custa horas (entrar numa loja, encher as garrafas, ir
# trabalhar), e o sofá passa o tempo de propósito. Às 22h não dá mais para
# fazer nada além de dormir.
#
# Dormir fecha o dia consumindo suprimentos — comida, água, pilhas, remédio:
# tudo o que se guarda em casa conta junto. A conta cresce com o colapso: 1 por
# dia enquanto há água e luz, 2 quando a água é cortada (dia 5), 3 depois que a
# luz acaba (breu, dia 6). Com a irmã em casa é 1 a mais — mas ela cuida da casa:
# o dia rende 2 horas a mais e ninguém entra de madrugada.
#
# Faltar suprimento enfraquece: acorda-se mais tarde (3 horas a menos por nível
# de fraqueza). Cada noite com falta soma um nível. Só se melhora comendo
# reforçado: numa noite em que sobra suprimento além do consumo, gasta-se 1 a
# mais e cai um nível; comendo só o mínimo, continua fraco. No terceiro nível,
# não se acorda mais.
#
# A água da torneira pode estar contaminada a partir do dia 3: é sorteado a
# cada partida, e só o noticiário conta a verdade (e nem toda fonte). Beber
# sem ferver adoece de madrugada — um nível de fraqueza. Ferver leva o dobro
# do tempo.
#
# Aqui ficam só as regras e as contas. Quem pinta o céu, acende as lâmpadas e
# esvazia a rua é o mundo, que escuta o sinal `mudou`.
signal mudou
signal virou_o_dia(dia: int)
## A fraqueza chegou ao limite durante a noite.
signal morreu(motivo: String)

const ACORDA := 8
const DORME := 22
const HORAS_DO_DIA := DORME - ACORDA
const DIA_DO_CORTE := 5
const DIA_DO_BREU := 6
## O dia em que a invasão chega fisicamente (comboio, chamas).
const DIA_DO_ATAQUE := 7
const TRABALHO := {"horas": 8, "paga": 25}
## O mercado de ônibus ficou sem acesso; o custo fica para quem ainda o lê.
const MERCADO := {"horas": 2}
## Hora em que cada período começa.
const PERIODOS := ["Manhã", "Tarde", "Fim de tarde", "Anoitecer", "Noite"]
const COMECO_DOS_PERIODOS := [8, 12, 16, 18, 20]
## Horas a menos no dia seguinte por noite seguida de falta.
const HORAS_PERDIDAS_POR_FRAQUEZA := 3
## Na terceira noite seguida sem suprimento suficiente, o morador não acorda.
const LIMITE_DA_FRAQUEZA := 3
## O que a irmã em casa muda: come junto, mas toca a casa.
const IRMA_CONSOME := 1
const IRMA_DA_HORAS := 2
## Desde quando a água da rede pode vir contaminada, e a chance disso numa
## partida.
const DIA_DA_CONTAMINACAO := 3
const CHANCE_DE_CONTAMINAR := 0.5
## O que o modo deus põe na despensa e na carteira.
const FARTURA := 99
const RIQUEZA := 999999

var dia := 1
## Horas que ainda dá para usar hoje, até as 22h.
var horas := HORAS_DO_DIA
## A despensa inteira num número só: comida, água, pilhas e o resto do básico.
var suprimentos := 3
var dinheiro := 30
## Fraqueza acumulada: sobe com cada noite de falta; só desce comendo reforçado.
var fraqueza := 0
var irma_em_casa := false
## A irmã trouxe o rádio a pilha: notícia mesmo sem luz.
var tem_radio := false
## Sorteado no começo da partida: a água da rede vai ou não vir contaminada.
var agua_vai_contaminar := false
## Bebeu água da torneira sem ferver num dia de contaminação.
var passou_mal := false
var morto := false
## Modo deus: para testar o jogo sem jogar. Nada se gasta, nada falta e nada
## mata — os perigos que vierem também olham para esta chave.
var modo_deus := false
## Quem já passou o número: chave do vizinho e o dia em que ele passou. É por
## aqui que as mensagens dele começam a chegar no celular.
var contatos := {}
## A lanterna acesa ou apagada.
var lanterna_acesa := false
## A lanterna comprada no mercadinho. Ela não serve para nada enquanto há luz na
## rua — é para o dia em que não houver.
var tem_lanterna := false
## As garrafas só se enchem uma vez por dia.
var garrafas_cheias_hoje := false
## Canais já vistos hoje.
var tv_vista := {}
## Última coisa que aconteceu, para o mundo mostrar.
var recado := ""

func tem_energia_da_rede() -> bool:
	return dia < DIA_DO_BREU

func tem_agua_da_rede() -> bool:
	return dia < DIA_DO_CORTE

## Sorteia, para a partida, se a água vai vir contaminada.
func sortear_a_agua(semente := -1) -> void:
	var sorte := RandomNumberGenerator.new()
	if semente >= 0: sorte.seed = semente
	else: sorte.randomize()
	agua_vai_contaminar = sorte.randf() < CHANCE_DE_CONTAMINAR

func agua_contaminada() -> bool:
	return agua_vai_contaminar and dia >= DIA_DA_CONTAMINACAO and tem_agua_da_rede()

func onibus_funciona() -> bool:
	return dia < DIA_DO_BREU

## Quanto a noite de hoje vai consumir da despensa.
func consumo_da_noite() -> int:
	var base := 1 if tem_agua_da_rede() else (2 if tem_energia_da_rede() else 3)
	return base + (IRMA_CONSOME if irma_em_casa else 0)

# ------------------------------------------------------------------- relógio

func hora() -> int:
	return DORME - horas

func texto_da_hora() -> String:
	return "%02d:00" % hora()

## Quanto do dia já passou: 0 às 8h, 1 às 22h.
func progresso() -> float:
	return clampf(float(hora() - ACORDA) / float(HORAS_DO_DIA), 0.0, 1.0)

## Em que pedaço do dia o relógio está, de 0 (manhã) a 4 (noite).
func indice_do_periodo() -> int:
	var qual := 0
	for i in COMECO_DOS_PERIODOS.size():
		if hora() >= int(COMECO_DOS_PERIODOS[i]): qual = i
	return qual

func periodo() -> String:
	return PERIODOS[indice_do_periodo()]

func e_noite() -> bool:
	return hora() >= int(COMECO_DOS_PERIODOS[3])

## Põe o relógio no começo de um período. Ferramenta de teste: só no modo deus.
func por_o_periodo(qual: int) -> String:
	if not modo_deus: return ""
	var alvo := clampi(qual, 0, PERIODOS.size() - 1)
	horas = DORME - int(COMECO_DOS_PERIODOS[alvo])
	recado = "Modo deus: %s." % PERIODOS[alvo]
	mudou.emit()
	return PERIODOS[alvo]

## O sofá: deixa o relógio correr até `ate` (uma hora cheia). Não gasta nada
## além do tempo.
func passar_ate(ate: int) -> bool:
	var alvo := clampi(ate, hora(), DORME)
	if alvo <= hora(): return false
	horas = DORME - alvo
	recado = "O tempo passou. Agora são %s." % texto_da_hora()
	mudou.emit()
	return true

## As horas cheias em que começam os próximos períodos, para o sofá oferecer.
func proximos_periodos() -> Array:
	var lista := []
	for i in COMECO_DOS_PERIODOS.size():
		if int(COMECO_DOS_PERIODOS[i]) > hora(): lista.append({"hora": int(COMECO_DOS_PERIODOS[i]), "periodo": PERIODOS[i]})
	return lista

# ------------------------------------------------------------------- gastos

## Liga ou desliga o modo deus. Ligado, enche a despensa e a carteira;
## desligado, só para de proteger — o que já está guardado continua guardado.
func virar_deus(ligado: bool) -> void:
	modo_deus = ligado
	if ligado:
		suprimentos = FARTURA
		dinheiro = RIQUEZA
		tem_lanterna = true
		fraqueza = 0
	recado = "Modo deus ligado." if ligado else "Modo deus desligado."
	mudou.emit()

## Tenta gastar horas. Devolve falso e explica quando não dá.
func gastar(quantas: int) -> bool:
	if modo_deus: return true
	if horas < quantas:
		recado = "Não dá tempo: isso leva %dh e já são %s. Nem com horário de verão." % [quantas, texto_da_hora()] if horas > 0 else "Já é tarde demais. A cama é a única coisa que ainda funciona neste país."
		mudou.emit()
		return false
	horas -= quantas
	mudou.emit()
	return true

## Encher as garrafas: 1h, ou 2h fervendo. Contaminada e sem ferver, adoece
## de madrugada.
func guardar_agua(ferver := false) -> bool:
	if not tem_agua_da_rede():
		recado = "Abastecimento cortado. A torneira só solta um assobio — e a conta, essa, vai chegar."
		mudou.emit()
		return false
	if garrafas_cheias_hoje:
		recado = "As garrafas já estão cheias. Mais que isso só se você beber direto do cano."
		mudou.emit()
		return false
	if not gastar(2 if ferver else 1): return false
	garrafas_cheias_hoje = true
	suprimentos += 1
	if agua_contaminada() and not ferver: passou_mal = true
	recado = "Você ferveu e encheu as garrafas: +1 suprimento." if ferver else "Você encheu as garrafas: +1 suprimento."
	mudou.emit()
	return true

## Verifica todos os custos antes de descontar qualquer recurso. Aceita os
## nomes antigos dos dados ("acoes", "comida", "agua", "energia").
func pagar_escolha(custo: Dictionary) -> bool:
	var h := int(custo.get("horas", custo.get("acoes", 0)))
	var item := String(custo.get("item", ""))
	var quanto := int(custo.get("quanto", 0))
	if h < 0 or quanto < 0: return false
	if modo_deus: return true
	var tem := 0
	match item:
		"": tem = quanto
		"suprimentos", "comida", "agua", "energia": tem = suprimentos
		"dinheiro": tem = dinheiro
		_: return false
	if horas < h or tem < quanto:
		recado = "Não dá mais tempo para isso." if horas < h else "Você não tem isso para dar."
		mudou.emit()
		return false
	horas -= h
	match item:
		"suprimentos", "comida", "agua", "energia": suprimentos -= quanto
		"dinheiro": dinheiro -= quanto
	mudou.emit()
	return true

func trabalhar() -> bool:
	if not onibus_funciona():
		recado = "Ônibus fora de serviço. O fim do mundo finalmente te deu folga."
		mudou.emit()
		return false
	if not gastar(int(TRABALHO.horas)): return false
	dinheiro += int(TRABALHO.paga)
	recado = "Dia de trabalho: +R$ %d." % TRABALHO.paga
	mudou.emit()
	return true

func ir_ao_mercado() -> bool:
	if not onibus_funciona():
		recado = "Os ônibus pararam. Não dá para chegar ao mercado."
		mudou.emit()
		return false
	return gastar(int(MERCADO.horas))

## Tirar da despensa ou da carteira para dar a alguém. Devolve falso quando não
## há o que dar.
func pagar(item: String, quanto: int) -> bool:
	if modo_deus: return true
	match item:
		"suprimentos", "comida", "agua", "energia":
			if suprimentos < quanto: return false
			suprimentos -= quanto
		"dinheiro":
			if dinheiro < quanto: return false
			dinheiro -= quanto
		_: return true
	mudou.emit()
	return true

## Ligar a TV. Só pede luz da rede.
func assistir_tv(canal: String) -> bool:
	if not tem_energia_da_rede():
		recado = "Sem energia. A TV ia dizer que estava tudo sob controle mesmo."
		mudou.emit()
		return false
	tv_vista[canal] = true
	return true

## O que entra em casa: suprimentos e o que sobrou na carteira.
func guardar(quantos_suprimentos: int, quanto_sobrou: int) -> void:
	suprimentos += quantos_suprimentos
	dinheiro = RIQUEZA if modo_deus else quanto_sobrou
	mudou.emit()

## Esperar protegido cobra tempo, nunca suprimento extra: pula para o começo
## do próximo período.
func esperar_no_abrigo() -> String:
	if horas > 0:
		var proximos := proximos_periodos()
		passar_ate(int(proximos[0].hora) if not proximos.is_empty() else DORME)
		return "Você continua abrigado. Agora são %s." % texto_da_hora()
	# As reservas acompanham o jogador no abrigo. Portas da própria casa não
	# causam um roubo implícito aqui; a regra de dormir em casa continua igual.
	return dormir([])

# ------------------------------------------------------------------- noite

## "a, b e c": uma lista em português.
static func juntar(itens: Array) -> String:
	if itens.size() <= 1: return "".join(itens)
	return ", ".join(itens.slice(0, itens.size() - 1)) + " e " + String(itens.back())

## Fecha o dia. `portas_abertas` são as portas para a rua que ficaram sem
## tranca — por elas alguém entra de madrugada. Devolve o resumo da noite.
func dormir(portas_abertas: Array) -> String:
	var contas: Array[String] = []
	if modo_deus:
		# No modo deus a noite não cobra nada: só vira o dia.
		dia += 1
		amanhecer(HORAS_DO_DIA)
		virar_deus(true)
		virou_o_dia.emit(dia)
		return "Modo deus: a noite não cobrou nada."
	var consumo := consumo_da_noite()
	var falta := maxi(0, consumo - suprimentos)
	var adoeceu := passou_mal
	if passou_mal:
		passou_mal = false
		fraqueza += 1
		contas.append("A água da torneira te fez mal de madrugada.")
	suprimentos = maxi(0, suprimentos - consumo)
	if falta > 0:
		fraqueza += 1
		contas.append("Faltaram %d suprimento%s para a noite." % [falta, "" if falta == 1 else "s"])
	elif not adoeceu and fraqueza > 0:
		if suprimentos > 0:
			suprimentos -= 1
			fraqueza -= 1
			contas.append("Você comeu reforçado. A fraqueza diminuiu.")
		else:
			contas.append("Deu pra comer só o mínimo. Você continua fraco.")
	if falta == 0 and suprimentos == 0: contas.append("A despensa ficou vazia.")
	if fraqueza >= LIMITE_DA_FRAQUEZA:
		morto = true
		var motivo := "Noites demais sem comer nem beber o bastante. Você não acordou."
		recado = motivo
		mudou.emit()
		morreu.emit(motivo)
		return motivo
	if fraqueza == 1: contas.append("Você acordou fraco e tarde.")
	elif fraqueza == 2: contas.append("Você mal consegue levantar. Mais uma noite assim e não acorda.")
	if not portas_abertas.is_empty() and suprimentos > 0:
		var quais := juntar(portas_abertas)
		if irma_em_casa:
			contas.append("Sua irmã trancou %s antes de dormir." % quais)
		else:
			suprimentos -= 1
			contas.append("Alguém entrou de madrugada e levou um suprimento. %s %s sem tranca." % [quais.left(1).to_upper() + quais.substr(1), "ficou" if portas_abertas.size() == 1 else "ficaram"])
	dia += 1
	var livres := HORAS_DO_DIA - HORAS_PERDIDAS_POR_FRAQUEZA * fraqueza + (IRMA_DA_HORAS if irma_em_casa else 0)
	amanhecer(livres)
	if hora() != ACORDA: contas.append("Você levantou às %s." % texto_da_hora())
	var amanha := consumo_da_noite()
	contas.append("Hoje a casa consome %d suprimento%s." % [amanha, "" if amanha == 1 else "s"])
	# O texto sai numa variável: quem escuta `mudou` limpa o recado depois de
	# mostrar, e sem isto o resumo da noite voltaria vazio para a tela de dormir.
	var resumo := "\n".join(contas)
	recado = resumo
	mudou.emit()
	virou_o_dia.emit(dia)
	return resumo

## Começa um dia com tantas horas livres. Com a irmã, o dia pode começar antes
## das 8h; com fraqueza, depois.
func amanhecer(livres: int) -> void:
	horas = clampi(livres, 2, HORAS_DO_DIA + IRMA_DA_HORAS)
	garrafas_cheias_hoje = false
	tv_vista.clear()
