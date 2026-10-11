extends SceneTree
## Headless route for ruinas-1. Inputs only — Maya is never teleported.
## From the P00 spawn, wall-hop the P01 face to the crown, cross P02, crawl the
## P04 lip, and continue to G00.
##   godot --headless --fixed-fps 60 --path runtime -s res://tests/ruinas_route_probe.gd

const SCENE := "res://scenes/pilot_ruinas.tscn"
const LAYOUT := "res://data/ruinas1_layout.json"

var _pilot: Node
var _p: CharacterBody3D
var _move := 0.0
var _held := false
var _down := false
var _plats: Array = []
var _hazards: Array = []
var _crown := false
var _max_x := 0.0
var _max_y := 0.0
var _phase := "approach"
var _doubled := false
var _p17_prev := -1.0
var _p17_x := 0.0
var _p17_down := false
var _stuck := 0
var _stuck_x := 0.0
var _stuck_y := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_load_layout()
	await _frame()
	_pilot = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_pilot)
	_p = _pilot.get_node("PlayerMaya")
	for i in 25:
		await _go(0.0, false, false)
	var goal := false
	var lives := int(_pilot._lives)
	for t in 60 * 150:
		if _pilot._status == "playing":
			await _drive()
		else:
			_phase = "wait-" + String(_pilot._status)
			await _go(0.0, false, false)
		_max_x = maxf(_max_x, _p.global_position.x)
		_max_y = maxf(_max_y, _p.global_position.y)
		if not _crown and _on_crown():
			_crown = true
			print("RUINAS_CROWN tick=%d feet=(%.2f, %.2f)" % [t, _p.global_position.x, _p.global_position.y])
		if bool(_pilot._goal_taken):
			goal = true
			print("RUINAS_GOAL tick=%d feet=(%.2f, %.2f)" % [t, _p.global_position.x, _p.global_position.y])
			break
		if _pilot._status == "over":
			print("RUINAS_DEAD tick=%d" % t)
			break
		if t % 60 == 0 or _stuck == 120:
			print("t=%d phase=%s feet=(%.2f, %.2f) vy=%.1f floor=%s wall=%s pose=%s lives=%s p17=%.1f" % [
				t, _phase, _p.global_position.x, _p.global_position.y, _p.velocity.y,
				str(_p.is_on_floor()), str(_p._wall_dir), str(_p.pose_id), str(_pilot._lives), _p17_x])
		if int(_pilot._lives) < lives:
			lives = int(_pilot._lives)
			print("RUINAS_HIT tick=%d lives=%d feet=(%.2f, %.2f) phase=%s" % [t, lives, _p.global_position.x, _p.global_position.y, _phase])
	print("RUINAS_PROBE crown=%s goal=%s max=(%.2f, %.2f) feet=(%.2f, %.2f) lives=%s phase=%s" % [
		str(_crown), str(goal), _max_x, _max_y, _p.global_position.x, _p.global_position.y, str(_pilot._lives), _phase])
	quit(0 if _crown and goal else 1)


func _on_crown() -> bool:
	# Either wall top (P01 13.3–16, P02 18.7–21.3). The hop between them is the zigzag.
	return _p.is_on_floor() and _p.global_position.y > 39.2 and _p.global_position.x > 13.5 and _p.global_position.x < 21.5


func _drive() -> void:
	var x := _p.global_position.x
	var y := _p.global_position.y
	var px := _plat_x("P17")
	_p17_down = _p17_prev > 0.0 and px < _p17_prev - 0.02
	_p17_prev = px
	_p17_x = px
	if absf(x - _stuck_x) < 0.04 and absf(y - _stuck_y) < 0.04:
		_stuck += 1
	else:
		_stuck = 0
		_stuck_x = x
		_stuck_y = y
	if _p._hanging:
		_set_phase("mantle")
		await _go(0.0, true, false)
		return
	# A leg latches in the air so a takeoff keeps its jump through the gap.
	# Landing picks the next leg from where the feet actually are, so a death
	# respawn (start or a saved pole) rejoins the route without a teleport.
	if _p.is_on_floor():
		_doubled = false
		_set_phase(_plan(x, y))
	elif _phase == "wall-p05" and x > 33.2 and y > 21.05 and y < 24.8 and int(_p._wall_dir) == 0:
		_set_phase("settle-p05")
	elif _phase == "wall-p22" and x > 168.35 and y > 26.35 and int(_p._wall_dir) == 0:
		_set_phase("settle-p22")
	await _act(x, y)


