class_name Tutorial3D
extends Node

# Dia 0: a irmã passa o dia com o morador e ensina a casa conversando. Cada
# passo mostra as falas dela, deixa um objetivo no HUD e espera o evento que o
# mundo avisa (TV, torneira, trabalho, mercadinho, tranca, cama). Textos e ordem
# em data/tutorial3d.json. Ela pula o que o morador já fez sozinho, vai para a
# casa dela depois das compras e, se a noite chegar antes, reclama e vai embora.
const DADOS := "res://data/tutorial3d.json"
## Passos que só dá para cumprir de dia: anoiteceu neles, ela desiste.
const PRECISA_DO_DIA := ["agua", "trabalhou"]

var dados: Dictionary = {}
var passos: Array = []
var indice := -1
var ativo := false
var feitos: Dictionary = {}
## Ela está indo para casa (seguindo este marco, no portão dela).
var indo_embora := false
var _marco: Node3D
## Esperando a fala acabar para pôr o objetivo.
var _falando := false
## Falas guardadas até o jogador sair do balcão, da TV, do ônibus.
var _na_fila: Array = []
## Ela falou porque ele foi deitar cedo: acabada a fala, ele dorme.
var _dormir_depois := false
## Acabada a fala de despedida, ela sai de casa.
var _sair_depois := false
## Comentários dela quando ele faz algo fora de ordem: caixa de fala com o
## rosto, mostrada quando ele estiver livre.
var _comentarios: Array = []
## Indo embora: há quanto tempo ela anda, e há quanto não aparece na tela.
var _andando := 0.0
var _fora_da_vista := 0.0
var jogo: Node

func comecar(mundo: Node) -> void:
	jogo = mundo
	var lido = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	dados = lido if lido is Dictionary else {}
	passos = dados.get("passos", [])
	ativo = true
	jogo.evento.connect(_ao_evento)
	jogo.dialogo.terminou.connect(_ao_terminar_fala)
	call_deferred("_abrir")

## Ela acorda do lado dele, dentro de casa, e passa a ir junto.
func _abrir() -> void:
	var irma: Node3D = jogo.irma
	if irma != null:
		irma.global_position = jogo.jogador.global_position + Vector3(1.2, -0.1, 0.8)
		irma.seguir(jogo.jogador, jogo.camera)
	_proximo()

func passo_atual() -> Dictionary:
	return passos[indice] if indice >= 0 and indice < passos.size() else {}

func _proximo() -> void:
	indice += 1
	var passo := passo_atual()
	if passo.is_empty():
		_encerrar()
		return
	# O que ele já fez por conta própria, ela não pede de novo.
	if feitos.has(String(passo.get("evento", ""))):
		_proximo()
		return
	var falas: Array = passo.get("falas", [])
	if falas.is_empty() or indo_embora:
		_por_objetivo()
		return
	_falar(falas)

func _falar(falas: Array) -> void:
	_falando = true
	jogo.status.mostrar_objetivo("")
	_na_fila = falas

## O jogador está no meio de outra coisa (conversa, menu, TV, viagem, cama)?
func ocupado() -> bool:
	return jogo.dialogo.visible or jogo.escolha != null or jogo.tv != null or jogo.expediente != null \
		or jogo.menu != null or jogo.mochila != null or jogo.celular != null or jogo.dormindo

func _ao_terminar_fala() -> void:
	if not ativo or not _falando: return
	_falando = false
	if _sair_depois:
		_sair_depois = false
		ir_para_casa()
	if _dormir_depois:
		_dormir_depois = false
		jogo.call_deferred("dormir")
		return
	_por_objetivo()
	if bool(passo_atual().get("vai_embora", false)): ir_para_casa()

func _por_objetivo() -> void:
	jogo.status.mostrar_objetivo(String(passo_atual().get("objetivo", "")))

func _ao_evento(nome: String) -> void:
	var ja_feito := feitos.has(nome)
	feitos[nome] = true
	if not ativo: return
	if nome == "dormiu":
		_encerrar()
		return
	if nome == String(passo_atual().get("evento", "")) and not _falando:
		jogo.status.mostrar_objetivo("")
		_proximo()
		return
	# Fez fora de ordem: ela comenta, na caixa de fala, quando ele estiver livre.
	if not ja_feito and not indo_embora and _e_de_um_passo_adiante(nome): reagir(nome)

func _e_de_um_passo_adiante(nome: String) -> bool:
	for i in range(indice + 1, passos.size()):
		if String(passos[i].get("evento", "")) == nome: return true
	return false

func reagir(nome: String) -> void:
	var frase := String(dados.get("reacoes", {}).get(nome, ""))
	if frase.is_empty() or jogo.irma == null or not jogo.irma.visible: return
	_comentarios.append(frase)

## Na cama antes do fim do dia dela: ela reclama, vai embora e só depois ele
## dorme. Devolve true se segurou o sono para falar.
func segurar_o_sono() -> bool:
	if not ativo or indo_embora: return false
	var evento := String(passo_atual().get("evento", ""))
	if evento == "dormiu": return false
	var falas: Array = dados.get("falas_dormiu_sem_trancar" if evento == "trancou" else "falas_dormiu", [])
	_dormir_depois = true
	_sair_depois = true
	indo_embora = true
	indice = passos.size() - 1
	_falar(falas)
	return true

func _process(_delta: float) -> void:
	if not ativo: return
	if not _na_fila.is_empty() and not ocupado():
		var falas := _na_fila
		_na_fila = []
		jogo.falar_como_irma(String(dados.get("personagem", "Irmã")), falas)
	elif not _comentarios.is_empty() and _na_fila.is_empty() and not ocupado():
		jogo.falar_como_irma(String(dados.get("personagem", "Irmã")), [_comentarios.pop_front()])
	# Anoiteceu no meio do que só se faz de dia: ela desiste e vai embora.
	if not indo_embora and not _falando and jogo.ciclo.e_noite() and String(passo_atual().get("evento", "")) in PRECISA_DO_DIA:
		_falar(dados.get("falas_sem_tempo", []))
		indo_embora = true
		_sair_depois = true
		indice = passos.size() - 1
	# Indo embora: sai pelo portão e some quando chega lá, quando passa um tempo
	# fora da vista dele ou, no máximo, depois de vinte segundos.
	if indo_embora and _marco != null and jogo.irma != null and jogo.irma.visible and jogo.irma.seguindo == _marco:
		_andando += _delta
		var na_tela: bool = jogo.camera.is_position_in_frustum(jogo.irma.global_position + Vector3(0, 1.2, 0))
		_fora_da_vista = 0.0 if na_tela else _fora_da_vista + _delta
		if jogo.irma.global_position.distance_to(_marco.global_position) < 1.8 or _fora_da_vista > 1.2 or _andando > 20.0:
			jogo.irma.seguir(null)
			jogo.irma.aparecer(false)

## Ela vai embora a pé: sai pelo portão da casa dele, rumo à rua.
func ir_para_casa() -> void:
	indo_embora = true
	if jogo.irma == null: return
	if _marco == null:
		_marco = Node3D.new()
		_marco.name = "SaidaDaIrma"
		jogo.mundo.add_child(_marco)
	_marco.global_position = jogo.saida_de_casa()
	_andando = 0.0
	_fora_da_vista = 0.0
	jogo.irma.seguir(_marco, null)

func _encerrar() -> void:
	ativo = false
	jogo.status.mostrar_objetivo("")
	if jogo.irma != null:
		jogo.irma.seguir(null)
		jogo.irma.aparecer(false)
