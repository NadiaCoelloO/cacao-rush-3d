extends Node3D
## Río de Chocolate greybox (rio-1). Layout values come from sim.ts / levels.ts.
## player_maya.gd is not modified. camera_offset is set again here because an
## export written above `script =` in the tscn is discarded.

const LAYOUT := "res://data/rio1_layout.json"
const LEVEL_H_PX := 896.0
const LEVEL_W_PX := 4992.0
const PX := 1.0 / 24.0
const PW := 26.0 * PX
const VIEW_W_M := 960.0 * PX
const CAM_DOLLY := 24.1256
const MAYA_LAYER := 2
const DEPTH := 64.0 * PX

const COL_BANK := Color("2c1810")
const COL_LIP := Color("3a2820")
const COL_CRATE := Color("322018")
const COL_SPIKE := Color("c9c4bc")
const COL_SPIKE_EDGE := Color("2c1810")
const COL_BEAN_EDGE := Color("2c1810")
const COL_GOAL := Color("d4a84b")
const COL_POLE := Color("6a5a4a")
const COL_POLE_ON := Color("c4a07a")
const COL_SECRET := Color("f0c020")
const COL_SKY := Color("1a100c")
const COL_MIST := Color("2a1812")
const FALL_Y := -(80.0 + 42.0) * PX

var _layout: Dictionary = {}
var _player: CharacterBody3D
var _oneways: Array = []
var _movers: Array = []
var _solids: Array = []
var _hazards: Array = []
var _winds: Array = []
var _coins: Array = []
var _poles: Array = []
var _goal_aabb := AABB()
var _goal_mesh: MeshInstance3D
var _goal_taken := false
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
var _warp_lock := 0.0
var _message := ""
var _message_t := 0.0
var _hint: Label
var _hud: CanvasLayer
var _hud_label: Label
var _fade_mats: Array = []
var _water_mat: ShaderMaterial
var _wind_mats: Array = []


func _ready() -> void:
	_player = $PlayerMaya as CharacterBody3D
	_player.camera_offset = Vector3(0.0, 1.0, CAM_DOLLY)
	_player.kill_y = -1000.0
	_hud = $UI as CanvasLayer
	_hud_label = $UI/Hud/WorldLabel as Label
	_hint = $UI/Hud/HintLabel as Label
	_layout = _load_layout()
	if _layout.is_empty():
		return
	_build_world()
	_paint_maya()
	_tag_maya_layer(_player)
	_attach_maya_lights()
	var spawn: Array = _layout["meta"]["spawn_feet_m"]
	_player.global_position = Vector3(float(spawn[0]), float(spawn[1]), float(spawn[2]))
	if _hud_label:
		var meta: Dictionary = _layout["meta"]
		_hud_label.text = "%s  ·  id %s  ·  greybox  ·  %s" % [meta["display"], meta["world_id"], meta["level_id"]]
	_style_light()
	_tick_movers()
	var late := Node.new()
	late.name = "LateSim"
	late.set_script(load("res://scripts/pilot_rio_late.gd"))
	add_child(late)
	if _wants_probe():
		var probe := Node.new()
		probe.name = "RioProbe"
		probe.set_script(load("res://scripts/rio_probe.gd"))
		add_child(probe)
	if _wants_capture():
		_capturing = true
		if _hud:
			_hud.visible = false
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
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
	_bob_coins()
	_sync_shaders()
	if not _capturing:
		_tick_play(delta)


func _process(delta: float) -> void:
	_push_fade()
	if _message_t > 0.0:
		_message_t = maxf(0.0, _message_t - delta)
		_show_hud()


func late_physics(delta: float) -> void:
	if _player == null:
		return
	if _capturing:
		_player.velocity = Vector3.ZERO
		_player.global_position = _shot_feet
	else:
		_apply_wind(delta)
		_tick_freeze(delta)
		_tick_void()
	_match_framing()


func _load_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT):
		push_error("Missing %s" % LAYOUT)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Rio layout JSON is not an object")
		return {}
	return parsed


