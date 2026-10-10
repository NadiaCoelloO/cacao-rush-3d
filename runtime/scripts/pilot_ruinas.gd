extends Node3D
## Greybox pilot: world id `ruinas`, display **Ruinas de Kakaw**, level `ruinas-1`
## "El patio de las lanzas". Layout 1:1 from the 2D level (24 px = 1 m, the same
## PX_TO_M as player_maya.gd). Geometry is built from res://data/ruinas1_layout.json.
## player_maya.gd, its feel, and Maya's collision capsule are not modified.
## High-poly HOLD. Oneway collision drops while Maya's feet are below the lip
## (jump-through) and while player_maya's _drop_timer is running (down+jump,
## 0.18 s). Mantle still queries every solid on Maya's collision_mask; excluding
## oneways from that query needs a change in player_maya.gd, so it is not done.
##
## sim.ts values used here: hazard inset (x+4, y+8, w-8, h-10), coin radius 28 px,
## laser duty 0.42, kill invuln 0.8 / hitstop 0.08 / deathT 0.55 / respawn invuln
## 1.1 / MAX_LIVES 5, checkpoint poleLock 0.35, goal winT 1.35, fall warpT 0.28.
## K00 / F00 log the missing destination and respawn at the last spawn (no freeze,
## no life lost). Dropping below the 2D kill line (level height + 80 px) costs a life.

const LAYOUT := "res://data/ruinas1_layout.json"
const LEVEL_H_PX := 1152.0
const LEVEL_W_PX := 4800.0
const PX := 1.0 / 24.0
const PW := 26.0 * PX
const VIEW_W_M := 960.0 * PX
const VIEW_H_M := 540.0 * PX
## fov 50 vertical, dolly set so the view covers the 2D 960×540 window.
const CAM_DOLLY := 24.1256
const MAYA_LAYER := 2

const COL_STONE := Color("4a382c")
const COL_STONE_LIP := Color("6b5440")
const COL_STONE_WET := Color("3a2e28")
const COL_WOOD := Color("5c4030")
const COL_MOSS := Color("4a5a38")
const COL_SPIKE := Color("c9c4bc")
const COL_LASER := Color("c41418")
const COL_LASER_CORE := Color("fff0d2")
const COL_BEAN := Color("8b4a2b")
const COL_BEVEL := Color("d8cbb8")
const COL_POLE := Color("6a5a4a")
const COL_POLE_ON := Color("3d8a72")
const COL_ROOT := Color("3a2a22")
const COL_VINE := Color("2c3a28")
const COL_SKY := Color("1e1714")
const COL_FOG := Color("2c241e")
## sim.ts: kill when p.y > level.height + 80. Feet are PH below that top.
const FALL_Y := -(80.0 + 42.0) * PX

var _layout: Dictionary = {}
var _player: CharacterBody3D
var _oneways: Array = []
var _crumbles: Array = []
var _movers: Array = []
var _lasers: Array = []
var _hazards: Array = []
var _coins: Array = []
var _poles: Array = []
var _falls: Array = []
var _goal_aabb := AABB()
var _goal_mesh: MeshInstance3D
var _goal_taken := false
var _crumble_t: Dictionary = {}
var _time := 0.0
var _capturing := false
var _shot_feet := Vector3.ZERO
var _lives := 5
var _coins_taken := 0
var _invuln := 0.0
var _hitstop := 0.0
var _death_t := 0.0
var _win_t := 0.0
var _status := "playing"
var _hold_pos := Vector3.ZERO
var _pole_lock := 0.0
var _message := ""
var _message_t := 0.0
var _hint: Label
var _fade_mats: Array = []

@onready var _hud: Control = $UI/Hud
@onready var _hud_label: Label = $UI/Hud/WorldLabel


func _ready() -> void:
	_player = $PlayerMaya as CharacterBody3D
	# The tscn export is ignored if it sits above `script =`. Set it here too.
	_player.camera_offset = Vector3(0.0, 1.0, CAM_DOLLY)
	_player.kill_y = -1000.0
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
	_tag_maya_layer(_player)
	_attach_maya_lights()
	_hint = $UI/Hud/HintLabel as Label
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
	if not _capturing and _status == "playing" and _hitstop <= 0.0:
		_time += delta
	_tick_movers()
	_tick_oneways()
	_tick_lasers()
	_bob_coins()
	if not _capturing:
		_tick_play(delta)


