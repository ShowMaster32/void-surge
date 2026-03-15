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

# Visual moderno (player_visual.gd)
var _visual: Node2D = null

# Fisica
const ACCELERATION := 1200.0
const FRICTION      := 900.0

@onready var sprite: Sprite2D        = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var muzzle: Marker2D        = $Muzzle
@onready var inv_timer: Timer        = $InvincibilityTimer
@onready var camera: Camera2D        = $Camera2D  # Null in split screen

@export var projectile_scene: PackedScene
## Metà larghezza e altezza del mondo giocabile. Il player non può uscire da questo rettangolo.
## Imposta i valori uguali alle dimensioni della tua arena (metà, perché si misura dal centro).
@export var world_half_size: Vector2 = Vector2(1920, 1080)

# ── POTERI ATTIVABILI ──────────────────────────────────────────────────────────
const POWER_COOLDOWNS: Dictionary = {
	"shield_burst": 8.0,
	"plasma_bomb":  12.0,
	"void_dash":    6.0,
	"time_surge":   18.0,
}
const POWER_NAMES: Dictionary = {
	"shield_burst": "Shield Burst",
	"plasma_bomb":  "Plasma Bomb",
	"void_dash":    "Void Dash",
	"time_surge":   "Time Surge",
}
var _active_power_id: String   = ""
var _power_cooldown_max: float = 0.0
var _power_cooldown: float     = 0.0


func _ready() -> void:
	add_to_group("players")

	var col := MetaManager.get_active_color() if player_id == 0 \
		else PLAYER_COLORS[clampi(player_id, 0, 3)]

	# ── visual moderno: nasconde Sprite2D e usa PlayerVisual ─────────────────
	if sprite:
		sprite.visible = false

	var vis_script = load("res://scripts/visuals/player_visual.gd")
	if vis_script:
		_visual = vis_script.new()
		add_child(_visual)
		_visual.modulate = col
	elif sprite:
		# fallback: usa sprite originale se script non trovato
		sprite.visible = true
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
	EquipmentManager.equipment_stats_changed.connect(_recalculate_stats)

	# ── potere attivabile selezionato nel MetaHub ─────────────────────────────
	_active_power_id    = GameManager.get_meta("active_power", "") as String
	_power_cooldown_max = POWER_COOLDOWNS.get(_active_power_id, 0.0)

	# Registra l'azione "activate_power" se non esiste già nel progetto
	if not InputMap.has_action("activate_power"):
		InputMap.add_action("activate_power")
		var ev_key := InputEventKey.new()
		ev_key.keycode = KEY_E
		InputMap.action_add_event("activate_power", ev_key)


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
	var eq_stats: Dictionary = EquipmentManager.get_all_stats()
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
	_update_visual_rotation()
	move_and_slide()
	_clamp_to_world()

	# Decrementa cooldown potere attivabile
	if _power_cooldown > 0.0:
		_power_cooldown = maxf(_power_cooldown - delta, 0.0)


## Calcola la direzione di mira in modo affidabile per ogni input device.
## • player_id == 0 (keyboard+mouse) : usa get_global_mouse_position() sul nodo.
##   Questo è il metodo CORRETTO in Godot 4 — gestisce automaticamente camera,
##   canvas transform e viewport senza calcoli manuali.
## • player_id > 0 (controller) : legge JOY_AXIS_RIGHT_X/Y dal device associato.
func _get_aim_dir() -> Vector2:
	if player_id == 0:
		# Mouse: calcolo diretto senza passare per InputManager
		var mouse_world := get_global_mouse_position()
		var dir := mouse_world - global_position
		if dir.length_squared() > 4.0:   # soglia 2px per evitare jitter
			return dir.normalized()
		return Vector2.RIGHT
	else:
		# Controller: stick destro tramite device associato a questo player_id
		var device_id: int = InputManager.player_to_device.get(player_id, 0)
		var x := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
		var y := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
		var vec := Vector2(x, y)
		if vec.length() > 0.28:
			return vec.normalized()
		# Fallback: direzione di movimento se stick non usato
		if velocity.length_squared() > 10.0:
			return velocity.normalized()
		return Vector2.RIGHT


