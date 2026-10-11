extends Node
## Holds jump on the active warpRandom pole. One press must log a single stub.


var _t := 0
var _secret: Dictionary = {}


func drive(_delta: float) -> void:
	var pilot := get_parent()
	var player: CharacterBody3D = pilot._player
	if _secret.is_empty():
		for pole in pilot._poles:
			if bool(pole["secret"]):
				_secret = pole
				break
		var spawn: Vector3 = _secret["spawn"]
		player.global_position = spawn
		player.velocity = Vector3.ZERO
	_t += 1
	if _t == 25:
		# First press only saves. Release, then hold.
		Input.action_press("jump")
	elif _t == 28:
		Input.action_release("jump")
	elif _t >= 50 and _t < 140:
		Input.action_press("jump")
	else:
		Input.action_release("jump")
	if _t == 150:
		print("RIO_WARP_CHECK status=%s lives=%d x=%.2f" % [pilot._status, pilot._lives, player.global_position.x])
		pilot.get_tree().quit()
