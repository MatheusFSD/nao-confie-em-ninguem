extends SceneTree

# Ferramenta de autoria. O jogo e o mapa não dependem deste script.
# Executar manualmente recria suburbio.tres e mapa_editavel.tscn.
const DIR := "res://tilesets/suburbio/"
var catalog: Dictionary
var tiles := TileSet.new()
var lookup: Dictionary = {}
var scene := Node2D.new()
var layers: Dictionary = {}

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string(DIR + "catalogo.json"))
	tiles.tile_size = Vector2i(32, 32)
	tiles.resource_name = "Subúrbio carioca · 32 px"
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	tiles.set_physics_layer_collision_mask(0, 1)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "nome")
	tiles.set_custom_data_layer_type(0, TYPE_STRING)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(1, "categoria")
	tiles.set_custom_data_layer_type(1, TYPE_STRING)
	var terrain_names := ["Reboco verde", "Muro de cimento", "Tijolo aparente"]
	for terrain_set in range(3):
		tiles.add_terrain_set()
		tiles.set_terrain_set_mode(terrain_set, TileSet.TERRAIN_MODE_MATCH_SIDES)
		tiles.add_terrain(terrain_set)
		tiles.set_terrain_name(terrain_set, 0, terrain_names[terrain_set])
		tiles.set_terrain_color(terrain_set, 0, [Color("759174"), Color("a5ab91"), Color("b17a50")][terrain_set])
	var titles := ["01 · Pisos", "02 · Paredes e aberturas", "03 · Móveis", "04 · Quintal e rua"]
	for id in range(catalog.sources.size()):
		var source := TileSetAtlasSource.new()
		source.texture = load(DIR + catalog.sources[id] + ".png")
		source.texture_region_size = Vector2i(32, 32)
		source.resource_name = titles[id]
		tiles.add_source(source, id)
	for entry: Dictionary in catalog.tiles:
		var id: int = catalog.sources.find(entry.source)
		var source := tiles.get_source(id) as TileSetAtlasSource
		var coord := Vector2i(int(entry.atlas[0]), int(entry.atlas[1]))
		var size := Vector2i(int(entry.size[0]), int(entry.size[1]))
		assert(not source.has_tile(coord), "Tile duplicado: " + entry.name)
		source.create_tile(coord, size)
		var data := source.get_tile_data(coord, 0)
		# O clique ancora o canto superior esquerdo, inclusive em móveis grandes.
		data.texture_origin = -(size - Vector2i.ONE) * 16
		data.set_custom_data("nome", entry.name)
		data.set_custom_data("categoria", entry.source)
		for box: Array in entry.collision:
			var rect := Rect2(float(box[0]) - 16, float(box[1]) - 16, float(box[2]), float(box[3]))
			var polygon := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, data.get_collision_polygons_count(0) - 1, polygon)
		if entry.has("terrain_set"):
			data.terrain_set = int(entry.terrain_set)
			data.terrain = 0
			var neighbors := [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE]
			for bit in range(4):
				data.set_terrain_peering_bit(neighbors[bit], 0 if (int(entry.mask) & (1 << bit)) else -1)
		lookup[entry.name] = {"id": id, "coord": coord, "size": size}
	assert(ResourceSaver.save(tiles, DIR + "suburbio.tres") == OK)
	tiles.take_over_path(DIR + "suburbio.tres")
	# Atualizar a arte não deve substituir mapas que já foram editados.
	if "--tiles-only" not in OS.get_cmdline_user_args(): make_demo()
	else: scene.free()
	print("TileSet salvo: ", catalog.tiles.size(), " peças, 4 atlas e 3 terrenos de parede.")
	quit()

