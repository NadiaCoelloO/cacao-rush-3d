extends Node
## selva-1 play layer: 21 platforms, 6 hazards, pickups, 2 poles, goal.
## Layout 1:1 from Cacao.Game levels.ts / sim.ts (24 px = 1 m). Y shifted so
## the entrance floor top is 0 and oneway #0 sits at 6.67 m.
## player_maya.gd, its feel, and Maya's collision capsule are not modified.
##
## sim.ts: hazard inset (x+4, y+8, w-8, h-10), coin radius 28 px,
## kill invuln 0.8 / hitstop 0.08 / deathT 0.55 / respawn invuln 1.1 / MAX_LIVES 5,
## checkpoint poleLock 0.35, goal winT 1.35. Oneway drops while feet are below
## the lip (jump-through) and while player_maya's _drop_timer is running.

const LAYOUT := "res://data/selva1_layout.json"
const LEVEL_H_PX := 1024.0
const LEVEL_W_PX := 4864.0
const PX := 1.0 / 24.0
const PW := 26.0 * PX
const VIEW_W_M := 960.0 * PX
const VIEW_H_M := 540.0 * PX
const CAM_DOLLY := 24.1256
const Y_SHIFT := 13.333333
const MAYA_LAYER := 2
const COL_EARTH := Color(0.20, 0.14, 0.09)
const COL_EARTH_LIP := Color(0.28, 0.20, 0.12)
const COL_WET := Color(0.10, 0.08, 0.06)
const COL_CRATE := Color(0.36, 0.24, 0.14)
const COL_CRUMBLE := Color(0.16, 0.11, 0.07)
const COL_SPIKE := Color("c9c4bc")
const COL_SPIKE_EDGE := Color("2c1810")
const COL_FROG := Color(0.28, 0.46, 0.22)
const COL_ROCK := Color(0.38, 0.30, 0.22)
const COL_WIND := Color(0.78, 0.86, 0.72)
const COL_BEAN := Color("8b4a2b")
const COL_POLE := Color("6a5a4a")
const COL_POLE_ON := Color("3d8a72")

var _layout: Dictionary = {}
var _player: CharacterBody3D
var _oneways: Array = []
var _crumbles: Array = []
var _movers: Array = []
var _hazards: Array = []
var _coins: Array = []
var _poles: Array = []
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
var _root: Node3D
var _feel := false


func _ready() -> void:
	var pilot := get_parent()
	_player = pilot.get_node_or_null("PlayerMaya") as CharacterBody3D
	if _player == null:
		return
	# The tscn export is ignored if it sits above `script =`. Set it here too.
	_player.camera_offset = Vector3(0.0, 1.0, CAM_DOLLY)
	_layout = _load_layout()
	if _layout.is_empty():
		return
	_feel = _is_feel_harness()
	_disable_slice_boxes(pilot, _feel)
	_root = pilot.get_node_or_null("WorldRoot") as Node3D
	if _root == null:
		return
	# Feel harness keeps the 24 m CSG floor + 1 m ledge + CSGOneway lip.
	# Play/capture builds the real selva-1 strip and uses the 1:1 spawn.
	if _feel:
		return
	_build_world()
	var spawn: Array = _layout["meta"]["spawn_feet_m"]
	var feet := Vector3(float(spawn[0]), float(spawn[1]), float(spawn[2]))
	_player.global_position = feet
	var xf: Transform3D = _player._spawn
	xf.origin = feet
	_player._spawn = xf
	_hint = pilot.get_node_or_null("UI/Hud/HintLabel") as Label
	var hud_label := pilot.get_node_or_null("UI/Hud/WorldLabel") as Label
	if hud_label:
		var meta: Dictionary = _layout["meta"]
		hud_label.text = "%s  ·  id %s  ·  selva-1  ·  %s" % [meta["display"], meta["world_id"], meta["level_id"]]
	var late := Node.new()
	late.name = "LateSim"
	late.set_script(load("res://scripts/selva1_play_late.gd"))
	add_child(late)
	if _wants_capture():
		_capturing = true
		var hud := pilot.get_node_or_null("UI")
		if hud:
			hud.visible = false
		set_physics_process(true)
		_run_capture()
	elif _wants_check():
		_print_counts()
		get_tree().quit()


func _physics_process(delta: float) -> void:
	if _player == null or _feel:
		return
	if not _capturing and _status == "playing" and _hitstop <= 0.0:
		_time += delta
	_tick_movers()
	_tick_oneways()
	_tick_rocks()
	_bob_coins()
	if not _capturing:
		_tick_play(delta)


