class_name PS1Util
## Troca os materiais importados do .glb pelo shader PS1 (mantém a textura, filtro nearest).
## Materiais de dupla face usam a versão sem descarte de faces.

static func aplicar(raiz: Node, resolucao := Vector2(320, 240)) -> void:
	var sh: Shader = load("res://comum/ps1.gdshader")
	var sh2: Shader = load("res://comum/ps1_duplo.gdshader")
	_aplicar(raiz, sh, sh2, resolucao)

static func _aplicar(n: Node, sh: Shader, sh2: Shader, res: Vector2) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			if src is StandardMaterial3D:
				var m := ShaderMaterial.new()
				m.shader = sh2 if src.cull_mode == BaseMaterial3D.CULL_DISABLED else sh
				m.set_shader_parameter("albedo_tex", src.albedo_texture)
				m.set_shader_parameter("tint", src.albedo_color)
				m.set_shader_parameter("snap_resolution", res)
				mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_aplicar(c, sh, sh2, res)
