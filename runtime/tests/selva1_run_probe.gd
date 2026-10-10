extends SceneTree
## Headless scripted run of selva-1 from spawn to G00 using inputs only.
##   SELVA_RUN=1 godot --headless --fixed-fps 60 --path runtime -s res://tests/selva1_run_probe.gd
## Does not modify player_maya.gd. Exit 0 if the goal is taken.

const PILOT := "res://scenes/pilot_cuyabeno.tscn"
const MAX_TICKS := 60 * 180
const GOAL_X := 195.0

var _p: CharacterBody3D
var _play: Node
var _plats: Array = []
var _movers: Array = []
var _move := 0.0
var _held := false
var _down := false
var _far_x := 0.0
var _stuck := 0
var _last_x := 0.0
var _deaths := 0
var _last_lives := 5
var _air := 0
var _jump_armed := false
var _phase := "intro"
var _did_double := false
var _repress := 0
var _wait := 0
var _k00 := false
var _k01 := false
var _p14_top := -99.0


func _initialize() -> void:
	OS.set_environment("SELVA_RUN", "1")
	_run.call_deferred()


func _run() -> void:
	var pilot: Node = (load(PILOT) as PackedScene).instantiate()
	root.add_child(pilot)
	current_scene = pilot
	_p = pilot.get_node("PlayerMaya")
	_play = pilot.get_node_or_null("Selva1Play")
	if _play == null:
		for c in pilot.get_children():
			if String(c.name).begins_with("Selva") or c.has_method("_tick_play"):
				_play = c
				break
	if _play and _play.get("_layout"):
		_plats = (_play.get("_layout") as Dictionary).get("platforms", [])
	if _play:
		_movers = _play.get("_movers")
		_last_lives = int(_play.get("_lives"))
	for i in 50:
		await _step(0.0, false, false)
	_far_x = _p.global_position.x
	_last_x = _far_x
	print("SELVA_RUN start feet=", _p.global_position, " plats=", _plats.size(), \
			" movers=", _movers.size(), \
			" feel=", _play.get("_feel") if _play else "?", \
			" kill_y=", _p.kill_y, " pit=", _play.get("PIT_KILL_Y") if _play else "?")
	for tick in MAX_TICKS:
		if _play:
			var lives := int(_play.get("_lives"))
			if lives < _last_lives:
				_deaths += _last_lives - lives
				_last_lives = lives
				print("SELVA_RUN death n=%d lives=%d phase=%s feet=%s" % [
					_deaths, lives, _phase, _p.global_position
				])
			if lives <= 0 and String(_play.get("_status")) == "over":
				print("SELVA_RUN FAIL game_over ticks=%d far_x=%.2f feet=%s deaths=%d goal=0" % [
					tick, _far_x, _p.global_position, _deaths
				])
				quit(1)
				return
		var plan := _plan()
		await _step(plan.x, plan.y > 0.5, plan.z > 0.5)
		var x := _p.global_position.x
		if x > _far_x:
			_far_x = x
		if absf(x - _last_x) < 0.04:
			_stuck += 1
		else:
			_stuck = 0
			_last_x = x
		var won := false
		if _play:
			won = bool(_play.get("_goal_taken")) or String(_play.get("_status")) == "win"
		if won or x >= GOAL_X:
			print("SELVA_RUN PASS ticks=%d far_x=%.2f feet=%s deaths=%d goal=1" % [
				tick, _far_x, _p.global_position, _deaths
			])
			quit(0)
			return
		if (tick < 1800 and tick % 120 == 119) or tick % 600 == 599:
			print("SELVA_RUN progress t=%.1f x=%.2f y=%.2f far=%.2f phase=%s stuck=%d hang=%s lives=%s" % [
				tick / 60.0, x, _p.global_position.y, _far_x, _phase, _stuck,
				str(_p.get("_hanging")), str(_play.get("_lives")) if _play else "?"
			])
	print("SELVA_RUN FAIL ticks=%d far_x=%.2f feet=%s deaths=%d goal=0" % [
		MAX_TICKS, _far_x, _p.global_position, _deaths
	])
	quit(1)


