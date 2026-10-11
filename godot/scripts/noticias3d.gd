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
## O que é verdade nesta partida (sorteado no começo). Notícia com "se" só
## passa quando a condição bate: "agua_contaminada" ou "agua_limpa".
var estado := {}

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
		if texto.is_empty() or not vale(item): continue
		# Uma frase por vez na tela: fala de três frases não cabe num letreiro.
		if String(item.get("fonte", "")).to_lower() == OFICIAL: oficiais.append_array(frases(texto))
		else: jornal.append_array(frases(texto))
	return {
		"pronunciamento": marcar_o_tempo(oficiais),
		"telejornal": marcar_o_tempo(jornal),
		"rodape": letreiro(hoje),
	}

## A notícia vale nesta partida? As que dependem de um sorteio só passam
## quando ele bate.
func vale(item: Dictionary) -> bool:
	match String(item.get("se", "")):
		"agua_contaminada": return bool(estado.get("agua_vai_contaminar", false))
		"agua_limpa": return not bool(estado.get("agua_vai_contaminar", false))
	return true

## O que o rádio diz hoje: [[fonte, texto], ...]. Funciona sem luz — é a pilha.
func radio_do_dia(dia: int) -> Array:
	var falas: Array = []
	for item: Dictionary in dias.get(str(dia), {}).get("radio", []):
		var texto := String(item.get("texto", ""))
		if texto.is_empty() or not vale(item): continue
		for frase in frases(texto): falas.append([quem_fala(String(item.get("fonte", ""))), frase])
	return falas

## Como cada fonte se apresenta no rádio.
static func quem_fala(fonte: String) -> String:
	match fonte.to_lower():
		"governo": return "Presidente (gravado)"
		"cientistas": return "Equipe de pesquisa"
		"testemunhas": return "Vizinhos na escuta"
		"conspiracionistas": return "Faixa livre"
	return fonte

## Quebra um texto nas frases dele, para mostrar uma por vez.
static func frases(texto: String) -> PackedStringArray:
	var lista := PackedStringArray()
	var atual := ""
	for i in texto.length():
		atual += texto[i]
		var fim := texto[i] in [".", "!", "?"] and (i == texto.length() - 1 or texto[i + 1] == " ")
		if fim:
			lista.append(atual.strip_edges())
			atual = ""
	if not atual.strip_edges().is_empty(): lista.append(atual.strip_edges())
	return lista

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