func _plan(x: float, y: float) -> String:
	if y > 36.0 and x < 18.6:
		return "cross" if x < 16.3 else "drop"
	if x < 12.15 and y < 30.0:
		return "approach"
	if x < 17.2 and y < 39.6:
		return "wall-p01"
	if x < 32.7 and y < 16.0:
		# Stay under the P04 lip until the feet are on its far side, then hop.
		return "wall-p05" if x > 32.05 else "crawl-p04"
	if x < 32.7:
		return "drop"
	if x < 41.2 and y < 20.9:
		return "wall-p05"
	if x < 41.2:
		return "run-p05" if x < 38.55 else "leap-p07"
	if x < 53.6 and y > 22.0:
		return "run-p07" if x < 51.55 else "board-p10"
	var top10 := _plat_top("P10")
	if x > 52.4 and x < 58.2 and absf(y - top10) < 1.45:
		return "launch-p11" if y > 40.0 else "ride-p10"
	if x < 78.8 and y > 34.0:
		return "run-p11" if x < 75.25 else "short-p13"
	if x < 86.8 and y > 20.5 and y < 27.5:
		return "leap-p14"
	if x < 96.5 and y > 27.0:
		if x >= 89.65 and x <= 90.45:
			return "full-p15"
		return "seek-p14"
	if x < 108.0 and y > 19.2 and y < 24.8:
		return "leap-p16" if _p17_go() else "wait-p15"
	if x < 116.2 and y > 24.2 and y < 27.8:
		return "board-p17"
	var top17 := _plat_top("P17")
	if absf(y - top17) < 1.55 and absf(x - _p17_x) < 3.1 and y > 26.5:
		if x >= 130.05 and x <= 131.4:
			return "cross-h03"
		return "ride-p17"
	if x < 141.6 and y > 22.2 and y < 26.8:
		return "run-p18l" if x < 139.65 else "cross-h03"
	if x < 156.5 and y > 22.2 and y < 26.8:
		return "run-p18r" if x < 148.55 else "jump-p20"
	if y < 26.45 and x < 167.4:
		return "crawl-p21"
	if y < 26.45:
		return "wall-p22"
	if x < 176.5:
		return "run-p22" if x < 171.15 else "leap-p24"
	return "goal"


func _p17_go() -> bool:
	return _p17_down and _p17_x > 123.3 and _p17_x < 129.3


func _act(x: float, y: float) -> void:
	match _phase:
		"approach", "drop", "run-p05", "run-p07", "run-p11", "run-p18l", "run-p18r", "run-p22", "goal":
			await _go(1.0, false, false)
		"wall-p01", "wall-p05", "wall-p22":
			await _wall_hop(1.0)
		"cross":
			await _go(1.0, x > 15.45 or not _p.is_on_floor(), false)
		"crawl-p04":
			await _go(1.0, false, x > 23.45 and x < 31.5)
		"settle-p05":
			await _go(-1.0 if x > 36.2 else 0.35, false, false)
		"leap-p07", "leap-p14", "leap-p16", "leap-p24", "launch-p11":
			await _double_right(0.0)
		"board-p10":
			await _board_p10(y)
		"ride-p10":
			await _steer_p10(x)
		"short-p13":
			await _short_right()
		"seek-p14":
			await _go(-1.0 if x > 90.5 else 1.0, false, false)
		"full-p15", "cross-h03", "jump-p20":
			await _go(1.0, true, false)
		"wait-p15":
			var steer := 0.0
			if x < 99.45:
				steer = 1.0
			elif x > 100.45:
				steer = -1.0
			await _go(steer, false, false)
		"board-p17":
			var steer17 := 1.0 if x < _p17_x - 0.3 else 0.0
			await _go(steer17, true, false)
		"ride-p17":
			await _steer_p17(x)
		"crawl-p21":
			await _go(1.0, false, x > 157.15 and x < 164.7)
		"settle-p22":
			await _go(-1.0 if x > 169.2 else 0.3, false, false)
		_:
			await _go(1.0, false, false)


func _set_phase(next: String) -> void:
	if next == _phase:
		return
	_phase = next
	print("PHASE %s feet=(%.2f, %.2f) floor=%s" % [next, _p.global_position.x, _p.global_position.y, str(_p.is_on_floor())])