func _advance_phase(x: float, y: float, on: bool) -> void:
	# Only retarget on the floor so a mid-air jump cannot change the script.
	if not on:
		return
	if x < 20.0 and y < 4.0:
		_phase = "intro"
	elif x < 49.5 and y < 8.5:
		_phase = "p04"
	elif x < 63.5 and y < 5.5:
		_phase = "crawl"
	elif x < 81.5 and y < 10.0:
		_phase = "spikes"
	elif x < 91.2 and y < 12.0:
		_phase = "frog"
	elif x < 101.0:
		_phase = "column"
	elif x < 112.8 and y < 8.0:
		_phase = "squeeze"
	elif x < 127.5:
		_phase = "lift"
	elif x < 149.0:
		_phase = "wind"
	elif x < 160.0:
		_phase = "frog2"
	elif x < 184.0:
		_phase = "ride"
	else:
		_phase = "goal"
	if on:
		_did_double = false


func _pulse_double() -> float:
	# just_pressed is required for the second jump. Hold, release 2 frames, repress.
	if _repress > 0:
		_repress -= 1
		return 0.0 if _repress > 0 else 1.0
	if (not _p.is_on_floor()) and _air > 14 and _p.velocity.y < 0.0 and not _did_double:
		_did_double = true
		_repress = 2
		return 0.0
	return 1.0


func _plan() -> Vector3:
	var feet := _p.global_position
	var x := feet.x
	var y := feet.y
	var on := _p.is_on_floor()
	var hanging: bool = bool(_p.get("_hanging"))
	if on:
		_air = 0
	else:
		_air += 1
	_advance_phase(x, y, on)

	if hanging:
		_jump_armed = false
		return Vector3(0.0, 0.0, 0.0)
	if _stuck > 160 and _phase != "p04":
		return Vector3(1.0, 1.0 if (_stuck % 50) < 10 else 0.0, 0.0)

	match _phase:
		"intro":
			# Full-hold first jump from ~11.9 lands on P02. No double — that overshoots.
			if on and x > 11.7:
				_jump_armed = true
			elif not on:
				_jump_armed = true
			else:
				_jump_armed = false
			return Vector3(1.0, 1.0 if _jump_armed else 0.0, 0.0)
		"p04":
			var m := _nearest_mover(x, y)
			if not on and x > 34.0:
				return Vector3(1.0, 1.0, 0.0)
			if y < 3.15:
				var under := m.x < 0.8 and m.y > x + 0.5
				if under:
					return Vector3(0.0, 1.0, 0.0)
				if x < 27.6:
					return Vector3(1.0, 0.0, 0.0)
				return Vector3(0.0, 0.0, 0.0)
			if x > 43.6:
				return Vector3(1.0, 1.0, 0.0)
			return Vector3(1.0, 0.0, 0.0)
		"crawl":
			if (not _k00) and on and x > 51.7 and x < 52.7:
				_k00 = true
				return Vector3(1.0, 1.0, 0.0)
			return Vector3(1.0, 0.0, 1.0)
		"spikes":
			# Double-jump H00. Release over P08 (hold+fall = hang on the
			# crumble), then hold again to grab P09's left lip — mantle
			# stands at ~82.8, left of frog H01 (84.0–84.75).
			if x < 71.5:
				if on and x > 63.9:
					_did_double = false
					return Vector3(1.0, 1.0, 0.0)
				if not on:
					return Vector3(1.0, _pulse_double(), 0.0)
				return Vector3(1.0, 0.0, 0.0)
			if x < 81.3:
				return Vector3(1.0, 0.0, 0.0)
			if not on:
				return Vector3(1.0, 1.0, 0.0)
			return Vector3(1.0, 0.0, 0.0)
		"frog":
			# After the P09 mantle we stand left of H01. Short-hop the frog,
			# then double-jump from ~88 onto P11 (top 14.67).
			if on and x < 83.8:
				return Vector3(1.0, 1.0, 0.0)
			if not on and x < 86.4:
				return Vector3(1.0, 1.0 if _air < 10 else 0.0, 0.0)
			if on and x < 87.8:
				return Vector3(1.0, 0.0, 0.0)
			if on:
				_did_double = false
				return Vector3(1.0, 1.0, 0.0)
			return Vector3(1.0, _pulse_double() if x < 96.5 else 0.0, 0.0)
		"column":
			if on and y > 12.0 and x < 96.8:
				return Vector3(1.0, 0.0, 0.0)
			if on and y > 12.0:
				return Vector3(1.0, 1.0, 0.0)
			if not on:
				return Vector3(1.0, 1.0 if _p.velocity.y > 0.0 else 0.0, 0.0)
			return Vector3(1.0, 0.0, 0.0)
		"squeeze":
			if x >= 113.2:
				return Vector3(0.0, 0.0, 0.0)
			return Vector3(1.0, 0.0, 1.0)
		"lift":
			var p14 := _mover_at(120.0)
			var left := p14.x
			var right := p14.y
			var top := p14.z
			var riding := on and x > 116.4 and y > 3.05
			if riding or (not on and x > 116.4 and y > 3.5):
				if y < 15.7:
					if x > right - 0.75:
						return Vector3(-1.0, 0.0, 0.0)
					if x < left + 0.75:
						return Vector3(1.0, 0.0, 0.0)
					return Vector3(0.0, 0.0, 0.0)
				return Vector3(1.0, 1.0, 0.0)
			var sampled := _p14_top > -50.0
			var rising := sampled and top > _p14_top + 0.01
			_p14_top = top
			# P14 is fast (±9 m). Catch it by grabbing the lip while we fall,
			# or by walking off P12 onto the deck near the bottom of the stroke.
			var grab := top > 4.8 and top < 11.2 and left < 3.8 and left > -0.8
			var step_on := rising and top > 1.1 and top < 3.4 and left < 3.8
			if grab:
				return Vector3(1.0, 1.0, 0.0)
			if step_on:
				return Vector3(1.0, 0.0, 0.0)
			if x > 113.5:
				return Vector3(0.0, 0.0, 0.0)
			return Vector3(1.0, 0.0, 0.0)
		"wind":
			if (not _k01) and on and x > 129.4 and x < 130.9:
				_k01 = true
				return Vector3(1.0, 1.0, 0.0)
			# Walk off P15 (wind already adds +x). A full jump overshoots into H02.
			if on:
				return Vector3(1.0, 0.0, 0.0)
			if x < 147.8:
				return Vector3(1.0, 0.0, 0.0)
			return Vector3(1.0, 1.0, 0.0)
		"frog2":
			# Stand left of H02 (151.0) after the P17 mantle, then short-hop.
			if on and x < 150.4:
				return Vector3(1.0, 1.0, 0.0)
			if not on and x < 153.4:
				return Vector3(1.0, 1.0 if _air < 8 else 0.0, 0.0)
			if on and x < 156.8:
				return Vector3(1.0, 0.0, 0.0)
			if on:
				return Vector3(1.0, 1.0, 0.0)
			return Vector3(1.0, 1.0 if x < 164.5 else 0.0, 0.0)
		"ride":
			var p19 := _mover_at(170.7)
			var left19 := p19.x
			var right19 := p19.y
			if x < 166.2 and y < 13.8:
				if on and x > 157.6:
					return Vector3(1.0, 1.0, 0.0)
				if not on:
					return Vector3(1.0, 1.0 if x < 164.8 else 0.0, 0.0)
				return Vector3(1.0, 0.0, 0.0)
			if on and right19 > 176.8 and x > 172.5:
				return Vector3(1.0, 1.0, 0.0)
			if on:
				if x > right19 - 0.55:
					return Vector3(0.0, 0.0, 0.0)
				return Vector3(1.0, 0.0, 0.0)
			return Vector3(1.0, 1.0 if x < 184.2 else 0.0, 0.0)
		_:
			return Vector3(1.0, 0.0, 0.0)


