extends SceneTree

# Desenha o ícone do cadeado fechado, 12 × 12, no mesmo padrão dos ícones do
# HUD (ui/hud/icones.png): contorno escuro #1a1d1b, corpo amarelo #f2c84a com
# sombra #e0a040 e o arco em cinza-claro #c8d6d4.
#
#   godot --headless --path godot --script res://sprites/fontes/desenhar_cadeado.gd
const CONTORNO := Color("1a1d1b")
const CORPO := Color("f2c84a")
const SOMBRA := Color("e0a040")
const ARCO := Color("c8d6d4")
const ARCO_ESCURO := Color("8a5a32")
const BURACO := Color("1a1d1b")

func _init() -> void:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# O arco, em U invertido, com o contorno por fora.
	for x in range(4, 8): pintar(img, x, 1, ARCO)
	for y in range(2, 5):
		pintar(img, 3, y, ARCO)
		pintar(img, 8, y, ARCO_ESCURO)
	pintar(img, 3, 1, ARCO)
	pintar(img, 8, 1, ARCO_ESCURO)
	# O corpo do cadeado.
	for y in range(5, 11):
		for x in range(2, 10):
			pintar(img, x, y, CORPO if y < 8 else SOMBRA)
	# O buraco da chave.
	pintar(img, 5, 7, BURACO)
	pintar(img, 6, 7, BURACO)
	pintar(img, 5, 8, BURACO)
	pintar(img, 6, 8, BURACO)
	pintar(img, 6, 9, BURACO)
	# Contorno: tudo que encosta no vazio fica escuro.
	contornar(img)
	var caminho := ProjectSettings.globalize_path("res://ui/hud/cadeado.png")
	img.save_png(caminho)
	print("cadeado salvo em ", caminho)
	quit()

func pintar(img: Image, x: int, y: int, cor: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height(): return
	img.set_pixel(x, y, cor)

## Põe contorno escuro em volta do que foi desenhado, como nos outros ícones.
func contornar(img: Image) -> void:
	var copia := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if copia.get_pixel(x, y).a > 0.5: continue
			var encosta := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var vx: int = x + d.x
				var vy: int = y + d.y
				if vx < 0 or vy < 0 or vx >= img.get_width() or vy >= img.get_height(): continue
				if copia.get_pixel(vx, vy).a > 0.5: encosta = true
			if encosta: img.set_pixel(x, y, CONTORNO)