func _style_light() -> void:
	var sun := $DirectionalLight3D as DirectionalLight3D
	if sun:
		sun.rotation_degrees = Vector3(-58.0, 28.0, 0.0)
		sun.light_color = Color("c4a07a")
		sun.light_energy = 0.22
		sun.shadow_enabled = false
	var env_node := $WorldEnvironment as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = COL_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = COL_SKY
		env.ambient_light_energy = 0.16
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.fog_enabled = true
		env.fog_light_color = COL_SKY
		env.fog_density = 0.01
		env.fog_aerial_perspective = 0.0
		env.volumetric_fog_enabled = false
		env.glow_enabled = false


func _build_world() -> void:
	var root := $WorldRoot as Node3D
	var visual := root.get_node("Visual") as Node3D
	var bank_mat := _bank_mat(COL_BANK, 0.94)
	var lip_mat := _bank_mat(COL_LIP, 0.88)
	var crate_mat := _bank_mat(COL_CRATE, 0.9)
	var stamps := {}
	for raw in _layout["platforms"]:
		var p: Dictionary = raw
		var kind := String(p["kind"])
		var body: CollisionObject3D
		if kind == "moving":
			body = AnimatableBody3D.new()
		else:
			body = StaticBody3D.new()
		body.name = String(p["id"])
		body.set_meta("kind", kind)
		body.set_meta("top_m", float(p["top_m"]))
		var mat: Material = bank_mat
		var stamp_key := "bank"
		if kind == "crate":
			mat = crate_mat
			stamp_key = "crate"
		elif kind == "oneway":
			stamp_key = "oneway"
		var dynamic := kind == "moving"
		_add_box(body, p["center_m"], p["size_m"], mat, true, dynamic)
		if dynamic:
			_add_lip(body, _vec(p["size_m"]), lip_mat)
			(body as AnimatableBody3D).sync_to_physics = true
			body.set_meta("move", p["move"])
			_movers.append(body)
		else:
			_stamp_stone(_tool(stamps, stamp_key), _tool(stamps, "lip"), _vec(p["center_m"]), _vec(p["size_m"]))
		root.add_child(body)
		_solids.append(body)
		if kind == "oneway":
			_oneways.append(body)
	var mats := {
		"bank": bank_mat,
		"oneway": bank_mat,
		"crate": crate_mat,
		"lip": lip_mat,
		"spike": _flat(COL_SPIKE, 1.0),
		"spike_edge": _flat(COL_SPIKE_EDGE, 1.0),
	}
	for raw_h in _layout["hazards"]:
		var h: Dictionary = raw_h
		var kind := String(h["kind"])
		var aabb := _aabb_of(_vec(h["center_m"]), _vec(h["size_m"]))
		_hazards.append({
			"id": String(h["id"]),
			"kind": kind,
			"aabb": aabb,
			"vx": float(h["vx"]),
			"ay": float(h["ay"]),
		})
		if kind == "spikes":
			_add_spikes(visual, h, _tool(stamps, "spike"), _tool(stamps, "spike_edge"))
		elif kind == "lava":
			_add_river(visual, h)
		elif kind == "wind":
			_add_wind(visual, h)
	_commit_stamps(visual, stamps, mats)
	var bean_mat := _bean_mat()
	var edge_mat := _flat(COL_BEAN_EDGE, 1.0)
	for raw_c in _layout["pickups"]:
		var c: Dictionary = raw_c
		var center := _vec(c["center_m"])
		var bean := _make_bean(String(c["id"]), center, Vector3(1.515, 2.084, 0.36), bean_mat, edge_mat)
		visual.add_child(bean)
		_coins.append({
			"id": String(c["id"]),
			"center": center,
			"phase": float(c["px"]["x"]) * 0.05,
			"mesh": bean,
			"taken": false,
		})
	for raw_k in _layout["checkpoints"]:
		_add_pole(visual, raw_k)
	var goal: Dictionary = _layout["goal"]
	_goal_aabb = _aabb_of(_vec(goal["center_m"]), _vec(goal["size_m"]))
	var goal_mat := _flat(COL_GOAL, 1.0)
	# render.ts null-art goal: ellipse radius 16×22 px, fill #d4a84b.
	_goal_mesh = _make_bean("G00", _vec(goal["center_m"]), Vector3(3.030, 4.166, 0.42), goal_mat, edge_mat)
	visual.add_child(_goal_mesh)
	_add_backdrop(visual)
	_add_mist(visual)


