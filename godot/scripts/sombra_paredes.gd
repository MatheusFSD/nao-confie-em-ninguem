@tool
extends TileMapLayer

# Sombra projetada das paredes: copia a camada de origem, desloca e pinta de preto
# translúcido. Atualiza sozinha no editor enquanto a camada Paredes é pintada.
# Ajuste no Inspetor: Deslocamento (direção/tamanho) e Cor (alfa = intensidade).
@export var origem: NodePath = ^"../Paredes":
	set(value):
		origem = value
		_sync()
@export var deslocamento := Vector2(4, 5):
	set(value):
		deslocamento = value
		_last_data = PackedByteArray()
		_sync()
@export var cor := Color(0, 0, 0, 0.38):
	set(value):
		cor = value
		self_modulate = value
# Peças que não projetam sombra (desenhadas no chão).
@export var ignorar: PackedStringArray = ["porta_giro"]:
	set(value):
		ignorar = value
		_sync()
var _last_data := PackedByteArray()

func _ready() -> void:
	collision_enabled = false
	navigation_enabled = false
	occlusion_enabled = false
	self_modulate = cor
	_sync()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): _sync()

func _sync() -> void:
	var source := get_node_or_null(origem) as TileMapLayer
	if source == null or not is_inside_tree(): return
	position = source.position + deslocamento
	var data := source.tile_map_data
	if data == _last_data: return
	_last_data = data
	tile_set = source.tile_set
	tile_map_data = data
	for cell in get_used_cells():
		var tile := get_cell_tile_data(cell)
		if tile and String(tile.get_custom_data("nome")) in ignorar:
			erase_cell(cell)