func _process(delta: float) -> void:
	_push_fade()
	if _message_t > 0.0:
		_message_t = maxf(0.0, _message_t - delta)
		_show_hud()


## Runs after PlayerMaya (later sibling) so floor state and the capture pin are post-move.
func late_physics(delta: float) -> void:
	if _player == null:
		return
	_tick_crumbles(delta)
	if _capturing:
		_player.velocity = Vector3.ZERO
		_player.global_position = _shot_feet
	else:
		_tick_freeze(delta)
		_tick_void()
	_match_framing()


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
	if sun:
		# Warm light from above the canopy. Low energy so the stone stays in shadow.
		sun.rotation_degrees = Vector3(-72.0, 36.0, 0.0)
		sun.light_color = Color("c4a07a")
		sun.light_energy = 0.42
		sun.shadow_enabled = true
	var env_node := $WorldEnvironment as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = COL_SKY
		env.ambient_light_color = COL_SKY
		env.ambient_light_energy = 0.18
		env.fog_enabled = true
		env.fog_light_color = COL_FOG
		env.fog_density = 0.035
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.015
		env.volumetric_fog_albedo = Color("3a3028")
	_add_pit_fog()


func _add_pit_fog() -> void:
	var fog := FogVolume.new()
	fog.name = "PitFog"
	# Between the climb walls, sitting in the shaft. F00 spans x 15.3–22, y up to 6.7.
	fog.position = Vector3(18.7, 3.2, 0.0)
	fog.size = Vector3(8.0, 7.0, 5.0)
	var mat := FogMaterial.new()
	mat.density = 1.15
	mat.albedo = Color("1a2820")
	fog.material = mat
	add_child(fog)


