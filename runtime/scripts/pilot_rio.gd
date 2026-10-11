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

const COL_BANK := Color("5c4030")
const COL_LIP := Color("8a6244")
const COL_CRATE := Color("6b4632")
const COL_SPIKE := Color("c9c4bc")
const COL_SPIKE_EDGE := Color("2c1810")
const COL_BEAN_EDGE := Color("2c1810")
const COL_GOAL := Color("d4a84b")
const COL_POLE := Color("6a5a4a")
const COL_POLE_ON := Color("c4a07a")
const COL_SECRET := Color("f0c020")
const COL_SKY := Color("1a100c")
const COL_MIST := Color("c48458")
const TOTEM_GLB := "res://models/totem_warp_cuyabeno.glb"
const COL_WOOD := Color("654B34")
const COL_WOOD_DARK := Color("3E2E21")
const COL_POD_Y := Color("D6AB3D")
const COL_POD_O := Color("CE722E")
const COL_POD_R := Color("A64B36")
const COL_BEAM := Color("FFD16A")
const COL_VINE := Color("3C5634")
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
var _input_driver: Node = null


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
		_input_driver = probe
	if OS.get_environment("RIO_WARP") != "":
		var warp := Node.new()
		warp.name = "RioWarpCheck"
		warp.set_script(load("res://scripts/rio_warp_check.gd"))
		add_child(warp)
		_input_driver = warp
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
	# Same physics frame as Maya, and before her, so just_pressed('jump') lands.
	if _input_driver and _input_driver.has_method("drive"):
		_input_driver.call("drive", delta)
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
		env.background_color = Color("5c4032")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = COL_SKY
		env.ambient_light_energy = 0.16
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.fog_enabled = true
		env.fog_light_color = Color("c4895a")
		env.fog_density = 0.02
		env.fog_aerial_perspective = 0.42
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
	# Vertical sheet the size of the lava AABB. A box's top face read as a
	# fake amber floor from this camera; the 2D draws a side-on rectangle.
	var quad := QuadMesh.new()
	quad.size = Vector2(s.x, s.y)
	mesh.mesh = quad
	mesh.position = Vector3(c.x, c.y, -0.45)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://materials/m_rio_water.gdshader")
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
		# In front of the bank's near face (z = +1.33) so the teeth aren't buried.
		_stamp_wedge(edge, x0 + tw * i - 0.02, tw + 0.04, bottom, height * 1.06, 1.50, 1.22)
		_stamp_wedge(pale, x0 + tw * i, tw, bottom, height, 1.62, 1.30)
	# visual is parented later via the committed mesh; wedges are in world space
	visual.set_meta("spikes_ready", true)


func _add_pole(visual: Node3D, k: Dictionary) -> void:
	var center := _vec(k["center_m"])
	var secret := bool(k["warp_random"])
	var pole := MeshInstance3D.new()
	pole.name = String(k["id"])
	if secret:
		# Hitbox stays the layout AABB. The mesh is the Kakaw post, not a collider.
		var base_y := center.y - float(k["size_m"][1]) * 0.5
		pole.position = Vector3(center.x, base_y, center.z)
		_mount_kakaw_totem(pole)
	else:
		var box := BoxMesh.new()
		# 2D fallback draws an 8×72 px post inside the 36×72 hitbox.
		box.size = Vector3(8.0 * PX, float(k["px"]["h"]) * PX, 0.22)
		pole.mesh = box
		pole.position = center
		pole.material_override = _flat(COL_POLE, 1.0)
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(pole)
	var spawn: Array = k["spawn_feet_m"]
	_poles.append({
		"id": String(k["id"]),
		"aabb": _aabb_of(center, _vec(k["size_m"])),
		"secret": secret,
		"active": false,
		"mesh": pole,
		"spawn": Vector3(float(spawn[0]), float(spawn[1]), float(spawn[2])),
	})


func _mount_kakaw_totem(anchor: Node3D) -> void:
	var spawned := false
	if ResourceLoader.exists(TOTEM_GLB):
		var packed: Resource = load(TOTEM_GLB)
		if packed is PackedScene:
			var inst := (packed as PackedScene).instantiate()
			inst.name = "TotemWarpCuyabeno"
			anchor.add_child(inst)
			_recolor_totem(inst)
			var spawn := _find_named(inst, "VFX_WarpBeam_Spawn")
			var origin := Marker3D.new()
			origin.name = "BeamOrigin"
			if spawn:
				spawn.add_child(origin)
			else:
				origin.position = Vector3(0.0, 3.03, 0.0)
				anchor.add_child(origin)
			_add_warm_beam(origin)
			spawned = true
	if not spawned:
		_add_carved_fallback(anchor)
		var origin := Marker3D.new()
		origin.name = "BeamOrigin"
		origin.position = Vector3(0.0, 3.03, 0.0)
		anchor.add_child(origin)
		_add_warm_beam(origin)
	_add_yor_pods(anchor)


