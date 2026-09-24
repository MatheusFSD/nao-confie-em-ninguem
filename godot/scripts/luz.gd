@tool
extends PointLight2D

# Luz que acende conforme a noite chega. Paredes (camada Paredes) e portas fechadas
# projetam sombra. Rua: poste amarelado e falhando. Casa: lâmpada elétrica branca e estável.
enum Tipo { RUA, CASA }
@export var tipo: Tipo = Tipo.CASA:
	set(value):
		tipo = value
		_aplicar_estilo()
## Alcance da luz em pixels.
@export var raio := 150.0:
	set(value):
		raio = value
		_aplicar_estilo()
## Intensidade com a noite completa.
@export var intensidade := 1.0
## A partir de que ponto do dia (0 manhã, 1 noite) a luz começa a acender.
@export_range(0.0, 1.0) var acende_em := 0.5

static var _textura: ImageTexture
var _noite := 0.0
var _falha := 0.0
var _tempo := randf() * 10.0

func _ready() -> void:
	add_to_group("luzes")
	_aplicar_estilo()
	if Engine.is_editor_hint():
		energy = intensidade
	else:
		aplicar_noite(0.0)

## Brilho radial gerado na hora (sem atualização adiada), compartilhado por todas as luzes.
static func textura_radial() -> ImageTexture:
	if _textura == null:
		var imagem := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
		for y in 256:
			for x in 256:
				var d := clampf(Vector2(x - 127.5, y - 127.5).length() / 128.0, 0.0, 1.0)
				# Centro forte, meia-luz até ~35% e queda suave até a borda.
				var a := lerpf(1.0, 0.55, d / 0.35) if d < 0.35 else lerpf(0.55, 0.0, smoothstep(0.35, 1.0, d))
				imagem.set_pixel(x, y, Color(1, 1, 1, a))
		_textura = ImageTexture.create_from_image(imagem)
	return _textura

func _aplicar_estilo() -> void:
	texture = textura_radial()
	texture_scale = raio / 128.0
	shadow_enabled = true
	shadow_filter = Light2D.SHADOW_FILTER_PCF5
	shadow_color = Color(0, 0, 0, 0.85)
	color = Color(1.0, 0.7, 0.36) if tipo == Tipo.RUA else Color(0.9, 0.95, 1.0)

## noite: 0 = manhã, 1 = noite completa.
func aplicar_noite(noite: float) -> void:
	_noite = smoothstep(acende_em, minf(acende_em + 0.35, 1.0), noite)
	enabled = _noite > 0.01
	_atualizar()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not enabled: return
	if tipo == Tipo.RUA:
		# Iluminação precária: tremor constante e apagões curtos de vez em quando.
		_tempo += delta
		if _falha <= 0.0 and randf() < delta * 0.25: _falha = randf_range(0.05, 0.35)
		_falha -= delta
		_atualizar()

func _atualizar() -> void:
	var fator := _noite * intensidade
	if tipo == Tipo.RUA:
		fator *= 0.88 + 0.08 * sin(_tempo * 11.0) + 0.04 * sin(_tempo * 37.0)
		if _falha > 0.0: fator *= 0.25
	energy = fator
