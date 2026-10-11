extends Node
## Input-only route attempt for rio-1. No teleports. Reports a block instead of inventing a move.

var _pilot
var _t := 0.0
var _best_x := -1.0
var _stuck := 0.0
var _jump_cd := 0.0
var _deaths := 0
var _last_lives := 5
var _death_x := 0.0
var _log_t := 0.0
var _air_jump := false
var _cruise_t := 0.0
var _still_t := 0.0
var _sustain := 0.0
var _release_one := false
var _double_armed := false

const _JUMP_V := 720.0 / 24.0
const _RUN_V := 290.0 / 24.0
const _G_UP := 2100.0 / 24.0
const _G_DOWN := 3400.0 / 24.0
const _G_APEX := 1200.0 / 24.0
const _APEX_V := 80.0 / 24.0
const _MAX_FALL := 1100.0 / 24.0
const _SIM_DT := 1.0 / 60.0


func _ready() -> void:
	_pilot = get_parent()
	_last_lives = int(_pilot._lives)
	print("RIO_PROBE start level=rio-1 inputs=only")


func drive(delta: float) -> void:
	if _pilot == null or _pilot._player == null:
		return
	_t += delta
	_jump_cd = maxf(0.0, _jump_cd - delta)
	_cruise_t = maxf(0.0, _cruise_t - delta)
	_still_t = maxf(0.0, _still_t - delta)
	var player: CharacterBody3D = _pilot._player
	var feet := player.global_position
	var lives := int(_pilot._lives)
	if lives < _last_lives:
		_deaths += 1
		_death_x = feet.x
		_last_lives = lives
		_sustain = 0.0
		_double_armed = false
		_release_one = false
		Input.action_release("jump")
		print("RIO_PROBE death n=%d x=%.2f y=%.2f lives=%d" % [_deaths, feet.x, feet.y, lives])
	if str(_pilot._status) == "win":
		_finish("win", feet, "goal")
		return
	if str(_pilot._status) == "over" or _deaths >= 6:
		_finish("blocked", feet, "lives spent before the goal")
		return
	if _t > 120.0:
		_finish("blocked", feet, "timeout 120s")
		return
	if feet.x > _best_x + 0.45:
		_best_x = feet.x
		_stuck = 0.0
	elif feet.x < _best_x - 3.0:
		_best_x = feet.x
		_stuck = 0.0
	else:
		_stuck += delta
	if _stuck > 20.0:
		_finish("blocked", feet, _reason(feet))
		return
	_log_t += delta
	if _log_t > 3.0:
		_log_t = 0.0
		var nxt_id := "-"
		var spans := _spans()
		var nxt := _ahead(spans, feet, _under(spans, feet))
		if not nxt.is_empty():
			nxt_id = "%s@%.1f" % [String(nxt["id"]), float(nxt["top"])]
		print("RIO_PROBE tick t=%.1f x=%.2f y=%.2f vy=%.2f floor=%s lives=%d coins=%d nxt=%s" % [
			_t, feet.x, feet.y, player.velocity.y, player.is_on_floor(), lives, int(_pilot._coins_taken), nxt_id
		])
	_drive(player, feet, delta)