func _recolor_totem(node: Node) -> void:
	var n := node.name.to_lower()
	if "lod1" in n or "maya" in n or "stub" in n:
		if node is Node3D:
			(node as Node3D).visible = false
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var kind := _totem_surface_kind(mi.get_active_material(s))
				if kind == "cyan":
					mi.set_surface_override_material(s, _flat(COL_WOOD_DARK, 1.0))
				elif kind == "gold":
					mi.set_surface_override_material(s, _flat(Color("c4a05a"), 1.0))
				elif kind == "vine":
					mi.set_surface_override_material(s, _flat(COL_VINE, 1.0))
				else:
					mi.set_surface_override_material(s, _flat(COL_WOOD, 1.0))
	for child in node.get_children():
		_recolor_totem(child)


func _totem_surface_kind(mat: Material) -> String:
	if mat == null:
		return "wood"
	var label := mat.resource_name.to_lower()
	if "cyan" in label:
		return "cyan"
	if "gold" in label:
		return "gold"
	if "liana" in label or "vine" in label:
		return "vine"
	if mat is StandardMaterial3D:
		var em: Color = (mat as StandardMaterial3D).emission
		if em.b > em.r + 0.25 and em.g > em.r + 0.15:
			return "cyan"
	if "stone" in label:
		return "wood"
	return "wood"


func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found:
			return found
	return null