func _in_low_cover(x: float) -> bool:
	# P06 crawl 53.33–62.67. P13 squeeze 104–112.
	return (x > 52.4 and x < 63.4) or (x > 103.2 and x < 113.2)


func _gap_ahead(x: float, y: float) -> bool:
	var here := _support_top(x, y + 0.4)
	var land := _support_top(x + 2.3, y + 0.4)
	if here < -90.0:
		return false
	if land < -90.0:
		return true
	if land < here - 0.5:
		return true
	return false


func _hazard_hop(x: float, y: float) -> bool:
	if x > 63.6 and x < 69.8 and y < 4.2:
		return true
	# H01 (84.4, 8.33) H02 (151.0, 13.67)
	if absf(x - 84.4) < 1.6 and absf(y - 8.33) < 1.4:
		return true
	if absf(x - 151.0) < 1.6 and absf(y - 13.67) < 1.4:
		return true
	return false


func _mover_at(around_x: float) -> Vector3:
	# left, right, top of the mover whose centre is nearest around_x.
	var best := Vector3(-99.0, -99.0, -99.0)
	var best_dx := 99.0
	for body in _movers:
		if body == null or not (body is Node3D):
			continue
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var pos: Vector3 = (body as Node3D).global_position
		var sz: Vector3 = (mesh.mesh as BoxMesh).size
		var dx := absf(pos.x - around_x)
		if dx < best_dx:
			best_dx = dx
			best = Vector3(pos.x - sz.x * 0.5 - _p.global_position.x, \
					pos.x + sz.x * 0.5, pos.y + sz.y * 0.5)
	return best


