extends Node
## Physics tick after PlayerMaya: wind, void, capture pin, camera clamp.


func _physics_process(delta: float) -> void:
	var pilot := get_parent()
	if pilot and pilot.has_method("late_physics"):
		pilot.call("late_physics", delta)
