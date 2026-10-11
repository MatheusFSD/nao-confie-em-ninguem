class_name Observadores3D
extends Node3D

# Quem decide quando o Observador aparece. Ele é raro de propósito: um por vez,
# longe, e só surge onde o jogador não está olhando — para ser descoberto, nunca
# para "brotar" na frente. Cada aparição do roteiro (data/observador3d.json)
# acontece no máximo uma vez por dia, num ponto sorteado do seu grupo de
# lugares; ao virar o dia, quem estava na rua some sem ninguém ver.
#
# Dois jeitos de ir embora:
#   - "desviar": depois de visto, basta o jogador desviar o olhar para ele não
#     estar mais lá;
#   - "fugir": deixa chegar perto e, a `alerta` metros, vira e corre (é o
#     comportamento do próprio observador.gd).
const DADOS := "res://data/observador3d.json"
const CENA := "res://modelos/observador/observador.tscn"
## Altura da cabeça, para saber se dá para vê-lo.
const CABECA := 1.95
## De quanto em quanto tempo o roteiro é conferido.
const INTERVALO := 0.4
## Do dia seguinte ao ataque em diante, se ele vê o jogador na rua, grita.
const DIA_DO_OLHO := 8
## Até onde ele enxerga o jogador.
const VISTA_DO_OBSERVADOR := 30.0

## O Observador viu o jogador: os caçadores vão atrás de `onde`.
signal alarme(onde: Vector3)

var dados := {}
## Preenchidos pelo mundo.
var jogador: Node3D
var camera: Camera3D
var ciclo: Ciclo3D
var casa_lugar := Vector3.ZERO
var resolucao := Vector2(320, 213)
## Colisores que não se veem (barreiras do fim da rua, cercas dos becos): não
## tapam a vista.
var transparentes: Array[RID] = []
## Onde o jogador está protegido (o lote de casa): dali ele não é visto.
var abrigo_do_jogador := Rect2()
var _gritou := false

## O que está na rua agora (ou null) e de qual aparição ele veio.
var atual: Node3D
var aparicao_atual := {}
## Aparições já usadas, por "id|dia".
var usadas := {}
## Último lugar de cada grupo, para não repetir o mesmo ponto em seguida.
var ultimo_lugar := {}
var _visto := false
var _fora_da_vista := 0.0
var _espera := 0.0
var _sorte := RandomNumberGenerator.new()
var _cena: PackedScene

func _ready() -> void:
	name = "Observadores"
	var documento = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	dados = documento if documento is Dictionary else {}
	_sorte.randomize()
	_cena = load(CENA)

func regra(chave: String, padrao: float) -> float:
	return float(dados.get("regras", {}).get(chave, padrao))

## As aparições que valem para este dia e período e ainda não aconteceram hoje.
func possiveis(dia: int, periodo: int) -> Array:
	var lista := []
	for aparicao: Dictionary in dados.get("aparicoes", []):
		var dias: Array = aparicao.get("dias", [0, 0])
		if dia < int(dias[0]) or dia > int(dias[1]): continue
		if not (aparicao.get("periodos", []) as Array).has(float(periodo)) and not (aparicao.get("periodos", []) as Array).has(periodo): continue
		if usadas.has("%s|%d" % [aparicao.get("id", ""), dia]): continue
		lista.append(aparicao)
	return lista

## Um ponto do grupo, evitando repetir o último que saiu dele.
func sortear_lugar(grupo: String) -> Vector3:
	var pontos: Array = dados.get("lugares", {}).get(grupo, [])
	if pontos.is_empty(): return Vector3.INF
	var escolha := _sorte.randi_range(0, pontos.size() - 1)
	if pontos.size() > 1 and ultimo_lugar.get(grupo, -1) == escolha: escolha = (escolha + 1) % pontos.size()
	ultimo_lugar[grupo] = escolha
	var p: Array = pontos[escolha]
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

## O jogador está vendo este ponto agora? Na tela, perto o bastante e sem
## parede no meio.
func a_vista(ponto: Vector3) -> bool:
	if camera == null or not camera.is_inside_tree(): return false
	var cabeca := ponto + Vector3.UP * CABECA
	if camera.global_position.distance_to(cabeca) > regra("alcance_da_vista", 70.0): return false
	if not camera.is_position_in_frustum(cabeca): return false
	var raio := PhysicsRayQueryParameters3D.create(camera.global_position, cabeca, 1, transparentes)
	return get_world_3d().direct_space_state.intersect_ray(raio).is_empty()

