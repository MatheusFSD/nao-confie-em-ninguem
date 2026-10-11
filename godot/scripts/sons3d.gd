class_name Sons3D
extends RefCounted

# Sons gerados por código, sem arquivo: o projeto não tem áudio gravado, e
# estes são simples o bastante para sair de uma fórmula. Cada um é criado uma
# vez e guardado.
#   - passo pesado: o caçador andando, um baque surdo;
#   - passo de corrida: mais curto e seco, com estalo de unha no chão;
#   - grito: o Observador avisando os caçadores;
#   - bote: o ataque;
#   - tiro: o revólver do bandido do beco e do sargento;
#   - passo do jogador (em terra), motor e pneu de carro, caminhão e tanque do
#     Exército, helicóptero, motor e freio a ar do ônibus, caixa registradora;
#   - o celular (tecla, abrir, guardar, mensagem chegando, vibrar) e o "tic"
#     das letras surgindo nas falas, como nos RPGs japoneses antigos.
# Os sons gravados (bairro, cachorros, guerra, monstros, TV, rádio) ficam em
# res://sons e entram pelo AmbienteSonoro, pela TV e pelo rádio.
# Os motores voltam ao começo sem emenda (laço): as frequências cabem inteiras
# na duração.
const TAXA := 22050

static var _guardados := {}

static func passo_pesado() -> AudioStreamWAV:
	return _guardar("passo_pesado", func(): return _gerar(0.22, func(t: float, ruido: float) -> float:
		var baque := sin(TAU * lerpf(85.0, 42.0, t / 0.22) * t) * exp(-t * 26.0)
		return baque * 0.9 + ruido * exp(-t * 45.0) * 0.35))

static func passo_corrida() -> AudioStreamWAV:
	return _guardar("passo_corrida", func(): return _gerar(0.12, func(t: float, ruido: float) -> float:
		var baque := sin(TAU * lerpf(110.0, 60.0, t / 0.12) * t) * exp(-t * 40.0)
		var unha := ruido * exp(-t * 90.0) * (1.0 if t < 0.03 else 0.2)
		return baque * 0.7 + unha * 0.6))

static func grito() -> AudioStreamWAV:
	return _guardar("grito", func(): return _gerar(1.7, func(t: float, ruido: float) -> float:
		var altura := lerpf(780.0, 330.0, pow(t / 1.7, 0.7)) * (1.0 + sin(t * 37.0) * 0.03)
		var voz := 0.0
		for harmonico in [1.0, 1.5, 2.02, 3.01]:
			voz += sin(TAU * altura * harmonico * t) / harmonico
		var envelope := minf(1.0, t / 0.04) * exp(-t * 1.4)
		return clampf((voz * 0.55 + ruido * 0.35) * envelope * 1.8, -1.0, 1.0)))

static func bote() -> AudioStreamWAV:
	return _guardar("bote", func(): return _gerar(0.6, func(t: float, ruido: float) -> float:
		var rugido := sin(TAU * lerpf(160.0, 55.0, t / 0.6) * t) * exp(-t * 4.0)
		return clampf((rugido * 0.8 + ruido * exp(-t * 6.0) * 0.7) * 1.6, -1.0, 1.0)))

## Tiro de revólver: estalo seco e o eco grave da rua.
static func tiro() -> AudioStreamWAV:
	return _guardar("tiro", func(): return _gerar(0.9, func(t: float, ruido: float) -> float:
		var estalo := ruido * 2.2 * exp(-t * 38.0)
		var eco := sin(TAU * lerpf(90.0, 40.0, t / 0.9) * t) * exp(-t * 6.0) * 0.7
		var cauda := ruido * exp(-t * 5.0) * 0.18
		return clampf(estalo + eco + cauda, -1.0, 1.0)))