func _add_warm_beam(origin: Node3D) -> void:
	# Gold cone only. The LOOK preview's cyan core stays out of the river.
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = 0.07
	mesh.top_radius = 0.34
	mesh.height = 5.6
	mesh.radial_segments = 8
	var beam := MeshInstance3D.new()
	beam.name = "WarmBeam"
	beam.mesh = mesh
	beam.position = Vector3(0.0, mesh.height * 0.5, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/warp_beam.gdshader")
	mat.set_shader_parameter("beam_color", COL_BEAM)
	# Additive. Above ~0.9 the gold clips to white and the cone reads as a bar.
	mat.set_shader_parameter("strength", 0.72)
	mat.set_shader_parameter("height_m", mesh.height)
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	origin.add_child(beam)


func _add_yor_pods(anchor: Node3D) -> void:
	# Camera looks from +Z. Pods sit on the left face so they read beside Maya.
	var pods := [
		{"at": Vector3(-0.58, 2.22, 0.46), "color": COL_POD_Y},
		{"at": Vector3(-0.50, 1.42, 0.50), "color": COL_POD_O},
		{"at": Vector3(-0.62, 0.68, 0.44), "color": COL_POD_R},
	]
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.62
	sphere.radial_segments = 10
	sphere.rings = 6
	for i in pods.size():
		var spec: Dictionary = pods[i]
		var pod := MeshInstance3D.new()
		pod.name = "PodYOR%d" % i
		pod.mesh = sphere
		pod.position = spec["at"]
		pod.material_override = _flat(spec["color"], 1.0)
		pod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anchor.add_child(pod)


func _add_carved_fallback(anchor: Node3D) -> void:
	var wood := _flat(COL_WOOD, 1.0)
	var dark := _flat(COL_WOOD_DARK, 1.0)
	var parts := [
		{"at": Vector3(0, 0.18, 0), "size": Vector3(0.72, 0.36, 0.72), "mat": dark},
		{"at": Vector3(0, 0.95, 0), "size": Vector3(0.46, 1.10, 0.46), "mat": wood},
		{"at": Vector3(0, 1.55, 0), "size": Vector3(0.62, 0.12, 0.62), "mat": dark},
		{"at": Vector3(0, 2.08, 0), "size": Vector3(0.38, 0.90, 0.38), "mat": wood},
		{"at": Vector3(0, 2.55, 0), "size": Vector3(0.52, 0.12, 0.52), "mat": dark},
	]
	for i in parts.size():
		var spec: Dictionary = parts[i]
		var mesh := MeshInstance3D.new()
		mesh.name = "CarvedPost%d" % i
		var box := BoxMesh.new()
		box.size = spec["size"]
		mesh.mesh = box
		mesh.position = spec["at"]
		mesh.material_override = spec["mat"]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anchor.add_child(mesh)


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
	outline.scale = Vector3(1.18, 1.18, 1.0)
	outline.position = Vector3(0.0, 0.0, -0.08)
	outline.material_override = edge
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(outline)
	return root


func _add_backdrop(visual: Node3D) -> void:
	# Warm sky behind a broken canopy line. The mass stays dark where Maya
	# and the beans sit; the crowns poke into the fog so the frame is not a wall.
	var sky := SurfaceTool.new()
	var far := SurfaceTool.new()
	var mass_a := SurfaceTool.new()
	var mass_b := SurfaceTool.new()
	var trunk := SurfaceTool.new()
	var cane := SurfaceTool.new()
	sky.begin(Mesh.PRIMITIVE_TRIANGLES)
	far.begin(Mesh.PRIMITIVE_TRIANGLES)
	mass_a.begin(Mesh.PRIMITIVE_TRIANGLES)
	mass_b.begin(Mesh.PRIMITIVE_TRIANGLES)
	trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	cane.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span := LEVEL_W_PX * PX + 36.0
	_stamp_box(sky, Vector3(LEVEL_W_PX * PX * 0.5, 22.0, -30.0), Vector3(span, 48.0, 0.4))
	var x := -6.0
	var i := 0
	while x < LEVEL_W_PX * PX + 8.0:
		var top := _foliage_top(x)
		var peak := top + 2.4 + float(i % 5) * 1.15
		var mass: SurfaceTool = mass_a if i % 2 == 0 else mass_b
		var y := 7.0
		while y < top:
			var rx := 4.6 + float(i % 3) * 0.45
			_disc(mass, Vector3(x + float(i % 2) * 0.7, y, -8.2), rx, 3.4)
			y += 4.6
		_disc(mass, Vector3(x + 1.1, peak - 1.8, -7.4), 3.8, 2.9)
		_disc(far, Vector3(x + 2.4, peak + 1.6, -16.0 - float(i % 3)), 5.2, 3.6)
		_disc(far, Vector3(x - 1.0, peak + 4.2, -20.0), 4.4, 2.8)
		if not _near_shot_x(x + 0.8) and not _near_bean_x(x + 0.8):
			var th := peak - 3.0
			_stamp_box(trunk, Vector3(x + 0.8, 4.0 + th * 0.5, -6.4), Vector3(0.55, th, 0.22))
		x += 5.4
		i += 1
	var cx := 1.5
	var ci := 0
	while cx < LEVEL_W_PX * PX:
		for k in 4:
			var lean := 0.55 if (k + ci) % 2 == 0 else -0.4
			var h := 2.2 + float((k + ci) % 3) * 0.55
			_cane(cane, Vector3(cx + float(k) * 0.34, 4.02, -1.55), h, lean)
		cx += 11.0
		ci += 1
	for fx in [26.0, 68.0, 118.0, 158.0]:
		for k in 3:
			_cane(cane, Vector3(fx + float(k) * 0.4, 4.1, 3.1), 2.6 + float(k) * 0.35, 0.3 if k != 1 else -0.35)
	_commit_layer(visual, "SelvaSky", sky, _sil(Color("6a4530")))
	_commit_layer(visual, "SelvaFar", far, _sil(Color("1e3428")))
	# Near mass stays a warm dark so Maya and the bean rim hold 4.4.
	# The green is the far crown layer, the lianas and the cane.
	_commit_layer(visual, "SelvaMassA", mass_a, _flat(Color("14110e"), 1.0))
	_commit_layer(visual, "SelvaMassB", mass_b, _flat(Color("1c1612"), 1.0))
	_commit_layer(visual, "SelvaTrunk", trunk, _flat(Color("3a2c22"), 1.0))
	_commit_layer(visual, "SelvaCane", cane, _flat(Color("b89658"), 1.0))
	_add_foreground_lianas(visual)


func _foliage_top(x: float) -> float:
	var top := 14.8
	var guards := [
		[4.54, 14.6],
		[57.0, 17.2],
		[96.2, 25.2],
		[136.5, 14.6],
		[194.5, 25.2],
	]
	for g in guards:
		if absf(x - float(g[0])) < 2.6:
			top = maxf(top, float(g[1]))
	for raw in _layout["pickups"]:
		var p: Array = raw["center_m"]
		if absf(x - float(p[0])) < 1.7:
			top = maxf(top, float(p[1]) + 1.2)
	return top


func _near_bean_x(x: float) -> bool:
	for raw in _layout["pickups"]:
		var p: Array = raw["center_m"]
		if absf(x - float(p[0])) < 1.15:
			return true
	return false


func _near_shot_x(x: float) -> bool:
	for s in [4.54, 57.0, 96.2, 136.5, 194.5]:
		if absf(x - s) < 1.7:
			return true
	return false


func _disc(st: SurfaceTool, c: Vector3, rx: float, ry: float) -> void:
	var n := 12
	var prev := c + Vector3(rx, 0.0, 0.0)
	for i in n:
		var a := TAU * float(i + 1) / float(n)
		var p := c + Vector3(cos(a) * rx, sin(a) * ry, 0.0)
		_tri(st, c, prev, p)
		prev = p


func _cane(st: SurfaceTool, base: Vector3, h: float, lean: float) -> void:
	var w := 0.11
	var top := base + Vector3(lean, h, 0.04)
	var a := base + Vector3(-w, 0.0, 0.0)
	var b := base + Vector3(w, 0.0, 0.0)
	var c := top + Vector3(w * 0.4, 0.0, 0.0)
	var d := top + Vector3(-w * 0.4, 0.0, 0.0)
	_tri(st, a, b, c)
	_tri(st, a, c, d)


func _commit_layer(visual: Node3D, layer_name: String, st: SurfaceTool, mat: Material) -> void:
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = layer_name
	mesh.mesh = st.commit()
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(mesh)


func _sil(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/m_rio_sil.gdshader")
	mat.set_shader_parameter("albedo", color)
	return mat


func _add_foreground_lianas(visual: Node3D) -> void:
	# In front of the lane ( +Z ), curved, kept off the five Maya stills.
	var xs := [14.0, 32.0, 44.0, 72.0, 82.0, 112.0, 124.0, 152.0, 172.0, 186.0]
	var mat := _flat(COL_VINE, 1.0)
	for i in xs.size():
		var x: float = xs[i]
		var bow := 2.2 if i % 2 == 0 else -2.0
		var pts := PackedVector3Array()
		var n := 9
		for k in n + 1:
			var t := float(k) / float(n)
			var y := lerpf(23.5, 8.2, t)
			var sag := sin(t * PI) * bow
			pts.append(Vector3(x + sag, y, 3.55 + sin(t * PI) * 0.45))
		_ribbon(visual, "LianaFG%d" % i, pts, 0.16, mat)
		if i % 2 == 0:
			var pts2 := PackedVector3Array()
			for k in n + 1:
				var t := float(k) / float(n)
				var y := lerpf(21.0, 11.0, t)
				pts2.append(Vector3(x + 1.4 - sin(t * PI) * bow * 0.45, y, 4.15))
			_ribbon(visual, "LianaFG%dB" % i, pts2, 0.09, mat)
		var mid := PackedVector3Array()
		for k in n + 1:
			var t := float(k) / float(n)
			var y := lerpf(26.0, 13.5, t)
			mid.append(Vector3(x - 2.2 + sin(t * PI) * bow, y, -3.4))
		_ribbon(visual, "LianaMid%d" % i, mid, 0.1, mat)


func _ribbon(visual: Node3D, rname: String, pts: PackedVector3Array, half_w: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var dir := b - a
		var side := dir.cross(Vector3(0.0, 0.0, 1.0))
		if side.length_squared() < 0.0001:
			side = Vector3(1.0, 0.0, 0.0)
		side = side.normalized()
		var a0 := a + side * half_w
		var a1 := a - side * half_w
		var b0 := b + side * half_w
		var b1 := b - side * half_w
		_tri(st, a0, b0, a1)
		_tri(st, a1, b0, b1)
	_commit_layer(visual, rname, st, mat)


func _add_mist(visual: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/m_rio_mist.gdshader")
	mat.set_shader_parameter("albedo", COL_MIST)
	mat.set_shader_parameter("alpha", 0.46)
	var bands := [
		{"y": 5.4, "z": -3.2, "h": 2.8, "a": 0.5},
		{"y": 7.2, "z": -4.4, "h": 1.8, "a": 0.28},
		{"y": 4.3, "z": -2.4, "h": 1.5, "a": 0.34},
	]
	for i in bands.size():
		var b: Dictionary = bands[i]
		var sheet := MeshInstance3D.new()
		sheet.name = "Mist%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(LEVEL_W_PX * PX + 8.0, float(b["h"]))
		sheet.mesh = quad
		sheet.position = Vector3(LEVEL_W_PX * PX * 0.5, float(b["y"]), float(b["z"]))
		var band := mat.duplicate() as ShaderMaterial
		band.set_shader_parameter("alpha", float(b["a"]))
		sheet.material_override = band
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(sheet)


func _paint_maya() -> void:
	# CSG ignored material_override under the GL capture and stayed a lit grey.
	# Mesh instances carry the cream shader. Collision stays the capsule.
	var shader: Shader = load("res://materials/m_rio_maya.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var holder := _player.get_node("MeshPlaceholder") as Node3D
	var body := holder.get_node_or_null("BodyCapsule")
	if body:
		body.visible = false
	var head := holder.get_node_or_null("HeadSphere")
	if head:
		head.visible = false
	var torso := MeshInstance3D.new()
	torso.name = "MayaBody"
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.45
	torso.mesh = cap
	torso.position = Vector3(0.0, 0.78, 0.0)
	torso.material_override = mat
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(torso)
	var skull := MeshInstance3D.new()
	skull.name = "MayaHead"
	var sphere := SphereMesh.new()
	sphere.radius = 0.26
	sphere.height = 0.52
	skull.mesh = sphere
	skull.position = Vector3(0.0, 1.62, 0.0)
	skull.material_override = mat
	skull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(skull)


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
