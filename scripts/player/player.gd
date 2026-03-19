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

# ── POTERI ATTIVABILI (slot Q + slot E) ───────────────────────────────────────
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
# Slot Q (tasto Q / JOY X)
var _power_q: String    = ""
var _cd_max_q: float    = 0.0
var _cd_q: float        = 0.0
# Slot E (tasto E / JOY Y)
var _power_e: String    = ""
var _cd_max_e: float    = 0.0
var _cd_e: float        = 0.0
# Pierce bonus da arma attiva
var _weapon_pierce_bonus: int = 0
var _last_aim_dir: Vector2 = Vector2.ZERO   # ultima dir valida stick destro (controller)
## Livello visivo proiettile 0–5, ricalcolato in _recalculate_stats()
var _power_level: int = 0

# ── Moduli nave ────────────────────────────────────────────────────────────────
var _turret_dirs:       int   = 0
var _turret_interval:   float = 0.0
var _turret_dmg_mult:   float = 0.0
var _turret_timer:      float = 0.0

var _missile_count:     int   = 0
var _missile_interval:  float = 0.0
var _missile_dmg_mult:  float = 0.0
var _missile_timer:     float = 0.0

var _orb_count:         int   = 0
var _orb_dmg_mult:      float = 0.0
var _orb_angle:         float = 0.0
var _orb_nodes:         Array = []
var _orb_cd:            Array = []     # cooldown hit per orb (evita danno ogni frame)

var _drone_count:       int   = 0
var _drone_interval:    float = 0.0
var _drone_timer:       float = 0.0
var _drone_nodes:       Array = []

# ── Sprint Boost (L2/LT — sempre disponibile, no acquisto) ────────────────────
const BOOST_DURATION:   float = 0.70   ## secondi di velocità aumentata
const BOOST_SPEED_MULT: float = 2.20   ## moltiplicatore velocità durante boost
const BOOST_COOLDOWN:   float = 5.00   ## secondi di ricarica dopo uso
var _boost_timer: float = 0.0          ## tempo rimanente del boost attivo
var _boost_cd:    float = 0.0          ## cooldown rimanente prima del prossimo uso

