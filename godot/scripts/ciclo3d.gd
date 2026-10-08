class_name Ciclo3D
extends Node

# O dia do morador, com as mesmas regras do jogo 2D (scripts/survival.gd):
# quatro ações por dia, cada ação empurra o relógio da manhã para a noite, e
# dormir fecha o dia — consumindo uma comida e uma água, cobrando fome e sede
# em ações a menos no dia seguinte.
#
# Aqui ficam só as regras e as contas. Quem pinta o céu, acende as lâmpadas e
# esvazia a rua é o mundo, que escuta o sinal `mudou`.
signal mudou
signal virou_o_dia(dia: int)

const DIARIAS := 4
const DIA_DO_BREU := 6
const DIA_DO_CORTE := 7
const TRABALHO := {"acoes": 2, "paga": 40, "energia": 10}
const MERCADO := {"acoes": 1, "energia": 2}
## Ver televisão cansa: a primeira vez em cada canal, por dia, cobra isto. É o
## eco da regra do 2D, onde consultar uma fonte custava e reler era de graça.
const TV := {"energia": 4}
## Um pacote de pilhas, como no 2D: é daqui que a energia volta.
const PILHA := 20
const ENERGIA_CHEIA := 100
const PERIODOS := ["Manhã", "Tarde", "Fim de tarde", "Anoitecer", "Noite"]
## O que o modo deus põe na despensa e na carteira.
const FARTURA := 99
const RIQUEZA := 999999

var dia := 1
var acoes := DIARIAS
var acoes_do_dia := DIARIAS
var energia := ENERGIA_CHEIA
var comida := 2
var agua := 3
var dinheiro := 80
## Modo deus: para testar o jogo sem jogar. Nada se gasta, nada falta e nada
## mata — os perigos que vierem também olham para esta chave.
var modo_deus := false
## Quem já passou o número: chave do vizinho e o dia em que ele passou. É por
## aqui que as mensagens dele começam a chegar no celular.
var contatos := {}
## A lanterna acesa ou apagada.
var lanterna_acesa := false
## A lanterna comprada no mercado. Ela não serve para nada enquanto há luz na
## rua — é para o dia em que não houver.
var tem_lanterna := false
## Canais já vistos hoje: rever o mesmo canal não cobra outra vez.
var tv_vista := {}
## Última coisa que aconteceu, para o mundo mostrar.
var recado := ""

## Energia do HUD é disposição/pilhas; a rede elétrica é outra coisa.
func tem_energia_da_rede() -> bool:
	return dia < DIA_DO_BREU

func tem_agua_da_rede() -> bool:
	return dia < DIA_DO_CORTE

func onibus_funciona() -> bool:
	return dia < DIA_DO_BREU

func guardar_agua() -> bool:
	if not tem_agua_da_rede():
		recado = "A torneira está seca. Só resta a água guardada."
		mudou.emit()
		return false
	if not gastar(1, 0): return false
	agua += 2
	recado = "Você guardou duas águas."
	mudou.emit()
	return true

## Verifica todos os custos antes de descontar qualquer recurso.
func pagar_escolha(custo: Dictionary) -> bool:
	var a := int(custo.get("acoes", 0))
	var item := String(custo.get("item", ""))
	var quanto := int(custo.get("quanto", 0))
	if a < 0 or quanto < 0: return false
	if modo_deus: return true
	var tem := 0
	match item:
		"": tem = quanto
		"comida": tem = comida
		"agua": tem = agua
		"energia": tem = energia / PILHA
		"dinheiro": tem = dinheiro
		_: return false
	if acoes < a or tem < quanto:
		recado = "Não sobra ação para isso." if acoes < a else "Você não tem isso para dar."
		mudou.emit()
		return false
	acoes -= a
	match item:
		"comida": comida -= quanto
		"agua": agua -= quanto
		"energia": energia -= PILHA * quanto
		"dinheiro": dinheiro -= quanto
	mudou.emit()
	return true

