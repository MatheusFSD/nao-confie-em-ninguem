extends CharacterBody2D

const PACE := 29.0
var route := PackedVector2Array([Vector2(420, 150), Vector2(580, 160), Vector2(590, 360), Vector2(600, 520), Vector2(656, 560), Vector2(590, 400), Vector2(570, 165), Vector2(330, 150)])
var waypoint := 0
var pause := 2.5
var stride := 0.0
var elapsed := 0.0
var facing_angle := 0.0

func _ready() -> void:
	# Rota editável no mapa: marcadores filhos de Mapa/RotaCachorro, em ordem.
	var markers := get_node_or_null("../Mapa/RotaCachorro")
	if markers and markers.get_child_count() > 0:
		route = PackedVector2Array()
		for marker: Node2D in markers.get_children():
			route.append(get_parent().to_local(marker.global_position))
		position = route[route.size() - 1]
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8
	collider.shape = shape
	add_child(collider)
	collision_layer = 2
	collision_mask = 1
	z_index = 5

func _physics_process(delta: float) -> void:
	elapsed += delta
	if pause > 0:
		pause -= delta
		velocity = Vector2.ZERO
		if waypoint == 5 or waypoint == 0:
			facing_angle = lerp_angle(facing_angle, PI, delta * 2.0)
	else:
		var direction := route[waypoint] - position
		if direction.length() < 5:
			waypoint = (waypoint + 1) % route.size()
			pause = 3.0 if waypoint != 5 else 6.0
			velocity = Vector2.ZERO
		else:
			velocity = direction.normalized() * PACE
			facing_angle = lerp_angle(facing_angle, direction.angle() + PI / 2, delta * 5.0)
			stride += delta * 9
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(3, 3), facing_angle, Vector2(0.8, 1.25))
	draw_circle(Vector2.ZERO, 10, Color(0.02, 0.04, 0.03, 0.25))
	draw_set_transform(Vector2.ZERO, facing_angle)
	var step := sin(stride) * 2.0 if velocity.length() > 0 else 0.0
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 5, -5), Vector2(side * 7, -4 + side * step), Color("b78b53"), 3)
		draw_line(Vector2(side * 5, 7), Vector2(side * 7, 9 - side * step), Color("b78b53"), 3)
	draw_polyline(PackedVector2Array([Vector2(0, 10), Vector2(1, 16), Vector2(4 + sin(elapsed * 4) * 2, 18)]), Color("bc8d4e"), 3)
	draw_set_transform(Vector2.ZERO, facing_angle, Vector2(0.72, 1.2))
	draw_circle(Vector2.ZERO, 9, Color("a77742"))
	draw_set_transform(Vector2.ZERO, facing_angle)
	draw_line(Vector2(-1, -5), Vector2(-1, 7), Color("be955b"), 4)
	draw_line(Vector2(-5, -7), Vector2(5, -7), Color("546e61"), 2)
	draw_circle(Vector2(0, -11), 6, Color("c2985d"))
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -15), Vector2(-8, -11), Vector2(-5, -7)]), Color("725335"))
	draw_colored_polygon(PackedVector2Array([Vector2(4, -15), Vector2(8, -11), Vector2(5, -7)]), Color("725335"))
	draw_line(Vector2(0, -14), Vector2(0, -18), Color("ae834e"), 5)
	draw_circle(Vector2(0, -18), 2, Color("333b2e"))
	draw_set_transform(Vector2.ZERO)