var _applied_module_levels: Dictionary = {}   # cache per evitare ricreazione inutile
var _turret_visual:  Node2D = null            # icona rotante torretta
var _missile_visual: Node2D = null            # icona missili (lampeggia al fuoco)
var _missile_visual_t: float = 0.0            # oscillazione cosmetica


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

	# ── poteri attivabili: Q = slot 1, E = slot 2 ───────────────────────────
	_power_q  = GameManager.get_meta("active_power_q", "") as String
	_cd_max_q = POWER_COOLDOWNS.get(_power_q, 0.0)
	_power_e  = GameManager.get_meta("active_power_e", "") as String
	_cd_max_e = POWER_COOLDOWNS.get(_power_e, 0.0)

	# Compatibilità con vecchio meta "active_power" (solo E)
	if _power_e.is_empty() and GameManager.has_meta("active_power"):
		_power_e  = GameManager.get_meta("active_power") as String
		_cd_max_e = POWER_COOLDOWNS.get(_power_e, 0.0)

	if not InputMap.has_action("activate_power_q"):
		InputMap.add_action("activate_power_q")
		var ev_q := InputEventKey.new()
		ev_q.keycode = KEY_Q
		InputMap.action_add_event("activate_power_q", ev_q)
	if not InputMap.has_action("activate_power_e"):
		InputMap.add_action("activate_power_e")
		var ev_e := InputEventKey.new()
		ev_e.keycode = KEY_E
		InputMap.action_add_event("activate_power_e", ev_e)


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

	# 3. Bonus da Shop (acquistati durante la run, salvati in GameManager metadata)
	#    damage_pct = moltiplicatore %  |  speed/fire_rate/crit/health = valori flat
	#    cdr_bonus  = riduzione cooldown poteri (0.0–0.75)
	var _shop_cdr: float = 0.0
	if GameManager.has_meta("shop_bonuses"):
		var sb: Dictionary = GameManager.get_meta("shop_bonuses") as Dictionary
		damage      *= 1.0 + sb.get("damage_pct",       0.0)
		move_speed  += sb.get("speed_bonus",             0.0)
		fire_rate    = maxf(fire_rate - sb.get("fire_rate_bonus", 0.0), 0.05)
		crit_chance  = minf(crit_chance + sb.get("crit_bonus",   0.0), 0.95)
		max_health  += sb.get("health_bonus",            0.0)
		_shop_cdr    = clampf(sb.get("cdr_bonus", 0.0), 0.0, 0.75)

	# 3.5  Bonus PERMANENTI da shop post-run (MetaManager.perm_upgrades)
	#      Ogni punto acquistato aggiunge un'unità fissa di bonus.
	var pu: Dictionary = MetaManager.perm_upgrades
	max_health  += pu.get("perm_hp",    0) * 10.0
	move_speed  += pu.get("perm_speed", 0) * 20.0
	damage      *= 1.0 + pu.get("perm_dmg",  0) * 0.05
	crit_chance  = minf(crit_chance + pu.get("perm_crit", 0) * 0.03, 0.95)
	fire_rate    = maxf(fire_rate   - pu.get("perm_fr",   0) * 0.025, 0.05)

	# 3.6  Moduli nave permanenti — riconfigura solo se i livelli sono cambiati
	apply_modules()

	# 3.7  Poteri attivabili — aggiorna slot se cambiati; applica CDR ad ogni ricalcolo
	var new_pq := GameManager.get_meta("active_power_q", "") as String
	if new_pq != _power_q:
		_power_q = new_pq
		_cd_q    = 0.0   # cooldown azzerato al cambio potere
	_cd_max_q = POWER_COOLDOWNS.get(_power_q, 0.0) * (1.0 - _shop_cdr)
	_cd_q     = minf(_cd_q, _cd_max_q)   # mai superiore al nuovo max

	var new_pe := GameManager.get_meta("active_power_e", "") as String
	if new_pe != _power_e:
		_power_e = new_pe
		_cd_e    = 0.0
	_cd_max_e = POWER_COOLDOWNS.get(_power_e, 0.0) * (1.0 - _shop_cdr)
	_cd_e     = minf(_cd_e, _cd_max_e)

	# Compatibilità backward con vecchio meta "active_power" (solo E)
	if _power_e.is_empty() and GameManager.has_meta("active_power"):
		var legacy := GameManager.get_meta("active_power") as String
		if legacy != _power_e:
			_power_e  = legacy
			_cd_e     = 0.0
		_cd_max_e = POWER_COOLDOWNS.get(_power_e, 0.0) * (1.0 - _shop_cdr)
		_cd_e     = minf(_cd_e, _cd_max_e)

	# 4. Modificatori arma attiva
	_weapon_pierce_bonus = 0
	var _wid: String = GameManager.get_meta("active_weapon", "") as String
	match _wid:
		"rapid":
			fire_rate = maxf(fire_rate * 0.55, 0.05)
			damage   *= 0.72
		"heavy":
			fire_rate            *= 1.75
			damage               *= 2.8
			_weapon_pierce_bonus  = 2
		"spread":
			damage *= 0.82
		"twin":
			damage *= 0.88
		"void_seeker":
			damage *= 1.20

	# Penalità Hardcore: -25% HP massimi
	if GameManager.game_mode == "hardcore":
		max_health *= 0.75

	# Clamp
	move_speed   = maxf(move_speed, 50.0)
	damage       = maxf(damage, 1.0)
	max_health   = maxf(max_health, 20.0)

	# Aggiorna health corrente proporzionalmente
	if current_health > 0:
		current_health = minf(current_health, max_health)

	# Power level visivo proiettili: 0 = base, 5 = massimo
	# Ogni raddoppio del danno rispetto al base aggiunge ~2.5 livelli
	_power_level = clamp(int((damage / maxf(base_damage, 1.0) - 1.0) * 2.5), 0, 5)

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

	if _cd_q > 0.0: _cd_q = maxf(_cd_q - delta, 0.0)
	if _cd_e > 0.0: _cd_e = maxf(_cd_e - delta, 0.0)

	# Boost L2: decay timer e cooldown
	if _boost_timer > 0.0: _boost_timer = maxf(_boost_timer - delta, 0.0)
	if _boost_cd    > 0.0: _boost_cd    = maxf(_boost_cd    - delta, 0.0)
	_check_boost_input()

	_tick_modules(delta)


