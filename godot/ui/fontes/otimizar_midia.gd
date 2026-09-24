extends SceneTree

# Ferramenta de autoria: gera as imagens do jogo a partir das artes originais,
# que ficam fora do projeto, em ../arte-original/.
#   ui/cenas/tv.webp, radio.webp, mercado.webp  (cenários de tela cheia)
#   ui/personagens/irma.webp                    (retrato dos diálogos, com transparência)
# A tela do jogo é 960 × 640 (janela 1152 × 768): 1280 × 720 basta nos cenários.
#   godot --headless --path godot --script res://ui/fontes/otimizar_midia.gd
const CENA := Vector2i(1280, 720)
const RETRATO_ALTURA := 460

func _initialize() -> void:
	otimizar_cena("tv")
	otimizar_cena("radio", func(image: Image) -> void:
		# Apaga o ponteiro vermelho pintado: o jogo desenha um ponteiro que se move.
		# Copia a escala 13 px à esquerda, que repete as mesmas marcas.
		for y in range(352, 418):
			for x in range(1266, 1279):
				image.set_pixel(x, y, image.get_pixel(x - 13, y)))
	otimizar_cena("mercado")
	otimizar_retrato("irma")
	quit()

func carregar(nome: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path("res://../arte-original/%s.png" % nome))

func salvar(image: Image, destino: String, qualidade := 0.82) -> void:
	assert(image.save_webp(ProjectSettings.globalize_path(destino), true, qualidade) == OK)
	print(destino, ": ", FileAccess.get_file_as_bytes(destino).size() / 1024, " KB")

func otimizar_cena(nome: String, retoque := Callable()) -> void:
	var image := carregar(nome)
	image.convert(Image.FORMAT_RGB8)
	if retoque.is_valid(): retoque.call(image)
	image.resize(CENA.x, CENA.y, Image.INTERPOLATE_LANCZOS)
	salvar(image, "res://ui/cenas/%s.webp" % nome)

# Retrato mantém a transparência e é recortado no que realmente tem desenho.
func otimizar_retrato(nome: String) -> void:
	var image := carregar(nome)
	image.convert(Image.FORMAT_RGBA8)
	var usado := image.get_used_rect()
	image = image.get_region(usado)
	var escala := float(RETRATO_ALTURA) / image.get_height()
	image.resize(roundi(image.get_width() * escala), RETRATO_ALTURA, Image.INTERPOLATE_LANCZOS)
	salvar(image, "res://ui/personagens/%s.webp" % nome, 0.88)
