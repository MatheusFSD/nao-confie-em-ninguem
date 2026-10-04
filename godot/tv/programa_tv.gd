extends Node3D
## Programa de TV em estilo PS1: "pronunciamento" ou "telejornal".
## Tudo roda aqui: pose do personagem, boca e piscadas (troca de pixels na textura),
## câmeras, telão, arte da TV e legendas. Os textos ficam nas constantes lá embaixo.

@export_enum("pronunciamento", "telejornal") var tipo := "pronunciamento"
@export var arte_da_tv := true
@export var legendas := true
@export var quadros_por_segundo := 15.0

## Falas postas de fora, no formato [[inicio, fim, texto], ...]. É por aqui que
## o jogo manda a notícia do dia para a boca do apresentador; vazio mantém o
## texto que veio no arquivo.
var falas_de_fora: Array = []
## Quanto dura a volta inteira, em segundos. Zero calcula pela última fala.
var loop_de_fora := 0.0
## O letreiro que corre no rodapé do telejornal.
var rodape := RODAPE

const PRONUNCIAMENTO := {
	"loop": 12.0,
	"falas": [
		[0.4, 2.7, "Boa noite, brasileiras e brasileiros."],
		[3.0, 5.6, "Venho falar com vocês sobre o futuro do nosso país."],
		[6.4, 8.9, "O momento pede união, trabalho e responsabilidade."],
		[9.2, 11.5, "Conto com cada um de vocês. Boa noite."],
	],
	"boca": Rect2i(12, 25, 7, 3), "olhos": [Rect2i(8, 11, 9, 3), Rect2i(19, 11, 9, 3)],
	"cor_boca": Color("#4a2420"), "cor_pele": Color("#ce9f7c"), "cor_cilio": Color("#5a4034"),
	"fundo": Color("#1a1512"), "luz": Vector3(-0.35, 0.7, 0.9), "ambiente": 0.55,
}
const TELEJORNAL := {
	"loop": 16.0,
	"falas": [
		[0.5, 2.9, "Boa noite. Começamos com uma notícia da ciência."],
		[3.2, 5.4, "Uma equipe de cientistas brasileiros fez um anúncio hoje."],
		[5.8, 7.8, "Os pesquisadores trabalham em sigilo há mais de dez anos."],
		[8.4, 10.6, "Os nomes da equipe não foram divulgados."],
		[10.9, 13.4, "Novas informações devem sair nos próximos dias."],
		[13.8, 15.5, "Voltamos já."],
	],
	"boca": Rect2i(12, 25, 7, 2), "olhos": [Rect2i(8, 12, 8, 3), Rect2i(19, 12, 8, 3)],
	"cor_boca": Color("#4a1e22"), "cor_pele": Color("#a86e4c"), "cor_cilio": Color("#26160f"),
	"fundo": Color("#0b1d4a"), "luz": Vector3(0.3, 0.6, 1.0), "ambiente": 0.6,
}
const RODAPE := "TRÂNSITO LENTO NA AVENIDA BRASIL  •  PREVISÃO: CALOR DE 38 °C NO RIO NESTE FIM DE SEMANA  •  LOTERIA ACUMULA DE NOVO  •  CIENTISTAS FARÃO NOVO ANÚNCIO  •  "

const SH_NORMAL := preload("res://tv/ps1.gdshader")
const SH_DUPLO := preload("res://tv/ps1_duplo.gdshader")
const SH_BANDEIRA := preload("res://tv/ps1_bandeira.gdshader")
const W := 320.0
const H := 240.0

var P: Dictionary
var t := 0.0
var tq := 0.0
var acc := 0.0
var skel: Skeleton3D
var ossos := {}
var cam: Camera3D
var overlay: Control
var fonte: Font
var face_img: Image
var face_orig: Image
var face_tex: ImageTexture
var face_key := ""
var tela_base: Image
var tela_img: Image
var tela_tex: ImageTexture