## Calcola la direzione di mira in modo affidabile per ogni input device.
## • player_id == 0 (keyboard+mouse) : usa get_global_mouse_position() sul nodo.
##   Questo è il metodo CORRETTO in Godot 4 — gestisce automaticamente camera,
##   canvas transform e viewport senza calcoli manuali.
## • player_id > 0 (controller) : legge JOY_AXIS_RIGHT_X/Y dal device associato.
func _get_aim_dir() -> Vector2:
	# Controlla il DEVICE reale per questo player (non player_id).
	# Con controller connesso come P1, device_id ≠ KEYBOARD_MOUSE_DEVICE
	# anche se player_id == 0.
	var device_id: int = InputManager.player_to_device.get(
		player_id, InputManager.KEYBOARD_MOUSE_DEVICE)

	# FIX: se P0 risulta ancora keyboard/mouse ma c'è un controller connesso,
	# usa il primo joypad disponibile (es. controller connesso dopo l'avvio)
	if device_id == InputManager.KEYBOARD_MOUSE_DEVICE:
		var pads := Input.get_connected_joypads()
		if not pads.is_empty():
			device_id = pads[0]

	if device_id == InputManager.KEYBOARD_MOUSE_DEVICE:
		# ── Mouse ───────────────────────────────────────────────────────────
		# get_global_mouse_position() in Godot 4 gestisce automaticamente
		# camera, viewport e canvas transform.
		var mouse_world := get_global_mouse_position()
		var dir := mouse_world - global_position
		if dir.length_squared() > 4.0:   # soglia 2px per evitare jitter
			return dir.normalized()
		return Vector2.RIGHT
	else:
		# ── Controller: stick destro ─────────────────────────────────────────
		var rx := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
		var stick := Vector2(rx, ry)
		if stick.length() > 0.20:   # deadzone stick destro
			_last_aim_dir = stick.normalized()
			return _last_aim_dir
		# Stick destro inattivo: mantieni ultima direzione valida
		# (evita che la nave torni di scatto a Vector2.RIGHT)
		if _last_aim_dir != Vector2.ZERO:
			return _last_aim_dir
		# Fallback finale: direzione di movimento
		if velocity.length_squared() > 10.0:
			return velocity.normalized()
		return Vector2.RIGHT


## Impedisce al player di uscire dall'arena.
## world_half_size definisce il raggio del mondo partendo dal centro (0,0).
## Adatta world_half_size nel Inspector alla dimensione reale della tua arena.
func _clamp_to_world() -> void:
	## Mantiene il player entro i bordi visibili dello schermo.
	## Calcola i limiti reali in unità mondo a partire dal viewport e dallo zoom
	## della Camera2D: così i bordi coincidono esattamente con lo schermo,
	## indipendentemente dalla risoluzione.
	var cam := get_node_or_null("Camera2D") as Camera2D
	var zoom := cam.zoom if cam != null else Vector2(1.5, 1.5)
	var vp_size := get_viewport().get_visible_rect().size
	# Margine pari al raggio del collider (16 px) + 4 px sicurezza
	const MARGIN := 20.0
	var hw := (vp_size.x * 0.5 / zoom.x) - MARGIN
	var hh := (vp_size.y * 0.5 / zoom.y) - MARGIN
	global_position.x = clampf(global_position.x, -hw, hw)
	global_position.y = clampf(global_position.y, -hh, hh)


func _update_visual_rotation() -> void:
	## Ruota il visual della nave verso la direzione di mira
	if _visual == null:
		return
	_visual.rotation = _get_aim_dir().angle()