func _build_world() -> void:
	var root := $WorldRoot as Node3D
	var mats := {
		"solid": _stone_mat(COL_STONE, 0.92),
		"lip": _stone_mat(COL_STONE_LIP, 0.84),
		"bevel": _stone_mat(COL_BEVEL, 0.7),
		"oneway": _stone_mat(COL_STONE, 0.9),
		"moving": _stone_mat(COL_STONE, 0.88),
		"crate": _stone_mat(COL_WOOD, 0.86),
		"crumble": _stone_mat(COL_STONE_WET, 0.72),
		"spike": _flat(COL_SPIKE),
		"laser": _mat(COL_LASER, 0.4, true),
		"moss": _mat(COL_MOSS, 0.9),
		"root": _mat(COL_ROOT, 0.9),
	}
	var stamps := {}
	for raw in _layout["platforms"]:
		var p: Dictionary = raw
		var kind := String(p["kind"])
		var mat_key := kind if mats.has(kind) else "solid"
		var body: CollisionObject3D = AnimatableBody3D.new() if kind == "moving" else StaticBody3D.new()
		body.name = String(p["id"])
		body.set_meta("kind", kind)
		body.set_meta("top_m", float(p["top_m"]))
		var dynamic := kind == "moving" or kind == "crumble"
		_add_box(body, p["center_m"], p["size_m"], mats[mat_key], true, dynamic)
		if dynamic:
			_add_lip(body, _vec(p["size_m"]), mats["lip"])
		root.add_child(body)
		if not dynamic:
			var center := _vec(p["center_m"])
			var size := _vec(p["size_m"])
			_stamp_stone(_tool(stamps, mat_key), _tool(stamps, "lip"), center, size)
			_stamp_bevel(_tool(stamps, "bevel"), center, size)
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
			_add_spikes(visual, h, _tool(stamps, "spike"))
		else:
			var beam := Node3D.new()
			beam.name = String(h["id"])
			beam.set_meta("period", float(h["period"]))
			beam.set_meta("phase", float(h["phase"]))
			_add_box(beam, h["center_m"], h["size_m"], mats["laser"], false)
			var mesh := beam.get_node("Mesh") as MeshInstance3D
			_thin_laser(mesh)
			visual.add_child(beam)
			_lasers.append(mesh)
	var bean_mat := _bean_mat()
	for raw_c in _layout["pickups"]:
		var c: Dictionary = raw_c
		var cp: Array = c["center_m"]
		var center := Vector3(float(cp[0]), float(cp[1]), float(cp[2]))
		var bean := MeshInstance3D.new()
		bean.name = String(c["id"])
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		sphere.radial_segments = 8
		sphere.rings = 4
		bean.mesh = sphere
		bean.scale = Vector3(0.72, 1.15, 0.62)
		bean.position = center
		bean.material_override = bean_mat
		visual.add_child(bean)
		_coins.append({
			"id": String(c["id"]),
			"center": center,
			"phase": float(c["px"]["x"]) * 0.05,
			"mesh": bean,
			"taken": false,
		})
	for raw_k in _layout["checkpoints"]:
		var k: Dictionary = raw_k
		var secret = k["secret"]
		var sz: Vector3 = _vec(k["size_m"])
		sz.z = 0.45
		var pole := MeshInstance3D.new()
		pole.name = String(k["id"])
		var box := BoxMesh.new()
		box.size = Vector3(0.33, sz.y, 0.28)
		pole.mesh = box
		pole.position = _vec(k["center_m"])
		pole.material_override = _mat(COL_POLE, 0.8)
		visual.add_child(pole)
		var px: Dictionary = k["px"]
		var spawn_feet := Vector3((float(px["x"]) + 4.0 + 13.0) * PX, (LEVEL_H_PX - float(px["y"]) - float(px["h"])) * PX, 0.0)
		_poles.append({
			"id": String(k["id"]),
			"aabb": _aabb_of(_vec(k["center_m"]), _vec(k["size_m"])),
			"secret": secret if secret != null else "",
			"active": false,
			"mesh": pole,
			"spawn": spawn_feet,
		})
	var goal: Dictionary = _layout["goal"]
	var gsz: Vector3 = _vec(goal["size_m"])
	_goal_aabb = _aabb_of(_vec(goal["center_m"]), gsz)
	_goal_mesh = MeshInstance3D.new()
	_goal_mesh.name = "G00"
	var goal_sphere := SphereMesh.new()
	goal_sphere.radius = 0.38
	goal_sphere.height = 0.76
	goal_sphere.radial_segments = 8
	goal_sphere.rings = 4
	_goal_mesh.mesh = goal_sphere
	_goal_mesh.scale = Vector3(0.85, 1.2, 0.7)
	_goal_mesh.position = _vec(goal["center_m"])
	_goal_mesh.material_override = _bean_mat()
	visual.add_child(_goal_mesh)
	for raw_f in _layout["falls"]:
		var f: Dictionary = raw_f
		_falls.append({
			"id": String(f["id"]),
			"secret": String(f["secret"]),
			"aabb": _aabb_of(_vec(f["center_m"]), _vec(f["size_m"])),
			"used": false,
		})
	_commit_stamps(visual, stamps, mats)
	_dress_pit(visual, mats)
	for raw_h in _layout["hazards"]:
		var h: Dictionary = raw_h
		_hazards.append({
			"id": String(h["id"]),
			"kind": String(h["kind"]),
			"aabb": _aabb_of(_vec(h["center_m"]), _vec(h["size_m"])),
			"period": float(h["period"]) if h["period"] != null else 0.0,
			"phase": float(h["phase"]) if h["phase"] != null else 0.0,
		})


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