## Quanto do dia já passou: 0 de manhã, 1 à noite.
func progresso() -> float:
	if acoes_do_dia <= 0: return 1.0
	return clampf(1.0 - float(acoes) / float(acoes_do_dia), 0.0, 1.0)

## Em que pedaço do dia o relógio está, de 0 (manhã) a 4 (noite).
func indice_do_periodo() -> int:
	return clampi(roundi(progresso() * (PERIODOS.size() - 1)), 0, PERIODOS.size() - 1)

## Põe o relógio num pedaço do dia. As ações seguem a hora: de manhã estão
## todas de pé, à noite não sobra nenhuma. É ferramenta de quem está testando
## o jogo — por isso só vale no modo deus.
func por_o_periodo(qual: int) -> String:
	if not modo_deus: return ""
	var quantos := PERIODOS.size() - 1
	var alvo := clampi(qual, 0, quantos)
	acoes_do_dia = maxi(acoes_do_dia, DIARIAS)
	acoes = roundi(float(acoes_do_dia) * (1.0 - float(alvo) / float(quantos)))
	recado = "Modo deus: %s." % PERIODOS[alvo]
	mudou.emit()
	return PERIODOS[alvo]

func periodo() -> String:
	return PERIODOS[clampi(roundi(progresso() * (PERIODOS.size() - 1)), 0, PERIODOS.size() - 1)]

func e_noite() -> bool:
	return progresso() > 0.62

## Liga ou desliga o modo deus. Ligado, enche a despensa, a carteira e a energia;
## desligado, só para de proteger — o que já está guardado continua guardado.
func virar_deus(ligado: bool) -> void:
	modo_deus = ligado
	if ligado:
		comida = FARTURA
		agua = FARTURA
		energia = ENERGIA_CHEIA
		dinheiro = RIQUEZA
		tem_lanterna = true
		acoes = maxi(acoes, DIARIAS)
		acoes_do_dia = maxi(acoes_do_dia, acoes)
	recado = "Modo deus ligado." if ligado else "Modo deus desligado."
	mudou.emit()

## Tenta gastar ações e energia. Devolve falso e explica quando não dá.
func gastar(quantas: int, quanta_energia: int) -> bool:
	if modo_deus: return true
	if acoes < quantas:
		recado = "Não dá: isso ocupa %d ações e você tem %d." % [quantas, acoes]
		mudou.emit()
		return false
	if energia < quanta_energia:
		recado = "Sem energia para isso."
		mudou.emit()
		return false
	acoes -= quantas
	energia = maxi(0, energia - quanta_energia)
	mudou.emit()
	return true

func trabalhar() -> bool:
	if not onibus_funciona():
		recado = "Os ônibus pararam. Não dá para ir trabalhar."
		mudou.emit()
		return false
	if not gastar(int(TRABALHO.acoes), int(TRABALHO.energia)): return false
	dinheiro += int(TRABALHO.paga)
	recado = "Dia de trabalho: +R$ %d, −%d de energia." % [TRABALHO.paga, TRABALHO.energia]
	mudou.emit()
	return true

func ir_ao_mercado() -> bool:
	if not onibus_funciona():
		recado = "Os ônibus pararam. Não dá para chegar ao mercado."
		mudou.emit()
		return false
	if not gastar(int(MERCADO.acoes), int(MERCADO.energia)): return false
	recado = "No mercado o que pesa é o dinheiro, não o tempo."
	mudou.emit()
	return true

## Tirar da despensa, da carteira ou das pilhas para dar a alguém. Devolve falso
## quando não há o que dar.
func pagar(item: String, quanto: int) -> bool:
	if modo_deus: return true
	match item:
		"comida":
			if comida < quanto: return false
			comida -= quanto
		"agua":
			if agua < quanto: return false
			agua -= quanto
		"energia":
			if energia < PILHA * quanto: return false
			energia -= PILHA * quanto
		"dinheiro":
			if dinheiro < quanto: return false
			dinheiro -= quanto
		_: return true
	mudou.emit()
	return true