func _handle_movement(delta: float) -> void:
	var move_vec := InputManager.get_movement_vector(player_id)
	var cur_speed := move_speed * (BOOST_SPEED_MULT if _boost_timer > 0.0 else 1.0)

	if move_vec.length_squared() > 0.0:
		velocity = velocity.move_toward(move_vec * cur_speed, ACCELERATION * delta)
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
	var spawn_dist := 24.0
	if muzzle:
		var ml := muzzle.position.length()
		if ml > 4.0:
			spawn_dist = ml

	var final_damage := _calculate_shot_damage()
	var eq_stats: Dictionary = EquipmentManager.get_all_stats()
	var pierce: int = eq_stats.get("pierce_count", 0) as int
	if GameManager.has_meta("shop_pierce"):
		pierce += GameManager.get_meta("shop_pierce") as int
	pierce += _weapon_pierce_bonus

	var weapon_id: String = GameManager.get_meta("active_weapon", "") as String
	match weapon_id:
		"spread":
			_spawn_proj(aim_dir.rotated(-deg_to_rad(15.0)), final_damage, pierce, spawn_dist)
			_spawn_proj(aim_dir,                            final_damage, pierce, spawn_dist)
			_spawn_proj(aim_dir.rotated( deg_to_rad(15.0)), final_damage, pierce, spawn_dist)
		"twin":
			var perp := aim_dir.rotated(deg_to_rad(90.0)) * 12.0
			_spawn_proj(aim_dir, final_damage, pierce, spawn_dist,  perp)
			_spawn_proj(aim_dir, final_damage, pierce, spawn_dist, -perp)
		"void_seeker":
			_spawn_proj(_get_seek_dir(aim_dir), final_damage, pierce, spawn_dist)
		_:
			_spawn_proj(aim_dir, final_damage, pierce, spawn_dist)


func _spawn_proj(dir: Vector2, dmg: float, pierce: int,
		spawn_dist: float, offset: Vector2 = Vector2.ZERO) -> void:
	var p := projectile_scene.instantiate()
	p.global_position = global_position + dir * spawn_dist + offset
	p.rotation        = dir.angle()
	if "direction" in p:
		p.direction = dir
	if "damage" in p:
		p.damage = dmg
	if "pierce_count" in p and pierce > 0:
		p.pierce_count = pierce
	if "owner_player_id" in p:
		p.owner_player_id = player_id
	if "power_level" in p:
		p.power_level = _power_level
	if p.has_method("setup"):
		p.setup(dmg, pierce, _meta_proj_scale)
	get_tree().current_scene.add_child(p)
	# Override dopo _ready() (Godot 4: add_child è sincrono)
	if "direction" in p:
		p.direction = dir


## Void Seeker: punta il nemico più vicino entro 400px
func _get_seek_dir(default_dir: Vector2) -> Vector2:
	var nearest_dist := 400.0
	var nearest_dir  := default_dir
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_dir  = (enemy.global_position - global_position).normalized()
	return nearest_dir


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


