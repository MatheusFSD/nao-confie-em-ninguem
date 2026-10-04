extends Node3D
## A Coisa no horizonte: criatura de 8 pernas atrás da cidade em chamas, atacada por 3 helicópteros.
## Tudo é procedural (como na visualização): pernas com IK de dois ossos, tentáculos, olhos piscando,
## circuito dos helicópteros, traçantes, foguetes, fumaça, explosões e fogo.
## Teclas 1, 2 e 3 trocam a câmera (fundo da cidade, perto, no helicóptero).

@export_enum("fundo", "perto", "heli") var camera_modo := "fundo"
@export var aplicar_ps1 := true
@export var numero_de_helicopteros := 3
@export var quadros_por_segundo := 15.0
## Ligado, a cena entra como peça de outro cenário: sem câmera, sem céu, sem
## luz e sem teclas próprias — quem manda nessas coisas é o mundo que a recebe.
@export var so_a_criatura := false

const CY := 96.0
const PERNA_D := [119.803, 114.266, 118.025, 117.689, 105.853, 113.355, 118.501, 117.841]
const PERNA_A := [0.3927, 1.1781, 1.9635, 2.74889, 3.53429, 4.31969, 5.10509, 5.89049]
const TENT_A := [0, 0.8976, 1.7952, 2.69279, 3.59039, 4.48799, 5.38559]
const OLHOS := [[3.2, 3.972, 0.446, 0, 102, 23.5], [2.4, 5.728, 5.767, -6, 100, 22.42], [2.6, 5.983, 8.617, 6, 99, 22.42], [1.8, 5.885, 6.609, -3, 95, 22.96], [2, 7.481, 7.622, 4, 94, 22.78], [1.4, 4.451, 7.034, -9, 93, 21.88], [1.5, 4.073, 8.648, 9, 92, 21.88], [1.6, 6.323, 6.633, 0, 108, 22.6], [1.2, 5.706, 8.296, -4, 106, 22.18], [1.3, 7.289, 5.833, 5, 105, 22.15]]          # [raio, ritmo da piscada, fase, x, y, z]
const FOGOS := [[63.79, 3.3, -123.58, 7.34, 3.48], [87.08, 8.81, -162.88, 19.57, 7.12], [-39.28, 2.73, -32.15, 6.07, 2.556], [-10.2, 3.2, -134.6, 7.11, 4.812], [125.55, 5.14, -227.98, 11.43, 6.582], [142.08, 6.25, -142.94, 13.88, 1.498], [-12.02, 6.99, -38.74, 15.53, 2.907], [13.03, 4.28, -162.57, 9.5, 5.636], [96.73, 3.33, -103.68, 7.41, 9.767], [20.48, 4.45, -59.84, 9.89, 2.099], [-6.77, 4.25, -263.7, 9.44, 4.841], [121.37, 3.98, -262.59, 8.85, 7.752], [241.24, 7.35, -200.04, 16.32, 0.77], [44.54, 6.81, -67.95, 15.12, 1.3], [-7.98, 8.75, -48.37, 19.45, 5.748], [-138.87, 3.25, -144.76, 7.23, 8.23], [53.17, 5.81, -192.18, 12.91, 8.628], [26.5, 4.63, -127.78, 10.28, 0.554], [-66.56, 7.83, -95.94, 17.4, 6.786], [182.55, 6.14, -172.49, 13.63, 6.014], [142.32, 3.52, -121.95, 7.83, 9.293], [-33.55, 7.81, -27.17, 17.36, 3.361]]          # [x, y, z, tamanho, fase]
const HELI_CENA := preload("res://monstro/helicoptero.glb")

var t := 0.0
var acc := 0.0
var impacto := 0.0
var criatura: Node3D
var corpo: Node3D
var segs := {}
var olhos := []
var helis := []
var fogos := []
var tiros := []
var fumacas := []
var explosoes := []
var i_tiro := 0
var i_fum := 0
var i_exp := 0
var cam: Camera3D
var env: Environment
var yaw := 0.6
var pitch := 0.18
var arrastando := false
var tex_halo: GradientTexture2D
var tex_fogo: GradientTexture2D
var tex_fumaca: GradientTexture2D

