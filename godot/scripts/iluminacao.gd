extends Node

# Hora do dia guiada pelas ações: cada ação gasta avança da manhã para a noite.
# Ajusta a luz ambiente (CanvasModulate), acende postes e lâmpadas e esvazia a rua.
## Cor ambiente ao longo do dia: 0 = manhã, 1 = noite.
@export var ambiente: Gradient
## Quanto da rua continua movimentada à noite (1 = igual ao dia).
@export_range(0.0, 1.0) var movimento_a_noite := 0.15
## Segundos da transição entre um período e o próximo.
@export var transicao := 2.5
## Força da vinheta de manhã e à noite.
@export var vinheta := Vector2(0.4, 0.7)

const PERIODOS := ["Manhã", "Tarde", "Fim de tarde", "Anoitecer", "Noite"]
var progresso := 0.0
var _alvo := 0.0
var _tween: Tween
@onready var _modulo: CanvasModulate = $Ambiente

func _ready() -> void:
	if ambiente == null:
		ambiente = Gradient.new()
		ambiente.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		ambiente.colors = PackedColorArray([Color(0.97, 0.97, 0.94), Color(1.0, 0.96, 0.88), Color(0.93, 0.74, 0.58), Color(0.42, 0.37, 0.48), Color(0.14, 0.16, 0.26)])
	_aplicar.call_deferred(progresso)

## p: 0 = manhã, 1 = noite. `imediato` pula a transição (usado ao carregar).
func definir_progresso(p: float, imediato := false) -> void:
	p = clampf(p, 0.0, 1.0)
	if is_equal_approx(p, _alvo) and not imediato: return
	_alvo = p
	if _tween: _tween.kill()
	if imediato:
		_aplicar(p)
		return
	_tween = create_tween()
	_tween.tween_method(_aplicar, progresso, p, transicao).set_trans(Tween.TRANS_SINE)

func periodo(p := _alvo) -> String:
	return PERIODOS[clampi(roundi(p * (PERIODOS.size() - 1)), 0, PERIODOS.size() - 1)]

func _aplicar(p: float) -> void:
	progresso = p
	_modulo.color = ambiente.sample(p)
	get_tree().call_group("luzes", "aplicar_noite", p)
	get_tree().call_group("reage_a_noite", "aplicar_noite", p)
	for transito in get_tree().get_nodes_in_group("transito"):
		transito.definir_movimento(lerpf(1.0, movimento_a_noite, smoothstep(0.3, 1.0, p)))
	var noite := get_node_or_null("../Atmosfera/Noite") as ColorRect
	if noite and noite.material:
		(noite.material as ShaderMaterial).set_shader_parameter("forca", lerpf(vinheta.x, vinheta.y, p))