## L2/LT = Sprint Boost — sempre disponibile, no acquisto richiesto.
## Durata BOOST_DURATION secondi a ×BOOST_SPEED_MULT velocità, poi CD BOOST_COOLDOWN s.
func _check_boost_input() -> void:
	var device_id: int = InputManager.player_to_device.get(
		player_id, InputManager.KEYBOARD_MOUSE_DEVICE)
	if device_id == InputManager.KEYBOARD_MOUSE_DEVICE:
		return
	# L2/LT = JOY_AXIS_TRIGGER_LEFT
	if Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_LEFT) > 0.5 \
			and _boost_cd <= 0.0 and _boost_timer <= 0.0:
		_boost_timer = BOOST_DURATION
		_boost_cd    = BOOST_COOLDOWN
		# Flash azzurro breve per feedback visivo
		var vis: Node2D = _visual if _visual != null else sprite
		if vis:
			var tw := create_tween()
			tw.tween_property(vis, "modulate", Color(0.6, 1.0, 2.5, 1.0), 0.05)
			tw.tween_property(vis, "modulate",
				PLAYER_COLORS[clampi(player_id, 0, 3)], BOOST_DURATION)


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
			# FIX: marca l'evento come gestito così non raggiunge pause_menu._unhandled_input
			# (che altrimenti trova is_paused=true e riprende subito il gioco)
			get_viewport().set_input_as_handled()

	# Poteri: Q / L1 (LB) = slot 1    E / R1 (RB) = slot 2
	# Guard: L1/R1 vengono usati per switchare tab nello shop → attiva poteri
	# SOLO quando si è effettivamente in gioco (state == PLAYING).
	if not is_dead and GameManager.current_state == GameManager.GameState.PLAYING:
		var is_q_kb:  bool = event.is_action_pressed("activate_power_q")
		var is_q_joy: bool = (event is InputEventJoypadButton and
			(event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER and
			(event as InputEventJoypadButton).pressed)
		var is_e_kb:  bool = event.is_action_pressed("activate_power_e")
		var is_e_joy: bool = (event is InputEventJoypadButton and
			(event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER and
			(event as InputEventJoypadButton).pressed)
		if is_q_kb or is_q_joy: _try_activate_q()
		if is_e_kb or is_e_joy: _try_activate_e()


# ---------------------------------------------------------------------------
# SISTEMA POTERI ATTIVABILI
# ---------------------------------------------------------------------------

## API pubblica per l'HUD ──────────────────────────────────────────────────
func get_power_q_name() -> String:      return POWER_NAMES.get(_power_q, "")
func get_power_e_name() -> String:      return POWER_NAMES.get(_power_e, "")
func get_cd_ratio_q()   -> float:
	return 0.0 if _cd_max_q <= 0.0 else clampf(_cd_q / _cd_max_q, 0.0, 1.0)
func get_cd_ratio_e()   -> float:
	return 0.0 if _cd_max_e <= 0.0 else clampf(_cd_e / _cd_max_e, 0.0, 1.0)
# Alias backward-compat con HUD vecchio
func get_active_power_name()    -> String: return get_power_e_name()
func get_power_cooldown_ratio() -> float:  return get_cd_ratio_e()


func _try_activate_q() -> void:
	if _cd_q > 0.0 or _power_q.is_empty():
		return
	_execute_power(_power_q)
	_cd_q = _cd_max_q


func _try_activate_e() -> void:
	if _cd_e > 0.0 or _power_e.is_empty():
		return
	_execute_power(_power_e)
	_cd_e = _cd_max_e


func _execute_power(power_id: String) -> void:
	match power_id:
		"shield_burst": _power_shield_burst()
		"plasma_bomb":  _power_plasma_bomb()
		"void_dash":    _power_void_dash()
		"time_surge":   _power_time_surge()


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


# ══════════════════════════════════════════════
#  MODULI NAVE
# ══════════════════════════════════════════════

## Chiamato da _recalculate_stats() e dal shop dopo l'acquisto.
## Riconfigura i moduli solo se i livelli sono cambiati (cache).
func apply_modules() -> void:
	var pu := MetaManager.perm_upgrades
	var new_levels := {
		"module_turret":     pu.get("module_turret",     0) as int,
		"module_missile":    pu.get("module_missile",    0) as int,
		"module_shield_orb": pu.get("module_shield_orb", 0) as int,
		"module_drone":      pu.get("module_drone",      0) as int,
	}
	if new_levels == _applied_module_levels:
		return
	_applied_module_levels = new_levels

	# ── Torretta ──────────────────────────────────────────────────────────────
	match new_levels["module_turret"]:
		1: _turret_dirs = 8;  _turret_interval = 3.0; _turret_dmg_mult = 0.30
		2: _turret_dirs = 8;  _turret_interval = 2.0; _turret_dmg_mult = 0.35
		3: _turret_dirs = 16; _turret_interval = 1.5; _turret_dmg_mult = 0.40
		_: _turret_dirs = 0;  _turret_interval = 0.0; _turret_dmg_mult = 0.0
	_turret_timer = 0.0
	_setup_turret_visual(new_levels["module_turret"])

	# ── Missile ───────────────────────────────────────────────────────────────
	match new_levels["module_missile"]:
		1: _missile_count = 1; _missile_interval = 8.0; _missile_dmg_mult = 2.0
		2: _missile_count = 2; _missile_interval = 5.0; _missile_dmg_mult = 2.5
		_: _missile_count = 0; _missile_interval = 0.0; _missile_dmg_mult = 0.0
	_missile_timer = 0.0
	_setup_missile_visual(new_levels["module_missile"])

	# ── Orb scudo ─────────────────────────────────────────────────────────────
	_setup_orbs(new_levels["module_shield_orb"])

	# ── Drone ─────────────────────────────────────────────────────────────────
	_setup_drones(new_levels["module_drone"])


# ── Setup orb ─────────────────────────────────────────────────────────────────

func _setup_orbs(level: int) -> void:
	for orb: Node in _orb_nodes:
		if is_instance_valid(orb):
			orb.queue_free()
	_orb_nodes.clear()
	_orb_cd.clear()

	match level:
		1: _orb_count = 2; _orb_dmg_mult = 0.50
		2: _orb_count = 3; _orb_dmg_mult = 0.75
		3: _orb_count = 4; _orb_dmg_mult = 1.00
		_: _orb_count = 0; _orb_dmg_mult = 0.0

	for _i in _orb_count:
		var orb := Node2D.new()
		# "●" ciano con outline neon — simula una sfera luminosa
		var lbl := Label.new()
		lbl.text = "●"
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color",         Color(0.25, 0.92, 1.00, 0.95))
		lbl.add_theme_constant_override("outline_size",    4)
		lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.60, 1.00, 0.70))
		lbl.position = Vector2(-10, -12)
		orb.add_child(lbl)
		add_child(orb)
		_orb_nodes.append(orb)
		_orb_cd.append(0.0)


