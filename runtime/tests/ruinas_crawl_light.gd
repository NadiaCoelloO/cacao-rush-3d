extends SceneTree
## Prone/crouch light check for the Ruinas crawl. Prints fill/rim Y against the
## current body center, then saves a drag still and a plate (Maya hidden) when
## RUINAS_STILL is set. Display + opengl3; headless images are not valid.
##   DISPLAY=:1 godot --rendering-driver opengl3 --fixed-fps 60 --path runtime -s res://tests/ruinas_crawl_light.gd

var _move := 0.0
var _down := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pilot: Node = (load("res://scenes/pilot_ruinas.tscn") as PackedScene).instantiate()
	root.add_child(pilot)
	var p: CharacterBody3D = pilot.get_node("PlayerMaya")
	var hud: CanvasLayer = pilot.get_node("UI")
	hud.visible = false
	for i in 8:
		await process_frame
	# Open floor (P00 top is 12 m). Down, no steer: crouch, not crawl.
	p.global_position = Vector3(8.0, 12.2, 0.0)
	p.velocity = Vector3.ZERO
	for i in 25:
		await _step(0.0, true)
	var crouch_ok := _lights_on_center(p, "crouch")
	_report("crouch", p)
	# Under P04. Down + move forces the drag pose; the lid blocks standing.
	p.global_position = Vector3(26.6, 12.2, 0.0)
	p.velocity = Vector3.ZERO
	for i in 18:
		await _step(1.0, true)
	_report("prone", p)
	var cam := p.get_node("Camera3D") as Camera3D
	var offset: Vector3 = p.camera_offset
	var focus: Vector3 = cam.global_position - offset
	print("CAM focus=(%.4f, %.4f) eye=(%.4f, %.4f, %.4f) feet=(%.4f, %.4f) h=%.4f" % [focus.x, focus.y, cam.global_position.x, cam.global_position.y, cam.global_position.z, p.global_position.x, p.global_position.y, float(p._h)])
	var out := OS.get_environment("RUINAS_STILL")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		p.velocity = Vector3.ZERO
		p.set_physics_process(false)
		pilot.set_physics_process(false)
		var late := pilot.get_node_or_null("LateSim")
		if late:
			late.set_physics_process(false)
		_write_body_box(p, "%s/crawl_box.txt" % out)
		await _save(p, "%s/crawl_still.png" % out)
		var visual: Node3D = p._visual
		var arms: Array[Node] = [p.get_node_or_null("PoseArmL"), p.get_node_or_null("PoseArmR")]
		if visual:
			visual.visible = false
		for arm in arms:
			if arm:
				arm.visible = false
		await _save(p, "%s/crawl_plate.png" % out)
	var fill: OmniLight3D = p.get_node("LOOK001_FILL_MayaBack")
	var rim: OmniLight3D = p.get_node("LOOK001_RIM_MayaFollow")
	var prone_ok := String(p.pose_id) == "drag" and _lights_on_center(p, "drag") and fill.light_cull_mask == 2 and rim.light_cull_mask == 2
	var ok := crouch_ok and prone_ok
	print("CRAWL_LIGHT %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _write_body_box(p: CharacterBody3D, path: String) -> void:
	var cam := p.get_node("Camera3D") as Camera3D
	var feet := p.global_position
	var h := float(p._h)
	var min_x := 10000.0
	var min_y := 10000.0
	var max_x := 0.0
	var max_y := 0.0
	var pts: Array[Vector3] = [
		feet + Vector3(-0.55, -0.02, -0.55),
		feet + Vector3(0.55, -0.02, 0.55),
		feet + Vector3(-0.55, h + 0.15, -0.55),
		feet + Vector3(0.55, h + 0.15, 0.55),
	]
	for arm_name in ["PoseArmL", "PoseArmR"]:
		var arm := p.get_node_or_null(arm_name) as Node3D
		if arm and arm.visible:
			pts.append(arm.global_position)
	for c in pts:
		if cam.is_position_behind(c):
			continue
		var s := cam.unproject_position(c)
		min_x = minf(min_x, s.x)
		min_y = minf(min_y, s.y)
		max_x = maxf(max_x, s.x)
		max_y = maxf(max_y, s.y)
	var note := FileAccess.open(path, FileAccess.WRITE)
	if note:
		note.store_string("%d %d %d %d\n" % [int(min_x) - 8, int(min_y) - 8, int(max_x) + 8, int(max_y) + 8])


func _lights_on_center(p: CharacterBody3D, pose: String) -> bool:
	var fill: OmniLight3D = p.get_node("LOOK001_FILL_MayaBack")
	var rim: OmniLight3D = p.get_node("LOOK001_RIM_MayaFollow")
	var h := float(p._h)
	var scale := h / float(p._stand_h)
	var center := h * 0.5
	return String(p.pose_id) == pose and absf(fill.position.y - (center + 0.32 * scale)) < 0.02 and absf(rim.position.y - (center + 0.58 * scale)) < 0.02


func _report(tag: String, p: CharacterBody3D) -> void:
	var fill: OmniLight3D = p.get_node("LOOK001_FILL_MayaBack")
	var rim: OmniLight3D = p.get_node("LOOK001_RIM_MayaFollow")
	var center := float(p._h) * 0.5
	print("LIGHT %s pose=%s h=%.4f center=%.4f fill_y=%.4f rim_y=%.4f mask=%d feet=(%.2f, %.2f)" % [tag, String(p.pose_id), float(p._h), center, fill.position.y, rim.position.y, fill.light_cull_mask, p.global_position.x, p.global_position.y])


func _save(p: CharacterBody3D, path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)
		print("STILL %s" % path)


func _step(move: float, down: bool) -> void:
	if move != _move:
		Input.action_release("move_left")
		Input.action_release("move_right")
		if move > 0.0:
			Input.action_press("move_right", move)
		_move = move
	if down != _down:
		if down:
			Input.action_press("move_down")
		else:
			Input.action_release("move_down")
		_down = down
	await process_frame
