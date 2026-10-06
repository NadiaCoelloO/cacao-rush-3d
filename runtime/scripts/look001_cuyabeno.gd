extends Node3D
## LOOK-001 atmosphere reconstructed in Godot (Forward+).
## The selva_look001_LOD*.glb files carry geometry + simple PBR/unlit/emissive
## only. Water ripples, SSR + probe, volumetric fog banks, sky, warp beam, and
## filmic grade are built here from LOOK-001_manifest.json. High-poly HOLD.
##
## Capture (optional, not used by the feel harness):
##   godot --path runtime res://scenes/pilot_cuyabeno.tscn -- --look001-capture=both --look001-out=/path

const WATER_MAT := preload("res://materials/m_blackwater.tres")
const BEAM_GOLD_MAT := preload("res://materials/m_warp_beam_gold.tres")
const BEAM_CYAN_MAT := preload("res://materials/m_warp_beam_cyan.tres")

const WATER_Y := -0.12
const TOTEM_XZ := Vector3(7.5, 0.0, 0.0)
const MAYA_STILL := Vector3(5.55, 1.20, 0.0)
const WARP_GOLD_ACTIVE := 3.0
const WARP_CYAN_ACTIVE := 2.4
const WARP_GOLD_DIM := 0.55
const WARP_CYAN_DIM := 0.28
const TOTEM_LIGHT_ACTIVE := 1.4
const TOTEM_LIGHT_DIM := 0.35
## paint_v03 / M_MAYA_GREY — cream-grey, never white puro. Mesh materials only
## (not surface overrides) so T-020 crouch/crawl overrides still land on Maya_Body.
const MAYA_BODY := Color("8f8578")
const MAYA_HAIR := Color("6b5a46")
const MAYA_PACK := Color("8a7358")
const ONEWAY_SLAB := Color("847866")
const ONEWAY_CUE := Color("4a3a2a")
const PLAT_ALBEDO := Color(0.62, 0.57, 0.48)
## Soft top-edge lift on greybox platforms only (not Maya). Keep this low —
## combined with the path lights, 0.4+ reads as white puro.
const PLAT_EMIT := Color(0.42, 0.38, 0.32)
const PLAT_EMIT_ENERGY := 0.14
const CACAO_Y := Color("d6ab3d")
const CACAO_O := Color("ce722e")
const CACAO_R := Color("a64b36")

## FogVolume ellipsoids from manifest fog.banks (AerialHaze omitted — world
## volumetric fog on the Environment covers that role in Forward+).
const FOG_BANKS := [
	{"pos": Vector3(5.0604, 0.1, -12.1359), "size": Vector3(9.0, 1.685, 4.4), "yaw": 129.5},
	{"pos": Vector3(3.2528, 0.05, -11.3375), "size": Vector3(9.0, 1.509, 3.6), "yaw": 123.2},
	{"pos": Vector3(-6.6207, 0.05, -11.4544), "size": Vector3(10.0, 1.529, 3.2), "yaw": 39.3},
	{"pos": Vector3(16.1031, 0.1, -6.9233), "size": Vector3(7.0, 1.645, 4.4), "yaw": 8.5},
	{"pos": Vector3(-1.7874, 0.15, -19.1504), "size": Vector3(12.0, 1.587, 6.0), "yaw": 119.9},
	{"pos": Vector3(11.7899, 0.15, -24.188), "size": Vector3(13.0, 1.574, 7.0), "yaw": 42.5},
	{"pos": Vector3(-12.4072, 0.15, -22.9836), "size": Vector3(12.0, 1.707, 7.0), "yaw": 78.2},
	{"pos": Vector3(1.8832, 0.2, -31.2905), "size": Vector3(16.0, 1.34, 8.0), "yaw": 153.4},
	{"pos": Vector3(-4.2383, 0.05, 12.0472), "size": Vector3(12.0, 1.893, 4.4), "yaw": 107.6},
	{"pos": Vector3(9.1565, 0.05, 13.231), "size": Vector3(10.0, 1.402, 4.0), "yaw": 62.2},
	{"pos": Vector3(-14.9336, 0.1, -13.5821), "size": Vector3(9.0, 1.499, 6.0), "yaw": 100.3},
	{"pos": Vector3(20.0532, 0.1, -14.9661), "size": Vector3(10.0, 1.454, 6.0), "yaw": 149.6},
]

