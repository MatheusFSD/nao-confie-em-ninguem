class_name Vizinho3D
extends RefCounted

# Conteúdo em data/vizinhos/*.json. O estado pertence a cada morador sorteado;
# conversas, confiança e escolhas duram a partida, sem mudar o arquivo.
const PASTA := "res://data/vizinhos/"
const RETRATOS := "res://sprites/vizinhos/%s.png"
const CHAVES := ["neide", "beto", "sueli", "claudia", "rita", "jorge", "nilton", "emerson", "valdo", "fabinho", "kaio"]

var chave := ""
var nome := ""
var casa: Node3D
var porta: StaticBody3D
var conversas := 0
var mente := false
var adiado_ate := 0
var historia := {"confianca": 0, "marcas": [], "escolhas": {}}
var dados := {}
var no_atual := ""
var dia_da_conversa := 1
var aviso_do_mundo := ""

func _init(conteudo: Dictionary) -> void:
	dados = conteudo.duplicate(true)
	chave = String(dados.get("chave", ""))
	nome = String(dados.get("nome", chave.capitalize()))

static func carregar(chave_do_vizinho: String) -> Dictionary:
	var arquivo := PASTA + chave_do_vizinho + ".json"
	var lido = JSON.parse_string(FileAccess.get_file_as_string(arquivo))
	if lido is Dictionary: return lido
	push_error("Não foi possível ler o vizinho: " + arquivo)
	return {}

static func sortear(quantos: int) -> Array:
	var baralho := CHAVES.duplicate()
	baralho.shuffle()
	var escolhidos := []
	for i in mini(quantos, baralho.size()):
		var conteudo := carregar(String(baralho[i]))
		if not conteudo.is_empty(): escolhidos.append(Vizinho3D.new(conteudo))
	if not escolhidos.is_empty(): escolhidos[randi() % escolhidos.size()].mente = true
	return escolhidos

func retrato() -> String:
	return RETRATOS % chave

## Todas as condições declaradas precisam ser satisfeitas.
func atende(condicoes: Dictionary, dia: int) -> bool:
	if dia < int(condicoes.get("dia_min", 1)): return false
	if dia > int(condicoes.get("dia_max", 2147483647)): return false
	if int(historia.confianca) < int(condicoes.get("confianca_min", -99)): return false
	if int(historia.confianca) > int(condicoes.get("confianca_max", 99)): return false
	if condicoes.has("mente") and mente != bool(condicoes.mente): return false
	if bool(condicoes.get("pedido_disponivel", false)) and dia < adiado_ate: return false
	for marca: String in condicoes.get("marcas", []):
		if not historia.marcas.has(marca): return false
	for marca: String in condicoes.get("sem_marcas", []):
		if historia.marcas.has(marca): return false
	return true

## Entradas são avaliadas na ordem do JSON: coloque a mais específica antes.
func iniciar(dia: int, aviso := "") -> void:
	dia_da_conversa = dia
	aviso_do_mundo = aviso
	no_atual = ""
	for entrada: Dictionary in dados.get("entradas", []):
		if atende(entrada.get("se", {}), dia):
			no_atual = String(entrada.no)
			break
	conversas += 1

func no() -> Dictionary:
	return dados.get("nos", {}).get(no_atual, {})

func falas() -> Array:
	var atual := no()
	var linhas: Array = atual.get("falas", [])
	for variante: Dictionary in atual.get("variantes", []):
		if atende(variante.get("se", {}), dia_da_conversa):
			linhas = variante.falas
			break
	var resultado := []
	for linha: String in linhas: resultado.append(linha.replace("{aviso}", aviso()))
	return resultado

func aviso() -> String:
	var de_hoje: Dictionary = dados.get("avisos", {}).get(str(dia_da_conversa), {})
	if mente: return String(de_hoje.get("mentira", "Me disseram que amanhã volta tudo. Não sei de onde veio."))
	return String(de_hoje.get("verdade", aviso_do_mundo if not aviso_do_mundo.is_empty() else "Não sei o que vem amanhã. Só sei o que vi hoje."))

func opcoes() -> Array:
	var lista := []
	for opcao: Dictionary in no().get("opcoes", []):
		if atende(opcao.get("se", {}), dia_da_conversa): lista.append(opcao)
	return lista

## O mundo paga o custo antes de confirmar. Efeitos só valem uma vez por
## opção, evitando ganhar confiança repetindo a mesma pergunta.
func escolher(id: String) -> bool:
	for opcao: Dictionary in opcoes():
		if String(opcao.id) != id: continue
		var registro := no_atual + ":" + id
		var efeito: Dictionary = opcao.get("efeitos", {})
		if not historia.escolhas.has(registro):
			historia.confianca = clampi(int(historia.confianca) + int(efeito.get("confianca", 0)), -3, 5)
			historia.escolhas[registro] = dia_da_conversa
		for marca: String in efeito.get("tirar_marcas", []): historia.marcas.erase(marca)
		for marca: String in efeito.get("marcas", []):
			if not historia.marcas.has(marca): historia.marcas.append(marca)
		# Recusar novamente pode adiar, mas não cobra confiança novamente.
		adiado_ate = maxi(adiado_ate, dia_da_conversa + int(opcao.get("efeitos", {}).get("adiar", 0)))
		no_atual = String(opcao.get("destino", ""))
		return true
	return false

func pode_passar_numero() -> bool:
	return historia.marcas.has("ajudou") and int(historia.confianca) >= 2