# ── Setup droni ───────────────────────────────────────────────────────────────

func _setup_drones(level: int) -> void:
	for dn: Node in _drone_nodes:
		if is_instance_valid(dn):
			dn.queue_free()
	_drone_nodes.clear()

	match level:
		1: _drone_count = 1; _drone_interval = 1.5
		2: _drone_count = 2; _drone_interval = 0.8
		_: _drone_count = 0; _drone_interval = 0.0
	_drone_timer = 0.0

	for _i in _drone_count:
		var dn := Node2D.new()
		# "◆" oro con outline ambrato — drone romboide ben visibile
		var lbl := Label.new()
		lbl.text = "◆"
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color",         Color(1.00, 0.85, 0.10, 0.95))
		lbl.add_theme_constant_override("outline_size",    3)
		lbl.add_theme_color_override("font_outline_color", Color(0.90, 0.45, 0.00, 0.75))
		lbl.position = Vector2(-8, -10)
		dn.add_child(lbl)
		add_child(dn)
		_drone_nodes.append(dn)


# ── Tick moduli (chiamato ogni physics frame) ─────────────────────────────────

func _tick_modules(delta: float) -> void:
	# Torretta
	if _turret_dirs > 0:
		_turret_timer += delta
		if _turret_timer >= _turret_interval:
			_turret_timer = 0.0
			_fire_turret()

	# Missile
	if _missile_count > 0:
		_missile_timer += delta
		if _missile_timer >= _missile_interval:
			_missile_timer = 0.0
			_fire_missiles()

	# Torretta: ruota il visual lentamente
	if _turret_visual and is_instance_valid(_turret_visual):
		_turret_visual.rotation += delta * 1.8

	# Missile: oscillazione verticale cosmetica (bob su-giù) + carica colore
	if _missile_visual and is_instance_valid(_missile_visual):
		_missile_visual_t += delta * 3.0
		_missile_visual.position.y = 28.0 + sin(_missile_visual_t) * 2.5
		# Diventa più luminoso man mano che il cooldown si avvicina allo sparo
		if _missile_interval > 0.0:
			var charge := clampf(_missile_timer / _missile_interval, 0.0, 1.0)
			_missile_visual.modulate = Color(1.0, 1.0, 1.0, 0.55 + charge * 0.45)

	# Orb: orbita + danni da contatto
	_update_orbs(delta)

	# Droni: orbita + sparo
	_update_drones(delta)


