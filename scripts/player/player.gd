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
@export var move_speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 1500.0

# Combat
@export_group("Combat")
@export var fire_rate: float = 0.15  # Secondi tra spari
@export var projectile_scene: PackedScene

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
	
	# Aggiungi alla scena
	get_tree().current_scene.add_child(projectile)


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
	# Effetto morte (da implementare)
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