func _ready() -> void:
	# Cópia: o dicionário do arquivo é constante e vale para todas as TVs, então
	# mexer nele direto trocaria a fala de todas as telas de uma vez.
	P = (PRONUNCIAMENTO if tipo == "pronunciamento" else TELEJORNAL).duplicate(true)
	if not falas_de_fora.is_empty():
		P["falas"] = falas_de_fora
		P["loop"] = loop_de_fora if loop_de_fora > 0.0 else float(falas_de_fora[falas_de_fora.size() - 1][1]) + 1.5
	fonte = load("res://tv/PixelifySans.ttf") if ResourceLoader.exists("res://tv/PixelifySans.ttf") else ThemeDB.fallback_font
	var achados := find_children("*", "Skeleton3D", true, false)
	skel = achados[0] if achados.size() > 0 else null
	if skel:
		for i in skel.get_bone_count():
			ossos[skel.get_bone_name(i)] = i
	_converter_materiais(self)
	cam = Camera3D.new(); add_child(cam); cam.current = true
	var luz := DirectionalLight3D.new(); add_child(luz)
	luz.look_at_from_position(P["luz"] * 10.0, Vector3.ZERO)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = P["fundo"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color.WHITE; env.ambient_light_energy = P["ambiente"]
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var camada := CanvasLayer.new(); add_child(camada)
	overlay = Control.new(); overlay.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_desenhar_arte); camada.add_child(overlay)

# ---------- materiais: troca tudo pelo shader PS1 e prepara as texturas que mudam
func _converter_materiais(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			if not (src is StandardMaterial3D): continue
			var nome := String(mi.name)
			var m := ShaderMaterial.new()
			m.shader = SH_BANDEIRA if nome.begins_with("bandeira") else (SH_DUPLO if src.cull_mode == BaseMaterial3D.CULL_DISABLED else SH_NORMAL)
			var tex: Texture2D = src.albedo_texture
			if mi.skin != null: tex = _preparar_rosto(tex)
			elif nome.begins_with("telao"): tex = _preparar_telao(tex)
			m.set_shader_parameter("albedo_tex", tex)
			m.set_shader_parameter("tint", src.albedo_color)
			mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_converter_materiais(c)

func _imagem(tex: Texture2D) -> Image:
	var img := tex.get_image()
	if img.is_compressed(): img.decompress()
	img.clear_mipmaps(); img.convert(Image.FORMAT_RGBA8)
	return img

func _preparar_rosto(tex: Texture2D) -> Texture2D:
	face_img = _imagem(tex); face_orig = face_img.duplicate()
	face_tex = ImageTexture.create_from_image(face_img)
	return face_tex

func _preparar_telao(tex: Texture2D) -> Texture2D:
	tela_base = _imagem(tex); tela_base.flip_y()          # o glTF guarda essa imagem de ponta-cabeça
	tela_img = tela_base.duplicate(); tela_img.flip_y()
	tela_tex = ImageTexture.create_from_image(tela_img)
	return tela_tex

# ---------- utilidades de tempo
func _sst(a: float, b: float, x: float) -> float:
	var k := clampf((x - a) / (b - a), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

func _env(x: float, a: float, b: float, f := 0.35) -> float:
	return _sst(a, a + f, x) * (1.0 - _sst(b - f, b, x))

func _fala(x: float) -> Array:
	for f in P["falas"]:
		if x >= f[0] and x <= f[1]: return f
	return []

func _rot(nome: String, x := 0.0, y := 0.0, z := 0.0) -> void:
	if ossos.has(nome):
		skel.set_bone_pose_rotation(ossos[nome], Quaternion.from_euler(Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z))))

func _quadril(y: float) -> void:
	if ossos.has("hips"): skel.set_bone_pose_position(ossos["hips"], Vector3(0, y, 0))