func _stone_mat(color: Color, rough: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/m_ruinas_stone.gdshader")
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("roughness_value", rough)
	mat.set_shader_parameter("maya_pos", Vector3.ZERO)
	_fade_mats.append(mat)
	return mat


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 1.0
	return mat


func _push_fade() -> void:
	if _player == null or _fade_mats.is_empty():
		return
	var mid := _player.global_position + Vector3(0.0, float(_player._h) * 0.5, 0.0)
	for mat in _fade_mats:
		(mat as ShaderMaterial).set_shader_parameter("maya_pos", mid)


func _stamp_wedge(st: SurfaceTool, x: float, w: float, bottom: float, h: float) -> void:
	# Pale triangle, thin in Z. Gameplay still uses the hazard AABB.
	var z := 0.08
	var bl := Vector3(x, bottom, z)
	var br := Vector3(x + w, bottom, z)
	var ap := Vector3(x + w * 0.5, bottom + h, z)
	var bl2 := Vector3(x, bottom, -z)
	var br2 := Vector3(x + w, bottom, -z)
	var ap2 := Vector3(x + w * 0.5, bottom + h, -z)
	_tri(st, bl, br, ap)
	_tri(st, bl2, ap2, br2)
	_tri(st, bl, ap, bl2)
	_tri(st, bl2, ap, ap2)
	_tri(st, br, br2, ap)
	_tri(st, br2, ap2, ap)
	_tri(st, bl, bl2, br)
	_tri(st, br, bl2, br2)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _stamp_bevel(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	if s.y < 0.22 or s.x < 0.3:
		return
	var bh := 0.16
	var bd := 0.22
	var inset := minf(0.06, s.x * 0.03)
	var top := c.y + s.y * 0.5
	var front := c.z + s.z * 0.5
	# Proud of the front face so it does not z-fight the stone.
	var bc := Vector3(c.x, top - bh * 0.5, front + 0.025 - bd * 0.5)
	var bs := Vector3(maxf(0.2, s.x - inset * 2.0), bh, bd)
	_stamp_box(st, bc, bs)


func _thin_laser(mesh: MeshInstance3D) -> void:
	var box := mesh.mesh as BoxMesh
	var sz := box.size
	sz.x = 0.16
	sz.z = 0.05
	box.size = sz
	var red := StandardMaterial3D.new()
	red.albedo_color = COL_LASER
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = red
	var core := MeshInstance3D.new()
	core.name = "Core"
	var core_box := BoxMesh.new()
	core_box.size = Vector3(0.048, sz.y, 0.06)
	core.mesh = core_box
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = COL_LASER_CORE
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material_override = core_mat
	mesh.add_child(core)


func _add_spikes(_visual: Node3D, h: Dictionary, st: SurfaceTool) -> void:
	var px: Dictionary = h["px"]
	var tooth := 16.0
	var n := maxi(1, int(round(float(px["w"]) / tooth)))
	var bw := float(px["w"]) / float(n)
	var center: Array = h["center_m"]
	var size: Array = h["size_m"]
	var origin_x := float(center[0]) - float(size[0]) * 0.5
	var bottom := float(center[1]) - float(size[1]) * 0.5
	for i in n:
		_stamp_wedge(st, origin_x + float(i) * bw * PX, bw * PX, bottom, float(size[1]))


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


func _stamp_stone(body: SurfaceTool, lip: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var hx := s.x * 0.5
	var hy := s.y * 0.5
	var hz := s.z * 0.5
	_stamp_face(body, c, Vector3(0, 0, 1), Vector3(hx, 0, 0), Vector3(0, hy, 0), hz)
	_stamp_face(body, c, Vector3(0, 0, -1), Vector3(-hx, 0, 0), Vector3(0, hy, 0), hz)
	_stamp_face(lip, c, Vector3(0, 1, 0), Vector3(hx, 0, 0), Vector3(0, 0, -hz), hy)
	_stamp_face(body, c, Vector3(0, -1, 0), Vector3(hx, 0, 0), Vector3(0, 0, hz), hy)
	_stamp_face(body, c, Vector3(1, 0, 0), Vector3(0, 0, -hz), Vector3(0, hy, 0), hx)
	_stamp_face(body, c, Vector3(-1, 0, 0), Vector3(0, 0, hz), Vector3(0, hy, 0), hx)


func _add_lip(host: Node3D, size: Vector3, mat: Material) -> void:
	var lip_h := minf(0.12, size.y * 0.35)
	var mesh := MeshInstance3D.new()
	mesh.name = "Lip"
	var box := BoxMesh.new()
	box.size = Vector3(size.x, lip_h, size.z)
	mesh.mesh = box
	mesh.position = Vector3(0.0, size.y * 0.5 - lip_h * 0.5 + 0.01, 0.0)
	mesh.material_override = mat
	host.add_child(mesh)


func _bean_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COL_BEAN
	mat.roughness = 0.42
	mat.metallic = 0.04
	mat.metallic_specular = 0.35
	mat.emission_enabled = true
	mat.emission = Color("c46a3a")
	mat.emission_energy_multiplier = 0.8
	return mat


func _aabb_of(center: Vector3, size: Vector3) -> AABB:
	return AABB(center - size * 0.5, size)


func _dress_pit(visual: Node3D, mats: Dictionary) -> void:
	# Vines hang on the shaft walls, gapped around x≈17.3 so jardin Maya stays visible.
	var vine_mat := _vine_mat()
	var vine_x := [15.35, 15.95, 16.45, 18.75, 19.3, 19.85]
	for i in vine_x.size():
		var quad := MeshInstance3D.new()
		quad.name = "Vine%d" % i
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.5, 7.6)
		quad.mesh = mesh
		quad.material_override = vine_mat
		quad.position = Vector3(vine_x[i], 3.6, 0.28 if i % 2 == 0 else -0.28)
		visual.add_child(quad)
	# Moss along the inner base of the climb walls. Visual only.
	var moss_mat := _mat(COL_MOSS, 0.85)
	moss_mat.emission_enabled = true
	moss_mat.emission = Color("5d7a48")
	moss_mat.emission_energy_multiplier = 0.35
	for side in [15.7, 19.5]:
		var moss := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.55, 1.15, 2.4)
		moss.mesh = box
		moss.position = Vector3(side, 0.55, 0.0)
		moss.material_override = moss_mat
		visual.add_child(moss)
	# A few roots hugging the stone at the shaft mouth. Not colliders.
	for i in 4:
		var root := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.35, 0.22, 1.6)
		root.mesh = box
		root.position = Vector3(14.2 + float(i) * 1.5, 0.35 + float(i % 2) * 0.4, 1.15)
		root.rotation_degrees = Vector3(0.0, 18.0 * float(i), 8.0)
		root.material_override = mats["root"]
		visual.add_child(root)
	# Local green only: a short beam and an emissive sheet on the pit floor.
	var glow := MeshInstance3D.new()
	glow.name = "PitGlow"
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(2.1, 0.06, 1.4)
	glow.mesh = glow_mesh
	glow.position = Vector3(17.35, 0.18, 0.0)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color("6a9a62")
	glow_mat.emission_enabled = true
	glow_mat.emission = Color("8fce86")
	glow_mat.emission_energy_multiplier = 0.9
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = glow_mat
	visual.add_child(glow)
	var beam := SpotLight3D.new()
	beam.name = "JardinBeam"
	beam.position = Vector3(17.35, 0.45, 0.0)
	beam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	beam.light_color = Color("8fce86")
	beam.light_energy = 2.2
	beam.spot_range = 6.5
	beam.spot_angle = 18.0
	beam.spot_attenuation = 0.8
	beam.shadow_enabled = false
	visual.add_child(beam)
	_add_mist(visual)
	_add_dust(visual, Vector3(17.35, 2.2, 0.2), Color(0.75, 0.9, 0.62, 0.35))
	_add_silhouettes(visual)