func _drive(player: CharacterBody3D, feet: Vector3, delta: float) -> void:
	var spans := _spans()
	var current := _under(spans, feet)
	var nxt := _ahead(spans, feet, current)
	var hold_right := false
	var hold_left := false
	var want_jump := false
	var want_down := false
	var want_double := false
	var hold_for := 0.52
	var dropping := false
	if not current.is_empty():
		_air_jump = false
		var plan := _plan(current, nxt, feet, player)
		hold_right = bool(plan["right"])
		hold_left = bool(plan["left"])
		want_jump = bool(plan["jump"])
		want_double = bool(plan["double"])
		want_down = bool(plan["down"])
		dropping = want_down
		hold_for = float(plan["hold"])
	else:
		if _still_t > 0.0:
			hold_right = false
			hold_left = false
		elif _cruise_t > 0.0:
			hold_right = player.velocity.x < 4.8
			hold_left = false
		elif player.velocity.x > 0.5:
			hold_right = true
		elif player.velocity.x < -0.5:
			hold_left = true
		if not _air_jump and not _double_armed and _sustain <= 0.0 and player.velocity.y < 2.0 and player.velocity.y > -8.0 and not nxt.is_empty():
			var vx := player.velocity.x
			if vx > 6.0 and _lands(float(_pilot._time), feet.x, feet.y, vx, nxt, true):
				want_jump = true
				_air_jump = true
	if _secret_under(feet):
		want_jump = false
		want_down = false
		dropping = false
		want_double = false
	elif _needs_save(feet):
		want_double = false
		hold_right = false
		if absf(player.velocity.x) > 1.0:
			hold_left = player.velocity.x > 0.0
		else:
			want_jump = true
			hold_left = false
			hold_for = 0.04
			_still_t = 0.45
	elif not current.is_empty():
		var hop := _spike_hold(current, feet, player.velocity.x)
		if hop >= 0.0 and not _short_overhead(current, nxt):
			want_jump = true
			want_double = false
			hold_right = true
			hold_left = false
			hold_for = hop
	if hold_right and not want_jump and _spike_close(feet):
		hold_right = false
	# Air keeps whatever horizontal speed she took off with. Once the slow
	# double jump has started, do not accelerate.
	if _cruise_t > 0.0 and player.velocity.y > 0.4:
		hold_right = false
		hold_left = false
	if want_jump and _sustain <= 0.0 and _jump_cd <= 0.0 and not Input.is_action_pressed("jump"):
		var cid := "-"
		var nid := "-"
		if not current.is_empty():
			cid = String(current["id"])
		if not nxt.is_empty():
			nid = String(nxt["id"])
		print("RIO_PROBE go cur=%s nxt=%s x=%.2f y=%.2f double=%s hold=%.2f" % [cid, nid, feet.x, feet.y, want_double, hold_for])
	_set_action("move_right", hold_right and not hold_left)
	_set_action("move_left", hold_left and not hold_right)
	_set_action("move_down", want_down)
	_jump_input(want_jump, want_double, dropping, hold_for, delta)


func _plan_is_step(current: Dictionary, nxt: Dictionary) -> bool:
	if current.is_empty() or nxt.is_empty():
		return false
	if float(nxt["top"]) < float(current["top"]) + 0.8:
		return false
	return float(nxt["left"]) < float(current["right"]) - 0.15 and float(nxt["right"]) > float(current["left"]) + 0.3


func _plan(current: Dictionary, nxt: Dictionary, feet: Vector3, player: CharacterBody3D) -> Dictionary:
	var edge := float(current["right"])
	var plan := {"right": false, "left": false, "jump": false, "double": false, "down": false, "hold": 0.52}
	if nxt.is_empty():
		var goal: AABB = _pilot._goal_aabb
		plan["right"] = feet.x < goal.position.x + 0.4
		return plan
	var gap := float(nxt["left"]) - edge
	var dy := float(nxt["top"]) - feet.y
	if _horizontal_dock(nxt) and absf(dy) < 0.55:
		if gap < 0.45:
			return _board(nxt, feet)
		return _camp(edge, feet)
	if _plan_is_step(current, nxt) and float(nxt["left"]) < edge - 0.4:
		return _step_up(current, nxt, feet, player, dy)
	if str(current["kind"]) == "oneway" and dy < -1.2 and float(nxt["left"]) < feet.x + 1.2 and float(nxt["right"]) > feet.x - 0.4:
		plan["down"] = true
		plan["jump"] = true
		plan["hold"] = 0.05
		return plan
	if dy < -1.2 and gap < 1.6 and _falls_onto(_pilot._time, edge - 0.2, float(current["top"]), _RUN_V, nxt):
		plan["right"] = feet.x < edge - 0.15
		return plan
	var time := float(_pilot._time)
	var ready: Dictionary = _lip_ready(current, nxt, time)
	if bool(ready["ok"]):
		var tx := float(ready["x"])
		if player.velocity.x > 6.0 and feet.x > tx - 0.45 and feet.x < tx + 0.55:
			plan["right"] = true
			plan["jump"] = true
			plan["double"] = bool(ready["double"])
		elif feet.x < tx - 0.15:
			plan["right"] = true
		elif feet.x > tx + 0.45:
			plan["left"] = true
		return plan
	if _window_soon(current, nxt, time):
		if feet.x < edge - 0.4:
			plan["right"] = true
		elif feet.x > edge - 0.12:
			plan["left"] = true
		return plan
	return _camp(edge, feet)


func _board(nxt: Dictionary, feet: Vector3) -> Dictionary:
	var plan := {"right": false, "left": false, "jump": false, "double": false, "down": false, "hold": 0.52}
	var deck_right := float(nxt["right"])
	if feet.x < deck_right - 1.4:
		plan["right"] = true
	elif feet.x > deck_right - 0.6:
		plan["left"] = true
	return plan


