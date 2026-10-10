extends Node3D
## LOOK-001 atmosphere reconstructed in Godot (Forward+).
## The selva_look001_LOD*.glb files carry geometry + simple PBR/unlit/emissive
## only. Water ripples, SSR + probe, volumetric fog banks, sky, warp beam, and
## filmic grade are built here from LOOK-001_manifest.json.
## HP-001 E1: when totem_warp_cuyabeno_hp_LOD0.glb is present, the HP totem and
## trunk kit replace LOOK totem/post/pods and LOOK001_Trees. Collisions, feel,
## playable lights and Maya follow fill stay LOOK-001.
##
## Capture (optional, not used by the feel harness):
##   godot --path runtime res://scenes/pilot_cuyabeno.tscn -- --look001-capture=both --look001-out=/path

const WATER_MAT := preload("res://materials/m_blackwater.tres")
const BEAM_GOLD_MAT := preload("res://materials/m_warp_beam_gold.tres")
const BEAM_CYAN_MAT := preload("res://materials/m_warp_beam_cyan.tres")
const HP001_SCRIPT := preload("res://scripts/hp001_cuyabeno.gd")
const HP_TOTEM_LOD0 := "res://models/hp001/totem_warp_cuyabeno_hp_LOD0.glb"
const HP_CANOPY_LOD0 := "res://models/hp001/canopy_cuyabeno_hp_LOD0.glb"
const HP_SKY_TEX := "res://textures/hp001_cuyabeno_sky_2k.png"
const HP_SIL_TEX := "res://textures/hp001_selva_silhouette.png"
const HP_LIANA_TEX := "res://textures/hp001_fg_liana.png"

const WATER_Y := -0.12
const TOTEM_XZ := Vector3(7.5, 0.0, 0.0)
const MAYA_STILL := Vector3(5.55, 1.20, 0.0)
const CROWN_TOP_LOCAL_Y := 2.61
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
const ONEWAY_SLAB := Color("3a2a1c")
const ONEWAY_CUE := Color("4a3a2a")
## Wet várzea earth — dark brown, not the old light-grey slabs.
const PLAT_ALBEDO := Color(0.20, 0.14, 0.09)
const PLAT_WET_EDGE := Color(0.10, 0.08, 0.06)
## Soft top-edge lift on greybox platforms only (not Maya). Keep this low —
## combined with the path lights, 0.4+ reads as white puro.
const PLAT_EMIT := Color(0.16, 0.12, 0.08)
const PLAT_EMIT_ENERGY := 0.05
const CACAO_Y := Color("d6ab3d")
const CACAO_O := Color("ce722e")
const CACAO_R := Color("a64b36")
## Gameplay-cam Maya-only fill (visual layer 2). Scene lights keep default layer 1.
## Does not change KEY/FILL/RIM/SPOT energy or fog.
const MAYA_FOLLOW_LAYER := 2
## Warm white near #FFF4E6. Slightly less G/B than 1/0.957/0.902 so the
## lit back sits in hue 28–35° against Maya_Body albedo (pure #FFF4E6 → ~37°).
const MAYA_FOLLOW_LIGHT := Color(1.0, 0.86, 0.70)
const MAYA_BACK_FILL_ENERGY := 0.34
const MAYA_BACK_FILL_RANGE := 3.0
const MAYA_BACK_FILL_ATTEN := 1.5
const MAYA_RIM_ENERGY := 0.10
const MAYA_RIM_RANGE := 2.6

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
var _maya_fill: OmniLight3D = null
var _maya_rim: OmniLight3D = null
var _hero_mats: Array[BaseMaterial3D] = []
var _hp_ok := false
var _hp_totem_mats: Array[BaseMaterial3D] = []


func apply(pilot: Node3D, lod_roots: Array) -> void:
	_lod_roots.clear()
	for r in lod_roots:
		if r is Node:
			_lod_roots.append(r)
	_hp_ok = ResourceLoader.exists(HP_TOTEM_LOD0)
	_bind_look_meshes()
	_grade_platforms()
	_grade_oneway(pilot)
	_grade_csg_playable(pilot)
	_grade_hero(pilot)
	_attach_maya_follow_fill(pilot)
	_thicken_canopy()
	_build_environment(pilot)
	_build_lights(pilot)
	_build_fog()
	_build_probe()
	if ResourceLoader.exists(HP_CANOPY_LOD0):
		_build_side_follow_art(pilot)
		_build_wet_earth_edge(pilot)
	if _hp_ok:
		var hp: Node = HP001_SCRIPT.new()
		hp.name = "HP001"
		add_child(hp)
		_hp_ok = bool(hp.call("wire", pilot))
		var mats = hp.get("totem_mats")
		_hp_totem_mats.clear()
		if mats is Array:
			for m in mats:
				if m is BaseMaterial3D:
					_hp_totem_mats.append(m)
		if ResourceLoader.exists(HP_CANOPY_LOD0):
			_hide_look_dosel(pilot)
	if not _hp_ok:
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
		mat.emission_energy_multiplier = 0.55 if active else 0.32
	for mat in _hp_totem_mats:
		if mat == null:
			continue
		mat.emission_energy_multiplier = 1.0 if active else 0.55
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
			if ResourceLoader.exists(HP_CANOPY_LOD0):
				_hide_look_dosel(root)