func _vine_mat() -> StandardMaterial3D:
	var img := Image.create(8, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 32:
		img.set_pixel(1, y, Color("c6e6a8"))
		img.set_pixel(2, y, Color("a8d48a"))
		img.set_pixel(3, y, Color("7fbf6a"))
		if y % 3 != 0:
			img.set_pixel(5, y, Color("d4f0bc"))
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color("d4f0bc")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat


func _add_mist(visual: Node3D) -> void:
	# Horizontal sheets. FogVolume is Forward+ only; these stay visible on the GL capture too.
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.12, 0.18, 0.14, 0.42)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 3:
		var sheet := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(7.2, 4.2)
		sheet.mesh = mesh
		sheet.material_override = mat
		sheet.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		sheet.position = Vector3(17.6, 0.8 + float(i) * 1.5, 0.0)
		visual.add_child(sheet)


func _add_silhouettes(visual: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("0c0908")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 1.0
	var heights := [18.0, 26.0, 14.0, 22.0, 16.0, 28.0]
	# Kept off the patio gap (x 4–16) and far behind the play plane.
	var xs := [-18.0, 26.0, 44.0, 62.0, 80.0, 98.0]
	for i in heights.size():
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(7.0, heights[i])
		quad.mesh = mesh
		quad.material_override = mat
		quad.position = Vector3(xs[i], heights[i] * 0.45, -16.0)
		visual.add_child(quad)


func _add_dust(visual: Node3D, at: Vector3, color: Color) -> void:
	var parts := GPUParticles3D.new()
	parts.position = at
	parts.amount = 28
	parts.lifetime = 3.2
	parts.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 8, 4))
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(1.1, 1.6, 0.35)
	proc.direction = Vector3(0.05, 1, 0)
	proc.spread = 18.0
	proc.initial_velocity_min = 0.12
	proc.initial_velocity_max = 0.35
	proc.gravity = Vector3(0, 0.04, 0)
	proc.color = color
	parts.process_material = proc
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var qmat := StandardMaterial3D.new()
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.albedo_color = Color(1, 1, 1, 0.45)
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = qmat
	parts.draw_pass_1 = quad
	visual.add_child(parts)


