extends SceneTree

# Ferramenta de autoria: desenha sprites/pessoas.png em pixel art.
# Mesma leitura do protagonista (vista de cima, cabeça sobre ombros, nariz à frente),
# com tronco de ombros retos em vez de oval.
# Folha: 4 quadros de caminhada (colunas) × 8 pessoas (linhas), quadros de 24 × 24,
# todas olhando para CIMA. O jogo gira o sprite na direção da caminhada.
#   godot --headless --path godot --script res://sprites/fontes/desenhar_pessoas.gd
#   godot --headless --path godot --import
const FRAME := 24
const PEOPLE := [
	# camisa, sombra da camisa, pele, cabelo, calçado
	["b0503f", "7e3a2f", "c69a6c", "2b2420", "2e3230"],
	["4f6f8f", "3a526b", "8d5f3f", "1d1a18", "3b3a36"],
	["d8cfb4", "a9a08a", "e0b48a", "6b4a2e", "5a4a3a"],
	["5c7a4e", "44603a", "a87550", "8f8a80", "2a2c2a"],
	["7a5a8a", "5a4266", "6e4a32", "141212", "3a3030"],
	["c9a042", "977630", "d6a47a", "3a2a20", "2e3230"],
	["3c4540", "2a302c", "b3825a", "b89860", "4a3c2e"],
	["e8e4d8", "b8b4a8", "8a5a3a", "2a2220", "6a3e30"],
]

var image: Image

func _initialize() -> void:
	image = Image.create_empty(FRAME * 4, FRAME * PEOPLE.size(), false, Image.FORMAT_RGBA8)
	for row in PEOPLE.size():
		for col in 4:
			draw_person(Vector2i(col * FRAME + 12, row * FRAME + 12), PEOPLE[row], [0, 1, 0, -1][col])
	assert(image.save_png(ProjectSettings.globalize_path("res://sprites/pessoas.png")) == OK)
	print("pessoas.png salvo")
	quit()

func px(p: Vector2i, color: Color) -> void:
	if Rect2i(Vector2i.ZERO, image.get_size()).has_point(p): image.set_pixelv(p, color)

func rect(c: Vector2i, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in h:
		for xx in w:
			px(c + Vector2i(x + xx, y + yy), color)

func disc(c: Vector2i, center: Vector2, radius: float, color: Color) -> void:
	for y in range(floori(center.y - radius), ceili(center.y + radius) + 1):
		for x in range(floori(center.x - radius), ceili(center.x + radius) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(center + Vector2(0.5, 0.5)) <= radius:
				px(c + Vector2i(x, y), color)

func draw_person(c: Vector2i, palette: Array, step: int) -> void:
	var shirt := Color(palette[0])
	var shirt_dark := Color(palette[1])
	var skin := Color(palette[2])
	var hair := Color(palette[3])
	var shoe := Color(palette[4])
	var outline := Color("1a1d1b")
	# Pés sob os ombros, alternando à frente e atrás.
	for side: int in [-1, 1]:
		var fy := 3 + step * side * 2
		rect(c, side * 4 - 2 + (1 if side > 0 else 0), fy, 3, 4, outline)
		rect(c, side * 4 - 1 + (1 if side > 0 else 0) - 1, fy + 1, 3, 2, shoe)
	# Braços retos saindo dos ombros; mãos balançam ao contrário dos pés.
	for side: int in [-1, 1]:
		var hy := -step * side * 2
		var hx := side * 10 - (1 if side > 0 else 0)
		rect(c, hx - 1, hy - 3, 3, 6, outline)
		rect(c, hx, hy - 2, 1, 4, shirt_dark)
		rect(c, hx - 1 + (1 if side < 0 else 0), hy + 2, 2, 2, skin)
	# Tronco de ombros retos: retângulo com cantos cortados.
	rect(c, -9, -5, 18, 10, outline)
	rect(c, -8, -4, 16, 8, shirt)
	rect(c, -8, 2, 16, 2, shirt_dark)
	for corner in [Vector2i(-9, -5), Vector2i(8, -5), Vector2i(-9, 4), Vector2i(8, 4)]:
		px(c + corner, Color(0, 0, 0, 0))
	rect(c, -7, -4, 3, 1, shirt.lightened(0.18))
	rect(c, 4, -4, 3, 1, shirt.lightened(0.18))
	# Nariz à frente, orelhas e topo da cabeça (sem rosto frontal).
	rect(c, -1, -9, 2, 2, skin)
	px(c + Vector2i(-6, -2), skin)
	px(c + Vector2i(5, -2), skin)
	disc(c, Vector2(-0.5, -2.5), 5.2, outline)
	disc(c, Vector2(-0.5, -2.5), 4.4, hair)
	disc(c, Vector2(-1.5, -3.5), 2.0, hair.lightened(0.12))
