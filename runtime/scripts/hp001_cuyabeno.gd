extends Node
## HP-001 E1/E2b: high-poly totem + trunk kit + canopy v2 + visual dock + groundcover.
## Totem sits on TotemWarpAnchor (same pivot/footprint as LOOK/greybox).
## Trunks/crowns instance LOOK-001 tree transforms via MultiMesh + visibility_range.
## Dock and groundcover are visual only. Collisions stay on the existing CSG
## shapes; this node never adds physics. WaterLily flower is sparse + cream.

const TOTEM := [
	"res://models/hp001/totem_warp_cuyabeno_hp_LOD0.glb",
	"res://models/hp001/totem_warp_cuyabeno_hp_LOD1.glb",
	"res://models/hp001/totem_warp_cuyabeno_hp_LOD2.glb",
]
const TRUNK := [
	"res://models/hp001/trunk_selva_kit_hp_LOD0.glb",
	"res://models/hp001/trunk_selva_kit_hp_LOD1.glb",
	"res://models/hp001/trunk_selva_kit_hp_LOD2.glb",
]
const TREES_JSON := "res://data/hp001_tree_instances.json"
const DOCK := [
	"res://models/hp001/dock_cuyabeno_hp_LOD0.glb",
	"res://models/hp001/dock_cuyabeno_hp_LOD1.glb",
	"res://models/hp001/dock_cuyabeno_hp_LOD2.glb",
]
const GROUNDCOVER := [
	"res://models/hp001/groundcover_cuyabeno_LOD0.glb",
	"res://models/hp001/groundcover_cuyabeno_LOD1.glb",
]
const CANOPY := [
	"res://models/hp001/canopy_cuyabeno_hp_LOD0.glb",
	"res://models/hp001/canopy_cuyabeno_hp_LOD1.glb",
	"res://models/hp001/canopy_cuyabeno_hp_LOD2.glb",
]
const BEAM_ORIGIN_LOCAL := Vector3(-0.0009, 2.2783, 0.220)
# Trunks: overlap enough that Godot 4.2.2 first-frame hysteresis cannot
# hide every LOD (become-visible uses [begin+margin, end-margin]).
# LOD2 end = 0 → visible to the camera far plane. Same ranges for Thin/Medium/Thick.
const LOD_BEGIN := [0.0, 14.0, 32.0]
const LOD_END := [26.0, 44.0, 0.0]
const LOD_MARGIN := 3.0
# Totem is a unique prop: never fully culled. Inner ranges abut/overlap
# under the same hysteresis (laguna/dosel sit ~18 m from the post).
const TOTEM_LOD_BEGIN := [0.0, 28.0, 58.0]
const TOTEM_LOD_END := [36.0, 66.0, 0.0]
const TOTEM_LOD_MARGIN := 4.0
# Dock: unique prop, never fully culled (same hysteresis rule as the totem).
const DOCK_LOD_BEGIN := [0.0, 28.0, 58.0]
const DOCK_LOD_END := [36.0, 66.0, 0.0]
const DOCK_LOD_MARGIN := 4.0
# Groundcover LOD0/1 overlap; LOD1 fades out (no LOD2 in the kit).
const GC_LOD_BEGIN := [0.0, 12.0]
const GC_LOD_END := [18.0, 40.0]
const GC_LOD_MARGIN := 3.0
const GC_KINDS := ["Fern", "CacaoLeaves", "WaterLilyPads", "WaterLily"]
# Identidad PASA on the flower: ~1 of every 4–5 lily groups. Flag stays so it
# can be switched off without unwiring the mesh.
const LILY_FLOWER_ENABLED := true
const LILY_FLOWER_RATIO := 0.22
const LILY_CREAM := Color("8f8578")
# Canopy v2: overlapping LODs, LOD2 never culled. First-frame inner 0–13 / 13–29 / 29–∞.
const CANOPY_LOD_BEGIN := [0.0, 10.0, 26.0]
const CANOPY_LOD_END := [16.0, 32.0, 0.0]
const CANOPY_LOD_MARGIN := 3.0
# Blender Z-up fork offset → Godot Y-up (x, z, −y). Same transform as the trunk.
const CANOPY_KIND := {"Thin": "Small", "Medium": "Medium", "Thick": "Large"}
const CANOPY_LOCAL_OFF := {
	"Thin": Vector3(0.5679, 6.72, -0.5651),
	"Medium": Vector3(-0.2995, 9.24, -0.0545),
	"Thick": Vector3(-0.5955, 11.76, -0.0651),
}
# No greybox wooden walkway in the lagoon: pier on the −Z shore, east of the
# totem, off the playable strip / oneway / solid (x≈10, into the lagoon).
const DOCK_ORIGIN := Vector3(10.0, 0.0, -4.0)
const DOCK_YAW := PI * 0.5
const DOCK_SEGMENTS := [
	{"kind": "Straight", "along_m": 2.0},
	{"kind": "End", "along_m": 6.0},
]
const FLOOR_COLLISION_TOP := 0.0
const CELL := 18.0
const VARIANTS := ["Thin", "Medium", "Thick"]
var dock_deck_delta_m := 0.0

