class_name Mensagens3D
extends RefCounted

# As mensagens que chegam no celular. Vêm de data/mensagens.json: as da irmã
# chegam sozinhas, dia a dia; as dos vizinhos só depois que a pessoa passa o
# número — e isso só acontece quando ela confia em você.
#
# O aparelho é um Nokia: não tem internet nem procura nada. Só recebe.
const ARQUIVO := "res://data/mensagens.json"

var da_irma: Array = []
var dos_vizinhos := {}
## Mensagens recebidas continuam na caixa, mesmo após a condição mudar.
var recebidas := {}
## Quais já foram lidas: "quem:indice".
var lidas := {}

func _init() -> void:
	var lido = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if not (lido is Dictionary): return
	da_irma = (lido as Dictionary).get("irma", [])
	dos_vizinhos = (lido as Dictionary).get("vizinhos", {})

## A caixa de entrada de hoje: o que já chegou, da mais nova para a mais velha.
## `contatos` traz a chave de cada vizinho que já passou o número, e o dia em
## que passou — as mensagens dele começam a chegar daí em diante.
func caixa(dia: int, contatos: Dictionary, nome_da_irma := "Irmã", vizinhos: Array = []) -> Array:
	var tudo: Array = []
	for i in da_irma.size():
		var m: Dictionary = da_irma[i]
		if int(m.get("dia", 1)) > dia: continue
		tudo.append({"de": nome_da_irma, "chave": "irma:%d" % i, "dia": int(m.get("dia", 1)), "texto": String(m.get("texto", ""))})
	for morador: Vizinho3D in vizinhos:
		if not contatos.has(morador.chave): continue
		var desde: int = int(contatos[morador.chave])
		var lista: Array = morador.dados.get("mensagens", [])
		for i in lista.size():
			var m: Dictionary = lista[i]
			var quando := desde + int(m.dia_relativo) if m.has("dia_relativo") else int(m.get("dia_min", 1))
			if quando > dia or dia > int(m.get("dia_max", 2147483647)): continue
			if not morador.atende(m.get("se", {}), dia): continue
			var id := "%s:%s" % [morador.chave, String(m.get("id", str(i)))]
			if recebidas.has(id): continue
			recebidas[id] = {"de": morador.nome, "chave": id, "dia": dia, "texto": String(m.get("texto", ""))}
	for m: Dictionary in recebidas.values(): tudo.append(m.duplicate())
	tudo.sort_custom(func(a, b): return int(a["dia"]) > int(b["dia"]))
	return tudo

## O nome que aparece no visor, tirado do elenco dos vizinhos.
func nome_de(chave: String) -> String:
	if Vizinho3D.CHAVES.has(chave): return String(Vizinho3D.carregar(chave).get("nome", chave.capitalize()))
	return chave.capitalize()

func ja_lida(chave: String) -> bool:
	return lidas.has(chave)

func marcar_lida(chave: String) -> void:
	lidas[chave] = true

## Quantas ainda não foram lidas.
func novas(dia: int, contatos: Dictionary, vizinhos: Array = []) -> int:
	var quantas := 0
	for m: Dictionary in caixa(dia, contatos, "Irmã", vizinhos):
		if not ja_lida(String(m["chave"])): quantas += 1
	return quantas
