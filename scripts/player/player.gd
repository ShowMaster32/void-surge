extends CharacterBody2D
class_name Player
## Player - Personaggio giocabile con supporto co-op (0-3)
## Integra: MetaManager (stats base), EquipmentManager (bonus run),
##           GameManager (co-op synergy), InputManager (multi-device)

signal died(player: Player)
signal health_changed(current: float, max_hp: float)
signal killed_enemy  ## emesso per tracking Plasma Nova

# Colori neon per co-op
const PLAYER_COLORS: Array[Color] = [
	Color(0.0, 1.0, 1.0),  # Cyan   (P1)
	Color(1.0, 0.2, 1.0),  # Magenta(P2)
	Color(0.2, 1.0, 0.2),  # Verde  (P3)
	Color(1.0, 1.0, 0.0),  # Giallo (P4)
]

@export var player_id: int = 0

# Stats base (sovrascritte da apply_meta_stats)
@export_group("Base Stats")
@export var base_max_health: float   = 100.0
@export var base_move_speed: float   = 300.0
@export var base_damage: float       = 20.0
@export var base_fire_rate: float    = 0.15  ## Secondi tra spari
@export var base_crit_chance: float  = 0.05

# Stats finali (calcolate da _recalculate_stats)
var max_health: float
var current_health: float
var move_speed: float
var damage: float
var fire_rate: float
var crit_chance: float

# Bonus da MetaManager
var _meta_damage_reduction: float  = 0.0
var _meta_melee_bonus: float       = 0.0
var _meta_proj_scale: float        = 1.0
var _meta_plasma_nova: bool        = false
var _meta_crit_storm: bool         = false
var _meta_entropy: bool            = false

# Stato giocatore
var is_dead: bool = false
var _invincible: bool = false
var _fire_timer: float = 0.0
var _kills_this_run: int = 0  ## Per Plasma Nova (ogni 10 → AOE)

# Fisica
const ACCELERATION := 1200.0
const FRICTION      := 900.0

@onready var sprite: Sprite2D        = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var muzzle: Marker2D        = $Muzzle
@onready var inv_timer: Timer        = $InvincibilityTimer
@onready var camera: Camera2D        = $Camera2D  # Null in split screen

@export var projectile_scene: PackedScene


func _ready() -> void:
	add_to_group("players")

	# Colore personalizzato per co-op
	if sprite:
		var col := MetaManager.get_active_color() if player_id == 0 \
			else PLAYER_COLORS[clampi(player_id, 0, 3)]
		sprite.modulate = col

	inv_timer.wait_time = 0.5
	inv_timer.one_shot = true
	inv_timer.timeout.connect(_on_inv_timer_timeout)

	# Applica stats da MetaManager + EquipmentManager
	_recalculate_stats()

	current_health = max_health

	# Disabilita camera built-in se SplitScreenManager è attivo
	_check_disable_builtin_camera()

	GameManager.register_player(self)
	GameManager.coop_synergy_active.connect(_on_coop_synergy_changed)
	EquipmentManager.stats_changed.connect(_recalculate_stats)


## Disabilita la Camera2D interna se il SplitScreenManager gestisce le camere
func _check_disable_builtin_camera() -> void:
	if camera == null:
		return
	var ssm := get_tree().get_first_node_in_group("split_screen_manager")
	if ssm and GameManager.player_count > 1:
		camera.enabled = false


# ---------------------------------------------------------------------------
# STATS
# ---------------------------------------------------------------------------
func _recalculate_stats() -> void:
	# 1. Base dal personaggio
	var meta_stats := MetaManager.get_active_stats() if player_id == 0 \
		else _get_default_meta_stats()

	max_health   = meta_stats.get("max_health",    base_max_health)
	move_speed   = meta_stats.get("move_speed",    base_move_speed)
	damage       = base_damage * meta_stats.get("damage_mult", 1.0)
	fire_rate    = base_fire_rate / meta_stats.get("fire_rate_mult", 1.0)
	crit_chance  = meta_stats.get("crit_chance",   base_crit_chance)

	_meta_damage_reduction = meta_stats.get("damage_reduction",   0.0)
	_meta_melee_bonus      = meta_stats.get("melee_damage_bonus", 0.0)
	_meta_proj_scale       = meta_stats.get("projectile_scale",   1.0)
	_meta_plasma_nova      = meta_stats.get("plasma_nova_enabled", false)
	_meta_crit_storm       = meta_stats.get("crit_storm_enabled",  false)
	_meta_entropy          = meta_stats.get("entropy_enabled",     false)

	# 2. Bonus da Equipment (bonus cumulativi della run corrente)
	var eq_stats := EquipmentManager.get_cached_stats()
	damage       += eq_stats.get("damage_bonus",    0.0)
	move_speed   += eq_stats.get("speed_bonus",     0.0)
	fire_rate    = maxf(fire_rate - eq_stats.get("fire_rate_bonus", 0.0), 0.05)
	crit_chance  = minf(crit_chance + eq_stats.get("crit_bonus",   0.0), 0.95)
	max_health   += eq_stats.get("health_bonus",    0.0)

	# Clamp
	move_speed   = maxf(move_speed, 50.0)
	damage       = maxf(damage, 1.0)

	# Aggiorna health corrente proporzionalmente
	if current_health > 0:
		current_health = minf(current_health, max_health)

	health_changed.emit(current_health, max_health)