func _camp(edge: float, feet: Vector3) -> Dictionary:
	var plan := {"right": false, "left": false, "jump": false, "double": false, "down": false, "hold": 0.52}
	if feet.x < edge - 2.1:
		plan["right"] = true
	elif feet.x > edge - 1.15:
		plan["left"] = true
	return plan


func _short_overhead(current: Dictionary, nxt: Dictionary) -> bool:
	if not _plan_is_step(current, nxt):
		return false
	var deck_w := float(nxt["right"]) - float(nxt["left"])
	var dy := float(nxt["top"]) - float(current["top"])
	return deck_w < 5.5 and dy > 4.2


func _step_up(current: Dictionary, nxt: Dictionary, feet: Vector3, player: CharacterBody3D, dy: float) -> Dictionary:
	var plan := {"right": false, "left": false, "jump": false, "double": false, "down": false, "hold": 0.52}
	var edge := float(current["right"])
	var deck_w := float(nxt["right"]) - float(nxt["left"])
	var cruise := deck_w < 5.5 and dy > 4.2
	var stand := float(nxt["left"]) - (2.5 if cruise else 2.2)
	stand = minf(stand, edge - 0.9)
	if stand < float(current["left"]) + 0.4:
		stand = float(current["left"]) + 0.4
	if cruise:
		if feet.x < stand - 1.4:
			plan["right"] = true
		elif feet.x < stand - 0.15:
			plan["right"] = player.velocity.x < 4.2
		elif feet.x > stand + 0.45:
			plan["left"] = true
		elif player.velocity.x > 5.2:
			plan["right"] = false
		elif player.velocity.x >= 3.2:
			plan["jump"] = true
			plan["double"] = true
			_cruise_t = 1.25
		else:
			plan["right"] = true
		return plan
	if feet.x < stand - 0.2:
		plan["right"] = true
	elif feet.x > stand + 0.25:
		plan["left"] = true
	elif player.velocity.x > 8.0:
		plan["jump"] = true
		plan["double"] = dy > 4.1
		plan["right"] = true
	else:
		plan["right"] = true
	return plan


func _horizontal_dock(nxt: Dictionary) -> bool:
	if str(nxt["kind"]) != "moving" or not nxt.has("move"):
		return false
	var m: Dictionary = nxt["move"]
	return absf(float(m["ax"])) > 8.0 and absf(float(m["ay"])) < 8.0


func _jump_input(want_new: bool, want_double: bool, dropping: bool, hold_for: float, delta: float) -> void:
	if dropping:
		_sustain = 0.0
		_double_armed = false
		_release_one = false
		if want_new and _jump_cd <= 0.0:
			Input.action_press("jump")
			_jump_cd = 0.30
		else:
			Input.action_release("jump")
		return
	if _release_one:
		Input.action_release("jump")
		_release_one = false
		_sustain = 0.0
		return
	if _double_armed and _sustain <= 0.0 and not Input.is_action_pressed("jump"):
		Input.action_press("jump")
		_sustain = 0.52
		_double_armed = false
		return
	if want_new and _jump_cd <= 0.0 and _sustain <= 0.0 and not Input.is_action_pressed("jump"):
		Input.action_press("jump")
		_sustain = hold_for
		_jump_cd = 0.16
		_double_armed = want_double
		print("RIO_PROBE jump hold=%.2f double=%s" % [hold_for, want_double])
		return
	if _double_armed and _sustain > 0.0 and _sustain < 0.22:
		Input.action_release("jump")
		_sustain = 0.0
		_release_one = true
		return
	if _sustain > 0.0:
		_sustain = maxf(0.0, _sustain - delta)
		Input.action_press("jump")
	else:
		Input.action_release("jump")


func _future(s: Dictionary, time: float) -> Dictionary:
	if not s.has("move"):
		return {"left": s["left"], "right": s["right"], "top": s["top"], "vx": 0.0}
	var m: Dictionary = s["move"]
	var period := maxf(0.2, float(m["period"]))
	var ang := time * TAU / period + float(m["phase"])
	var nx := float(m["ox"]) + sin(ang) * float(m["ax"])
	var ny := float(m["oy"]) + cos(ang) * float(m["ay"])
	var w := float(s["w_px"])
	var om := TAU / period
	return {
		"left": nx / 24.0,
		"right": (nx + w) / 24.0,
		"top": (896.0 - ny) / 24.0,
		"vx": cos(ang) * float(m["ax"]) * om / 24.0,
	}