var totem_mats: Array[BaseMaterial3D] = []


func wire(pilot: Node3D) -> bool:
	if not ResourceLoader.exists(TOTEM[0]) or not ResourceLoader.exists(TRUNK[0]):
		push_warning("HP001: GLBs missing, leave LOOK totem/trees")
		return false
	if not ResourceLoader.exists(TREES_JSON):
		push_warning("HP001: tree instance JSON missing")
		return false
	_wire_totem(pilot)
	_wire_trunks(pilot)
	_wire_canopy(pilot)
	_wire_dock(pilot)
	_wire_groundcover(pilot)
	print("HP001 wired totem + trunks + canopy v2 + dock + groundcover")
	return true


func _wire_totem(pilot: Node3D) -> void:
	totem_mats.clear()
	var anchor: Node3D = pilot.get_node_or_null("WorldRoot/TotemWarpAnchor")
	if anchor == null:
		push_error("HP001: TotemWarpAnchor missing")
		return
	var marker := Marker3D.new()
	marker.name = "BeamOrigin"
	marker.position = BEAM_ORIGIN_LOCAL
	anchor.add_child(marker)
	var shared: BaseMaterial3D = null
	for lod in TOTEM.size():
		if not ResourceLoader.exists(TOTEM[lod]):
			continue
		var packed: Resource = load(TOTEM[lod])
		if not (packed is PackedScene):
			continue
		var inst: Node = (packed as PackedScene).instantiate()
		inst.name = "HP001_Totem_LOD%d" % lod
		anchor.add_child(inst)
		_hide_legacy_beam_empties(inst)
		var mi := _find_named(inst, "Totem_LOD%d" % lod) as MeshInstance3D
		if mi == null:
			mi = _find_mesh_instance(inst)
		if mi == null:
			continue
		if lod == 0:
			var mat := mi.material_override
			if mat == null:
				mat = mi.get_active_material(0)
			if mat is BaseMaterial3D:
				shared = (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				_harden_mat(shared)
				shared.resource_name = "M_Totem_HP"
				totem_mats.append(shared)
		_style_totem_geometry(inst, lod, shared)
	_share_totem_custom_aabb(anchor)


func _wire_trunks(pilot: Node3D) -> void:
	var kit := _load_trunk_kit()
	var meshes: Dictionary = kit["meshes"]
	var bark: BaseMaterial3D = kit["bark"]
	var trees := _load_trees()
	if trees.is_empty():
		push_error("HP001: no tree instances")
		return
	var grouped: Dictionary = {}
	for t in trees:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var variant := String(t.get("variant", "Medium"))
		var xf := _xform_from(t)
		var key := _cluster_key(xf.origin)
		if not grouped.has(variant):
			grouped[variant] = {}
		var cells: Dictionary = grouped[variant]
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(xf)
	var root := Node3D.new()
	root.name = "HP001_Trunks"
	var world: Node3D = pilot.get_node_or_null("WorldRoot")
	if world:
		world.add_child(root)
	else:
		add_child(root)
	var mm_count := 0
	for variant in VARIANTS:
		if not grouped.has(variant):
			continue
		var cells: Dictionary = grouped[variant]
		for key in cells.keys():
			var xforms: Array = cells[key]
			var centroid := Vector3.ZERO
			for xf in xforms:
				centroid += (xf as Transform3D).origin
			centroid /= float(xforms.size())
			var cluster_mmis: Array[MultiMeshInstance3D] = []
			var shared_aabb := AABB()
			var have_aabb := false
			for lod in 3:
				var mesh_key := "%s_%d" % [variant, lod]
				if not meshes.has(mesh_key):
					continue
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = meshes[mesh_key]
				mm.instance_count = xforms.size()
				for i in xforms.size():
					var world_xf: Transform3D = xforms[i]
					var local := Transform3D(world_xf.basis, world_xf.origin - centroid)
					mm.set_instance_transform(i, local)
					if lod == 0:
						var inst_aabb := _xform_aabb(local, mm.mesh.get_aabb())
						if not have_aabb:
							shared_aabb = inst_aabb
							have_aabb = true
						else:
							shared_aabb = shared_aabb.merge(inst_aabb)
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "HP001_Trunk_%s_LOD%d_%d_%d" % [variant, lod, key.x, key.y]
				mmi.multimesh = mm
				mmi.position = centroid
				if bark:
					mmi.material_override = bark
				mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				_apply_lod_range(mmi, LOD_BEGIN[lod], LOD_END[lod], LOD_MARGIN)
				# Shadows: directional key only, and only near LOD0 clusters.
				var xz := Vector2(centroid.x, centroid.z).length()
				if lod == 0 and xz <= 24.0:
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				else:
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mmi)
				cluster_mmis.append(mmi)
				mm_count += 1
			# Same custom AABB on every LOD so Godot's AABB-center distance
			# cannot open a hole between meshes of different height.
			if have_aabb:
				for mmi in cluster_mmis:
					mmi.custom_aabb = shared_aabb
	print("HP001 trunks: ", trees.size(), " instances, ", mm_count, " MultiMeshes")


