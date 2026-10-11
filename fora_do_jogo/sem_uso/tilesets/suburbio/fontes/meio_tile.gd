extends SceneTree

# Ferramenta de autoria: tiles alternativos "meio tile" para os móveis.
# As paredes em corte têm 16 px e às vezes terminam no meio de uma célula de 32 px;
# as alternativas deslocam desenho e colisão 16 px para o móvel encostar nelas.
# Rode depois de montar_recursos.gd (que recria suburbio.tres sem alternativas):
#   godot --headless --path godot --script res://tilesets/suburbio/fontes/meio_tile.gd
const TRES := "res://tilesets/suburbio/suburbio.tres"
# Ordem das alternativas no painel TileMap (ID 1 a 8).
const SHIFTS := [Vector2i(-16, 0), Vector2i(16, 0), Vector2i(0, -16), Vector2i(0, 16), Vector2i(-16, -16), Vector2i(16, -16), Vector2i(-16, 16), Vector2i(16, 16)]
const SOURCES := [2, 3] # moveis, quintal_rua

func _initialize() -> void:
	var tiles := load(TRES) as TileSet
	var created := 0
	for source_id in SOURCES:
		var source := tiles.get_source(source_id) as TileSetAtlasSource
		for i in source.get_tiles_count():
			var coord := source.get_tile_id(i)
			for alt_index in range(source.get_alternative_tiles_count(coord) - 1, 0, -1):
				source.remove_alternative_tile(coord, source.get_alternative_tile_id(coord, alt_index))
			var base := source.get_tile_data(coord, 0)
			for shift: Vector2i in SHIFTS:
				var alt := source.create_alternative_tile(coord)
				var data := source.get_tile_data(coord, alt)
				# O desenho fica em (centro da célula - texture_origin); a colisão não usa a origem.
				data.texture_origin = base.texture_origin - shift
				data.z_index = base.z_index
				data.set_custom_data("nome", base.get_custom_data("nome"))
				data.set_custom_data("categoria", base.get_custom_data("categoria"))
				for p in base.get_collision_polygons_count(0):
					var points := base.get_collision_polygon_points(0, p)
					for k in points.size():
						points[k] += Vector2(shift)
					data.add_collision_polygon(0)
					data.set_collision_polygon_points(0, p, points)
				created += 1
	assert(ResourceSaver.save(tiles, TRES) == OK)
	print("Alternativas meio tile: ", created)
	quit()
