extends Node3D
## Greybox pilot: world id `ruinas`, display **Ruinas de Kakaw**, level `ruinas-1`
## "El patio de las lanzas". Layout 1:1 from the 2D level (24 px = 1 m, the same
## PX_TO_M as player_maya.gd). Geometry is built from res://data/ruinas1_layout.json.
## player_maya.gd, its feel, and Maya's collision capsule are not modified.
## High-poly HOLD. Oneway collision drops while Maya's feet are below the lip
## (jump-through). Down+jump drop-through stays in the player and is not wired.
## Spikes and lasers are volumes only: damage is not added here.

const LAYOUT := "res://data/ruinas1_layout.json"
const LEVEL_H_PX := 1152.0
const PX := 1.0 / 24.0

const COL_STONE := Color("77766a")
const COL_STONE_LIT := Color("aaa083")
const COL_STONE_WET := Color("46514b")
const COL_COVER := Color("5c5b52")
const COL_WOOD := Color("63503a")
const COL_MOSS := Color("657047")
const COL_SPIKE := Color("a34d36")
const COL_HONEY := Color("e3c58c")
const COL_CACAO := Color("d7a43b")
const COL_CACAO_DEEP := Color("c97632")

var _layout: Dictionary = {}
var _player: CharacterBody3D
var _oneways: Array = []
var _crumbles: Array = []
var _movers: Array = []
var _lasers: Array = []
var _crumble_t: Dictionary = {}
var _time := 0.0
var _capturing := false
var _shot_feet := Vector3.ZERO

@onready var _hud: Control = $UI/Hud
@onready var _hud_label: Label = $UI/Hud/WorldLabel


func _ready() -> void:
	_player = $PlayerMaya as CharacterBody3D
	_layout = _load_layout()
	if _layout.is_empty():
		return
	_build_world()
	var spawn: Array = _layout["meta"]["spawn_feet_m"]
	_player.global_position = Vector3(float(spawn[0]), float(spawn[1]), float(spawn[2]))
	if _hud_label:
		var meta: Dictionary = _layout["meta"]
		_hud_label.text = "%s  ·  id %s  ·  greybox  ·  %s" % [meta["display"], meta["world_id"], meta["level_id"]]
	_style_light()
	var late := Node.new()
	late.name = "LateSim"
	late.set_script(load("res://scripts/pilot_ruinas_late.gd"))
	add_child(late)
	if _wants_capture():
		_capturing = true
		if _hud:
			_hud.visible = false
		set_physics_process(true)
		_run_capture()
	elif _wants_check():
		_print_counts()
		get_tree().quit()


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if not _capturing:
		_time += delta
	_tick_movers()
	_tick_oneways()
	_tick_lasers()


## Runs after PlayerMaya (later sibling) so floor state and the capture pin are post-move.
func late_physics(delta: float) -> void:
	if _player == null:
		return
	_tick_crumbles(delta)
	if _capturing:
		_player.velocity = Vector3.ZERO
		_player.global_position = _shot_feet


func _load_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT):
		push_error("Missing %s" % LAYOUT)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Ruinas layout JSON is not an object")
		return {}
	return parsed


func _style_light() -> void:
	var sun := $DirectionalLight3D as DirectionalLight3D
	if sun == null:
		return
	sun.rotation_degrees = Vector3(-28.0, 48.0, 0.0)
	sun.light_color = COL_HONEY
	sun.light_energy = 1.15
	sun.shadow_enabled = true


