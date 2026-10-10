extends Node
## Physics tick after PlayerMaya so crumble reads the floor and capture pins the body.


func _physics_process(delta: float) -> void:
	var pilot := get_parent()
	if pilot and pilot.has_method("late_physics"):
		pilot.call("late_physics", delta)