func _process(delta: float) -> void:
	if _message_t > 0.0:
		_message_t = maxf(0.0, _message_t - delta)
		_show_hud()


func late_physics(delta: float) -> void:
	if _player == null or _feel:
		return
	_tick_crumbles(delta)
	if _capturing:
		_player.velocity = Vector3.ZERO
		_player.global_position = _shot_feet
	else:
		_apply_wind(delta)
		_tick_freeze(delta)
	_match_framing()


func _is_feel_harness() -> bool:
	# maya_feel_check instantiates the packed scene into its own SceneTree.
	# OS.has_feature("headless") is not set for `--headless -s` on 4.2.2.
	var tree := get_tree()
	if tree == null:
		return true
	return tree.current_scene != get_parent()


func _load_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT):
		push_error("Missing %s" % LAYOUT)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("selva-1 layout JSON is not an object")
		return {}
	return parsed


func _disable_slice_boxes(pilot: Node3D, keep_feel_ledge: bool) -> void:
	# Feel: CSGFloor (24 m, top y=0) + CSGPlatform (1 m ledge) + CSGOneway lip.
	# Play/capture: all three off. P00 is the floor; P01 is the real drop-through.
	for path in [
		"WorldRoot/FloorPlaceholder/CSGFloor",
		"WorldRoot/FloorPlaceholder/CSGPlatform",
		"WorldRoot/PlatformOnewayAnchor/PlatformOnewayPlaceholder/CSGOneway",
	]:
		var n: Node = pilot.get_node_or_null(path)
		if n is CSGShape3D:
			(n as CSGShape3D).use_collision = keep_feel_ledge


func _build_world() -> void:
	var mats := {
		"solid": _earth(COL_EARTH, 0.86),
		"oneway": _earth(COL_EARTH_LIP, 0.8),
		"moving": _earth(COL_EARTH_LIP, 0.82),
		"crate": _earth(COL_CRATE, 0.84),
		"crumble": _earth(COL_CRUMBLE, 0.74),
		"lip": _earth(COL_EARTH_LIP, 0.78),
	}
	var play := Node3D.new()
	play.name = "Selva1Geo"
	_root.add_child(play)
	for raw in _layout["platforms"]:
		var p: Dictionary = raw
		var kind := String(p["kind"])
		var mat_key := kind if mats.has(kind) else "solid"
		var body: CollisionObject3D = AnimatableBody3D.new() if kind == "moving" else StaticBody3D.new()
		body.name = String(p["id"])
		body.set_meta("kind", kind)
		body.set_meta("top_m", float(p["top_m"]))
		_add_box(body, p["center_m"], p["size_m"], mats[mat_key], true)
		if kind == "moving" or kind == "crumble" or kind == "oneway":
			_add_lip(body, _vec(p["size_m"]), mats["lip"])
		play.add_child(body)
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
	var visual := Node3D.new()
	visual.name = "Selva1Actors"
	play.add_child(visual)
	for raw_h in _layout["hazards"]:
		var h: Dictionary = raw_h
		var kind := String(h["kind"])
		var rec := {
			"id": String(h["id"]),
			"kind": kind,
			"aabb": _aabb_of(_vec(h["center_m"]), _vec(h["size_m"])),
			"period": float(h["period"]) if h.get("period") != null else 0.0,
			"phase": float(h["phase"]) if h.get("phase") != null else 0.0,
			"ox": float(h["ox"]) if h.get("ox") != null else float(h["px"]["x"]),
			"oy": float(h["oy"]) if h.get("oy") != null else float(h["px"]["y"]),
			"ax": float(h["ax"]) if h.get("ax") != null else 0.0,
			"ay": float(h["ay"]) if h.get("ay") != null else 0.0,
			"vx": float(h["vx"]) if h.get("vx") != null else 0.0,
			"range": float(h["range"]) if h.get("range") != null else 0.0,
			"mesh": null,
		}
		if kind == "spikes":
			_add_spikes(visual, h)
		elif kind == "frog":
			rec["mesh"] = _add_critter(visual, String(h["id"]), _vec(h["center_m"]), COL_FROG, 0.28, 0.22)
		elif kind == "rock":
			rec["mesh"] = _add_critter(visual, String(h["id"]), _vec(h["center_m"]), COL_ROCK, 0.32, 0.28)
		elif kind == "wind":
			_add_wind_card(visual, h)
		_hazards.append(rec)
	var bean_mat := _bean_mat()
	for raw_c in _layout["pickups"]:
		var c: Dictionary = raw_c
		var center := _vec(c["center_m"])
		var bean := MeshInstance3D.new()
		bean.name = String(c["id"])
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		sphere.radial_segments = 10
		sphere.rings = 6
		bean.mesh = sphere
		bean.scale = Vector3(1.515, 2.084, 0.36)
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
		var pole := MeshInstance3D.new()
		pole.name = String(k["id"])
		var box := BoxMesh.new()
		box.size = Vector3(0.33, _vec(k["size_m"]).y, 0.28)
		pole.mesh = box
		pole.position = _vec(k["center_m"])
		pole.material_override = _mat(COL_POLE, 0.8)
		visual.add_child(pole)
		var px: Dictionary = k["px"]
		var spawn_feet := Vector3(
			(float(px["x"]) + 4.0 + 13.0) * PX,
			(LEVEL_H_PX - float(px["y"]) - float(px["h"])) * PX - Y_SHIFT,
			0.0
		)
		_poles.append({
			"id": String(k["id"]),
			"aabb": _aabb_of(_vec(k["center_m"]), _vec(k["size_m"])),
			"active": false,
			"mesh": pole,
			"spawn": spawn_feet,
		})
	var goal: Dictionary = _layout["goal"]
	_goal_aabb = _aabb_of(_vec(goal["center_m"]), _vec(goal["size_m"]))
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


