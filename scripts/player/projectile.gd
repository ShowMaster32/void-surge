extends Area2D
class_name Projectile
## Projectile - Proiettile base del giocatore
## Si muove in linea retta e infligge danno ai nemici

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
	
	# Effetto hit (colore diverso per crit)
	if is_instance_valid(VFX):
		var hit_color := Color(1, 1, 0) if is_crit else PROJECTILE_COLORS[owner_player_id % PROJECTILE_COLORS.size()]
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
		pierce_count -= 1
		enemies_pierced += 1


func _on_lifetime_timeout() -> void:
	_destroy()


func _destroy() -> void:
	# Qui potresti aggiungere effetti particellari
	queue_free()
