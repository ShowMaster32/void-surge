extends Node2D
class_name ZoneGenerator
## ZoneGenerator v2 — Biomi spaziali procedurali con visual avanzati
##
## Ogni zona ha:
##   - Shader nebulare animato con domain-warping fbm
##   - 3 layer di stelle (piccole, medie, grandi/luminose)
##   - Decorazioni: pianeti con atmosfera/anelli, gas cloud wisps
##   - Ostacoli unici per bioma (rocce irregolari, cristalli, piloni, frammenti rift)
##   - Animazioni zona-specifiche (fulmini arco, linee glitch)
##   - Boundary glow neon pulsante per bioma

signal zone_changed(zone_data: ZoneData)
signal zone_generated(zone_id: String)
signal hazard_hit(damage: float)

@export var zone_size: Vector2 = Vector2(4800, 4800)
@export var transition_duration: float = 1.5

var available_zones: Array[ZoneData] = []
var current_zone: ZoneData
var current_zone_index: int = 0
var generation_seed: int = 0

# Layer root nodes
var _bg:             ColorRect
var _bg_mat:         ShaderMaterial
var _stars_a:        Node2D   # piccole e dense
var _stars_b:        Node2D   # medie, colorate
var _stars_c:        Node2D   # grandi, luminose
var _decor:          Node2D   # pianeti e wisps
var _obstacles_root: Node2D
var _hazards_root:   Node2D
var _boundary_root:  Node2D
var _anim_root:      Node2D   # animazioni zona-specifiche
var _anim_timer:     Timer    # timer per animazioni cicliche

# ── Configurazioni visive per ogni bioma ──────────────────────────────────────
const ZONE_VIS := {
	"void_black": {
		"bg_a":      Color(0.000, 0.000, 0.022),
		"bg_b":      Color(0.014, 0.008, 0.052),
		"neb_col":   Color(0.28, 0.12, 0.85, 0.30),
		"neb_scale": 3.0, "neb_spd": 0.007, "neb_thr": 0.50,
		"star_col":  Color(0.80, 0.88, 1.00), "star_n": 240,
		"bnd_col":   Color(0.35, 0.15, 1.00),
		"planet": {
			"col": Color(0.16, 0.07, 0.40), "atm": Color(0.45, 0.20, 1.00),
			"r": 290.0, "ring": true, "pos": Vector2(-1350, -980),
		},
		"wisps": [
			{"pos": Vector2(-600, -800), "r": 320, "col": Color(0.30, 0.10, 0.80, 0.06)},
			{"pos": Vector2( 900,  500), "r": 260, "col": Color(0.20, 0.10, 0.60, 0.05)},
		],
		"obs_style": "void_rock", "obs_col": Color(0.22, 0.18, 0.35),
		"anim": "none",
	},
	"nebula_purple": {
		"bg_a":      Color(0.032, 0.008, 0.068),
		"bg_b":      Color(0.062, 0.016, 0.132),
		"neb_col":   Color(0.88, 0.22, 0.98, 0.44),
		"neb_scale": 1.85, "neb_spd": 0.016, "neb_thr": 0.35,
		"star_col":  Color(1.00, 0.82, 0.96), "star_n": 160,
		"bnd_col":   Color(0.92, 0.15, 1.00),
		"planet": null,
		"wisps": [
			{"pos": Vector2(-400, -500), "r": 480, "col": Color(0.80, 0.10, 0.90, 0.07)},
			{"pos": Vector2( 700, -200), "r": 360, "col": Color(0.90, 0.30, 0.80, 0.05)},
			{"pos": Vector2(-800,  600), "r": 420, "col": Color(0.60, 0.10, 0.90, 0.06)},
		],
		"obs_style": "crystal", "obs_col": Color(0.95, 0.30, 1.00),
		"anim": "none",
	},
	"asteroid_field": {
		"bg_a":      Color(0.022, 0.016, 0.007),
		"bg_b":      Color(0.055, 0.038, 0.014),
		"neb_col":   Color(0.78, 0.44, 0.10, 0.22),
		"neb_scale": 2.6, "neb_spd": 0.005, "neb_thr": 0.48,
		"star_col":  Color(0.92, 0.84, 0.70), "star_n": 110,
		"bnd_col":   Color(0.88, 0.44, 0.06),
		"planet": {
			"col": Color(0.30, 0.19, 0.10), "atm": Color(0.80, 0.44, 0.12),
			"r": 400.0, "ring": false, "pos": Vector2(1400, -900),
		},
		"wisps": [
			{"pos": Vector2(200, 400), "r": 380, "col": Color(0.50, 0.30, 0.10, 0.05)},
		],
		"obs_style": "heavy_rock", "obs_col": Color(0.48, 0.32, 0.16),
		"anim": "none",
	},
	"plasma_storm": {
		"bg_a":      Color(0.000, 0.016, 0.072),
		"bg_b":      Color(0.000, 0.038, 0.135),
		"neb_col":   Color(0.05, 0.68, 1.00, 0.40),
		"neb_scale": 1.65, "neb_spd": 0.030, "neb_thr": 0.32,
		"star_col":  Color(0.72, 0.92, 1.00), "star_n": 130,
		"bnd_col":   Color(0.00, 0.82, 1.00),
		"planet": null,
		"wisps": [
			{"pos": Vector2(-300,  300), "r": 500, "col": Color(0.00, 0.50, 1.00, 0.05)},
			{"pos": Vector2( 600, -400), "r": 350, "col": Color(0.10, 0.70, 1.00, 0.04)},
		],
		"obs_style": "pylon", "obs_col": Color(0.00, 0.88, 1.00),
		"anim": "arc_lightning",
	},
	"dimension_rift": {
		"bg_a":      Color(0.000, 0.022, 0.010),
		"bg_b":      Color(0.008, 0.052, 0.025),
		"neb_col":   Color(0.12, 0.95, 0.38, 0.32),
		"neb_scale": 2.0, "neb_spd": 0.022, "neb_thr": 0.40,
		"star_col":  Color(0.78, 1.00, 0.84), "star_n": 165,
		"bnd_col":   Color(0.12, 1.00, 0.44),
		"planet": null,
		"wisps": [
			{"pos": Vector2(0, 0), "r": 600, "col": Color(0.10, 0.90, 0.30, 0.04)},
		],
		"obs_style": "rift_shard", "obs_col": Color(0.18, 1.00, 0.52),
		"anim": "glitch_lines",
	},
}