func _build_world() -> void:
	var root := $WorldRoot as Node3D
	var mats := {
		"solid": _mat(COL_STONE, 0.88),
		"cover": _mat(COL_COVER, 0.9),
		"oneway": _mat(COL_STONE_LIT, 0.82),
		"moving": _mat(COL_STONE_LIT, 0.8),
		"crate": _mat(COL_WOOD, 0.86),
		"crumble": _mat(COL_STONE_WET, 0.55),
		"spike": _mat(COL_SPIKE, 0.75),
		"laser": _mat(COL_HONEY, 0.45, true),
		"coin": _mat(COL_CACAO, 0.7),
		"pole": _mat(COL_STONE_LIT, 0.84),
		"pole_secret": _mat(COL_CACAO_DEEP, 0.7),
		"goal": _mat(COL_CACAO, 0.62),
		"fall": _mat(COL_MOSS, 0.8, false, 0.38),
	}
	var stamps := {}
	for raw in _layout["platforms"]:
		var p: Dictionary = raw
		var kind := String(p["kind"])
		var tag := String(p["tag"])
		var mat_key := kind
		if tag.begins_with("techo"):
			mat_key = "cover"
		var body: CollisionObject3D = AnimatableBody3D.new() if kind == "moving" else StaticBody3D.new()
		body.name = String(p["id"])
		body.set_meta("kind", kind)
		body.set_meta("top_m", float(p["top_m"]))
		var dynamic := kind == "moving" or kind == "crumble"
		_add_box(body, p["center_m"], p["size_m"], mats[mat_key], true, dynamic)
		root.add_child(body)
		if not dynamic:
			_stamp_box(_tool(stamps, mat_key), _vec(p["center_m"]), _vec(p["size_m"]))
		if kind == "oneway":
			_oneways.append(body)
		elif kind == "crumble":
			body.set_meta("broken", false)
			body.set_meta("respawn", 0.0)
			_crumbles.append(body)
			_crumble_t[body.name] = 0.0
		elif kind == "moving":
			(body as AnimatableBody3D).sync_to_physics = true
			body.set_meta("move", p["move"])
			_movers.append(body)
	var visual := root.get_node("Visual") as Node3D
	for raw_h in _layout["hazards"]:
		var h: Dictionary = raw_h
		if String(h["kind"]) == "spikes":
			_add_spikes(visual, h, mats["spike"], _tool(stamps, "spike"))
		else:
			var beam := Node3D.new()
			beam.name = String(h["id"])
			beam.set_meta("period", float(h["period"]))
			beam.set_meta("phase", float(h["phase"]))
			_add_box(beam, h["center_m"], h["size_m"], mats["laser"], false)
			# Keep the beam readable and narrow in Z; XY stays the 2D AABB.
			var mesh := beam.get_node("Mesh") as MeshInstance3D
			_set_depth(mesh, 0.25)
			visual.add_child(beam)
			_lasers.append(mesh)
	for raw_c in _layout["pickups"]:
		var c: Dictionary = raw_c
		var cp: Array = c["center_m"]
		_stamp_sphere(_tool(stamps, "coin"), Vector3(float(cp[0]), float(cp[1]), float(cp[2])), float(c["radius_m"]))
	for raw_k in _layout["checkpoints"]:
		var k: Dictionary = raw_k
		var secret = k["secret"]
		var key := "pole_secret" if secret != null else "pole"
		var sz: Vector3 = _vec(k["size_m"])
		sz.z = 0.45
		_stamp_box(_tool(stamps, key), _vec(k["center_m"]), sz)
	var goal: Dictionary = _layout["goal"]
	var gsz: Vector3 = _vec(goal["size_m"])
	gsz.z = 0.7
	_stamp_box(_tool(stamps, "goal"), _vec(goal["center_m"]), gsz)
	for raw_f in _layout["falls"]:
		var f: Dictionary = raw_f
		_stamp_box(_tool(stamps, "fall"), _vec(f["center_m"]), _vec(f["size_m"]))
	_commit_stamps(visual, stamps, mats)


func _add_box(host: Node3D, center: Array, size: Array, mat: Material, collide: bool, with_mesh := true) -> void:
	var c := Vector3(float(center[0]), float(center[1]), float(center[2]))
	var s := Vector3(float(size[0]), float(size[1]), float(size[2]))
	host.position = c
	if with_mesh:
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		var box := BoxMesh.new()
		box.size = s
		mesh.mesh = box
		mesh.material_override = mat
		host.add_child(mesh)
	if collide:
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box_shape := BoxShape3D.new()
		box_shape.size = s
		shape.shape = box_shape
		host.add_child(shape)


func _add_spikes(_visual: Node3D, h: Dictionary, _mat: Material, st: SurfaceTool) -> void:
	var px: Dictionary = h["px"]
	var tooth := 16.0
	var n := maxi(1, int(round(float(px["w"]) / tooth)))
	var bw := float(px["w"]) / float(n)
	var center: Array = h["center_m"]
	var size: Array = h["size_m"]
	var origin_x := float(center[0]) - float(size[0]) * 0.5
	for i in n:
		_stamp_box(st, Vector3(origin_x + (float(i) + 0.5) * bw * PX, float(center[1]), 0.0), Vector3(bw * PX, float(size[1]), 0.45))


