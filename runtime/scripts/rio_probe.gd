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


func _ready() -> void:
	_pilot = get_parent()
	_last_lives = int(_pilot._lives)
	print("RIO_PROBE start level=rio-1 inputs=only")


func _physics_process(delta: float) -> void:
	if _pilot == null or _pilot._player == null:
		return
	_t += delta
	_jump_cd = maxf(0.0, _jump_cd - delta)
	var player: CharacterBody3D = _pilot._player
	var feet := player.global_position
	var lives := int(_pilot._lives)
	if lives < _last_lives:
		_deaths += 1
		_death_x = feet.x
		_last_lives = lives
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
	else:
		_stuck += delta
	if _stuck > 14.0:
		_finish("blocked", feet, _reason(feet))
		return
	_log_t += delta
	if _log_t > 3.0:
		_log_t = 0.0
		print("RIO_PROBE tick t=%.1f x=%.2f y=%.2f vy=%.2f floor=%s lives=%d coins=%d" % [
			_t, feet.x, feet.y, player.velocity.y, player.is_on_floor(), lives, int(_pilot._coins_taken)
		])
	_drive(player, feet)


func _drive(player: CharacterBody3D, feet: Vector3) -> void:
	var spans := _spans()
	var current := _under(spans, feet)
	var nxt := _ahead(spans, feet, current)
	var hold_right := true
	var want_jump := false
	var want_down := false
	if _spike_ahead(feet):
		want_jump = true
	if current.is_empty():
		if player.velocity.y < 6.0 and player.velocity.y > -12.0 and not _air_jump and not nxt.is_empty():
			if float(nxt["left"]) - feet.x > 2.2:
				want_jump = true
				_air_jump = true
	else:
		_air_jump = false
		var edge := float(current["right"])
		var continuous := false
		if not nxt.is_empty():
			var gap := float(nxt["left"]) - edge
			var dy := float(nxt["top"]) - feet.y
			continuous = gap < 0.45 and absf(dy) < 0.55
			if continuous:
				hold_right = true
			elif gap < 8.5 and dy < 5.2 and dy > -3.2:
				hold_right = true
				if feet.x > edge - 1.45:
					want_jump = true
			else:
				hold_right = feet.x < edge - 1.1
				var ride := _ride(spans, feet)
				if not ride.is_empty():
					hold_right = true
					if feet.x > edge - 1.5:
						want_jump = true
		if str(current["kind"]) == "oneway" and not nxt.is_empty():
			if float(nxt["top"]) < feet.y - 1.3 and float(nxt["left"]) < edge + 1.0:
				want_down = true
				want_jump = true
	_set_action("move_right", hold_right)
	_set_action("move_left", false)
	_set_action("move_down", want_down)
	if want_jump and _jump_cd <= 0.0:
		Input.action_press("jump")
		_jump_cd = 0.26
	else:
		Input.action_release("jump")


func _spans() -> Array:
	var out: Array = []
	for body in _pilot._solids:
		var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape == null or shape.disabled:
			continue
		var box := shape.shape as BoxShape3D
		var c: Vector3 = body.global_position
		var s := box.size
		out.append({
			"left": c.x - s.x * 0.5,
			"right": c.x + s.x * 0.5,
			"top": c.y + s.y * 0.5,
			"bottom": c.y - s.y * 0.5,
			"kind": String(body.get_meta("kind")),
		})
	return out


func _under(spans: Array, feet: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dy := 1.0
	for s in spans:
		if feet.x < float(s["left"]) - 0.15 or feet.x > float(s["right"]) + 0.15:
			continue
		var dy := absf(float(s["top"]) - feet.y)
		if dy < 0.55 and dy < best_dy:
			best = s
			best_dy = dy
	return best


func _ahead(spans: Array, feet: Vector3, current: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_left := 1e9
	var edge := feet.x
	if not current.is_empty():
		edge = float(current["right"])
	for s in spans:
		if not current.is_empty() and absf(float(s["left"]) - float(current["left"])) < 0.05 and absf(float(s["top"]) - float(current["top"])) < 0.05:
			continue
		if float(s["right"]) < feet.x + 0.3:
			continue
		var dy := float(s["top"]) - feet.y
		if dy > 6.2 or dy < -6.0:
			continue
		if float(s["left"]) < best_left and float(s["left"]) >= edge - 0.8:
			best = s
			best_left = float(s["left"])
	return best


func _ride(spans: Array, feet: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dx := 1e9
	for s in spans:
		if str(s["kind"]) != "moving":
			continue
		var dx := float(s["left"]) - feet.x
		var dy := float(s["top"]) - feet.y
		if dx < -1.0 or dx > 7.0:
			continue
		if dy > 5.0 or dy < -2.5:
			continue
		if dx < best_dx:
			best = s
			best_dx = dx
	return best


func _spike_ahead(feet: Vector3) -> bool:
	for h in _pilot._hazards:
		if str(h["kind"]) != "spikes":
			continue
		var box: AABB = h["aabb"]
		if box.position.x > feet.x + 1.9 or box.end.x < feet.x + 0.2:
			continue
		if box.position.y < feet.y + 0.45 and box.end.y > feet.y - 0.15:
			return true
	return false


func _reason(feet: Vector3) -> String:
	var wall := false
	for s in _spans():
		if float(s["left"]) > feet.x + 0.05 and float(s["left"]) < feet.x + 1.1:
			if float(s["top"]) > feet.y + 1.6 and float(s["bottom"]) < feet.y + 1.2:
				wall = true
	if wall:
		return "vertical face in front, Maya has no wall hop (MOVE-001)"
	return "no progress for 14s at x=%.2f y=%.2f; gap or raft timing, wall hop not observed" % [feet.x, feet.y]


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