## Mid-height haze between trunks (not over landing tops). Fills the air the
## ground-hugging banks leave empty, matching the Blender stills.
const FOG_TRUNKS := [
	# light2: volumes that sat between Cam_Laguna and Maya (z≈-11 / -9.5)
	# dropped; remaining banks live deeper in the lagoon, above playable y.
	{"pos": Vector3(-8.5, 5.5, -18.0), "size": Vector3(14.0, 8.5, 11.0), "yaw": 42.0},
	{"pos": Vector3(0.5, 7.0, -26.0), "size": Vector3(24.0, 11.0, 14.0), "yaw": 10.0},
	{"pos": Vector3(11.0, 6.0, -24.0), "size": Vector3(14.0, 8.0, 12.0), "yaw": 55.0},
]

var _env: Environment
var _totem_light: OmniLight3D
var _beam: Node3D
var _warp_mats: Array[BaseMaterial3D] = []
var _pod_mats: Array[BaseMaterial3D] = []
var _lod_roots: Array[Node] = []


func apply(pilot: Node3D, lod_roots: Array) -> void:
	_lod_roots.clear()
	for r in lod_roots:
		if r is Node:
			_lod_roots.append(r)
	_bind_look_meshes()
	_grade_platforms()
	_grade_oneway(pilot)
	_grade_csg_playable(pilot)
	_grade_hero(pilot)
	_thicken_canopy()
	_build_environment(pilot)
	_build_lights(pilot)
	_build_fog()
	_build_probe()
	_build_kakaw_pods(pilot)
	_build_beam(pilot)
	set_totem_state(true)


func set_totem_state(active: bool) -> void:
	var gold := WARP_GOLD_ACTIVE if active else WARP_GOLD_DIM
	var cyan := WARP_CYAN_ACTIVE if active else WARP_CYAN_DIM
	for mat in _warp_mats:
		if mat == null:
			continue
		var energy := gold
		if String(mat.resource_name).find("CYAN") >= 0:
			energy = cyan
		mat.emission_energy_multiplier = energy
	# Pods keep a readable glow even when the beam is off (dosel).
	for mat in _pod_mats:
		if mat == null:
			continue
		mat.emission_energy_multiplier = 1.15 if active else 0.70
	if _totem_light:
		_totem_light.light_energy = TOTEM_LIGHT_ACTIVE if active else TOTEM_LIGHT_DIM
	if _beam:
		_beam.visible = active


func force_lod0() -> void:
	for i in _lod_roots.size():
		var root := _lod_roots[i]
		var keep := i == 0
		root.visible = keep
		if keep:
			_clear_visibility_range(root)


func capture_still(shot: String, out_path: String) -> void:
	var tree := get_tree()
	var vp := tree.root.get_viewport()
	vp.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	force_lod0()
	var hud := get_parent().get_node_or_null("UI")
	if hud:
		hud.visible = false
	var player: Node3D = get_parent().get_node_or_null("PlayerMaya")
	if player:
		player.global_position = MAYA_STILL
		player.rotation = Vector3.ZERO
		player.set_physics_process(false)
		var play_cam: Camera3D = player.get_node_or_null("Camera3D")
		if play_cam:
			play_cam.current = false
	var cam: Camera3D
	var pods_cam: Camera3D = null
	if shot == "pods":
		pods_cam = Camera3D.new()
		pods_cam.name = "Cam_TotemPods"
		pods_cam.fov = 32.0
		pods_cam.far = 80.0
		pods_cam.position = Vector3(8.85, 3.08, 1.25)
		get_parent().add_child(pods_cam)
		pods_cam.look_at(Vector3(7.50, 2.86, 0.0), Vector3.UP)
		cam = pods_cam
	else:
		var cam_name := "Cam_Laguna" if shot == "laguna" else "Cam_Dosel"
		cam = get_parent().get_node_or_null(cam_name)
	if cam == null:
		push_error("LOOK-001 capture: missing camera for " + shot)
		return
	if player and shot != "pods":
		if shot == "dosel":
			# 3/4 toward Cam_Dosel so she reads as a character, not a blade.
			var aim := Vector3(cam.global_position.x, player.global_position.y, cam.global_position.z)
			player.look_at(aim, Vector3.UP)
			player.rotate_y(deg_to_rad(38.0))
		else:
			player.rotation.y = deg_to_rad(35.0)
	cam.current = true
	set_totem_state(shot != "dosel")
	# More frames so volumetric fog / SSR settle on software rasterizers too.
	for i in 24:
		await tree.process_frame
	var img: Image = vp.get_texture().get_image()
	if img == null:
		push_error("LOOK-001 capture: viewport image is null (headless dummy?)")
		return
	img.save_png(out_path)
	print("LOOK-001 wrote ", out_path, " ", img.get_width(), "x", img.get_height())
	if pods_cam:
		pods_cam.queue_free()