func _add_box(host: Node3D, center: Array, size: Array, mat: Material, collide: bool) -> void:
	var c := Vector3(float(center[0]), float(center[1]), float(center[2]))
	var s := Vector3(float(size[0]), float(size[1]), float(size[2]))
	host.position = c
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


func _add_spikes(visual: Node3D, h: Dictionary) -> void:
	var px: Dictionary = h["px"]
	var tooth := 16.0
	var n := maxi(1, int(round(float(px["w"]) / tooth)))
	var bw := float(px["w"]) / float(n)
	var origin_x := float(h["center_m"][0]) - float(h["size_m"][0]) * 0.5
	var bottom := float(h["center_m"][1]) - float(h["size_m"][1]) * 0.5
	var height := float(h["size_m"][1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var x := origin_x + float(i) * bw * PX
		var w := bw * PX
		_stamp_wedge(st, x, w, bottom, height, 0.12, 0.02)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = String(h["id"])
	mi.mesh = st.commit()
	mi.material_override = _flat(COL_SPIKE)
	visual.add_child(mi)


func _stamp_wedge(st: SurfaceTool, x: float, w: float, bottom: float, h: float, z_near: float, z_far: float) -> void:
	var bl := Vector3(x, bottom, z_near)
	var br := Vector3(x + w, bottom, z_near)
	var ap := Vector3(x + w * 0.5, bottom + h, z_near)
	var bl2 := Vector3(x, bottom, z_far)
	var br2 := Vector3(x + w, bottom, z_far)
	var ap2 := Vector3(x + w * 0.5, bottom + h, z_far)
	for tri in [[bl, br, ap], [bl2, ap2, br2], [bl, ap, bl2], [bl2, ap, ap2], [br, br2, ap], [br2, ap2, ap]]:
		st.add_vertex(tri[0])
		st.add_vertex(tri[1])
		st.add_vertex(tri[2])


func _add_critter(visual: Node3D, id: String, at: Vector3, color: Color, rx: float, ry: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = id
	var mesh := SphereMesh.new()
	mesh.radius = rx
	mesh.height = ry * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mi.mesh = mesh
	mi.position = at
	mi.material_override = _mat(color, 0.7)
	visual.add_child(mi)
	return mi


func _add_wind_card(visual: Node3D, h: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.name = String(h["id"])
	var box := BoxMesh.new()
	var sz := _vec(h["size_m"])
	sz.z = 0.08
	box.size = sz
	mi.mesh = box
	mi.position = _vec(h["center_m"])
	var mat := _mat(COL_WIND, 0.9, false, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	visual.add_child(mi)


func _earth(color: Color, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = Color(0.16, 0.12, 0.08)
	mat.emission_energy_multiplier = 0.05
	return mat


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _mat(color: Color, rough: float, _emit := false, alpha := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.roughness = rough
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _bean_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nrender_mode unshaded, fog_disabled, cull_back;\nuniform vec4 albedo : source_color = vec4(0.420, 0.227, 0.122, 1.0);\nuniform vec4 warm : source_color = vec4(0.769, 0.416, 0.227, 1.0);\nvoid fragment() {\n\tALBEDO = mix(albedo.rgb, warm.rgb, 0.2) * 0.70;\n}\n"
	mat.shader = shader
	mat.set_shader_parameter("albedo", Color("6b3a1f"))
	mat.set_shader_parameter("warm", Color("c46a3a"))
	return mat


func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _aabb_of(center: Vector3, size: Vector3) -> AABB:
	return AABB(center - size * 0.5, size)


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


func _match_framing() -> void:
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var offset: Vector3 = _player.camera_offset
	var focus := cam.global_position - offset
	var min_x := VIEW_W_M * 0.5
	var max_x := LEVEL_W_PX * PX - VIEW_W_M * 0.5
	var max_y := (LEVEL_H_PX - 270.0) * PX - Y_SHIFT
	var min_y := (LEVEL_H_PX - (LEVEL_H_PX - 540.0) - 270.0) * PX - Y_SHIFT
	focus.x = clampf(focus.x, min_x, max_x)
	focus.y = clampf(focus.y, min_y, max_y)
	cam.global_position = focus + offset
	if focus.distance_squared_to(cam.global_position) > 0.001:
		cam.look_at(focus, Vector3.UP)


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
	_show_hud()


func _hazards_touch() -> void:
	if _invuln > 0.0:
		return
	var body := _hurt_body()
	for h in _hazards:
		if String(h["kind"]) == "wind":
			continue
		if _overlap(body, h["aabb"]):
			_kill()
			return


func _apply_wind(delta: float) -> void:
	if _capturing or _status != "playing":
		return
	var body := _full_body()
	for h in _hazards:
		if String(h["kind"]) != "wind":
			continue
		if not _overlap(body, h["aabb"]):
			continue
		_player.velocity.x += float(h["vx"]) * PX * delta
		_player.velocity.y += float(h["ay"]) * PX * delta


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
		if not jump:
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
	print("SELVA_GOAL taken")


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
		var cy := (LEVEL_H_PX - ny - h * 0.5) * PX - Y_SHIFT
		body.global_position = Vector3(cx, cy, 0.0)


func _tick_oneways() -> void:
	var feet := _player.global_position.y
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


func _tick_rocks() -> void:
	for h in _hazards:
		if String(h["kind"]) != "rock":
			continue
		var rng := float(h["range"])
		var along := fposmod(_time * float(h["vx"]) + float(h["phase"]) * 40.0, rng + 80.0)
		var nx := (float(h["ox"]) - 80.0) if along > rng else (float(h["ox"]) + along)
		var ny := float(h["oy"])
		var w := 22.0
		var hh := 20.0
		var cx := (nx + w * 0.5) * PX
		var cy := (LEVEL_H_PX - ny - hh * 0.5) * PX - Y_SHIFT
		var center := Vector3(cx, cy, 0.0)
		h["aabb"] = _aabb_of(center, Vector3(w * PX, hh * PX, 2.0))
		var mesh: MeshInstance3D = h["mesh"]
		if mesh:
			mesh.position = center


func _wants_capture() -> bool:
	if OS.get_environment("SELVA_CAPTURE") != "":
		return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--selva-capture"):
			return true
	return false


func _wants_check() -> bool:
	if OS.get_environment("SELVA_CHECK") != "":
		return true
	for a in OS.get_cmdline_user_args():
		if a == "--selva-check":
			return true
	return false


func _capture_dir() -> String:
	var out := OS.get_environment("SELVA_CAPTURE")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--selva-capture="):
			out = a.substr("--selva-capture=".length())
	if out == "":
		out = "user://"
	if not out.ends_with("/"):
		out += "/"
	return out


func _print_counts() -> void:
	print("SELVA_CHECK platforms=%d hazards=%d pickups=%d checks=%d goal=1" % [
		_layout["platforms"].size(), _layout["hazards"].size(),
		_layout["pickups"].size(), _layout["checkpoints"].size()
	])
	print("SELVA_CAM offset=%s P01_top=%.4f" % [_player.camera_offset, float(_layout["platforms"][1]["top_m"])])


func _run_capture() -> void:
	var out := _capture_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var vp := get_viewport()
	vp.size = Vector2i(1280, 720)
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
		var img := vp.get_texture().get_image()
		var path := "%s3d_%s.png" % [out, String(shot["id"])]
		img.save_png(path)
		_write_perf(out, String(shot["id"]))
		print("SELVA_SHOT %s" % path)
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
	print("SELVA_CAM shot=%s offset=%s fov=%.2f formula_h=%.4f plane_h=%.4f plane_w=%.4f vp=%sx%s maya_px=%.2f" % [
		shot, _player.camera_offset, fov, vis_h, absf(top.y - bot.y), absf(right.x - left.x),
		vp.x, vp.y, absf(feet.y - head.y)
	])


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
	print("SELVA_PERF %s" % line.strip_edges())
