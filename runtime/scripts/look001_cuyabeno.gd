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
const MAYA_STILL := Vector3(5.55, 1.02, 0.0)
const WARP_GOLD_ACTIVE := 3.0
const WARP_CYAN_ACTIVE := 2.4
const WARP_GOLD_DIM := 0.35
const WARP_CYAN_DIM := 0.25
const TOTEM_LIGHT_ACTIVE := 2.0
const TOTEM_LIGHT_DIM := 0.15

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

var _env: Environment
var _totem_light: OmniLight3D
var _beam: Node3D
var _warp_mats: Array[BaseMaterial3D] = []
var _lod_roots: Array[Node] = []


func apply(pilot: Node3D, lod_roots: Array) -> void:
	_lod_roots.clear()
	for r in lod_roots:
		if r is Node:
			_lod_roots.append(r)
	_bind_look_meshes()
	_build_environment(pilot)
	_build_lights(pilot)
	_build_fog()
	_build_probe()
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
		player.rotation.y = deg_to_rad(35.0)
		player.set_physics_process(false)
		var play_cam: Camera3D = player.get_node_or_null("Camera3D")
		if play_cam:
			play_cam.current = false
	var cam_name := "Cam_Laguna" if shot == "laguna" else "Cam_Dosel"
	var cam: Camera3D = get_parent().get_node_or_null(cam_name)
	if cam == null:
		push_error("LOOK-001 capture: missing " + cam_name)
		return
	cam.current = true
	set_totem_state(shot == "laguna")
	# A few frames so SSR / probe / volumetric fog settle.
	for i in 12:
		await tree.process_frame
	var img: Image = vp.get_texture().get_image()
	if img == null:
		push_error("LOOK-001 capture: viewport image is null (headless dummy?)")
		return
	img.save_png(out_path)
	print("LOOK-001 wrote ", out_path, " ", img.get_width(), "x", img.get_height())


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
		if n.name.begins_with("LOOK001_Totem_Warp") and mi.mesh:
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if mat is BaseMaterial3D:
					var dup := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					mi.set_surface_override_material(s, dup)
					_warp_mats.append(dup)
	for c in n.get_children():
		_walk_look(c)


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
	sky_mat.sky_top_color = Color("5c6b7c")
	sky_mat.sky_horizon_color = Color("8a7a66")
	sky_mat.ground_horizon_color = Color("6e6a63")
	sky_mat.ground_bottom_color = Color("10191a")
	sky_mat.sky_energy_multiplier = 0.5
	sky_mat.ground_energy_multiplier = 0.25
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("6f8c8a")
	_env.ambient_light_energy = 0.45
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 0.85
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
	_env.adjustment_contrast = 1.03
	_env.adjustment_saturation = 0.95
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.0025
	_env.volumetric_fog_albedo = Color(0.80, 0.84, 0.88)
	_env.volumetric_fog_anisotropy = 0.3
	_env.volumetric_fog_length = 64.0
	_env.volumetric_fog_detail_spread = 2.0
	_env.volumetric_fog_ambient_inject = 0.2
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
	key.light_energy = 1.6
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.light_volumetric_fog_energy = 1.0
	key.light_specular = 0.6
	if key.get("light_angular_distance") != null:
		key.set("light_angular_distance", 4.0)
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "LOOK001_FILL_Cool"
	fill.light_color = Color("9ee6ec")
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	fill.light_specular = 0.0
	fill.light_volumetric_fog_energy = 0.15
	add_child(fill)
	fill.position = Vector3(-8.0, 8.5, 6.0)
	fill.look_at(Vector3(4.0, 0.0, -6.0), Vector3.UP)

	var lateral := OmniLight3D.new()
	lateral.name = "LOOK001_KEY_Soft_Lateral"
	lateral.position = Vector3(18.0, 5.0, 6.0)
	lateral.light_color = Color("ffcc94")
	lateral.light_energy = 1.2
	lateral.light_specular = 0.0
	lateral.omni_range = 28.0
	lateral.light_volumetric_fog_energy = 0.4
	lateral.shadow_enabled = false
	add_child(lateral)

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
	noise.frequency = 0.25
	noise.fractal_octaves = 3
	var tex := NoiseTexture3D.new()
	tex.width = 64
	tex.height = 64
	tex.depth = 64
	tex.seamless = true
	tex.noise = noise
	var mat := FogMaterial.new()
	mat.density = 0.5
	mat.albedo = Color(0.78, 0.82, 0.86)
	mat.height_falloff = 0.8
	mat.edge_fade = 0.6
	mat.density_texture = tex
	for i in FOG_BANKS.size():
		var spec: Dictionary = FOG_BANKS[i]
		var vol := FogVolume.new()
		vol.name = "LOOK001_FogBank_%02d" % i
		vol.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		vol.size = spec["size"]
		vol.position = spec["pos"]
		vol.rotation_degrees = Vector3(0.0, spec["yaw"], 0.0)
		vol.material = mat
		add_child(vol)


func _build_probe() -> void:
	var probe := ReflectionProbe.new()
	probe.name = "LOOK001_LP_Blackwater"
	probe.position = Vector3(0.0, 2.0, -12.0)
	probe.size = Vector3(60.0, 8.0, 50.0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	probe.enable_shadows = true
	add_child(probe)


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
	_beam.add_child(_make_beam("CyanCore", Vector3(0.025, 0.085, 5.0), BEAM_CYAN_MAT, Vector3(0.02, 0.0, 0.02)))
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