func _wire_canopy(pilot: Node3D) -> void:
	if not ResourceLoader.exists(CANOPY[0]):
		push_warning("HP001: canopy GLBs missing")
		return
	var kit := _load_named_kit(CANOPY, ["Small", "Medium", "Large"], "Canopy_Clump_%s_LOD%d", "M_Canopy_HP")
	var meshes: Dictionary = kit["meshes"]
	var mat: BaseMaterial3D = kit["mat"]
	if mat:
		_harden_mat(mat, 0.5, true)
		# Leaf grade toward sunlit yellow-green (README sat↑ hue− val↑), not olive.
		mat.albedo_color = Color(1.10, 1.16, 0.80)
	var placements := _canopy_placements()
	var world: Node3D = pilot.get_node_or_null("WorldRoot")
	var root := Node3D.new()
	root.name = "HP001_Canopy"
	if world:
		world.add_child(root)
	else:
		add_child(root)
	var mm_count := 0
	for kind in ["Small", "Medium", "Large"]:
		var by_cell: Dictionary = {}
		for p in placements:
			if String(p["kind"]) != kind:
				continue
			var xf: Transform3D = p["xf"]
			var key := _cluster_key(xf.origin)
			if not by_cell.has(key):
				by_cell[key] = []
			(by_cell[key] as Array).append(xf)
		for key in by_cell.keys():
			var xforms: Array = by_cell[key]
			var centroid := Vector3.ZERO
			for xf in xforms:
				centroid += (xf as Transform3D).origin
			centroid /= float(xforms.size())
			var cluster_mmis: Array[MultiMeshInstance3D] = []
			var shared_aabb := AABB()
			var have_aabb := false
			for lod in 3:
				var mesh_key := "%s_%d" % [kind, lod]
				if not meshes.has(mesh_key):
					continue
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = meshes[mesh_key]
				mm.instance_count = xforms.size()
				for i in xforms.size():
					var world_xf: Transform3D = xforms[i]
					var local := Transform3D(world_xf.basis, world_xf.origin - centroid)
					mm.set_instance_transform(i, local)
					if lod == 0:
						var inst_aabb := _xform_aabb(local, mm.mesh.get_aabb())
						if not have_aabb:
							shared_aabb = inst_aabb
							have_aabb = true
						else:
							shared_aabb = shared_aabb.merge(inst_aabb)
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "HP001_Canopy_%s_LOD%d_%d_%d" % [kind, lod, key.x, key.y]
				mmi.multimesh = mm
				mmi.position = centroid
				if mat:
					mmi.material_override = mat
				mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				_apply_lod_range(mmi, CANOPY_LOD_BEGIN[lod], CANOPY_LOD_END[lod], CANOPY_LOD_MARGIN)
				var xz := Vector2(centroid.x, centroid.z).length()
				if lod == 0 and xz <= 28.0:
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				else:
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mmi)
				cluster_mmis.append(mmi)
				mm_count += 1
			if have_aabb:
				for mmi in cluster_mmis:
					mmi.custom_aabb = shared_aabb
	print("HP001 canopy: ", placements.size(), " crowns, ", mm_count, " MultiMeshes")


