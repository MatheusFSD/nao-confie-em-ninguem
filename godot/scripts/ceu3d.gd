class_name Ceu3D
extends RefCounted

# Céu em degradê, neblina e sol para uma cutscene, que roda com o mundo do jogo
# escondido e portanto precisa do seu próprio ambiente. Veio do projeto do
# artefato (scripts/ambiente.gd).
#
# A neblina aqui é exponencial e bem rala (densidade na casa dos milésimos): ela
# serve para dar profundidade à cidade que passa, não para esconder o fim do
# mundo como a do bairro.

static func criar(pai: Node, topo: Color, horizonte: Color, neblina: Color, densidade: float, rumo_da_luz: Vector3) -> void:
	var ar := Environment.new()
	var ceu := ProceduralSkyMaterial.new()
	ceu.sky_top_color = topo
	ceu.sky_horizon_color = horizonte
	ceu.ground_horizon_color = horizonte
	ceu.ground_bottom_color = horizonte.darkened(0.4)
	ceu.sun_angle_max = 8.0
	var abobada := Sky.new()
	abobada.sky_material = ceu
	ar.background_mode = Environment.BG_SKY
	ar.sky = abobada
	ar.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ar.ambient_light_color = Color.WHITE
	ar.ambient_light_energy = 0.62
	ar.fog_enabled = true
	ar.fog_light_color = neblina
	ar.fog_density = densidade
	ar.fog_sky_affect = 0.0
	ar.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var mundo := WorldEnvironment.new()
	mundo.environment = ar
	pai.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.5
	sol.shadow_enabled = false
	pai.add_child(sol)
	var rumo := rumo_da_luz.normalized()
	sol.look_at_from_position(Vector3.ZERO, -rumo, Vector3.UP if absf(rumo.y) < 0.99 else Vector3.FORWARD)