## Passo do morador: abafado, como pisando em terra batida. Baque grave e um
## chiado curto de terra, sem estalo de ataque.
static func passo_jogador() -> AudioStreamWAV:
	return _guardar("passo_jogador", func(): return _gerar(0.16, func(t: float, ruido: float) -> float:
		var ataque := minf(1.0, t / 0.008)
		var baque := sin(TAU * lerpf(95.0, 58.0, t / 0.16) * t) * exp(-t * 30.0) * 0.6
		var terra := ruido * exp(-t * 24.0) * 0.4
		return (baque + terra) * ataque))

## Motor de carro em marcha lenta, em laço de 1 s.
static func motor_carro() -> AudioStreamWAV:
	return _guardar("motor_carro", func(): return _gerar(1.0, func(t: float, ruido: float) -> float:
		var giro := 0.6 + 0.4 * sin(TAU * 24.0 * t)
		var ronco := sin(TAU * 48.0 * t) * 0.5 + sin(TAU * 96.0 * t) * 0.25 + sin(TAU * 144.0 * t) * 0.12
		return (ronco * giro + ruido * 0.15) * 0.55, true))

## Diesel do ônibus, em laço de 1 s: mais grave e com o bater das válvulas.
static func motor_onibus() -> AudioStreamWAV:
	return _guardar("motor_onibus", func(): return _gerar(1.0, func(t: float, ruido: float) -> float:
		var batida := pow(absf(sin(PI * 13.0 * t)), 6.0)
		var ronco := sin(TAU * 32.0 * t) * 0.55 + sin(TAU * 64.0 * t) * 0.3 + sin(TAU * 128.0 * t) * 0.1
		return (ronco * (0.55 + 0.45 * batida) + ruido * 0.25 * batida) * 0.7, true))

## Caminhão do Exército: diesel grosso, mais lento que o do ônibus, com a
## lataria batendo. Laço de 1 s.
static func motor_caminhao() -> AudioStreamWAV:
	return _guardar("motor_caminhao", func(): return _gerar(1.0, func(t: float, ruido: float) -> float:
		var batida := pow(absf(sin(PI * 9.0 * t)), 6.0)
		var ronco := sin(TAU * 30.0 * t) * 0.55 + sin(TAU * 60.0 * t) * 0.3 + sin(TAU * 90.0 * t) * 0.15
		return (ronco * (0.6 + 0.4 * batida) + ruido * 0.3 * batida) * 0.8, true))

## Carro de combate: ronco fundo, o assobio da turbina e a esteira batendo
## nos roletes. Laço de 1 s.
static func motor_tanque() -> AudioStreamWAV:
	return _guardar("motor_tanque", func(): return _gerar(1.0, func(t: float, ruido: float) -> float:
		var ronco := sin(TAU * 22.0 * t) * 0.6 + sin(TAU * 44.0 * t) * 0.3 + ruido * 0.25
		var turbina := sin(TAU * 330.0 * t) * 0.05
		var u := fmod(t, 0.125)
		var esteira := (sin(TAU * 1200.0 * u) * 0.5 + sin(TAU * 1730.0 * u) * 0.3) * exp(-u * 70.0)
		return clampf((ronco + turbina + esteira * 0.45) * 0.85, -1.0, 1.0), true))

## Pneu no asfalto: o chiado que cresce quando o carro passa perto. Laço.
static func pneu() -> AudioStreamWAV:
	return _guardar("pneu", func(): return _gerar(1.0, func(_t: float, chiado: float) -> float:
		return chiado * 0.22, true, true))

## Hélices do helicóptero: o "tuc-tuc" das pás e a turbina. Laço de 1 s.
static func helicoptero() -> AudioStreamWAV:
	return _guardar("helicoptero", func(): return _gerar(1.0, func(t: float, ruido: float) -> float:
		var u := fmod(t, 0.2)
		var pa := (sin(TAU * 62.0 * u) * 0.6 + ruido * 0.5) * exp(-u * 22.0)
		var turbina := sin(TAU * 880.0 * t) * 0.04
		return clampf(pa + turbina, -1.0, 1.0), true))