func _canopy_placements() -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261010
	var trees := _load_trees()
	for t in trees:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var variant := String(t.get("variant", "Medium"))
		if not CANOPY_KIND.has(variant):
			continue
		var xf := _xform_from(t)
		var off: Vector3 = CANOPY_LOCAL_OFF[variant]
		# Mixed crown heights + some lateral slip so they are not one mushroom.
		off.y *= rng.randf_range(0.90, 1.14)
		if rng.randf() < 0.58:
			off.x += rng.randf_range(-0.38, 0.38)
			off.z += rng.randf_range(-0.30, 0.30)
		var origin := xf * off
		var basis := xf.basis
		# Random yaw hides the LOD2 impostor thread.
		basis = Basis(Vector3.UP, rng.randf() * TAU) * basis
		if rng.randf() < 0.64:
			var axis := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			if axis.length() > 0.01:
				basis = Basis(axis.normalized(), deg_to_rad(rng.randf_range(2.4, 7.8))) * basis
		out.append({"kind": String(CANOPY_KIND[variant]), "xf": Transform3D(basis, origin)})
	# Filler crowns above LOOK sky-gap spots (no trunk; merge into the ceiling).
	var fillers := [
		{"kind": "Large", "origin": Vector3(2.6, 15.4, -3.8)},
		{"kind": "Medium", "origin": Vector3(-2.0, 16.2, -6.2)},
		{"kind": "Large", "origin": Vector3(5.8, 16.8, -8.8)},
		{"kind": "Small", "origin": Vector3(-6.2, 14.8, 3.6)},
		{"kind": "Medium", "origin": Vector3(8.4, 15.6, -12.4)},
		{"kind": "Large", "origin": Vector3(-4.8, 17.0, -14.2)},
		{"kind": "Large", "origin": Vector3(-12.0, 16.2, -20.0)},
		{"kind": "Medium", "origin": Vector3(14.2, 15.6, -18.5)},
		{"kind": "Large", "origin": Vector3(0.4, 17.4, -24.0)},
		{"kind": "Medium", "origin": Vector3(-14.5, 15.2, 8.0)},
		{"kind": "Large", "origin": Vector3(16.0, 16.4, 6.2)},
		{"kind": "Small", "origin": Vector3(10.5, 17.0, -30.0)},
		{"kind": "Large", "origin": Vector3(-16.0, 16.6, -8.5)},
		{"kind": "Medium", "origin": Vector3(4.2, 18.0, -34.0)},
	]
	for spec in fillers:
		var yaw := rng.randf() * TAU
		var s := rng.randf_range(0.92, 1.12)
		var b := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
		out.append({"kind": String(spec["kind"]), "xf": Transform3D(b, spec["origin"])})
	return out


