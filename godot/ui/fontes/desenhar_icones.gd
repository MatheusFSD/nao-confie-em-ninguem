extends SceneTree

# Ferramenta de autoria: desenha ui/icones.png (ícones do HUD em pixel art, 12 × 12 px).
# Ordem no atlas: 0 comida (prato), 1 água (gota), 2 energia (raio), 3 ação (ampulheta).
#   godot --headless --path godot --script res://ui/fontes/desenhar_icones.gd
#   godot --headless --path godot --import
const SIZE := 12
const PALETTE := {
	"k": "1a1d1b", "w": "ece6d4", "v": "c6bda4", "b": "a0452f", "h": "d07a5a",
	"a": "4a90c8", "l": "a8d8f0", "d": "2f6a9a",
	"y": "f2c84a", "o": "d69a2a",
	"m": "8a5a32", "g": "c8d6d4", "s": "e0a040",
}
const ICONS := [
	[
		"....kkkk....",
		"..kkwwwwkk..",
		".kwwwwwwvwk.",
		"kwwwvwwwwwwk",
		"kkkkkkkkkkkk",
		"kbbbbbbbbbbk",
		"kbhbbbbbbbbk",
		".kbbbbbbbbk.",
		"..kbbbbbbk..",
		"...kkkkkk...",
		"....kbbk....",
		"...kkkkkk...",
	],
	[
		".....kk.....",
		"....kaak....",
		"....kaak....",
		"...kaaaak...",
		"...kaaaak...",
		"..kaaaaaak..",
		".kaalaaaaak.",
		".kallaaaaak.",
		".kaalaaaadk.",
		".kaaaaaaddk.",
		"..kaaaaddk..",
		"...kkkkkk...",
	],
	[
		"......kkkk..",
		".....kyyyk..",
		"....kyyyk...",
		"...kyyok....",
		"..kyyyykkkk.",
		".kyyyyyyyyk.",
		".kkkkyyyyk..",
		"....kyyok...",
		"...kyyok....",
		"..kyyk......",
		"..kyk.......",
		"..kk........",
	],
	[
		"kkkkkkkkkkkk",
		"kmmmmmmmmmmk",
		".kggggggggk.",
		".kgssssssgk.",
		"..kgssssgk..",
		"...kgssgk...",
		"...kggsgk...",
		"..kgggsggk..",
		".kggggsgggk.",
		".kgssssssgk.",
		"kmmmmmmmmmmk",
		"kkkkkkkkkkkk",
	],
]

func _initialize() -> void:
	var image := Image.create_empty(SIZE * ICONS.size(), SIZE, false, Image.FORMAT_RGBA8)
	for index in ICONS.size():
		var rows: Array = ICONS[index]
		assert(rows.size() == SIZE)
		for y in SIZE:
			var row: String = rows[y]
			assert(row.length() == SIZE, "Ícone %d, linha %d com %d colunas" % [index, y, row.length()])
			for x in SIZE:
				var key := row[x]
				if key != ".": image.set_pixel(index * SIZE + x, y, Color(PALETTE[key]))
	assert(image.save_png(ProjectSettings.globalize_path("res://ui/hud/icones.png")) == OK)
	print("icones.png salvo")
	quit()