## Impedisce al player di uscire dall'arena.
## world_half_size definisce il raggio del mondo partendo dal centro (0,0).
## Adatta world_half_size nel Inspector alla dimensione reale della tua arena.
func _clamp_to_world() -> void:
	global_position.x = clampf(global_position.x, -world_half_size.x, world_half_size.x)
	global_position.y = clampf(global_position.y, -world_half_size.y, world_half_size.y)


func _update_visual_rotation() -> void:
	## Ruota il visual della nave verso la direzione di mira
	if _visual == null:
		return
	_visual.rotation = _get_aim_dir().angle()


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


## ──────────────────────────────────────────────────────────────────────────────
## _shoot  — GODOT 4 FIX  (v8)
##
## CAUSA DEL BUG "spara sempre a destra":
##   add_child() in Godot 4 è SINCRONO: chiama _ready() del proiettile
##   *immediatamente*, prima di ritornare al chiamante.
##   Se il proiettile fa in _ready():
##       velocity = Vector2(speed, 0)   # hardcoded RIGHT
##   questo sovrascrive rotation e posizione che avevamo impostato.
##
## FIX 1 — posizione spawn:
##   global_position + aim_dir * spawn_dist
##   (NON muzzle.global_position: in Godot 4 il Marker2D ha la posizione
##    nello spazio locale del Player — se il Player non ruota, punta sempre
##    a destra nel world space)
##
## FIX 2 — velocity override DOPO add_child():
##   Dopo add_child() _ready() del proiettile è già terminata.
##   Leggiamo la velocità scalare (norma del vettore) e sostituiamo
##   la direzione con aim_dir, preservando la velocità.
## ──────────────────────────────────────────────────────────────────────────────
func _shoot() -> void:
	if not projectile_scene:
		return

	var aim_dir := _get_aim_dir()

	# Distanza di spawn dal centro del player (default 24px)
	var spawn_dist := 24.0
	if muzzle:
		var ml := muzzle.position.length()
		if ml > 4.0:
			spawn_dist = ml

	var projectile := projectile_scene.instantiate()

	# Spawn nella direzione di mira, non dalla posizione locale del Muzzle
	projectile.global_position = global_position + aim_dir * spawn_dist
	projectile.rotation        = aim_dir.angle()

	# FIX DEFINITIVO — il proiettile usa "direction * speed * delta" in _physics_process
	# e in _ready() fa: rotation = direction.angle()
	# → va impostata PRIMA di add_child() così _ready() legge già aim_dir
	if "direction" in projectile:
		projectile.direction = aim_dir

	var final_damage := _calculate_shot_damage()
	var eq_stats: Dictionary = EquipmentManager.get_all_stats()
	var pierce: int = eq_stats.get("pierce_count", 0) as int

	if projectile.has_method("setup"):
		projectile.setup(final_damage, pierce, _meta_proj_scale)

	# Imposta danno e pierce direttamente se non c'è setup()
	if "damage" in projectile:
		projectile.damage = final_damage
	if "pierce_count" in projectile and pierce > 0:
		projectile.pierce_count = pierce

	# add_child chiama _ready() del proiettile subito (sincrono in Godot 4)
	get_tree().current_scene.add_child(projectile)

	# Sicurezza: override direction anche dopo _ready() (nel caso _ready() la resetti)
	if "direction" in projectile:
		projectile.direction = aim_dir


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

	# Flash bianco (sul visual, oppure sullo sprite fallback)
	var flash_target: Node2D = _visual if _visual != null else sprite
	if flash_target:
		flash_target.modulate = Color.WHITE
		await get_tree().create_timer(0.05).timeout
		if not is_dead and flash_target:
			flash_target.modulate = PLAYER_COLORS[clampi(player_id, 0, 3)]

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
	if _visual:
		_visual.visible = false
	elif sprite:
		sprite.visible = false


func _on_inv_timer_timeout() -> void:
	_invincible = false


