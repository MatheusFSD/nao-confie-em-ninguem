class_name Onibus3D
extends Node3D

# A viagem de ônibus, portada do projeto do artefato (cutscene_onibus.gd).
#
# O ônibus não anda: ele fica parado e a cidade passa por trás. Tudo que tem
# nome começando por `Mover_` corre para trás e volta pelo outro lado, e o
# número no nome é a velocidade (×100) — morro vai devagar, carro na contramão
# vai rápido. Em cima disso entram o chacoalho da carroceria, os passageiros
# balançando junto e quatro cortes de câmera de seis segundos.
signal terminou

const VELOCIDADE := 11.5
## Comprimento do trecho que dá a volta.
const TRECHO := 340.0
## Quanto dura cada corte de câmera.
const CORTE := 6.0

## Preenchido por quem cria a cena, antes de ela entrar na árvore.
var receita: Dictionary
var resolucao := Vector2(320, 213)
## Onde pendurar a interface: fora da tela pequena, para o texto sair nítido.
var camada_da_interface: Node
var hud: Hud3D
var _tempo := 0.0
var _camera: Camera3D
var _carroceria: Node3D
var _passando: Array = []
var _rodas: Array = []
var _gente: Array = []
var _protagonista: Skeleton3D
var _sacolas: Array = []

func _ready() -> void:
	var cena: Node3D = load(receita.glb).instantiate()
	add_child(cena)
	# Sem o conserto de faces coladas: estes modelos são grandes e passam em
	# seis segundos de câmera, longe demais para valer o custo.
	RuaModelo.aplicar_ps1(cena, resolucao)
	Ceu3D.criar(self, receita.ceu_topo, receita.ceu_horizonte, receita.neblina, receita.densidade, receita.luz)
	_carroceria = cena.find_child("Carroceria", true, false)
	for no in cena.find_children("Mover_*", "", true, false):
		_passando.append([no, float(String(no.name).split("_")[1]) / 100.0])
	for no in cena.find_children("Roda_*", "", true, false):
		_rodas.append(no)
	for no in cena.find_children("Sentado_*", "", true, false):
		_gente.append([Pose3D.esqueleto(no), true, randf() * TAU])
	for no in cena.find_children("EmPe_*", "", true, false):
		_gente.append([Pose3D.esqueleto(no), false, randf() * TAU])
	_protagonista = Pose3D.esqueleto(cena.find_child("Protagonista", true, false))
	for i in 3:
		var sacola := cena.find_child("Sacola_%d" % i, true, false)
		if sacola:
			sacola.visible = i < int(receita.get("sacolas", 0))
			_sacolas.append(sacola)
	_camera = Camera3D.new()
	_camera.near = 0.1
	_camera.far = 900.0
	add_child(_camera)
	_camera.make_current()
	hud = Hud3D.new()
	(camada_da_interface if camada_da_interface != null else self).add_child(hud)
	hud.linha.text = receita.linha
	hud.dica.text = "Enter: pular"

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_accept"): terminou.emit()

func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= CORTE * 4:
		set_process(false)
		terminou.emit()
		return
	var rumo: float = receita.dir
	for peca: Array in _passando:
		var no: Node3D = peca[0]
		no.position.x -= rumo * VELOCIDADE * float(peca[1]) * delta
		if no.position.x < -TRECHO / 2.0: no.position.x += TRECHO
		if no.position.x > TRECHO / 2.0: no.position.x -= TRECHO
	for roda: Node3D in _rodas:
		roda.rotate_object_local(Vector3.UP, -VELOCIDADE / 0.5 * delta)
	# Buraco, lombada e o balanço lento da suspensão.
	var solavanco := sin(_tempo * 9.1) * 0.012 + pow(maxf(0.0, sin(_tempo * 1.7)), 12) * 0.05
	var balanco := sin(_tempo * 0.9) * 0.012 + sin(_tempo * 2.3) * 0.004
	_carroceria.position.y = solavanco
	_carroceria.rotation = Vector3(balanco, 0, sin(_tempo * 1.1) * 0.006)
	for p: Array in _gente:
		var gingado: float = -balanco * 57.0 + sin(_tempo * 1.3 + float(p[2])) * 1.5
		if p[1]:
			Pose3D.girar(p[0], "spine", Vector3(4, 0, gingado * 0.6))
		else:
			Pose3D.girar(p[0], "hips", Vector3(0, 0, gingado))
			Pose3D.girar(p[0], "spine", Vector3(0, 0, -gingado * 0.4))
	if bool(receita.get("cansado", false)):
		# Na volta ele vem derrubado, com a cabeça pendendo para a janela.
		Pose3D.girar(_protagonista, "head", Vector3(10 + solavanco * 160, -24 + sin(_tempo * 0.2) * 4, 16 - balanco * 30))
		Pose3D.girar(_protagonista, "spine", Vector3(10, 0, 4 - balanco * 50))
	else:
		var olhar := -38 + sin(_tempo * 0.35) * 14 + (28.0 if sin(_tempo * 0.13) > 0.8 else 0.0)
		Pose3D.girar(_protagonista, "head", Vector3(4 + solavanco * 120, olhar, -balanco * 40))
		Pose3D.girar(_protagonista, "spine", Vector3(4, 0, -balanco * 50))
	for i in _sacolas.size():
		_sacolas[i].rotation.z = -balanco * 2.0 + sin(_tempo * 3.0 + i) * 0.03
	var tomadas: Array = receita.tomadas
	var tomada: Dictionary = tomadas[int(_tempo / CORTE) % tomadas.size()]
	var t := fmod(_tempo, CORTE)
	var de: Vector3 = tomada.de.call(t)
	var para: Vector3 = tomada.para.call(t)
	# Tomada de dentro do ônibus anda junto com a carroceria.
	if not tomada.mundo:
		de = _carroceria.to_global(de) + Vector3(0, sin(_tempo * 6.3) * 0.006, 0)
		para = _carroceria.to_global(para)
	_camera.fov = 50.0 if tomada.mundo else 62.0
	_camera.look_at_from_position(de, para, Vector3.UP)
	hud.tomada.text = tomada.nome
	hud.relogio.text = "%s:%02d" % [receita.hora, (int(receita.minuto) + int(_tempo / 10.0)) % 60]

## A interface está pendurada fora desta cena, então ela não some junto: aqui
## ela é recolhida quando a cena sai.
func _exit_tree() -> void:
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
		hud = null