func _ready() -> void:
	criatura = $Criatura
	corpo = $Criatura/Corpo
	for n in $Criatura/Segmentos.find_children("*", "MeshInstance3D", true, false): segs[String(n.name)] = n
	if aplicar_ps1: PS1Util.aplicar(self)
	tex_halo = _gradiente([Color(1, 0.9, 0.47, 1), Color(1, 0.78, 0.24, 0.45), Color(1, 0.63, 0, 0)])
	tex_fogo = _gradiente([Color(1, 0.86, 0.55, 1), Color(1, 0.47, 0.16, 0.7), Color(0.47, 0.08, 0, 0)])
	tex_fumaca = _gradiente([Color(0.67, 0.63, 0.59, 0.8), Color(0.47, 0.43, 0.39, 0.3), Color(0.47, 0.43, 0.39, 0)])
	if not so_a_criatura: _ambiente()
	_olhos()
	for f in FOGOS:
		var q := _quad(tex_fogo, Color(1, 1, 1, 1), Vector2(f[3], f[3] * 1.3)); q.position = Vector3(f[0], f[1], f[2]); add_child(q)
		fogos.append({"n": q, "k": f[3], "f": f[4]})
	for i in numero_de_helicopteros: _helicoptero(i)
	for i in 90: tiros.append({"n": _pool(tex_halo), "v": Vector3.ZERO, "vida": 0.0, "foguete": false})
	for i in 80: fumacas.append({"n": _pool(tex_fumaca), "vida": 0.0})
	for i in 24: explosoes.append({"n": _pool(tex_fogo), "vida": 0.0, "tam": 1.0})
	if not so_a_criatura:
		cam = Camera3D.new(); cam.far = 3000.0; add_child(cam); cam.current = true

# ---------- visual: céu, neblina de fumaça e luz
func _ambiente() -> void:
	env = Environment.new()
	var ceu := Sky.new(); var ps := ProceduralSkyMaterial.new()
	ps.sky_top_color = Color("#262429"); ps.sky_horizon_color = Color("#8a4a2c"); ps.ground_horizon_color = Color("#6e3a24"); ps.ground_bottom_color = Color("#2a2020")
	ps.sun_angle_max = 0.0; ceu.sky_material = ps
	env.background_mode = Environment.BG_SKY; env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("#a08070"); env.ambient_light_energy = 0.55
	env.fog_enabled = true; env.fog_light_color = Color("#6e3a24"); env.fog_density = 0.0026; env.fog_sky_affect = 0.4
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var luz := DirectionalLight3D.new(); luz.light_color = Color("#ffd9b0"); luz.light_energy = 0.8; add_child(luz)
	luz.look_at_from_position(Vector3(-0.4, 0.6, 0.7) * 100.0, Vector3.ZERO)

func _gradiente(cores: Array) -> GradientTexture2D:
	var g := Gradient.new(); g.set_color(0, cores[0]); g.set_color(1, cores[2]); g.add_point(0.4, cores[1])
	var t2 := GradientTexture2D.new(); t2.gradient = g; t2.width = 16; t2.height = 16
	t2.fill = GradientTexture2D.FILL_RADIAL; t2.fill_from = Vector2(0.5, 0.5); t2.fill_to = Vector2(1.0, 0.5)
	return t2

