extends CharacterBody2D
class_name Enemy
## Enemy - Nemico base che pattuglia e attacca i giocatori
## FIX: cache base_color per correggere il bug del hit flash

signal died(enemy: Enemy)
signal health_changed(current: float, max_health: float)

enum State { PATROL, CHASE, ATTACK }

@export_group("Stats")
@export var max_health: float = 30.0
@export var move_speed: float = 100.0
@export var damage: float = 10.0
@export var attack_cooldown: float = 1.0

@export_group("AI")
@export var detection_range: float = 400.0
@export var attack_range: float = 50.0
@export var patrol_radius: float = 150.0

@export_group("Drops")
@export var drop_chance: float = 0.3
@export var pickup_scene: PackedScene

var current_health: float
var current_state: State = State.PATROL
var target_player: Node2D = null
var patrol_center: Vector2
var patrol_target: Vector2
var can_attack: bool = true

# FIX: cache del colore base per il corretto ripristino dopo hit flash
var base_color: Color = Color.WHITE

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer
@onready var hit_flash_timer: Timer = $HitFlashTimer

const ENEMY_COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.3),  # Rosso
	Color(1.0, 0.5, 0.2),  # Arancione
	Color(0.8, 0.2, 0.8),  # Viola
]


func _ready() -> void:
	current_health = max_health
	patrol_center = global_position
	patrol_target = _get_random_patrol_point()
	add_to_group("enemies")

	# Assegna colore random e cachalo subito
	var chosen_color := ENEMY_COLORS[randi() % ENEMY_COLORS.size()]
	base_color = chosen_color
	if sprite:
		sprite.modulate = base_color

	if detection_area:
		var detection_shape := CircleShape2D.new()
		detection_shape.radius = detection_range
		var collision := CollisionShape2D.new()
		collision.shape = detection_shape
		detection_area.add_child(collision)

	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	hit_flash_timer.one_shot = true
	hit_flash_timer.timeout.connect(_on_hit_flash_timeout)


## Chiamato da EnemySpawner per applicare la tinta di zona.
## Aggiorna anche base_color così l'hit flash ripristina il colore corretto.
func setup_zone_color(zone_color: Color, blend_amount: float = 0.2) -> void:
	base_color = base_color.lerp(zone_color, blend_amount)
	if sprite:
		sprite.modulate = base_color


func _physics_process(delta: float) -> void:
	_update_target()

	match current_state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_attack()

	move_and_slide()


func _update_target() -> void:
	var closest_player: Node2D = null
	var closest_distance: float = detection_range

	for player in get_tree().get_nodes_in_group("players"):
		var distance := global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player

	target_player = closest_player

	if target_player:
		var distance := global_position.distance_to(target_player.global_position)
		if distance <= attack_range:
			current_state = State.ATTACK
		else:
			current_state = State.CHASE
	else:
		current_state = State.PATROL


func _patrol(_delta: float) -> void:
	var direction := (patrol_target - global_position).normalized()
	velocity = direction * move_speed * 0.5

	if sprite and direction.x != 0:
		sprite.flip_h = direction.x < 0

	if global_position.distance_to(patrol_target) < 20:
		patrol_target = _get_random_patrol_point()


func _chase(_delta: float) -> void:
	if not target_player:
		return

	var direction := (target_player.global_position - global_position).normalized()
	velocity = direction * move_speed

	if sprite and direction.x != 0:
		sprite.flip_h = direction.x < 0


func _attack() -> void:
	velocity = Vector2.ZERO

	if can_attack and target_player:
		can_attack = false
		attack_timer.start()

		if target_player.has_method("take_damage"):
			target_player.take_damage(damage)


func _get_random_patrol_point() -> Vector2:
	var angle := randf() * TAU
	var distance := randf_range(patrol_radius * 0.5, patrol_radius)
	return patrol_center + Vector2(cos(angle), sin(angle)) * distance


func take_damage(amount: float) -> void:
	current_health = maxf(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	_start_hit_flash()

	# Knockback verso l'esterno
	if target_player:
		var knockback_dir := (global_position - target_player.global_position).normalized()
		velocity = knockback_dir * 200

	if current_health <= 0:
		die()


func die() -> void:
	GameManager.add_kill()
	died.emit(self)

	# FIX: VFX è il nome autoload registrato in Project > Autoload per vfx_manager.gd
	# Assicurati che in Project Settings > Autoload il nome sia esattamente "VFX"
	if Engine.has_singleton("VFX") or get_node_or_null("/root/VFX") != null:
		var vfx := get_node("/root/VFX")
		vfx.spawn_death_effect(global_position, base_color)

	_try_drop_equipment()
	queue_free()


func _try_drop_equipment() -> void:
	var drop_mult := 1.0
	var zone_gen := get_tree().get_first_node_in_group("zone_generator") as ZoneGenerator
	if zone_gen and zone_gen.current_zone:
		drop_mult = zone_gen.current_zone.drop_rate_multiplier

	if randf() > drop_chance * drop_mult:
		return

	var equipment := EquipmentManager.roll_random_equipment(drop_mult)
	if not equipment:
		return

	if not pickup_scene:
		pickup_scene = load("res://scenes/pickups/equipment_pickup.tscn")

	if pickup_scene:
		var pickup := pickup_scene.instantiate() as EquipmentPickup
		pickup.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		pickup.setup(equipment)
		get_tree().current_scene.add_child(pickup)


func _start_hit_flash() -> void:
	if sprite:
		sprite.modulate = Color.WHITE
		hit_flash_timer.start(0.08)


func _on_attack_timer_timeout() -> void:
	can_attack = true


func _on_hit_flash_timeout() -> void:
	# FIX: ripristina base_color (che include anche la tinta di zona)
	# invece di scegliere un colore random che ignorava la zona
	if sprite:
		sprite.modulate = base_color