func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _tool(stamps: Dictionary, key: String) -> SurfaceTool:
	if not stamps.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		stamps[key] = st
	return stamps[key]


func _commit_stamps(visual: Node3D, stamps: Dictionary, mats: Dictionary) -> void:
	for key in stamps.keys():
		var st: SurfaceTool = stamps[key]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Stamp_%s" % key
		mi.mesh = st.commit()
		mi.material_override = mats[key]
		visual.add_child(mi)


func _stamp_box(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var hx := s.x * 0.5
	var hy := s.y * 0.5
	var hz := s.z * 0.5
	_stamp_face(st, c, Vector3(0, 0, 1), Vector3(hx, 0, 0), Vector3(0, hy, 0), hz)
	_stamp_face(st, c, Vector3(0, 0, -1), Vector3(-hx, 0, 0), Vector3(0, hy, 0), hz)
	_stamp_face(st, c, Vector3(0, 1, 0), Vector3(hx, 0, 0), Vector3(0, 0, -hz), hy)
	_stamp_face(st, c, Vector3(0, -1, 0), Vector3(hx, 0, 0), Vector3(0, 0, hz), hy)
	_stamp_face(st, c, Vector3(1, 0, 0), Vector3(0, 0, -hz), Vector3(0, hy, 0), hx)
	_stamp_face(st, c, Vector3(-1, 0, 0), Vector3(0, 0, hz), Vector3(0, hy, 0), hx)


func _stamp_face(st: SurfaceTool, c: Vector3, n: Vector3, right: Vector3, up: Vector3, along: float) -> void:
	var o := c + n * along
	var a := o - right - up
	var b := o + right - up
	var d := o + right + up
	var e := o - right + up
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(d)
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(d)
	st.add_vertex(e)


func _stamp_sphere(st: SurfaceTool, c: Vector3, radius: float) -> void:
	var rings := 4
	var segs := 6
	for ring in rings:
		var v0 := PI * float(ring) / float(rings)
		var v1 := PI * float(ring + 1) / float(rings)
		for seg in segs:
			var u0 := TAU * float(seg) / float(segs)
			var u1 := TAU * float(seg + 1) / float(segs)
			var p00 := _sphere_point(c, radius, u0, v0)
			var p10 := _sphere_point(c, radius, u1, v0)
			var p01 := _sphere_point(c, radius, u0, v1)
			var p11 := _sphere_point(c, radius, u1, v1)
			st.set_normal((p00 - c).normalized())
			st.add_vertex(p00)
			st.set_normal((p10 - c).normalized())
			st.add_vertex(p10)
			st.set_normal((p11 - c).normalized())
			st.add_vertex(p11)
			st.set_normal((p00 - c).normalized())
			st.add_vertex(p00)
			st.set_normal((p11 - c).normalized())
			st.add_vertex(p11)
			st.set_normal((p01 - c).normalized())
			st.add_vertex(p01)


func _sphere_point(c: Vector3, radius: float, u: float, v: float) -> Vector3:
	return c + Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u)) * radius


func _tick_movers() -> void:
	for body in _movers:
		var m: Dictionary = body.get_meta("move")
		var period := maxf(0.2, float(m["period"]))
		var t := _time * TAU / period + float(m["phase"])
		var nx := float(m["ox"]) + sin(t) * float(m["ax"])
		var ny := float(m["oy"]) + cos(t) * float(m["ay"])
		var mesh := body.get_node("Mesh") as MeshInstance3D
		var sz: Vector3 = (mesh.mesh as BoxMesh).size
		var w := sz.x / PX
		var h := sz.y / PX
		var cx := (nx + w * 0.5) * PX
		var cy := (LEVEL_H_PX - ny - h * 0.5) * PX
		body.global_position = Vector3(cx, cy, 0.0)


