extends CharacterBody2D
class_name Enemy

# ─────────────────────────────────────────────
#  Enemy  –  base class for all enemies
#  Includes: zone colour fix, damage numbers, hit flash
# ─────────────────────────────────────────────

signal died(enemy: Enemy)

# ── stats ─────────────────────────────────────────────────────────────────────
@export var max_health:      float = 30.0
@export var move_speed:      float = 80.0
@export var damage:          float = 10.0
@export var attack_range:    float = 42.0   # pixels – deals damage when this close
@export var attack_cooldown: float = 0.9    # seconds between hits
@export var xp_value:        int   = 5
@export var soul_value:      int   = 1
@export var drop_chance:     float = 0.30   # probabilità drop equipaggiamento

# ── runtime ───────────────────────────────────────────────────────────────────
var health: float
var target: Node2D = null
var is_dead: bool  = false
var base_color: Color            # cached so hit-flash can restore correctly
var _attack_timer: float = 0.0  # countdown to next allowed attack

## Variante del nemico: "", "speeder", "tank", "bomber"
var variant: String = ""

# ── internal ──────────────────────────────────────────────────────────────────
# Rilevamento automatico: cerca il primo Sprite2D / AnimatedSprite2D figlio
var sprite: Node2D = null
var hit_timer: Timer = null
var collision: CollisionShape2D = null

const ENEMY_COLORS: Array[Color] = [
	Color(0.8, 0.2, 1.0),   # violet
	Color(0.2, 0.8, 1.0),   # cyan
	Color(1.0, 0.4, 0.1),   # orange
	Color(0.2, 1.0, 0.5),   # green
]
const HIT_FLASH_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HIT_FLASH_TIME  := 0.08


# ══════════════════════════════════════════════
#  Lifecycle
# ══════════════════════════════════════════════

func _ready() -> void:
	health = max_health

	# ── auto-detect sprite (qualunque nome abbia nella scena) ─────────────────
	sprite = _find_sprite()

	# ── auto-detect hit timer ─────────────────────────────────────────────────
	hit_timer = get_node_or_null("HitFlashTimer")
	if hit_timer == null:
		# non esiste → crealo a runtime
		hit_timer = Timer.new()
		hit_timer.name = "HitFlashTimer"
		add_child(hit_timer)

	# ── auto-detect collision ─────────────────────────────────────────────────
	collision = get_node_or_null("CollisionShape2D")
	if collision == null:
		for child in get_children():
			if child is CollisionShape2D:
				collision = child
				break

	# random base colour
	base_color = ENEMY_COLORS[randi() % ENEMY_COLORS.size()]

	# ── visual moderno: nasconde Sprite2D e usa EnemyVisual ──────────────────
	if sprite != null:
		sprite.visible = false
	var vis_script = load("res://scripts/visuals/enemy_visual.gd")
	if vis_script:
		var vis: Node2D = vis_script.new()
		add_child(vis)
		sprite = vis   # ora hit-flash / zone-color agiscono sul visual
	elif sprite != null:
		sprite.visible = true   # fallback: usa sprite originale

	if sprite != null:
		sprite.modulate = base_color

	# connect timer
	if not hit_timer.timeout.is_connected(_on_hit_flash_timeout):
		hit_timer.timeout.connect(_on_hit_flash_timeout)
	hit_timer.wait_time = HIT_FLASH_TIME
	hit_timer.one_shot  = true

	add_to_group("enemies")


## Cerca il primo nodo Sprite2D o AnimatedSprite2D tra i figli (qualunque nome)
func _find_sprite() -> Node2D:
	# prima prova nomi comuni
	for name_try in ["Sprite2D", "Sprite", "AnimatedSprite2D", "AnimatedSprite"]:
		var n := get_node_or_null(name_try)
		if n != null:
			return n as Node2D
	# fallback: primo figlio di tipo Sprite2D
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child as Node2D
	return null


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# Freeze durante shop o pausa — non muoversi se il gioco non è in PLAYING
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	# Auto-trova il giocatore più vicino se non abbiamo un target valido
	if not is_instance_valid(target):
		_find_nearest_player()
	if not is_instance_valid(target):
		return

	# ── attacco da contatto ──────────────────────────────────────────────────
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		var dist := global_position.distance_to(target.global_position)
		if dist <= attack_range:
			if target.has_method("take_damage"):
				target.take_damage(damage)
			_attack_timer = attack_cooldown

	_move_toward_target(delta)


func _find_nearest_player() -> void:
	var best: Node2D = null
	var best_dist := INF
	for group_name in ["players", "player"]:
		for p in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(p):
				continue
			var d := global_position.distance_squared_to(p.global_position)
			if d < best_dist:
				best_dist = d
				best = p as Node2D
	target = best