func _add_box(host: Node3D, center: Array, size: Array, mat: Material, collide: bool, with_mesh: bool) -> void:
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
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(mesh)
	if collide:
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box_shape := BoxShape3D.new()
		box_shape.size = s
		shape.shape = box_shape
		host.add_child(shape)


func _add_lip(host: Node3D, size: Vector3, mat: Material) -> void:
	var lip_h := 0.08
	var mesh := MeshInstance3D.new()
	mesh.name = "Lip"
	var box := BoxMesh.new()
	box.size = Vector3(size.x, lip_h, size.z)
	mesh.mesh = box
	mesh.position = Vector3(0.0, size.y * 0.5 - lip_h * 0.5 + 0.01, 0.0)
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mesh)


func _add_river(visual: Node3D, h: Dictionary) -> void:
	var c := _vec(h["center_m"])
	var s := _vec(h["size_m"])
	var mesh := MeshInstance3D.new()
	mesh.name = String(h["id"])
	var box := BoxMesh.new()
	# Full X/Y of the lava AABB. Z sits behind the bank faces so the stone
	# occludes the volume inside a bank and the open channel stays visible.
	box.size = Vector3(s.x, s.y, 1.6)
	mesh.mesh = box
	mesh.position = Vector3(c.x, c.y, -0.55)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://materials/m_rio_water.gdshader")
	_water_mat.set_shader_parameter("water_top", c.y + s.y * 0.5)
	_water_mat.set_shader_parameter("sim_time", 0.0)
	mesh.material_override = _water_mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(mesh)


func _add_wind(visual: Node3D, h: Dictionary) -> void:
	var c := _vec(h["center_m"])
	var s := _vec(h["size_m"])
	var mesh := MeshInstance3D.new()
	mesh.name = String(h["id"])
	var quad := QuadMesh.new()
	quad.size = Vector2(s.x, s.y)
	mesh.mesh = quad
	mesh.position = Vector3(c.x, c.y, -1.8)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/m_rio_wind.gdshader")
	mat.set_shader_parameter("dir", 1.0 if float(h["vx"]) >= 0.0 else -1.0)
	mat.set_shader_parameter("sim_time", 0.0)
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(mesh)
	_wind_mats.append(mat)


func _add_spikes(visual: Node3D, h: Dictionary, pale: SurfaceTool, edge: SurfaceTool) -> void:
	var px: Dictionary = h["px"]
	var x0 := float(px["x"]) * PX
	var w := float(px["w"]) * PX
	var height := float(px["h"]) * PX
	var bottom := (LEVEL_H_PX - float(px["y"]) - float(px["h"])) * PX
	var tooth := 16.0 * PX
	var n := maxi(1, int(round(w / tooth)))
	var tw := w / float(n)
	for i in n:
		_stamp_wedge(edge, x0 + tw * i - 0.02, tw + 0.04, bottom, height * 1.06, 1.02, 0.22)
		_stamp_wedge(pale, x0 + tw * i, tw, bottom, height, 1.14, 0.34)
	# visual is parented later via the committed mesh; wedges are in world space
	visual.set_meta("spikes_ready", true)


func _add_pole(visual: Node3D, k: Dictionary) -> void:
	var center := _vec(k["center_m"])
	var secret := bool(k["warp_random"])
	var pole := MeshInstance3D.new()
	pole.name = String(k["id"])
	var box := BoxMesh.new()
	# 2D fallback draws an 8×72 px post inside the 36×72 hitbox.
	box.size = Vector3(8.0 * PX, float(k["px"]["h"]) * PX, 0.22)
	pole.mesh = box
	pole.position = center
	pole.material_override = _flat(COL_SECRET if secret else COL_POLE, 1.0)
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(pole)
	if secret:
		var beam := MeshInstance3D.new()
		beam.name = "SecretBeam"
		var beam_box := BoxMesh.new()
		beam_box.size = Vector3(0.7, 2.0, 0.08)
		beam.mesh = beam_box
		beam.position = center + Vector3(0.0, 2.2, 0.05)
		beam.material_override = _flat(COL_SECRET, 0.82)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(beam)
	var spawn: Array = k["spawn_feet_m"]
	_poles.append({
		"id": String(k["id"]),
		"aabb": _aabb_of(center, _vec(k["size_m"])),
		"secret": secret,
		"active": false,
		"mesh": pole,
		"spawn": Vector3(float(spawn[0]), float(spawn[1]), float(spawn[2])),
	})


