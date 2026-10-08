class_name Mercado3D
extends Node3D

# O mercado jogável, entre a ida e a volta de ônibus. Portado do projeto do
# artefato (mercado.gd), com três mudanças:
#   - é em primeira pessoa, como o resto do jogo;
#   - por enquanto as prateleiras só vendem comida e água, que é o que o morador
#     precisa contar em casa;
#   - o preço sobe com os dias, e sobe forte.
#
# A cena, as caixas de colisão e os pontos de pegar/pagar/sair vêm de
# data/mercado3d.json, do mesmo jeito que vieram no artefato.
signal terminou

const MODELO := "res://modelos/cutscene/mercado.glb"
const DADOS := "res://data/mercado3d.json"
## Altura das caixas de colisão (paredes, gôndolas, caixas).
const TETO := 3.2
const OLHOS := 1.62
## O passo é o mesmo da rua: entrar na loja não muda o jeito de andar.
const ANDAR := 3.2
const CORRER := 5.4
## De quão perto dá para pegar o que está na prateleira.
const ALCANCE := 1.3
## O que cada item vale em casa. Só isto está à venda por enquanto.
const VALE := {
	"agua": "agua", "arroz": "comida", "feijao": "comida", "macarrao": "comida",
	"sardinha": "comida", "pao": "comida", "cafe": "comida",
	"pilhas": "energia",
	"lanterna": "lanterna",
}
## Padrão para dados antigos. Cada produto pode definir `rende` no JSON.
const RENDE := {"comida": 1, "agua": 1, "energia": 20, "lanterna": 1}
## Quanto o preço multiplica por dia que passa. Em onze dias fica quinze vezes
## mais caro: é o aperto que o jogo conta.
const CARESTIA := 1.32

## Preenchidos por quem cria a cena.
var dia := 1
var dinheiro := 80
var resolucao := Vector2(320, 213)
var camada_da_interface: Node
## O que saiu daqui, para o mundo somar ao voltar.
var comprou := {"comida": 0, "agua": 0, "energia": 0, "lanterna": 0}

var hud: Hud3D
var dica: Dica3D
var _itens := {}
var _pontos := []
var _cesta := {}
var _jogador: CharacterBody3D
var _camera: Camera3D
var _tempo := 0.0
var _lampada: Node3D
var _operadora: Skeleton3D
var _clientes: Array = []
var _freguês: Node3D
var _onde_freguês := 3.2
var _rumo_freguês := 1.0
var _olhando := 0.0

func _ready() -> void:
	var cena: Node3D = load(MODELO).instantiate()
	add_child(cena)
	RuaModelo.aplicar_ps1(cena, resolucao)
	Ceu3D.criar(self, Color("5d86c4"), Color("e8dcc0"), Color("d9d4c6"), 0.012, Vector3(0.2, 1, 0.3))
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	_itens = dados.itens
	for ponto: Dictionary in dados.spots:
		# Fora comida e água, nada está à venda por enquanto.
		if String(ponto.kind) == "item" and not VALE.has(String(ponto.key)): continue
		_pontos.append(ponto)
	var corpo := StaticBody3D.new()
	add_child(corpo)
	for c: Dictionary in dados.colliders:
		var forma := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(c.x1 - c.x0, TETO, c.z1 - c.z0)
		forma.shape = caixa
		forma.position = Vector3((c.x0 + c.x1) / 2.0, TETO / 2.0, (c.z0 + c.z1) / 2.0)
		corpo.add_child(forma)
	_lampada = cena.find_child("LampadaPisca", true, false)
	_operadora = Pose3D.esqueleto(cena.find_child("Operadora", true, false))
	for n in cena.find_children("Cliente_*", "", true, false):
		_clientes.append(Pose3D.esqueleto(n))
	# Um freguês em silhueta indo e voltando pelo corredor.
	_freguês = load("res://modelos/marquinhos_ps1.glb").instantiate()
	add_child(_freguês)
	RuaModelo.silhueta(_freguês, Color("2f2a3a"))
	var passos: AnimationPlayer = _freguês.find_child("AnimationPlayer", true, false)
	if passos:
		for nome in passos.get_animation_list():
			passos.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
		passos.play("andar")
	montar_jogador()
	var camada: Node = camada_da_interface if camada_da_interface != null else self
	hud = Hud3D.new()
	camada.add_child(hud)
	hud.virar_jogo()
	hud.linha.text = "MERCADO · MADUREIRA"
	hud.dica.text = "E: pegar · Esc: soltar o mouse"
	dica = Dica3D.new()
	camada.add_child(dica)
	contar_dinheiro()

func montar_jogador() -> void:
	_jogador = CharacterBody3D.new()
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.28
	capsula.height = 1.7
	forma.shape = capsula
	forma.position.y = 0.85
	_jogador.add_child(forma)
	add_child(_jogador)
	# Entra pela porta, de frente para o fundo da loja.
	_jogador.position = Vector3(0, 0, 9.4)
	_jogador.rotation.y = PI
	_camera = Camera3D.new()
	_camera.near = 0.05
	_camera.fov = 66.0
	_camera.position.y = OLHOS
	_jogador.add_child(_camera)
	_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## O preço de hoje: o do artefato, corrigido pelos dias que passaram.
func preco(chave: String) -> int:
	return int(round(float(_itens[chave].preco) * pow(CARESTIA, maxf(0.0, dia - 1))))

func rendimento(chave: String) -> int:
	return maxi(1, int(_itens[chave].get("rende", RENDE[VALE[chave]])))

