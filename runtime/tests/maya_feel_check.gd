extends SceneTree
## Headless feel check for player_maya.gd against 2D sim.ts numbers (Maya, 60 Hz).
##   godot --headless --fixed-fps 60 --path runtime -s res://tests/maya_feel_check.gd
## Expected values come from a verbatim JS port of applyRun/applyJump/applyGravity
## on a flat floor (sand-vivid-dawn-sail @ 5fd45031 src/game/sim.ts, Maya from
## characters.ts; run/jump numbers unchanged since 8e7ce7ad). T-019 mantle and
## T-018 proneClearsLip cases use the same sim.ts geometry constants. T-020
## checks the greybox cream/tan albedo override (2D PR #12 crouch-1 / crawl-1
## outfit averages) on a MeshInstance3D + CSG placeholder and on hero_grey.glb.
## Exit code 1 on any failure.

const PX := 24.0
const PLAYER_SCRIPT := preload("res://scripts/player_maya.gd")
const PILOT_SCENE := "res://scenes/pilot_cuyabeno.tscn"

## Test geometry (m). Floor top is y=0.
const TALL_LEDGE_X := -61.5       # left face of a 5.5 m tall solid (mantle target)
const TALL_LEDGE_TOP := 5.5
const LIP_X := -78.5              # right face of a low rock: 0.75 m (18 px) clearance
const LIP_GAP := 0.75
const LOW_LIP_X := -88.5          # right face of a rock too low even for prone: 0.4 m
const LOW_LIP_GAP := 0.4
const BODY_R := 0.35
## Greybox grey the test placeholder starts with (must come back when standing).
const GREY := Color(0.45, 0.45, 0.45)

