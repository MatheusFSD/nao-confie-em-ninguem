class_name MesaDeSom
extends CanvasLayer

# A mesa de som (F9): todos os sons do jogo numa lista, para ouvir um por um.
# Os sons são gerados por código (Sons3D); os que são laço (motores) tocam
# três segundos e param. Clique, ou o número/letra ao lado, toca; F9 ou Esc
# fecha.
signal fechou

const TECLAS := "1234567890QWERTYUIOPASDFGHJKLZXCVBNM"
var _sons: Array = []
var _tocando: AudioStreamPlayer
var _parar_em := 0.0

func _init() -> void:
	layer = 6

func _ready() -> void:
	_sons = Sons3D.todos()
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var painel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("101814")
	estilo.border_color = Color("3c5146")
	estilo.set_border_width_all(1)
	estilo.set_content_margin_all(18)
	painel.add_theme_stylebox_override("panel", estilo)
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	painel.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "Mesa de som"
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color("e7c76a"))
	coluna.add_child(titulo)
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 6)
	coluna.add_child(grade)
	for i in _sons.size():
		var botao := Button.new()
		botao.text = "%s   %s" % [TECLAS[i] if i < TECLAS.length() else " ", _sons[i][0]]
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.custom_minimum_size = Vector2(230, 28)
		botao.add_theme_font_size_override("font_size", 13)
		botao.focus_mode = Control.FOCUS_NONE
		botao.pressed.connect(tocar.bind(i))
		grade.add_child(botao)
	var rodape := Label.new()
	rodape.text = "Clique ou aperte a tecla · F9 ou Esc fecha"
	rodape.add_theme_font_size_override("font_size", 13)
	rodape.add_theme_color_override("font_color", Color(0.9, 0.86, 0.75, 0.6))
	coluna.add_child(rodape)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func tocar(i: int) -> void:
	if i < 0 or i >= _sons.size(): return
	if _tocando != null: _tocando.queue_free()
	var som: AudioStream = _sons[i][1]
	_tocando = AudioStreamPlayer.new()
	_tocando.stream = som
	add_child(_tocando)
	_tocando.play()
	# Laços e gravações compridas tocam seis segundos e param.
	var laco := som is AudioStreamWAV and (som as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	_parar_em = 6.0 if laco or som.get_length() > 8.0 else 0.0

func _process(delta: float) -> void:
	if _parar_em <= 0.0 or _tocando == null: return
	_parar_em -= delta
	if _parar_em <= 0.0: _tocando.stop()

func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo: return
	var tecla := (evento as InputEventKey).physical_keycode
	get_viewport().set_input_as_handled()
	if tecla in [KEY_F9, KEY_ESCAPE]:
		fechou.emit()
		return
	var letra := OS.get_keycode_string(tecla)
	var i := TECLAS.find(letra) if letra.length() == 1 else -1
	if i >= 0: tocar(i)
