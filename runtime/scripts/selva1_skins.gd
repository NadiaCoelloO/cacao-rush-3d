extends RefCounted
## Visual-only Cuyabeno platform skins for the 21 selva-1 boxes.
## Collision boxes stay as authored. Pieces are tiled per README:
##   N = round((W − 0.6667) / 2), s = (W − 0.6667) / (2N) ∈ [0.83, 1.17]
##   CapL / CapR at the box ends (0.3333 m inside). Pivot = top face, Y ≤ 0.
## Solids: Solid_Top + stacked Solid_Fill + required Lip.
## Oneway P01/P07/P10/P16: hewn log; P16 Y-scale 1.125; two logs along Z
## so the follow camera does not see a walkable strip without a trunk.
## Combined per platform per LOD (SurfaceTool) to stay under the draw cap.
## Names are Selva1Skin_* — never HP001_ — so hole-check stacks stay clean.

const LOD_PATHS := [
	"res://models/hp001/platform_skins_cuyabeno_LOD0.glb",
	"res://models/hp001/platform_skins_cuyabeno_LOD1.glb",
	"res://models/hp001/platform_skins_cuyabeno_LOD2.glb",
]
const ATLAS := "res://textures/T_PlatformSkins_Cuyabeno_A.png"
const SHADER := "res://shaders/platform_skins_cuyabeno.gdshader"
const LOD_BEGIN := [0.0, 26.0, 58.0]
const LOD_END := [32.0, 66.0, 0.0]
const LOD_MARGIN := 3.0
const CAP := 0.3333
const MOD := 2.0
const TOP_H := 1.3333
const FILL_H := 2.0
const MIN_FILL := 0.15
const ONEWAY_Z2 := 0.72
const P16_Y_SCALE := 1.125

var _pieces: Array = [{}, {}, {}]
var _mat_solid: ShaderMaterial
var _mat_oneway: ShaderMaterial
var dressed := 0
var colliders := 0


func load_kit() -> bool:
	_mat_solid = _make_mat(0.0)
	_mat_oneway = _make_mat(1.0)
	if _mat_solid == null:
		push_error("Selva1Skins: shader/atlas missing")
		return false
	var ok := 0
	for lod in 3:
		if not ResourceLoader.exists(LOD_PATHS[lod]):
			continue
		var packed: Resource = load(LOD_PATHS[lod])
		if not (packed is PackedScene):
			continue
		var inst: Node = (packed as PackedScene).instantiate()
		_index_meshes(inst, lod)
		inst.free()
		ok += 1
	if ok == 0:
		push_error("Selva1Skins: no GLB pieces")
		return false
	return true


func dress(play: Node3D, platforms: Array) -> void:
	dressed = 0
	colliders = 0
	var fascia := play.get_node_or_null("P00_EarthFascia") as Node3D
	if fascia:
		fascia.visible = false
	for raw in platforms:
		var p: Dictionary = raw
		var body := play.get_node_or_null(String(p["id"])) as CollisionObject3D
		if body == null:
			continue
		if body.get_node_or_null("CollisionShape3D") != null:
			colliders += 1
		var kind := String(p["kind"])
		var size := Vector3(float(p["size_m"][0]), float(p["size_m"][1]), float(p["size_m"][2]))
		var hid := _hide_old(body)
		if kind == "oneway":
			_dress_oneway(body, String(p["id"]), size)
		else:
			_dress_solid(body, String(p["id"]), size)
		if hid:
			dressed += 1
	print("SELVA_SKINS dressed=%d colliders=%d pieces0=%d" % [
		dressed, colliders, (_pieces[0] as Dictionary).size()
	])


func _make_mat(oneway: float) -> ShaderMaterial:
	if not ResourceLoader.exists(SHADER) or not ResourceLoader.exists(ATLAS):
		return null
	var sh: Resource = load(SHADER)
	if not (sh is Shader):
		return null
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo_tex", load(ATLAS))
	mat.set_shader_parameter("roughness", 0.62)
	mat.set_shader_parameter("is_oneway", oneway)
	mat.set_shader_parameter("alpha_scissor", 0.5)
	return mat


func _index_meshes(n: Node, lod: int) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var key := _piece_key(String(mi.name), lod)
			if key != "":
				(_pieces[lod] as Dictionary)[key] = {
					"mesh": mi.mesh,
					"xf": _xf_to_root(mi, _root_of(mi)),
				}
	for c in n.get_children():
		_index_meshes(c, lod)