# ── Visual torretta ───────────────────────────────────────────────────────────

func _setup_turret_visual(level: int) -> void:
	if _turret_visual and is_instance_valid(_turret_visual):
		_turret_visual.queue_free()
	_turret_visual = null
	if level == 0:
		return

	_turret_visual = Node2D.new()
	_turret_visual.position = Vector2(0, -26)

	var body_lbl := Label.new()
	body_lbl.text = "⊕"
	body_lbl.add_theme_font_size_override("font_size", 18)
	body_lbl.add_theme_color_override("font_color",         Color(1.00, 0.52, 0.20, 0.95))
	body_lbl.add_theme_constant_override("outline_size",    3)
	body_lbl.add_theme_color_override("font_outline_color", Color(0.80, 0.20, 0.00, 0.80))
	body_lbl.position = Vector2(-9, -10)
	_turret_visual.add_child(body_lbl)

	for i in level:
		var dot := Label.new()
		dot.text = "▪"
		dot.add_theme_font_size_override("font_size", 9)
		dot.add_theme_color_override("font_color", Color(1.00, 0.52, 0.20, 0.80))
		dot.position = Vector2(-6 + i * 8, 6)
		_turret_visual.add_child(dot)

	add_child(_turret_visual)


# ── Visual missili ────────────────────────────────────────────────────────────

func _setup_missile_visual(level: int) -> void:
	if _missile_visual and is_instance_valid(_missile_visual):
		_missile_visual.queue_free()
	_missile_visual = null
	_missile_visual_t = 0.0
	if level == 0:
		return

	_missile_visual = Node2D.new()
	_missile_visual.position = Vector2(0, 28)   # sotto la nave, opposto alla torretta

	# Corpo icona: "▲" rosso-fuoco che evoca un razzo/missile
	var body_lbl := Label.new()
	body_lbl.text = "▲"
	body_lbl.add_theme_font_size_override("font_size", 16)
	body_lbl.add_theme_color_override("font_color",         Color(1.00, 0.28, 0.10, 0.95))
	body_lbl.add_theme_constant_override("outline_size",    3)
	body_lbl.add_theme_color_override("font_outline_color", Color(1.00, 0.70, 0.00, 0.80))
	body_lbl.position = Vector2(-8, -10)
	_missile_visual.add_child(body_lbl)

	# Punti livello
	for i in level:
		var dot := Label.new()
		dot.text = "▪"
		dot.add_theme_font_size_override("font_size", 9)
		dot.add_theme_color_override("font_color", Color(1.00, 0.45, 0.10, 0.80))
		dot.position = Vector2(-6 + i * 8, 6)
		_missile_visual.add_child(dot)

	add_child(_missile_visual)


# ── Torretta ──────────────────────────────────────────────────────────────────

func _fire_turret() -> void:
	if not projectile_scene:
		return
	var dmg := damage * _turret_dmg_mult
	for i in _turret_dirs:
		var dir := Vector2.RIGHT.rotated((TAU / _turret_dirs) * i)
		_spawn_module_proj(global_position, dir, dmg)

	# Flash sul visual torretta al momento dello sparo
	if _turret_visual and is_instance_valid(_turret_visual):
		var tw := create_tween()
		tw.tween_property(_turret_visual, "modulate",
			Color(2.0, 1.5, 0.5, 1.0), 0.05)
		tw.tween_property(_turret_visual, "modulate",
			Color.WHITE, 0.15)


# ── Missile ───────────────────────────────────────────────────────────────────

