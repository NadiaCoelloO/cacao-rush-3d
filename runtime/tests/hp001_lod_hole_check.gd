extends SceneTree
## Sample Godot 4.2.2 visibility_range hysteresis at 0.5 m from 0–100 m.
## Constants first, then the same check on MultiMeshes from a rendered pilot.
##   godot --headless --path runtime -s res://tests/hp001_lod_hole_check.gd
## Exit 1 if any distance hides every LOD of the totem or a trunk variant.

const HP := preload("res://scripts/hp001_cuyabeno.gd")
const PILOT := "res://scenes/pilot_cuyabeno.tscn"
const MAX_D := 100.0
const STEP := 0.5


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failed := 0
	print("HP001 LOD ranges (begin–end, margin)")
	_print_stack("totem", HP.TOTEM_LOD_BEGIN, HP.TOTEM_LOD_END, HP.TOTEM_LOD_MARGIN)
	_print_stack("trunk Thin/Medium/Thick", HP.LOD_BEGIN, HP.LOD_END, HP.LOD_MARGIN)
	_print_stack("dock", HP.DOCK_LOD_BEGIN, HP.DOCK_LOD_END, HP.DOCK_LOD_MARGIN)
	_print_stack("canopy Small/Medium/Large", HP.CANOPY_LOD_BEGIN, HP.CANOPY_LOD_END, HP.CANOPY_LOD_MARGIN)
	_print_stack("groundcover Fern/CacaoLeaves/Lily", HP.GC_LOD_BEGIN, HP.GC_LOD_END, HP.GC_LOD_MARGIN)
	failed += _check("totem", HP.TOTEM_LOD_BEGIN, HP.TOTEM_LOD_END, HP.TOTEM_LOD_MARGIN)
	for v in HP.VARIANTS:
		failed += _check("trunk %s" % v, HP.LOD_BEGIN, HP.LOD_END, HP.LOD_MARGIN)
	failed += _check("canopy", HP.CANOPY_LOD_BEGIN, HP.CANOPY_LOD_END, HP.CANOPY_LOD_MARGIN)
	failed += _check("dock", HP.DOCK_LOD_BEGIN, HP.DOCK_LOD_END, HP.DOCK_LOD_MARGIN)
	# Groundcover has no LOD2 on purpose: it may fade out past LOD1 end.
	failed += _check_until("groundcover Fern", HP.GC_LOD_BEGIN, HP.GC_LOD_END, HP.GC_LOD_MARGIN, 37.0)
	failed += _check_until("groundcover CacaoLeaves", HP.GC_LOD_BEGIN, HP.GC_LOD_END, HP.GC_LOD_MARGIN, 37.0)
	failed += _check_until("groundcover LilyPads", HP.GC_LOD_BEGIN, HP.GC_LOD_END, HP.GC_LOD_MARGIN, 37.0)
	failed += await _check_rendered_scene()
	if failed == 0:
		print("HP001 LOD HOLE CHECK: PASS (0 holes, 0–%.0f m @ %.1f m, first-frame hysteresis, rendered scene)" % [MAX_D, STEP])
		quit(0)
	else:
		print("HP001 LOD HOLE CHECK: FAIL (%d stacks)" % failed)
		quit(1)


func _print_stack(label: String, begins: Array, ends: Array, margin: float) -> void:
	print("  %s  margin=%.1f" % [label, margin])
	for i in begins.size():
		var end_s := "∞" if float(ends[i]) <= 0.0 else "%.1f" % float(ends[i])
		var inner_lo := float(begins[i]) + (0.0 if float(begins[i]) <= 0.0 else margin)
		var inner_hi := "∞" if float(ends[i]) <= 0.0 else "%.1f" % (float(ends[i]) - margin)
		print("    LOD%d  %.1f–%s  first-frame inner %.1f–%s" % [i, float(begins[i]), end_s, inner_lo, inner_hi])