# ---------------------------------------------------------------------------
# CO-OP SYNERGY
# ---------------------------------------------------------------------------
func _on_coop_synergy_changed(active: bool) -> void:
	# Effetto visivo: leggero glow quando synergy attiva
	var vis_target: Node2D = _visual if _visual != null else sprite
	if vis_target:
		var base_col := PLAYER_COLORS[clampi(player_id, 0, 3)]
		vis_target.modulate = base_col.lightened(0.25) if active else base_col


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


# ---------------------------------------------------------------------------
# INPUT (pausa + potere attivabile)
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	# Pausa: Escape oppure Start sul controller
	if event.is_action_pressed("ui_cancel") or \
	   (event is InputEventJoypadButton and
		event.button_index == JOY_BUTTON_START and
		event.pressed):
		if player_id == 0 or GameManager.player_count > 1:
			GameManager.toggle_pause()

	# Potere attivabile: tasto E (keyboard) oppure Y (controller)
	if is_dead or _active_power_id.is_empty():
		return
	var is_e: bool = event.is_action_pressed("activate_power")
	var is_y: bool = (event is InputEventJoypadButton and
				 event.button_index == JOY_BUTTON_Y and event.pressed)
	if is_e or is_y:
		_use_power()


# ---------------------------------------------------------------------------
# SISTEMA POTERI ATTIVABILI
# ---------------------------------------------------------------------------

## Restituisce il cooldown normalizzato [0..1] — 0 = pronto, 1 = appena usato
## Usato dall'HUD per la barra cooldown
func get_power_cooldown_ratio() -> float:
	if _power_cooldown_max <= 0.0:
		return 0.0
	return clampf(_power_cooldown / _power_cooldown_max, 0.0, 1.0)


## Restituisce il nome leggibile del potere attivo (o "" se nessuno)
func get_active_power_name() -> String:
	return POWER_NAMES.get(_active_power_id, "")


func _use_power() -> void:
	if _power_cooldown > 0.0 or _active_power_id.is_empty():
		return

	match _active_power_id:
		"shield_burst": _power_shield_burst()
		"plasma_bomb":  _power_plasma_bomb()
		"void_dash":    _power_void_dash()
		"time_surge":   _power_time_surge()

	_power_cooldown = _power_cooldown_max


## Shield Burst — scudo impenetrabile per 1.5 secondi + flash bianco
func _power_shield_burst() -> void:
	_invincible = true
	inv_timer.stop()

	var vis: Node2D = _visual if _visual != null else sprite
	if vis:
		vis.modulate = Color(1.5, 1.5, 2.5)
		var tw := create_tween()
		tw.tween_property(vis, "modulate",
			PLAYER_COLORS[clampi(player_id, 0, 3)], 1.5)

	await get_tree().create_timer(1.5).timeout
	if not is_dead:
		_invincible = false


## Plasma Bomb — esplode con danno AOE (5× danno) in raggio 250px
func _power_plasma_bomb() -> void:
	var radius     := 250.0
	var bomb_dmg   := damage * 5.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(bomb_dmg)

	var vfx := get_node_or_null("/root/VFX")
	if vfx and vfx.has_method("spawn_death_effect"):
		vfx.spawn_death_effect(global_position, Color(0.8, 0.2, 1.0))


## Void Dash — scatto rapido (6× move_speed) nella direzione di mira,
##             invincibile per 0.25 s durante lo scatto
func _power_void_dash() -> void:
	var dash_dir := _get_aim_dir()
	if velocity.length_squared() > 10.0:
		dash_dir = velocity.normalized()

	velocity   = dash_dir * move_speed * 6.0
	_invincible = true

	await get_tree().create_timer(0.25).timeout
	if not is_dead:
		_invincible = false


## Time Surge — rallenta tutti i nemici al 25% della velocità per 4 secondi
## enemy.gd legge GameManager.get_meta("time_surge_active") in _move_toward_target
func _power_time_surge() -> void:
	GameManager.set_meta("time_surge_active", true)

	var vfx := get_node_or_null("/root/VFX")
	if vfx and vfx.has_method("spawn_death_effect"):
		vfx.spawn_death_effect(global_position, Color(0.2, 0.8, 1.0))

	await get_tree().create_timer(4.0).timeout
	if GameManager.has_meta("time_surge_active"):
		GameManager.remove_meta("time_surge_active")