## O freio a ar do ônibus parando: um chiado que esvazia.
static func freio_onibus() -> AudioStreamWAV:
	return _guardar("freio_onibus", func(): return _gerar(1.3, func(t: float, chiado: float) -> float:
		var sopro := minf(1.0, t / 0.03) * exp(-t * 2.6)
		return chiado * sopro * 0.5, false, true))

## Caixa registradora: o sino e a gaveta batendo.
static func compra() -> AudioStreamWAV:
	return _guardar("compra", func(): return _gerar(0.9, func(t: float, ruido: float) -> float:
		var gaveta := (ruido * 0.9 + sin(TAU * 110.0 * t) * 0.6) * exp(-t * 40.0)
		var u := t - 0.12
		var sino := 0.0
		if u > 0.0: sino = (sin(TAU * 1760.0 * u) * 0.5 + sin(TAU * 2637.0 * u) * 0.3 + sin(TAU * 3520.0 * u) * 0.12) * exp(-u * 5.0)
		return clampf(gaveta + sino, -1.0, 1.0)))

## Sons de porta feitos como o som de verdade se faz: um empurrão (estalo,
## atrito, batida) passando por corpos que ressoam — madeira grave e curta,
## metal agudo e longo. Nada de tom puro subindo, que soa como apito.
class Ressoa:
	var a1 := 0.0
	var a2 := 0.0
	var ganho := 1.0
	var y1 := 0.0
	var y2 := 0.0
	func _init(freq: float, decaimento_s: float, g := 1.0) -> void:
		var r := exp(-1.0 / (decaimento_s * TAXA))
		a1 = 2.0 * r * cos(TAU * freq / TAXA)
		a2 = -r * r
		ganho = g * (1.0 - r)
	func passo(x: float) -> float:
		var y := a1 * y1 + a2 * y2 + x * ganho
		y2 = y1
		y1 = y
		return y

static func _wav(amostras: PackedFloat32Array, volume := 1.0) -> AudioStreamWAV:
	var maior := 0.0001
	for v in amostras: maior = maxf(maior, absf(v))
	var dados := PackedByteArray()
	dados.resize(amostras.size() * 2)
	for i in amostras.size():
		var v := amostras[i] / maior * volume
		v *= minf(1.0, (amostras.size() - i) / (TAXA * 0.01))
		dados.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var som := AudioStreamWAV.new()
	som.format = AudioStreamWAV.FORMAT_16_BITS
	som.mix_rate = TAXA
	som.stereo = false
	som.data = dados
	return som

## Um clique metálico (trinco, lingueta) somado em `saida` a partir de `inicio`.
static func _clique(saida: PackedFloat32Array, inicio: float, forca: float, sorte: RandomNumberGenerator) -> void:
	var metais := [Ressoa.new(2350.0 * sorte.randf_range(0.95, 1.05), 0.018), Ressoa.new(3650.0 * sorte.randf_range(0.95, 1.05), 0.012), Ressoa.new(5200.0, 0.006)]
	var de := int(inicio * TAXA)
	for i in range(de, mini(saida.size(), de + int(0.08 * TAXA))):
		var x := (sorte.randf_range(-1.0, 1.0) if i - de < 60 else 0.0) * forca
		var y := 0.0
		for m: Ressoa in metais: y += m.passo(x)
		saida[i] += y

## Uma batida de madeira (a folha da porta no batente).
static func _batida(saida: PackedFloat32Array, inicio: float, forca: float, sorte: RandomNumberGenerator) -> void:
	var madeira := [Ressoa.new(88.0, 0.09, 3.0), Ressoa.new(176.0, 0.05, 1.6), Ressoa.new(410.0, 0.025, 0.8)]
	var de := int(inicio * TAXA)
	var filtrado := 0.0
	for i in range(de, mini(saida.size(), de + int(0.35 * TAXA))):
		filtrado = lerpf(filtrado, sorte.randf_range(-1.0, 1.0), 0.25)
		var x := filtrado * forca * exp(-(i - de) / (TAXA * 0.006))
		var y := 0.0
		for m: Ressoa in madeira: y += m.passo(x)
		saida[i] += y