func _lip_ready(current: Dictionary, nxt: Dictionary, time: float) -> Dictionary:
	var fut := _future(current, time)
	var pvx := float(fut["vx"])
	var none := {"ok": false, "double": false, "x": 0.0}
	if pvx < -1.5:
		return none
	var take_y := float(fut["top"])
	var nxt_now := _future(nxt, time)
	var gap := float(nxt_now["left"]) - float(fut["right"])
	var backs: Array = [0.30]
	if gap < 3.2 and gap > -0.3:
		backs = [1.6, 2.2, 2.8]
	var saved: Dictionary = {}
	for back in backs:
		var take_x := float(fut["right"]) - float(back)
		if take_x < float(fut["left"]) + 0.35:
			continue
		if _lands(time, take_x, take_y, _RUN_V, nxt, false):
			return {"ok": true, "double": false, "x": take_x}
		if saved.is_empty() and _lands(time, take_x, take_y, _RUN_V, nxt, true):
			saved = {"ok": true, "double": true, "x": take_x}
	if not saved.is_empty():
		return saved
	return none


func _window_soon(current: Dictionary, nxt: Dictionary, time: float) -> bool:
	for ahead in [0.10, 0.20, 0.30]:
		var ready: Dictionary = _lip_ready(current, nxt, time + ahead)
		if bool(ready["ok"]):
			return true
	return false


func _lands(time: float, x0: float, y0: float, vx: float, nxt: Dictionary, double: bool) -> bool:
	var x := x0
	var y := y0
	var vy := _JUMP_V
	var t := 0.0
	var used := false
	while t < 1.65:
		if double and not used and t > 0.30 and vy < 8.0 and vy > -8.0:
			vy = _JUMP_V
			used = true
		var grav := _G_DOWN
		if vy > 0.0:
			grav = _G_APEX if vy < _APEX_V else _G_UP
		vy -= grav * _SIM_DT
		vy = maxf(vy, -_MAX_FALL)
		x += vx * _SIM_DT
		y += vy * _SIM_DT
		t += _SIM_DT
		var q := _future(nxt, time + t)
		if x > float(q["left"]) + 0.7 and x < float(q["right"]) - 0.85 and vy < -2.0:
			if y <= float(q["top"]) + 0.15 and y >= float(q["top"]) - 0.2 and not _spike_covers(x, float(q["top"])):
				return true
		if y < 3.4 and vy < 0.0:
			return false
	return false


func _falls_onto(time: float, x0: float, y0: float, vx: float, nxt: Dictionary) -> bool:
	var x := x0
	var y := y0
	var vy := 0.0
	var t := 0.0
	while t < 1.3:
		vy -= _G_DOWN * _SIM_DT
		vy = maxf(vy, -_MAX_FALL)
		x += vx * _SIM_DT
		y += vy * _SIM_DT
		t += _SIM_DT
		var q := _future(nxt, time + t)
		if x > float(q["left"]) + 0.1 and x < float(q["right"]) - 0.12 and vy < 0.0:
			if y <= float(q["top"]) + 0.35 and y >= float(q["top"]) - 0.55:
				return true
		if y < 3.4:
			return false
	return false


func _pole_here(feet: Vector3) -> Dictionary:
	for pole in _pilot._poles:
		var box: AABB = pole["aabb"]
		if feet.x < box.position.x - 0.05 or feet.x > box.end.x + 0.05:
			continue
		if feet.y < box.position.y - 0.4 or feet.y > box.end.y + 0.2:
			continue
		return pole
	return {}


func _secret_under(feet: Vector3) -> bool:
	var pole := _pole_here(feet)
	return not pole.is_empty() and bool(pole["secret"])


func _needs_save(feet: Vector3) -> bool:
	var pole := _pole_here(feet)
	return not pole.is_empty() and not bool(pole["secret"]) and not bool(pole["active"])


func _spans() -> Array:
	var out: Array = []
	for body in _pilot._solids:
		var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape == null or shape.disabled:
			if shape == null or String(body.get_meta("kind")) != "oneway":
				continue
		var box := shape.shape as BoxShape3D
		var c: Vector3 = body.global_position
		var s := box.size
		var span := {
			"id": String(body.name),
			"left": c.x - s.x * 0.5,
			"right": c.x + s.x * 0.5,
			"top": c.y + s.y * 0.5,
			"bottom": c.y - s.y * 0.5,
			"kind": String(body.get_meta("kind")),
			"w_px": s.x * 24.0,
			"ghost": shape.disabled,
		}
		if body.has_meta("move"):
			span["move"] = body.get_meta("move")
		out.append(span)
	return out