# ══════════════════════════════════════════════════════════════════════════════
#  Inner class: pianeta decorativo
# ══════════════════════════════════════════════════════════════════════════════
class _Planet extends Node2D:
	var planet_radius: float = 200.0
	var body_col: Color      = Color(0.18, 0.08, 0.40)
	var atm_col: Color       = Color(0.45, 0.20, 1.00)
	var has_ring: bool       = false

	func _draw() -> void:
		# Alone atmosferica esterna (glow a strati)
		for i in range(9, 0, -1):
			var gr: float  = planet_radius + i * 16.0
			var ga: float  = 0.055 * (float(i) / 9.0)
			draw_circle(Vector2.ZERO, gr, Color(atm_col.r, atm_col.g, atm_col.b, ga))

		# Corpo pianeta
		draw_circle(Vector2.ZERO, planet_radius, body_col)

		# Highlight (lucentezza in alto a sinistra)
		var hl_col := body_col.lightened(0.35)
		hl_col.a = 0.22
		draw_circle(
			Vector2(-planet_radius * 0.30, -planet_radius * 0.28),
			planet_radius * 0.58, hl_col)

		# Ombra (cerchio scuro sfumato, lato destro)
		draw_circle(
			Vector2(planet_radius * 0.32, planet_radius * 0.14),
			planet_radius * 0.87,
			Color(0.0, 0.0, 0.0, 0.52))

		# Linea atmosfera brillante sul bordo illuminato
		var rim_col := atm_col.lightened(0.4)
		rim_col.a = 0.30
		draw_arc(Vector2.ZERO, planet_radius, deg_to_rad(200), deg_to_rad(340), 48, rim_col, 2.5)

		# Anelli (se abilitati)
		if has_ring:
			for ri in 10:
				var rr: float = planet_radius * (1.30 + ri * 0.085)
				var ra: float = 0.18 - ri * 0.016
				if ra <= 0.0:
					break
				var rc := Color(0.92, 0.84, 0.62, ra)
				draw_arc(Vector2.ZERO, rr, deg_to_rad(12), deg_to_rad(168), 48, rc, 2.2)


# ══════════════════════════════════════════════════════════════════════════════
#  Inner class: roccia irregolare (void_rock / heavy_rock)
# ══════════════════════════════════════════════════════════════════════════════
class _Rock extends Node2D:
	var sz: float      = 36.0
	var col: Color     = Color(0.22, 0.18, 0.35)
	var heavy: bool    = false   # heavy rock = più grande e bumposa

	func _draw() -> void:
		var pts := PackedVector2Array()
		var n: int = 10 if heavy else 8
		var glow_col := col.lightened(0.4)
		glow_col.a = 0.18

		for i in n:
			var a := TAU * i / n + sin(float(i) * 2.1) * 0.28
			var r := sz * (0.78 + sin(float(i) * 3.7 + 1.0) * 0.22)
			pts.append(Vector2(cos(a), sin(a)) * r)

		# Glow esterno
		var glow_pts := PackedVector2Array()
		for p in pts:
			glow_pts.append(p * 1.35)
		var gcols := PackedColorArray()
		for i in glow_pts.size():
			gcols.append(Color(glow_col.r, glow_col.g, glow_col.b, 0.0 if i == glow_pts.size() - 1 else 0.12))
		draw_polygon(glow_pts, gcols)

		# Corpo roccia
		var cols := PackedColorArray()
		for _i in pts.size():
			cols.append(col)
		draw_polygon(pts, cols)

		# Bordo luminoso
		var edge_col := col.lightened(0.5)
		edge_col.a = 0.55
		var edge_pts := pts.duplicate()
		edge_pts.append(pts[0])
		draw_polyline(edge_pts, edge_col, 1.4)

		# Craterini (solo heavy)
		if heavy:
			var c1_col := col.darkened(0.4)
			c1_col.a = 0.7
			draw_circle(Vector2(-sz * 0.25, -sz * 0.20), sz * 0.18, c1_col)
			draw_circle(Vector2( sz * 0.30,  sz * 0.15), sz * 0.12, c1_col)


