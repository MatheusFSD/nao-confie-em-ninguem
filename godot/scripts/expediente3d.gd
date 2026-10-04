class_name Expediente3D
extends Node

# O dia fora de casa, encadeado: ônibus de ida → o lugar → ônibus de volta.
# Trabalho vai para o call center; mercado passa pela loja jogável, onde se pega
# comida e água nas prateleiras, paga no caixa e sai pela porta — e é a porta
# que chama o ônibus de volta.
#
# As receitas de cada trecho — modelo, horário, linha, cores do céu e as quatro
# tomadas de câmera — vieram do projeto do artefato (scripts/fluxo.gd).
signal terminou

const VELOCIDADE := 11.5
var resolucao := Vector2(320, 213)
## Onde a interface das cenas é pendurada. Fica fora da tela pequena do jogo,
## para o texto sair nítido.
var camada_da_interface: Node
## Quantas sacolas voltam do mercado (0 a 3).
var sacolas := 0
## Que dia é hoje: o mercado usa para corrigir os preços.
var dia := 1
## Dinheiro do morador, que o mercado gasta.
var dinheiro := 80
## O que voltou do mercado, para o mundo somar.
var comprou := {"comida": 0, "agua": 0, "energia": 0, "lanterna": 0}
var _etapas: Array = []
var _qual := -1
var _atual: Node

## Tomadas da ida: o ônibus corre para a direita.
static func tomadas_ida() -> Array:
	return [
		{"nome": "LADO DE FORA", "mundo": true, "de": func(t): return Vector3(-6 + t * 1.4, 2.1, 9.4), "para": func(t): return Vector3(-1.5 + t * 0.8, 1.6, 2.2)},
		{"nome": "CORREDOR", "mundo": false, "de": func(t): return Vector3(4.1 - t * 0.12, 1.75, -0.05), "para": func(_t): return Vector3(-0.55, 1.3, 0.9)},
		{"nome": "JANELA", "mundo": false, "de": func(t): return Vector3(-1.05 + t * 0.03, 1.66, 0.6), "para": func(_t): return Vector3(1.2, 1.35, 3.2)},
		{"nome": "FRENTE", "mundo": true, "de": func(t): return Vector3(24 - t * 1.1, 0.9, 4.6), "para": func(_t): return Vector3(0, 1.7, 2.2)},
	]

## Tomadas da volta: o ônibus corre para a esquerda, mostrando a traseira.
static func tomadas_volta() -> Array:
	return [
		{"nome": "TRASEIRA", "mundo": true, "de": func(t): return Vector3(15 - t * 0.5, 3.4, 0.2), "para": func(_t): return Vector3(1.5, 1.4, -2.2)},
		{"nome": "LADO DE FORA", "mundo": true, "de": func(t): return Vector3(6 - t * 1.4, 2.1, -9.4), "para": func(t): return Vector3(1.5 - t * 0.8, 1.6, -2.2)},
		{"nome": "JANELA", "mundo": false, "de": func(t): return Vector3(-1.05 + t * 0.03, 1.66, 0.6), "para": func(_t): return Vector3(1.2, 1.3, 3.2)},
		{"nome": "INDO EMBORA", "mundo": true, "de": func(t): return Vector3(9 + t * VELOCIDADE, 1.25, -2.9), "para": func(_t): return Vector3(0, 1.5, -2.2)},
	]

func receita(nome: String) -> Dictionary:
	match nome:
		"trabalho_ida":
			return {"glb": "res://modelos/cutscene/trabalho_ida.glb", "dir": 1.0, "tomadas": tomadas_ida(),
				"hora": "06", "minuto": 12, "linha": "LINHA 950 · PENHA → CENTRO",
				"ceu_topo": Color("33406f"), "ceu_horizonte": Color("f4c48c"), "neblina": Color("f4c48c"),
				"densidade": 0.0075, "luz": Vector3(0.7, 0.45, -0.5)}
		"trabalho_volta":
			return {"glb": "res://modelos/cutscene/trabalho_volta.glb", "dir": -1.0, "tomadas": tomadas_volta(),
				"hora": "18", "minuto": 40, "linha": "LINHA 950 · CENTRO → PENHA", "cansado": true,
				"ceu_topo": Color("1d1f44"), "ceu_horizonte": Color("ef9a5a"), "neblina": Color("d9785c"),
				"densidade": 0.0085, "luz": Vector3(-0.8, 0.3, 0.4)}
		"mercado_ida":
			return {"glb": "res://modelos/cutscene/mercado_ida.glb", "dir": 1.0, "tomadas": tomadas_ida(),
				"hora": "14", "minuto": 10, "linha": "LINHA 950 · PENHA → MADUREIRA",
				"ceu_topo": Color("5d86c4"), "ceu_horizonte": Color("e8dcc0"), "neblina": Color("e4dccb"),
				"densidade": 0.0065, "luz": Vector3(0.5, 0.8, -0.4)}
		_:
			return {"glb": "res://modelos/cutscene/mercado_volta.glb", "dir": -1.0, "tomadas": tomadas_volta(),
				"hora": "16", "minuto": 35, "linha": "LINHA 950 · MADUREIRA → PENHA", "sacolas": sacolas,
				"ceu_topo": Color("3d5a9a"), "ceu_horizonte": Color("f3c88c"), "neblina": Color("efc390"),
				"densidade": 0.0072, "luz": Vector3(-0.8, 0.35, 0.4)}

## `destino` é "trabalho" ou "mercado".
func comecar(destino: String) -> void:
	_etapas = ["trabalho_ida", "escritorio", "trabalho_volta"] if destino == "trabalho" else ["mercado_ida", "mercado", "mercado_volta"]
	proxima()

func proxima() -> void:
	if _atual != null:
		# O que a pessoa comprou volta com ela: vira sacola no ônibus e comida
		# e água em casa.
		if _atual is Mercado3D:
			var loja := _atual as Mercado3D
			comprou = loja.comprou
			dinheiro = loja.dinheiro
			var volume: int = comprou["comida"] + comprou["agua"]
			sacolas = 0 if volume == 0 else mini(3, ceili(volume / 3.0))
		_atual.queue_free()
		_atual = null
	_qual += 1
	if _qual >= _etapas.size():
		terminou.emit()
		return
	var nome: String = _etapas[_qual]
	if nome == "mercado":
		var loja := Mercado3D.new()
		loja.resolucao = resolucao
		loja.camada_da_interface = camada_da_interface
		loja.dia = dia
		loja.dinheiro = dinheiro
		_atual = loja
	elif nome == "escritorio":
		var escritorio := Escritorio3D.new()
		escritorio.resolucao = resolucao
		escritorio.camada_da_interface = camada_da_interface
		_atual = escritorio
	else:
		var viagem := Onibus3D.new()
		viagem.resolucao = resolucao
		viagem.receita = receita(nome)
		viagem.camada_da_interface = camada_da_interface
		_atual = viagem
	_atual.terminou.connect(proxima, CONNECT_ONE_SHOT | CONNECT_DEFERRED)
	add_child(_atual)
