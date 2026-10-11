class_name Lojas3D
extends RefCounted

# O comércio da rua que vende: mercadinho, as duas padarias (dos gêmeos Lúcio
# e Lauro) e os dois bares (do Zé, flamenguista, e do Tião, vascaíno). Cada um tem dono,
# retrato, o que vende e o dia em que baixa a porta de vez — tudo em
# data/lojas3d.json. Fechado de vez, dá para arrombar; o que tiver lá dentro
# sai uma vez só — e é pouco ou nada: o quanto sobrou é sorteado a cada partida,
# porque outra pessoa pode ter chegado antes.
#
# O tipo da loja vem do nome do prédio no casario: "mercadinho_aberto",
# "padaria_fechado2" e "bar_do_ze_aberto" viram "mercadinho", "padaria" e
# "bar_do_ze". O resto do comércio (barbearia, bazar...) segue o calendário
# geral, fechando no breu.
const DADOS := "res://data/lojas3d.json"

var dados := {}
## Lojas já arrombadas e esvaziadas nesta partida.
var saqueadas := {}
## Quantos suprimentos sobraram em cada loja nesta partida (0 = já saqueada).
## Embalagens compradas hoje em cada loja, para o racionamento.
var compras_hoje := {}
var dia_das_compras := 0
var saques_sorteados := {}
var _sorte := RandomNumberGenerator.new()

func _init() -> void:
	var documento = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	dados = documento if documento is Dictionary else {}
	_sorte.randomize()
	sortear_saques()

## Sorteia, para a partida, o que sobrou dentro de cada loja. Com a semente
## fixa (testes), o sorteio se repete.
func sortear_saques(semente := -1) -> void:
	if semente >= 0: _sorte.seed = semente
	saques_sorteados.clear()
	for tipo: String in lojas():
		var saque: Dictionary = loja(tipo).get("saque", {})
		var faixa: Array = saque.get("suprimentos", [0, 0])
		var vazia := _sorte.randf() < float(saque.get("chance_vazia", 0.0))
		saques_sorteados[tipo] = 0 if vazia else _sorte.randi_range(int(faixa[0]), int(faixa[1]))

## Suprimentos que o arrombamento encontra nesta loja, nesta partida.
func saque_da_partida(tipo: String) -> int:
	return int(saques_sorteados.get(tipo, 0))

func lojas() -> Dictionary:
	return dados.get("lojas", {})

func existe(tipo: String) -> bool:
	return lojas().has(tipo)

func loja(tipo: String) -> Dictionary:
	return lojas().get(tipo, {})

## "padaria_fechado2" → "padaria". Vazio quando o prédio não é loja de compras.
func tipo_do_predio(nome: String) -> String:
	# O nome mais comprido que servir: "padaria_gemea_aberto" é da padaria do
	# Lauro, não da do Lúcio.
	var achado := ""
	for tipo: String in lojas():
		if nome.begins_with(tipo + "_") and tipo.length() > achado.length(): achado = tipo
	return achado

## Dia em que o comércio deste prédio baixa a porta de vez.
func dia_que_fecha(nome_do_predio: String, padrao: int) -> int:
	var tipo := tipo_do_predio(nome_do_predio)
	return int(loja(tipo).get("fecha_no_dia", padrao)) if not tipo.is_empty() else padrao

func fechada_de_vez(tipo: String, dia: int) -> bool:
	return dia >= int(loja(tipo).get("fecha_no_dia", 6))

func aberta(tipo: String, dia: int, noite: bool) -> bool:
	return not noite and not fechada_de_vez(tipo, dia)

## Preço por embalagem, subindo com os dias como no mercado.
func preco(produto: Dictionary, dia: int) -> int:
	return int(round(float(produto.get("preco", 0)) * pow(float(dados.get("carestia", 1.32)), maxf(0.0, dia - 1))))

## O que o produto rende em casa, escrito para a lista do balcão.
static func rendimento(vale: String, rende: int) -> String:
	match vale:
		"suprimentos": return "%d suprimento%s" % [rende, "" if rende == 1 else "s"]
		"energia": return "+%d de energia" % rende
		"lanterna": return "lanterna para o escuro"
	return ""

## As falas do dono para hoje: a última fase que já começou.
func falas(tipo: String, dia: int) -> Array:
	var escolhida: Array = []
	for fase: Dictionary in loja(tipo).get("falas", []):
		if dia >= int(fase.get("a_partir_do_dia", 1)): escolhida = fase.get("texto", [])
	return escolhida

func custo_visita() -> Dictionary:
	return dados.get("custo_visita", {"horas": 1})

func custo_arrombar() -> Dictionary:
	return dados.get("custo_arrombar", {"horas": 2})

## Quantas embalagens cada dono vende por cliente neste dia.
func limite_do_dia(dia: int) -> int:
	var limite := 99
	for faixa: Array in dados.get("racionamento", []):
		if dia >= int(faixa[0]): limite = int(faixa[1])
	return limite

## Quantas ainda dá para levar desta loja hoje.
func restam_hoje(tipo: String, dia: int) -> int:
	if dia != dia_das_compras:
		dia_das_compras = dia
		compras_hoje.clear()
	return maxi(0, limite_do_dia(dia) - int(compras_hoje.get(tipo, 0)))

func registrar_compra(tipo: String, dia: int) -> void:
	restam_hoje(tipo, dia)
	compras_hoje[tipo] = int(compras_hoje.get(tipo, 0)) + 1
