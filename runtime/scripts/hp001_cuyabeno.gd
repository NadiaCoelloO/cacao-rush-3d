extends Node
## HP-001 E1: high-poly totem + trunk kit for Cuyabeno (visual only).
## Totem sits on TotemWarpAnchor (same pivot/footprint as LOOK/greybox).
## Trunks instance LOOK-001 tree transforms via MultiMesh + visibility_range LODs.
## Collisions stay on the existing CSG shapes; this node never adds physics.

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
const CELL := 18.0
const VARIANTS := ["Thin", "Medium", "Thick"]

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
	print("HP001 wired totem LODs + %s trunk MultiMeshes" % str(VARIANTS))
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


func _harden_mat(mat: BaseMaterial3D) -> void:
	if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.45
	elif mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.45
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