func beneficio(chave: String) -> String:
	match String(VALE[chave]):
		"comida": return "+%d de comida" % rendimento(chave)
		"agua": return "+%d de água" % rendimento(chave)
		"energia": return "+%d de energia" % rendimento(chave)
	return "Lanterna reutilizável"

func total_da_cesta() -> int:
	var soma := 0
	for chave: String in _cesta: soma += preco(chave) * int(_cesta[chave])
	return soma

func itens_na_cesta() -> int:
	var quantos := 0
	for chave: String in _cesta: quantos += int(_cesta[chave])
	return quantos

func contar_dinheiro() -> void:
	hud.dinheiro.text = "Carteira: R$ %d · Cesta: %d (R$ %d)" % [dinheiro, itens_na_cesta(), total_da_cesta()]

## O ponto mais próximo do jogador, ou {} se não houver nenhum ao alcance.
func ponto_perto() -> Dictionary:
	var achado := {}
	var menor := ALCANCE
	for ponto: Dictionary in _pontos:
		var quanto := Vector2(float(ponto.x) - _jogador.position.x, float(ponto.z) - _jogador.position.z).length()
		if quanto < menor:
			menor = quanto
			achado = ponto
	return achado

func rotulo(ponto: Dictionary) -> String:
	match String(ponto.kind):
		"item": return "Pegar %s · R$ %d · %s" % [_itens[ponto.key].nome, preco(String(ponto.key)), beneficio(String(ponto.key))]
		"caixa": return "Pagar no caixa"
		_: return "Sair do mercado"

func usar() -> void:
	var ponto := ponto_perto()
	if ponto.is_empty(): return
	match String(ponto.kind):
		"item":
			var chave := String(ponto.key)
			var sobra := dinheiro - total_da_cesta()
			if sobra >= preco(chave):
				_cesta[chave] = int(_cesta.get(chave, 0)) + 1
				hud.avisar("Na cesta: %s · %s" % [_itens[chave].nome, beneficio(chave)])
			else:
				hud.avisar("Não dá: faltam R$ %d" % (preco(chave) - sobra))
		"caixa":
			if _cesta.is_empty():
				hud.avisar("Cesta vazia")
			else:
				var conta := total_da_cesta()
				dinheiro -= conta
				for chave: String in _cesta:
					var alvo: String = VALE[chave]
					comprou[alvo] += int(_cesta[chave]) * rendimento(chave)
				_cesta.clear()
				hud.avisar("Pago: R$ %d" % conta)
		"porta":
			if not _cesta.is_empty():
				hud.avisar("Passe no caixa antes de sair")
			else:
				sair()
				return
	contar_dinheiro()

func sair() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	terminou.emit()

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		match (evento as InputEventKey).physical_keycode:
			KEY_E, KEY_SPACE, KEY_ENTER: usar()
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif evento is InputEventMouseButton and evento.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_jogador.rotate_y(-(evento as InputEventMouseMotion).relative.x * 0.0022)
		_olhando = clampf(_olhando - (evento as InputEventMouseMotion).relative.y * 0.0022, -1.2, 1.2)
		_camera.rotation.x = _olhando

func tecla(qual: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(qual) else 0.0

func _physics_process(delta: float) -> void:
	_tempo += delta
	var frente := tecla(KEY_W) + tecla(KEY_UP) - tecla(KEY_S) - tecla(KEY_DOWN)
	var lado := tecla(KEY_D) + tecla(KEY_RIGHT) - tecla(KEY_A) - tecla(KEY_LEFT)
	var passo := (_jogador.global_basis * Vector3(lado, 0, -frente))
	passo.y = 0.0
	var velocidade := CORRER if Input.is_physical_key_pressed(KEY_SHIFT) else ANDAR
	_jogador.velocity = passo.normalized() * velocidade if passo.length() > 0.1 else Vector3.ZERO
	_jogador.move_and_slide()
	_jogador.position.y = 0.0
	var ponto := ponto_perto()
	if ponto.is_empty(): dica.esconder()
	else: dica.mostrar(rotulo(ponto))
	# A loja viva: a lâmpada falhando, a operadora passando compras, os clientes
	# olhando em volta e um freguês andando pelo corredor.
	if _lampada: _lampada.visible = sin(_tempo * 23.0) * sin(_tempo * 3.1) < 0.6
	if _operadora: Pose3D.girar(_operadora, "forearm_R", Vector3(-50 + sin(_tempo * 4.0) * 12, 0, 0))
	for i in _clientes.size():
		Pose3D.girar(_clientes[i], "head", Vector3(12 + sin(_tempo * 0.5 + i) * 4, sin(_tempo * 0.3 + i * 2.0) * 25, 0))
	_onde_freguês += _rumo_freguês * 1.4 * delta
	if _onde_freguês > 3.3:
		_onde_freguês = 3.3
		_rumo_freguês = -1.0
	if _onde_freguês < -7.0:
		_onde_freguês = -7.0
		_rumo_freguês = 1.0
	_freguês.position = Vector3(-0.8, 0, _onde_freguês)
	_freguês.rotation.y = 0.0 if _rumo_freguês > 0.0 else PI
	hud.relogio.text = "15:%02d" % ((5 + int(_tempo / 20.0)) % 60)

## A interface está pendurada fora desta cena: aqui ela é recolhida.
func _exit_tree() -> void:
	for peca in [hud, dica]:
		if peca != null and is_instance_valid(peca): peca.queue_free()
	hud = null
	dica = null