# ══════════════════════════════════════════════════════════════════════════════
#  Inner class: cristallo luminoso (nebula zone)
# ══════════════════════════════════════════════════════════════════════════════
class _Crystal extends Node2D:
	var sz: float   = 30.0
	var col: Color  = Color(0.95, 0.30, 1.00)

	func _draw() -> void:
		# Alone glow
		for gi in range(4, 0, -1):
			var gr: float = sz * (1.2 + gi * 0.22)
			var ga: float = 0.08 * float(gi) / 4.0
			draw_circle(Vector2.ZERO, gr, Color(col.r, col.g, col.b, ga))

		# Corpo cristallo (diamante allungato)
		var pts := PackedVector2Array([
			Vector2(0.0,           -sz * 1.10),
			Vector2( sz * 0.38,   -sz * 0.18),
			Vector2( sz * 0.55,    sz * 0.50),
			Vector2( sz * 0.15,    sz * 0.85),
			Vector2(-sz * 0.15,    sz * 0.85),
			Vector2(-sz * 0.55,    sz * 0.50),
			Vector2(-sz * 0.38,   -sz * 0.18),
		])
		var body_col := col.darkened(0.35)
		var bcols := PackedColorArray()
		for _i in pts.size():
			bcols.append(body_col)
		draw_polygon(pts, bcols)

		# Faccia interna (più chiara)
		var inner_pts := PackedVector2Array([
			Vector2(0.0,          -sz * 0.80),
			Vector2( sz * 0.22,   -sz * 0.05),
			Vector2( sz * 0.32,    sz * 0.38),
			Vector2(0.0,           sz * 0.58),
			Vector2(-sz * 0.32,    sz * 0.38),
			Vector2(-sz * 0.22,   -sz * 0.05),
		])
		var face_col := col.lightened(0.15)
		face_col.a = 0.75
		var fcols := PackedColorArray()
		for _i in inner_pts.size():
			fcols.append(face_col)
		draw_polygon(inner_pts, fcols)

		# Bordo brillante
		var edge_pts := pts.duplicate()
		edge_pts.append(pts[0])
		draw_polyline(edge_pts, Color(col.r, col.g, col.b, 0.90), 1.6)

		# Punto luce in cima
		draw_circle(Vector2(0, -sz * 1.1), 3.0, Color(1, 1, 1, 0.85))


# ══════════════════════════════════════════════════════════════════════════════
#  Inner class: pilone plasma (plasma storm)
# ══════════════════════════════════════════════════════════════════════════════
class _Pylon extends Node2D:
	var sz: float   = 18.0
	var col: Color  = Color(0.00, 0.88, 1.00)
	var _phase: float = 0.0

	func _ready() -> void:
		_phase = randf() * TAU
		# Pulsazione lenta
		var tw := create_tween()
		tw.set_loops()
		tw.set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "modulate:a", 0.55, randf_range(0.8, 1.4))
		tw.tween_property(self, "modulate:a", 1.00, randf_range(0.8, 1.4))

	func _draw() -> void:
		var h: float = sz * 3.8

		# Alone glow colonna
		for gi in range(5, 0, -1):
			var gw: float = sz * (1.4 + gi * 0.28)
			draw_rect(Rect2(-gw * 0.5, -h * 0.5, gw, h),
				Color(col.r, col.g, col.b, 0.04 * float(gi)))

		# Corpo pilone
		draw_rect(Rect2(-sz * 0.5, -h * 0.5, sz, h),
			Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.95))

		# Bordi luminosi laterali
		draw_line(Vector2(-sz * 0.5, -h * 0.5), Vector2(-sz * 0.5, h * 0.5),
			Color(col.r, col.g, col.b, 0.80), 1.8)
		draw_line(Vector2( sz * 0.5, -h * 0.5), Vector2( sz * 0.5, h * 0.5),
			Color(col.r, col.g, col.b, 0.80), 1.8)

		# Bande orizzontali energia
		for bi in 4:
			var by: float = -h * 0.35 + bi * (h * 0.22)
			draw_line(Vector2(-sz * 0.5, by), Vector2(sz * 0.5, by),
				Color(col.r, col.g, col.b, 0.50), 1.2)

		# Nucleo centrale luminoso
		draw_circle(Vector2.ZERO, sz * 0.32, Color(1.0, 1.0, 1.0, 0.80))
		draw_circle(Vector2.ZERO, sz * 0.20, col)