func _under(spans: Array, feet: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dy := 1.0
	for s in spans:
		if feet.x < float(s["left"]) - 0.15 or feet.x > float(s["right"]) + 0.15:
			continue
		if bool(s.get("ghost", false)):
			continue
		var dy := absf(float(s["top"]) - feet.y)
		if dy < 0.55 and dy < best_dy:
			best = s
			best_dy = dy
	return best


func _ahead(spans: Array, feet: Vector3, current: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 1e9
	for s in spans:
		if str(s["kind"]) == "crate":
			continue
		if not current.is_empty() and absf(float(s["left"]) - float(current["left"])) < 0.08 and absf(float(s["top"]) - float(current["top"])) < 0.08:
			continue
		if float(s["right"]) < feet.x + 0.2:
			continue
		# The deck we jumped off still extends under us. Don't drop back onto it.
		if float(s["top"]) < feet.y - 1.0 and float(s["left"]) < feet.x - 0.8:
			continue
		var dy := float(s["top"]) - feet.y
		if dy > 9.6 or dy < -9.0:
			continue
		var score := float(s["left"]) - feet.x
		if score < 0.0 and float(s["top"]) > feet.y + 0.6:
			score = 0.15
		if score < best_score:
			best = s
			best_score = score
	return best


func _spike_covers(x: float, top: float) -> bool:
	for h in _pilot._hazards:
		if str(h["kind"]) != "spikes":
			continue
		var box: AABB = h["aabb"]
		if x < box.position.x - 0.15 or x > box.end.x + 0.15:
			continue
		if top > box.position.y - 0.4 and top < box.end.y + 0.8:
			return true
	return false


func _spike_hold(current: Dictionary, feet: Vector3, vx: float) -> float:
	if vx < 11.0:
		return -1.0
	var lip := _spike_left(feet)
	if lip > feet.x + 0.85 or lip < feet.x + 0.25:
		return -1.0
	var spike_end := _spike_right(feet)
	if spike_end < 0.0:
		return -1.0
	var edge := float(current["right"])
	var lo := spike_end + 0.65 - feet.x
	var hi := edge - 0.4 - feet.x
	if hi < lo:
		return -1.0
	# hold seconds → horizontal travel of a run jump, measured from the same gravity.
	var options := [[0.05, 3.55], [0.08, 3.95], [0.10, 4.55], [0.12, 4.95], [0.15, 5.50]]
	for opt in options:
		var travel := float(opt[1])
		if travel >= lo and travel <= hi:
			return float(opt[0])
	return -1.0


func _spike_right(feet: Vector3) -> float:
	var best := -1.0
	for h in _pilot._hazards:
		if str(h["kind"]) != "spikes":
			continue
		var box: AABB = h["aabb"]
		if box.end.x < feet.x:
			continue
		if box.position.y > feet.y + 0.7 or box.end.y < feet.y - 0.2:
			continue
		if box.position.x > feet.x + 3.0:
			continue
		best = maxf(best, box.end.x)
	return best


func _spike_close(feet: Vector3) -> bool:
	var lip := _spike_left(feet)
	return lip < feet.x + 0.55 and lip > feet.x - 0.2


func _spike_left(feet: Vector3) -> float:
	var best := 1e9
	for h in _pilot._hazards:
		if str(h["kind"]) != "spikes":
			continue
		var box: AABB = h["aabb"]
		if box.end.x < feet.x + 0.15:
			continue
		if box.position.y > feet.y + 0.7 or box.end.y < feet.y - 0.2:
			continue
		best = minf(best, box.position.x)
	return best


func _reason(feet: Vector3) -> String:
	var wall := false
	for s in _spans():
		if float(s["left"]) > feet.x + 0.05 and float(s["left"]) < feet.x + 1.1:
			if float(s["top"]) > feet.y + 1.6 and float(s["bottom"]) < feet.y + 1.2:
				wall = true
	if wall:
		return "vertical face in front, Maya has no wall hop (MOVE-001)"
	return "no progress for 20s at x=%.2f y=%.2f; gap or raft timing, wall hop not observed" % [feet.x, feet.y]


func _set_action(action: String, down: bool) -> void:
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _finish(result: String, feet: Vector3, reason: String) -> void:
	print("RIO_PROBE result=%s t=%.2f x=%.2f y=%.2f lives=%d coins=%d deaths=%d reason=%s" % [
		result, _t, feet.x, feet.y, int(_pilot._lives), int(_pilot._coins_taken), _deaths, reason
	])
	_pilot.get_tree().quit()
