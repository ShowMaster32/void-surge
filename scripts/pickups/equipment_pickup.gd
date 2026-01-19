extends Area2D
class_name EquipmentPickup
## EquipmentPickup - Oggetto raccoglibile che contiene un equipaggiamento

signal collected(equipment: EquipmentData)

@export var equipment: EquipmentData
@export var magnet_speed: float = 500.0
@export var magnet_range: float = 150.0
@export var lifetime: float = 30.0

var is_being_collected: bool = false
var target_player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var glow_effect: PointLight2D = $GlowEffect


func _ready() -> void:
	# Setup lifetime
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	lifetime_timer.start()
	
	# Connetti collisione
	body_entered.connect(_on_body_entered)
	
	# Applica visuals dell'equipaggiamento
	_setup_visuals()
	
	# Animazione spawn
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)


func _physics_process(delta: float) -> void:
	if is_being_collected and target_player and is_instance_valid(target_player):
		# Muovi verso il giocatore
		var direction := (target_player.global_position - global_position).normalized()
		global_position += direction * magnet_speed * delta
		
		# Raccogli se abbastanza vicino
		if global_position.distance_to(target_player.global_position) < 30:
			_collect()
	else:
		# Controlla se un giocatore è nel range del magnete
		_check_magnet_range()


func _check_magnet_range() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if global_position.distance_to(player.global_position) < magnet_range:
			is_being_collected = true
			target_player = player
			break


func setup(equip: EquipmentData) -> void:
	## Configura il pickup con l'equipaggiamento
	equipment = equip
	if is_inside_tree():
		_setup_visuals()


func _setup_visuals() -> void:
	if not equipment:
		return
	
	# Colore basato sulla rarità
	var rarity_color := equipment.get_rarity_color()
	
	if sprite:
		sprite.modulate = equipment.glow_color
	
	if glow_effect:
		glow_effect.color = rarity_color
		# Intensità glow basata su rarità
		match equipment.rarity:
			EquipmentData.Rarity.COMMON:
				glow_effect.energy = 0.5
			EquipmentData.Rarity.RARE:
				glow_effect.energy = 1.0
			EquipmentData.Rarity.EPIC:
				glow_effect.energy = 1.5
			EquipmentData.Rarity.LEGENDARY:
				glow_effect.energy = 2.0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") and not is_being_collected:
		is_being_collected = true
		target_player = body


func _collect() -> void:
	if not equipment:
		queue_free()
		return
	
	# Aggiungi all'inventario
	EquipmentManager.collect_equipment(equipment)
	
	# Effetto raccolta
	if is_instance_valid(VFX):
		VFX.spawn_hit_effect(global_position, equipment.glow_color)
	
	collected.emit(equipment)
	queue_free()


func _on_lifetime_timeout() -> void:
	# Fade out e distruggi
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