func _bind_look_meshes() -> void:
	_warp_mats.clear()
	for root in _lod_roots:
		_walk_look(root)


func _walk_look(n: Node) -> void:
	if n.name.begins_with("SELVA_GP_Oneway"):
		n.visible = false
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if n.name.begins_with("LOOK001_Blackwater"):
			mi.material_override = WATER_MAT
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if n.name.begins_with("LOOK001_Totem_Warp"):
			# Hide baked cone + gold blob (they read as fire from Cam_TotemPods).
			# Gold shaft rings are rebuilt as greybox in _build_kakaw_pods.
			n.visible = false
		if n.name.begins_with("LOOK001_Totem_Post"):
			var wood_post := StandardMaterial3D.new()
			wood_post.albedo_color = Color(0.28, 0.20, 0.13)
			wood_post.vertex_color_use_as_albedo = false
			wood_post.emission_enabled = false
			wood_post.roughness = 0.85
			mi.material_override = wood_post
	for c in n.get_children():
		_walk_look(c)


func _grade_hero(pilot: Node3D) -> void:
	var player: Node = pilot.get_node_or_null("PlayerMaya")
	if player == null:
		return
	_grade_hero_node(player)


func _grade_hero_node(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			mi.mesh = mi.mesh.duplicate()
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if not (mat is BaseMaterial3D):
					continue
				var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				var slot := String(d.resource_name)
				# Lit albedo, emission off: unlit #f1ddc1 reads as white puro under filmic.
				d.emission_enabled = false
				d.emission_energy_multiplier = 0.0
				d.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				d.roughness = 0.48
				if slot.begins_with("Maya_Body"):
					d.albedo_color = MAYA_BODY
				elif slot.begins_with("Maya_Hair"):
					d.albedo_color = MAYA_HAIR
				elif slot.begins_with("Maya_Pack"):
					d.albedo_color = MAYA_PACK
				else:
					d.albedo_color = MAYA_BODY
				mi.mesh.surface_set_material(s, d)
	for c in n.get_children():
		_grade_hero_node(c)


func _grade_platforms() -> void:
	for root in _lod_roots:
		_grade_platform_node(root)


func _grade_platform_node(n: Node) -> void:
	if n is MeshInstance3D:
		var nm := String(n.name)
		if nm.begins_with("SELVA_GP_PlatformSolid") or nm.begins_with("SELVA_GP_Platforms") or nm.begins_with("SELVA_GP_Floor"):
			var mi := n as MeshInstance3D
			if mi.mesh:
				for s in mi.mesh.get_surface_count():
					var mat := mi.get_active_material(s)
					if mat is BaseMaterial3D:
						var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
						d.albedo_color = PLAT_ALBEDO
						d.vertex_color_use_as_albedo = true
						_rim_platform_mat(d)
						mi.set_surface_override_material(s, d)
	for c in n.get_children():
		_grade_platform_node(c)


func _grade_oneway(pilot: Node3D) -> void:
	var anchor: Node = pilot.get_node_or_null("WorldRoot/PlatformOnewayAnchor")
	if anchor:
		_grade_oneway_node(anchor)


func _grade_oneway_node(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			mi.mesh = mi.mesh.duplicate()
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if not (mat is BaseMaterial3D):
					continue
				var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				var slot := String(d.resource_name)
				if slot.find("Cue") >= 0:
					d.albedo_color = ONEWAY_CUE
					d.emission_enabled = false
					d.emission_energy_multiplier = 0.0
					d.roughness = 0.78
				else:
					d.albedo_color = ONEWAY_SLAB
					_rim_platform_mat(d)
				mi.mesh.surface_set_material(s, d)
	for c in n.get_children():
		_grade_oneway_node(c)


func _rim_platform_mat(d: BaseMaterial3D) -> void:
	d.emission_enabled = true
	d.emission = PLAT_EMIT
	d.emission_energy_multiplier = PLAT_EMIT_ENERGY
	d.roughness = 0.50
	d.metallic = 0.0


func _grade_csg_playable(pilot: Node3D) -> void:
	# Collision CSGs can still draw if the LOD floor doesn't cover them.
	for path in [
		"WorldRoot/FloorPlaceholder/CSGFloor",
		"WorldRoot/FloorPlaceholder/CSGPlatform",
		"WorldRoot/PlatformOnewayAnchor/PlatformOnewayPlaceholder/CSGOneway",
	]:
		var n: Node = pilot.get_node_or_null(path)
		if not (n is CSGPrimitive3D):
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PLAT_ALBEDO
		_rim_platform_mat(mat)
		(n as CSGPrimitive3D).material = mat


func _thicken_canopy() -> void:
	# Reuse the LOD canopy mesh (not a new high-poly) to close sky holes.
	for root in _lod_roots:
		var canopy := _find_named(root, "LOOK001_Canopy")
		if canopy == null or not (canopy is MeshInstance3D):
			continue
		var parent := canopy.get_parent()
		if parent == null:
			continue
		for k in 1:
			var extra := (canopy as MeshInstance3D).duplicate() as MeshInstance3D
			extra.name = "%s_cover%d" % [canopy.name, k]
			extra.rotate_y(deg_to_rad(21.0))
			extra.scale = Vector3(1.08, 1.04, 1.08)
			extra.position.y += 0.45
			parent.add_child(extra)
		# Identidad notes: extra clumps over the top-centre sky gaps (dosel + laguna).
		# High Y only — does not sit on the playable route.
		var covers := [
			{"yaw": 48.0, "scale": Vector3(1.16, 1.10, 1.16), "off": Vector3(2.5, 1.35, -3.5)},
			{"yaw": -38.0, "scale": Vector3(1.12, 1.08, 1.12), "off": Vector3(-1.8, 1.70, -5.0)},
			{"yaw": 72.0, "scale": Vector3(1.20, 1.12, 1.20), "off": Vector3(4.2, 1.90, -7.2)},
		]
		for i in covers.size():
			var spec: Dictionary = covers[i]
			var clump := (canopy as MeshInstance3D).duplicate() as MeshInstance3D
			clump.name = "%s_gap%d" % [canopy.name, i]
			clump.rotate_y(deg_to_rad(spec["yaw"]))
			clump.scale = spec["scale"]
			clump.position += spec["off"]
			parent.add_child(clump)
	_add_canopy_leaf_cards()


func _add_canopy_leaf_cards() -> void:
	# Dark olive cards, no shadows, high above the path. Closes sepia sky
	# at Cam_Dosel / Cam_Laguna top-centre without darkening the route.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.11, 0.15, 0.10)
	mat.roughness = 0.95
	mat.emission_enabled = false
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cards := [
		{"pos": Vector3(5.8, 13.6, -1.2), "size": Vector2(9.0, 5.5), "eul": Vector3(deg_to_rad(-18.0), deg_to_rad(12.0), 0.0)},
		{"pos": Vector3(7.4, 14.8, -4.0), "size": Vector2(8.0, 5.0), "eul": Vector3(deg_to_rad(-12.0), deg_to_rad(-25.0), 0.0)},
		{"pos": Vector3(2.2, 15.4, -8.5), "size": Vector2(10.0, 6.0), "eul": Vector3(deg_to_rad(-22.0), deg_to_rad(40.0), 0.0)},
		{"pos": Vector3(0.6, 16.6, -10.2), "size": Vector2(9.5, 5.5), "eul": Vector3(deg_to_rad(-28.0), deg_to_rad(-10.0), 0.0)},
		{"pos": Vector3(4.8, 15.2, -6.4), "size": Vector2(8.5, 5.2), "eul": Vector3(deg_to_rad(-16.0), deg_to_rad(55.0), 0.0)},
		{"pos": Vector3(9.0, 14.2, 1.0), "size": Vector2(7.5, 4.5), "eul": Vector3(deg_to_rad(-14.0), deg_to_rad(-50.0), 0.0)},
	]
	for i in cards.size():
		var spec: Dictionary = cards[i]
		var plane := PlaneMesh.new()
		plane.size = spec["size"]
		var mi := MeshInstance3D.new()
		mi.name = "LOOK001_LeafCard_%02d" % i
		mi.mesh = plane
		mi.material_override = mat
		mi.position = spec["pos"]
		mi.rotation = spec["eul"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _find_named(n: Node, prefix: String) -> Node:
	if n.name.begins_with(prefix):
		return n
	for c in n.get_children():
		var hit := _find_named(c, prefix)
		if hit:
			return hit
	return null


func _clear_visibility_range(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.visibility_range_begin = 0.0
		mi.visibility_range_end = 0.0
	for c in n.get_children():
		_clear_visibility_range(c)


func _build_environment(pilot: Node3D) -> void:
	var we: WorldEnvironment = pilot.get_node_or_null("WorldEnvironment")
	if we == null:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		pilot.add_child(we)
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3a4844")
	sky_mat.sky_horizon_color = Color("6a655c")
	sky_mat.ground_horizon_color = Color("4a5048")
	sky_mat.ground_bottom_color = Color("10191a")
	sky_mat.sky_energy_multiplier = 0.32
	sky_mat.ground_energy_multiplier = 0.18
	sky_mat.sun_angle_max = 14.0
	sky_mat.sun_curve = 0.15
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env.sky = sky
	_env.background_energy_multiplier = 0.55
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("6a7c74")
	_env.ambient_light_energy = 0.62
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.00
	_env.ssr_enabled = true
	_env.ssr_max_steps = 64
	_env.ssr_fade_in = 0.15
	_env.ssr_fade_out = 2.0
	_env.ssr_depth_tolerance = 0.2
	_env.glow_enabled = true
	_env.glow_intensity = 0.25
	_env.glow_strength = 0.8
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.2
	_env.glow_normalized = true
	_env.set("glow_levels/1", 0.0)
	_env.set("glow_levels/2", 0.0)
	_env.set("glow_levels/3", 1.0)
	_env.set("glow_levels/4", 1.0)
	_env.set("glow_levels/5", 1.0)
	_env.set("glow_levels/6", 0.0)
	_env.set("glow_levels/7", 0.0)
	_env.adjustment_enabled = true
	_env.adjustment_brightness = 1.06
	_env.adjustment_contrast = 0.97
	_env.adjustment_saturation = 0.92
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.0020
	_env.volumetric_fog_albedo = Color(0.72, 0.75, 0.70)
	_env.volumetric_fog_anisotropy = 0.32
	_env.volumetric_fog_length = 72.0
	_env.volumetric_fog_detail_spread = 2.0
	_env.volumetric_fog_ambient_inject = 0.55
	we.environment = _env


func _build_lights(pilot: Node3D) -> void:
	var old: Node = pilot.get_node_or_null("DirectionalLight3D")
	if old:
		old.visible = false
		if old is Light3D:
			(old as Light3D).light_energy = 0.0
	var key := DirectionalLight3D.new()
	key.name = "LOOK001_KEY_SunDawn_Filtered"
	key.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-35.0), deg_to_rad(70.0), 0.0)), Vector3(0, 8, 4))
	key.light_color = Color(1.0, 0.78, 0.56)
	key.light_energy = 1.35
	key.shadow_enabled = true
	key.shadow_blur = 1.8
	key.light_volumetric_fog_energy = 1.35
	key.light_specular = 0.35
	if key.get("light_angular_distance") != null:
		key.set("light_angular_distance", 4.0)
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "LOOK001_FILL_Cool"
	fill.light_color = Color("8a9a88")
	fill.light_energy = 0.70
	fill.shadow_enabled = false
	fill.light_specular = 0.0
	fill.light_volumetric_fog_energy = 0.2
	add_child(fill)
	fill.position = Vector3(-8.0, 8.5, 6.0)
	fill.look_at(Vector3(5.0, 1.0, 0.0), Vector3.UP)

	var lateral := OmniLight3D.new()
	lateral.name = "LOOK001_KEY_Soft_Lateral"
	lateral.position = Vector3(18.0, 5.0, 6.0)
	lateral.light_color = Color("e0b07a")
	lateral.light_energy = 0.5
	lateral.light_specular = 0.0
	lateral.omni_range = 18.0
	lateral.light_volumetric_fog_energy = 0.25
	lateral.shadow_enabled = false
	add_child(lateral)

	# light2: local fill + rim + path spot so Maya, floor, solid/oneway @ (6,1,0)
	# and mantle edges read as mid-tones. No shadows (keep the closed-canopy
	# key), low vol-fog energy so banks/haze stay on the lagoon.
	var route_fill := OmniLight3D.new()
	route_fill.name = "LOOK001_FILL_Route"
	route_fill.position = Vector3(4.2, 3.6, 0.0)
	route_fill.light_color = Color(1.0, 0.88, 0.70)
	route_fill.light_energy = 1.15
	route_fill.light_specular = 0.22
	route_fill.omni_range = 13.0
	route_fill.omni_attenuation = 0.9
	route_fill.light_volumetric_fog_energy = 0.08
	route_fill.shadow_enabled = false
	add_child(route_fill)

	var route_rim := OmniLight3D.new()
	route_rim.name = "LOOK001_RIM_Route"
	route_rim.position = Vector3(6.2, 3.2, 2.6)
	route_rim.light_color = Color(0.90, 0.94, 0.88)
	route_rim.light_energy = 1.45
	route_rim.light_specular = 0.35
	route_rim.omni_range = 10.0
	route_rim.omni_attenuation = 1.1
	route_rim.light_volumetric_fog_energy = 0.06
	route_rim.shadow_enabled = false
	add_child(route_rim)

	var maya_key := OmniLight3D.new()
	maya_key.name = "LOOK001_KEY_Maya"
	maya_key.position = Vector3(5.7, 2.55, -1.5)
	maya_key.light_color = Color(1.0, 0.90, 0.74)
	maya_key.light_energy = 2.6
	maya_key.light_specular = 0.40
	maya_key.omni_range = 5.5
	maya_key.omni_attenuation = 1.5
	maya_key.light_volumetric_fog_energy = 0.04
	maya_key.shadow_enabled = false
	add_child(maya_key)

	var maya_rim := OmniLight3D.new()
	maya_rim.name = "LOOK001_RIM_Maya"
	maya_rim.position = Vector3(5.2, 2.45, 1.8)
	maya_rim.light_color = Color(0.95, 0.96, 0.90)
	maya_rim.light_energy = 2.2
	maya_rim.light_specular = 0.55
	maya_rim.omni_range = 5.0
	maya_rim.omni_attenuation = 1.6
	maya_rim.light_volumetric_fog_energy = 0.03
	maya_rim.shadow_enabled = false
	add_child(maya_rim)

	var laguna_face := OmniLight3D.new()
	laguna_face.name = "LOOK001_FILL_LagunaFace"
	laguna_face.position = Vector3(8.5, 2.8, -7.5)
	laguna_face.light_color = Color(1.0, 0.86, 0.68)
	laguna_face.light_energy = 1.15
	laguna_face.light_specular = 0.28
	laguna_face.omni_range = 11.0
	laguna_face.omni_attenuation = 1.0
	laguna_face.light_volumetric_fog_energy = 0.05
	laguna_face.shadow_enabled = false
	add_child(laguna_face)

	var path_spot := SpotLight3D.new()
	path_spot.name = "LOOK001_SPOT_Path"
	path_spot.position = Vector3(5.3, 7.4, 0.2)
	path_spot.light_color = Color(1.0, 0.91, 0.76)
	path_spot.light_energy = 1.85
	path_spot.spot_range = 12.0
	path_spot.spot_angle = 40.0
	path_spot.light_specular = 0.45
	path_spot.shadow_enabled = false
	path_spot.light_volumetric_fog_energy = 0.06
	add_child(path_spot)
	# Spot looks down local -Z; look_at(straight down, UP) is degenerate.
	path_spot.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)

	var anchor: Node3D = pilot.get_node_or_null("WorldRoot/TotemWarpAnchor")
	_totem_light = OmniLight3D.new()
	_totem_light.name = "LOOK001_TOTEM_Local_Gold"
	_totem_light.position = Vector3(0.0, 3.15, 0.0)
	_totem_light.light_color = Color("ffc77a")
	_totem_light.light_energy = TOTEM_LIGHT_ACTIVE
	_totem_light.omni_range = 6.0
	_totem_light.shadow_enabled = false
	if anchor:
		anchor.add_child(_totem_light)
	else:
		_totem_light.position = Vector3(7.5, 3.15, 0.0)
		add_child(_totem_light)


