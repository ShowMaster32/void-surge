extends Area2D
class_name Projectile
## Projectile - Proiettile base del giocatore
## Si muove in linea retta e infligge danno ai nemici

@export var speed: float = 800.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0
@export var pierce_count: int = 0  # 0 = si distrugge al primo hit

var direction: Vector2 = Vector2.RIGHT
var owner_player_id: int = 0
var enemies_hit: Array[Node2D] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer

# Colori proiettili (match player colors ma più luminosi)
const PROJECTILE_COLORS: Array[Color] = [
	Color(0.3, 1.0, 1.0),    # P1: Cyan bright
	Color(1.0, 0.4, 0.8),    # P2: Magenta bright
	Color(0.5, 1.0, 0.5),    # P3: Green bright
	Color(1.0, 0.9, 0.4),    # P4: Yellow bright
]


func _ready() -> void:
	# Ruota nella direzione di movimento
	rotation = direction.angle()
	
	# Colore basato sul giocatore
	if sprite:
		sprite.modulate = PROJECTILE_COLORS[owner_player_id % PROJECTILE_COLORS.size()]
	
	# Setup lifetime
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	lifetime_timer.start()
	
	# Connetti segnale collisione
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


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
	
	# Effetto hit
	if is_instance_valid(VFX):
		VFX.spawn_hit_effect(global_position, PROJECTILE_COLORS[owner_player_id % PROJECTILE_COLORS.size()])
	
	# Infliggi danno
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
		GameManager.add_damage(damage)
	
	# Gestisci pierce
	if pierce_count <= 0:
		_destroy()
	else:
		pierce_count -= 1


func _on_lifetime_timeout() -> void:
	_destroy()


func _destroy() -> void:
	# Qui potresti aggiungere effetti particellari
	queue_free()