func capture_still(shot: String, out_path: String) -> void:
	var tree := get_tree()
	var vp := tree.root.get_viewport()
	vp.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	force_lod0()
	# Laguna / dosel / dock / pods / cmp_bg are art cameras. Hide the 200 m
	# selva-1 strip so brown boxes do not fill the canopy or blow the draw cap.
	# Gameplay and SELVA_CAPTURE keep the 1:1 geometry.
	if shot != "gameplay":
		for path in [
			"WorldRoot/Selva1Geo",
			"WorldRoot/HP001_CorridorBank",
		]:
			var geo: Node = get_parent().get_node_or_null(path)
			if geo:
				geo.visible = false
	var hud := get_parent().get_node_or_null("UI")
	if hud:
		hud.visible = false
	var player: Node3D = get_parent().get_node_or_null("PlayerMaya")
	var play_cam: Camera3D = null
	if player:
		play_cam = player.get_node_or_null("Camera3D")
	var cam: Camera3D
	var pods_cam: Camera3D = null
	if shot == "gameplay":
		# Follow-cam at the 1:1 selva-1 spawn on P00. Do not use MAYA_STILL
		# and do not put Maya on the tscn feel spawn (x=0 is the P00 lip).
		if player:
			player.global_position = Vector3(4.5417, 1.2, 0.0)
			player.rotation = Vector3.ZERO
			player.set_physics_process(true)
		cam = play_cam
	elif shot == "dock":
		# Capture-only: side view of the bank/deck joint. Maya stands on the
		# existing CSGFloor (no new collision) east of the pier so her feet
		# and the visual deck top share the same height in frame.
		if player:
			player.global_position = Vector3(11.15, 1.2, -3.05)
			player.rotation = Vector3.ZERO
			player.rotation.y = deg_to_rad(-48.0)
			player.set_physics_process(true)
			if play_cam:
				play_cam.current = false
		pods_cam = Camera3D.new()
		pods_cam.name = "Cam_DockCloseup"
		pods_cam.far = 80.0
		pods_cam.fov = 50.0
		pods_cam.position = Vector3(13.05, 1.22, -2.15)
		get_parent().add_child(pods_cam)
		pods_cam.look_at(Vector3(10.35, 0.12, -5.35), Vector3.UP)
		cam = pods_cam
	elif shot == "cmp_bg":
		# Same framing as HP001_canopy_2d_vs_3d: eye 22.5 m, +5.4° so the
		# horizon sits ~63 % down. Capture-only; gameplay cam unchanged.
		if player:
			player.visible = false
			if play_cam:
				play_cam.current = false
		pods_cam = Camera3D.new()
		pods_cam.name = "Cam_CmpBg"
		pods_cam.far = 280.0
		pods_cam.fov = 42.0
		pods_cam.position = Vector3(6.0, 14.5, 4.0)
		get_parent().add_child(pods_cam)
		pods_cam.look_at(Vector3(-8.0, 13.2, -48.0), Vector3.UP)
		cam = pods_cam
	else:
		if player:
			player.global_position = MAYA_STILL
			player.rotation = Vector3.ZERO
			player.set_physics_process(false)
			if play_cam:
				play_cam.current = false
		if shot == "pods":
			pods_cam = Camera3D.new()
			pods_cam.name = "Cam_TotemPods"
			pods_cam.far = 80.0
			if _hp_ok:
				# HP cluster is at BeamOrigin (~y 2.28), not the greybox 3.03 tip.
				# 3/4 from +X/+Z, slightly below the cluster (~1.8 m) so the
				# carved crown, three hanging pods + stalks, and beam base read.
				pods_cam.fov = 40.0
				pods_cam.position = Vector3(8.48, 2.02, 1.70)
				get_parent().add_child(pods_cam)
				pods_cam.look_at(Vector3(7.50, 2.38, 0.20), Vector3.UP)
				if player:
					player.visible = false
				_set_pods_closeup_beam(true)
			else:
				pods_cam.fov = 32.0
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
		if player and shot != "pods" and shot != "dock":
			if shot == "dosel":
				# 3/4 toward Cam_Dosel so she reads as a character, not a blade.
				var aim := Vector3(cam.global_position.x, player.global_position.y, cam.global_position.z)
				player.look_at(aim, Vector3.UP)
				player.rotate_y(deg_to_rad(38.0))
			else:
				player.rotation.y = deg_to_rad(35.0)
	if cam == null:
		push_error("LOOK-001 capture: missing camera for " + shot)
		return
	cam.current = true
	set_totem_state(shot != "dosel")
	if _hp_ok:
		var tanchor: Node3D = get_parent().get_node_or_null("WorldRoot/TotemWarpAnchor")
		if tanchor and cam:
			print("HP001 totem dist=", cam.global_position.distance_to(tanchor.global_position), " cam=", cam.name)
	# Follow fill is for the spawn gameplay cam (KEY_Maya does not reach).
	# Laguna / dosel / pods keep vertex albedo + scene KEY so Maya stays cream.
	_set_maya_follow_for_shot(player, shot == "gameplay")
	if shot == "gameplay" or shot == "dock":
		# Let Maya land from y=1.2 so feet sit on the existing collision.
		for i in 50:
			await tree.physics_frame
	# More frames so volumetric fog / SSR settle on software rasterizers too.
	for i in 24:
		await tree.process_frame
	var perf := {
		"shot": shot,
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"video_mem_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_mem_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_mem_bytes": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	}
	print("HP001_E1_PERF ", JSON.stringify(perf))
	var img: Image = vp.get_texture().get_image()
	if img:
		img.save_png(out_path)
		print("LOOK-001 wrote ", out_path, " ", img.get_width(), "x", img.get_height())
		var perf_path := out_path.get_basename() + "_perf.json"
		var pf := FileAccess.open(perf_path, FileAccess.WRITE)
		if pf:
			pf.store_string(JSON.stringify(perf, "\t"))
			pf.close()
			print("HP001_E1_PERF wrote ", perf_path)
	else:
		push_error("LOOK-001 capture: viewport image is null (headless dummy?)")
	if shot == "pods" and _hp_ok:
		_set_pods_closeup_beam(false)
		if player:
			player.visible = true
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
			if _hp_ok:
				n.visible = false
			else:
				var wood_post := StandardMaterial3D.new()
				wood_post.albedo_color = Color(0.28, 0.20, 0.13)
				wood_post.vertex_color_use_as_albedo = false
				wood_post.emission_enabled = false
				wood_post.roughness = 0.85
				mi.material_override = wood_post
		if n.name.begins_with("LOOK001_Trees") and _hp_ok:
			n.visible = false
		if ResourceLoader.exists(HP_CANOPY_LOD0) and (n.name.begins_with("LOOK001_Canopy") or String(n.name).find("Canopy") >= 0):
			n.visible = false
	for c in n.get_children():
		_walk_look(c)


