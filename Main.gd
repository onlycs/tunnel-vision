extends Node3D

const NUM_CIVILIANS   = 12
const INITIAL_COPS    = 5
const MAX_COPS        = 15
const CIVILIAN_SPEED  = 3.2
const INFECTED_SPEED  = 4.5   # newly separated speed for the player
const COP_BASE_SPEED  = 4.8   # slightly faster than infected speed
const COP_SIGHT_RANGE = 7.0   # cops only chase within this distance
const JUMP_COOLDOWN   = 1.5   
const MAX_JUMP_DIST   = 10.0  # Maximum distance you can jump
const HOST_RADIUS     = 0.30
const COP_RADIUS      = 0.32
const CATCH_DIST      = 0.65
const SPAWN_DIST      = 22.0  # spawn new entities this far from infected host
const DESPAWN_DIST    = 30.0  # despawn entities beyond this distance
const CAM_HEIGHT      = 7.0
const CAM_BACK        = 7.0

# ── materials ─────────────────────────────────────────────────────────────────
var mat_civilian: StandardMaterial3D
var mat_infected: StandardMaterial3D
var mat_cop:      StandardMaterial3D
var mat_hat:      StandardMaterial3D
var mat_badge:    StandardMaterial3D
var mat_target:   StandardMaterial3D   # highlight for jump target
var mat_wisp:     StandardMaterial3D
var ground_mat:   ShaderMaterial       # infinite grid shader

# ── game state ────────────────────────────────────────────────────────────────
var entities:      Array  = []
var infected_idx:  int    = 0
var highlight_idx: int    = -1
var jump_cooldown: float  = 0.0
var score:         float  = 0.0
var game_over:     bool   = false
var started:       bool   = false
var pulse_t:       float  = 0.0
var jump_anim_active: bool   = false
var jump_anim_t:      float  = 0.0
var jump_anim_from:   Vector2 = Vector2.ZERO
var jump_anim_to:     Vector2 = Vector2.ZERO
var cop_spawn_timer: float = 8.0
var cop_count:       int   = INITIAL_COPS
var best_score:      float = 0.0

# ── scene nodes ───────────────────────────────────────────────────────────────
var camera:        Camera3D
var cam_look_pos:  Vector3 = Vector3.ZERO
var fill_light:    OmniLight3D
var ground_node:   MeshInstance3D
var jump_wisp:     MeshInstance3D
var target_marker: MeshInstance3D

# ── hud ───────────────────────────────────────────────────────────────────────
var score_label:     Label
var best_label:      Label
var cop_label:       Label
var cooldown_label:  Label
var bar_bg:          ColorRect
var bar_fill:        ColorRect
var hint_label:      Label
var overlay_label:   Label
var sub_label:       Label
var dim_rect:        ColorRect

# ═══════════════════════════════════════════════════════════════════════════════
func _ready():
	get_window().size = Vector2i(1280, 720)
	_make_materials()
	_setup_scene()
	_setup_hud()
	_spawn_entities()