func _wire_dock(pilot: Node3D) -> void:
	if not ResourceLoader.exists(DOCK[0]):
		push_warning("HP001: dock GLBs missing")
		return
	var kit := _load_named_kit(DOCK, ["Straight", "End", "Step"], "Dock_%s_LOD%d", "M_Dock_HP")
	var meshes: Dictionary = kit["meshes"]
	var mat: BaseMaterial3D = kit["mat"]
	if mat:
		# Subtle bark/irregularity on fascia and bearers (atlas multiply).
		mat.albedo_color = Color(0.86, 0.78, 0.68)
		mat.roughness = maxf(mat.roughness, 0.78)
	if not meshes.has("Straight_0"):
		push_warning("HP001: Dock_Straight mesh missing")
		return
	var deck_top := _deck_plank_top_y(meshes["Straight_0"])
	# Visual Y only. CSGFloor top is y=0; Maya stands on that at the bank.
	var root_y := FLOOR_COLLISION_TOP - deck_top
	dock_deck_delta_m = (root_y + deck_top) - FLOOR_COLLISION_TOP
	var world: Node3D = pilot.get_node_or_null("WorldRoot")
	var root := Node3D.new()
	root.name = "HP001_Dock"
	root.position = Vector3(DOCK_ORIGIN.x, root_y, DOCK_ORIGIN.z)
	root.rotation.y = DOCK_YAW
	if world:
		world.add_child(root)
	else:
		add_child(root)
	for spec in DOCK_SEGMENTS:
		var kind := String(spec["kind"])
		var along_m := float(spec["along_m"])
		for lod in 3:
			var key := "%s_%d" % [kind, lod]
			if not meshes.has(key):
				continue
			var mi := MeshInstance3D.new()
			mi.name = "HP001_Dock_%s_LOD%d" % [kind, lod]
			mi.mesh = meshes[key]
			mi.position = Vector3(along_m, 0.0, 0.0)
			if mat:
				mi.material_override = mat
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			_apply_lod_range(mi, DOCK_LOD_BEGIN[lod], DOCK_LOD_END[lod], DOCK_LOD_MARGIN)
			if lod == 0:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			else:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
	print(
		"HP001 dock deck_top_local=%.4f collision_top=%.4f visual_y=%.4f delta=%.4f"
		% [deck_top, FLOOR_COLLISION_TOP, root_y, dock_deck_delta_m]
	)


func _wire_groundcover(pilot: Node3D) -> void:
	if not ResourceLoader.exists(GROUNDCOVER[0]):
		push_warning("HP001: groundcover GLBs missing")
		return
	var kit := _load_named_kit(GROUNDCOVER, GC_KINDS, "GC_%s_LOD%d", "M_Groundcover")
	var meshes: Dictionary = kit["meshes"]
	var mat: BaseMaterial3D = kit["mat"]
	if mat:
		_harden_mat(mat, 0.5, true)
	var flower_mat: BaseMaterial3D = null
	if mat:
		flower_mat = mat.duplicate() as BaseMaterial3D
		# White petals → Maya cream from the material (atlas still drives pads).
		flower_mat.albedo_color = LILY_CREAM.lightened(0.18)
	var placements := _scatter_groundcover()
	var world: Node3D = pilot.get_node_or_null("WorldRoot")
	var root := Node3D.new()
	root.name = "HP001_Groundcover"
	if world:
		world.add_child(root)
	else:
		add_child(root)
	var mm_count := 0
	for kind in GC_KINDS:
		var by_cell: Dictionary = {}
		for p in placements:
			if String(p["kind"]) != kind:
				continue
			var xf: Transform3D = p["xf"]
			var key := _cluster_key(xf.origin)
			if not by_cell.has(key):
				by_cell[key] = []
			(by_cell[key] as Array).append(xf)
		for key in by_cell.keys():
			var xforms: Array = by_cell[key]
			var centroid := Vector3.ZERO
			for xf in xforms:
				centroid += (xf as Transform3D).origin
			centroid /= float(xforms.size())
			var cluster_mmis: Array[MultiMeshInstance3D] = []
			var shared_aabb := AABB()
			var have_aabb := false
			for lod in GC_LOD_BEGIN.size():
				var mesh_key := "%s_%d" % [kind, lod]
				if not meshes.has(mesh_key):
					continue
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = meshes[mesh_key]
				mm.instance_count = xforms.size()
				for i in xforms.size():
					var world_xf: Transform3D = xforms[i]
					var local := Transform3D(world_xf.basis, world_xf.origin - centroid)
					mm.set_instance_transform(i, local)
					if lod == 0:
						var inst_aabb := _xform_aabb(local, mm.mesh.get_aabb())
						if not have_aabb:
							shared_aabb = inst_aabb
							have_aabb = true
						else:
							shared_aabb = shared_aabb.merge(inst_aabb)
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "HP001_GC_%s_LOD%d_%d_%d" % [kind, lod, key.x, key.y]
				mmi.multimesh = mm
				mmi.position = centroid
				var use_mat := flower_mat if kind == "WaterLily" and flower_mat else mat
				if use_mat:
					mmi.material_override = use_mat
				mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_apply_lod_range(mmi, GC_LOD_BEGIN[lod], GC_LOD_END[lod], GC_LOD_MARGIN)
				root.add_child(mmi)
				cluster_mmis.append(mmi)
				mm_count += 1
			if have_aabb:
				for mmi in cluster_mmis:
					mmi.custom_aabb = shared_aabb
	print("HP001 groundcover: ", placements.size(), " instances, ", mm_count, " MultiMeshes (lily flower flag=", LILY_FLOWER_ENABLED, ")")


