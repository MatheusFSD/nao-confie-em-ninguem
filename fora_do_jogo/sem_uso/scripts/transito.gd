@tool
extends Node2D

# Carros nas duas faixas e pedestres nas duas calçadas. No editor, desenha as guias.
const Carro := preload("res://scripts/carro.gd")
const Pedestre := preload("res://scripts/pedestre.gd")
@export_group("Carros")
@export var carros_por_faixa := 3
## Faixa de cima (sentido oeste, ←) e de baixo (sentido leste, →), em y.
@export var faixa_oeste_y := 680.0:
	set(value): faixa_oeste_y = value; queue_redraw()
@export var faixa_leste_y := 736.0:
	set(value): faixa_leste_y = value; queue_redraw()
## Carros reaparecem do outro lado ao sair deste intervalo em x.
@export var carros_x := Vector2(-760, 1800):
	set(value): carros_x = value; queue_redraw()
@export_group("Pedestres")
@export var pedestres := 7
@export var calcada_casa_y := 624.0:
	set(value): calcada_casa_y = value; queue_redraw()
@export var calcada_oposta_y := 784.0:
	set(value): calcada_oposta_y = value; queue_redraw()
@export var pedestres_x := Vector2(-250, 1300):
	set(value): pedestres_x = value; queue_redraw()
var _carros: Array = []
var _pessoas: Array = []
## 1 = movimento de dia; perto de 0 = rua quase vazia. Definido pela Iluminacao.
var movimento := 1.0
const LONGE := Vector2(-20000, -20000)

func _ready() -> void:
	add_to_group("transito")
	if Engine.is_editor_hint(): return
	for faixa in 2:
		for i in carros_por_faixa:
			var carro := Carro.new()
			carro.sentido = -1.0 if faixa == 0 else 1.0
			var largura := carros_x.y - carros_x.x
			carro.position = Vector2(carros_x.x + largura * (i + randf_range(0.1, 0.6)) / carros_por_faixa, faixa_oeste_y if faixa == 0 else faixa_leste_y)
			add_child(carro)
			_carros.append(carro)
	var sequencia := range(8)
	sequencia.shuffle()
	for i in pedestres:
		var pessoa := Pedestre.new()
		pessoa.pessoa = sequencia[i % sequencia.size()]
		var casa := i % 2 == 0
		pessoa.calcada_y = calcada_casa_y if casa else calcada_oposta_y
		pessoa.lado_desvio = 1.0 if casa else -1.0
		pessoa.x_min = pedestres_x.x
		pessoa.x_max = pedestres_x.y
		pessoa.sentido = [-1.0, 1.0].pick_random()
		pessoa.velocidade = randf_range(30, 48)
		pessoa.position = _lugar_livre(pessoa.calcada_y)
		add_child(pessoa)
		_pessoas.append(pessoa)

## Quantos carros (por faixa) e pedestres continuam na rua. Quem sobra sai de cena
## sem sumir na frente do jogador: carros ao deixar a rua, pedestres desaparecendo aos poucos.
func definir_movimento(valor: float) -> void:
	movimento = clampf(valor, 0.0, 1.0)

func _carro_ativo(indice: int) -> bool:
	var na_faixa := indice % maxi(carros_por_faixa, 1)
	return na_faixa < maxi(1, ceili(carros_por_faixa * movimento))

func _pessoa_ativa(indice: int) -> bool:
	return indice < maxi(1, ceili(pedestres * movimento))

func _guardar(corpo: Node2D) -> void:
	corpo.visible = false
	corpo.process_mode = Node.PROCESS_MODE_DISABLED
	corpo.position = LONGE
	corpo.set_meta("guardado", true)

func _trazer(corpo: Node2D, posicao: Vector2) -> void:
	corpo.position = posicao
	corpo.modulate.a = 1.0
	corpo.visible = true
	corpo.process_mode = Node.PROCESS_MODE_INHERIT
	corpo.set_meta("guardado", false)

func _lugar_livre(y: float) -> Vector2:
	var consulta := PhysicsPointQueryParameters2D.new()
	for tentativa in 30:
		var p := Vector2(randf_range(pedestres_x.x, pedestres_x.y), y)
		consulta.position = p
		if get_world_2d().direct_space_state.intersect_point(consulta, 1).is_empty():
			return p
	return Vector2(pedestres_x.x, y)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	_carros = _carros.filter(func(c): return is_instance_valid(c))
	_pessoas = _pessoas.filter(func(p): return is_instance_valid(p))
	for i in _carros.size():
		var carro = _carros[i]
		var inicio: float = carros_x.x if carro.sentido > 0 else carros_x.y
		var y: float = faixa_oeste_y if carro.sentido < 0 else faixa_leste_y
		if carro.get_meta("guardado", false):
			if _carro_ativo(i):
				_trazer(carro, Vector2(inicio, y))
				carro.sortear()
			continue
		var saiu: bool = carro.position.x > carros_x.y if carro.sentido > 0 else carro.position.x < carros_x.x
		if saiu:
			if _carro_ativo(i):
				carro.position.x = inicio
				carro.sortear()
			else:
				_guardar(carro)
	for i in _pessoas.size():
		var pessoa = _pessoas[i]
		if pessoa.get_meta("guardado", false):
			if _pessoa_ativa(i):
				_trazer(pessoa, Vector2(pedestres_x.x if randf() < 0.5 else pedestres_x.y, pessoa.calcada_y))
			continue
		if not _pessoa_ativa(i) and not pessoa.get_meta("saindo", false):
			# Vai para casa: some aos poucos.
			pessoa.set_meta("saindo", true)
			var tween := create_tween()
			tween.tween_property(pessoa, "modulate:a", 0.0, 1.5)
			tween.tween_callback(_terminar_saida.bind(pessoa))

func _terminar_saida(pessoa: Node2D) -> void:
	pessoa.set_meta("saindo", false)
	if _pessoa_ativa(_pessoas.find(pessoa)): pessoa.modulate.a = 1.0
	else: _guardar(pessoa)

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	var guia := Color(0.3, 0.8, 1.0, 0.7)
	for y in [faixa_oeste_y, faixa_leste_y]:
		draw_dashed_line(Vector2(carros_x.x, y), Vector2(carros_x.y, y), guia, 2, 12)
	for y in [calcada_casa_y, calcada_oposta_y]:
		draw_dashed_line(Vector2(pedestres_x.x, y), Vector2(pedestres_x.y, y), Color(1, 0.8, 0.3, 0.8), 2, 6)
	draw_string(ThemeDB.fallback_font, Vector2(carros_x.x + 8, faixa_oeste_y - 6), "Carros ←", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, guia)
	draw_string(ThemeDB.fallback_font, Vector2(carros_x.x + 8, faixa_leste_y - 6), "Carros →", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, guia)
	draw_string(ThemeDB.fallback_font, Vector2(pedestres_x.x + 8, calcada_casa_y - 6), "Pedestres", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.8, 0.3))
