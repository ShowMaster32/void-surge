extends Area2D
class_name EquipmentPickup
## EquipmentPickup - Oggetto raccoglibile che contiene un equipaggiamento
## AGGIORNATO: forme diverse per tipo (WEAPON=diamante, ARMOR=scudo, UTILITY=cerchio, SPECIAL=stella)
##              + bobbing animation + notifica di pickup

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

## Dimensione texture generata proceduralmente
const SHAPE_SIZE := 32


func _ready() -> void:
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	lifetime_timer.start()

	body_entered.connect(_on_body_entered)

	_setup_visuals()

	# Animazione spawn (pop-in)
	scale = Vector2.ZERO
	var spawn_tween := create_tween()
	spawn_tween.set_ease(Tween.EASE_OUT)
	spawn_tween.set_trans(Tween.TRANS_BACK)
	spawn_tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	spawn_tween.tween_callback(_start_bob_animation)


func _start_bob_animation() -> void:
	## Animazione di galleggiamento continua
	var bob := create_tween()
	bob.set_loops()
	bob.set_trans(Tween.TRANS_SINE)
	bob.set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(sprite, "position:y", -5.0, 0.7)
	bob.tween_property(sprite, "position:y",  5.0, 0.7)

	# Rotazione lenta per i SPECIAL (stelle)
	if equipment and equipment.equipment_type == EquipmentData.EquipmentType.SPECIAL:
		var rot := create_tween()
		rot.set_loops()
		rot.tween_property(sprite, "rotation", TAU, 3.0)


func _physics_process(delta: float) -> void:
	if is_being_collected and target_player and is_instance_valid(target_player):
		var direction := (target_player.global_position - global_position).normalized()
		global_position += direction * magnet_speed * delta
		if global_position.distance_to(target_player.global_position) < 30:
			_collect()
	else:
		_check_magnet_range()


func _check_magnet_range() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if global_position.distance_to(player.global_position) < magnet_range:
			is_being_collected = true
			target_player = player
			break


func setup(equip: EquipmentData) -> void:
	equipment = equip
	if is_inside_tree():
		_setup_visuals()


func _setup_visuals() -> void:
	if not equipment:
		return

	var rarity_color := equipment.get_rarity_color()

	if sprite:
		# Genera texture con la forma giusta per il tipo di equipment
		sprite.texture = _build_shape_texture(equipment.equipment_type)
		sprite.modulate = equipment.glow_color
		# Scala basata sulla rarità: più raro = leggermente più grande
		var rarity_scale := 1.0 + equipment.rarity * 0.12
		sprite.scale = Vector2(rarity_scale, rarity_scale)

	if glow_effect:
		glow_effect.color = rarity_color
		match equipment.rarity:
			EquipmentData.Rarity.COMMON:    glow_effect.energy = 0.5
			EquipmentData.Rarity.RARE:      glow_effect.energy = 1.0
			EquipmentData.Rarity.EPIC:      glow_effect.energy = 1.5
			EquipmentData.Rarity.LEGENDARY: glow_effect.energy = 2.2


# ---------------------------------------------------------------------------
# GENERAZIONE TEXTURE FORME
# ---------------------------------------------------------------------------

func _build_shape_texture(eq_type: EquipmentData.EquipmentType) -> ImageTexture:
	## Genera una ImageTexture 32×32 con la forma appropriata al tipo
	var img := Image.create(SHAPE_SIZE, SHAPE_SIZE, false, Image.FORMAT_RGBA8)
	var cx  := SHAPE_SIZE / 2.0
	var cy  := SHAPE_SIZE / 2.0
	var r   := (SHAPE_SIZE / 2.0) - 1.5   # Raggio utile (con 1.5px di margine)

	for px in SHAPE_SIZE:
		for py in SHAPE_SIZE:
			var dx: float = px - cx
			var dy: float = py - cy
			var alpha := _shape_alpha(dx, dy, r, eq_type)
			if alpha > 0.0:
				img.set_pixel(px, py, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)


func _shape_alpha(dx: float, dy: float, r: float, eq_type: EquipmentData.EquipmentType) -> float:
	## Restituisce l'alpha (0‥1) per il pixel (dx, dy) rispetto al centro
	## usando antialiasing sull'edge dei 2 pixel più esterni.
	const ANTIALIAS := 2.0  # px di sfumatura sul bordo

	match eq_type:

		EquipmentData.EquipmentType.WEAPON:
			## Diamante: |dx| + |dy| <= r
			var dist: float = absf(dx) + absf(dy)
			return clampf((r - dist) / ANTIALIAS, 0.0, 1.0)

		EquipmentData.EquipmentType.ARMOR:
			## Scudo: rettangolo nella metà superiore + triangolo nella metà inferiore
			var split: float = r * 0.25
			if dy <= split:
				# Parte rettangolare (top)
				var half_w: float = r * 0.82
				var dist_x: float = absf(dx) - half_w
				var edge_x: float = clampf(-dist_x / ANTIALIAS, 0.0, 1.0)
				var edge_y_top: float = clampf((dy - (-r)) / ANTIALIAS, 0.0, 1.0)
				return minf(edge_x, edge_y_top)
			else:
				# Parte triangolare (bottom): la larghezza si restringe verso il basso
				var t: float = (dy - split) / (r - split)
				var half_w: float = r * 0.82 * (1.0 - t)
				var dist_x: float = absf(dx) - half_w
				return clampf(-dist_x / ANTIALIAS, 0.0, 1.0)

		EquipmentData.EquipmentType.UTILITY:
			## Cerchio pieno
			var dist: float = sqrt(dx * dx + dy * dy)
			return clampf((r - dist) / ANTIALIAS, 0.0, 1.0)

		EquipmentData.EquipmentType.SPECIAL:
			## Stella a 4 punte
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 0.01:
				return 1.0
			var angle: float = fmod(atan2(dy, dx) + TAU, TAU)
			var seg: float   = fmod(angle, PI * 0.5)
			var t: float     = absf(seg - PI * 0.25) / (PI * 0.25)
			var star_r: float = r * lerp(0.38, 1.0, t)
			return clampf((star_r - dist) / ANTIALIAS, 0.0, 1.0)

	# Fallback cerchio
	var fallback_dist: float = sqrt(dx * dx + dy * dy)
	return clampf((r - fallback_dist) / ANTIALIAS, 0.0, 1.0)


# ---------------------------------------------------------------------------
# RACCOLTA
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") and not is_being_collected:
		is_being_collected = true
		target_player = body


func _collect() -> void:
	if not equipment:
		queue_free()
		return

	EquipmentManager.collect_equipment(equipment)

	if is_instance_valid(VFX):
		VFX.spawn_hit_effect(global_position, equipment.glow_color)

	collected.emit(equipment)
	queue_free()


func _on_lifetime_timeout() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