func _fire_missiles() -> void:
	if not projectile_scene:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	# Ordina per distanza
	enemies.sort_custom(func(a: Node, b: Node) -> bool:
		return global_position.distance_squared_to((a as Node2D).global_position) \
			 < global_position.distance_squared_to((b as Node2D).global_position))

	var dmg := damage * _missile_dmg_mult
	for i in mini(_missile_count, enemies.size()):
		var t: Node2D = enemies[i] as Node2D
		var dir := (t.global_position - global_position).normalized()
		_spawn_module_proj(global_position, dir, dmg)

	# Flash sul visual missili al momento del lancio
	if _missile_visual and is_instance_valid(_missile_visual):
		var tw := create_tween()
		tw.tween_property(_missile_visual, "modulate",
			Color(3.0, 1.2, 0.2, 1.0), 0.04)
		tw.tween_property(_missile_visual, "modulate",
			Color.WHITE, 0.20)


# ── Orb scudo ─────────────────────────────────────────────────────────────────

func _update_orbs(delta: float) -> void:
	if _orb_nodes.is_empty():
		return
	_orb_angle += delta * 2.2

	# Aggiorna cooldown hit
	for i in _orb_cd.size():
		_orb_cd[i] = maxf(_orb_cd[i] - delta, 0.0)

	var enemies := get_tree().get_nodes_in_group("enemies")

	for i in _orb_nodes.size():
		var orb: Node2D = _orb_nodes[i] as Node2D
		if not is_instance_valid(orb):
			continue
		var angle   := _orb_angle + (TAU / _orb_nodes.size()) * float(i)
		var orb_pos := global_position + Vector2.RIGHT.rotated(angle) * 48.0
		orb.global_position = orb_pos

		# Danno da contatto (hit radius 20px, cooldown 0.6s per orb)
		if _orb_cd[i] <= 0.0:
			for enemy: Node in enemies:
				var e: Node2D = enemy as Node2D
				if is_instance_valid(e) and orb_pos.distance_to(e.global_position) < 20.0:
					if e.has_method("take_damage"):
						e.take_damage(damage * _orb_dmg_mult)
					_orb_cd[i] = 0.6
					break


# ── Droni ─────────────────────────────────────────────────────────────────────

func _update_drones(delta: float) -> void:
	if _drone_nodes.is_empty():
		return

	# Posizione orbita (offset di fase rispetto agli orb)
	for i in _drone_nodes.size():
		var dn: Node2D = _drone_nodes[i] as Node2D
		if not is_instance_valid(dn):
			continue
		var angle   := _orb_angle * 0.65 + (TAU / maxi(_drone_count, 1)) * float(i) + PI * 0.5
		dn.global_position = global_position + Vector2.RIGHT.rotated(angle) * 68.0

	# Timer sparo droni
	_drone_timer += delta
	if _drone_timer >= _drone_interval:
		_drone_timer = 0.0
		_fire_drones()


func _fire_drones() -> void:
	if not projectile_scene:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	enemies.sort_custom(func(a: Node, b: Node) -> bool:
		return global_position.distance_squared_to((a as Node2D).global_position) \
			 < global_position.distance_squared_to((b as Node2D).global_position))

	for i in _drone_nodes.size():
		var dn: Node2D = _drone_nodes[i] as Node2D
		if not is_instance_valid(dn):
			continue
		var target_idx := mini(i, enemies.size() - 1)
		var t: Node2D  = enemies[target_idx] as Node2D
		var dir := (t.global_position - dn.global_position).normalized()
		_spawn_module_proj(dn.global_position, dir, damage * 0.65)


# ── Helper proiettile modulo ──────────────────────────────────────────────────

func _spawn_module_proj(pos: Vector2, dir: Vector2, dmg: float) -> void:
	if not projectile_scene:
		return
	var p := projectile_scene.instantiate()
	p.global_position = pos + dir * 24.0
	p.rotation        = dir.angle()
	if "direction"   in p: p.direction = dir
	if "damage"      in p: p.damage    = dmg
	if p.has_method("setup"):
		p.setup(dmg, 0, 0.75)   # proiettili modulo leggermente più piccoli
	get_tree().current_scene.add_child(p)
	if "direction" in p:
		p.direction = dir
