extends Node2D

# Junções compartilham uma superfície. Sombras opacas são desenhadas
# antes de TODOS os topos, sem acumular transparência nas interseções.
const CELL := 8
var cells: Dictionary = {}
var windows: Array[Rect2] = []
var plaster := Color("59695b")
var shadow := Color("303d35")

func build(rectangles: Array[Rect2], color: Color, shadow_color: Color) -> void:
	plaster = color
	shadow = shadow_color
	for rect in rectangles:
		for y in range(int(rect.position.y), int(rect.end.y), CELL):
			for x in range(int(rect.position.x), int(rect.end.x), CELL):
				cells[Vector2i(x / CELL, y / CELL)] = true
	z_index = 12
	queue_redraw()

func _draw() -> void:
	for cell: Vector2i in cells:
		draw_rect(Rect2(Vector2(cell * CELL) + Vector2(5, 7), Vector2(CELL, CELL)), shadow)
	for cell: Vector2i in cells:
		draw_rect(Rect2(Vector2(cell * CELL), Vector2(CELL, CELL)), plaster)
	for cell: Vector2i in cells:
		var p := Vector2(cell * CELL)
		# Apenas contornos expostos, nunca bordas entre segmentos.
		if not cells.has(cell + Vector2i.UP):
			draw_rect(Rect2(p, Vector2(CELL, 2)), plaster.lightened(0.15))
		if not cells.has(cell + Vector2i.LEFT):
			draw_rect(Rect2(p, Vector2(2, CELL)), plaster.lightened(0.07))
		if not cells.has(cell + Vector2i.DOWN):
			draw_rect(Rect2(p + Vector2(0, CELL - 2), Vector2(CELL, 2)), plaster.darkened(0.4))
		if not cells.has(cell + Vector2i.RIGHT):
			draw_rect(Rect2(p + Vector2(CELL - 2, 0), Vector2(2, CELL)), plaster.darkened(0.28))
	for window in windows:
		draw_rect(window.grow(-2), Color("233f38"))
		draw_rect(window.grow(-2), Color("939c82"), false, 1)
		if window.size.x > window.size.y:
			for x in range(int(window.position.x) + 4, int(window.end.x) - 2, 7):
				draw_line(Vector2(x, window.position.y + 2), Vector2(x, window.end.y - 2), Color("7c8974"), 1)
		else:
			for y in range(int(window.position.y) + 4, int(window.end.y) - 2, 7):
				draw_line(Vector2(window.position.x + 2, y), Vector2(window.end.x - 2, y), Color("7c8974"), 1)
