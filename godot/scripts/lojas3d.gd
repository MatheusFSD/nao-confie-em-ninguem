class_name Lojas3D
extends RefCounted

# O comércio da rua que vende: mercadinho, padaria e bar. Cada um tem dono,
# retrato, o que vende e o dia em que baixa a porta de vez — tudo em
# data/lojas3d.json. Fechado de vez, dá para arrombar; o que tiver lá dentro
# sai uma vez só.
#
# O tipo da loja vem do nome do prédio no casario: "mercadinho_aberto",
# "padaria_fechado2" e "bar_do_ze_aberto" viram "mercadinho", "padaria" e
# "bar_do_ze". O resto do comércio (barbearia, bazar...) segue o calendário
# geral, fechando no breu.
const DADOS := "res://data/lojas3d.json"

var dados := {}
## Lojas já arrombadas e esvaziadas nesta partida.
var saqueadas := {}

func _init() -> void:
	var documento = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	dados = documento if documento is Dictionary else {}

func lojas() -> Dictionary:
	return dados.get("lojas", {})

func existe(tipo: String) -> bool:
	return lojas().has(tipo)

func loja(tipo: String) -> Dictionary:
	return lojas().get(tipo, {})

## "padaria_fechado2" → "padaria". Vazio quando o prédio não é loja de compras.
func tipo_do_predio(nome: String) -> String:
	for tipo: String in lojas():
		if nome.begins_with(tipo + "_"): return tipo
	return ""

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
		"comida": return "%d comida%s" % [rende, "" if rende == 1 else "s"]
		"agua": return "%d água%s" % [rende, "" if rende == 1 else "s"]
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
	return dados.get("custo_visita", {"acoes": 1, "energia": 0})

func custo_arrombar() -> Dictionary:
	return dados.get("custo_arrombar", {"acoes": 1, "energia": 5})