func _build_fog() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = 1001
	noise.frequency = 0.22
	noise.fractal_octaves = 3
	var tex := NoiseTexture3D.new()
	tex.width = 64
	tex.height = 64
	tex.depth = 64
	tex.seamless = true
	tex.noise = noise
	var bank_mat := FogMaterial.new()
	bank_mat.density = 0.62
	bank_mat.albedo = Color(0.74, 0.76, 0.70)
	bank_mat.height_falloff = 0.55
	bank_mat.edge_fade = 0.5
	bank_mat.density_texture = tex
	for i in FOG_BANKS.size():
		var spec: Dictionary = FOG_BANKS[i]
		add_child(_make_fog_volume("LOOK001_FogBank_%02d" % i, spec, bank_mat))
	var trunk_mat := FogMaterial.new()
	trunk_mat.density = 0.18
	trunk_mat.albedo = Color(0.68, 0.72, 0.66)
	trunk_mat.height_falloff = 0.25
	trunk_mat.edge_fade = 0.45
	trunk_mat.density_texture = tex
	for i in FOG_TRUNKS.size():
		var spec: Dictionary = FOG_TRUNKS[i]
		add_child(_make_fog_volume("LOOK001_FogTrunk_%02d" % i, spec, trunk_mat))
	var haze := FogVolume.new()
	haze.name = "LOOK001_AerialHaze"
	haze.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	# Lifted off the playable plane (y ~0–2); still covers canopy + lagoon depth.
	haze.size = Vector3(120.0, 20.0, 80.0)
	haze.position = Vector3(0.0, 14.0, -18.0)
	var haze_mat := FogMaterial.new()
	haze_mat.density = 0.032
	haze_mat.albedo = Color(0.66, 0.70, 0.64)
	haze_mat.height_falloff = 0.04
	haze_mat.edge_fade = 0.3
	haze.material = haze_mat
	add_child(haze)
	# Soft subtract over the playable strip so world vol-fog stays in the
	# background without a hard hole. Negative density is a FogMaterial feature.
	var clear := FogVolume.new()
	clear.name = "LOOK001_PlayableClear"
	clear.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	clear.size = Vector3(22.0, 6.5, 10.0)
	clear.position = Vector3(4.8, 2.4, 0.0)
	var clear_mat := FogMaterial.new()
	clear_mat.density = -0.24
	clear_mat.albedo = Color(0.72, 0.75, 0.70)
	clear_mat.height_falloff = 0.0
	clear_mat.edge_fade = 0.7
	clear.material = clear_mat
	add_child(clear)