func _make_bean(bean_name: String, center: Vector3, bean_scale: Vector3, fill: Material, edge: Material) -> MeshInstance3D:
	var root := MeshInstance3D.new()
	root.name = bean_name
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 12
	sphere.rings = 8
	root.mesh = sphere
	root.scale = bean_scale
	root.position = center
	root.material_override = fill
	root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var outline := MeshInstance3D.new()
	outline.name = "Outline"
	outline.mesh = sphere
	outline.scale = Vector3(1.07, 1.07, 1.0)
	outline.position = Vector3(0.0, 0.0, -0.04)
	outline.material_override = edge
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(outline)
	return root


func _add_backdrop(visual: Node3D) -> void:
	var wall := MeshInstance3D.new()
	wall.name = "RiverBackdrop"
	var box := BoxMesh.new()
	box.size = Vector3(LEVEL_W_PX * PX + 16.0, 48.0, 0.4)
	wall.mesh = box
	wall.position = Vector3(LEVEL_W_PX * PX * 0.5, 16.0, -6.0)
	wall.material_override = _flat(COL_SKY, 1.0)
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(wall)


func _add_mist(visual: Node3D) -> void:
	var mat := _flat(COL_MIST, 0.2)
	var bands := [
		{"y": 5.6, "z": -2.4, "h": 2.2},
		{"y": 7.4, "z": -3.1, "h": 1.6},
		{"y": 4.6, "z": -2.0, "h": 1.1},
	]
	for i in bands.size():
		var b: Dictionary = bands[i]
		var sheet := MeshInstance3D.new()
		sheet.name = "Mist%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(LEVEL_W_PX * PX, float(b["h"]))
		sheet.mesh = quad
		sheet.position = Vector3(LEVEL_W_PX * PX * 0.5, float(b["y"]), float(b["z"]))
		sheet.material_override = mat
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(sheet)


func _paint_maya() -> void:
	var shader := load("res://materials/m_rio_maya.gdshader")
	for path in ["MeshPlaceholder/BodyCapsule", "MeshPlaceholder/HeadSphere"]:
		var node := _player.get_node_or_null(path)
		if node == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = shader
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).material_override = mat
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _tag_maya_layer(node: Node) -> void:
	if node is VisualInstance3D:
		var vis := node as VisualInstance3D
		vis.layers = vis.layers | MAYA_LAYER
	for child in node.get_children():
		_tag_maya_layer(child)


func _attach_maya_lights() -> void:
	var fill := OmniLight3D.new()
	fill.name = "LOOK001_FILL_MayaBack"
	fill.light_color = Color(1.0, 0.86, 0.70)
	fill.light_energy = 0.34
	fill.light_specular = 0.0
	fill.omni_range = 3.0
	fill.omni_attenuation = 1.5
	fill.shadow_enabled = false
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
	rim.light_cull_mask = MAYA_LAYER
	rim.position = Vector3(0.50, 1.48, -0.60)
	_player.add_child(rim)