## Porta abrindo e fechando: gravações (sons/CREDITOS.md). Trancar, maçaneta
## forçada e batidas continuam sintetizados abaixo.
static func porta_abrir() -> AudioStream:
	return load("res://sons/porta_abrir.ogg")

static func porta_fechar() -> AudioStream:
	return load("res://sons/porta_fechar.ogg")

## Trancar: a chave entra raspando, gira, e o ferrolho corre e bate.
static func trancar() -> AudioStreamWAV:
	return _guardar("trancar", func():
		var sorte := RandomNumberGenerator.new()
		sorte.seed = 41
		var saida := PackedFloat32Array()
		saida.resize(int(0.42 * TAXA))
		var raspa := Ressoa.new(2800.0, 0.004, 1.0)
		for i in int(0.07 * TAXA):
			saida[i] += raspa.passo(sorte.randf_range(-1.0, 1.0) * 0.25)
		_clique(saida, 0.09, 0.6, sorte)
		var corre := Ressoa.new(1600.0, 0.006, 1.0)
		for i in range(int(0.16 * TAXA), int(0.26 * TAXA)):
			saida[i] += corre.passo(sorte.randf_range(-1.0, 1.0) * 0.2)
		_clique(saida, 0.27, 1.0, sorte)
		_batida(saida, 0.27, 0.25, sorte)
		return _wav(saida, 0.75))

## Maçaneta forçada numa porta trancada: o trinco batendo, três vezes.
static func porta_forcada() -> AudioStreamWAV:
	return _guardar("porta_forcada", func():
		var sorte := RandomNumberGenerator.new()
		sorte.seed = 43
		var saida := PackedFloat32Array()
		saida.resize(int(0.55 * TAXA))
		for inicio in [0.0, 0.14, 0.28]:
			_clique(saida, inicio, 0.7, sorte)
			_batida(saida, inicio + 0.01, 0.35, sorte)
		return _wav(saida, 0.75))

## Batidas fortes numa porta, de punho fechado: quem quer entrar.
static func batidas_na_porta() -> AudioStreamWAV:
	return _guardar("batidas_na_porta", func():
		var sorte := RandomNumberGenerator.new()
		sorte.seed = 47
		var saida := PackedFloat32Array()
		saida.resize(int(1.3 * TAXA))
		for inicio in [0.0, 0.22, 0.42, 0.78, 0.98]:
			_batida(saida, inicio, 1.0, sorte)
		return _wav(saida, 0.95))

## Buzina de carro: duas notas desafinadas juntas, como as buzinas baratas.
static func buzina() -> AudioStreamWAV:
	return _guardar("buzina", func(): return _gerar(0.55, func(t: float, _r: float) -> float:
		var env := minf(1.0, t / 0.015) * (1.0 - smoothstep(0.45, 0.55, t))
		var som := _quadrada(415.0, t) * 0.5 + _quadrada(523.0, t) * 0.4 + sin(TAU * 830.0 * t) * 0.15
		return clampf(som * env * 0.45, -1.0, 1.0)))

## Onda quadrada, o som dos aparelhos e dos jogos antigos.
static func _quadrada(freq: float, t: float) -> float:
	return 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0

## Tecla do celular: um bipe curto e agudo.
static func celular_tecla() -> AudioStreamWAV:
	return _guardar("celular_tecla", func(): return _gerar(0.05, func(t: float, _r: float) -> float:
		return _quadrada(1320.0, t) * 0.22 * (1.0 - t / 0.05)))

## Celular saindo do bolso: dois bipes subindo.
static func celular_abrir() -> AudioStreamWAV:
	return _guardar("celular_abrir", func(): return _gerar(0.16, func(t: float, _r: float) -> float:
		var freq := 880.0 if t < 0.08 else 1320.0
		return _quadrada(freq, t) * 0.2 * (1.0 if fmod(t, 0.08) < 0.06 else 0.0)))

