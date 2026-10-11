class_name LegendaTV
extends RefCounted

# A legenda dos programas de TV: texto claro sobre uma tarja preta
# translúcida, do tamanho da fala, encostada embaixo. Só o contorno de sombra
# não segurava a leitura em cima do cenário claro do jornal.
#
# A quebra de linha é feita aqui, palavra por palavra, e não pelo Label: com
# quebra automática ele media a altura antes de quebrar o texto, e a tarja da
# primeira fala saía do tamanho da tela, vazia.

## Uma legenda pronta para ir no quadro da TV.
static func criar(largura: float, tamanho := 19) -> Label:
	var rotulo := Label.new()
	rotulo.name = "Legenda"
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", Color("f6f1e4"))
	var tarja := StyleBoxFlat.new()
	tarja.bg_color = Color(0, 0, 0, 0.66)
	tarja.content_margin_left = 12
	tarja.content_margin_right = 12
	tarja.content_margin_top = 4
	tarja.content_margin_bottom = 6
	rotulo.add_theme_stylebox_override("normal", tarja)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.set_meta("largura", largura)
	rotulo.set_meta("fala", "")
	rotulo.visible = false
	return rotulo

## Troca o texto e encolhe a tarja até a fala, com a base em `base_y` e
## centrada em `meio_x`. Sem texto, some.
static func escrever(rotulo: Label, texto: String, meio_x: float, base_y: float) -> void:
	if String(rotulo.get_meta("fala", "")) == texto and rotulo.visible == not texto.is_empty(): return
	rotulo.set_meta("fala", texto)
	rotulo.visible = not texto.is_empty()
	if texto.is_empty():
		rotulo.text = ""
		return
	var fonte := rotulo.get_theme_font("font")
	var tamanho := rotulo.get_theme_font_size("font_size")
	var util: float = float(rotulo.get_meta("largura", 600.0)) - 24.0
	var linhas: Array[String] = []
	var atual := ""
	for palavra in texto.split(" ", false):
		var teste := palavra if atual.is_empty() else atual + " " + palavra
		if not atual.is_empty() and fonte.get_string_size(teste, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x > util:
			linhas.append(atual)
			atual = palavra
		else:
			atual = teste
	linhas.append(atual)
	rotulo.text = "\n".join(linhas)
	rotulo.reset_size()
	rotulo.position = Vector2(meio_x - rotulo.size.x / 2.0, base_y - rotulo.size.y)