func _tag_maya_layer(node: Node) -> void:
	if node is VisualInstance3D:
		var vis := node as VisualInstance3D
		vis.layers = vis.layers | MAYA_LAYER
	for child in node.get_children():
		_tag_maya_layer(child)


func _attach_maya_lights() -> void:
	# LOOK-001 fill and rim. cull_mask is Maya's layer only; the world light stays on layer 1.
	var fill := OmniLight3D.new()
	fill.name = "LOOK001_FILL_MayaBack"
	fill.light_color = Color(1.0, 0.86, 0.70)
	fill.light_energy = 0.34
	fill.light_specular = 0.0
	fill.omni_range = 3.0
	fill.omni_attenuation = 1.5
	fill.shadow_enabled = false
	fill.light_volumetric_fog_energy = 0.0
	fill.light_cull_mask = MAYA_LAYER
	fill.position = Vector3(0.0, 1.22, 0.88)
	_player.add_child(fill)
	var rim := OmniLight3D.new()
	rim.name = "LOOK001_RIM_MayaFollow"
	rim.light_color = Color(1.0, 0.86, 0.70)
	rim.light_energy = 0.10
	rim.light_specular = 0.0
	rim.omni_range = 2.6
	rim.omni_attenuation = 1.5
	rim.shadow_enabled = false
	rim.light_volumetric_fog_energy = 0.0
	rim.light_cull_mask = MAYA_LAYER
	rim.position = Vector3(0.50, 1.48, -0.60)
	_player.add_child(rim)


func _match_framing() -> void:
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var offset: Vector3 = _player.camera_offset
	var focus := cam.global_position - offset
	# 2D followCam clamped to the level, then the 960×540 window is centered on that.
	var min_x := VIEW_W_M * 0.5
	var max_x := LEVEL_W_PX * PX - VIEW_W_M * 0.5
	var max_y := (LEVEL_H_PX - 270.0) * PX
	var min_y := (LEVEL_H_PX - (LEVEL_H_PX - 540.0) - 270.0) * PX
	focus.x = clampf(focus.x, min_x, max_x)
	focus.y = clampf(focus.y, min_y, max_y)
	cam.global_position = focus + offset
	if focus.distance_squared_to(cam.global_position) > 0.001:
		cam.look_at(focus, Vector3.UP)


func _overlap(a: AABB, b: AABB) -> bool:
	return a.position.x < b.end.x and a.end.x > b.position.x and a.position.y < b.end.y and a.end.y > b.position.y


func _full_body() -> AABB:
	var feet := _player.global_position
	var h := float(_player._h)
	return AABB(Vector3(feet.x - PW * 0.5, feet.y, -2.0), Vector3(PW, h, 4.0))