func _move_toward_target(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dir := (target.global_position - global_position).normalized()
	var spd := move_speed

	# Time Surge: rallenta i nemici al 25% della velocità normale per 4 secondi
	# Attivato da player._power_time_surge() tramite GameManager metadata
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.has_meta("time_surge_active"):
		spd *= 0.25

	velocity = dir * spd
	move_and_slide()


# ══════════════════════════════════════════════
#  Zone colour  (called by EnemySpawner)
# ══════════════════════════════════════════════

## Blends the enemy's base colour with the zone's glow colour.
## Caches the result as base_color so the hit flash restores it correctly.
func setup_zone_color(zone_color: Color, blend_amount: float = 0.25) -> void:
	base_color = base_color.lerp(zone_color, blend_amount)
	if sprite != null:
		sprite.modulate = base_color


func set_variant(v: String) -> void:
	## Applica modificatori di variante. Chiamare DOPO _ready().
	variant = v
	match v:
		"speeder":
			move_speed   *= 2.2
			max_health   *= 0.45
			health        = max_health
			xp_value      = int(xp_value * 1.5)
			attack_cooldown *= 0.6
			if sprite != null:
				sprite.scale   *= Vector2(0.65, 0.65)
			base_color = base_color.lerp(Color(0.2, 1.0, 0.8), 0.55)
			if sprite != null:
				sprite.modulate = base_color

		"tank":
			move_speed   *= 0.38
			max_health   *= 3.2
			health        = max_health
			damage        *= 1.6
			soul_value    *= 3
			xp_value      = int(xp_value * 2.5)
			if sprite != null:
				sprite.scale   *= Vector2(1.7, 1.7)
			base_color = base_color.lerp(Color(0.6, 0.1, 0.1), 0.60)
			if sprite != null:
				sprite.modulate = base_color
			# Collision più grande
			if collision != null and collision.shape is CircleShape2D:
				(collision.shape as CircleShape2D).radius *= 1.6

		"bomber":
			max_health   *= 1.15
			health        = max_health
			move_speed   *= 1.1
			soul_value    *= 2
			# Colore arancio/rosso acceso
			base_color = base_color.lerp(Color(1.0, 0.4, 0.05), 0.70)
			if sprite != null:
				sprite.modulate = base_color


# ══════════════════════════════════════════════
#  Damage / death
# ══════════════════════════════════════════════

func take_damage(amount: float, crit: bool = false, _source_player_id: int = -1) -> void:
	if is_dead:
		return

	health -= amount
	AudioManager.sfx("hit_enemy", 0.15)
	_trigger_hit_flash()

	# ── floating damage number ────────────────────────────────────────────────
	var vfx_node: Node = get_node_or_null("/root/VFX")
	if vfx_node != null and vfx_node.has_method("spawn_damage_number"):
		var dmg_color := Color.WHITE
		if crit:
			dmg_color = Color(1.0, 0.85, 0.1)   # gold for crits
		vfx_node.spawn_damage_number(global_position, int(amount), crit, dmg_color)

	if health <= 0.0:
		_die()


func _trigger_hit_flash() -> void:
	if sprite != null:
		sprite.modulate = HIT_FLASH_COLOR
	hit_timer.start()

func _on_hit_flash_timeout() -> void:
	if sprite != null:
		sprite.modulate = base_color


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	AudioManager.sfx("explosion", 0.12)
	CameraShake.light()

	# Incrementa kill counter nel GameManager
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("add_kill"):
		gm.add_kill()

	# Assegna souls al giocatore in base al valore del nemico
	var mm: Node = get_node_or_null("/root/MetaManager")
	if mm != null and mm.has_method("gain_souls"):
		mm.gain_souls(soul_value)

	# VFX death burst
	var vfx_node: Node = get_node_or_null("/root/VFX")
	if vfx_node != null and vfx_node.has_method("spawn_death_effect"):
		vfx_node.spawn_death_effect(global_position, base_color)

	# disable collision immediately
	if collision != null:
		collision.set_deferred("disabled", true)

	# Bomber: esplode all'impatto danneggiando i player vicini
	if variant == "bomber":
		_bomber_explosion()

	emit_signal("died", self)
	_try_drop_equipment()
	queue_free()


func _bomber_explosion() -> void:
	const BOMB_RADIUS := 160.0
	const BOMB_DMG    := 22.0
	CameraShake.medium()
	for player in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(player):
			continue
		if global_position.distance_to(player.global_position) <= BOMB_RADIUS:
			if player.has_method("take_damage"):
				player.take_damage(BOMB_DMG)
	# VFX esplosione grande
	var vfx_node: Node = get_node_or_null("/root/VFX")
	if vfx_node != null and vfx_node.has_method("spawn_death_effect"):
		vfx_node.spawn_death_effect(global_position, Color(1.0, 0.4, 0.05))
		vfx_node.spawn_death_effect(global_position + Vector2(20, 0),  Color(1.0, 0.6, 0.0))
		vfx_node.spawn_death_effect(global_position + Vector2(-20, 0), Color(1.0, 0.2, 0.0))


# ── drop equipaggiamento ──────────────────────────────────────────────────────

func _try_drop_equipment() -> void:
	var drop_mult := 1.0

	# zona: opzionale, nessun errore se ZoneGenerator non è presente
	var zone_gen := get_tree().get_first_node_in_group("zone_generator")
	if zone_gen:
		var zone = zone_gen.get("current_zone")
		if zone:
			var dmult = zone.get("drop_rate_multiplier")
			if dmult != null:
				drop_mult = float(dmult)

	if randf() > drop_chance * drop_mult:
		return

	# EquipmentManager
	var em := get_node_or_null("/root/EquipmentManager")
	if em == null or not em.has_method("roll_random_equipment"):
		return

	var equipment = em.roll_random_equipment(drop_mult)
	if not equipment:
		return

	# Pickup scene
	var pickup_path := "res://scenes/pickups/equipment_pickup.tscn"
	if not ResourceLoader.exists(pickup_path):
		push_warning("EnemyVisual: pickup scene non trovata in " + pickup_path)
		return

	var pickup_res = load(pickup_path)
	if not pickup_res:
		return

	var pickup = pickup_res.instantiate()
	pickup.global_position = global_position + \
		Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
	if pickup.has_method("setup"):
		pickup.setup(equipment)
	get_tree().current_scene.add_child(pickup)


# ══════════════════════════════════════════════
#  Utility
# ══════════════════════════════════════════════

func get_health_ratio() -> float:
	return clampf(health / max_health, 0.0, 1.0)

func set_target(new_target: Node2D) -> void:
	target = new_target