# ---------- loop
func _process(delta: float) -> void:
	t = fmod(t + delta, float(P["loop"]))
	acc += delta
	if acc >= 1.0 / quadros_por_segundo:                    # animação a 15 quadros, como na época
		acc = 0.0; tq = t
		if skel:
			if tipo == "pronunciamento": _pose_presidente(tq)
			else: _pose_ancora(tq)
		if tela_img: _desenhar_telao(tq)
	_camera(t)
	overlay.queue_redraw()

func _pose_presidente(x: float) -> void:
	var w: float = TAU * x / float(P["loop"])
	var fala := 1.0 if _fala(x).size() > 0 else 0.0
	_quadril(0.57); _rot("hips", -3)
	_rot("thigh_L", -86); _rot("thigh_R", -86); _rot("shin_L", 84); _rot("shin_R", 84); _rot("foot_L", 2); _rot("foot_R", 2)
	_rot("spine", 7 + 1.2 * sin(w * 3), 1.5 * sin(w))
	_rot("chest", 2 + 0.8 * sin(w * 6))
	var gd := _env(x, 3.2, 5.4, 0.45)
	var ge := _env(x, 6.9, 8.6, 0.45)
	_rot("upperarm_R", -42 - 16 * gd, 0, -7 - 14 * gd)
	_rot("forearm_R", -48 - 38 * gd - 6 * gd * sin(x * 9))
	_rot("hand_R", -4 * gd, -20 * gd)
	_rot("upperarm_L", -42 - 10 * ge, 0, 7 + 10 * ge)
	_rot("forearm_L", -48 - 26 * ge)
	_rot("hand_L", -6 * ge, 18 * ge)
	var baixo := _env(x, 5.55, 6.35, 0.2)
	_rot("neck", 2)
	_rot("head", 2 + fala * 2.2 * sin(x * 5.3) + 16 * baixo - 2 * ge, 4 * sin(w) + 5 * gd - 4 * ge, 1.5 * sin(w * 2))
	var boca := 0
	if fala > 0 and sin(x * 17.3) + 0.6 * sin(x * 29.1 + 1) > 0.15: boca = 2 if sin(x * 11.7) > 0.3 else 1
	var pisca := baixo > 0.6
	for b in [1.8, 4.7, 8.2, 10.6]:
		if x > b and x < b + 0.13: pisca = true
	_rosto(boca, pisca)

func _pose_ancora(x: float) -> void:
	var w: float = TAU * x / float(P["loop"])
	var fala := 1.0 if _fala(x).size() > 0 else 0.0
	_quadril(0.6); _rot("hips", -3)
	_rot("thigh_L", -86, 0, -3); _rot("thigh_R", -86, 0, 3); _rot("shin_L", 84); _rot("shin_R", 84)
	_rot("spine", 6 + 1.0 * sin(w * 3), 1.2 * sin(w * 2))
	_rot("chest", 2 + 0.8 * sin(w * 8))
	var bate := _env(x, 2.95, 3.35, 0.12)
	var ge := _env(x, 3.4, 5.2, 0.4)
	var gc := _env(x, 11.2, 12.9, 0.4) + _env(x, 6.0, 7.4, 0.4)
	_rot("upperarm_R", -40 - 8 * bate - 12 * ge, 0, -6 - 8 * ge)
	_rot("forearm_R", -52 - 10 * bate - 30 * ge - 5 * ge * sin(x * 8))
	_rot("hand_R", -8 * ge, -16 * ge)
	_rot("upperarm_L", -40 - 8 * bate - 10 * gc, 0, 6 + 8 * gc)
	_rot("forearm_L", -52 - 10 * bate - 26 * gc)
	_rot("hand_L", -6 * gc, 16 * gc)
	var cam2 := x > 8.1
	_rot("neck", 1)
	_rot("head", 1 + fala * 2 * sin(x * 5.7) + 8 * bate, (-12.0 if cam2 else -3.0) + 3 * sin(w * 2) + 4 * ge, 2 * sin(w * 3) - 2 * ge)
	var boca := 0
	if fala > 0 and sin(x * 18.1) + 0.6 * sin(x * 27.3 + 2) > 0.15: boca = 2 if sin(x * 12.9) > 0.35 else 1
	var pisca := bate > 0.5
	for b in [1.5, 4.6, 7.9, 9.9, 13.6, 15.2]:
		if x > b and x < b + 0.12: pisca = true
	_rosto(boca, pisca)