func _process(delta: float) -> void:
	if jogador == null or ciclo == null: return
	if atual != null:
		acompanhar(delta)
		return
	_espera -= delta
	if _espera > 0.0: return
	_espera = INTERVALO
	tentar_surgir()

## Põe o Observador na rua, se o roteiro pedir e o lugar sorteado servir: longe
## do jogador e fora da vista dele.
func tentar_surgir() -> bool:
	var dia := ciclo.dia
	var periodo := ciclo.indice_do_periodo()
	for aparicao: Dictionary in possiveis(dia, periodo):
		var lugar := sortear_lugar(String(aparicao.get("lugares", "")))
		if lugar == Vector3.INF: continue
		var longe := Vector2(lugar.x - jogador.global_position.x, lugar.z - jogador.global_position.z).length()
		if longe < regra("distancia_minima_para_surgir", 14.0) or a_vista(lugar): continue
		surgir(aparicao, lugar)
		return true
	return false

func surgir(aparicao: Dictionary, lugar: Vector3) -> void:
	usadas["%s|%d" % [aparicao.get("id", ""), ciclo.dia]] = true
	var novo: Observador3D = _cena.instantiate()
	novo.resolucao = resolucao
	novo.alvo = jogador
	if String(aparicao.get("modo", "desviar")) == "fugir":
		novo.distancia_alerta = float(aparicao.get("alerta", 7.0))
		novo.distancia_para_sumir = 6.0
	else:
		# Quem só some ao desviar o olhar também não deixa chegar muito perto.
		novo.distancia_alerta = float(aparicao.get("alerta", 0.0))
	add_child(novo)
	var mirar := casa_lugar if bool(aparicao.get("olha_para_a_casa", false)) else jogador.global_position
	novo.reaparecer(lugar, mirar)
	atual = novo
	aparicao_atual = aparicao
	_visto = false
	_fora_da_vista = 0.0

func acompanhar(delta: float) -> void:
	if not is_instance_valid(atual) or atual.estado == Observador3D.Estado.SUMIU:
		retirar()
		return
	# Depois do ataque: viu o jogador na rua, grita e chama os caçadores.
	if not _gritou and ciclo.dia >= DIA_DO_OLHO and atual.estado == Observador3D.Estado.OBSERVANDO and ve_o_jogador():
		_gritou = true
		atual.gritar()
		alarme.emit(jogador.global_position)
		return
	# Passou a hora dele sem ninguém ver: vai embora em silêncio.
	if not _visto and possiveis_agora_inclui_atual() == false and not a_vista(atual.global_position):
		retirar()
		return
	if String(aparicao_atual.get("modo", "desviar")) != "desviar": return
	if atual.estado != Observador3D.Estado.OBSERVANDO: return
	if a_vista(atual.global_position):
		_visto = true
		_fora_da_vista = 0.0
	elif _visto:
		_fora_da_vista += delta
		if _fora_da_vista >= regra("segundos_para_sumir_depois_de_visto", 0.6): retirar()

## A aparição atual ainda vale para o período de agora?
func possiveis_agora_inclui_atual() -> bool:
	var periodos: Array = aparicao_atual.get("periodos", [])
	var agora := ciclo.indice_do_periodo()
	return periodos.has(float(agora)) or periodos.has(agora)

## O Observador enxerga o jogador: perto, sem parede no meio e fora de casa.
func ve_o_jogador() -> bool:
	if not is_instance_valid(atual) or jogador == null: return false
	if abrigo_do_jogador.has_area() and abrigo_do_jogador.has_point(Vector2(jogador.global_position.x, jogador.global_position.z)): return false
	var olho := atual.global_position + Vector3.UP * CABECA
	var alvo := jogador.global_position + Vector3.UP * 1.3
	# Agachado, o vulto some atrás de muro e carro: ele só vê de mais perto.
	var vista := VISTA_DO_OBSERVADOR * (0.45 if jogador.get("agachado") == true else 1.0)
	if jogador.get("agachado") == true: alvo.y -= 0.5
	if olho.distance_to(alvo) > vista: return false
	var raio := PhysicsRayQueryParameters3D.create(olho, alvo, 1, transparentes)
	return get_world_3d().direct_space_state.intersect_ray(raio).is_empty()

func retirar() -> void:
	if is_instance_valid(atual): atual.queue_free()
	atual = null
	aparicao_atual = {}
	_visto = false
	_gritou = false
	_espera = INTERVALO

## Virou o dia: ninguém fica na rua de um dia para o outro.
func limpar() -> void:
	retirar()
