extends Node
## Physics tick after PlayerMaya so crumble reads the floor and capture pins the body.


func _physics_process(delta: float) -> void:
	var play := get_parent()
	if play and play.has_method("late_physics"):
		play.call("late_physics", delta)
