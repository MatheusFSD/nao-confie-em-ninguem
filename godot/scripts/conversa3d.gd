class_name Conversa3D
extends RefCounted

# As falas da rua, as mesmas do jogo 2D (data/conversas.json): frases em fases,
# que vão ficando mais desconfiadas conforme os dias passam.
#
# A regra também é a de lá: cada pessoa tem UMA frase por fase — falar de novo
# com ela repete a mesma coisa — e pessoas diferentes recebem frases diferentes
# enquanto houver frase livre na fase.
const ARQUIVO := "res://data/conversas.json"
## Quanto tempo o balão fica na tela.
const SEGUNDOS := 5.0

var fases: Array = []
## Frases já distribuídas em cada fase, para não repetir entre pessoas.
var ouvidas := {}

func _init() -> void:
	var texto := FileAccess.get_file_as_string(ARQUIVO)
	if texto.is_empty(): return
	var lido = JSON.parse_string(texto)
	if lido is Dictionary: fases = (lido as Dictionary).get("fases", [])

## A fase que vale hoje: a última cujo dia de início já passou.
func fase_do_dia(dia: int) -> Dictionary:
	var achada := {}
	for candidata: Dictionary in fases:
		if int(candidata.get("a_partir_do_dia", 1)) <= dia: achada = candidata
	return achada

## O que esta pessoa tem a dizer hoje.
func frase_de(quem: Node, dia: int) -> String:
	var fase := fase_do_dia(dia)
	var frases: Array = fase.get("frases", [])
	if frases.is_empty(): return "..."
	var chave := str(fase.get("a_partir_do_dia", 0))
	var dela: Dictionary = quem.get_meta("falas", {})
	if not dela.has(chave):
		var tomadas: Array = ouvidas.get(chave, [])
		# Acabaram as frases livres: a fase recomeça e todas voltam a valer.
		if tomadas.size() >= frases.size(): tomadas = []
		var livres := range(frases.size()).filter(func(i): return not tomadas.has(i))
		dela[chave] = livres.pick_random()
		tomadas.append(dela[chave])
		ouvidas[chave] = tomadas
		quem.set_meta("falas", dela)
	return String(frases[int(dela[chave])])