var _fails := 0
var _held := false
var _down := false
var _move := 0.0
var _p: CharacterBody3D
var _root: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	_build_flat_world()
	await _settle()

	_expect_arr("run ramp px/s", await _vx_series(1.0, 5), [76.667, 153.333, 230.0, 290.0, 290.0], 0.01)
	_expect_arr("stop px/s", await _vx_series(0.0, 6), [220.0, 150.0, 80.0, 10.0, 0.0, 0.0], 0.01)

	var hold := await _jump_apex(-1)
	_expect("full-hold apex px", hold.x, 118.0, 0.5)
	_expect("full-hold air ticks", hold.y, 38.0, 1.0)
	var hop := await _jump_apex(1)
	_expect("1-tick hold apex px", hop.x, 18.6, 0.5)
	_expect("double-jump apex px", await _double_apex(), 234.89, 1.0)
	_expect("third press denied (jumps used)", await _press_count(3), 2.0, 0.0)

	var land_ticks := await _second_jump_land_ticks()
	for n in [5, 6, 7, 8, 9]:
		_expect("buffer %d ticks early jumps" % n, 1.0 if await _buffer_jumps(n, land_ticks) else 0.0, 1.0 if n <= 8 else 0.0, 0.0)

	_expect("full jump clears 1 m ledge", 1.0 if await _ledge_climb() else 0.0, 1.0, 0.0)
	_expect("fall-kill respawns at spawn", 1.0 if await _falls_and_respawns(Vector3(0, 0.05, 0), 60.0) else 0.0, 1.0, 0.0)

	# T-019 mantle: ledgeGrab at the tip → 0.28 s smoothstep pull-up → grounded on top.
	var mantle := await _mantle_from_tip()
	_expect("mantle: grabs the tip while falling", 1.0 if mantle.grabbed else 0.0, 1.0, 0.0)
	_expect("mantle: hang x = lip - w + 6 px", (mantle.hang.x - BODY_R - TALL_LEDGE_X) * PX, -2.0 * BODY_R * PX + 6.0, 0.05)
	_expect("mantle: hang head 8 px above lip", (mantle.hang.y + _p._stand_h - TALL_LEDGE_TOP) * PX, 8.0, 0.05)
	_expect("mantle: MANTLE_T 0.28 s = 17 ticks", mantle.ticks, 17.0, 0.0)
	_expect("mantle: stands at lip + 2 px", (mantle.stand.x - BODY_R - TALL_LEDGE_X) * PX, 2.0, 0.05)
	_expect("mantle: feet on lip top", (mantle.stand.y - TALL_LEDGE_TOP) * PX, 0.0, 0.05)
	_expect("mantle: grounded, jumps refilled", 1.0 if mantle.grounded and _p._jumps_left == 2 else 0.0, 1.0, 0.0)
	_expect("mantle: down during hang drops to floor", 1.0 if await _hang_drop() else 0.0, 1.0, 0.0)
	var kick := await _hang_jump()
	_expect("mantle: jump from hang vy (720 - grav tick)", kick.y, 685.0, 0.5)
	_expect("mantle: jump from hang kicks -0.95 run", kick.x, -275.5, 0.5)

	# T-018 crouch / prone (updateCrouch, proneClearsLip) + T-020 cream/tan tint.
	# Identidad PASA: tints stay in the ~28° hue band (cream/tan, never olive).
	_expect("identidad: crouch tint hue ≈ 28°", _p.TINT_CROUCH.h * 360.0, _p.TINT_HUE_DEG, _p.TINT_HUE_BAND_DEG)
	_expect("identidad: crawl tint hue ≈ 28°", _p.TINT_CRAWL.h * 360.0, _p.TINT_HUE_DEG, _p.TINT_HUE_BAND_DEG)
	_expect("tint: standing = untouched greybox", 1.0 if _tint_restored() else 0.0, 1.0, 0.0)
	_expect("crouch: down still → PH_CROUCH 24 px", await _crouch_height(0.0), 24.0, 0.01)
	_expect_arr("tint: crouch albedo RGB8 (crouch-1)", _tint_rgb8(), [138, 99, 65], 0.0)
	_expect("crouch: release → stands again", await _release_height(), 43.2, 0.01)
	_expect("tint: stand restores greybox", 1.0 if _tint_restored() else 0.0, 1.0, 0.0)
	_expect_arr("crawl: down+move px/s (0.42 run)", await _crawl_series(3), [76.667, 121.8, 121.8], 0.01)
	_expect("crawl: moving crouch → PH_PRONE 14 px", _p._h * PX, 14.0, 0.01)
	_expect_arr("tint: crawl albedo RGB8 (crawl-1)", _tint_rgb8(), [148, 110, 76], 0.0)
	await _settle()
	_expect("prone lip: standing push does not pass", 1.0 if await _push_lip(LIP_X, false) else 0.0, 0.0, 0.0)
	_expect("prone lip: proneClearsLip(-1) at 18 px lip", 1.0 if _p._prone_clears_lip(-1.0) else 0.0, 1.0, 0.0)
	_expect("prone lip: proneClearsLip(+1) open side", 1.0 if _p._prone_clears_lip(1.0) else 0.0, 0.0, 0.0)
	_expect("prone lip: down+move forces crawl under", 1.0 if await _push_lip(LIP_X, true) else 0.0, 1.0, 0.0)
	await _step(0.0, false, false)
	_expect("prone lip: release under rock stays prone", 1.0 if _p._dragging and is_equal_approx(_p._h * PX, 14.0) else 0.0, 1.0, 0.0)
	_expect_arr("tint: prone under rock keeps crawl tan", _tint_rgb8(), [148, 110, 76], 0.0)
	var out_left := false
	for i in 90:
		await _step(-1.0, false, false)
		if _p.global_position.x + BODY_R < LIP_X - 3.0 - 0.5:
			out_left = true
	await _step(0.0, false, false)
	_expect("prone lip: crawls out and stands up", 1.0 if out_left and is_equal_approx(_p._h * PX, 43.2) else 0.0, 1.0, 0.0)
	_expect("tint: stood up → greybox restored", 1.0 if _tint_restored() else 0.0, 1.0, 0.0)
	await _settle()
	_expect("prone lip: 0.4 m lip blocks prone too", 1.0 if await _push_lip(LOW_LIP_X, true) else 0.0, 0.0, 0.0)
	_expect("prone lip: proneClearsLip(-1) false at 0.4 m", 1.0 if _p._prone_clears_lip(-1.0) else 0.0, 0.0, 0.0)

	_root.queue_free()
	await physics_frame
	await _pilot_smoke()

	print("MAYA FEEL CHECK: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)


func _build_flat_world() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	_add_box(Vector3(0, -0.5, 0), Vector3(200, 1, 8))
	_add_box(Vector3(-40, 0.5, 0), Vector3(3, 1, 8))
	_add_box(Vector3(TALL_LEDGE_X + 1.5, TALL_LEDGE_TOP * 0.5, 0), Vector3(3, TALL_LEDGE_TOP, 8))
	_add_box(Vector3(LIP_X - 1.5, LIP_GAP + 0.5, 0), Vector3(3, 1, 8))
	_add_box(Vector3(LOW_LIP_X - 1.5, LOW_LIP_GAP + 0.5, 0), Vector3(3, 1, 8))
	_p = CharacterBody3D.new()
	_p.floor_stop_on_slope = true
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = BODY_R
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	_p.add_child(col)
	var mesh := Node3D.new()
	mesh.name = "MeshPlaceholder"
	_p.add_child(mesh)
	# T-020: the player picks up hero_grey.glb as _visual (placeholder hidden), so
	# these two are registered as extra tint slots below to cover the CSG path
	# and a mesh with a material of its own (must be duplicated, not mutated).
	var body := MeshInstance3D.new()
	body.name = "Body"
	var box_mesh := BoxMesh.new()
	var grey := StandardMaterial3D.new()
	grey.albedo_color = GREY
	grey.roughness = 0.9
	box_mesh.material = grey
	body.mesh = box_mesh
	mesh.add_child(body)
	var csg := CSGBox3D.new()
	csg.name = "Csg"
	mesh.add_child(csg)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	_p.add_child(cam)
	_p.set_script(PLAYER_SCRIPT)
	_p.position = Vector3(0, 0.05, 0)
	_root.add_child(_p)
	_p._collect_tint_slots(mesh)


func _add_box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	body.position = center
	_root.add_child(body)


## Applies inputs for one physics tick (runs before the player's _physics_process).
func _step(move: float, held: bool, down := false) -> void:
	if move != _move:
		Input.action_release("move_left")
		Input.action_release("move_right")
		if move > 0.0:
			Input.action_press("move_right", move)
		elif move < 0.0:
			Input.action_press("move_left", -move)
		_move = move
	if held != _held:
		if held:
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		_held = held
	if down != _down:
		if down:
			Input.action_press("move_down")
		else:
			Input.action_release("move_down")
		_down = down
	await physics_frame


func _settle(x := 0.0) -> void:
	_p.global_position = Vector3(x, 0.05, 0)
	_p.velocity = Vector3.ZERO
	for i in 20:
		await _step(0.0, false)


func _vx_series(move: float, n: int) -> Array:
	var out := []
	for i in n:
		await _step(move, false)
		out.append(_p.velocity.x * PX)
	return out


## hold_ticks < 0 keeps jump held for the whole flight. Returns (apex px, air ticks).
func _jump_apex(hold_ticks: int) -> Vector2:
	await _settle()
	var y0 := _p.global_position.y
	var apex := 0.0
	var t := 0
	await _step(0.0, true)
	t += 1
	while not _p.is_on_floor() and t < 300:
		apex = maxf(apex, _p.global_position.y - y0)
		await _step(0.0, hold_ticks < 0 or t < hold_ticks)
		t += 1
	return Vector2(apex * PX, t)


func _double_apex() -> float:
	await _settle()
	var y0 := _p.global_position.y
	await _step(0.0, true)
	while _p.velocity.y > 0.0:
		await _step(0.0, true)
	await _step(0.0, false)
	await _step(0.0, true)
	var apex := 0.0
	var t := 0
	while not _p.is_on_floor() and t < 300:
		apex = maxf(apex, _p.global_position.y - y0)
		await _step(0.0, true)
		t += 1
	return apex * PX


func _press_count(presses: int) -> float:
	await _settle()
	var count := 0
	for i in presses:
		var vy_before := _p.velocity.y
		await _step(0.0, true)
		if _p.velocity.y > vy_before + 1.0:
			count += 1
		for k in 10:
			await _step(0.0, true)
		await _step(0.0, false)
	for k in 120:
		await _step(0.0, false)
	return float(count)


func _use_both_jumps() -> void:
	await _settle()
	await _step(0.0, true)
	for i in 5:
		await _step(0.0, true)
	await _step(0.0, false)
	await _step(0.0, true)


func _second_jump_land_ticks() -> int:
	await _use_both_jumps()
	var k := 0
	while not _p.is_on_floor() and k < 300:
		await _step(0.0, true)
		k += 1
	return k


func _buffer_jumps(n: int, land_ticks: int) -> bool:
	await _use_both_jumps()
	for i in land_ticks - n:
		await _step(0.0, true)
	await _step(0.0, false)
	await _step(0.0, true)
	var jumped := false
	for i in n + 2:
		await _step(0.0, true)
		if _p.velocity.y > 20.0:
			jumped = true
	for i in 120:
		await _step(0.0, false)
	return jumped


func _ledge_climb() -> bool:
	await _settle(-46.0)
	await _step(1.0, true)
	for i in 90:
		await _step(1.0, true)
		if _p.is_on_floor() and _p.global_position.y > 0.9:
			await _step(0.0, false)
			return true
	await _step(0.0, false)
	return false


## Full jump straight up beside the tall solid's left face (0.1 m gap), jump held.
## The tip is caught on the first falling tick; returns hang pose, mantle ticks
## (grab → grounded), stand pose.
func _mantle_from_tip() -> Dictionary:
	var out := {"grabbed": false, "ticks": 0.0, "hang": Vector3.ZERO, "stand": Vector3.ZERO, "grounded": false}
	await _settle(TALL_LEDGE_X - BODY_R - 0.1)
	var grab_tick := -1
	for t in 200:
		await _step(0.0, true)
		if _p._hanging and grab_tick < 0:
			grab_tick = t
			out.grabbed = true
			out.hang = _p.global_position
		elif grab_tick >= 0 and not _p._hanging:
			out.ticks = float(t - grab_tick)
			out.stand = _p.global_position
			out.grounded = _p._grounded
			break
	await _step(0.0, false)
	return out


func _hang_until() -> bool:
	await _settle(TALL_LEDGE_X - BODY_R - 0.1)
	for t in 200:
		await _step(0.0, true)
		if _p._hanging:
			return true
	return false


## Down releases the hang (applyRun). Jump must be let go too: with jumpHeld the
## 2D ledgeGrab re-catches the same lip on the very next tick.
func _hang_drop() -> bool:
	if not await _hang_until():
		return false
	await _step(0.0, false, true)
	if _p._hanging:
		return false
	for t in 200:
		await _step(0.0, false)
		if _p.is_on_floor():
			return absf(_p.global_position.y) < 0.1
	return false


## Release then re-press jump while hanging; returns (vx, vy) px/s right after.
func _hang_jump() -> Vector2:
	if not await _hang_until():
		return Vector2.ZERO
	await _step(0.0, false)
	if not _p._hanging:
		return Vector2.ZERO
	await _step(0.0, true)
	var v := Vector2(_p.velocity.x, _p.velocity.y) * PX
	for t in 200:
		await _step(0.0, true)
		if _p.is_on_floor():
			break
	await _step(0.0, false)
	return v


func _crouch_height(move: float) -> float:
	await _settle()
	await _step(move, false, true)
	return _p._h * PX


func _release_height() -> float:
	await _step(0.0, false, false)
	return _p._h * PX


func _crawl_series(n: int) -> Array:
	await _settle()
	var out := []
	for i in n:
		await _step(1.0, false, true)
		out.append(_p.velocity.x * PX)
	return out


## Push left into a low rock whose right face is at face_x. Standing first (30
## ticks), then keep pushing with/without down. True once Maya is under its middle.
func _push_lip(face_x: float, down: bool) -> bool:
	await _settle(face_x + BODY_R + 0.6)
	for i in 30:
		await _step(-1.0, false, false)
	for i in 150:
		await _step(-1.0, false, down)
		if _p.global_position.x < face_x - 1.5:
			return true
	return false


## T-020: every material slot under `node` as the player sees it — MeshInstance3D
## surface overrides (glTF path) and CSG primitive materials (placeholder path).
## Nulls are kept so the caller can tell "restored" from "tinted".
func _slot_materials(node: Node) -> Array:
	var out := []
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			out.append(mi.get_surface_override_material(i))
	elif node is CSGPrimitive3D:
		out.append(node.get("material"))
	for c in node.get_children():
		out.append_array(_slot_materials(c))
	return out


## Slots under `node` whose flat colour (emission on the unlit glb export,
## albedo otherwise) equals `want`.
func _count_tinted(node: Node, want: Color) -> int:
	var n := 0
	for m in _slot_materials(node):
		if m != null and PLAYER_SCRIPT.flat_color(m) == want:
			n += 1
	return n


func _count_overrides(node: Node) -> int:
	var n := 0
	for m in _slot_materials(node):
		if m != null:
			n += 1
	return n


## 8-bit colour while crouched / crawling: every override on hero_grey.glb (the
## Maya_Body outfit slots) and both registered placeholders must carry
## pose_tint_color(); the Body mesh keeps its own grey material and the override
## keeps its roughness (duplicate, not mutation). [-1, -1, -1] on any mismatch.
func _tint_rgb8() -> Array:
	var body: MeshInstance3D = _p.get_node("MeshPlaceholder/Body")
	var placeholder: Node = _p.get_node("MeshPlaceholder")
	var want: Color = _p.pose_tint_color()
	var glb_tinted := _count_tinted(_p._visual, want)
	if glb_tinted < 1 or glb_tinted != _count_overrides(_p._visual):
		return [-1, -1, -1]
	if _count_tinted(placeholder, want) != 2 or _slot_materials(placeholder).size() != 2:
		return [-1, -1, -1]
	var over := body.get_surface_override_material(0) as BaseMaterial3D
	if over == null or not is_equal_approx(over.roughness, 0.9):
		return [-1, -1, -1]
	if (body.mesh.surface_get_material(0) as BaseMaterial3D).albedo_color != GREY:
		return [-1, -1, -1]
	return [want.r8, want.g8, want.b8]


## Standing puts back exactly what the slots had at _ready: no overrides on the
## glb, CSG material null, Body mesh material untouched.
func _tint_restored() -> bool:
	var body: MeshInstance3D = _p.get_node("MeshPlaceholder/Body")
	return _p._pose_tint == _p.PoseTint.STAND \
		and _count_overrides(_p._visual) == 0 \
		and _count_overrides(_p.get_node("MeshPlaceholder")) == 0 \
		and (body.mesh.surface_get_material(0) as BaseMaterial3D).albedo_color == GREY


func _falls_and_respawns(spawn: Vector3, run_to_x: float) -> bool:
	await _settle()
	_p.global_position = Vector3(run_to_x + 100.0, 0.05, 0)
	for i in 180:
		await _step(0.0, false)
		if _p.global_position.distance_to(spawn) < 0.5 and _p.velocity.length() < 1.0:
			return true
	return false


func _pilot_smoke() -> void:
	var pilot: Node = (load(PILOT_SCENE) as PackedScene).instantiate()
	root.add_child(pilot)
	_p = pilot.get_node("PlayerMaya")
	var spawn := _p.global_position
	for i in 60:
		await _step(0.0, false)
	_expect("pilot: Maya lands on floor from spawn", 1.0 if _p.is_on_floor() and absf(_p.global_position.y) < 0.1 else 0.0, 1.0, 0.0)
	# T-020 on the real greybox: hero_grey.glb = 3 LODs × (Maya_Body, Maya_Hair,
	# Maya_Pack), no overrides at rest; only the 3 outfit surfaces go cream while
	# crouched (hair / pack keep the idle materials) and come back on release.
	var hero: Node3D = _p._visual
	var glb_attached := hero != _p.get_node("MeshPlaceholder")
	var overrides_at_rest := _count_overrides(hero)
	await _step(0.0, false, true)
	_expect("pilot: crouch tints the 3 Maya_Body surfaces", float(_count_tinted(hero, _p.TINT_CROUCH)) if glb_attached and overrides_at_rest == 0 else -1.0, 3.0, 0.0)
	_expect("pilot: Maya_Hair / Maya_Pack untouched", float(_count_overrides(hero) - _count_tinted(hero, _p.TINT_CROUCH)), 0.0, 0.0)
	await _step(0.0, false, false)
	_expect("pilot: release restores hero_grey materials", float(_count_overrides(hero)), 0.0, 0.0)
	for i in 10:
		await _step(0.0, false)
	var on_ledge := false
	await _step(1.0, true)
	for i in 90:
		await _step(1.0, true)
		if _p.is_on_floor() and _p.global_position.y > 0.9:
			on_ledge = true
			break
	for i in 30:
		await _step(0.0, false)
	_expect("pilot: full jump from spawn lands on ledge", 1.0 if on_ledge else 0.0, 1.0, 0.0)
	# 1 m solid platform (CSGPlatform x 4.5..7.5, or PR#3's PlatformSolidAnchor
	# x 2..5): jump straight up beside its left face, the tip is caught on the way
	# down (CSG / StaticBody collider → AABB path).
	var face_x := 4.5
	var solid_anchor: Node3D = pilot.get_node_or_null("WorldRoot/PlatformSolidAnchor")
	if solid_anchor:
		face_x = solid_anchor.global_position.x - 1.5
	_p.global_position = Vector3(face_x - BODY_R - 0.1, 0.05, 0)
	_p.velocity = Vector3.ZERO
	for i in 20:
		await _step(0.0, false)
	var grabbed := false
	var mantled := false
	for i in 200:
		await _step(0.0, true)
		if _p._hanging:
			grabbed = true
		elif grabbed and _p._grounded:
			mantled = _p.global_position.y > 0.9 and _p.global_position.y < 1.3 and absf(_p.global_position.x - (face_x + 2.0 / PX + BODY_R)) < 0.05
			break
	for i in 30:
		await _step(0.0, false)
	_expect("pilot: mantle onto CSG platform from its face", 1.0 if grabbed and mantled else 0.0, 1.0, 0.0)
	_p.global_position = spawn
	_p.velocity = Vector3.ZERO
	for i in 20:
		await _step(0.0, false)
	var respawned := false
	for i in 360:
		await _step(-1.0, false)
		if i > 30 and _p.global_position.distance_to(spawn) < 0.5:
			respawned = true
			break
	await _step(0.0, false)
	_expect("pilot: running off the left edge respawns", 1.0 if respawned else 0.0, 1.0, 0.0)
	pilot.queue_free()


func _expect(label: String, got: float, want: float, tol: float) -> void:
	var ok := absf(got - want) <= tol
	if not ok:
		_fails += 1
	print("%s  %-36s got %9.3f  want %9.3f" % ["ok  " if ok else "FAIL", label, got, want])


func _expect_arr(label: String, got: Array, want: Array, tol: float) -> void:
	var ok := got.size() == want.size()
	for i in mini(got.size(), want.size()):
		ok = ok and absf(float(got[i]) - float(want[i])) <= tol
	if not ok:
		_fails += 1
	print("%s  %-36s got %s  want %s" % ["ok  " if ok else "FAIL", label, str(got.map(func(v): return snappedf(v, 0.001))), str(want)])
