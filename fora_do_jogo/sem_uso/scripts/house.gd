extends Node2D

# O cenário é pintado no editor em res://scenes/mapa.tscn (instanciado como "Mapa").
# Este script só lê o mapa: móveis interativos, portas, pontos de ônibus, início
# do morador e luz dos postes. Nada aqui desenha ou cria cenário.
# Nome do tile (dado "nome" do tileset) -> tipo usado pelo loop de sobrevivência.
const INTERACTIVE := {"geladeira": "fridge", "pia_bancada": "counter", "pia_banheiro": "sink", "tv_aparador": "tv", "radio_aparador": "radio", "cama_verde": "bed", "cama_terracota": "bed"}
const FLIP_H := TileSetAtlasSource.TRANSFORM_FLIP_H
const FLIP_V := TileSetAtlasSource.TRANSFORM_FLIP_V
const TRANSPOSE := TileSetAtlasSource.TRANSFORM_TRANSPOSE
const LIGHT := preload("res://scenes/luz.tscn")
var furniture: Array[Dictionary] = []
var doors: Array[Node2D] = []
var bus_stops: Array[Node2D] = []
var lamps: Array[Vector2] = []
@onready var map: Node2D = $Mapa

func _ready() -> void:
	configure_controls()
	var objects := map.get_node("Objetos") as TileMapLayer
	for cell in objects.get_used_cells():
		var data := objects.get_cell_tile_data(cell)
		var tile_name: String = data.get_custom_data("nome")
		var center := to_local(objects.to_global(objects.map_to_local(cell)))
		if tile_name == "poste":
			lamps.append(center + Vector2(0, 36))
		if not INTERACTIVE.has(tile_name) or data.get_collision_polygons_count(0) == 0:
			continue
		# Mesmo retângulo da colisão da peça (girada ou espelhada), em coordenadas da casa.
		var flags := objects.get_cell_alternative_tile(cell)
		var bounds := Rect2()
		var points := data.get_collision_polygon_points(0, 0)
		for i in points.size():
			var p := oriented(points[i], flags)
			bounds = Rect2(p, Vector2.ZERO) if i == 0 else bounds.expand(p)
		furniture.append({"kind": INTERACTIVE[tile_name], "rect": Rect2(center + bounds.position, bounds.size)})
	for node in get_tree().get_nodes_in_group("portas"):
		doors.append(node)
	for node in get_tree().get_nodes_in_group("ponto_onibus"):
		bus_stops.append(node)
	var start := map.get_node_or_null("InicioMorador") as Node2D
	if start and has_node("Morador"):
		$Morador.global_position = start.global_position
	# Cada poste pintado ganha uma luz de rua; lâmpadas da casa ficam em Mapa/Luzes.
	for center in lamps:
		var lamp := LIGHT.instantiate() as PointLight2D
		lamp.tipo = 0
		lamp.raio = 190.0
		lamp.acende_em = 0.45
		lamp.position = center
		add_child(lamp)

# Mesma ordem do Godot ao desenhar tiles girados: transpõe e depois espelha.
func oriented(point: Vector2, flags: int) -> Vector2:
	if flags & TRANSPOSE: point = Vector2(point.y, point.x)
	if flags & FLIP_H: point.x = -point.x
	if flags & FLIP_V: point.y = -point.y
	return point

func configure_controls() -> void:
	var bindings := {"walk_left": [KEY_A, KEY_LEFT], "walk_right": [KEY_D, KEY_RIGHT], "walk_up": [KEY_W, KEY_UP], "walk_down": [KEY_S, KEY_DOWN]}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
