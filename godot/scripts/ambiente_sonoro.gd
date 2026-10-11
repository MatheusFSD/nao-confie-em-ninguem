class_name AmbienteSonoro
extends Node

# O som do bairro, gravado (res://sons, do Pixabay — ver sons/CREDITOS.md),
# em Ogg Vorbis: fundos de 50–90 s em laço emendado, avulsos em mono (o
# conversor é output/godot-validation/_converter_sons.py).
#
# Camadas em laço que trocam devagar conforme o dia da história e a hora:
#   - dias 0 a 5: de manhã, pássaros e trânsito; à tarde, a cidade; ao
#     anoitecer, carros passando na rua de trás; de noite, a praça vazia.
#     Do dia 3 em diante a cidade fica estranha e o trânsito, mais ralo;
#   - dia 6 (o breu): silêncio. Só, de tempos em tempos, um monstro à espreita
#     ao longe. Nem cachorro;
#   - dia 7 (o ataque): guerra ao longe de dia, mais perto de noite, e por
#     cima disparos fortes — tiros e explosões recortados das gravações e
#     rajadas de metralhadora;
#   - dia 8 em diante (cidade destruída): um coro grave de fundo, tiros muito
#     longe de dia e, de vez em quando, monstros e gritos no horizonte.
# Por cima, os cachorros: de dia latem perto e mais vezes; de noite, longe e
# abafados. Depois do ataque, nem cachorro late mais.
#
# Dentro de casa (com teto em cima da cabeça), tudo passa por um filtro que
# abafa, como através da parede. Os volumes compensam a altura de gravação de
# cada arquivo, medida em dB.
const PASTA := "res://sons/"
const BARRAMENTO := "Ambiente"
## Camada → [arquivo, ganho em dB que leva o arquivo ao nível dela].
const CAMADAS := {
	"dia": ["dia_passaros_transito.ogg", 13.9],
	"beco": ["dia_beco_transito.ogg", -10.1],
	"tarde": ["tarde_cidade.ogg", -2.7],
	"anoitecer": ["anoitecer_carros.ogg", 3.7],
	"noite": ["noite_calma.ogg", -3.0],
	"guerra": ["guerra_distante.ogg", -5.4],
	"guerra_perto": ["guerra_perto.ogg", -10.7],
	"tiros_longe": ["guerra_tiros_longe.ogg", -20.1],
	"cidade_morta": ["cidade_morta.ogg", -20.9],
}
## Onde começa cada latido dentro das gravações de cachorro, em segundos.
const LATIDOS := {
	"cachorro_grande.ogg": [0.05, 1.6, 4.3, 6.75, 11.85, 16.3, 19.45, 23.9],
	"cachorro_pequeno.ogg": [0.0, 1.3, 5.75, 7.45, 10.15],
}
const MONSTROS := ["monstro_espreita.ogg", "monstro_respiracao.ogg", "monstro_assombro.ogg"]
## Disparos fortes dentro das gravações de guerra (onde começa cada um), já
## no corte em Ogg (que começa 2 s depois do original).
const DISPAROS := {
	"guerra_tiros_longe.ogg": [2.2, 4.55, 6.95, 11.4, 17.65, 19.85, 22.6, 27.55],
	"guerra_perto.ogg": [18.95, 26.15, 59.2, 66.7],
}
## As explosões da gravação de guerra distante, no mesmo corte.
const EXPLOSOES := [22.25, 27.05, 31.5, 41.35, 57.25, 79.9, 81.45, 83.0]
## Os dois gritos da gravação de gritos: [começo, duração].
const GRITOS := [[0.8, 7.2], [9.4, 7.3]]
## Quanto tempo leva para uma camada entrar ou sair.
const TROCA := 3.0

