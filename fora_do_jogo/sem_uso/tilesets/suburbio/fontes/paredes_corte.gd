extends SceneTree

# Ferramenta de autoria das paredes em corte (grade de 16 px, meio tile).
# Etapa 1: godot --headless --path godot --script res://tilesets/suburbio/fontes/paredes_corte.gd -- --png
# Etapa 2: godot --headless --path godot --import
# Etapa 3: godot --headless --path godot --script res://tilesets/suburbio/fontes/paredes_corte.gd -- --tres
# Recriar sobrescreve paredes_corte.png e paredes_corte.tres; os mapas não são alterados.
const DIR := "res://tilesets/suburbio/"
const CELL := 16
const BLACK := Color("0c0d0c")
const LINE := Color("1b1e1c")
const GLASS := Color("aab5ad")
# nome, coordenada no atlas, tamanho em células, tem colisão
const PIECES := [
	["parede", Vector2i(0, 0), Vector2i(1, 1), true],
	["janela_h", Vector2i(1, 0), Vector2i(2, 1), true],
	["janela_v", Vector2i(3, 0), Vector2i(1, 2), true],
	["porta_giro", Vector2i(4, 0), Vector2i(2, 2), false],
]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--png" in args: draw_png()
	if "--tres" in args: build_tileset()
	quit()

func draw_png() -> void:
	var image := Image.create_empty(8 * CELL, 4 * CELL, false, Image.FORMAT_RGBA8)
	# Parede cortada: preenchimento preto chapado, sem contorno, para emendar sem costura.
	image.fill_rect(Rect2i(0, 0, CELL, CELL), BLACK)
	# Janela: batentes pretos, peitoril claro e duas linhas de caixilho.
	var h := Rect2i(CELL, 0, 2 * CELL, CELL)
	image.fill_rect(h, BLACK)
	image.fill_rect(h.grow(-1), GLASS)
	image.fill_rect(Rect2i(h.position.x + 1, 5, h.size.x - 2, 1), LINE)
	image.fill_rect(Rect2i(h.position.x + 1, 10, h.size.x - 2, 1), LINE)
	var v := Rect2i(3 * CELL, 0, CELL, 2 * CELL)
	image.fill_rect(v, BLACK)
	image.fill_rect(v.grow(-1), GLASS)
	image.fill_rect(Rect2i(v.position.x + 5, 1, 1, v.size.y - 2), LINE)
	image.fill_rect(Rect2i(v.position.x + 10, 1, 1, v.size.y - 2), LINE)
	# Porta: folha aberta na borda esquerda e arco de giro até o batente oposto.
	# O vão fica na borda de baixo da peça; gire com Z/X no editor para outras direções.
	var origin := Vector2i(4 * CELL, 0)
	image.fill_rect(Rect2i(origin.x, origin.y, 2, 2 * CELL), BLACK)
	for step in range(0, 181):
		var angle := deg_to_rad(step * 0.5)
		var p := Vector2(0, 31) + Vector2(sin(angle), -cos(angle)) * 30.5
		image.set_pixelv(origin + Vector2i(roundi(p.x), roundi(p.y)).clamp(Vector2i.ZERO, Vector2i(31, 31)), LINE)
	assert(image.save_png(ProjectSettings.globalize_path(DIR + "paredes_corte.png")) == OK)
	print("paredes_corte.png salvo")

func build_tileset() -> void:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(CELL, CELL)
	tiles.resource_name = "Paredes em corte · 16 px"
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	tiles.set_physics_layer_collision_mask(0, 1)
	# Paredes bloqueiam a luz das lâmpadas e postes; janelas deixam passar.
	tiles.add_occlusion_layer()
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "nome")
	tiles.set_custom_data_layer_type(0, TYPE_STRING)
	var source := TileSetAtlasSource.new()
	source.texture = load(DIR + "paredes_corte.png")
	source.texture_region_size = Vector2i(CELL, CELL)
	source.resource_name = "Paredes em corte"
	tiles.add_source(source, 0)
	for piece: Array in PIECES:
		var coord: Vector2i = piece[1]
		var size: Vector2i = piece[2]
		source.create_tile(coord, size)
		var data := source.get_tile_data(coord, 0)
		data.texture_origin = -(size - Vector2i.ONE) * CELL / 2
		data.set_custom_data("nome", piece[0])
		if piece[3]:
			var half := Vector2(CELL, CELL) / 2
			var rect := Rect2(-half, Vector2(size * CELL))
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
		if piece[0] == "parede":
			var occluder := OccluderPolygon2D.new()
			occluder.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
			data.add_occluder_polygon(0)
			data.set_occluder_polygon(0, 0, occluder)
	assert(ResourceSaver.save(tiles, DIR + "paredes_corte.tres") == OK)
	print("paredes_corte.tres salvo")