func make_demo() -> void:
	scene.name = "MapaEditavel"
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(scene)
	for name: String in ["Pisos", "PisosCasa", "Detalhes", "Objetos", "Paredes", "Acima"]:
		var layer := TileMapLayer.new()
		layer.name = name
		layer.tile_set = tiles
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		scene.add_child(layer)
		layer.owner = scene
		layers[name] = layer
	fill_floor(Rect2i(0, 0, 32, 26), "cimento")
	fill_floor(Rect2i(0, 0, 1, 19), "telha")
	fill_floor(Rect2i(24, 0, 8, 19), "telha")
	fill_floor(Rect2i(2, 2, 21, 16), "cimento")
	fill_floor(Rect2i(0, 19, 32, 1), "calcada")
	fill_floor(Rect2i(0, 20, 32, 4), "asfalto")
	fill_floor(Rect2i(0, 24, 32, 1), "calcada")
	fill_floor(Rect2i(0, 25, 32, 1), "telha")
	# Todas as camadas na mesma grade; a parede ocupa uma célula inteira.
	fill_floor(Rect2i(4, 7, 6, 4), "taco", "PisosCasa")
	fill_floor(Rect2i(4, 12, 6, 4), "ceramica_bege", "PisosCasa")
	fill_floor(Rect2i(11, 7, 5, 3), "azulejo_verde", "PisosCasa")
	fill_floor(Rect2i(11, 11, 5, 5), "ceramica_bege", "PisosCasa")
	# Soleiras completam o piso por baixo dos vãos.
	for p in [Vector2i(8,11),Vector2i(10,14),Vector2i(13,10),Vector2i(16,12),Vector2i(8,16),Vector2i(9,16)]:
		put("Detalhes", "soleira_v" if p.x in [10,16] else "soleira_h", p)
	var outline: Array[Vector2i] = []
	append_line(outline, Vector2i(3,6), Vector2i(16,6))
	append_line(outline, Vector2i(3,6), Vector2i(3,16))
	append_line(outline, Vector2i(16,6), Vector2i(16,16), [Vector2i(16,12)])
	append_line(outline, Vector2i(3,16), Vector2i(16,16), [Vector2i(8,16),Vector2i(9,16)])
	append_line(outline, Vector2i(10,6), Vector2i(10,16), [Vector2i(10,14)])
	append_line(outline, Vector2i(3,11), Vector2i(10,11), [Vector2i(8,11)])
	append_line(outline, Vector2i(10,10), Vector2i(16,10), [Vector2i(13,10)])
	(layers.Paredes as TileMapLayer).set_cells_terrain_connect(outline, 0, 0, false)
	var fence: Array[Vector2i] = []
	append_line(fence, Vector2i(1,1), Vector2i(23,1))
	append_line(fence, Vector2i(1,1), Vector2i(1,18))
	append_line(fence, Vector2i(23,1), Vector2i(23,18))
	append_line(fence, Vector2i(1,18), Vector2i(23,18), [Vector2i(19,18),Vector2i(20,18),Vector2i(21,18)])
	(layers.Paredes as TileMapLayer).set_cells_terrain_connect(fence, 1, 0, false)
	# Aberturas se sobrepõem à estrutura; parede continua sólida nas janelas.
	for item in [["janela_grade_h",Vector2i(5,6)],["janela_grade_h",Vector2i(6,6)],["janela_grade_v",Vector2i(3,13)],["janela_banheiro_v",Vector2i(16,8)],["janela_grade_h",Vector2i(12,16)],["porta_aberta_h",Vector2i(8,16)],["soleira_h",Vector2i(9,16)],["porta_aberta_v",Vector2i(16,12)]]:
		put("Acima",item[0],item[1])
	var objects := [
		["cama_verde",Vector2i(4,7)],["guarda_roupa",Vector2i(7,7)],["comoda",Vector2i(7,9)],
		["sofa_vertical",Vector2i(4,12)],["tv_aparador",Vector2i(8,12)],["mesa_redonda",Vector2i(6,13)],
		["radio_aparador",Vector2i(5,15)],["ventilador",Vector2i(9,15)],
		["pia_banheiro",Vector2i(11,7)],["vaso_sanitario",Vector2i(15,7)],
		["pia_bancada",Vector2i(11,11)],["fogao",Vector2i(15,11)],["geladeira",Vector2i(15,14)],
		["mesa_cozinha",Vector2i(11,13)],["cadeira_madeira",Vector2i(13,13)],["filtro_barro",Vector2i(14,11)],
		["casinha_cachorro",Vector2i(3,3)],["potes",Vector2i(5,4)],["tanque",Vector2i(20,3)],
		["cadeira_plastica",Vector2i(21,5)],["canteiro",Vector2i(3,2)],["bananeira",Vector2i(17,2)],
		["espada_sao_jorge",Vector2i(22,17)],["lixeira",Vector2i(24,19)],["poste",Vector2i(27,19)],
		["caixa_agua",Vector2i(27,4)],["tijolos_empilhados",Vector2i(20,15)]]
	for item in objects: put("Objetos",item[0],item[1])
	for item in [["varal",Vector2i(8,3)],["mangueira",Vector2i(20,6)],["tapete_croche",Vector2i(6,13)],["tapete_banheiro",Vector2i(13,9)],["capacho",Vector2i(8,17)],["rachadura_grande",Vector2i(19,11)],["bueiro",Vector2i(12,20)],["poca",Vector2i(23,20)],["papeis",Vector2i(17,20)],["mato",Vector2i(2,14)]]:
		put("Detalhes",item[0],item[1])
	put("Objetos","portao_aberto",Vector2i(22,16))
	for x in range(32):
		put("Detalhes","meio_fio_cima",Vector2i(x,20))
		put("Detalhes","meio_fio_baixo",Vector2i(x,23))
	for x in range(0,32,4):put("Acima","fios",Vector2i(x,19))
	var camera := Camera2D.new()
	camera.name = "CameraDeEdicao"
	camera.position = Vector2(512,416)
	camera.zoom = Vector2(0.76,0.76)
	scene.add_child(camera)
	camera.owner = scene
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, DIR + "mapa_editavel.tscn") == OK)
	# Base limpa para iniciar outro mapa usando o mesmo recurso.
	for layer: TileMapLayer in layers.values():
		layer.clear()
		layer.update_internals()
	camera.position = Vector2(480,320)
	camera.zoom = Vector2.ONE
	scene.name = "MapaNovo"
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, DIR + "mapa_novo.tscn") == OK)

func put(layer: String, name: String, cell: Vector2i) -> void:
	var item: Dictionary = lookup[name]
	(layers[layer] as TileMapLayer).set_cell(cell, item.id, item.coord)

func fill_floor(rect: Rect2i, prefix: String, layer: String = "Pisos") -> void:
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var noise := absi(x * 71 + y * 173 + x * y * 13)
			var variation := (noise % 2) + 1
			if noise % 23 == 0: variation = 3
			elif noise % 11 == 0: variation = 4
			put(layer, prefix + "_" + str(variation),Vector2i(x,y))

func append_line(cells: Array[Vector2i], start: Vector2i, finish: Vector2i, gaps: Array[Vector2i] = []) -> void:
	var direction := Vector2i(signi(finish.x-start.x),signi(finish.y-start.y))
	var p := start
	while true:
		if p not in cells and p not in gaps: cells.append(p)
		if p == finish: break
		p += direction