## Per i player P2-P4 in co-op usiamo stats base (no meta individuale per MVP)
func _get_default_meta_stats() -> Dictionary:
	return {
		"max_health":    100.0,
		"move_speed":    300.0,
		"damage_mult":   1.0,
		"fire_rate_mult": 1.0,
		"crit_chance":   0.05,
		"damage_reduction":   0.0,
		"melee_damage_bonus": 0.0,
		"projectile_scale":   1.0,
	}


## Chiamato da MainController dopo lo spawn, applica colore personaggio
func apply_character_color(char_id: String) -> void:
	if sprite and MetaManager.CHARACTERS.has(char_id):
		sprite.modulate = MetaManager.CHARACTERS[char_id].get("color", Color.CYAN)


# ---------------------------------------------------------------------------
# FISICA & INPUT
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead or GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_handle_movement(delta)
	_handle_shooting(delta)
	move_and_slide()


func _handle_movement(delta: float) -> void:
	var move_vec := InputManager.get_movement_vector(player_id)

	if move_vec.length_squared() > 0.0:
		velocity = velocity.move_toward(move_vec * move_speed, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	if sprite and velocity.x != 0:
		sprite.flip_h = velocity.x < 0


func _handle_shooting(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	if not InputManager.is_shooting(player_id):
		return

	_fire_timer = fire_rate
	_shoot()


func _shoot() -> void:
	if not projectile_scene or not muzzle:
		return

	var aim_dir := InputManager.get_aim_vector(player_id, get_viewport())
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT

	var projectile := projectile_scene.instantiate()
	projectile.global_position = muzzle.global_position
	projectile.rotation = aim_dir.angle()

	# Calcola danno finale con: base + coop synergy + melee bonus + crit
	var final_damage := _calculate_shot_damage()
	var eq_stats := EquipmentManager.get_cached_stats()
	var pierce   := eq_stats.get("pierce_count", 0) as int

	if projectile.has_method("setup"):
		projectile.setup(final_damage, pierce, _meta_proj_scale)

	get_tree().current_scene.add_child(projectile)


func _calculate_shot_damage() -> float:
	var d := damage

	# Co-op synergy bonus (+10% se vicino a partner)
	d *= (1.0 + GameManager.get_coop_damage_bonus())

	# Melee bonus (sentinel) — se c'è un nemico vicino
	if _meta_melee_bonus > 0.0 and _has_nearby_enemy(100.0):
		d *= (1.0 + _meta_melee_bonus)

	# Crit
	var is_crit := randf() < crit_chance
	if is_crit:
		d *= 2.0
		if _meta_crit_storm:
			MetaManager.on_crit_hit()
			d *= (1.0 + MetaManager.get_crit_storm_bonus())
	else:
		if _meta_crit_storm:
			MetaManager.on_non_crit_hit()

	GameManager.add_damage(d)
	return d


func _has_nearby_enemy(radius: float) -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= radius:
			return true
	return false


# ---------------------------------------------------------------------------
# DANNO & MORTE
# ---------------------------------------------------------------------------
func take_damage(amount: float) -> void:
	if is_dead or _invincible:
		return

	# Riduzione danno da talento sentinel
	var reduced := amount * (1.0 - _meta_damage_reduction)
	current_health = maxf(current_health - reduced, 0.0)
	health_changed.emit(current_health, max_health)

	# Flash bianco
	if sprite:
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.05).timeout
		if not is_dead and sprite:
			sprite.modulate = PLAYER_COLORS[clampi(player_id, 0, 3)]

	_invincible = true
	inv_timer.start()

	if current_health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func _die() -> void:
	is_dead = true
	died.emit(self)
	GameManager.unregister_player(self)
	collision.set_deferred("disabled", true)
	if sprite:
		sprite.visible = false


func _on_inv_timer_timeout() -> void:
	_invincible = false


# ---------------------------------------------------------------------------
# CO-OP SYNERGY
# ---------------------------------------------------------------------------
func _on_coop_synergy_changed(active: bool) -> void:
	# Effetto visivo: leggero glow quando synergy attiva
	if sprite:
		var base_col := PLAYER_COLORS[clampi(player_id, 0, 3)]
		sprite.modulate = base_col.lightened(0.25) if active else base_col


# ---------------------------------------------------------------------------
# SPECIALI TALENTI RUNTIME
# ---------------------------------------------------------------------------

## Plasma Nova: ogni 10 kill → AOE
func on_kill() -> void:
	_kills_this_run += 1
	killed_enemy.emit()

	# Entropy: accumula bonus
	if _meta_entropy:
		MetaManager.on_enemy_killed_for_entropy()

	# Plasma Nova
	if _meta_plasma_nova and _kills_this_run % 10 == 0:
		_trigger_plasma_nova()


func _trigger_plasma_nova() -> void:
	## Danno AOE attorno al giocatore
	var nova_radius := 200.0
	var nova_damage := damage * 3.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= nova_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(nova_damage)

	# VFX
	var vfx := get_node_or_null("/root/VFX")
	if vfx:
		vfx.spawn_death_effect(global_position, Color(1.0, 0.5, 0.0))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or \
	   (event is InputEventJoypadButton and
	    event.button_index == JOY_BUTTON_START and
	    event.pressed):
		if player_id == 0 or GameManager.player_count > 1:
			GameManager.toggle_pause()