var jogo: Node
var _tocadores := {}
var _alvos := {}
var _proximo_latido := 5.0
var _proximo_monstro := 12.0
var _proximo_grito := 60.0
var _proximo_disparo := 2.0
var _olhar_o_teto := 0.0
var dentro := false
## O quanto a parede abafa agora (0 = rua aberta, 1 = dentro de casa). Muda
## devagar: entrar e sair de casa não pode cortar o som de uma vez.
var _parede := 0.0
var _proxima_buzina := 2.0
## Abafa tudo (TV ligada, viagem, cama): de 0 (normal) a 1 (mudo).
var abafar := 0.0

static func carregar(nome: String) -> AudioStream:
	return load(PASTA + nome)

## O barramento do ambiente, com o filtro de parede (desligado na rua).
static func barramento() -> int:
	var indice := AudioServer.get_bus_index(BARRAMENTO)
	if indice >= 0: return indice
	AudioServer.add_bus()
	indice = AudioServer.bus_count - 1
	AudioServer.set_bus_name(indice, BARRAMENTO)
	AudioServer.set_bus_send(indice, "Master")
	var parede := AudioEffectLowPassFilter.new()
	parede.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(indice, parede)
	return indice

func comecar(mundo: Node) -> void:
	jogo = mundo
	barramento()
	for nome: String in CAMADAS:
		var tocador := AudioStreamPlayer.new()
		tocador.name = "Camada_" + nome
		var som := carregar(String(CAMADAS[nome][0]))
		if "loop" in som: som.set("loop", true)
		tocador.stream = som
		tocador.bus = BARRAMENTO
		tocador.volume_linear = 0.0
		add_child(tocador)
		_tocadores[nome] = tocador

## Quanto de cada camada toca agora (0 a 1), pelo dia e pela hora.
static func alvos(dia: int, hora: int) -> Dictionary:
	var a := {}
	if dia >= 8:
		a["cidade_morta"] = 1.0
		a["noite"] = 0.5
		if hora < 18: a["tiros_longe"] = 0.6
		return a
	if dia == 7:
		a["guerra"] = 1.0 if hora < 18 else 0.6
		if hora >= 18: a["guerra_perto"] = 1.0
		return a
	# O breu é silêncio: nenhuma camada.
	if dia == 6: return a
	# Dias normais. A partir do 3, a cidade estranha: trânsito mais ralo.
	var transito := 1.0 if dia < 3 else 0.65
	if hora < 16:
		a["dia"] = 1.0
		a["beco"] = 0.6 * transito
	elif hora < 18:
		a["tarde"] = transito
		a["dia"] = 0.4
	elif hora < 20:
		a["anoitecer"] = transito
		a["noite"] = 0.3
	else:
		a["noite"] = 1.0
	return a

func _process(delta: float) -> void:
	if jogo == null or jogo.ciclo == null: return
	_alvos = alvos(jogo.dia_de_hoje(), jogo.ciclo.hora())
	# Viagem de ônibus, TV ligada ou cama: o bairro fica de fundo.
	var mudo: bool = jogo.expediente != null or jogo.dormindo
	abafar = move_toward(abafar, 1.0 if mudo else (0.55 if jogo.tv != null else 0.0), delta * 0.8)
	for nome: String in _tocadores:
		var tocador: AudioStreamPlayer = _tocadores[nome]
		var alvo: float = float(_alvos.get(nome, 0.0)) * (1.0 - abafar)
		var atual := tocador.volume_linear / db_to_linear(float(CAMADAS[nome][1])) if tocador.playing else 0.0
		atual = move_toward(atual, alvo, delta / TROCA)
		if atual <= 0.001:
			if tocador.playing: tocador.stop()
			continue
		if not tocador.playing: tocador.play(randf() * maxf(0.0, tocador.stream.get_length() - 5.0))
		tocador.volume_linear = atual * db_to_linear(float(CAMADAS[nome][1]))
	conferir_o_teto(delta)
	# A parede entra e sai em quase um segundo: corte do filtro em escala
	# logarítmica (de 20 kHz a 700 Hz) e um pouco de volume.
	_parede = move_toward(_parede, 1.0 if dentro else 0.0, delta * 1.3)
	var filtro := AudioServer.get_bus_effect(barramento(), 0) as AudioEffectLowPassFilter
	if filtro != null: filtro.cutoff_hz = exp(lerpf(log(20000.0), log(700.0), _parede))
	AudioServer.set_bus_volume_db(barramento(), lerpf(0.0, -4.0, _parede))
	if not mudo:
		buzinar(delta)
		latir(delta)
		assombrar(delta)
		guerrear(delta)

