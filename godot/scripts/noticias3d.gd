class_name Noticias3D
extends RefCounted

# O que passa na TV em cada dia. Os textos são os mesmos do jogo 2D
# (data/dias.json): cada dia traz falas de "tv" assinadas por uma fonte —
# Governo, Cientistas, Jornal — e o evento do dia, que vira o letreiro do
# rodapé.
#
# O que é do Governo vai para a cadeia nacional; o resto é matéria de jornal.
# Dia sem notícia mantém o texto que veio nas cenas do artefato.
const ARQUIVO := "res://data/dias.json"
## Fonte que fala em cadeia nacional; as outras são do telejornal.
const OFICIAL := "governo"
## Quanto tempo cada fala fica no ar, por letra, e os limites.
const POR_LETRA := 0.075
const MINIMO := 2.4
const MAXIMO := 7.0
## Respiro entre uma fala e outra.
const PAUSA := 0.5

var dias := {}

func _init() -> void:
	var lido = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if lido is Dictionary: dias = lido

## As falas do dia, já no formato das cenas de TV: [[início, fim, texto], ...].
func do_dia(dia: int) -> Dictionary:
	var hoje: Dictionary = dias.get(str(dia), {})
	var oficiais: Array = []
	var jornal: Array = []
	for item: Dictionary in hoje.get("tv", []):
		var texto := String(item.get("texto", ""))
		if texto.is_empty(): continue
		if String(item.get("fonte", "")).to_lower() == OFICIAL: oficiais.append(texto)
		else: jornal.append(texto)
	return {
		"pronunciamento": marcar_o_tempo(oficiais),
		"telejornal": marcar_o_tempo(jornal),
		"rodape": letreiro(hoje),
	}

## Cada fala ganha começo e fim conforme o tamanho: frase curta some rápido,
## frase longa fica tempo de ler.
func marcar_o_tempo(textos: Array) -> Array:
	var falas: Array = []
	var quando := 0.8
	for texto: String in textos:
		var quanto := clampf(texto.length() * POR_LETRA, MINIMO, MAXIMO)
		falas.append([quando, quando + quanto, texto])
		quando += quanto + PAUSA
	return falas

## O que um vizinho bem informado contaria hoje sobre amanhã. Sai dos mesmos
## dados da TV: dia que corta a água, dia que derruba a energia, ou o evento
## em si. Vazio quando o dia seguinte não está escrito.
func aviso_de_amanha(dia: int) -> String:
	var amanha: Dictionary = dias.get(str(dia + 1), {})
	if amanha.is_empty(): return ""
	if amanha.has("agua_da_rede") and not bool(amanha["agua_da_rede"]):
		return "Amanhã corta a água. Enche hoje tudo que for pote."
	if amanha.has("energia"):
		return "Amanhã a noite é pesada. Dorme cedo, que você vai acordar moído."
	var evento := String(amanha.get("evento", "")).strip_edges()
	if evento.is_empty(): return ""
	return "Me falaram uma coisa de amanhã: %s" % evento[0].to_lower() + evento.substr(1)

## O letreiro que corre no rodapé: o evento do dia, repetido com separador.
func letreiro(hoje: Dictionary) -> String:
	var evento := String(hoje.get("evento", "")).strip_edges()
	if evento.is_empty(): return ""
	return "%s  •  " % evento.to_upper()