func _hurt_body() -> AABB:
	# sim.ts hazards: aabb(p.x+4, p.y+8, p.w-8, p.h-10). 2D y grows down.
	var feet := _player.global_position
	var h := float(_player._h)
	var left := feet.x - PW * 0.5 + 4.0 * PX
	var box_h := h - 10.0 * PX
	var bottom := feet.y + 2.0 * PX
	return AABB(Vector3(left, bottom, -2.0), Vector3(PW - 8.0 * PX, box_h, 4.0))


func _tick_play(delta: float) -> void:
	if _status != "playing":
		return
	_invuln = maxf(0.0, _invuln - delta)
	_pole_lock = maxf(0.0, _pole_lock - delta)
	_hazards_touch()
	if _status != "playing":
		return
	_collect_coins()
	_touch_poles()
	_touch_goal()
	_touch_falls()
	_show_hud()


func _hazards_touch() -> void:
	if _invuln > 0.0:
		return
	var body := _hurt_body()
	for h in _hazards:
		if String(h["kind"]) == "laser":
			var period := float(h["period"])
			var phase := float(h["phase"])
			if fposmod(_time + phase, period) >= period * 0.42:
				continue
		if _overlap(body, h["aabb"]):
			_kill()
			return


func _kill() -> void:
	if _invuln > 0.0 or _status != "playing":
		return
	_lives -= 1
	_invuln = 0.8
	_hitstop = 0.08
	_hold_pos = _player.global_position
	if _lives <= 0:
		_status = "over"
		_say("Sin vidas", 2.0)
	else:
		_status = "dead"
		_death_t = 0.55
		_say("Caída", 0.55)


func _tick_freeze(delta: float) -> void:
	if _hitstop > 0.0:
		_hitstop = maxf(0.0, _hitstop - delta)
		_player.velocity = Vector3.ZERO
		_player.global_position = _hold_pos
		return
	if _status == "dead":
		_death_t -= delta
		_player.velocity = Vector3.ZERO
		_player.global_position = _hold_pos
		if _death_t <= 0.0:
			_player._respawn()
			_invuln = 1.1
			_status = "playing"
			_say("Partida", 0.8)
		return
	if _status == "over" or _status == "win" or _status == "warp":
		_player.velocity = Vector3.ZERO
		_player.global_position = _hold_pos
		if _status == "win":
			_win_t -= delta


func _collect_coins() -> void:
	var feet := _player.global_position
	var h := float(_player._h)
	var center := Vector2(feet.x, feet.y + h * 0.5)
	for c in _coins:
		if bool(c["taken"]):
			continue
		var at: Vector3 = c["center"]
		if center.distance_to(Vector2(at.x, at.y)) < 28.0 * PX:
			c["taken"] = true
			(c["mesh"] as MeshInstance3D).visible = false
			_coins_taken += 1


func _touch_poles() -> void:
	var body := _full_body()
	var jump := Input.is_action_just_pressed("jump")
	var held := Input.is_action_pressed("jump")
	for pole in _poles:
		if not _overlap(body, pole["aabb"]):
			continue
		var secret := String(pole["secret"])
		var active := bool(pole["active"])
		var can_warp := secret != ""
		var ready := active and can_warp
		var press := jump or (ready and held and _pole_lock <= 0.0)
		if not press or _status == "warp":
			continue
		if ready:
			_pole_lock = 0.35
			_begin_warp(secret)
			continue
		pole["active"] = true
		var mesh := pole["mesh"] as MeshInstance3D
		var mat := mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = COL_POLE_ON
		var spawn: Vector3 = pole["spawn"]
		var xf: Transform3D = _player._spawn
		xf.origin = spawn
		_player._spawn = xf
		_pole_lock = 0.35
		if secret != "":
			_say("Tótem guardado — W otra vez", 1.6)
			print("RUINAS_SECRET %s" % secret)
		else:
			_say("Partida guardada", 1.6)


func _touch_goal() -> void:
	if _goal_taken:
		return
	if not _overlap(_full_body(), _goal_aabb):
		return
	_goal_taken = true
	if _goal_mesh:
		_goal_mesh.visible = false
	_status = "win"
	_win_t = 1.35
	_hold_pos = _player.global_position
	_say("Meta", 1.35)
	print("RUINAS_GOAL taken")