## Sentar na frente da TV. Devolve falso quando não há energia para isso.
func assistir_tv(canal: String) -> bool:
	if not tem_energia_da_rede():
		recado = "Sem luz da rede. A televisão não liga."
		mudou.emit()
		return false
	if modo_deus: return true
	if tv_vista.has(canal): return true
	if energia < int(TV.energia):
		recado = "Sem energia para prestar atenção na TV."
		mudou.emit()
		return false
	energia -= int(TV.energia)
	tv_vista[canal] = true
	recado = "Você ficou um tempo na frente da TV. −%d de energia." % TV.energia
	mudou.emit()
	return true

func guardar(quanta_comida: int, quanta_agua: int, quanto_sobrou: int, quanta_energia := 0) -> void:
	comida += quanta_comida
	agua += quanta_agua
	dinheiro = RIQUEZA if modo_deus else quanto_sobrou
	if quanta_energia > 0: energia = mini(ENERGIA_CHEIA, energia + quanta_energia)
	mudou.emit()

## Esperar protegido cobra tempo, nunca energia ou comida extra.
func esperar_no_abrigo() -> String:
	if acoes > 0:
		gastar(1, 0)
		# Mesmo no modo de teste, esperar deve mover o relógio.
		if modo_deus:
			acoes = maxi(0, acoes - 1)
			mudou.emit()
		return "Você continua abrigado. O período avançou; nenhuma energia foi gasta."
	# As reservas acompanham o jogador no abrigo. Portas da própria casa não
	# causam um roubo implícito aqui; a regra de dormir em casa continua igual.
	return dormir([])

## Fecha o dia. `portas_abertas` são as portas para a rua que ficaram sem
## tranca — por elas alguém entra de madrugada. Devolve o resumo da noite.
func dormir(portas_abertas: Array) -> String:
	var contas: Array[String] = []
	if modo_deus:
		# No modo deus a noite não cobra nada: só vira o dia.
		dia += 1
		tv_vista.clear()
		acoes = DIARIAS
		acoes_do_dia = DIARIAS
		virar_deus(true)
		virou_o_dia.emit(dia)
		return "Modo deus: a noite não cobrou nada."
	if comida == 0: contas.append("Você passou o dia sem comer.")
	if agua == 0: contas.append("Você passou o dia sem beber água.")
	comida = maxi(0, comida - 1)
	agua = maxi(0, agua - 1)
	var castigo := 0
	if comida == 0:
		contas.append("Você está com fome.")
		castigo += 1
	if agua == 0:
		contas.append("Você está com sede.")
		castigo += 1
	if not portas_abertas.is_empty() and (comida > 0 or agua > 0):
		var levou: Array[String] = []
		if comida > 0:
			comida -= 1
			levou.append("uma comida")
		if agua > 0:
			agua -= 1
			levou.append("uma água")
		contas.append("Alguém entrou de madrugada e levou %s. %s ficou sem tranca." % [" e ".join(levou), " e ".join(portas_abertas)])
	# A noite não devolve energia: no jogo 2D ela só volta com pilhas do
	# mercado. O que a noite faz é zerar o dia e cobrar a despensa vazia.
	dia += 1
	# A programação de amanhã é outra: dá para ver tudo de novo.
	tv_vista.clear()
	acoes = maxi(1, DIARIAS - castigo)
	acoes_do_dia = acoes
	if castigo > 0: contas.append("Hoje você tem %d ações." % acoes)
	# O texto sai numa variável: quem escuta `mudou` limpa o recado depois de
	# mostrar, e sem isto o resumo da noite voltaria vazio para a tela de dormir.
	var resumo := "\n".join(contas)
	recado = resumo
	mudou.emit()
	virou_o_dia.emit(dia)
	return resumo
