extends SceneTree
## Sample Godot 4.2.2 visibility_range hysteresis at 0.5 m from 0–100 m.
##   godot --headless --path runtime -s res://tests/hp001_lod_hole_check.gd
## Exit 1 if any distance hides every LOD of the totem or a trunk variant.

const HP := preload("res://scripts/hp001_cuyabeno.gd")
const MAX_D := 100.0
const STEP := 0.5


func _init() -> void:
	var failed := 0
	print("HP001 LOD ranges (begin–end, margin)")
	_print_stack("totem", HP.TOTEM_LOD_BEGIN, HP.TOTEM_LOD_END, HP.TOTEM_LOD_MARGIN)
	_print_stack("trunk Thin/Medium/Thick", HP.LOD_BEGIN, HP.LOD_END, HP.LOD_MARGIN)
	_print_stack("dock", HP.DOCK_LOD_BEGIN, HP.DOCK_LOD_END, HP.DOCK_LOD_MARGIN)
	_print_stack("groundcover Fern/CacaoLeaves", HP.GC_LOD_BEGIN, HP.GC_LOD_END, HP.GC_LOD_MARGIN)
	failed += _check("totem", HP.TOTEM_LOD_BEGIN, HP.TOTEM_LOD_END, HP.TOTEM_LOD_MARGIN)
	for v in HP.VARIANTS:
		failed += _check("trunk %s" % v, HP.LOD_BEGIN, HP.LOD_END, HP.LOD_MARGIN)
	failed += _check("dock", HP.DOCK_LOD_BEGIN, HP.DOCK_LOD_END, HP.DOCK_LOD_MARGIN)
	# Groundcover has no LOD2 on purpose: it may fade out past LOD1 end.
	failed += _check_until("groundcover Fern", HP.GC_LOD_BEGIN, HP.GC_LOD_END, HP.GC_LOD_MARGIN, 37.0)
	failed += _check_until("groundcover CacaoLeaves", HP.GC_LOD_BEGIN, HP.GC_LOD_END, HP.GC_LOD_MARGIN, 37.0)
	if failed == 0:
		print("HP001 LOD HOLE CHECK: PASS (0 holes, 0–%.0f m @ %.1f m, first-frame hysteresis)" % [MAX_D, STEP])
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