func _double_right(_from_x: float) -> void:
	if _p.is_on_floor():
		await _go(1.0, true, false)
		return
	# Second press once the rise has stalled. K00's first press is the takeoff;
	# this one is past the pole (feet clear y≈24.3 well before vy drops under 1).
	if not _doubled and int(_p._jumps_left) > 0 and _p.velocity.y < 1.0 and not _over_pole():
		if _held:
			await _go(1.0, false, false)
		else:
			_doubled = true
			await _go(1.0, true, false)
		return
	await _go(1.0, true, false)


func _over_pole() -> bool:
	var x := _p.global_position.x
	var y := _p.global_position.y
	return x > 98.5 and x < 101.05 and y < 24.45


func _short_right() -> void:
	if _p.is_on_floor():
		await _go(1.0, true, false)
	else:
		await _go(1.0, false, false)


func _board_p10(y: float) -> void:
	var top := _plat_top("P10")
	if not _p.is_on_floor():
		await _go(1.0, true, false)
		return
	if top > y - 0.25 and top < y + 3.1:
		await _go(1.0, true, false)
	else:
		await _go(0.0, false, false)


func _steer_p10(x: float) -> void:
	var anchor := _plat_x("P10") - 1.15
	var steer := 0.0
	if x < anchor - 0.12:
		steer = 1.0
	elif x > anchor + 0.18:
		steer = -1.0
	await _go(steer, false, false)


func _steer_p17(x: float) -> void:
	var aim := 130.6
	if _p17_x < 128.5:
		aim = _p17_x
	var steer := 0.0
	if x < aim - 0.18:
		steer = 1.0
	elif x > aim + 0.18:
		steer = -1.0
	await _go(steer, false, false)


func _spikes_under() -> bool:
	var x := _p.global_position.x
	var y := _p.global_position.y
	for h in _hazards:
		if String(h["kind"]) != "spikes":
			continue
		if x > float(h["left"]) - 0.4 and x < float(h["right"]) + 0.4 and absf(y - float(h["top"])) < 1.6:
			return true
	return false


func _plat_top(id: String) -> float:
	var n := _pilot.get_node_or_null("WorldRoot/" + id) as Node3D
	if n == null:
		return -999.0
	var mesh := n.get_node("Mesh") as MeshInstance3D
	return n.global_position.y + (mesh.mesh as BoxMesh).size.y * 0.5


func _plat_x(id: String) -> float:
	var n := _pilot.get_node_or_null("WorldRoot/" + id) as Node3D
	if n == null:
		return -999.0
	return n.global_position.x


## Single-wall hop. `into` is +1 when the wall is on the right.
func _wall_hop(into: float) -> void:
	var want := 1 if into > 0.0 else -1
	if _p.is_on_floor():
		await _go(into, true, false)
		return
	if _p._wall_dir == want and _p._wall_lock <= 0.0:
		# Release for one tick so the next press is just_pressed, then kick.
		if _held:
			await _go(into, false, false)
		else:
			await _go(into, true, false)
		return
	# Back to the wall. Keep jump held so CUT does not kill the rise.
	await _go(into, true, false)


func _go(move: float, held: bool, down: bool) -> void:
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
	await _frame()


func _frame() -> void:
	await process_frame


func _load_layout() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for raw in parsed["platforms"]:
		var p: Dictionary = raw
		var c: Array = p["center_m"]
		var s: Array = p["size_m"]
		_plats.append({
			"id": String(p["id"]),
			"kind": String(p["kind"]),
			"left": float(c[0]) - float(s[0]) * 0.5,
			"right": float(c[0]) + float(s[0]) * 0.5,
			"top": float(p["top_m"]),
			"bottom": float(c[1]) - float(s[1]) * 0.5,
		})
	for raw_h in parsed["hazards"]:
		var h: Dictionary = raw_h
		var c: Array = h["center_m"]
		var s: Array = h["size_m"]
		_hazards.append({
			"id": String(h["id"]),
			"kind": String(h["kind"]),
			"left": float(c[0]) - float(s[0]) * 0.5,
			"right": float(c[0]) + float(s[0]) * 0.5,
			"top": float(c[1]) + float(s[1]) * 0.5,
			"bottom": float(c[1]) - float(s[1]) * 0.5,
		})