func _nearest_mover(x: float, y: float) -> Vector3:
	# x = dist to left face (>=0 if ahead), y = right face, z = right face (copy)
	var best := Vector3(-1.0, -1.0, -1.0)
	var best_dist := 99.0
	for body in _movers:
		if body == null or not (body is Node3D):
			continue
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var pos: Vector3 = (body as Node3D).global_position
		var sz: Vector3 = (mesh.mesh as BoxMesh).size
		var top := pos.y + sz.y * 0.5
		if top < y - 0.5 or top > y + 5.5:
			continue
		var left := pos.x - sz.x * 0.5
		var right := pos.x + sz.x * 0.5
		var dist := left - x
		if absf(dist) < best_dist:
			best_dist = absf(dist)
			best = Vector3(dist, right, right)
	return best


func _higher_ahead(x: float, y: float) -> float:
	var best := -1.0
	# Only moving decks are mount targets. Static crates/oneways (P03/P07)
	# sit too high and steal the running jump.
	for body in _movers:
		if body == null or not (body is Node3D):
			continue
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var pos: Vector3 = (body as Node3D).global_position
		var sz: Vector3 = (mesh.mesh as BoxMesh).size
		var x0 := pos.x - sz.x * 0.5
		var x1 := pos.x + sz.x * 0.5
		var top := pos.y + sz.y * 0.5
		if top < y + 0.7 or top > y + 4.6:
			continue
		if x1 < x - 0.2 or x0 > x + 6.0:
			continue
		var dist := maxf(0.0, x0 - x)
		if best < 0.0 or dist < best:
			best = dist
	return best


func _mover_too_far(x: float, y: float) -> bool:
	var nxt := _support_top(x + 3.0, y + 2.0)
	if nxt > -90.0 and nxt >= y - 0.7:
		return false
	for body in _movers:
		if body == null or not (body is Node3D):
			continue
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var pos: Vector3 = (body as Node3D).global_position
		var sz: Vector3 = (mesh.mesh as BoxMesh).size
		var left := pos.x - sz.x * 0.5
		var top := pos.y + sz.y * 0.5
		if top < y - 1.2 or top > y + 7.0:
			continue
		if left > x + 0.3 and left < x + 9.0:
			return left > x + 4.6
	return false


func _support_top(x: float, y: float) -> float:
	var best := -999.0
	for raw in _plats:
		var p: Dictionary = raw
		if String(p.get("kind", "")) == "moving":
			continue
		var c: Array = p["center_m"]
		var s: Array = p["size_m"]
		var x0 := float(c[0]) - float(s[0]) * 0.5
		var x1 := float(c[0]) + float(s[0]) * 0.5
		if x < x0 or x > x1:
			continue
		var top := float(p["top_m"])
		if top <= y + 0.5 and top > best:
			best = top
	for body in _movers:
		if body == null or not (body is Node3D):
			continue
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null or not (mesh.mesh is BoxMesh):
			continue
		var pos: Vector3 = (body as Node3D).global_position
		var sz: Vector3 = (mesh.mesh as BoxMesh).size
		if x < pos.x - sz.x * 0.5 or x > pos.x + sz.x * 0.5:
			continue
		var top := pos.y + sz.y * 0.5
		if top <= y + 0.5 and top > best:
			best = top
	return best


func _step(move: float, held: bool, down := false) -> void:
	if move != _move:
		Input.action_release("move_left")
		Input.action_release("move_right")
		if move > 0.0:
			Input.action_press("move_right", 1.0)
		elif move < 0.0:
			Input.action_press("move_left", 1.0)
		_move = move
	if held and not _held:
		Input.action_press("jump")
	elif not held and _held:
		Input.action_release("jump")
	_held = held
	if down and not _down:
		Input.action_press("move_down")
	elif not down and _down:
		Input.action_release("move_down")
	_down = down
	await process_frame