func _mat_luz(tex: Texture2D, cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED; m.disable_fog = true
	m.albedo_texture = tex; m.albedo_color = cor
	return m

func _quad(tex: Texture2D, cor: Color, tam: Vector2) -> MeshInstance3D:
	var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2.ONE; q.mesh = qm
	q.material_override = _mat_luz(tex, cor); q.scale = Vector3(tam.x, tam.y, 1); return q

func _pool(tex: Texture2D) -> MeshInstance3D:
	var q := _quad(tex, Color(1, 1, 1, 0), Vector2.ONE); q.visible = false; q.top_level = true; add_child(q); return q

# ---------- olhos acesos com pupila vertical e halo
func _olhos() -> void:
	var olho_m := StandardMaterial3D.new(); olho_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; olho_m.albedo_color = Color("#f4d24a")
	var pup_m := StandardMaterial3D.new(); pup_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pup_m.albedo_color = Color("#1a1206")
	var fen_m := StandardMaterial3D.new(); fen_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fen_m.albedo_color = Color("#1e0f12")
	for n in corpo.find_children("*", "MeshInstance3D", true, false):
		var nome := String(n.name)
		if nome.begins_with("olho_"): n.material_override = olho_m
		elif nome.begins_with("pupila_"): n.material_override = pup_m
		elif nome.begins_with("fenda"): n.material_override = fen_m
	for i in OLHOS.size():
		var o: Array = OLHOS[i]
		var h := _quad(tex_halo, Color(1, 1, 1, 0.8), Vector2(o[0] * 5, o[0] * 5)); h.position = Vector3(o[3], o[4], o[5] + 1); corpo.add_child(h)
		olhos.append({"olho": corpo.find_child("olho_%d" % i, true, false), "pup": corpo.find_child("pupila_%d" % i, true, false), "halo": h, "r": o[0], "ritmo": o[1], "fase": o[2]})

# ---------- helicópteros
func _helicoptero(i: int) -> void:
	var h: Node3D = HELI_CENA.instantiate(); add_child(h)
	if aplicar_ps1: PS1Util.aplicar(h)
	var luz := _quad(tex_halo, Color(1, 0.19, 0.12, 1), Vector2(5, 5)); luz.position = Vector3(0, -1.9, -2); h.add_child(luz)
	var cone_pai := Node3D.new(); add_child(cone_pai)
	var cone := MeshInstance3D.new(); var cm := CylinderMesh.new()
	cm.top_radius = 0.0; cm.bottom_radius = 18.0; cm.height = 1.0; cm.cap_top = false; cm.cap_bottom = false; cm.radial_segments = 8
	cone.mesh = cm; cone.rotation.x = PI / 2; cone.position.z = -0.5
	var mc := StandardMaterial3D.new(); mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mc.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; mc.cull_mode = BaseMaterial3D.CULL_DISABLED; mc.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mc.albedo_color = Color(1, 0.95, 0.77, 0.07); cone.material_override = mc; cone_pai.add_child(cone)
	helis.append({"h": h, "rotor": h.find_child("rotor", true, false), "cauda": h.find_child("rotor_cauda", true, false), "luz": luz, "cone": cone_pai,
		"fase": float(i) / max(1, numero_de_helicopteros), "alt": 78.0 + i * 14.0, "lado": 1.0 if i % 2 else -1.0, "cad": 0.0, "fog": 1.2 + i * 0.7, "yaw": 0.0})

func _rota(u: float, H: Dictionary) -> Vector3:
	var a := u * TAU
	return Vector3(H["lado"] * sin(a) * 135.0, H["alt"] + sin(a * 2.0) * 10.0, -290.0 - cos(a) * 125.0)

func _centro() -> Vector3:
	return criatura.global_position + Vector3(0, CY + corpo.position.y, 0)

func _dispara(de: Vector3, foguete: bool) -> void:
	var alvo := _centro() + Vector3(randf_range(-13, 13), randf_range(-15, 15), randf_range(-9, 9) + 12)
	var tr: Dictionary = tiros[i_tiro % tiros.size()]; i_tiro += 1
	var d := alvo - de; var vel := 140.0 if foguete else 320.0
	tr["vida"] = d.length() / vel; tr["v"] = d.normalized() * vel; tr["foguete"] = foguete
	var n: MeshInstance3D = tr["n"]; n.global_position = de; n.visible = true
	n.scale = Vector3.ONE * (4.0 if foguete else 2.2)
	(n.material_override as StandardMaterial3D).albedo_color = Color(1, 0.63, 0.25, 1) if foguete else Color(1, 0.88, 0.48, 1)

func _explode(p: Vector3, tam: float) -> void:
	var e: Dictionary = explosoes[i_exp % explosoes.size()]; i_exp += 1
	e["n"].global_position = p; e["vida"] = 1.0; e["tam"] = tam; e["n"].visible = true

func _fumaca(p: Vector3) -> void:
	var f: Dictionary = fumacas[i_fum % fumacas.size()]; i_fum += 1
	f["n"].global_position = p; f["vida"] = 1.0; f["n"].visible = true

func _anima_helis(dt: float) -> void:
	var c := _centro()
	for i in helis.size():
		var H: Dictionary = helis[i]
		var u: float = t / 26.0 + float(H["fase"])
		var p := _rota(u, H); var q := _rota(u + 0.002, H)
		var v := (q - p).normalized(); var yaw_novo := atan2(v.x, v.z)
		var giro := wrapf(yaw_novo - H["yaw"], -PI, PI); H["yaw"] = yaw_novo
		var h: Node3D = H["h"]
		h.global_position = p
		h.rotation = Vector3(0.18, yaw_novo, -clampf(giro / maxf(dt, 0.001) * 0.9, -0.6, 0.6))
		if H["rotor"]: H["rotor"].rotation.y += dt * 28.0
		if H["cauda"]: H["cauda"].rotation.x += dt * 40.0
		(H["luz"].material_override as StandardMaterial3D).albedo_color.a = 1.0 if fmod(t * 1.5 + i, 1.0) < 0.15 else 0.15
		var cone: Node3D = H["cone"]
		cone.global_position = p + Vector3(0, -2, 0)
		var mira := c + Vector3(sin(t * 0.7 + i) * 14.0, cos(t * 0.5 + i) * 16.0, 0)
		cone.look_at(mira); cone.scale = Vector3(1, 1, cone.global_position.distance_to(c) * 1.05)
		var para := (c - p); var dist := para.length(); para = para.normalized()
		var frente := Vector3(sin(yaw_novo), 0, cos(yaw_novo))
		if frente.dot(para) > 0.6 and dist < 320.0:
			H["cad"] -= dt
			if H["cad"] <= 0.0: H["cad"] = 0.07; _dispara(p + frente * 5.0 + Vector3(0, -1.2, 0), false)
			H["fog"] -= dt
			if H["fog"] <= 0.0:
				H["fog"] = 1.6 + randf() * 1.2
				for s in [-1.0, 1.0]: _dispara(h.to_global(Vector3(s * 2.0, -0.6, 2.0)), true)
	for tr in tiros:
		var n: MeshInstance3D = tr["n"]
		if not n.visible: continue
		n.global_position += tr["v"] * dt; tr["vida"] -= dt
		if tr["foguete"] and randf() < 0.8: _fumaca(n.global_position)
		if tr["vida"] <= 0.0:
			n.visible = false
			if tr["foguete"]: _explode(n.global_position, 22.0 + randf() * 10.0); impacto = 1.0
			elif randf() < 0.25: _explode(n.global_position, 4.0)
	for f in fumacas:
		var n: MeshInstance3D = f["n"]
		if not n.visible: continue
		f["vida"] -= dt * 0.9; n.scale = Vector3.ONE * (3.0 + (1.0 - f["vida"]) * 9.0); n.global_position.y += dt * 2.0
		(n.material_override as StandardMaterial3D).albedo_color.a = maxf(0.0, f["vida"] * 0.6)
		if f["vida"] <= 0.0: n.visible = false
	for e in explosoes:
		var n: MeshInstance3D = e["n"]
		if not n.visible: continue
		e["vida"] -= dt * 1.8; var k: float = e["tam"] * (1.3 - e["vida"] * 0.5); n.scale = Vector3(k, k, 1)
		(n.material_override as StandardMaterial3D).albedo_color.a = maxf(0.0, e["vida"])
		if e["vida"] <= 0.0: n.visible = false
	impacto = maxf(0.0, impacto - dt * 1.5)

# ---------- a criatura (a 15 quadros por segundo)
func _aponta(n: Node3D, a: Vector3, b: Vector3) -> void:
	if n == null: return
	var d := b - a; var L := d.length()
	if L < 0.001: return
	var dir := d / L
	var q := Quaternion(Vector3.UP, dir) if dir.dot(Vector3.UP) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	n.transform = Transform3D(Basis(q) * Basis.from_scale(Vector3(1, L, 1)), a)

func _anima_criatura() -> void:
	var bob := sin(t * 0.35) * 2.5; var balanco := sin(t * 0.21) * 0.05
	corpo.position.y = bob - impacto * 3.0
	corpo.rotation = Vector3(sin(t * 0.27) * 0.03 - impacto * 0.12, balanco + sin(t * 23.0) * impacto * 0.04, sin(t * 0.19) * 0.04)
	var centro := Vector3(0, CY + bob, 0)
	for i in 8:
		var a: float = PERNA_A[i] + balanco
		var r := Vector3(sin(a), 0, cos(a)); var tg := Vector3(r.z, 0, -r.x)
		var quadril := centro + r * 13.0 + Vector3(0, -4, 0)
		var joelho := quadril + r * (40.0 * cos(0.75)) + Vector3.UP * (40.0 * sin(0.75))
		var ciclo := (t + i * 1.05) / 8.4; var fase: float = ciclo - floorf(ciclo); var volta := 1.0 if int(floorf(ciclo)) % 2 else -1.0
		var off := volta * 6.0; var alt := 0.0
		if fase < 0.2:
			var q: float = fase / 0.2; off = lerpf(-volta * 6.0, volta * 6.0, q * q * (3.0 - 2.0 * q)); alt = sin(PI * q) * 16.0
		var pe := r * float(PERNA_D[i]) + tg * off; pe.y = alt
		var v := pe - joelho; var d := minf(v.length(), 88.0 + 72.0 - 0.5); v = v.normalized() * d
		var vn := v.normalized()
		var a2 := (88.0 * 88.0 - 72.0 * 72.0 + d * d) / (2.0 * d); var h := sqrt(maxf(0.0, 88.0 * 88.0 - a2 * a2))
		var nrm := (Vector3.UP - vn * Vector3.UP.dot(vn)).normalized()
		var meio := joelho + vn * a2 + nrm * h
		_aponta(segs.get("perna_%d_0" % i), quadril, joelho)
		_aponta(segs.get("perna_%d_1" % i), joelho, meio)
		_aponta(segs.get("perna_%d_2" % i), meio, joelho + v)
	for i in TENT_A.size():
		var ta: float = TENT_A[i]
		var p := centro + Vector3(sin(ta) * 7.0, -22.0, cos(ta) * 8.0 + 4.0)
		for k in 6:
			var f := (k + 1) / 6.0
			var dir := Vector3(sin(t * 0.6 + i * 1.7 + k * 0.7) * 0.45 * f + sin(ta) * 0.15, -1.0, cos(t * 0.45 + i * 2.3 + k * 0.5) * 0.35 * f + cos(ta) * 0.15).normalized()
			var q2 := p + dir * 10.0; _aponta(segs.get("tent_%d_%d" % [i, k]), p, q2); p = q2
	for o in olhos:
		var c := fmod(t + o["fase"], o["ritmo"]); var fechado := sin(c / 0.18 * PI) if c < 0.18 else 0.0
		if o["olho"]: o["olho"].scale.y = 1.0 - fechado * 0.95
		if o["pup"]: o["pup"].scale.y = maxf(0.01, 1.0 - fechado)
		var halo: MeshInstance3D = o["halo"]
		(halo.material_override as StandardMaterial3D).albedo_color.a = minf(1.0, (0.75 + 0.25 * sin(t * 2.0 + o["fase"])) * (1.0 - fechado) + impacto)
		var s: float = o["r"] * (5.0 + impacto * 4.0); halo.scale = Vector3(s, s, 1)

# ---------- loop e câmeras
func _process(dt: float) -> void:
	t += dt; acc += dt
	_anima_helis(dt)
	if acc >= 1.0 / quadros_por_segundo:
		acc = 0.0; _anima_criatura()
		for f in fogos:
			var k: float = f["k"] * (0.85 + 0.2 * sin(t * 9.0 + f["f"])); f["n"].scale = Vector3(k, k * 1.3, 1)
	if so_a_criatura: return
	var c := _centro()
	match camera_modo:
		"fundo":
			env.fog_density = 0.0026; cam.fov = 55
			cam.global_position = Vector3(sin(t * 0.15) * 1.5, 2.3 + sin(t * 0.8) * 0.05, 0); cam.look_at(Vector3(0, 40, -220))
		"perto":
			env.fog_density = 0.0011; cam.fov = 50
			if not arrastando: yaw += dt * 0.12
			var cc := criatura.global_position
			cam.global_position = cc + Vector3(sin(yaw) * cos(pitch) * 300.0, 60.0 + sin(pitch) * 300.0, cos(yaw) * cos(pitch) * 300.0); cam.look_at(cc + Vector3(0, 70, 0))
		"heli":
			env.fog_density = 0.0016; cam.fov = 58
			if helis.size() > 0:
				var hp: Vector3 = helis[0]["h"].global_position
				var atras := hp - c; atras.y = 0; atras = atras.normalized()
				cam.global_position = hp + atras * 28.0 + Vector3(0, 6, 0); cam.look_at(c + Vector3(0, -10, 0))

func _unhandled_input(e: InputEvent) -> void:
	if so_a_criatura: return
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_1: camera_modo = "fundo"
			KEY_2: camera_modo = "perto"
			KEY_3: camera_modo = "heli"
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT: arrastando = e.pressed
	if e is InputEventMouseMotion and arrastando and camera_modo == "perto":
		yaw -= e.relative.x * 0.008; pitch = clampf(pitch + e.relative.y * 0.006, -0.1, 1.2)
