extends Area2D
class_name Projectile
## Projectile - Proiettile base del giocatore
## Visuale: cerchio luminoso con gradiente radiale, trail particellare e PointLight2D.
## Il colore evolve dal neon base del giocatore verso tonalità "overcharged" in base al power_level.

@export var speed: float = 800.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0
@export var pierce_count: int = 0  # 0 = si distrugge al primo hit

# Stats aggiunte da equipment
var crit_chance: float = 0.0
var crit_damage: float = 1.5
var burn_damage: float = 0.0
var pierce_damage_mult: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var owner_player_id: int = 0
var enemies_hit: Array[Node2D] = []
var enemies_pierced: int = 0

## Livello di potenza 0–5: controlla colore, dimensione e intensità del glow.
## Impostato da player.gd prima di add_child().
var power_level: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer

# ── Palette colori per giocatore ──────────────────────────────────────────────
# Ogni entry: [colore base (power 0), colore overcharged (power 5)]
const POWER_COLOR_RAMPS: Array = [
	[Color(0.10, 0.95, 1.00), Color(1.00, 0.35, 1.00)],  # P1: cyan → viola-magenta
	[Color(1.00, 0.25, 0.85), Color(1.00, 0.90, 0.25)],  # P2: magenta → oro
	[Color(0.15, 1.00, 0.45), Color(0.20, 0.75, 1.00)],  # P3: verde → blu elettrico
	[Color(1.00, 0.92, 0.10), Color(1.00, 0.48, 0.10)],  # P4: giallo → arancio fuoco
]

# Cache texture globale per riciclo (evita di ricreare l'Image ogni sparo)
static var _glow_tex: ImageTexture = null


func _ready() -> void:
	rotation = direction.angle()
	_build_visuals()

	# Setup lifetime
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot  = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	lifetime_timer.start()

	# Connetti segnale collisione
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


# ══════════════════════════════════════════════
#  Visuale
# ══════════════════════════════════════════════

func _build_visuals() -> void:
	var t_ratio := clampf(power_level / 5.0, 0.0, 1.0)
	var ramp: Array = POWER_COLOR_RAMPS[owner_player_id % POWER_COLOR_RAMPS.size()]
	var col     := (ramp[0] as Color).lerp(ramp[1] as Color, t_ratio)

	# 1. Sprite: cerchio morbido generato via Image (cache globale)
	if _glow_tex == null:
		_glow_tex = _make_glow_texture(32)
	sprite.texture  = _glow_tex
	sprite.modulate = col

	# Scala: cresce leggermente con il power level (1× base, 1.6× al livello 5)
	var s := 1.0 + power_level * 0.12
	sprite.scale = Vector2(s, s)

	# 2. Trail particellare dietro il proiettile
	var trail := GPUParticles2D.new()
	trail.emitting       = true
	trail.amount         = 10 + power_level * 2
	trail.lifetime       = 0.12 + power_level * 0.015
	trail.one_shot       = false
	trail.explosiveness  = 0.0
	trail.local_coords   = false   # world-space: le particelle restano dove emesse
	trail.process_material = _make_trail_material(col)
	add_child(trail)

	# 3. PointLight2D per glow ambientale (scala con power level)
	# Richiede una texture: usiamo lo stesso gradiente radiale del proiettile
	var light := PointLight2D.new()
	light.texture       = _glow_tex
	light.color         = col
	light.energy        = 0.55 + power_level * 0.18
	light.texture_scale = 0.6 + power_level * 0.15
	add_child(light)


## Crea una texture 32×32 con gradiente radiale bianco (riutilizzabile tramite cache)
static func _make_glow_texture(size: int) -> ImageTexture:
	var img    := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.5
	for x in size:
		for y in size:
			var dist  := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var ratio := 1.0 - clampf(dist / radius, 0.0, 1.0)
			# Falloff esponenziale: nucleo molto brillante, bordo sfumato
			var alpha := pow(ratio, 1.4)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)


func _make_trail_material(col: Color) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	# Emissione nella direzione opposta al movimento (world-space, angolo negato)
	var backward := -direction
	m.direction            = Vector3(backward.x, backward.y, 0.0)
	m.spread               = 18.0
	m.initial_velocity_min = 15.0
	m.initial_velocity_max = 45.0
	m.gravity              = Vector3.ZERO
	m.scale_min            = 1.5 + power_level * 0.3
	m.scale_max            = 4.0 + power_level * 0.5
	# Colore con fade-out verso trasparente
	var grad := Gradient.new()
	grad.set_color(0, col)
	grad.add_point(1.0, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient        = grad
	m.color_ramp       = gt
	return m


# ══════════════════════════════════════════════
#  Hit / collisioni
# ══════════════════════════════════════════════

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body not in enemies_hit:
		_hit_enemy(body)


func _on_area_entered(area: Area2D) -> void:
	# Per nemici che usano Area2D invece di CharacterBody2D
	var parent := area.get_parent()
	if parent and parent.is_in_group("enemies") and parent not in enemies_hit:
		_hit_enemy(parent)


func _hit_enemy(enemy: Node2D) -> void:
	enemies_hit.append(enemy)

	# Calcola danno finale
	var final_damage := damage
	var is_crit := false

	# Check crit
	if crit_chance > 0 and randf() < crit_chance:
		final_damage *= crit_damage
		is_crit = true

	# Bonus danno da pierce (Void synergy)
	if enemies_pierced > 0 and pierce_damage_mult > 0:
		final_damage *= (1.0 + pierce_damage_mult * enemies_pierced)

	# Effetto hit (colore proiettile, più caldo per crit)
	if is_instance_valid(VFX):
		var ramp: Array = POWER_COLOR_RAMPS[owner_player_id % POWER_COLOR_RAMPS.size()]
		var proj_col := (ramp[0] as Color).lerp(ramp[1] as Color, clampf(power_level / 5.0, 0.0, 1.0))
		var hit_color := Color(1, 1, 0.5) if is_crit else proj_col
		VFX.spawn_hit_effect(global_position, hit_color)

	# Infliggi danno
	if enemy.has_method("take_damage"):
		enemy.take_damage(final_damage)
		GameManager.add_damage(final_damage)

		# Applica burn (Fire synergy)
		if burn_damage > 0 and enemy.has_method("apply_burn"):
			enemy.apply_burn(burn_damage, 3.0)  # 3 secondi di burn

	# Gestisci pierce
	if pierce_count <= 0:
		_destroy()
	else:
		pierce_count  -= 1
		enemies_pierced += 1


func _on_lifetime_timeout() -> void:
	_destroy()


func _destroy() -> void:
	queue_free()