func _make_materials():
	mat_civilian = StandardMaterial3D.new()
	mat_civilian.albedo_color = Color(0.75, 0.70, 0.60)

	mat_infected = StandardMaterial3D.new()
	mat_infected.albedo_color = Color(0.15, 0.70, 0.15)
	mat_infected.emission_enabled = true
	mat_infected.emission = Color(0.2, 1.0, 0.2)
	mat_infected.emission_energy_multiplier = 2.0

	mat_cop = StandardMaterial3D.new()
	mat_cop.albedo_color = Color(0.20, 0.38, 0.92)
	mat_cop.metallic = 0.3
	mat_cop.roughness = 0.5

	mat_hat = StandardMaterial3D.new()
	mat_hat.albedo_color = Color(0.10, 0.18, 0.72)

	mat_badge = StandardMaterial3D.new()
	mat_badge.albedo_color = Color(1.0, 0.88, 0.15)
	mat_badge.metallic = 1.0
	mat_badge.roughness = 0.2

	mat_target = StandardMaterial3D.new()
	mat_target.albedo_color = Color(0.65, 0.6, 0.35)
	mat_target.emission_enabled = true
	mat_target.emission = Color(0.5, 0.45, 0.2)
	mat_target.emission_energy_multiplier = 0.5

	mat_wisp = StandardMaterial3D.new()
	mat_wisp.albedo_color = Color(0.4, 1.0, 0.5)
	mat_wisp.emission_enabled = true
	mat_wisp.emission = Color(0.4, 1.0, 0.5)
	mat_wisp.emission_energy_multiplier = 3.5

	# Infinite grid shader — grid stays fixed in world space
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec2 world_offset = vec2(0.0, 0.0);
void fragment() {
    // UV 0..1 over a 200x200 plane → world-relative coords
    vec2 wp = (UV - 0.5) * 200.0 + world_offset;
    float gs = 3.0;
    vec2 g = fract(wp / gs);
    float lw = 0.04;
    float on_line = max(step(1.0 - lw, g.x), step(1.0 - lw, g.y));
    ALBEDO = mix(vec3(0.08, 0.10, 0.16), vec3(0.14, 0.17, 0.26), on_line);
}
"""
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = shader

func _setup_scene():
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 1.0, 1.0)
	env.ambient_light_energy = 1.8
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.97, 0.90)
	add_child(sun)

	# fill light — follows infected host so entities are always lit
	fill_light = OmniLight3D.new()
	fill_light.omni_range = 40.0
	fill_light.light_energy = 0.6
	fill_light.light_color = Color(0.4, 0.5, 0.8)
	add_child(fill_light)

	# Camera — added to tree before any look_at call
	camera = Camera3D.new()
	camera.fov = 62.0
	add_child(camera)
	camera.position = Vector3(0, CAM_HEIGHT, CAM_BACK)
	cam_look_pos = Vector3(0, 1, 0)
	camera.look_at(cam_look_pos)

	# Ground plane (200×200, follows infected host; shader makes grid world-fixed)
	ground_node = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground_node.mesh = pm
	ground_node.material_override = ground_mat
	add_child(ground_node)

	# Jump wisp
	jump_wisp = MeshInstance3D.new()
	var ws = SphereMesh.new()
	ws.radius = 0.25; ws.height = 0.50
	jump_wisp.mesh = ws
	jump_wisp.material_override = mat_wisp
	jump_wisp.visible = false
	add_child(jump_wisp)

	# Jump target ground marker
	target_marker = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.65; cyl.bottom_radius = 0.65; cyl.height = 0.04
	target_marker.mesh = cyl
	target_marker.material_override = mat_target
	target_marker.visible = false
	add_child(target_marker)

func _setup_hud():
	var canvas = CanvasLayer.new()
	add_child(canvas)

	dim_rect = ColorRect.new()
	dim_rect.position = Vector2.ZERO; dim_rect.size = Vector2(1280, 720)
	dim_rect.color = Color(0, 0, 0, 0.65); dim_rect.visible = false
	canvas.add_child(dim_rect)

	score_label    = _lbl(canvas, Vector2(0,12),    Vector2(1280,50),  32, Color(0.65,1.0,0.65), HORIZONTAL_ALIGNMENT_CENTER)
	best_label     = _lbl(canvas, Vector2(0,52),    Vector2(1280,28),  14, Color(0.35,0.55,0.35), HORIZONTAL_ALIGNMENT_CENTER)
	cop_label      = _lbl(canvas, Vector2(16,14),   Vector2(200,30),   16, Color(0.35,0.55,1.0),  HORIZONTAL_ALIGNMENT_LEFT)
	cooldown_label = _lbl(canvas, Vector2(16,666),  Vector2(220,22),   13, Color(0.3,1.0,0.35),   HORIZONTAL_ALIGNMENT_LEFT)

	bar_bg   = _rect(canvas, Vector2(16,684), Vector2(200,14), Color(0.08,0.12,0.08))
	bar_fill = _rect(canvas, Vector2(16,684), Vector2(200,14), Color(0.18,0.55,0.22))

	hint_label    = _lbl(canvas, Vector2(0,700),   Vector2(1264,20),  13, Color(0.28,0.32,0.28), HORIZONTAL_ALIGNMENT_RIGHT)
	hint_label.text = "SPACE — jump to nearest host"
	overlay_label = _lbl(canvas, Vector2(240,250), Vector2(800,100),  64, Color(0.25,0.95,0.28), HORIZONTAL_ALIGNMENT_CENTER)
	sub_label     = _lbl(canvas, Vector2(240,370), Vector2(800,300),  20, Color(0.55,0.65,0.55), HORIZONTAL_ALIGNMENT_CENTER)

func _lbl(p: Node, pos: Vector2, sz: Vector2, fs: int, col: Color, align: HorizontalAlignment) -> Label:
	var l = Label.new()
	l.position = pos; l.size = sz; l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	p.add_child(l); return l

func _rect(p: Node, pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r = ColorRect.new()
	r.position = pos; r.size = sz; r.color = col
	p.add_child(r); return r

# ═══════════════════════════════════════════════════════════════════════════════
# ENTITY FACTORIES
# ═══════════════════════════════════════════════════════════════════════════════

func _make_civilian() -> Dictionary:
	var root = Node3D.new()

	var body = MeshInstance3D.new()
	var cap = CapsuleMesh.new(); cap.radius = 0.28; cap.height = 0.85
	body.mesh = cap; body.material_override = mat_civilian
	body.position = Vector3(0, 0.42, 0); root.add_child(body)

	var head = MeshInstance3D.new()
	var sph = SphereMesh.new(); sph.radius = 0.22; sph.height = 0.44
	head.mesh = sph; head.material_override = mat_civilian
	head.position = Vector3(0, 1.0, 0); root.add_child(head)

	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.3)
	light.omni_range = 5.0; light.light_energy = 0.0
	light.position = Vector3(0, 0.6, 0); root.add_child(light)

	add_child(root)
	return {"node": root, "body": body, "head": head, "light": light}

func _make_cop() -> Dictionary:
	var root = Node3D.new()

	var body = MeshInstance3D.new()
	var cap = CapsuleMesh.new(); cap.radius = 0.30; cap.height = 0.90
	body.mesh = cap; body.material_override = mat_cop
	body.position = Vector3(0, 0.45, 0); root.add_child(body)

	var head = MeshInstance3D.new()
	var sph = SphereMesh.new(); sph.radius = 0.23; sph.height = 0.46
	head.mesh = sph; head.material_override = mat_cop
	head.position = Vector3(0, 1.05, 0); root.add_child(head)

	var hat = MeshInstance3D.new()
	var box = BoxMesh.new(); box.size = Vector3(0.55, 0.12, 0.42)
	hat.mesh = box; hat.material_override = mat_hat
	hat.position = Vector3(0, 1.34, 0); root.add_child(hat)

	var badge = MeshInstance3D.new()
	var bsph = SphereMesh.new(); bsph.radius = 0.11; bsph.height = 0.22
	badge.mesh = bsph; badge.material_override = mat_badge
	badge.position = Vector3(0.0, 0.48, 0.29); root.add_child(badge)

	add_child(root)
	return {"node": root, "body": body, "head": head, "light": null}

# ═══════════════════════════════════════════════════════════════════════════════
# SPAWN / DESPAWN
# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_entities():
	for e in entities:
		(e["node"] as Node3D).queue_free()
	entities.clear()
	highlight_idx = -1

	# Civilians scattered around origin
	for i in range(NUM_CIVILIANS):
		var a = randf() * TAU
		var d = randf_range(3.0, 14.0)
		var vis = _make_civilian()
		entities.append(_civ_dict(Vector2(cos(a)*d, sin(a)*d), vis))

	# Cops spawn mixed in with civilians now
	for i in range(cop_count):
		var a = i * TAU / cop_count + randf() * 0.5
		var d = randf_range(3.0, 14.0)
		var vis = _make_cop()
		entities.append(_cop_dict(Vector2(cos(a)*d, sin(a)*d), vis))

	infected_idx = 0
	entities[0]["infected"] = true
	_refresh_infected_visuals()
	_sync_nodes()

func _civ_dict(pos: Vector2, vis: Dictionary) -> Dictionary:
	return {
		"pos": pos, "vel": Vector2.ZERO, "is_cop": false, "infected": false,
		"wander_dir": Vector2(randf_range(-1,1), randf_range(-1,1)).normalized(),
		"wander_timer": randf_range(0, 2.5),
		"node": vis["node"], "body": vis["body"], "head": vis["head"], "light": vis["light"],
	}

func _cop_dict(pos: Vector2, vis: Dictionary) -> Dictionary:
	return {
		"pos": pos, "vel": Vector2.ZERO, "is_cop": true, "infected": false,
		"wander_dir": Vector2(randf_range(-1,1), randf_range(-1,1)).normalized(),
		"wander_timer": randf_range(0, 2.0),
		"node": vis["node"], "body": vis["body"], "head": vis["head"], "light": vis["light"],
	}

func _despawn_offscreen():
	var ip = entities[infected_idx]["pos"] as Vector2
	var infected_e = entities[infected_idx]

	var keep: Array = []
	var civ_count = 0
	var cop_c     = 0

	for e in entities:
		var dist = (e["pos"] as Vector2).distance_to(ip)
		if e == infected_e or dist <= DESPAWN_DIST:
			keep.append(e)
			if e["is_cop"]: cop_c += 1
			else:           civ_count += 1
		else:
			(e["node"] as Node3D).queue_free()

	entities = keep
	# Rebuild infected_idx after array rebuild
	for i in range(entities.size()):
		if entities[i] == infected_e:
			infected_idx = i
			break

	# After array change, reset highlight and refresh materials
	highlight_idx = -1
	_refresh_infected_visuals()

	# Spawn replacements at the edge of the visible area
	while civ_count < NUM_CIVILIANS:
		var a = randf() * TAU
		var pos = ip + Vector2(cos(a), sin(a)) * SPAWN_DIST
		var vis = _make_civilian()
		entities.append(_civ_dict(pos, vis))
		civ_count += 1

	while cop_c < cop_count:
		var a = randf() * TAU
		var pos = ip + Vector2(cos(a), sin(a)) * SPAWN_DIST
		var vis = _make_cop()
		entities.append(_cop_dict(pos, vis))
		cop_c += 1

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta):
	pulse_t += delta * 3.0

	if not started:
		_show_title(); return
	if game_over:
		return

	dim_rect.visible = false
	score         += delta
	jump_cooldown  = maxf(0.0, jump_cooldown - delta)

	if jump_anim_active:
		jump_anim_t = maxf(0.0, jump_anim_t - delta * 5.5)
		if jump_anim_t <= 0.0:
			jump_anim_active = false
			jump_wisp.visible = false

	if cop_count < MAX_COPS:
		cop_spawn_timer -= delta
		if cop_spawn_timer <= 0.0:
			cop_spawn_timer = 8.0 
			cop_count += 1 # Let _despawn_offscreen handle the actual spawning

	var difficulty = 1.0 + score / 70.0

	# Ensure the infected host gets its own movement update
	for i in range(entities.size()):
		var e = entities[i]
		if e["is_cop"]: 
			_update_cop(e, delta, difficulty)
		elif i == infected_idx:
			_update_infected(e, delta)
		else:           
			_update_civilian(e, delta)

	_despawn_offscreen()
	_sync_nodes()
	_update_camera(delta)
	_update_wisp()
	_update_target_highlight()
	_check_catch()
	_update_hud()

	# Pulse infected glow + fill light tracking
	var ip3 = Vector3((entities[infected_idx]["pos"] as Vector2).x, 1.5,
					  (entities[infected_idx]["pos"] as Vector2).y)
	fill_light.position = ip3
	ground_node.position = Vector3(ip3.x, 0, ip3.z)
	ground_mat.set_shader_parameter("world_offset", Vector2(ip3.x, ip3.z))

	var pulse = sin(pulse_t) * 0.5 + 0.5
	var li = entities[infected_idx]["light"]
	if li != null:
		(li as OmniLight3D).light_energy = 2.2 + pulse * 1.8
	mat_target.emission_energy_multiplier = 0.2 + pulse * 0.4

func _update_civilian(e: Dictionary, delta: float):
	e["wander_timer"] -= delta
	if e["wander_timer"] <= 0.0:
		e["wander_dir"]   = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
		e["wander_timer"] = randf_range(1.5, 3.5)
	var vel  = e["vel"]        as Vector2
	var wdir = e["wander_dir"] as Vector2
	vel = vel.lerp(wdir * CIVILIAN_SPEED, delta * 2.5)
	e["pos"]        = (e["pos"] as Vector2) + vel * delta
	e["vel"]        = vel
	e["wander_dir"] = wdir

func _update_infected(e: Dictionary, delta: float):
	var pos = e["pos"] as Vector2
	var vel = e["vel"] as Vector2
	
	# 1. Flee from nearby cops
	var flee_dir = Vector2.ZERO
	var is_fleeing = false
	var evade_radius = 6.0 # slightly larger than COP_SIGHT_RANGE

	for i in range(entities.size()):
		var other = entities[i]
		if other["is_cop"]:
			var dist = pos.distance_to(other["pos"])
			if dist < evade_radius:
				var dir = (pos - other["pos"]).normalized()
				if dir == Vector2.ZERO: dir = Vector2(1, 0)
				flee_dir += dir * (evade_radius - dist)
				is_fleeing = true

	if is_fleeing:
		vel = vel.lerp(flee_dir.normalized() * INFECTED_SPEED, delta * 4.0)
	else:
		# 2. Seek dense population if no cops are nearby
		var best_density = -1
		var best_dist = INF
		var target_pos = pos
		var found = false
		var cluster_radius = 8.0

		for i in range(entities.size()):
			if i == infected_idx or entities[i]["is_cop"]: continue
			var center_candidate = entities[i]["pos"] as Vector2
			var dist_to_us = pos.distance_to(center_candidate)
			
			var density = 0
			for j in range(entities.size()):
				if j == infected_idx or entities[j]["is_cop"]: continue
				if center_candidate.distance_to(entities[j]["pos"]) < cluster_radius:
					density += 1
					
			if density > best_density or (density == best_density and dist_to_us < best_dist):
				best_density = density
				best_dist = dist_to_us
				target_pos = center_candidate
				found = true

		if found:
			var dir = (target_pos - pos).normalized()
			vel = vel.lerp(dir * INFECTED_SPEED, delta * 3.5)
		else:
			e["wander_timer"] -= delta
			if e["wander_timer"] <= 0.0:
				e["wander_dir"]   = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
				e["wander_timer"] = randf_range(1.5, 3.5)
			vel = vel.lerp((e["wander_dir"] as Vector2) * INFECTED_SPEED, delta * 2.5)

	e["pos"] = pos + vel * delta
	e["vel"] = vel

func _update_cop(e: Dictionary, delta: float, difficulty: float):
	var ip  = entities[infected_idx]["pos"] as Vector2
	var pos = e["pos"] as Vector2
	var vel = e["vel"] as Vector2

	if pos.distance_to(ip) < COP_SIGHT_RANGE:
		vel = vel.lerp((ip - pos).normalized() * COP_BASE_SPEED * difficulty, delta * 3.5)
	else:
		e["wander_timer"] -= delta
		if e["wander_timer"] <= 0.0:
			e["wander_dir"]   = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
			e["wander_timer"] = randf_range(2.0, 4.5)
		vel = vel.lerp((e["wander_dir"] as Vector2) * CIVILIAN_SPEED * 0.65, delta * 2.0)

	e["pos"] = pos + vel * delta
	e["vel"] = vel

func _sync_nodes():
	for e in entities:
		var p = e["pos"] as Vector2
		var n = e["node"] as Node3D
		n.position = Vector3(p.x, 0, p.y)
		var v = e["vel"] as Vector2
		if v.length_squared() > 0.01:
			n.rotation.y = atan2(v.x, v.y)

func _update_camera(delta: float):
	if entities.is_empty(): return
	var ip = entities[infected_idx]["pos"] as Vector2
	var host3 = Vector3(ip.x, 0, ip.y)
	var desired_pos = host3 + Vector3(0, CAM_HEIGHT, CAM_BACK)
	# Slow lerp so the camera slides to the new host rather than snapping
	camera.position = camera.position.lerp(desired_pos, delta * 2.5)
	cam_look_pos    = cam_look_pos.lerp(host3 + Vector3(0, 1.0, 0), delta * 2.5)
	camera.look_at(cam_look_pos)

func _update_wisp():
	if not jump_anim_active: return
	var frac  = 1.0 - jump_anim_t
	var from3 = Vector3(jump_anim_from.x, 0.6, jump_anim_from.y)
	var to3   = Vector3(jump_anim_to.x,   0.6, jump_anim_to.y)
	var p = from3.lerp(to3, frac)
	p.y = 0.6 + sin(frac * PI) * 2.5
	jump_wisp.position = p
	jump_wisp.scale    = Vector3.ONE * (0.4 + jump_anim_t * 0.7)

func _update_target_highlight():
	if game_over: return
	var ip = entities[infected_idx]["pos"] as Vector2
	var best_dist = INF
	var best_i    = -1
	for i in range(entities.size()):
		if i == infected_idx or entities[i]["is_cop"]: continue
		var d = ip.distance_to(entities[i]["pos"])
		# Only allow jump if within maximum distance
		if d < best_dist and d <= MAX_JUMP_DIST:
			best_dist = d; best_i = i

	if best_i == highlight_idx:
		# Same target — just move the marker
		if highlight_idx >= 0:
			var tp = entities[highlight_idx]["pos"] as Vector2
			target_marker.position = Vector3(tp.x, 0.03, tp.y)
			var pulse = sin(pulse_t * 2.5) * 0.5 + 0.5
			target_marker.scale = Vector3.ONE * (0.85 + pulse * 0.35)
		return

	# Restore old target's material
	if highlight_idx >= 0 and highlight_idx < entities.size():
		var old = entities[highlight_idx]
		if not old["is_cop"] and not old.get("infected", false):
			(old["body"] as MeshInstance3D).material_override = mat_civilian
			(old["head"] as MeshInstance3D).material_override = mat_civilian

	highlight_idx = best_i

	if highlight_idx >= 0:
		var e = entities[highlight_idx]
		(e["body"] as MeshInstance3D).material_override = mat_target
		(e["head"] as MeshInstance3D).material_override = mat_target
		var tp = entities[highlight_idx]["pos"] as Vector2
		target_marker.position = Vector3(tp.x, 0.03, tp.y)
		target_marker.visible = true
	else:
		target_marker.visible = false

func _check_catch():
	var ip = entities[infected_idx]["pos"] as Vector2
	for e in entities:
		if e["is_cop"] and (e["pos"] as Vector2).distance_to(ip) < CATCH_DIST + COP_RADIUS:
			game_over = true
			if score > best_score: best_score = score
			_show_game_over(); return

func _refresh_infected_visuals():
	for i in range(entities.size()):
		var e = entities[i]
		if e["is_cop"]: continue
		var is_inf = (i == infected_idx)
		var mat    = mat_infected if is_inf else mat_civilian
		(e["body"] as MeshInstance3D).material_override = mat
		(e["head"] as MeshInstance3D).material_override = mat
		var li = e["light"]
		if li != null:
			(li as OmniLight3D).light_energy = 3.5 if is_inf else 0.0

# ═══════════════════════════════════════════════════════════════════════════════
# HUD
# ═══════════════════════════════════════════════════════════════════════════════

func _show_title():
	dim_rect.visible = true
	var pulse = sin(pulse_t) * 0.5 + 0.5
	overlay_label.text = "P A R A S I T E"
	overlay_label.add_theme_color_override("font_color", Color(0.25, 0.9+pulse*0.08, 0.28))
	sub_label.text = (
		"You are a virus. Jump between hosts.\n" +
		"Cops only chase when they spot you nearby.\n" +
        "Survive as long as you can.\n\n[ SPACE ] to start"
	)
	score_label.text = ""; best_label.text = ""
	cop_label.text   = ""; cooldown_label.text = ""
	bar_fill.size.x  = 0

func _show_game_over():
	dim_rect.visible = true
	target_marker.visible = false
	overlay_label.text = "C A U G H T"
	overlay_label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.08))
	var mins = int(score)/60;  var secs = int(score)%60
	var msg  = "You survived   %02d:%02d" % [mins, secs]
	if score >= best_score and best_score > 0: msg += "\n\nN E W   B E S T !"
	msg += "\n\n[ SPACE ] to try again"
	sub_label.text = msg

func _update_hud():
	var mins = int(score)/60;  var secs = int(score)%60
	score_label.text = "%02d:%02d" % [mins, secs]
	if best_score > 0:
		var bm = int(best_score)/60; var bs = int(best_score)%60
		best_label.text = "best  %02d:%02d" % [bm, bs]
	cop_label.text     = "COPS: %d" % cop_count
	overlay_label.text = ""; sub_label.text = ""

	if jump_cooldown > 0:
		bar_fill.size.x = (1.0 - jump_cooldown / JUMP_COOLDOWN) * 200.0
		bar_fill.color  = Color(0.18, 0.55, 0.22)
		cooldown_label.text = "CHARGING..."
		cooldown_label.add_theme_color_override("font_color", Color(0.35, 0.55, 0.35))
	else:
		var pulse = sin(pulse_t) * 0.5 + 0.5
		bar_fill.size.x = 200.0
		bar_fill.color  = Color(0.18, 0.50+pulse*0.35, 0.20)
		cooldown_label.text = "JUMP READY"
		cooldown_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))

# ═══════════════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════════════

func _input(event):
	if not (event is InputEventKey and event.pressed
			and not event.echo and event.keycode == KEY_SPACE):
		return
	if not started: started = true; return
	if game_over:   _restart(); return
	_try_jump()

func _try_jump():
	if jump_cooldown > 0: return
	var ip      = entities[infected_idx]["pos"] as Vector2
	var best_i  = highlight_idx  # jump to whatever is highlighted
	if best_i < 0:
		# fallback: find nearest
		var best_d = INF
		for i in range(entities.size()):
			if i == infected_idx or entities[i]["is_cop"]: continue
			var d = ip.distance_to(entities[i]["pos"])
			# Only allow jump if within maximum distance
			if d < best_d and d <= MAX_JUMP_DIST:
				best_d = d; best_i = i
	if best_i < 0: return # Fails if no host is in range

	var old_entity = entities[infected_idx]
	var new_entity = entities[best_i]

	jump_anim_from = ip
	jump_anim_to   = new_entity["pos"]
	jump_anim_active = true; jump_anim_t = 1.0
	jump_wisp.visible = true

	new_entity["infected"] = true

	# Kill the old host
	(old_entity["node"] as Node3D).queue_free()
	entities.erase(old_entity)

	# Re-find the new host's index because erasing the old one shifted the array
	infected_idx = entities.find(new_entity)
	
	highlight_idx = -1          # force highlight recalc next frame
	_refresh_infected_visuals() # also clears any stale mat_target
	jump_cooldown = JUMP_COOLDOWN

func _restart():
	score = 0.0; jump_cooldown = 0.0
	game_over = false; started = true
	pulse_t = 0.0; cop_count = INITIAL_COPS; cop_spawn_timer = 8.0 
	jump_anim_active = false; jump_wisp.visible = false
	highlight_idx = -1; target_marker.visible = false
	_spawn_entities()
