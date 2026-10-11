extends Node

# Dia 0: a irmã passa o dia com o morador e ensina as mecânicas conversando.
# Cada passo mostra as falas dela, deixa um objetivo no HUD e espera o evento
# correspondente vindo do survival. Textos e ordem ficam em data/tutorial.json.
# Ela se adapta: lembra o objetivo quando o morador faz outra coisa, pula o que
# ele já fez sozinho e vai embora se o dia acabar ou se ele for dormir antes.
const DADOS := "res://data/tutorial.json"
## Por onde ela vai embora (portão) e quanto tempo espera entre dois lembretes.
const SAIDA := Vector2(656, 632)
const LEMBRETE_ESPERA := 8.0
## Passos que dependem de ter ação sobrando no dia.
const PRECISA_DE_ACAO := ["geladeira", "agua", "noticias", "trabalho"]
var dados: Dictionary = {}
var passos: Array = []
var indice := -1
var personagem := "Nina"
var ativo := false
var feitos: Dictionary = {}
var _ultimo_lembrete := -100.0
@onready var survival: CanvasLayer = get_parent().get_node("Sobrevivencia")
@onready var player: CharacterBody2D = get_parent().get_node("Morador")
@onready var irma: CharacterBody2D = get_parent().get_node("Irma")

func _ready() -> void:
	dados = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	passos = dados.get("passos", [])
	personagem = dados.get("personagem", "Nina")
	survival.evento.connect(_ao_evento)
	survival.dialogo.terminou.connect(_ao_terminar_fala)
	# Só o dia 0 tem tutorial; em qualquer outro dia ela nem aparece.
	ativo = survival.dia == survival.DIA_TUTORIAL
	if not ativo:
		irma.queue_free()
		return
	irma.global_position = player.global_position + Vector2(-30, 8)
	irma.seguir(player)
	call_deferred("_proximo")

func passo_atual() -> Dictionary:
	return passos[indice] if indice >= 0 and indice < passos.size() else {}

func _proximo() -> void:
	indice += 1
	var passo := passo_atual()
	if passo.is_empty():
		_encerrar()
		return
	# Se o morador já tinha feito isso por conta própria, ela não repete o pedido.
	if feitos.has(passo.get("evento", "")):
		_proximo()
		return
	irma.esperar() if passo.id == "despedida" else irma.seguir(player)
	survival.mostrar_dialogo(personagem, passo.get("falas", []))

func _ao_terminar_fala() -> void:
	if not ativo: return
	var passo := passo_atual()
	if passo.is_empty(): return
	survival.definir_objetivo(passo.get("objetivo", ""))
	# Depois de pedir para trancar, ela sai pelo portão.
	if passo.id == "mercado": irma.ir_embora(SAIDA)

func _ao_evento(nome: String) -> void:
	feitos[nome] = true
	if not ativo or survival.em_dialogo: return
	var passo := passo_atual()
	if passo.is_empty(): return
	if nome == passo.get("evento", ""):
		survival.definir_objetivo("")
		_proximo()
		return
	if nome == "dormiu":
		# A tela já está escurecendo: o recado dela aparece ao acordar.
		_ir_embora(dados.get("falas_dormiu", []), true)
		return
	if nome == "sem_acoes" and passo.id in PRECISA_DE_ACAO:
		_ir_embora(dados.get("falas_sem_tempo", []))
		return
	if nome.begins_with("viagem"):
		# Ela vai junto de ônibus: reaparece ao lado do morador na volta.
		if irma.visible: irma.aparecer_perto(player.global_position)
		return
	if nome.begins_with("menu:") or nome.begins_with("comprou:") or nome in ["agua", "midia", "trabalhou"]:
		_lembrar(passo)

# Fora do combinado: ela cobra o objetivo num balão, sem travar o jogo.
func _lembrar(passo: Dictionary) -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _ultimo_lembrete < LEMBRETE_ESPERA or not irma.visible: return
	_ultimo_lembrete = agora
	var texto: String = passo.get("lembrete", passo.get("objetivo", ""))
	survival.bubble.falar(irma, player, texto, 4.5)

# Dia acabou ou o morador foi dormir antes da hora: ela reclama e vai embora.
func _ir_embora(falas: Array, ao_acordar := false) -> void:
	ativo = false
	survival.definir_objetivo("")
	survival.avisar("%s: %s" % [personagem, " ".join(falas)], ao_acordar)
	if is_instance_valid(irma): irma.ir_embora(SAIDA)

func _encerrar() -> void:
	ativo = false
	survival.definir_objetivo("")
	if is_instance_valid(irma): irma.ir_embora(SAIDA)