# boca e piscadas: troca de pixels na textura do rosto
func _rosto(boca: int, pisca: bool) -> void:
	if face_img == null: return
	var key := "%d|%s" % [boca, pisca]
	if key == face_key: return
	face_key = key
	face_img.copy_from(face_orig)
	var r: Rect2i = P["boca"]
	if boca > 0:
		var extra := 1 if boca == 2 else 0
		face_img.fill_rect(Rect2i(r.position.x, r.position.y - extra, r.size.x, r.size.y + extra), P["cor_boca"])
		face_img.fill_rect(Rect2i(r.position.x + 1, r.position.y - extra, r.size.x - 2, 1), Color("#e8e2d6"))
	if pisca:
		for e in P["olhos"]:
			face_img.fill_rect(Rect2i(e.position.x + 1, e.position.y, e.size.x - 2, e.size.y), P["cor_pele"])
			face_img.fill_rect(Rect2i(e.position.x + 1, e.position.y + 1, e.size.x - 2, 1), P["cor_cilio"])
	face_tex.update(face_img)

func _desenhar_telao(x: float) -> void:
	tela_img.copy_from(tela_base)
	tela_img.fill_rect(Rect2i(0, 0, 64, 31), Color("#0d2350"))
	var a: float = x / float(P["loop"]) * TAU * 6.0
	for o in 3:
		for k in 24:
			var q := k / 24.0 * TAU
			var p := Vector2(cos(q) * 13.0, sin(q) * 5.0).rotated(o * PI / 3.0)
			tela_img.set_pixel(32 + int(p.x), 15 + int(p.y), Color("#9fd0ff"))
	for o in 3:
		var p := Vector2(cos(a + o * 2.1) * 13.0, sin(a + o * 2.1) * 5.0).rotated(o * PI / 3.0)
		tela_img.fill_rect(Rect2i(32 + int(p.x) - 1, 15 + int(p.y) - 1, 2, 2), Color.WHITE)
	tela_img.fill_rect(Rect2i(30, 13, 4, 4), Color("#e8453c"))
	tela_img.flip_y()
	tela_tex.update(tela_img)

func _camera(x: float) -> void:
	if tipo == "pronunciamento":
		if x < 6.3:
			var k := x / 6.3
			cam.fov = 40; cam.position = Vector3(0.05 - 0.1 * k, 1.12, 2.25 - 0.12 * k); cam.look_at(Vector3(0, 1.0, 0))
		else:
			var k := (x - 6.3) / 5.7
			cam.fov = 30; cam.position = Vector3(0.36 - 0.06 * k, 1.3, 1.42 - 0.06 * k); cam.look_at(Vector3(0.02, 1.17, 0))
	else:
		if x < 8.1:
			var k := x / 8.1
			cam.fov = 42; cam.position = Vector3(-0.3 + 0.08 * k, 1.2, 2.05 - 0.1 * k); cam.look_at(Vector3(0.3, 1.12, 0))
		else:
			var k := (x - 8.1) / 7.9
			cam.fov = 30; cam.position = Vector3(-0.32 + 0.04 * k, 1.3, 1.34 - 0.05 * k); cam.look_at(Vector3(0.02, 1.16, 0))

# ---------- arte da TV, desenhada em coordenadas de 320×240
func _ret(x: float, y: float, w: float, h: float, c: Color) -> void:
	overlay.draw_rect(Rect2(x, y, w, h), c)