## Celular voltando para o bolso: dois bipes descendo.
static func celular_guardar() -> AudioStreamWAV:
	return _guardar("celular_guardar", func(): return _gerar(0.16, func(t: float, _r: float) -> float:
		var freq := 1320.0 if t < 0.08 else 880.0
		return _quadrada(freq, t) * 0.2 * (1.0 if fmod(t, 0.08) < 0.06 else 0.0)))

## Mensagem chegando: bi-bip, pausa, bi-bip.
static func celular_mensagem() -> AudioStreamWAV:
	return _guardar("celular_mensagem", func(): return _gerar(0.9, func(t: float, _r: float) -> float:
		var tocando := false
		for inicio in [0.0, 0.12, 0.5, 0.62]:
			if t >= inicio and t < inicio + 0.08: tocando = true
		return _quadrada(1760.0, t) * 0.18 if tocando else 0.0))

## Celular vibrando no bolso: dois zumbidos graves.
static func celular_vibrar() -> AudioStreamWAV:
	return _guardar("celular_vibrar", func(): return _gerar(0.95, func(t: float, ruido: float) -> float:
		if not (t < 0.38 or (t > 0.55 and t < 0.93)): return 0.0
		return (sin(TAU * 150.0 * t) * 0.5 + _quadrada(75.0, t) * 0.25 + ruido * 0.1) * 0.6))

## A letra surgindo na caixa de fala: um "tic" quadrado, curtíssimo.
static func letra() -> AudioStreamWAV:
	return _guardar("letra", func(): return _gerar(0.035, func(t: float, _r: float) -> float:
		return _quadrada(620.0, t) * 0.16 * (1.0 - t / 0.035)))

## Toca um pedaço de um som (de `de` a `de + dura`), sem posição.
static func tocar_trecho(pai: Node, som: AudioStream, de: float, dura: float, volume := 0.0) -> AudioStreamPlayer:
	var jogador := AudioStreamPlayer.new()
	jogador.stream = som
	jogador.volume_db = volume
	pai.add_child(jogador)
	jogador.play(de)
	jogador.get_tree().create_timer(dura).timeout.connect(jogador.queue_free)
	return jogador

## Toca um som solto, sem posição, e some quando acaba.
static func tocar(pai: Node, som: AudioStream, volume := 0.0) -> AudioStreamPlayer:
	var jogador := AudioStreamPlayer.new()
	jogador.stream = som
	jogador.volume_db = volume
	pai.add_child(jogador)
	jogador.play()
	jogador.finished.connect(jogador.queue_free)
	return jogador

## Toca um som num ponto do mundo, e some quando acaba.
static func tocar_em(pai: Node3D, onde: Vector3, som: AudioStream, alcance := 30.0, volume := 0.0) -> AudioStreamPlayer3D:
	var jogador := AudioStreamPlayer3D.new()
	jogador.stream = som
	jogador.volume_db = volume
	jogador.max_distance = alcance
	jogador.unit_size = alcance / 4.0
	pai.add_child(jogador)
	jogador.global_position = onde
	jogador.play()
	jogador.finished.connect(jogador.queue_free)
	return jogador