func _grade_hero(pilot: Node3D) -> void:
	var player: Node = pilot.get_node_or_null("PlayerMaya")
	if player == null:
		return
	_hero_mats.clear()
	_grade_hero_node(player)


func _grade_hero_node(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		# Imported hero_grey is GI-static (light_baking=1); dynamic Omnis would miss her.
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.layers = mi.layers | MAYA_FOLLOW_LAYER
		if mi.mesh:
			mi.mesh = mi.mesh.duplicate()
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if not (mat is BaseMaterial3D):
					continue
				var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				var slot := String(d.resource_name)
				d.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				d.roughness = 0.48
				d.metallic = 0.0
				d.vertex_color_use_as_albedo = false
				d.emission_enabled = false
				d.emission_energy_multiplier = 0.0
				if slot.begins_with("Maya_Body"):
					d.albedo_color = MAYA_BODY
				elif slot.begins_with("Maya_Hair"):
					d.albedo_color = MAYA_HAIR
				elif slot.begins_with("Maya_Pack"):
					d.albedo_color = MAYA_PACK
				else:
					d.albedo_color = MAYA_BODY
				mi.mesh.surface_set_material(s, d)
				_hero_mats.append(d)
	for c in n.get_children():
		_grade_hero_node(c)


func _attach_maya_follow_fill(pilot: Node3D) -> void:
	var player: Node3D = pilot.get_node_or_null("PlayerMaya")
	if player == null:
		return
	_tag_maya_follow_layer(player)
	# Parent to PlayerMaya (hero visual is a child). Local +Z is camera-back.
	# cull_mask = layer 2 only: lights Maya, not floor / canopy / totem.
	_maya_fill = OmniLight3D.new()
	_maya_fill.name = "LOOK001_FILL_MayaBack"
	_maya_fill.light_color = MAYA_FOLLOW_LIGHT
	_maya_fill.light_energy = MAYA_BACK_FILL_ENERGY
	_maya_fill.light_specular = 0.0
	_maya_fill.omni_range = MAYA_BACK_FILL_RANGE
	_maya_fill.omni_attenuation = MAYA_BACK_FILL_ATTEN
	_maya_fill.shadow_enabled = false
	_maya_fill.light_volumetric_fog_energy = 0.0
	_maya_fill.light_cull_mask = MAYA_FOLLOW_LAYER
	# Behind/above her back relative to PlayerMaya/Camera3D (+Z follow-cam).
	_maya_fill.position = Vector3(0.0, 1.22, 0.88)
	player.add_child(_maya_fill)
	_maya_rim = OmniLight3D.new()
	_maya_rim.name = "LOOK001_RIM_MayaFollow"
	_maya_rim.light_color = MAYA_FOLLOW_LIGHT
	_maya_rim.light_energy = MAYA_RIM_ENERGY
	_maya_rim.light_specular = 0.0
	_maya_rim.omni_range = MAYA_RIM_RANGE
	_maya_rim.omni_attenuation = 1.5
	_maya_rim.shadow_enabled = false
	_maya_rim.light_volumetric_fog_energy = 0.0
	_maya_rim.light_cull_mask = MAYA_FOLLOW_LAYER
	_maya_rim.position = Vector3(0.50, 1.48, -0.60)
	player.add_child(_maya_rim)


func _set_maya_follow_for_shot(player: Node, gameplay: bool) -> void:
	if _maya_fill:
		_maya_fill.visible = gameplay
		_maya_fill.light_energy = MAYA_BACK_FILL_ENERGY if gameplay else 0.0
	if _maya_rim:
		_maya_rim.visible = gameplay
		_maya_rim.light_energy = MAYA_RIM_ENERGY if gameplay else 0.0
	for mat in _hero_mats:
		if mat:
			mat.vertex_color_use_as_albedo = not gameplay
	if player == null:
		return
	_set_hero_gi_for_shot(player, gameplay)
	var vertex_on := false
	if not _hero_mats.is_empty():
		vertex_on = _hero_mats[0].vertex_color_use_as_albedo
	print("LOOK-001 follow gameplay=", gameplay, " hero_mats=", _hero_mats.size(), " vertex=", vertex_on)


func _set_hero_gi_for_shot(n: Node, gameplay: bool) -> void:
	if n is Camera3D or n is Light3D:
		pass
	elif n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED if gameplay else GeometryInstance3D.GI_MODE_STATIC
	for c in n.get_children():
		_set_hero_gi_for_shot(c, gameplay)


func _tag_maya_follow_layer(n: Node) -> void:
	if n is Camera3D or n is Light3D:
		pass
	elif n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		gi.layers = gi.layers | MAYA_FOLLOW_LAYER
	elif n is VisualInstance3D:
		var vi := n as VisualInstance3D
		vi.layers = vi.layers | MAYA_FOLLOW_LAYER
	for c in n.get_children():
		_tag_maya_follow_layer(c)


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
	d.roughness = 0.78
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


func _hide_look_dosel(from: Node) -> void:
	# LOOK canopy / understory / backdrop trees stay in the GLB; HP v2 is the dosel.
	if from == null:
		return
	if from is MeshInstance3D:
		var nm := String(from.name)
		if nm.begins_with("LOOK001_Canopy") or nm.begins_with("LOOK001_Understory") \
				or nm.begins_with("LOOK001_Backdrop") or nm.find("LOOK001_Canopy") >= 0:
			from.visible = false
	for c in from.get_children():
		_hide_look_dosel(c)


func _thicken_canopy() -> void:
	# HP canopy v2 replaces LOOK clumps and the extra gap cards.
	if ResourceLoader.exists(HP_CANOPY_LOD0):
		return
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
	var sky := Sky.new()
	if ResourceLoader.exists(HP_SKY_TEX):
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(HP_SKY_TEX)
		sky.sky_material = pano
		_env.background_energy_multiplier = 0.78
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = Color("a3ad92")
		_env.ambient_light_energy = 0.36
		_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_env.tonemap_exposure = 1.02
	else:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color("3a4844")
		sky_mat.sky_horizon_color = Color("6a655c")
		sky_mat.ground_horizon_color = Color("4a5048")
		sky_mat.ground_bottom_color = Color("10191a")
		sky_mat.sky_energy_multiplier = 0.32
		sky_mat.ground_energy_multiplier = 0.18
		sky_mat.sun_angle_max = 14.0
		sky_mat.sun_curve = 0.15
		sky.sky_material = sky_mat
		_env.background_energy_multiplier = 0.55
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = Color("6a7c74")
		_env.ambient_light_energy = 0.62
		_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_env.tonemap_exposure = 1.00
	_env.sky = sky
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
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
	if ResourceLoader.exists(HP_CANOPY_LOD0):
		_env.adjustment_brightness = 1.02
		_env.adjustment_contrast = 1.04
		_env.adjustment_saturation = 1.02
		# Low vol-fog. Olive-grey albedo so mid-distance crowns stay dark
		# olive, not an ochre cutout. Depth lives in the far haze volumes.
		_env.volumetric_fog_enabled = true
		_env.volumetric_fog_density = 0.00105
		_env.volumetric_fog_albedo = Color(0.52, 0.56, 0.46)
		_env.volumetric_fog_emission = Color(0.62, 0.64, 0.52)
		_env.volumetric_fog_emission_energy = 0.0
		_env.volumetric_fog_anisotropy = 0.28
		_env.volumetric_fog_length = 52.0
		_env.volumetric_fog_detail_spread = 1.5
		_env.volumetric_fog_ambient_inject = 0.38
	else:
		_env.adjustment_brightness = 1.06
		_env.adjustment_contrast = 0.97
		_env.adjustment_saturation = 0.92
		_env.volumetric_fog_enabled = true
		_env.volumetric_fog_density = 0.0020
		_env.volumetric_fog_albedo = Color(0.72, 0.75, 0.70)
		_env.volumetric_fog_anisotropy = 0.32
		_env.volumetric_fog_length = 48.0
		_env.volumetric_fog_detail_spread = 1.5
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
	if ResourceLoader.exists(HP_CANOPY_LOD0):
		# README table: elevation 18°, azimuth 160° from +X, colour (1, 0.78, 0.45).
		var el := deg_to_rad(18.0)
		var az := deg_to_rad(160.0)
		var to_sun := Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az))
		key.position = to_sun * 42.0
		key.light_color = Color(1.0, 0.78, 0.45)
		key.light_energy = 1.35
		key.light_volumetric_fog_energy = 0.85
		key.light_specular = 0.28
		if key.get("light_angular_distance") != null:
			key.set("light_angular_distance", 2.0)
	else:
		key.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-35.0), deg_to_rad(70.0), 0.0)), Vector3(0, 8, 4))
		key.light_color = Color(1.0, 0.78, 0.56)
		key.light_energy = 1.35
		key.light_volumetric_fog_energy = 1.35
		key.light_specular = 0.35
		if key.get("light_angular_distance") != null:
			key.set("light_angular_distance", 4.0)
	key.shadow_enabled = true
	key.shadow_blur = 1.8
	add_child(key)
	if ResourceLoader.exists(HP_CANOPY_LOD0):
		key.look_at(Vector3.ZERO, Vector3.UP)

	var fill := DirectionalLight3D.new()
	fill.name = "LOOK001_FILL_Cool"
	if ResourceLoader.exists(HP_CANOPY_LOD0):
		fill.light_color = Color("a3ad92")
		fill.light_energy = 0.40
	else:
		fill.light_color = Color("8a9a88")
		fill.light_energy = 0.70
	fill.shadow_enabled = false
	fill.light_specular = 0.0
	fill.light_volumetric_fog_energy = 0.2
	add_child(fill)
	fill.position = Vector3(-8.0, 8.5, 6.0)
	fill.look_at(Vector3(5.0, 1.0, 0.0), Vector3.UP)

	if ResourceLoader.exists(HP_CANOPY_LOD0):
		# Cheap rim on the crowns (not Maya — default cull, no follow layer).
		var canopy_rim := DirectionalLight3D.new()
		canopy_rim.name = "HP001_RIM_Canopy"
		var el_r := deg_to_rad(14.0)
		var az_r := deg_to_rad(340.0)
		var to_rim := Vector3(cos(el_r) * cos(az_r), sin(el_r), cos(el_r) * sin(az_r))
		canopy_rim.position = to_rim * 36.0
		canopy_rim.light_color = Color(1.0, 0.92, 0.62)
		canopy_rim.light_energy = 0.38
		canopy_rim.light_specular = 0.15
		canopy_rim.shadow_enabled = false
		canopy_rim.light_volumetric_fog_energy = 0.25
		add_child(canopy_rim)
		canopy_rim.look_at(Vector3(0.0, 10.0, -6.0), Vector3.UP)

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
	if ResourceLoader.exists(HP_CANOPY_LOD0):
		bank_mat.albedo = Color(0.58, 0.62, 0.50)
		bank_mat.density = 0.36
	else:
		bank_mat.albedo = Color(0.74, 0.76, 0.70)
	bank_mat.height_falloff = 0.55
	bank_mat.edge_fade = 0.5
	bank_mat.density_texture = tex
	for i in FOG_BANKS.size():
		var spec: Dictionary = FOG_BANKS[i]
		add_child(_make_fog_volume("LOOK001_FogBank_%02d" % i, spec, bank_mat))
	var trunk_mat := FogMaterial.new()
	trunk_mat.density = 0.18
	if ResourceLoader.exists(HP_CANOPY_LOD0):
		trunk_mat.albedo = Color(0.50, 0.54, 0.44)
		trunk_mat.density = 0.10
	else:
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
	if ResourceLoader.exists(HP_CANOPY_LOD0):
		haze.size = Vector3(180.0, 14.0, 140.0)
		haze.position = Vector3(0.0, 7.0, -48.0)
		haze_mat.density = 0.014
		haze_mat.albedo = Color(0.48, 0.52, 0.42)
	else:
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
	if ResourceLoader.exists(HP_CANOPY_LOD0):
		# Second haze layer on the far ridges (README k 0.0022 /m, warmer far).
		var ridge := FogVolume.new()
		ridge.name = "HP001_RidgeHaze"
		ridge.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		ridge.size = Vector3(220.0, 16.0, 80.0)
		ridge.position = Vector3(-8.0, 8.0, -92.0)
		var ridge_mat := FogMaterial.new()
		ridge_mat.density = 0.016
		ridge_mat.albedo = Color(0.56, 0.58, 0.50)
		ridge_mat.height_falloff = 0.03
		ridge_mat.edge_fade = 0.35
		ridge.material = ridge_mat
		add_child(ridge)