## Debaixo de um teto, o som da rua chega abafado.
func conferir_o_teto(delta: float) -> void:
	_olhar_o_teto -= delta
	if _olhar_o_teto > 0.0: return
	_olhar_o_teto = 0.4
	var olho: Vector3 = jogo.camera.global_position
	var espaco: PhysicsDirectSpaceState3D = jogo.camera.get_world_3d().direct_space_state
	var raio := PhysicsRayQueryParameters3D.create(olho, olho + Vector3.UP * 4.0, 1)
	dentro = jogo.abrigo != null or not espaco.intersect_ray(raio).is_empty()

## Um ponto longe do jogador, em volta.
func longe(de: float, ate: float) -> Vector3:
	var rumo := randf() * TAU
	return jogo.jogador.global_position + Vector3(cos(rumo), 0.0, sin(rumo)) * randf_range(de, ate)

## Toca um pedaço de uma gravação num ponto do mundo e some depois.
func tocar_trecho_em(onde: Vector3, som: AudioStream, de: float, dura: float, volume: float, alcance: float) -> AudioStreamPlayer3D:
	var tocador := AudioStreamPlayer3D.new()
	tocador.stream = som
	tocador.bus = BARRAMENTO
	tocador.volume_db = volume
	tocador.max_distance = alcance
	tocador.unit_size = alcance / 5.0
	tocador.attenuation_filter_db = -18.0
	jogo.mundo.add_child(tocador)
	tocador.global_position = onde
	tocador.play(de)
	tocador.get_tree().create_timer(dura).timeout.connect(tocador.queue_free)
	return tocador

## Os cachorros do bairro. De dia, perto e mais vezes; de noite, longe e
## abafados. Depois do ataque, silêncio.
func latir(delta: float) -> void:
	if jogo.dia_de_hoje() >= Ciclo3D.DIA_DO_BREU: return
	_proximo_latido -= delta
	if _proximo_latido > 0.0: return
	var noite: bool = jogo.ciclo.e_noite()
	_proximo_latido = randf_range(18.0, 40.0) if noite else randf_range(9.0, 24.0)
	var onde := longe(30.0, 55.0) if noite else longe(14.0, 30.0)
	var latido: AudioStreamPlayer3D
	if randf() < 0.55:
		latido = tocar_trecho_em(onde, carregar("latido.ogg"), 0.0, 1.2, 2.0 if noite else 4.0, 80.0)
	else:
		var arquivo: String = LATIDOS.keys()[randi() % LATIDOS.size()]
		var inicios: Array = LATIDOS[arquivo]
		latido = tocar_trecho_em(onde, carregar(arquivo), float(inicios[randi() % inicios.size()]), randf_range(1.2, 2.6), 0.0 if noite else 2.0, 80.0)
	latido.pitch_scale = randf_range(0.9, 1.1)
	if noite: latido.attenuation_filter_cutoff_hz = 1800.0