# ══════════════════════════════════════════════════════════════════════════════
#  Inner class: frammento rift (dimension rift)
# ══════════════════════════════════════════════════════════════════════════════
class _RiftShard extends Node2D:
	var sz: float  = 28.0
	var col: Color = Color(0.18, 1.00, 0.52)

	func _ready() -> void:
		# Glitch color shift
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(self, "modulate",
			Color(col.r * 0.6, col.g * 0.6, col.b * 1.2, 1.0), randf_range(0.4, 0.9))
		tw.tween_property(self, "modulate", Color.WHITE, randf_range(0.3, 0.7))

	func _draw() -> void:
		# Glow
		for gi in range(4, 0, -1):
			var gr: float = sz * (1.1 + gi * 0.18)
			draw_circle(Vector2.ZERO, gr, Color(col.r, col.g, col.b, 0.06 * float(gi)))

		# Forma shard angolosa
		var pts := PackedVector2Array([
			Vector2( 0.0,          -sz * 1.20),
			Vector2( sz * 0.55,    -sz * 0.25),
			Vector2( sz * 0.80,     sz * 0.55),
			Vector2( sz * 0.15,     sz * 0.90),
			Vector2(-sz * 0.40,     sz * 0.70),
			Vector2(-sz * 0.75,    -sz * 0.10),
			Vector2(-sz * 0.20,    -sz * 0.80),
		])
		var dark_col := col.darkened(0.55)
		dark_col.a = 0.92
		var bcols := PackedColorArray()
		for _i in pts.size():
			bcols.append(dark_col)
		draw_polygon(pts, bcols)

		# Venature interne
		draw_line(Vector2(0, -sz * 1.2), Vector2(sz * 0.15, sz * 0.9),
			Color(col.r, col.g, col.b, 0.55), 1.0)
		draw_line(Vector2(-sz * 0.20, -sz * 0.80), Vector2(sz * 0.80, sz * 0.55),
			Color(col.r, col.g, col.b, 0.35), 0.8)

		# Bordo neon
		var ep := pts.duplicate()
		ep.append(pts[0])
		draw_polyline(ep, Color(col.r, col.g, col.b, 0.88), 1.8)

		# Punta luminosa
		draw_circle(Vector2(0, -sz * 1.2), 2.8, Color(1, 1, 1, 0.90))


# ══════════════════════════════════════════════════════════════════════════════
#  Lifecycle
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("zone_generator")
	_load_zones()
	_setup_containers()

	if generation_seed == 0:
		generation_seed = randi()

	generate_zone(0)


func _load_zones() -> void:
	var zone_paths := [
		"res://resources/zones/void_black.tres",
		"res://resources/zones/nebula_purple.tres",
		"res://resources/zones/asteroid_field.tres",
		"res://resources/zones/plasma_storm.tres",
		"res://resources/zones/dimension_rift.tres",
	]
	for path in zone_paths:
		var zone := load(path) as ZoneData
		if zone:
			available_zones.append(zone)
		else:
			push_warning("ZoneGenerator: impossibile caricare %s" % path)


func _setup_containers() -> void:
	# Background
	_bg = ColorRect.new()
	_bg.name = "Background"
	_bg.z_index = -100
	_bg.size = zone_size
	_bg.position = -zone_size / 2
	add_child(_bg)
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = _create_nebula_shader()
	_bg.material = _bg_mat

	# Layer stelle
	_stars_a = Node2D.new(); _stars_a.name = "StarsA"; _stars_a.z_index = -90; add_child(_stars_a)
	_stars_b = Node2D.new(); _stars_b.name = "StarsB"; _stars_b.z_index = -85; add_child(_stars_b)
	_stars_c = Node2D.new(); _stars_c.name = "StarsC"; _stars_c.z_index = -80; add_child(_stars_c)

	# Decorazioni (pianeti, wisps)
	_decor = Node2D.new(); _decor.name = "Decorations"; _decor.z_index = -70; add_child(_decor)

	# Ostacoli
	_obstacles_root = Node2D.new(); _obstacles_root.name = "Obstacles"; _obstacles_root.z_index = -10; add_child(_obstacles_root)

	# Hazard
	_hazards_root = Node2D.new(); _hazards_root.name = "Hazards"; _hazards_root.z_index = -5; add_child(_hazards_root)

	# Animazioni zona
	_anim_root = Node2D.new(); _anim_root.name = "ZoneAnim"; _anim_root.z_index = -60; add_child(_anim_root)
	_anim_timer = Timer.new(); _anim_timer.name = "AnimTimer"; add_child(_anim_timer)

	_generate_world_bounds()


# ══════════════════════════════════════════════════════════════════════════════
#  API pubblica
# ══════════════════════════════════════════════════════════════════════════════

func generate_zone(zone_index: int, custom_seed: int = -1) -> void:
	if zone_index < 0 or zone_index >= available_zones.size():
		zone_index = 0

	current_zone_index = zone_index
	current_zone = available_zones[zone_index]

	var use_seed: int = custom_seed if custom_seed >= 0 else generation_seed + zone_index
	seed(use_seed)

	_clear_zone()
	_generate_background()
	_generate_stars()
	_generate_decorations()
	_generate_obstacles()
	_generate_boundary_glow()
	_setup_zone_animations()

	if current_zone.hazard_enabled:
		_setup_hazards()

	zone_changed.emit(current_zone)
	zone_generated.emit(current_zone.zone_id)