func _txt(s: String, x: float, y: float, tam: int, c: Color, centro := false) -> void:
	var px := x
	if centro: px = x - fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x / 2.0
	overlay.draw_string(fonte, Vector2(px, y + fonte.get_ascent(tam)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, c)

func _contorno(s: String, x: float, y: float, tam: int) -> void:
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_txt(s, x + d.x, y + d.y, tam, Color.BLACK, true)
	_txt(s, x, y, tam, Color.WHITE, true)

func _desenhar_arte() -> void:
	overlay.draw_set_transform(Vector2.ZERO, 0.0, overlay.size / Vector2(W, H))
	if arte_da_tv:
		if tipo == "pronunciamento": _arte_pronunciamento(tq)
		else: _arte_telejornal(tq)
	var f := _fala(tq)
	if legendas and f.size() > 0:
		var linhas: Array[String] = []
		var atual := ""
		for p in String(f[2]).split(" "):
			var teste := (atual + " " + p) if atual != "" else p
			if fonte.get_string_size(teste, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x > 280: linhas.append(atual); atual = p
			else: atual = teste
		linhas.append(atual)
		var base_y := 214.0 if tipo == "pronunciamento" else 204.0
		for i in linhas.size():
			_contorno(linhas[i], W / 2.0, base_y - (linhas.size() - 1 - i) * 11.0, 9)

func _arte_pronunciamento(x: float) -> void:
	_txt("REDE 7", 10, 9, 9, Color(1, 1, 1, 0.75))
	_ret(W - 92, 8, 84, 12, Color("#b8262d")); _txt("CADEIA NACIONAL", W - 50, 10, 8, Color.WHITE, true)
	var lt := _env(x, 0.6, 5.6, 0.35)
	if lt > 0.0:
		var px := -140.0 + 150.0 * lt
		_ret(px, 170, 170, 14, Color("#1f6b3a")); _ret(px, 184, 170, 11, Color("#f2c62a")); _ret(px + 168, 170, 3, 25, Color("#f2c62a"))
		_txt("PRONUNCIAMENTO OFICIAL", px + 6, 172, 9, Color.WHITE)
		_txt("Presidente da República", px + 6, 185, 8, Color("#1b2a1f"))

func _arte_telejornal(x: float) -> void:
	_ret(8, 8, 50, 14, Color("#16357a")); _ret(8, 8, 14, 14, Color("#f2c62a"))
	_txt("7", 15, 9, 10, Color("#16357a"), true); _txt("JORNAL", 25, 10, 8, Color.WHITE)
	_ret(W - 72, 8, 64, 13, Color("#b8262d")); _txt("AO VIVO  20:31", W - 40, 10, 8, Color.WHITE, true)
	if int(floor(x * 2.0)) % 2 == 0: _ret(W - 69, 13, 3, 3, Color.WHITE)
	var lt := _env(x, 0.7, 5.3, 0.35)
	if lt > 0.0:
		var px := -150.0 + 160.0 * lt
		_ret(px, 168, 176, 14, Color("#16357a")); _ret(px, 182, 176, 11, Color("#e6ecf5")); _ret(px + 174, 168, 4, 25, Color("#f2c62a"))
		_txt("JORNAL DA REDE 7", px + 6, 170, 9, Color.WHITE)
		_txt("Edição da noite", px + 6, 183, 8, Color("#16357a"))
	# rodapé: dá uma volta inteira por loop, então emenda sem pulo
	_ret(0, H - 15, W, 15, Color("#0b1d4a"))
	var tw := ceilf(fonte.get_string_size(rodape, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var off: float = x / float(P["loop"]) * tw
	var rx: float = -off
	while rx < W:
		_txt(rodape, rx + 58, H - 12, 8, Color("#e6ecf5")); rx += tw
	_ret(0, H - 15, 56, 15, Color("#b8262d")); _txt("URGENTE", 28, H - 12, 8, Color.WHITE, true)