func _tick_oneways() -> void:
	var feet := _player.global_position.y
	for body in _oneways:
		var enable: bool = feet >= float(body.get_meta("top_m")) - 0.06
		var shape := body.get_node("CollisionShape3D") as CollisionShape3D
		shape.disabled = not enable


func _standing_on(body: CollisionObject3D) -> bool:
	if not _player.is_on_floor():
		return false
	var count := _player.get_slide_collision_count()
	for i in count:
		var hit := _player.get_slide_collision(i)
		if hit.get_collider() == body and hit.get_normal().y > 0.7:
			return true
	return false


func _tick_crumbles(delta: float) -> void:
	for body in _crumbles:
		var shape := body.get_node("CollisionShape3D") as CollisionShape3D
		if bool(body.get_meta("broken")):
			var left := float(body.get_meta("respawn")) - delta
			body.set_meta("respawn", left)
			if left <= 0.0:
				body.set_meta("broken", false)
				shape.disabled = false
				body.visible = true
				_crumble_t[body.name] = 0.0
			continue
		var standing: bool = _standing_on(body)
		var t := float(_crumble_t[body.name])
		t = t + delta if standing else maxf(0.0, t - delta * 0.6)
		_crumble_t[body.name] = t
		if t > 0.46:
			body.set_meta("broken", true)
			body.set_meta("respawn", 2.7)
			shape.disabled = true
			body.visible = false


func _tick_lasers() -> void:
	for mesh in _lasers:
		var period := float(mesh.get_parent().get_meta("period"))
		var phase := float(mesh.get_parent().get_meta("phase"))
		var on: bool = fposmod(_time + phase, period) < period * 0.42
		mesh.visible = on


func _set_depth(mesh: MeshInstance3D, depth: float) -> void:
	var box := mesh.mesh as BoxMesh
	var sz := box.size
	sz.z = depth
	box.size = sz


func _mat(color: Color, rough: float, emit := false, alpha := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.roughness = rough
	mat.metallic = 0.0
	mat.metallic_specular = 0.15
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.35
	return mat


func _wants_capture() -> bool:
	if OS.get_environment("RUINAS_CAPTURE") != "":
		return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ruinas-capture"):
			return true
	return false


func _wants_check() -> bool:
	if OS.get_environment("RUINAS_CHECK") != "":
		return true
	for a in OS.get_cmdline_user_args():
		if a == "--ruinas-check":
			return true
	return false


func _capture_dir() -> String:
	var out := OS.get_environment("RUINAS_CAPTURE")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ruinas-capture="):
			out = a.substr("--ruinas-capture=".length())
	if out == "":
		out = "user://"
	if not out.ends_with("/"):
		out += "/"
	return out


func _print_counts() -> void:
	var plats: Array = _layout["platforms"]
	var hazards: Array = _layout["hazards"]
	var picks: Array = _layout["pickups"]
	print("RUINAS_CHECK platforms=%d hazards=%d pickups=%d checks=%d falls=%d goal=1" % [
		plats.size(), hazards.size(), picks.size(), _layout["checkpoints"].size(), _layout["falls"].size()
	])


func _run_capture() -> void:
	var out := _capture_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var shots: Array = _layout["shots"]
	for raw in shots:
		var shot: Dictionary = raw
		var feet: Array = shot["feet_m"]
		_shot_feet = Vector3(float(feet[0]), float(feet[1]), float(feet[2]))
		_player.global_position = _shot_feet
		_player.velocity = Vector3.ZERO
		for _i in 60:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s3d_%s.png" % [out, String(shot["id"])]
		img.save_png(path)
		_write_perf(out, String(shot["id"]), true)
		_player.visible = false
		await RenderingServer.frame_post_draw
		_write_perf(out, String(shot["id"]) + "_world", false)
		_player.visible = true
		print("RUINAS_SHOT %s" % path)
	get_tree().quit()


func _write_perf(out: String, shot: String, _with_player := true) -> void:
	var vp := get_viewport()
	var tris := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	var draws := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var objects := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
	var line := "%s tris=%d draws=%d objects=%d\n" % [shot, tris, draws, objects]
	var f := FileAccess.open(out + "perf.txt", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(out + "perf.txt", FileAccess.WRITE)
	else:
		f.seek_end()
	f.store_string(line)
	print("RUINAS_PERF %s" % line.strip_edges())
