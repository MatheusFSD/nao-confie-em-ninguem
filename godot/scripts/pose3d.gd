class_name Pose3D
extends RefCounted

# Gira ossos por cima da pose que veio no .glb — nos modelos das cutscenes a
# pose de descanso já é a pessoa sentada ou de pé, então basta acrescentar o
# balanço em cima dela. Veio do projeto do artefato (scripts/pose.gd).

static func esqueleto(no: Node) -> Skeleton3D:
	if no == null: return null
	if no is Skeleton3D: return no
	if no is MeshInstance3D and (no as MeshInstance3D).skeleton != NodePath():
		var achado = no.get_node_or_null((no as MeshInstance3D).skeleton)
		if achado is Skeleton3D: return achado
	var dentro := no.find_children("*", "Skeleton3D", true, false)
	if dentro.size() > 0: return dentro[0]
	var pai := no.get_parent()
	return pai if pai is Skeleton3D else null

static func girar(sk: Skeleton3D, osso: String, graus: Vector3) -> void:
	if sk == null: return
	var i := sk.find_bone(osso)
	if i < 0: return
	var giro := Quaternion.from_euler(Vector3(deg_to_rad(graus.x), deg_to_rad(graus.y), deg_to_rad(graus.z)))
	sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion() * giro)