func _touch_falls() -> void:
	if _status != "playing":
		return
	var body := _full_body()
	for f in _falls:
		if bool(f["used"]):
			continue
		if not _overlap(body, f["aabb"]):
			continue
		f["used"] = true
		_begin_warp(String(f["secret"]))
		return


func _begin_warp(world: String) -> void:
	var level := "%s-1" % world
	print("RUINAS_WARP world=%s level=%s stub=no 3D scene" % [world, level])
	_say("Warp %s (sin escena 3D)" % level, 2.4)
	# No destination scene: back to the last spawn. Lives stay put.
	_player._respawn()


func _tick_void() -> void:
	if _capturing or _status != "playing":
		return
	# sim.ts: p.y > level.height + 80. Feet sit PH below the 2D top.
	if _player.global_position.y < FALL_Y:
		_kill()


func _bob_coins() -> void:
	for c in _coins:
		if bool(c["taken"]):
			continue
		var mesh := c["mesh"] as MeshInstance3D
		var at: Vector3 = c["center"]
		mesh.position = at + Vector3(0.0, sin(_time * 4.0 + float(c["phase"])) * (4.0 * PX), 0.0)


func _say(text: String, seconds: float) -> void:
	_message = text
	_message_t = seconds
	_show_hud()


func _show_hud() -> void:
	if _hint == null:
		return
	var line := "Vidas %d · cacao %d" % [_lives, _coins_taken]
	if _message_t > 0.0 and _message != "":
		line = "%s · %s" % [_message, line]
	_hint.text = line


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
	# player_maya arms _drop_timer (0.18 s) on down+jump. This runs before Maya's
	# tick, so the disable lands on the next physics frame, inside that window.
	var dropping: bool = float(_player._drop_timer) > 0.0
	for body in _oneways:
		var enable: bool = (not dropping) and feet >= float(body.get_meta("top_m")) - 0.06
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
	print("RUINAS_CAM offset=%s kill_y=%.1f" % [_player.camera_offset, _player.kill_y])


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
		_log_framing(String(shot["id"]))
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


func _log_framing(shot: String) -> void:
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var dolly := float(_player.camera_offset.z)
	var fov := cam.fov
	var vis_h := 2.0 * dolly * tan(deg_to_rad(fov * 0.5))
	var vp := get_viewport().get_visible_rect().size
	var origin_top := cam.project_ray_origin(Vector2(vp.x * 0.5, 0.0))
	var dir_top := cam.project_ray_normal(Vector2(vp.x * 0.5, 0.0))
	var origin_bot := cam.project_ray_origin(Vector2(vp.x * 0.5, vp.y))
	var dir_bot := cam.project_ray_normal(Vector2(vp.x * 0.5, vp.y))
	var origin_l := cam.project_ray_origin(Vector2(0.0, vp.y * 0.5))
	var dir_l := cam.project_ray_normal(Vector2(0.0, vp.y * 0.5))
	var origin_r := cam.project_ray_origin(Vector2(vp.x, vp.y * 0.5))
	var dir_r := cam.project_ray_normal(Vector2(vp.x, vp.y * 0.5))
	var top := origin_top + dir_top * ((0.0 - origin_top.z) / dir_top.z)
	var bot := origin_bot + dir_bot * ((0.0 - origin_bot.z) / dir_bot.z)
	var left := origin_l + dir_l * ((0.0 - origin_l.z) / dir_l.z)
	var right := origin_r + dir_r * ((0.0 - origin_r.z) / dir_r.z)
	var feet := cam.unproject_position(_player.global_position)
	var head := cam.unproject_position(_player.global_position + Vector3(0.0, 42.0 * PX, 0.0))
	print("RUINAS_CAM shot=%s offset=%s fov=%.2f formula_h=%.4f plane_h=%.4f plane_w=%.4f vp=%sx%s maya_px=%.2f" % [
		shot, _player.camera_offset, fov, vis_h, absf(top.y - bot.y), absf(right.x - left.x),
		vp.x, vp.y, absf(feet.y - head.y)
	])


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