func _scissor_card(tex: Texture2D, tint: Color, cutoff: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = cutoff
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	return mat


func _add_card(parent: Node, card_name: String, pos: Vector3, size: Vector2, eul: Vector3, mat: Material) -> MeshInstance3D:
	# QuadMesh lives in XY and faces +Z. Camera looks down local −Z, so a child
	# at z<0 with identity rotation faces the lens. PlaneMesh is XZ / +Y and
	# was invisible in the 40×22.5 side camera.
	var quad := QuadMesh.new()
	quad.size = size
	var mi := MeshInstance3D.new()
	mi.name = card_name
	mi.mesh = quad
	mi.material_override = mat
	mi.position = pos
	mi.rotation = eul
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mi)
	return mi


func _cloud_card_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, specular_disabled;
uniform sampler2D sky : source_color;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec2 uv = vec2(fract(UV.x * 1.35 + 0.08), mix(0.46, 0.03, UV.y));
	ALBEDO = texture(sky, uv).rgb * tint.rgb;
}
"""
	mat.shader = sh
	if ResourceLoader.exists(HP_SKY_TEX):
		mat.set_shader_parameter("sky", load(HP_SKY_TEX))
	elif ResourceLoader.exists("res://textures/hp001_jungle_sky_2d.jpg"):
		mat.set_shader_parameter("sky", load("res://textures/hp001_jungle_sky_2d.jpg"))
	mat.set_shader_parameter("tint", Color(1.02, 0.98, 0.90))
	return mat


func _build_side_follow_art(pilot: Node3D) -> void:
	# Locked to the follow cam so every gameplay still (entrance / hazard /
	# cacao) shows cumulus + two low jungle strips + left-edge lianas.
	# Cards sit in camera space: play plane is local z ≈ −24.1; behind it is
	# z < −24. No collision. Flat várzea — no hills, no waterfalls.
	var cam: Node = pilot.get_node_or_null("PlayerMaya/Camera3D")
	if cam == null:
		return
	var hold := Node3D.new()
	hold.name = "HP001_SideFollow"
	cam.add_child(hold)
	_add_card(hold, "HP001_CloudBand", Vector3(0.0, 7.2, -44.0), Vector2(84.0, 28.0), Vector3.ZERO, _cloud_card_mat())
	if ResourceLoader.exists(HP_SIL_TEX):
		var tex: Texture2D = load(HP_SIL_TEX)
		# Nearer strip: darker, just behind the play plane.
		var near_mat := _scissor_card(tex, Color(0.14, 0.18, 0.10), 0.32)
		near_mat.albedo_color = Color(0.14, 0.18, 0.10)
		_add_card(hold, "HP001_SelvaSil_near", Vector3(0.0, -1.15, -33.0), Vector2(74.0, 8.4), Vector3.ZERO, near_mat)
		# Farther strip: lighter / hazy.
		var far_mat := _scissor_card(tex, Color(0.38, 0.40, 0.32), 0.32)
		_add_card(hold, "HP001_SelvaSil_far", Vector3(2.5, -0.35, -52.0), Vector2(92.0, 10.0), Vector3.ZERO, far_mat)
	if ResourceLoader.exists(HP_LIANA_TEX):
		var liana: Texture2D = load(HP_LIANA_TEX)
		var lmat := _scissor_card(liana, Color(0.78, 0.86, 0.62), 0.22)
		# Left edge of the 40×22.5 frame, like the 2D vine. Outside the
		# 0.7 m hitbox and the walkable strip (Maya stays center-frame).
		_add_card(hold, "HP001_FG_Liana_L", Vector3(-2.28, 0.72, -3.15), Vector2(1.55, 2.55), Vector3(deg_to_rad(4.0), deg_to_rad(8.0), deg_to_rad(-3.0)), lmat)
		_add_card(hold, "HP001_FG_Liana_L2", Vector3(-2.55, 1.05, -3.55), Vector2(1.15, 1.85), Vector3(deg_to_rad(6.0), deg_to_rad(12.0), deg_to_rad(4.0)), lmat)
	# Laguna still keeps a world-space curtain over the water (art camera).
	if ResourceLoader.exists(HP_LIANA_TEX):
		var lmat2 := _scissor_card(load(HP_LIANA_TEX), Color(0.78, 0.86, 0.62), 0.22)
		_add_card(pilot, "HP001_FG_Liana_Laguna", Vector3(15.15, 4.35, -16.55), Vector2(3.4, 4.6), Vector3(deg_to_rad(6.0), deg_to_rad(-22.0), 0.0), lmat2)


func _build_wet_earth_edge(pilot: Node3D) -> void:
	# Visual only: darker wet lip where the playable earth meets black water.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLAT_WET_EDGE
	mat.roughness = 0.82
	mat.metallic = 0.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 0.85)
	var mi := MeshInstance3D.new()
	mi.name = "HP001_WetEarthEdge"
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.012, -3.85)
	mi.rotation.x = deg_to_rad(-90.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var world: Node = pilot.get_node_or_null("WorldRoot")
	if world:
		world.add_child(mi)
	else:
		pilot.add_child(mi)


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
	# Small wood calyx on the crown plate. Beam spawn stays at local y=3.03.
	# Do not swallow Cam_TotemPods look-at (7.5, 2.86, 0) with a giant nest.
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.16, 0.10)
	wood.roughness = 0.88
	wood.emission_enabled = false
	var sock := MeshInstance3D.new()
	sock.name = "Calyx"
	var sock_mesh := CylinderMesh.new()
	sock_mesh.top_radius = 0.16
	sock_mesh.bottom_radius = 0.21
	sock_mesh.height = 0.12
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
	# Modest wood cap hides leftover baked crown lumps (already wood-overridden
	# so they cannot read as fire). Top stays below the close-up look-at.
	var nest := MeshInstance3D.new()
	nest.name = "Nest"
	var nest_mesh := SphereMesh.new()
	nest_mesh.radius = 0.14
	nest_mesh.height = 0.22
	nest_mesh.radial_segments = 12
	nest_mesh.rings = 6
	nest.mesh = nest_mesh
	nest.material_override = wood
	nest.position = Vector3(0.0, 2.66, 0.0)
	nest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cluster.add_child(nest)
	# At most two broad dark-green cacao leaves (wide, rounded tip, not spiky).
	# Disc faces Cam_TotemPods so they read as foliage, not edge-on needles.
	var toward_cam := Vector3(0.73, 0.12, 0.68)
	cluster.add_child(_make_cacao_leaf("Leaf_0", Vector3(-0.16, 2.74, -0.18), toward_cam.rotated(Vector3.UP, deg_to_rad(-28.0)) + Vector3(0.0, 0.35, 0.0)))
	cluster.add_child(_make_cacao_leaf("Leaf_1", Vector3(0.18, 2.73, -0.16), toward_cam.rotated(Vector3.UP, deg_to_rad(24.0)) + Vector3(0.0, 0.40, 0.0)))
	# Tight hanging bunch (not a left/right fire fan). Each pod is a whole
	# ribbed ellipsoid with pointed ends, slightly separated.
	var specs := [
		{"pos": Vector3(-0.14, 2.82, 0.14), "axis": Vector3(-0.18, -0.96, 0.16), "col": CACAO_Y},
		{"pos": Vector3(0.24, 2.82, 0.04), "axis": Vector3(0.22, -0.96, 0.10), "col": CACAO_O},
		{"pos": Vector3(0.08, 2.72, 0.24), "axis": Vector3(0.06, -0.98, 0.18), "col": CACAO_R},
	]
	for i in specs.size():
		var spec: Dictionary = specs[i]
		cluster.add_child(_make_cacao_pod("Pod_%d" % i, spec["pos"], spec["axis"], spec["col"]))


func _align_axis_y(node: Node3D, y_axis: Vector3) -> void:
	var y := y_axis.normalized()
	var x := Vector3.UP.cross(y)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT.cross(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	node.basis = Basis(x, y, z)


func _make_cacao_leaf(leaf_name: String, pos: Vector3, face_dir: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.20, 0.09)
	mat.roughness = 0.92
	mat.emission_enabled = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.034
	sphere.radial_segments = 10
	sphere.rings = 6
	var mi := MeshInstance3D.new()
	mi.name = leaf_name
	mi.mesh = sphere
	mi.material_override = mat
	mi.position = pos
	_align_axis_y(mi, face_dir)
	mi.scale = Vector3(1.85, 1.0, 2.55)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_cacao_pod(pod_name: String, pos: Vector3, long_axis: Vector3, col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = pod_name
	root.position = pos
	_align_axis_y(root, long_axis)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "KakawPod"
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.55
	mat.roughness = 0.78
	mat.metallic = 0.0
	_pod_mats.append(mat)
	# Closed ellipsoid: rounded stalk pole at local −Y, shaved blunt cap at +Y.
	# Ribs are CSG cylinder subtractions (valleys), not stuck-on slat meshes.
	var csg := CSGCombiner3D.new()
	csg.name = "Body"
	csg.material_override = mat
	csg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body := CSGSphere3D.new()
	body.radius = 0.092
	body.radial_segments = 16
	body.rings = 10
	body.smooth_faces = true
	body.scale = Vector3(1.0, 1.55, 1.0)
	body.material = mat
	csg.add_child(body)
	var blunt := CSGBox3D.new()
	blunt.operation = CSGShape3D.OPERATION_SUBTRACTION
	blunt.size = Vector3(0.22, 0.030, 0.22)
	blunt.position = Vector3(0.0, 0.148, 0.0)
	csg.add_child(blunt)
	for i in 5:
		var ang: float = TAU * float(i) / 5.0
		var g := CSGCylinder3D.new()
		g.operation = CSGShape3D.OPERATION_SUBTRACTION
		g.radius = 0.015
		g.height = 0.20
		g.sides = 8
		g.smooth_faces = true
		g.position = Vector3(cos(ang) * 0.090, 0.0, sin(ang) * 0.090)
		csg.add_child(g)
	root.add_child(csg)
	# Rounded stalk nub at local −Y (world top when hanging).
	var nub := MeshInstance3D.new()
	nub.name = "Stalk"
	var nub_mesh := SphereMesh.new()
	nub_mesh.radius = 0.020
	nub_mesh.height = 0.032
	nub_mesh.radial_segments = 8
	nub_mesh.rings = 4
	nub.mesh = nub_mesh
	nub.material_override = mat
	nub.position = Vector3(0.0, -0.148, 0.0)
	nub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(nub)
	return root


func _set_pods_closeup_beam(dim: bool) -> void:
	# Capture-only: keep the beam origin readable without additive wash on the pods.
	if BEAM_GOLD_MAT:
		BEAM_GOLD_MAT.set_shader_parameter("strength", 1.35 if dim else 3.2)
	if BEAM_CYAN_MAT:
		BEAM_CYAN_MAT.set_shader_parameter("strength", 1.10 if dim else 2.6)
	if _env:
		_env.glow_intensity = 0.10 if dim else 0.25


func _build_beam(pilot: Node3D) -> void:
	var spawn: Node3D = pilot.get_node_or_null("WorldRoot/TotemWarpAnchor/BeamOrigin")
	if spawn == null:
		spawn = pilot.get_node_or_null("WorldRoot/TotemWarpAnchor/VFX_WarpBeam_Spawn")
	_beam = Node3D.new()
	_beam.name = "LOOK001_WarpBeam"
	if spawn:
		spawn.add_child(_beam)
	else:
		_beam.position = Vector3(7.5, 3.03, 0.0)
		add_child(_beam)
	# BeamOrigin is the pod-cluster anchor (~y 2.278). Sit the open cylinder
	# flush on the chopped crown (~y 2.61) so the shaft is centred between
	# the pods and does not pierce them. The shader fades the bottom 0.35 m
	# (alpha 0 → full) so the open end does not read as a hovering disc.
	var lift := 0.0
	if spawn and spawn.name == "BeamOrigin":
		lift = CROWN_TOP_LOCAL_Y - spawn.position.y
		_beam.position = Vector3(0.0, lift, 0.0)
	if BEAM_GOLD_MAT:
		BEAM_GOLD_MAT.set_shader_parameter("base_fade_m", 0.35)
	if BEAM_CYAN_MAT:
		BEAM_CYAN_MAT.set_shader_parameter("base_fade_m", 0.35)
	_beam.add_child(_make_beam("Gold", Vector3(0.07, 0.30, 6.2), BEAM_GOLD_MAT, Vector3.ZERO))
	# Secondary core is Kakaw orange (paint_v03 Y/O/R), not turquoise.
	_beam.add_child(_make_beam("PodCore", Vector3(0.025, 0.085, 5.0), BEAM_CYAN_MAT, Vector3(0.02, 0.0, 0.02)))
	# Cheat-mirror so the lagoon reads the beam when SSR misses an off-screen shaft.
	var mirror := Node3D.new()
	mirror.name = "Mirror"
	var spawn_y := 3.03
	if spawn:
		spawn_y = spawn.global_position.y + lift
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