func _root_of(n: Node) -> Node:
	var cur := n
	while cur.get_parent() != null:
		cur = cur.get_parent()
	return cur


func _xf_to_root(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var cur := n.get_parent()
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _piece_key(nm: String, lod: int) -> String:
	var suf := "_LOD%d" % lod
	if nm.ends_with(suf):
		return nm.substr(0, nm.length() - suf.length())
	# Godot may keep the mesh name without the node suffix.
	if nm.find("Solid_") >= 0 or nm.find("Lip_") >= 0 or nm.find("Oneway_") >= 0:
		return nm.replace(suf, "").replace("_LOD0", "").replace("_LOD1", "").replace("_LOD2", "")
	return ""


func _hide_old(body: Node) -> bool:
	var hid := false
	var mesh := body.get_node_or_null("Mesh") as GeometryInstance3D
	if mesh:
		mesh.visible = false
		hid = true
	var lip := body.get_node_or_null("Lip") as GeometryInstance3D
	if lip:
		lip.visible = false
	return hid


func _tile_plan(width: float) -> Dictionary:
	var inner := width - 2.0 * CAP
	var n := int(round(inner / MOD))
	if n < 1:
		n = 1
	var s := inner / (float(n) * MOD)
	return {"n": n, "s": s, "inner": inner}


func _dress_solid(body: Node3D, pid: String, size: Vector3) -> void:
	var plan := _tile_plan(size.x)
	var y_top := size.y * 0.5
	for lod in 3:
		var st := SurfaceTool.new()
		_append_row(st, lod, "Solid_Top", plan, size.x, y_top, 0.0, 1.0)
		_append_row(st, lod, "Lip", plan, size.x, y_top, 0.0, 1.0)
		var remaining := size.y - TOP_H
		var y_fill := y_top - TOP_H
		while remaining > MIN_FILL:
			var this_h := minf(FILL_H, remaining)
			_append_row(st, lod, "Solid_Fill", plan, size.x, y_fill, 0.0, this_h / FILL_H)
			y_fill -= this_h
			remaining -= this_h
		_commit(body, pid, lod, st, _mat_solid)


func _dress_oneway(body: Node3D, pid: String, size: Vector3) -> void:
	var plan := _tile_plan(size.x)
	var y_top := size.y * 0.5
	var sy := P16_Y_SCALE if pid == "P16" else 1.0
	for lod in 3:
		var st := SurfaceTool.new()
		# Two logs along Z: the kit log is ~0.67 m of the 2.67 m box.
		# A second copy toward +Z (camera) covers the walkable front strip.
		for z_off in [0.0, ONEWAY_Z2]:
			_append_row(st, lod, "Oneway", plan, size.x, y_top, z_off, sy)
		_commit(body, pid, lod, st, _mat_oneway)


func _append_row(st: SurfaceTool, lod: int, kind: String, plan: Dictionary, width: float, y: float, z: float, sy: float) -> void:
	var bag: Dictionary = _pieces[lod]
	var n: int = plan["n"]
	var s: float = plan["s"]
	var half := width * 0.5
	_append_piece(st, bag, "%s_CapL" % kind, Transform3D(Basis.from_scale(Vector3(1.0, sy, 1.0)), Vector3(-half, y, z)))
	_append_piece(st, bag, "%s_CapR" % kind, Transform3D(Basis.from_scale(Vector3(1.0, sy, 1.0)), Vector3(half, y, z)))
	var inner_left := -half + CAP
	for i in n:
		var x := inner_left + s * MOD * (float(i) + 0.5)
		_append_piece(st, bag, "%s_2m" % kind, Transform3D(Basis.from_scale(Vector3(s, sy, 1.0)), Vector3(x, y, z)))


func _append_piece(st: SurfaceTool, bag: Dictionary, key: String, xf: Transform3D) -> void:
	if not bag.has(key):
		return
	var rec: Dictionary = bag[key]
	var mesh: Mesh = rec["mesh"]
	var local: Transform3D = rec["xf"]
	var world := xf * local
	for s in mesh.get_surface_count():
		st.append_from(mesh, s, world)


func _commit(body: Node3D, pid: String, lod: int, st: SurfaceTool, mat: Material) -> void:
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Selva1Skin_%s_LOD%d" % [pid, lod]
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.visibility_range_begin = float(LOD_BEGIN[lod])
	mi.visibility_range_end = float(LOD_END[lod])
	mi.visibility_range_begin_margin = LOD_MARGIN
	mi.visibility_range_end_margin = LOD_MARGIN
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	body.add_child(mi)
