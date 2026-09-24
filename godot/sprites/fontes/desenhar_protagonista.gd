extends SceneTree

# Ferramenta de autoria: desenha os sprites de topo dos personagens com nome.
#   sprites/protagonista.png — o morador
#   sprites/irma.png         — a irmã (cores do retrato em ui/personagens/irma.webp)
# Folha: 4 quadros de caminhada (colunas) × 8 direções (linhas), quadros de 32 × 32 px.
# Linha 0 olha para cima; cada linha seguinte gira 45° no sentido horário
# (cima, cima-direita, direita, baixo-direita, baixo, baixo-esquerda, esquerda, cima-esquerda).
# Cada direção é rasterizada separadamente, sem girar pixels, para manter o traço limpo.
#   godot --headless --path godot --script res://sprites/fontes/desenhar_protagonista.gd
#   godot --headless --path godot --import
const FRAME := 32
const STEPS := [0.0, 3.2, 0.0, -3.2]
const OUTLINE := Color("141a18")
const PERSONAGENS := {
	"protagonista": {
		"sapato": "373e38", "calcanhar": "ae855d", "manga": "6f5238", "mao": "c29a6c",
		"corpo": "987b57", "borda": "5e4a34", "cinto": "745f45", "ombro": "b59b6e",
		"nariz": "b38a60", "orelha": "aa7c53", "cabelo": "222c29", "cabelo_claro": "303a30",
		"brilho": "414738", "coque": 0.0,
	},
	"irma": {
		# Jaqueta preta, top branco, pele e cabelo do retrato, com coque atrás.
		"sapato": "2b2a28", "calcanhar": "8a5a3a", "manga": "1e1c1b", "mao": "c98a58",
		"corpo": "23211f", "borda": "0f0e0e", "cinto": "e9e6dd", "ombro": "3a3634",
		"nariz": "c98a58", "orelha": "b87c4c", "cabelo": "241d19", "cabelo_claro": "33291f",
		"brilho": "4a3a2c", "coque": 3.4,
	},
}

var paleta: Dictionary = {}

func _initialize() -> void:
	for nome: String in PERSONAGENS:
		paleta = PERSONAGENS[nome]
		desenhar(nome)
	quit()

func desenhar(nome: String) -> void:
	var image := Image.create_empty(FRAME * STEPS.size(), FRAME * 8, false, Image.FORMAT_RGBA8)
	for direction in 8:
		for col in STEPS.size():
			var frame := Image.create_empty(FRAME, FRAME, false, Image.FORMAT_RGBA8)
			var angle := direction * PI / 4
			for y in FRAME:
				for x in FRAME:
					var local := (Vector2(x + 0.5, y + 0.5) - Vector2(FRAME, FRAME) / 2).rotated(-angle)
					var color := sample(local, STEPS[col])
					if color.a > 0: frame.set_pixel(x, y, color)
			outline(frame)
			image.blit_rect(frame, Rect2i(0, 0, FRAME, FRAME), Vector2i(col * FRAME, direction * FRAME))
	assert(image.save_png(ProjectSettings.globalize_path("res://sprites/%s.png" % nome)) == OK)
	print(nome, ".png salvo")

func cor(chave: String) -> Color:
	return Color(paleta[chave])

# Formas vistas de cima, pintadas de trás para frente.
func sample(p: Vector2, step: float) -> Color:
	var color := Color(0, 0, 0, 0)
	for side: float in [-1.0, 1.0]:
		var foot := Vector2(side * 4, 3 + step * side)
		if segment(p, foot, foot + Vector2(0, 3), 2.0): color = cor("sapato")
		if segment(p, foot + Vector2(0, 1), foot + Vector2(0, 3), 1.5): color = cor("calcanhar")
		var hand := Vector2(side * 10, step * side * 0.7)
		if segment(p, Vector2(side * 7, -1), hand, 2.0): color = cor("manga")
		if p.distance_to(hand) <= 2.1: color = cor("mao")
	var torso := PackedVector2Array([Vector2(-10, -3), Vector2(-7, -6), Vector2(7, -6), Vector2(10, -3), Vector2(8, 4), Vector2(3, 6), Vector2(-4, 6), Vector2(-8, 4)])
	if Geometry2D.is_point_in_polygon(p, torso):
		color = cor("corpo")
		# Borda escura do casaco separa tronco e braços.
		for offset: Vector2 in [Vector2(1.1, 0), Vector2(-1.1, 0), Vector2(0, 1.1), Vector2(0, -1.1)]:
			if not Geometry2D.is_point_in_polygon(p + offset, torso): color = cor("borda")
	if segment(p, Vector2(-8, 2), Vector2(7, 3), 1.0): color = cor("cinto")
	if segment(p, Vector2(-8, -4), Vector2(-5, -5), 1.0) or segment(p, Vector2(5, -5), Vector2(8, -4), 1.0): color = cor("ombro")
	if p.distance_to(Vector2(0, -7)) <= 2.1: color = cor("nariz")
	if p.distance_to(Vector2(-5.3, -2)) <= 1.5 or p.distance_to(Vector2(5.3, -2)) <= 1.5: color = cor("orelha")
	var coque: float = paleta.get("coque", 0.0)
	if coque > 0.0 and p.distance_to(Vector2(0, 2.5)) <= coque: color = cor("cabelo")
	if p.distance_to(Vector2(0, -2)) <= 5.7: color = cor("cabelo")
	if p.distance_to(Vector2(-1, -3)) <= 4.4: color = cor("cabelo_claro")
	if p.distance_to(Vector2(-2, -4)) <= 1.6: color = cor("brilho")
	return color

func segment(p: Vector2, a: Vector2, b: Vector2, radius: float) -> bool:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= radius

func outline(frame: Image) -> void:
	var source := frame.duplicate() as Image
	for y in FRAME:
		for x in FRAME:
			if source.get_pixel(x, y).a > 0: continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < FRAME and n.y < FRAME and source.get_pixelv(n).a > 0:
					frame.set_pixel(x, y, OUTLINE)
					break
