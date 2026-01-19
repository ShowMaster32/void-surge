extends CharacterBody2D
class_name Player
## Player - Void Operator controllabile
## Supporta movimento WASD/stick, mira mouse/stick destro, sparo

signal health_changed(current: float, max_health: float)
signal died

# Identificatore giocatore per co-op (0-3)
@export var player_id: int = 0

# Stats base
@export_group("Stats")
@export var max_health: float = 100.0
@export var base_move_speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1500.0

# Combat
@export_group("Combat")
@export var base_fire_rate: float = 0.15  # Secondi tra spari
@export var base_damage: float = 10.0
@export var projectile_scene: PackedScene

# Stats modificate da equipment
var move_speed: float
var fire_rate: float
var damage_multiplier: float = 1.0
var crit_chance: float = 0.0
var crit_damage: float = 1.5  # Moltiplicatore base crit

# Stato interno
var current_health: float
var can_shoot: bool = true
var aim_direction: Vector2 = Vector2.RIGHT
var is_invincible: bool = false

# Nodi
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var muzzle: Marker2D = $Muzzle
@onready var fire_rate_timer: Timer = $FireRateTimer
@onready var invincibility_timer: Timer = $InvincibilityTimer
@onready var hit_flash_timer: Timer = $HitFlashTimer

# Colori per giocatori (neon style)
const PLAYER_COLORS: Array[Color] = [
	Color(0.0, 1.0, 1.0),    # P1: Cyan
	Color(1.0, 0.2, 0.6),    # P2: Magenta
	Color(0.4, 1.0, 0.4),    # P3: Green
	Color(1.0, 0.8, 0.2),    # P4: Yellow
]


func _ready() -> void:
	current_health = max_health
	move_speed = base_move_speed
	fire_rate = base_fire_rate
	add_to_group("players")
	
	# Setup timer
	fire_rate_timer.wait_time = fire_rate
	fire_rate_timer.one_shot = true
	fire_rate_timer.timeout.connect(_on_fire_rate_timer_timeout)
	
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timeout)
	
	hit_flash_timer.one_shot = true
	hit_flash_timer.timeout.connect(_on_hit_flash_timeout)
	
	# Colore giocatore
	if sprite:
		sprite.modulate = PLAYER_COLORS[player_id % PLAYER_COLORS.size()]
	
	# Registra con GameManager
	GameManager.register_player(self)
	
	# Connetti a equipment stats
	EquipmentManager.equipment_stats_changed.connect(_on_equipment_stats_changed)
	_apply_equipment_stats()


func _exit_tree() -> void:
	GameManager.unregister_player(self)


func _physics_process(delta: float) -> void:
	handle_movement(delta)
	handle_aim()
	handle_shooting()
	handle_pause()
	move_and_slide()


func handle_movement(delta: float) -> void:
	var input_vector := InputManager.get_movement_vector(player_id)
	
	if input_vector != Vector2.ZERO:
		# Accelerazione verso la direzione input
		velocity = velocity.move_toward(input_vector * move_speed, acceleration * delta)
	else:
		# Frizione quando non c'è input
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func handle_aim() -> void:
	aim_direction = InputManager.get_aim_vector(player_id, global_position)
	
	# Ruota il muzzle nella direzione di mira
	if muzzle:
		muzzle.rotation = aim_direction.angle()
	
	# Flip sprite basato sulla direzione
	if sprite and aim_direction.x != 0:
		sprite.flip_h = aim_direction.x < 0


func handle_shooting() -> void:
	if InputManager.is_shooting(player_id) and can_shoot:
		shoot()


func handle_pause() -> void:
	if InputManager.is_pause_pressed(player_id):
		GameManager.toggle_pause()


func shoot() -> void:
	if not projectile_scene:
		push_warning("Player %d: projectile_scene non assegnata!" % player_id)
		return
	
	can_shoot = false
	fire_rate_timer.start()
	
	# Spawn proiettile
	var projectile := projectile_scene.instantiate()
	projectile.global_position = muzzle.global_position
	projectile.direction = aim_direction
	projectile.owner_player_id = player_id
	
	# Applica bonus equipment
	var equip_stats := EquipmentManager.get_all_stats()
	projectile.damage = base_damage * damage_multiplier
	projectile.pierce_count = int(equip_stats.get("pierce_bonus", 0))
	projectile.speed *= (1.0 + equip_stats.get("projectile_speed_bonus", 0.0))
	projectile.crit_chance = crit_chance
	projectile.crit_damage = crit_damage
	
	# Bonus sinergie
	projectile.burn_damage = equip_stats.get("burn_damage", 0.0)
	projectile.pierce_damage_mult = equip_stats.get("pierce_damage_mult", 0.0)
	
	# Aggiungi alla scena
	get_tree().current_scene.add_child(projectile)


func _on_equipment_stats_changed(_stats: Dictionary) -> void:
	_apply_equipment_stats()


func _apply_equipment_stats() -> void:
	## Applica bonus degli equipaggiamenti
	var stats := EquipmentManager.get_all_stats()
	
	# Movimento
	move_speed = base_move_speed * (1.0 + stats.get("move_speed_bonus", 0.0))
	
	# Combattimento
	damage_multiplier = 1.0 + stats.get("damage_bonus", 0.0)
	crit_chance = stats.get("crit_chance_bonus", 0.0)
	crit_damage = 1.5 + stats.get("crit_damage_bonus", 0.0)
	
	# Fire rate (più basso = più veloce)
	var fire_rate_mult := 1.0 / (1.0 + stats.get("fire_rate_bonus", 0.0))
	fire_rate = base_fire_rate * fire_rate_mult
	fire_rate_timer.wait_time = fire_rate
	
	# HP bonus
	var hp_bonus: float = stats.get("health_bonus", 0.0)
	if hp_bonus > 0:
		var old_max := max_health
		max_health = 100.0 + hp_bonus
		# Scala HP corrente proporzionalmente
		if old_max > 0:
			current_health = current_health * (max_health / old_max)
		health_changed.emit(current_health, max_health)


func take_damage(amount: float) -> void:
	if is_invincible:
		return
	
	current_health = maxf(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	
	# Effetto flash
	_start_hit_flash()
	
	# Breve invincibilità dopo danno
	is_invincible = true
	invincibility_timer.start(0.5)
	
	if current_health <= 0:
		die()


func heal(amount: float) -> void:
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func die() -> void:
	died.emit()
	# Effetto morte
	if is_instance_valid(VFX):
		VFX.spawn_death_effect(global_position, PLAYER_COLORS[player_id % PLAYER_COLORS.size()])
	queue_free()


func _start_hit_flash() -> void:
	if sprite:
		sprite.modulate = Color.WHITE
		hit_flash_timer.start(0.1)


func _on_fire_rate_timer_timeout() -> void:
	can_shoot = true


func _on_invincibility_timeout() -> void:
	is_invincible = false


func _on_hit_flash_timeout() -> void:
	if sprite:
		sprite.modulate = PLAYER_COLORS[player_id % PLAYER_COLORS.size()]