## No breu, um monstro à espreita, longe, de vez em quando (e mais nada). Na
## cidade destruída: monstros no horizonte e, às vezes, alguém gritando.
func assombrar(delta: float) -> void:
	var hoje: int = jogo.dia_de_hoje()
	if hoje != Ciclo3D.DIA_DO_BREU and hoje < 8: return
	_proximo_monstro -= delta
	if _proximo_monstro <= 0.0:
		var no_breu := hoje == Ciclo3D.DIA_DO_BREU
		_proximo_monstro = randf_range(30.0, 70.0) if no_breu else randf_range(25.0, 55.0)
		var arquivo: String = "monstro_espreita.ogg" if no_breu else MONSTROS[randi() % MONSTROS.size()]
		var monstro := tocar_trecho_em(longe(60.0, 110.0) if no_breu else longe(70.0, 120.0), carregar(arquivo), 0.0, 10.0, 6.0 if no_breu else 8.0, 220.0)
		monstro.pitch_scale = randf_range(0.8, 0.95) if no_breu else randf_range(0.7, 0.95)
	if hoje < 8: return
	_proximo_grito -= delta
	if _proximo_grito <= 0.0:
		_proximo_grito = randf_range(70.0, 150.0)
		var grito: Array = GRITOS[randi() % GRITOS.size()]
		tocar_trecho_em(longe(60.0, 110.0), carregar("gritos_longe.ogg"), float(grito[0]), float(grito[1]), 0.0, 200.0)

## O dia do ataque: por cima da guerra de fundo, disparos que se ouvem de
## verdade. Rajadas de metralhadora, tiros e explosões recortados das
## gravações, a algumas dezenas de metros. De noite, mais seguidos.
func guerrear(delta: float) -> void:
	if jogo.dia_de_hoje() != Ciclo3D.DIA_DO_ATAQUE: return
	_proximo_disparo -= delta
	if _proximo_disparo > 0.0: return
	var noite: bool = jogo.ciclo.e_noite()
	_proximo_disparo = randf_range(0.8, 3.0) if noite else randf_range(1.2, 4.0)
	var sorte := randf()
	if sorte < 0.45:
		# Rajada: de três a oito tiros seguidos, do mesmo lugar.
		var onde := longe(12.0, 35.0)
		var intervalo := randf_range(0.08, 0.13)
		for i in randi_range(3, 8):
			jogo.get_tree().create_timer(i * intervalo).timeout.connect(func():
				if is_inside_tree(): tocar_trecho_em(onde, Sons3D.tiro(), 0.0, 0.9, 6.0, 140.0).pitch_scale = randf_range(0.85, 1.1))
	elif sorte < 0.75:
		var arquivo: String = DISPAROS.keys()[randi() % DISPAROS.size()]
		var inicios: Array = DISPAROS[arquivo]
		tocar_trecho_em(longe(15.0, 45.0), carregar(arquivo), maxf(0.0, float(inicios[randi() % inicios.size()]) - 0.1), 1.8, 10.0, 180.0)
	else:
		tocar_trecho_em(longe(25.0, 70.0), carregar("guerra_distante.ogg"), float(EXPLOSOES[randi() % EXPLOSOES.size()]) - 0.1, 3.0, 12.0, 260.0)

## No dia do engarrafamento: buzina atrás de buzina, de carros de verdade da rua.
func buzinar(delta: float) -> void:
	if not jogo.dia_de_engarrafamento(): return
	_proxima_buzina -= delta
	if _proxima_buzina > 0.0: return
	_proxima_buzina = randf_range(0.8, 3.5)
	var carros: Array = jogo.get_tree().get_nodes_in_group("carros3d").filter(func(c): return (c as Node3D).is_visible_in_tree())
	if carros.is_empty(): return
	var carro: Node3D = carros[randi() % carros.size()]
	var vezes := 1 if randf() < 0.6 else randi_range(2, 4)
	var tom := randf_range(0.85, 1.2)
	for i in vezes:
		jogo.get_tree().create_timer(i * randf_range(0.25, 0.4)).timeout.connect(func():
			if is_instance_valid(carro): tocar_trecho_em(carro.global_position + Vector3.UP, Sons3D.buzina(), 0.0, 0.6, 2.0, 70.0).pitch_scale = tom)