func _make_fog_volume(vol_name: String, spec: Dictionary, mat: FogMaterial) -> FogVolume:
	var vol := FogVolume.new()
	vol.name = vol_name
	vol.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	vol.size = spec["size"]
	vol.position = spec["pos"]
	vol.rotation_degrees = Vector3(0.0, spec["yaw"], 0.0)
	vol.material = mat
	return vol


func _build_probe() -> void:
	var probe := ReflectionProbe.new()
	probe.name = "LOOK001_LP_Blackwater"
	probe.position = Vector3(0.0, 2.0, -12.0)
	probe.size = Vector3(60.0, 8.0, 50.0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	probe.enable_shadows = true
	add_child(probe)


func _build_kakaw_pods(pilot: Node3D) -> void:
	_pod_mats.clear()
	var cluster := Node3D.new()
	cluster.name = "LOOK001_KakawPods"
	var anchor: Node3D = pilot.get_node_or_null("WorldRoot/TotemWarpAnchor")
	if anchor:
		anchor.add_child(cluster)
	else:
		cluster.position = Vector3(7.5, 0.0, 0.0)
		add_child(cluster)
	# Wood socket covers the baked GLB crown shards + gold blob (those read as
	# a torch from the close-up). Beam spawn stays at local y=3.03.
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.16, 0.10)
	wood.roughness = 0.88
	wood.emission_enabled = false
	var sock := MeshInstance3D.new()
	sock.name = "Calyx"
	var sock_mesh := CylinderMesh.new()
	sock_mesh.top_radius = 0.15
	sock_mesh.bottom_radius = 0.20
	sock_mesh.height = 0.11
	sock_mesh.radial_segments = 12
	sock.mesh = sock_mesh
	sock.material_override = wood
	sock.position = Vector3(0.0, 2.62, 0.0)
	sock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cluster.add_child(sock)
	var gold_mat := StandardMaterial3D.new()
	gold_mat.resource_name = "WARP_GOLD"
	gold_mat.albedo_color = CACAO_Y
	gold_mat.emission_enabled = true
	gold_mat.emission = CACAO_Y
	gold_mat.emission_energy_multiplier = WARP_GOLD_ACTIVE
	gold_mat.roughness = 0.45
	_warp_mats.append(gold_mat)
	for spec in [
		{"name": "BandLow", "y": 0.55, "r": 0.27, "h": 0.06},
		{"name": "BandHigh", "y": 2.20, "r": 0.23, "h": 0.05},
	]:
		var band := MeshInstance3D.new()
		band.name = spec["name"]
		var ring := CylinderMesh.new()
		ring.top_radius = spec["r"]
		ring.bottom_radius = spec["r"]
		ring.height = spec["h"]
		ring.radial_segments = 16
		band.mesh = ring
		band.material_override = gold_mat
		band.position = Vector3(0.0, spec["y"], 0.0)
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cluster.add_child(band)
	# One nest swallows the baked crown pods (they fanned as orange/yellow
	var nest := MeshInstance3D.new()
	nest.name = "Nest"
	var nest_mesh := SphereMesh.new()
	nest_mesh.radius = 0.30
	nest_mesh.height = 0.56
	nest_mesh.radial_segments = 14
	nest_mesh.rings = 8
	nest.mesh = nest_mesh
	nest.material_override = wood
	nest.position = Vector3(0.0, 2.66, 0.0)
	nest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cluster.add_child(nest)
	# At most two broad dark-green cacao leaves (rounded, not spiky).
	cluster.add_child(_make_cacao_leaf("Leaf_0", Vector3(-0.14, 2.72, -0.28), Vector3(deg_to_rad(-28.0), deg_to_rad(35.0), deg_to_rad(12.0))))
	cluster.add_child(_make_cacao_leaf("Leaf_1", Vector3(0.20, 2.70, -0.26), Vector3(deg_to_rad(-22.0), deg_to_rad(-40.0), deg_to_rad(-8.0))))
	# Hang around the rim, long axis across Cam_TotemPods so we see the
	# ellipsoid side (not an end-on melted disc on the nest).
	var specs := [
		{"pos": Vector3(0.18, 2.88, 0.54), "eul": Vector3(deg_to_rad(70.0), 0.0, 0.0), "col": CACAO_Y},
		{"pos": Vector3(-0.54, 2.86, 0.12), "eul": Vector3(deg_to_rad(70.0), deg_to_rad(90.0), 0.0), "col": CACAO_O},
		{"pos": Vector3(0.22, 2.84, -0.54), "eul": Vector3(deg_to_rad(70.0), deg_to_rad(180.0), 0.0), "col": CACAO_R},
	]
	for i in specs.size():
		var spec: Dictionary = specs[i]
		cluster.add_child(_make_cacao_pod("Pod_%d" % i, spec["pos"], spec["eul"], spec["col"]))