func _bank_mat(color: Color, rough: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/m_rio_bank.gdshader")
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("roughness_value", rough)
	mat.set_shader_parameter("maya_pos", Vector3.ZERO)
	_fade_mats.append(mat)
	return mat


func _flat(color: Color, alpha: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/m_rio_flat.gdshader")
	mat.set_shader_parameter("albedo", Color(color.r, color.g, color.b, 1.0))
	mat.set_shader_parameter("alpha", alpha)
	return mat


func _bean_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/m_rio_bean.gdshader")
	mat.set_shader_parameter("dark_col", Color("6b3a1f"))
	mat.set_shader_parameter("mid_col", Color("8B4A2B"))
	mat.set_shader_parameter("rim_col", Color("CE722E"))
	return mat


func _push_fade() -> void:
	if _player == null:
		return
	var mid := _player.global_position + Vector3(0.0, float(_player._h) * 0.5, 0.0)
	for mat in _fade_mats:
		(mat as ShaderMaterial).set_shader_parameter("maya_pos", mid)


func _sync_shaders() -> void:
	if _water_mat:
		_water_mat.set_shader_parameter("sim_time", _time)
	for mat in _wind_mats:
		(mat as ShaderMaterial).set_shader_parameter("sim_time", _time)


func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _aabb_of(center: Vector3, size: Vector3) -> AABB:
	return AABB(center - size * 0.5, size)


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
		var mesh := MeshInstance3D.new()
		mesh.name = "Stamp_%s" % key
		mesh.mesh = st.commit()
		mesh.material_override = mats[key]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(mesh)


func _stamp_stone(body: SurfaceTool, lip: SurfaceTool, c: Vector3, s: Vector3) -> void:
	_stamp_box(body, c, s)
	var lip_h := 0.08
	_stamp_box(lip, c + Vector3(0.0, s.y * 0.5 - lip_h * 0.5 + 0.012, 0.0), Vector3(s.x, lip_h, s.z * 0.98))


func _stamp_box(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var hx := s.x * 0.5
	var hy := s.y * 0.5
	var hz := s.z * 0.5
	_stamp_face(st, c + Vector3(0, 0, hz), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0), hx, hy)
	_stamp_face(st, c + Vector3(0, 0, -hz), Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0), hx, hy)
	_stamp_face(st, c + Vector3(hx, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0), hz, hy)
	_stamp_face(st, c + Vector3(-hx, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), hz, hy)
	_stamp_face(st, c + Vector3(0, hy, 0), Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), hx, hz)
	_stamp_face(st, c + Vector3(0, -hy, 0), Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), hx, hz)


func _stamp_face(st: SurfaceTool, c: Vector3, _n: Vector3, right: Vector3, up: Vector3, hx: float, hy: float) -> void:
	var a := c - right * hx - up * hy
	var b := c + right * hx - up * hy
	var d := c + right * hx + up * hy
	var e := c - right * hx + up * hy
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(d)
	st.add_vertex(a)
	st.add_vertex(d)
	st.add_vertex(e)


func _stamp_wedge(st: SurfaceTool, x: float, w: float, bottom: float, h: float, z_near: float, z_far: float) -> void:
	var bl := Vector3(x, bottom, z_near)
	var br := Vector3(x + w, bottom, z_near)
	var ap := Vector3(x + w * 0.5, bottom + h, z_near)
	var bl2 := Vector3(x, bottom, z_far)
	var br2 := Vector3(x + w, bottom, z_far)
	var ap2 := Vector3(x + w * 0.5, bottom + h, z_far)
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


func _match_framing() -> void:
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var offset: Vector3 = _player.camera_offset
	var focus := cam.global_position - offset
	var min_x := VIEW_W_M * 0.5
	var max_x := LEVEL_W_PX * PX - min_x
	var max_y := (LEVEL_H_PX - 270.0) * PX
	var min_y := 270.0 * PX
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
	_warp_lock = maxf(0.0, _warp_lock - delta)
	_hazards_touch()
	if _status != "playing":
		return
	_collect_coins()
	_touch_poles()
	_touch_goal()
	_show_hud()


func _hazards_touch() -> void:
	if _invuln > 0.0:
		return
	var body := _hurt_body()
	for h in _hazards:
		var kind := String(h["kind"])
		if kind == "wind":
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
		print("RIO_OVER")
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
	if _status == "over" or _status == "win":
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
	for pole in _poles:
		if not _overlap(body, pole["aabb"]):
			continue
		var secret := bool(pole["secret"])
		var active := bool(pole["active"])
		if not jump:
			continue
		if active and secret:
			if _warp_lock > 0.0:
				continue
			_warp_lock = 0.4
			_pole_lock = 0.4
			_begin_warp()
			continue
		pole["active"] = true
		var mesh := pole["mesh"] as MeshInstance3D
		var mat := mesh.material_override as ShaderMaterial
		if mat and not secret:
			mat.set_shader_parameter("albedo", COL_POLE_ON)
		var spawn: Vector3 = pole["spawn"]
		var xf: Transform3D = _player._spawn
		xf.origin = spawn
		_player._spawn = xf
		_pole_lock = 0.35
		if secret:
			_say("Tótem guardado — W otra vez", 1.6)
			print("RIO_SECRET warpRandom stub")
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
	print("RIO_GOAL taken")


func _begin_warp() -> void:
	print("RIO_WARP world=secret level=stub no 3D scene")
	_say("Destello (sin escena 3D)", 2.4)
	_player._respawn()