func generate_random_zone() -> void:
	var new_index := current_zone_index
	while new_index == current_zone_index and available_zones.size() > 1:
		new_index = randi() % available_zones.size()
	generate_zone(new_index)


func next_zone() -> void:
	generate_zone((current_zone_index + 1) % available_zones.size())


func get_current_zone() -> ZoneData:
	return current_zone


func get_zone_count() -> int:
	return available_zones.size()


func get_zone_by_id(zone_id: String) -> ZoneData:
	for zone in available_zones:
		if zone.zone_id == zone_id:
			return zone
	return null


# ══════════════════════════════════════════════════════════════════════════════
#  Clear
# ══════════════════════════════════════════════════════════════════════════════

func _clear_zone() -> void:
	for c in _stars_a.get_children():   c.queue_free()
	for c in _stars_b.get_children():   c.queue_free()
	for c in _stars_c.get_children():   c.queue_free()
	for c in _decor.get_children():     c.queue_free()
	for c in _obstacles_root.get_children(): c.queue_free()
	for c in _hazards_root.get_children():   c.queue_free()
	for c in _anim_root.get_children():      c.queue_free()
	_anim_timer.stop()


# ══════════════════════════════════════════════════════════════════════════════
#  Background shader nebulare animato
# ══════════════════════════════════════════════════════════════════════════════

func _generate_background() -> void:
	var zid: String = current_zone.zone_id if current_zone else "void_black"
	var cfg: Dictionary = ZONE_VIS.get(zid, ZONE_VIS["void_black"])

	_bg_mat.set_shader_parameter("color_a",    cfg["bg_a"])
	_bg_mat.set_shader_parameter("color_b",    cfg["bg_b"])
	_bg_mat.set_shader_parameter("neb_col",    cfg["neb_col"])
	_bg_mat.set_shader_parameter("neb_scale",  cfg["neb_scale"])
	_bg_mat.set_shader_parameter("neb_spd",    cfg["neb_spd"])
	_bg_mat.set_shader_parameter("neb_thr",    cfg["neb_thr"])


func _create_nebula_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;

uniform vec4  color_a   : source_color = vec4(0.00, 0.00, 0.022, 1.0);
uniform vec4  color_b   : source_color = vec4(0.014, 0.008, 0.052, 1.0);
uniform vec4  neb_col   : source_color = vec4(0.28, 0.12, 0.85, 0.30);
uniform float neb_scale = 3.0;
uniform float neb_spd   = 0.007;
uniform float neb_thr   = 0.50;

