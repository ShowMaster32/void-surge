extends Node

# ─────────────────────────────────────────────
#  VFX Manager  –  hit particles + floating damage numbers
# ─────────────────────────────────────────────

const POOL_SIZE     := 20
const HIT_LIFETIME  := 0.4
const DEATH_LIFETIME:= 0.8

# ── particle pool ──────────────────────────────────────────────────────────────
var _hit_pool:   Array[GPUParticles2D] = []
var _death_pool: Array[GPUParticles2D] = []

# ── damage number config ───────────────────────────────────────────────────────
const DMG_FLOAT_HEIGHT := -70.0   # pixels upward
const DMG_DURATION     := 0.85    # seconds
const DMG_CRIT_SCALE   := 1.6
const DMG_NORMAL_SCALE := 1.0

func _ready() -> void:
	_build_hit_pool()
	_build_death_pool()


# ══════════════════════════════════════════════
#  Particle pools
# ══════════════════════════════════════════════

func _build_hit_pool() -> void:
	for i in POOL_SIZE:
		var p := GPUParticles2D.new()
		p.emitting   = false
		p.one_shot   = true
		p.amount     = 8
		p.lifetime   = HIT_LIFETIME
		p.explosiveness = 0.9
		p.process_material = _make_hit_material()
		add_child(p)
		_hit_pool.append(p)

func _build_death_pool() -> void:
	for i in POOL_SIZE:
		var p := GPUParticles2D.new()
		p.emitting   = false
		p.one_shot   = true
		p.amount     = 24
		p.lifetime   = DEATH_LIFETIME
		p.explosiveness = 1.0
		p.process_material = _make_death_material()
		add_child(p)
		_death_pool.append(p)

func _make_hit_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction           = Vector3(0, -1, 0)
	m.spread              = 45.0
	m.initial_velocity_min = 60.0
	m.initial_velocity_max = 120.0
	m.gravity             = Vector3(0, 200, 0)
	m.scale_min           = 2.0
	m.scale_max           = 5.0
	m.color               = Color(1, 1, 1, 1)
	return m

func _make_death_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction           = Vector3(0, 0, 0)
	m.spread              = 180.0
	m.initial_velocity_min = 80.0
	m.initial_velocity_max = 200.0
	m.gravity             = Vector3(0, 120, 0)
	m.scale_min           = 3.0
	m.scale_max           = 8.0
	m.color               = Color(1, 0.4, 0.1, 1)
	return m

func _get_free_hit() -> GPUParticles2D:
	for p in _hit_pool:
		if not p.emitting:
			return p
	return _hit_pool[0]

func _get_free_death() -> GPUParticles2D:
	for p in _death_pool:
		if not p.emitting:
			return p
	return _death_pool[0]


# ══════════════════════════════════════════════
#  Public: particle spawners
# ══════════════════════════════════════════════

func spawn_hit_effect(world_pos: Vector2, hit_color: Color = Color.WHITE) -> void:
	var p := _get_free_hit()
	p.global_position = world_pos
	if p.process_material is ParticleProcessMaterial:
		p.process_material.color = hit_color
	p.restart()

func spawn_death_effect(world_pos: Vector2, death_color: Color = Color(1, 0.4, 0.1)) -> void:
	var p := _get_free_death()
	p.global_position = world_pos
	if p.process_material is ParticleProcessMaterial:
		p.process_material.color = death_color
	p.restart()


# ══════════════════════════════════════════════
#  Public: floating damage numbers
# ══════════════════════════════════════════════
#
#  Spawns a Label in world-space on current_scene.
#  Tween:  pop-scale  ➜  float upward  ➜  fade out
#
#  world_pos  : global position of the hit (usually enemy.global_position)
#  value      : damage dealt (int)
#  is_crit    : gold colour, ★ prefix, bigger scale, extra punch
#  color      : override tint (pass Color.TRANSPARENT to use defaults)

func spawn_damage_number(
		world_pos : Vector2,
		value     : int,
		is_crit   : bool  = false,
		color     : Color = Color.TRANSPARENT
) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	# ── Label node ────────────────────────────────────────────────────────────
	var lbl := Label.new()
	lbl.text = ("★ " if is_crit else "") + str(value)
	lbl.z_index = 100

	# Font size
	var font_size: int = 28 if is_crit else 20
	lbl.add_theme_font_size_override("font_size", font_size)

	# Colour
	var base_color: Color
	if color != Color.TRANSPARENT:
		base_color = color
	elif is_crit:
		base_color = Color(1.0, 0.85, 0.1)    # gold
	else:
		base_color = Color(1.0, 1.0, 1.0)     # white

	lbl.add_theme_color_override("font_color", base_color)

	# Outline for readability
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))

	# Position (world-space, offset so it centres above hit point)
	lbl.global_position = world_pos + Vector2(-20, -20)

	scene_root.add_child(lbl)

	# ── Initial pop scale ─────────────────────────────────────────────────────
	var start_scale: float = DMG_CRIT_SCALE if is_crit else DMG_NORMAL_SCALE
	lbl.scale = Vector2(start_scale * 1.4, start_scale * 1.4)

	# ── Tween: pop → float → fade ─────────────────────────────────────────────
	var tw: Tween = scene_root.create_tween()
	tw.set_parallel(true)

	# scale pop back to normal
	tw.tween_property(lbl, "scale",
		Vector2(start_scale, start_scale), 0.12
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# float upward
	var end_pos: Vector2 = lbl.global_position + Vector2(randf_range(-15, 15), DMG_FLOAT_HEIGHT)
	tw.tween_property(lbl, "global_position", end_pos, DMG_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# fade out (starts after 0.4 s hold)
	tw.tween_property(lbl, "modulate:a", 0.0, DMG_DURATION * 0.55
	).set_delay(DMG_DURATION * 0.45
	).set_ease(Tween.EASE_IN)

	# remove when done
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free).set_delay(DMG_DURATION + 0.05)


# ══════════════════════════════════════════════
#  Public: screen-shake helper
# ══════════════════════════════════════════════

func screen_shake(camera: Camera2D, strength: float = 6.0, duration: float = 0.18) -> void:
	if camera == null:
		return
	var origin := camera.offset
	var tw: Tween = create_tween()
	var steps := int(duration / 0.04)
	for _i in steps:
		tw.tween_property(camera, "offset",
			origin + Vector2(randf_range(-strength, strength), randf_range(-strength, strength)),
			0.04)
	tw.tween_property(camera, "offset", origin, 0.04)
