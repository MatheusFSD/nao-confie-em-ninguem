extends CanvasLayer

# Interior abstrato: mantém o jogador protegido até ele escolher sair.
# MenuEscolha conserva teclado, clique, carência e cancelamento existentes.
signal escolheu(chave: String)

var menu: MenuEscolha
var _titulo: Label
var _estado: Label
var _coluna: VBoxContainer

func _init() -> void:
	layer = 4
	var fundo := ColorRect.new()
	fundo.color = Color("0b1110")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var painel := PanelContainer.new()
	painel.custom_minimum_size.x = 520
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("151d1c")
	estilo.border_color = Color("455047")
	estilo.set_border_width_all(1)
	estilo.set_content_margin_all(24)
	painel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(painel)
	_coluna = VBoxContainer.new()
	_coluna.add_theme_constant_override("separation", 14)
	painel.add_child(_coluna)
	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 24)
	_titulo.add_theme_color_override("font_color", Color("e8c16a"))
	_coluna.add_child(_titulo)
	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.custom_minimum_size.x = 470
	_coluna.add_child(_estado)

func mostrar(nome: String, ciclo: Ciclo3D, resumo := "") -> void:
	_titulo.text = "Casa de %s · Dia %d · %s" % [nome, ciclo.dia, ciclo.periodo()]
	_estado.text = "Você está abrigado. A rua fica do lado de fora.\nComida: %d · Água: %d · Energia: %d · Ações: %d" % [ciclo.comida, ciclo.agua, ciclo.energia, ciclo.acoes]
	if not resumo.is_empty(): _estado.text += "\n\n" + resumo
	if menu != null:
		menu.hide()
		_coluna.remove_child(menu)
		menu.queue_free()
	menu = MenuEscolha.new()
	menu.escolheu.connect(func(chave: String): escolheu.emit(chave))
	_coluna.add_child(menu)
	var noite := ciclo.acoes == 0
	menu.perguntar("", [
		{"chave": "esperar", "texto": "Esperar até amanhã" if noite else "Esperar mais um período",
		"abaixo": "Consome 1 comida e 1 água das suas reservas; faltas reduzem as ações de amanhã. Não recupera energia." if noite else "1 ação de tempo · 0 energia · continuar abrigado"},
		{"chave": "sair", "texto": "Sair para a rua", "abaixo": "Voltar à mesma porta · sem custo · Esc também sai"}
	])