func _check(label: String, begins: Array, ends: Array, margin: float) -> int:
	return _check_until(label, begins, ends, margin, MAX_D)


func _check_until(label: String, begins: Array, ends: Array, margin: float, max_d: float) -> int:
	var holes: PackedFloat32Array = HP.lod_stack_holes(begins, ends, margin, max_d, STEP)
	var samples := int(max_d / STEP) + 1
	if holes.is_empty():
		print("  %s: PASS  %d/%d distances have ≥1 LOD (0–%.1f m)" % [label, samples, samples, max_d])
		return 0
	print("  %s: FAIL  %d holes, first at %.1f m (showing up to 12)" % [label, holes.size(), holes[0]])
	var n := mini(12, holes.size())
	for i in n:
		print("    hole d=%.1f" % holes[i])
	return 1


func _check_rendered_scene() -> int:
	var packed: Resource = load(PILOT)
	if not (packed is PackedScene):
		print("  rendered scene: FAIL  could not load %s" % PILOT)
		return 1
	var pilot: Node = (packed as PackedScene).instantiate()
	root.add_child(pilot)
	for i in 8:
		await process_frame
	var stacks := {}
	_collect_hp_visuals(pilot, stacks)
	var failed := 0
	var seen := 0
	for key in stacks.keys():
		var nodes: Array = stacks[key]
		if nodes.is_empty():
			continue
		seen += 1
		var begins: Array = []
		var ends: Array = []
		var margin := 3.0
		var instances := 0
		for n in nodes:
			var gi := n as GeometryInstance3D
			begins.append(gi.visibility_range_begin)
			ends.append(gi.visibility_range_end)
			margin = gi.visibility_range_begin_margin
			if n is MultiMeshInstance3D:
				var mm := (n as MultiMeshInstance3D).multimesh
				if mm:
					instances += mm.instance_count
			else:
				instances += 1
		if instances <= 0:
			print("  rendered %s: FAIL  0 instances" % key)
			failed += 1
			continue
		var max_d := 37.0 if String(key).begins_with("gc") else MAX_D
		var holes: PackedFloat32Array = HP.lod_stack_holes(begins, ends, margin, max_d, STEP)
		if holes.is_empty():
			print("  rendered %s: PASS  %d visuals, %d instances, 0 holes 0–%.0f m" % [key, nodes.size(), instances, max_d])
		else:
			print("  rendered %s: FAIL  %d holes, first at %.1f m" % [key, holes.size(), holes[0]])
			failed += 1
	pilot.queue_free()
	if seen == 0:
		print("  rendered scene: FAIL  no HP001 visuals after instantiate")
		return 1
	print("  rendered scene: %d stacks sampled from pilot_cuyabeno.tscn" % seen)
	return failed


func _collect_hp_visuals(n: Node, stacks: Dictionary) -> void:
	var nm := String(n.name)
	if nm.begins_with("HP001_"):
		var key := _stack_key(nm)
		_collect_gi(n, key, stacks)
		return
	for c in n.get_children():
		_collect_hp_visuals(c, stacks)


func _collect_gi(n: Node, key: String, stacks: Dictionary) -> void:
	if n is GeometryInstance3D:
		if not stacks.has(key):
			stacks[key] = []
		(stacks[key] as Array).append(n)
	for c in n.get_children():
		_collect_gi(c, key, stacks)


func _stack_key(nm: String) -> String:
	if nm.find("Totem") >= 0 or nm.find("totem") >= 0:
		return "totem"
	if nm.find("Dock") >= 0:
		return "dock"
	if nm.find("Canopy") >= 0:
		return "canopy"
	if nm.find("Fern") >= 0 or nm.find("CacaoLeaves") >= 0 or nm.find("Lily") >= 0 or nm.find("Groundcover") >= 0 or nm.find("GC_") >= 0:
		return "gc"
	if nm.find("Trunk") >= 0:
		return "trunk"
	return "hp_other"