func _load_named_kit(paths: Array, variants: Array, name_fmt: String, mat_name: String) -> Dictionary:
	var meshes := {}
	var shared: BaseMaterial3D = null
	for lod in paths.size():
		if not ResourceLoader.exists(paths[lod]):
			continue
		var packed: Resource = load(paths[lod])
		if not (packed is PackedScene):
			continue
		var inst: Node = (packed as PackedScene).instantiate()
		for v in variants:
			var mi := _find_named(inst, name_fmt % [v, lod]) as MeshInstance3D
			if mi == null:
				mi = _find_named_contains(inst, "%s_LOD%d" % [v, lod]) as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			meshes["%s_%d" % [v, lod]] = mi.mesh
			if lod == 0 and shared == null:
				var mat := mi.material_override
				if mat == null:
					mat = mi.get_active_material(0)
				if mat is BaseMaterial3D:
					shared = (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					_harden_mat(shared)
					shared.resource_name = mat_name
		inst.free()
	return {"meshes": meshes, "mat": shared}


func _deck_plank_top_y(mesh: Mesh) -> float:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0.42
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var acc := 0.0
	var n := 0
	for v in verts:
		# Planks: deck width 1.8 m (local Z), height band around 0.42; skip posts/piles.
		if abs(v.x) < 1.95 and abs(v.z) < 0.92 and v.y > 0.30 and v.y < 0.52:
			acc += v.y
			n += 1
	if n == 0:
		return 0.42
	return acc / float(n)


func _scatter_groundcover() -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261006
	var trees := _load_trees()
	var n_fern := 0
	var n_leaf := 0
	# Ferns hugging tree bases off the playable strip.
	for t in trees:
		if n_fern >= 10:
			break
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var o: Array = t.get("origin", [])
		if o.size() < 3:
			continue
		var base := Vector3(float(o[0]), float(o[1]), float(o[2]))
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(1.35, 2.4)
		var p := Vector3(base.x + cos(ang) * rad, max(base.y, -0.08), base.z + sin(ang) * rad)
		if _gc_blocked(p):
			continue
		out.append({"kind": "Fern", "xf": _gc_xform(p, rng)})
		n_fern += 1
	# Shore belts (lagoon −Z and back +Z), off the 8 m playable floor.
	var tries := 0
	while (n_fern < 12 or n_leaf < 16) and tries < 220:
		tries += 1
		var shore := -1.0 if rng.randf() < 0.62 else 1.0
		var p := Vector3(
			rng.randf_range(-11.5, 12.5),
			-0.04,
			shore * rng.randf_range(4.45, 7.4)
		)
		if _gc_blocked(p):
			continue
		if n_fern < 12 and rng.randf() < 0.45:
			out.append({"kind": "Fern", "xf": _gc_xform(p, rng)})
			n_fern += 1
		elif n_leaf < 16:
			p.y = -0.06
			out.append({"kind": "CacaoLeaves", "xf": _gc_xform(p, rng)})
			n_leaf += 1
	# Lilies on the lagoon, off the dock and playable strip. Pads by default;
	# flowered groups ~1/4–5 when the Identidad flag is on.
	var n_lily := 0
	var n_flower := 0
	var lily_tries := 0
	while n_lily < 10 and lily_tries < 160:
		lily_tries += 1
		var p := Vector3(
			rng.randf_range(-10.5, 9.5),
			-0.12,
			rng.randf_range(-13.5, -5.2)
		)
		if _gc_blocked(p):
			continue
		var flower := LILY_FLOWER_ENABLED and rng.randf() < LILY_FLOWER_RATIO
		var kind := "WaterLily" if flower else "WaterLilyPads"
		out.append({"kind": kind, "xf": _gc_xform(p, rng)})
		n_lily += 1
		if flower:
			n_flower += 1
	return out


func _gc_xform(origin: Vector3, rng: RandomNumberGenerator) -> Transform3D:
	var yaw := rng.randf() * TAU
	var s := rng.randf_range(0.82, 1.18)
	var b := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
	return Transform3D(b, origin)


func _gc_blocked(p: Vector3) -> bool:
	# Playable strip (CSGFloor 24×8), oneway, solid, totem, dock.
	if abs(p.z) < 3.35 and abs(p.x) < 11.2:
		return true
	if p.x > 4.0 and p.x < 8.2 and abs(p.z) < 1.35:
		return true
	if Vector2(p.x - 7.5, p.z).length() < 1.6:
		return true
	if p.x > 8.6 and p.x < 11.5 and p.z < -3.4 and p.z > -12.5:
		return true
	return false


func _load_trunk_kit() -> Dictionary:
	var meshes := {}
	var bark: BaseMaterial3D = null
	for lod in TRUNK.size():
		if not ResourceLoader.exists(TRUNK[lod]):
			continue
		var packed: Resource = load(TRUNK[lod])
		if not (packed is PackedScene):
			continue
		var inst: Node = (packed as PackedScene).instantiate()
		for v in VARIANTS:
			var mi := _find_named(inst, "Trunk_%s_LOD%d" % [v, lod]) as MeshInstance3D
			if mi == null:
				mi = _find_named_contains(inst, "Trunk_%s" % v) as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			meshes["%s_%d" % [v, lod]] = mi.mesh
			if lod == 0 and bark == null:
				var mat := mi.material_override
				if mat == null:
					mat = mi.get_active_material(0)
				if mat is BaseMaterial3D:
					bark = (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					_harden_mat(bark)
					bark.resource_name = "M_Bark_HP"
		inst.free()
	return {"meshes": meshes, "bark": bark}


func _load_trees() -> Array:
	var txt := FileAccess.get_file_as_string(TREES_JSON)
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	var trees = data.get("trees", [])
	if typeof(trees) != TYPE_ARRAY:
		return []
	return trees


func _xform_from(t: Dictionary) -> Transform3D:
	var xa: Array = t["x_axis"]
	var ya: Array = t["y_axis"]
	var za: Array = t["z_axis"]
	var o: Array = t["origin"]
	var basis := Basis(
		Vector3(float(xa[0]), float(xa[1]), float(xa[2])),
		Vector3(float(ya[0]), float(ya[1]), float(ya[2])),
		Vector3(float(za[0]), float(za[1]), float(za[2]))
	)
	return Transform3D(basis, Vector3(float(o[0]), float(o[1]), float(o[2])))


func _cluster_key(origin: Vector3) -> Vector2i:
	return Vector2i(int(floor(origin.x / CELL)), int(floor(origin.z / CELL)))


func _apply_lod_range(gi: GeometryInstance3D, begin: float, end: float, margin: float = LOD_MARGIN) -> void:
	gi.visibility_range_begin = begin
	gi.visibility_range_end = end
	gi.visibility_range_begin_margin = margin
	gi.visibility_range_end_margin = margin
	gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## Godot 4.2.2 `_visibility_range_check` with FADE_DISABLED.
## First frame (was_visible=false) uses [begin+margin, end-margin];
## once visible, hysteresis widens to [begin-margin, end+margin].
## end=0 means no far cull.
static func godot422_range_visible(dist: float, begin: float, end: float, margin: float, was_visible: bool) -> bool:
	var begin_offset := -margin
	var end_offset := margin
	if not was_visible:
		begin_offset = -begin_offset
		end_offset = -end_offset
	if end > 0.0 and dist > end + end_offset:
		return false
	if begin > 0.0 and dist < begin + begin_offset:
		return false
	return true


static func lod_stack_holes(begins: Array, ends: Array, margin: float, max_d := 100.0, step := 0.5) -> PackedFloat32Array:
	var holes := PackedFloat32Array()
	var d := 0.0
	while d <= max_d + 0.0001:
		var any := false
		for lod in begins.size():
			if godot422_range_visible(d, float(begins[lod]), float(ends[lod]), margin, false):
				any = true
				break
		if not any:
			holes.append(d)
		d += step
	return holes


func _harden_mat(mat: BaseMaterial3D, scissor: float = 0.45, double_sided: bool = false) -> void:
	if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = scissor
	elif mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = scissor
	elif mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		mat.alpha_scissor_threshold = scissor
	if double_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _style_totem_geometry(n: Node, lod: int, shared: BaseMaterial3D) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		_apply_lod_range(gi, TOTEM_LOD_BEGIN[lod], TOTEM_LOD_END[lod], TOTEM_LOD_MARGIN)
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if lod >= 2:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if n is MeshInstance3D and shared:
			(n as MeshInstance3D).material_override = shared
	for c in n.get_children():
		_style_totem_geometry(c, lod, shared)


func _xform_aabb(xf: Transform3D, aabb: AABB) -> AABB:
	var out := AABB(xf * aabb.position, Vector3.ZERO)
	for i in 8:
		out = out.expand(xf * aabb.get_endpoint(i))
	return out


func _share_totem_custom_aabb(anchor: Node3D) -> void:
	var gis: Array[GeometryInstance3D] = []
	_collect_totem_gi(anchor, gis)
	if gis.is_empty():
		return
	var union_world := AABB()
	var have := false
	for gi in gis:
		var world := _xform_aabb(gi.global_transform, gi.get_aabb())
		if not have:
			union_world = world
			have = true
		else:
			union_world = union_world.merge(world)
	if not have:
		return
	for gi in gis:
		gi.custom_aabb = _xform_aabb(gi.global_transform.affine_inverse(), union_world)


func _collect_totem_gi(n: Node, out: Array[GeometryInstance3D]) -> void:
	if n is GeometryInstance3D:
		var walk: Node = n
		while walk:
			if String(walk.name).begins_with("HP001_Totem"):
				out.append(n as GeometryInstance3D)
				break
			walk = walk.get_parent()
	for c in n.get_children():
		_collect_totem_gi(c, out)


func _hide_legacy_beam_empties(n: Node) -> void:
	if String(n.name) == "VFX_WarpBeam_Spawn":
		n.name = "VFX_WarpBeam_Spawn_Legacy"
	for c in n.get_children():
		_hide_legacy_beam_empties(c)


func _find_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c in n.get_children():
		var hit := _find_mesh_instance(c)
		if hit:
			return hit
	return null


func _find_named(n: Node, exact: String) -> Node:
	if n.name == exact:
		return n
	for c in n.get_children():
		var hit := _find_named(c, exact)
		if hit:
			return hit
	return null


func _find_named_contains(n: Node, token: String) -> Node:
	if String(n.name).find(token) >= 0 and n is MeshInstance3D:
		return n
	for c in n.get_children():
		var hit := _find_named_contains(c, token)
		if hit:
			return hit
	return null
