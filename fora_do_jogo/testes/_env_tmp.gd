extends SceneTree
func _initialize() -> void:
	var pasta := "C:/Users/Matheus/Documents/não confie em ninguém/sons"
	for n in DirAccess.get_files_at(pasta):
		var s := AudioStreamMP3.load_from_file(pasta + "/" + n)
		if s.get_length() > 40.0: continue
		var pb := s.instantiate_playback()
		pb.start(0.0)
		var taxa := 44100.0
		var janela := int(taxa * 0.25)
		var linha := ""
		var picos := 0.0
		var cruzamentos := 0
		var total := 0
		var anterior := 0.0
		var n_jan := int(s.get_length() / 0.25)
		for j in n_jan:
			var amostras: PackedVector2Array = pb.mix_audio(1.0, janela)
			var soma := 0.0
			for a in amostras:
				var v := (a.x + a.y) * 0.5
				soma += v * v
				picos = maxf(picos, absf(v))
				if (v > 0.0) != (anterior > 0.0): cruzamentos += 1
				anterior = v
				total += 1
			var rms := sqrt(soma / maxf(1, amostras.size()))
			var nivel := clampi(int(rms * 40.0), 0, 9)
			linha += str(nivel)
		print("%-60s pico %.2f  zc/s %d\n   %s" % [n.left(60), picos, int(cruzamentos / (total / taxa)), linha])
	quit()