## Os sons gravados, em res://sons, com o nome que aparece na mesa de som.
const GRAVADOS := [
	["Bairro de manhã", "dia_passaros_transito.ogg"], ["Trânsito no beco", "dia_beco_transito.ogg"],
	["Cidade à tarde", "tarde_cidade.ogg"], ["Anoitecer com carros", "anoitecer_carros.ogg"],
	["Noite calma", "noite_calma.ogg"],
	["Latido", "latido.ogg"], ["Cachorro grande", "cachorro_grande.ogg"], ["Cachorro pequeno", "cachorro_pequeno.ogg"],
	["Guerra ao longe", "guerra_distante.ogg"], ["Guerra perto", "guerra_perto.ogg"], ["Tiros ao longe", "guerra_tiros_longe.ogg"],
	["Rádio militar", "radio_militar.ogg"], ["Cidade destruída", "cidade_morta.ogg"],
	["Monstro à espreita", "monstro_espreita.ogg"], ["Monstro respirando", "monstro_respiracao.ogg"],
	["Monstro, assombro", "monstro_assombro.ogg"], ["Gritos ao longe", "gritos_longe.ogg"],
	["TV: chiado", "tv_chiado.ogg"], ["TV: zumbido do tubo", "tv_zumbido.ogg"],
	["TV: desligando", "tv_desligar.ogg"], ["TV: fora do ar", "tv_fora_do_ar.ogg"], ["Rádio: chiado", "radio_chiado.ogg"],
	["Grito do morador ao morrer", "grito_protagonista.ogg"], ["Grito da irmã que voltou", "grito_irma.ogg"],
]

## Todos os sons do jogo, para a mesa de som (F9).
static func todos() -> Array:
	var lista := [
		["Passo do morador", passo_jogador()], ["Motor de carro", motor_carro()], ["Pneu no asfalto", pneu()],
		["Caminhão do Exército", motor_caminhao()], ["Tanque", motor_tanque()], ["Helicóptero", helicoptero()],
		["Motor do ônibus", motor_onibus()], ["Freio a ar do ônibus", freio_onibus()],
		["Caixa registradora", compra()], ["Tiro", tiro()],
		["Caçador andando", passo_pesado()], ["Caçador correndo", passo_corrida()],
		["Bote do caçador", bote()], ["Grito do Observador", grito()],
		["Celular: tecla", celular_tecla()], ["Celular: abrir", celular_abrir()],
		["Celular: guardar", celular_guardar()], ["Celular: mensagem", celular_mensagem()],
		["Celular: vibrando", celular_vibrar()], ["Letra na fala", letra()],
		["Porta abrindo", porta_abrir()], ["Porta fechando", porta_fechar()], ["Trancar", trancar()],
		["Porta trancada forçada", porta_forcada()], ["Batidas na porta", batidas_na_porta()], ["Buzina", buzina()],
	]
	for par: Array in GRAVADOS:
		lista.append([par[0], load("res://sons/" + String(par[1]))])
	return lista

static func _guardar(chave: String, criar: Callable) -> AudioStreamWAV:
	if not _guardados.has(chave): _guardados[chave] = criar.call()
	return _guardados[chave]

## Amostra `segundos` de som; `onda(t, ruido)` devolve de −1 a 1. O ruído já
## vem passado por um filtro simples, para soar como chão e não como chiado;
## com `cru`, vem sem filtro (chiado de ar). Com `laco`, o som repete sem fim.
static func _gerar(segundos: float, onda: Callable, laco := false, cru := false) -> AudioStreamWAV:
	var quantas := int(segundos * TAXA)
	var dados := PackedByteArray()
	dados.resize(quantas * 2)
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 7
	var filtrado := 0.0
	for i in quantas:
		var t := float(i) / TAXA
		var bruto := sorte.randf_range(-1.0, 1.0)
		filtrado = lerpf(filtrado, bruto, 0.18)
		var valor := clampf(float(onda.call(t, bruto if cru else filtrado * 2.0)), -1.0, 1.0)
		# Um fade de 5 ms no fim, para não estalar (o laço já emenda sozinho).
		if not laco: valor *= minf(1.0, (quantas - i) / (TAXA * 0.005))
		dados.encode_s16(i * 2, int(valor * 32000.0))
	var som := AudioStreamWAV.new()
	som.format = AudioStreamWAV.FORMAT_16_BITS
	som.mix_rate = TAXA
	som.stereo = false
	som.data = dados
	if laco:
		som.loop_mode = AudioStreamWAV.LOOP_FORWARD
		som.loop_begin = 0
		som.loop_end = quantas
	return som