float h21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1,0)), u.x),
	           mix(h21(i + vec2(0,1)), h21(i + vec2(1,1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.13 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// Gradiente base con smoothstep per evitare il banding
	float gy = UV.y * UV.y * (3.0 - 2.0 * UV.y);
	vec4 base = mix(color_a, color_b, gy);

	float t = TIME;
	// Layer 1 nebulare con domain warping
	vec2 uv1 = UV * neb_scale + vec2(t * neb_spd, t * neb_spd * 0.60);
	vec2 uv2 = UV * neb_scale * 0.72 + vec2(-t * neb_spd * 0.80, t * neb_spd * 0.40) + vec2(3.5, 7.2);
	float c1  = fbm(uv1);
	float c2  = fbm(uv2 + fbm(uv1) * 1.6);   // domain warping
	float cl1 = smoothstep(neb_thr, neb_thr + 0.30, c1 * 0.55 + c2 * 0.45);

	// Layer 2 nebulare (più sottile, velocità diversa)
	vec2 uv3 = UV * neb_scale * 1.85 + vec2(t * neb_spd * 0.45, -t * neb_spd * 0.68) + vec2(6.1, 2.8);
	float c3  = fbm(uv3);
	float cl2 = smoothstep(neb_thr + 0.08, neb_thr + 0.42, c3) * 0.52;

	float total = cl1 + cl2 * (1.0 - cl1);

	// Vignetta sui bordi per profondità
	float vx = UV.x * (1.0 - UV.x) * 4.0;
	float vy = UV.y * (1.0 - UV.y) * 4.0;
	float vignette = clamp(vx * vy, 0.0, 1.0);
	float dark = 1.0 - (1.0 - vignette) * 0.35;

	COLOR = vec4((base.rgb + neb_col.rgb * total * neb_col.a) * dark, 1.0);
}
"""
	return s


# ══════════════════════════════════════════════════════════════════════════════
#  Stelle — 3 layer di profondità
# ══════════════════════════════════════════════════════════════════════════════

func _generate_stars() -> void:
	var zid: String = current_zone.zone_id if current_zone else "void_black"
	var cfg: Dictionary = ZONE_VIS.get(zid, ZONE_VIS["void_black"])
	var star_col: Color  = cfg["star_col"]
	var total: int       = cfg["star_n"]
	var half: Vector2    = zone_size / 2

	# Layer A: tante stelle piccole (60%)
	for _i in int(total * 0.60):
		var sp := _create_star_sprite(star_col, randf_range(0.8, 2.5), false)
		sp.position = Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		_stars_a.add_child(sp)

	# Layer B: stelle medie con leggero colore (30%)
	for _i in int(total * 0.30):
		var tint := star_col.lerp(Color(randf(), randf(), randf()), 0.15)
		var sp := _create_star_sprite(tint, randf_range(2.0, 4.5), randf() < 0.25)
		sp.position = Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		_stars_b.add_child(sp)

	# Layer C: stelle grandi/luminose con glow (10%)
	for _i in int(total * 0.10):
		var sp := _create_bright_star(star_col)
		sp.position = Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		_stars_c.add_child(sp)


func _create_star_sprite(col: Color, radius: float, twinkle: bool) -> Node2D:
	var star := Sprite2D.new()
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	star.texture = ImageTexture.create_from_image(img)
	star.scale = Vector2.ONE * (radius / 2.0)
	star.modulate = col
	star.modulate.a = randf_range(0.25, 0.85)

	if twinkle:
		var tw := star.create_tween()
		tw.set_loops()
		tw.set_trans(Tween.TRANS_SINE)
		var base_a := star.modulate.a
		tw.tween_property(star, "modulate:a", base_a * 0.30, randf_range(0.6, 2.2))
		tw.tween_property(star, "modulate:a", base_a,         randf_range(0.6, 2.2))
	return star


func _create_bright_star(base_col: Color) -> Node2D:
	# Stella grande con glow a croce (lens flare minimale)
	var n := Node2D.new()
	var bright_col := base_col.lightened(0.5)
	bright_col.a = randf_range(0.65, 1.0)

	# Nucleo
	var core := Sprite2D.new()
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	core.texture = ImageTexture.create_from_image(img)
	var sz := randf_range(2.5, 5.0)
	core.scale = Vector2.ONE * sz
	core.modulate = bright_col
	n.add_child(core)

	# Glow (cerchio semitrasparente disegnato intorno)
	var glow := Sprite2D.new()
	glow.texture = ImageTexture.create_from_image(img)
	glow.scale = Vector2.ONE * sz * 3.5
	glow.modulate = Color(bright_col.r, bright_col.g, bright_col.b, 0.12)
	n.add_child(glow)

	# Twinkle
	var tw := n.create_tween()
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "modulate:a", 0.40, randf_range(1.0, 3.0))
	tw.tween_property(n, "modulate:a", 1.00, randf_range(1.0, 3.0))
	return n


# ══════════════════════════════════════════════════════════════════════════════
#  Decorazioni: pianeti e gas cloud wisps
# ══════════════════════════════════════════════════════════════════════════════

func _generate_decorations() -> void:
	var zid: String = current_zone.zone_id if current_zone else "void_black"
	var cfg: Dictionary = ZONE_VIS.get(zid, ZONE_VIS["void_black"])

	# Gas cloud wisps
	for wdata: Dictionary in cfg.get("wisps", []):
		var wisp := _create_wisp(wdata["r"], wdata["col"])
		wisp.position = wdata["pos"]
		_decor.add_child(wisp)

	# Pianeta (se configurato per questa zona)
	var pdata: Variant = cfg.get("planet", null)
	if pdata != null:
		var planet := _Planet.new()
		planet.planet_radius = pdata["r"]
		planet.body_col      = pdata["col"]
		planet.atm_col       = pdata["atm"]
		planet.has_ring      = pdata["ring"]
		planet.position      = pdata["pos"]
		planet.z_index       = -75

		# Lentissima rotazione atmosferica (visiva, non fisica)
		var tw := planet.create_tween()
		tw.set_loops()
		tw.tween_property(planet, "rotation", TAU, 120.0)
		_decor.add_child(planet)


func _create_wisp(radius: float, col: Color) -> Node2D:
	# Gas cloud: cerchi concentrici semitrasparenti con tween di pulsazione
	var n := Node2D.new()
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	for layer in 5:
		var s := Sprite2D.new()
		s.texture = ImageTexture.create_from_image(img)
		var lr := radius * (1.0 - layer * 0.15)
		s.scale = Vector2.ONE * (lr / 2.0)
		var la := col.a * (1.0 - layer * 0.18)
		s.modulate = Color(col.r, col.g, col.b, la)
		n.add_child(s)

	# Lenta pulsazione
	var tw := n.create_tween()
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "modulate:a", 0.55, randf_range(3.0, 5.5))
	tw.tween_property(n, "modulate:a", 1.00, randf_range(3.0, 5.5))
	return n


# ══════════════════════════════════════════════════════════════════════════════
#  Ostacoli zona-specifici
# ══════════════════════════════════════════════════════════════════════════════

func _generate_obstacles() -> void:
	if not current_zone:
		return
	var density: int  = int(current_zone.obstacle_density * 55)
	var half: Vector2 = zone_size / 2

	for _i in density:
		var pos := Vector2(
			randf_range(-half.x + 120, half.x - 120),
			randf_range(-half.y + 120, half.y - 120))
		if pos.length() < 320.0:
			continue
		var obs := _create_obstacle(pos)
		_obstacles_root.add_child(obs)


func _create_obstacle(pos: Vector2) -> StaticBody2D:
	var zid: String = current_zone.zone_id if current_zone else "void_black"
	var cfg: Dictionary = ZONE_VIS.get(zid, ZONE_VIS["void_black"])
	var style: String = cfg["obs_style"]
	var col: Color    = cfg["obs_col"]

	var body := StaticBody2D.new()
	body.collision_layer = 64
	body.collision_mask  = 0
	body.position = pos
	body.rotation = randf() * TAU

	var sz: float
	var visual: Node2D

	match style:
		"void_rock":
			sz = randf_range(20, 48)
			var r := _Rock.new()
			r.sz = sz; r.col = col.darkened(randf_range(0.0, 0.3)); r.heavy = false
			visual = r

		"heavy_rock":
			sz = randf_range(32, 72)
			var r := _Rock.new()
			r.sz = sz; r.col = col.darkened(randf_range(0.0, 0.25)); r.heavy = true
			visual = r

		"crystal":
			sz = randf_range(18, 42)
			var c := _Crystal.new()
			c.sz = sz
			c.col = col.lerp(Color(1, 1, 1), randf() * 0.20)
			visual = c

		"pylon":
			sz = randf_range(14, 22)
			var p := _Pylon.new()
			p.sz = sz; p.col = col
			visual = p

		"rift_shard":
			sz = randf_range(18, 38)
			var rs := _RiftShard.new()
			rs.sz = sz; rs.col = col
			visual = rs

		_:
			sz = 30.0
			visual = _Rock.new()

	body.add_child(visual)

	# Forma collision (cerchio per semplicità)
	var coll := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = sz * 0.75
	coll.shape = shape
	body.add_child(coll)

	return body


# ══════════════════════════════════════════════════════════════════════════════
#  Animazioni zona-specifiche
# ══════════════════════════════════════════════════════════════════════════════

func _setup_zone_animations() -> void:
	var zid: String = current_zone.zone_id if current_zone else "void_black"
	var cfg: Dictionary = ZONE_VIS.get(zid, ZONE_VIS["void_black"])
	var anim: String = cfg.get("anim", "none")

	match anim:
		"arc_lightning":
			_anim_timer.wait_time = randf_range(0.8, 2.2)
			_anim_timer.timeout.connect(_spawn_arc_lightning)
			_anim_timer.start()

		"glitch_lines":
			_anim_timer.wait_time = randf_range(0.3, 1.1)
			_anim_timer.timeout.connect(_spawn_glitch_line)
			_anim_timer.start()


func _spawn_arc_lightning() -> void:
	if not is_instance_valid(_anim_root):
		return
	var half: Vector2 = zone_size / 2
	var p1 := Vector2(randf_range(-half.x * 0.8, half.x * 0.8),
					  randf_range(-half.y * 0.8, half.y * 0.8))
	var p2 := p1 + Vector2(randf_range(-600, 600), randf_range(-600, 600))
	var col := Color(0.4, 0.9, 1.0, 0.85)

	# Crea linea arco (spezzata per sembrare fulmine)
	var arc := Node2D.new()
	var pts := PackedVector2Array()
	var steps := 12
	for si in steps + 1:
		var t := float(si) / float(steps)
		var bp := p1.lerp(p2, t)
		if si > 0 and si < steps:
			bp += Vector2(randf_range(-50, 50), randf_range(-50, 50))
		pts.append(bp)

	# Disegna con LineShape2D tramite Node2D._draw
	var line_node := _ArcLine.new()
	line_node.pts = pts
	line_node.col = col
	_anim_root.add_child(line_node)

	# Fade out rapido
	var tw := arc.create_tween()
	tw.tween_property(line_node, "modulate:a", 0.0, randf_range(0.08, 0.20))
	tw.tween_callback(line_node.queue_free)

	# Rischedula con intervallo casuale
	_anim_timer.wait_time = randf_range(0.6, 2.0)
	_anim_timer.start()


func _spawn_glitch_line() -> void:
	if not is_instance_valid(_anim_root):
		return
	var half: Vector2 = zone_size / 2
	var y := randf_range(-half.y * 0.9, half.y * 0.9)
	var x1 := randf_range(-half.x, -half.x * 0.3)
	var x2 := randf_range( half.x * 0.3,  half.x)
	var h := randf_range(2.0, 12.0)
	var glitch_col := Color(0.18, 1.0, 0.50, randf_range(0.3, 0.7))

	var rect_node := ColorRect.new()
	rect_node.color = glitch_col
	rect_node.size  = Vector2(x2 - x1, h)
	rect_node.position = Vector2(x1, y - h * 0.5)
	_anim_root.add_child(rect_node)

	var tw := create_tween()
	tw.tween_property(rect_node, "modulate:a", 0.0, randf_range(0.05, 0.18))
	tw.tween_callback(rect_node.queue_free)

	_anim_timer.wait_time = randf_range(0.25, 0.90)
	_anim_timer.start()


# Inner class per disegnare le linee arco fulmine
class _ArcLine extends Node2D:
	var pts: PackedVector2Array
	var col: Color = Color(0.4, 0.9, 1.0)
	func _draw() -> void:
		if pts.size() < 2:
			return
		draw_polyline(pts, Color(1, 1, 1, 0.90), 1.5)
		draw_polyline(pts, col, 3.0)
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.25), 8.0)


# ══════════════════════════════════════════════════════════════════════════════
#  Boundary glow neon per bioma
# ══════════════════════════════════════════════════════════════════════════════

func _generate_boundary_glow() -> void:
	if _boundary_root and is_instance_valid(_boundary_root):
		_boundary_root.queue_free()

	_boundary_root = Node2D.new()
	_boundary_root.name = "BoundaryGlow"
	_boundary_root.z_index = -50
	add_child(_boundary_root)

	var zid: String = current_zone.zone_id if current_zone else "void_black"
	var cfg: Dictionary = ZONE_VIS.get(zid, ZONE_VIS["void_black"])
	var bnd_col: Color = cfg["bnd_col"]

	var half_w: float = zone_size.x / 2.0
	var half_h: float = zone_size.y / 2.0
	var thick: float  = 220.0

	var glow_shader := _create_edge_glow_shader()

	# [position, size, direction]
	var defs: Array = [
		[Vector2(-half_w,            -half_h), Vector2(thick, zone_size.y), 0.0],
		[Vector2(half_w - thick,     -half_h), Vector2(thick, zone_size.y), 1.0],
		[Vector2(-half_w,            -half_h), Vector2(zone_size.x, thick), 2.0],
		[Vector2(-half_w, half_h - thick),     Vector2(zone_size.x, thick), 3.0],
	]
	for d: Array in defs:
		var cr := ColorRect.new()
		cr.position = d[0]
		cr.size     = d[1]
		var mat := ShaderMaterial.new()
		mat.shader  = glow_shader
		mat.set_shader_parameter("edge_color", Color(bnd_col.r, bnd_col.g, bnd_col.b, 0.82))
		mat.set_shader_parameter("direction", d[2])
		cr.material = mat
		_boundary_root.add_child(cr)

		# Pulsing asincrono
		var tw := cr.create_tween()
		tw.set_loops()
		tw.set_trans(Tween.TRANS_SINE)
		tw.tween_property(cr, "modulate:a", 0.35, randf_range(1.3, 2.5))
		tw.tween_property(cr, "modulate:a", 1.00, randf_range(1.3, 2.5))


func _create_edge_glow_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;

uniform vec4  edge_color : source_color = vec4(0.35, 0.15, 1.0, 0.82);
uniform float direction  = 0.0;

void fragment() {
	float t;
	if      (direction < 0.5) t = 1.0 - UV.x;
	else if (direction < 1.5) t = UV.x;
	else if (direction < 2.5) t = 1.0 - UV.y;
	else                       t = UV.y;

	float alpha = pow(t, 1.6) * edge_color.a;
	float neon  = step(0.90, t) * 0.60;
	COLOR = vec4(edge_color.rgb, clamp(alpha + neon, 0.0, 1.0));
}
"""
	return s


# ══════════════════════════════════════════════════════════════════════════════
#  Hazard
# ══════════════════════════════════════════════════════════════════════════════

func _setup_hazards() -> void:
	var timer := Timer.new()
	timer.name = "HazardTimer"
	timer.wait_time = current_zone.hazard_interval
	timer.timeout.connect(_on_hazard_tick)
	_hazards_root.add_child(timer)
	timer.start()


func _on_hazard_tick() -> void:
	if not current_zone or not current_zone.hazard_enabled:
		return
	var hit := 0
	for player in get_tree().get_nodes_in_group("players"):
		if player.has_method("take_damage"):
			player.take_damage(current_zone.hazard_damage * 0.5)
			hit += 1
	if hit > 0:
		hazard_hit.emit(current_zone.hazard_damage * 0.5)


# ══════════════════════════════════════════════════════════════════════════════
#  World bounds (muri invisibili)
# ══════════════════════════════════════════════════════════════════════════════

func _generate_world_bounds() -> void:
	var hw: float     = zone_size.x / 2.0
	var hh: float     = zone_size.y / 2.0
	var thick: float  = 120.0
	var extra: float  = 240.0

	var wall_defs: Array = [
		[Vector2(0.0,  -hh - thick * 0.5), Vector2(zone_size.x + extra, thick)],
		[Vector2(0.0,   hh + thick * 0.5), Vector2(zone_size.x + extra, thick)],
		[Vector2(-hw - thick * 0.5, 0.0),  Vector2(thick, zone_size.y + extra)],
		[Vector2( hw + thick * 0.5, 0.0),  Vector2(thick, zone_size.y + extra)],
	]
	for wd: Array in wall_defs:
		var wall := StaticBody2D.new()
		wall.collision_layer = 64
		wall.collision_mask  = 0
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wd[1]
		col.shape  = shape
		wall.add_child(col)
		wall.position = wd[0]
		add_child(wall)
