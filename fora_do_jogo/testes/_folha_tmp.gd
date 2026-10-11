extends SceneTree
func _initialize() -> void:
	var pasta := "C:/Users/Matheus/Documents/não confie em ninguém/output/godot-validation/fotos"
	var lista := []
	for n in DirAccess.get_files_at(pasta): if n.begins_with(OS.get_cmdline_user_args()[0]) and n.ends_with(".png"): lista.append(n)
	lista.sort()
	var c := 3
	var w := 480; var h := 300
	var linhas := ceili(lista.size() / float(c))
	var folha := Image.create(c * w, linhas * h, false, Image.FORMAT_RGB8)
	for i in lista.size():
		var img := Image.load_from_file(pasta + "/" + lista[i])
		img.convert(Image.FORMAT_RGB8)
		img.resize(w, h)
		folha.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((i % c) * w, (i / c) * h))
	folha.save_png(pasta + "/folha-" + OS.get_cmdline_user_args()[0] + ".png")
	quit()