func _make_cacao_leaf(leaf_name: String, pos: Vector3, eul: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.22, 0.11)
	mat.roughness = 0.90
	mat.emission_enabled = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.04
	sphere.radial_segments = 10
	sphere.rings = 6
	var mi := MeshInstance3D.new()
	mi.name = leaf_name
	mi.mesh = sphere
	mi.material_override = mat
	mi.position = pos
	mi.rotation = eul
	mi.scale = Vector3(1.55, 1.0, 2.35)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_cacao_pod(pod_name: String, pos: Vector3, eul: Vector3, col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = pod_name
	root.position = pos
	root.rotation = eul
	var mat := StandardMaterial3D.new()
	mat.resource_name = "KakawPod"
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.15
	mat.roughness = 0.68
	mat.metallic = 0.0
	_pod_mats.append(mat)
	# Whole elongated ellipsoid (capsule) along local Y, not a flattened disc.
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.058
	cap.height = 0.26
	cap.radial_segments = 12
	cap.rings = 4
	body.mesh = cap
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	for sign in [-1.0, 1.0]:
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.032
		cone.height = 0.045
		cone.radial_segments = 10
		tip.mesh = cone
		tip.material_override = mat
		tip.position = Vector3(0.0, sign * 0.145, 0.0)
		if sign < 0.0:
			tip.rotation.x = PI
		tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(tip)
	for k in 5:
		var ang := TAU * float(k) / 5.0
		var rib := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.006
		cyl.bottom_radius = 0.006
		cyl.height = 0.22
		cyl.radial_segments = 6
		rib.mesh = cyl
		rib.material_override = mat
		rib.position = Vector3(cos(ang) * 0.052, 0.0, sin(ang) * 0.052)
		rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(rib)
	return root


func _build_beam(pilot: Node3D) -> void:
	var spawn: Node3D = pilot.get_node_or_null("WorldRoot/TotemWarpAnchor/VFX_WarpBeam_Spawn")
	_beam = Node3D.new()
	_beam.name = "LOOK001_WarpBeam"
	if spawn:
		spawn.add_child(_beam)
	else:
		_beam.position = Vector3(7.5, 3.03, 0.0)
		add_child(_beam)
	_beam.add_child(_make_beam("Gold", Vector3(0.07, 0.30, 6.2), BEAM_GOLD_MAT, Vector3.ZERO))
	# Secondary core is Kakaw orange (paint_v03 Y/O/R), not turquoise.
	_beam.add_child(_make_beam("PodCore", Vector3(0.025, 0.085, 5.0), BEAM_CYAN_MAT, Vector3(0.02, 0.0, 0.02)))
	# Cheat-mirror so the lagoon reads the beam when SSR misses an off-screen shaft.
	var mirror := Node3D.new()
	mirror.name = "Mirror"
	var spawn_y := 3.03
	mirror.position = Vector3(0.0, (WATER_Y - spawn_y) * 2.0, 0.0)
	mirror.scale = Vector3(1.0, -1.0, 1.0)
	_beam.add_child(mirror)
	mirror.add_child(_make_beam("GoldMirror", Vector3(0.07, 0.30, 6.2), BEAM_GOLD_MAT, Vector3.ZERO))


func _make_beam(beam_name: String, geom: Vector3, mat: Material, offset: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = geom.x
	mesh.top_radius = geom.y
	mesh.height = geom.z
	mesh.radial_segments = 16
	mesh.rings = 4
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.name = beam_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = offset + Vector3(0.0, geom.z * 0.5, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