func _tick_void() -> void:
	if _capturing or _status != "playing":
		return
	if _player.global_position.y < FALL_Y:
		_kill()


func _apply_wind(delta: float) -> void:
	if _status != "playing":
		return
	var body := _full_body()
	var mass := 1.0
	for h in _hazards:
		if String(h["kind"]) != "wind":
			continue
		if not _overlap(body, h["aabb"]):
			continue
		var dvx := float(h["vx"]) / mass * PX * delta
		var dvy := float(h["ay"]) / mass * PX * delta
		_player.velocity.x += dvx
		_player.velocity.y -= dvy
		_player.global_position.x += dvx * delta
		_player.global_position.y -= dvy * delta


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
	var dropping: bool = float(_player._drop_timer) > 0.0
	for body in _oneways:
		var enable: bool = (not dropping) and feet >= float(body.get_meta("top_m")) - 0.06
		var shape := body.get_node("CollisionShape3D") as CollisionShape3D
		shape.disabled = not enable


func _wants_capture() -> bool:
	if OS.get_environment("RIO_CAPTURE") != "":
		return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rio-capture"):
			return true
	return false


func _wants_check() -> bool:
	if OS.get_environment("RIO_CHECK") != "":
		return true
	for a in OS.get_cmdline_user_args():
		if a == "--rio-check":
			return true
	return false


func _wants_probe() -> bool:
	if OS.get_environment("RIO_PROBE") != "":
		return true
	for a in OS.get_cmdline_user_args():
		if a == "--rio-probe":
			return true
	return false


func _capture_dir() -> String:
	var out := OS.get_environment("RIO_CAPTURE")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rio-capture="):
			out = a.substr("--rio-capture=".length())
	if out == "":
		out = "user://"
	if not out.ends_with("/"):
		out += "/"
	return out


func _print_counts() -> void:
	print("RIO_CHECK platforms=%d hazards=%d pickups=%d checks=%d falls=0 goal=1" % [
		_layout["platforms"].size(), _layout["hazards"].size(), _layout["pickups"].size(), _layout["checkpoints"].size()
	])
	print("RIO_CAM offset=%s kill_y=%.1f" % [_player.camera_offset, _player.kill_y])


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
		_write_perf(out, String(shot["id"]))
		_player.visible = false
		await RenderingServer.frame_post_draw
		var bg := get_viewport().get_texture().get_image()
		bg.save_png("%s3d_%s_bg.png" % [out, String(shot["id"])])
		_write_perf(out, String(shot["id"]) + "_world")
		_player.visible = true
		print("RIO_SHOT %s" % path)
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
	print("RIO_CAM shot=%s offset=%s fov=%.2f formula_h=%.4f plane_h=%.4f plane_w=%.4f vp=%sx%s maya_px=%.2f" % [
		shot, _player.camera_offset, fov, vis_h, absf(top.y - bot.y), absf(right.x - left.x),
		vp.x, vp.y, absf(feet.y - head.y)
	])
	for c in _coins:
		var mesh := c["mesh"] as MeshInstance3D
		if not mesh.visible:
			continue
		var center := mesh.global_position
		var half := Vector2(0.22 * mesh.scale.x, 0.22 * mesh.scale.y)
		var p0 := cam.unproject_position(center + Vector3(-half.x, 0.0, 0.0))
		var p1 := cam.unproject_position(center + Vector3(half.x, 0.0, 0.0))
		var p2 := cam.unproject_position(center + Vector3(0.0, half.y, 0.0))
		var p3 := cam.unproject_position(center + Vector3(0.0, -half.y, 0.0))
		var bw := absf(p1.x - p0.x)
		var bh := absf(p3.y - p2.y)
		var mid := Vector2((p0.x + p1.x) * 0.5, (p2.y + p3.y) * 0.5)
		if mid.x < 8.0 or mid.y < 8.0 or mid.x > vp.x - 8.0 or mid.y > vp.y - 8.0:
			continue
		print("RIO_BEAN shot=%s id=%s px=%.1fx%.1f at=(%.0f,%.0f)" % [shot, c["id"], bw, bh, mid.x, mid.y])


func _write_perf(out: String, shot: String) -> void:
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
	print("RIO_PERF %s" % line.strip_edges())
