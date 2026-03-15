extends Node2D
class_name ZoneGenerator
## ZoneGenerator - Genera proceduralmente le zone di gioco
## Gestisce background, ostacoli, hazard e transizioni

signal zone_changed(zone_data: ZoneData)
signal zone_generated(zone_id: String)
signal hazard_hit(damage: float)   ## Emesso ogni volta che il danno ambientale colpisce i player

@export var zone_size: Vector2 = Vector2(3000, 3000)
@export var transition_duration: float = 1.5

# Zone disponibili
var available_zones: Array[ZoneData] = []
var current_zone: ZoneData
var current_zone_index: int = 0

# Nodi generati
var background_node: ColorRect
var stars_container: Node2D
var obstacles_container: Node2D
var hazards_container: Node2D

# Seed per riproducibilità
var generation_seed: int = 0

# Nodo visuale bordi mappa (ricreato ad ogni cambio zona)
var _boundary_visual: Node2D = null

# Riferimenti ai preload
const OBSTACLE_COLORS: Array[Color] = [
	Color(0.3, 0.3, 0.35, 0.8),
	Color(0.25, 0.25, 0.3, 0.8),
	Color(0.35, 0.3, 0.3, 0.8),
]


func _ready() -> void:
	_load_zones()
	_setup_containers()
	
	# Genera seed casuale se non specificato
	if generation_seed == 0:
		generation_seed = randi()
	
	# Genera prima zona
	generate_zone(0)


func _load_zones() -> void:
	## Carica tutti i biomi disponibili
	var zone_paths := [
		"res://resources/zones/void_black.tres",
		"res://resources/zones/nebula_purple.tres",
		"res://resources/zones/asteroid_field.tres",
		"res://resources/zones/plasma_storm.tres",
		"res://resources/zones/dimension_rift.tres",
	]
	
	for path in zone_paths:
		var zone := load(path) as ZoneData
		if zone:
			available_zones.append(zone)
		else:
			push_warning("ZoneGenerator: impossibile caricare zona da %s" % path)


func _setup_containers() -> void:
	## Crea i container per gli elementi della zona
	
	# Background
	background_node = ColorRect.new()
	background_node.name = "Background"
	background_node.z_index = -100
	background_node.size = zone_size
	background_node.position = -zone_size / 2
	add_child(background_node)
	
	# Container stelle/particelle
	stars_container = Node2D.new()
	stars_container.name = "Stars"
	stars_container.z_index = -90
	add_child(stars_container)
	
	# Container ostacoli
	obstacles_container = Node2D.new()
	obstacles_container.name = "Obstacles"
	obstacles_container.z_index = -10
	add_child(obstacles_container)
	
	# Container hazard
	hazards_container = Node2D.new()
	hazards_container.name = "Hazards"
	hazards_container.z_index = -5
	add_child(hazards_container)

	# Muri invisibili ai bordi della zona
	_generate_world_bounds()


func generate_zone(zone_index: int, custom_seed: int = -1) -> void:
	## Genera una zona specifica
	if zone_index < 0 or zone_index >= available_zones.size():
		zone_index = 0
	
	current_zone_index = zone_index
	current_zone = available_zones[zone_index]
	
	# Imposta seed per questa generazione
	var use_seed := custom_seed if custom_seed >= 0 else generation_seed + zone_index
	seed(use_seed)
	
	# Pulisci zona precedente
	_clear_zone()
	
	# Genera nuova zona
	_generate_background()
	_generate_stars()
	_generate_obstacles()
	_generate_boundary_glow()
	
	if current_zone.hazard_enabled:
		_setup_hazards()
	
	# Applica modificatori al GameManager
	_apply_zone_modifiers()
	
	zone_changed.emit(current_zone)
	zone_generated.emit(current_zone.zone_id)


func generate_random_zone() -> void:
	## Genera una zona casuale diversa dalla corrente
	var new_index := current_zone_index
	while new_index == current_zone_index and available_zones.size() > 1:
		new_index = randi() % available_zones.size()
	generate_zone(new_index)


func next_zone() -> void:
	## Passa alla zona successiva (ciclico)
	var next_index := (current_zone_index + 1) % available_zones.size()
	generate_zone(next_index)


func _clear_zone() -> void:
	## Rimuove tutti gli elementi della zona corrente
	for child in stars_container.get_children():
		child.queue_free()
	for child in obstacles_container.get_children():
		child.queue_free()
	for child in hazards_container.get_children():
		child.queue_free()


func _generate_background() -> void:
	## Genera il background con gradiente
	# Usiamo uno shader per il gradiente
	var shader_material := ShaderMaterial.new()
	shader_material.shader = _create_gradient_shader()
	shader_material.set_shader_parameter("color_top", current_zone.background_color_top)
	shader_material.set_shader_parameter("color_bottom", current_zone.background_color_bottom)
	
	background_node.material = shader_material


func _create_gradient_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(0.05, 0.02, 0.1, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.02, 0.01, 0.05, 1.0);

void fragment() {
	COLOR = mix(color_top, color_bottom, UV.y);
}
"""
	return shader


func _generate_stars() -> void:
	## Genera stelle/particelle di sfondo
	var star_count := int(randf_range(100, 200))
	var half_size := zone_size / 2
	
	for i in star_count:
		var star := _create_star()
		star.position = Vector2(
			randf_range(-half_size.x, half_size.x),
			randf_range(-half_size.y, half_size.y)
		)
		stars_container.add_child(star)


func _create_star() -> Node2D:
	## Crea una singola stella
	var star := Sprite2D.new()
	
	# Texture placeholder (quadrato bianco)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	star.texture = tex
	
	# Colore e dimensione variabile
	var base_color := current_zone.particle_color
	star.modulate = base_color.lerp(Color.WHITE, randf() * 0.3)
	star.modulate.a = randf_range(0.2, 0.8)
	
	var star_scale := randf_range(0.3, 1.5)
	star.scale = Vector2(star_scale, star_scale)
	
	# Aggiungi leggero twinkle effect
	if randf() < 0.3:
		var tween := star.create_tween()
		tween.set_loops()
		tween.tween_property(star, "modulate:a", star.modulate.a * 0.5, randf_range(0.5, 2.0))
		tween.tween_property(star, "modulate:a", star.modulate.a, randf_range(0.5, 2.0))
	
	return star


func _generate_obstacles() -> void:
	## Genera ostacoli nella zona
	var obstacle_count := int(current_zone.obstacle_density * 50)
	var half_size := zone_size / 2
	var safe_radius := 300.0  # Raggio sicuro attorno allo spawn
	
	for i in obstacle_count:
		var pos := Vector2(
			randf_range(-half_size.x + 100, half_size.x - 100),
			randf_range(-half_size.y + 100, half_size.y - 100)
		)
		
		# Evita spawn troppo vicino al centro (spawn giocatore)
		if pos.length() < safe_radius:
			continue
		
		var obstacle := _create_obstacle()
		obstacle.position = pos
		obstacles_container.add_child(obstacle)


func _create_obstacle() -> StaticBody2D:
	## Crea un singolo ostacolo
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = 64  # Layer 6: environment
	obstacle.collision_mask = 0
	
	# Forma casuale (cerchio o rettangolo)
	var is_circle := randf() < 0.6
	var size := randf_range(30, 80)
	
	# Visual
	var sprite := Sprite2D.new()
	var img: Image
	if is_circle:
		img = _create_circle_image(int(size))
	else:
		img = _create_rect_image(int(size), int(size * randf_range(0.5, 1.5)))
	
	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.modulate = OBSTACLE_COLORS[randi() % OBSTACLE_COLORS.size()]
	sprite.modulate = sprite.modulate.lerp(current_zone.ambient_color, 0.3)
	obstacle.add_child(sprite)
	
	# Collision
	var collision := CollisionShape2D.new()
	if is_circle:
		var shape := CircleShape2D.new()
		shape.radius = size / 2
		collision.shape = shape
	else:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(size, size * randf_range(0.5, 1.5))
		collision.shape = shape
	obstacle.add_child(collision)
	
	# Rotazione casuale
	obstacle.rotation = randf() * TAU
	
	return obstacle


func _create_circle_image(diameter: int) -> Image:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var center := diameter / 2.0
	var radius := center
	
	for x in diameter:
		for y in diameter:
			var dist := Vector2(x - center, y - center).length()
			if dist <= radius:
				var alpha := 1.0 - (dist / radius) * 0.3
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	return img


func _create_rect_image(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.9))
	return img


func _setup_hazards() -> void:
	## Configura gli hazard della zona (timer danno ambientale)
	var hazard_timer := Timer.new()
	hazard_timer.name = "HazardTimer"
	hazard_timer.wait_time = current_zone.hazard_interval
	hazard_timer.timeout.connect(_on_hazard_tick)
	hazards_container.add_child(hazard_timer)
	hazard_timer.start()


func _on_hazard_tick() -> void:
	## Applica danno ambientale ai giocatori
	if not current_zone or not current_zone.hazard_enabled:
		return

	var hit_count := 0
	for player in get_tree().get_nodes_in_group("players"):
		if player.has_method("take_damage"):
			player.take_damage(current_zone.hazard_damage * 0.5)
			hit_count += 1

	if hit_count > 0:
		hazard_hit.emit(current_zone.hazard_damage * 0.5)


func _apply_zone_modifiers() -> void:
	## Applica i modificatori della zona al gameplay
	# Questi verranno letti dall'EnemySpawner e altri sistemi
	pass


func get_current_zone() -> ZoneData:
	return current_zone


func get_zone_count() -> int:
	return available_zones.size()


func get_zone_by_id(zone_id: String) -> ZoneData:
	for zone in available_zones:
		if zone.zone_id == zone_id:
			return zone
	return null


func _generate_boundary_glow() -> void:
	## Crea strisce luminose neon ai bordi della zona – si aggiorna per ogni bioma.
	if _boundary_visual and is_instance_valid(_boundary_visual):
		_boundary_visual.queue_free()

	_boundary_visual = Node2D.new()
	_boundary_visual.name = "BoundaryGlow"
	_boundary_visual.z_index = -50   # sopra stelle/background, sotto ostacoli
	add_child(_boundary_visual)

	var zone_col: Color = current_zone.ambient_color \
		if current_zone else Color(0.55, 0.10, 1.00)

	var half_w    := zone_size.x / 2.0
	var half_h    := zone_size.y / 2.0
	var thickness := 200.0   # spessore fascia luminosa (px)

	var glow_shader := _create_edge_glow_shader()

	# [posizione, dimensione, direction: 0=sinistra 1=destra 2=sopra 3=sotto]
	var defs: Array = [
		[Vector2(-half_w,               -half_h), Vector2(thickness, zone_size.y), 0.0],
		[Vector2(half_w - thickness,    -half_h), Vector2(thickness, zone_size.y), 1.0],
		[Vector2(-half_w,               -half_h), Vector2(zone_size.x, thickness), 2.0],
		[Vector2(-half_w, half_h - thickness),    Vector2(zone_size.x, thickness), 3.0],
	]

	for d in defs:
		var cr := ColorRect.new()
		cr.position = d[0]
		cr.size     = d[1]
		var mat     := ShaderMaterial.new()
		mat.shader  = glow_shader
		mat.set_shader_parameter("edge_color",
			Color(zone_col.r, zone_col.g, zone_col.b, 0.78))
		mat.set_shader_parameter("direction", d[2])
		cr.material = mat
		_boundary_visual.add_child(cr)

		# Pulsing asincrono per effetto respiro
		var tween := cr.create_tween()
		tween.set_loops()
		tween.set_trans(Tween.TRANS_SINE)
		var t_in  := randf_range(1.4, 2.4)
		var t_out := randf_range(1.4, 2.4)
		tween.tween_property(cr, "modulate:a", 0.38, t_in)
		tween.tween_property(cr, "modulate:a", 1.00, t_out)


func _create_edge_glow_shader() -> Shader:
	## Gradiente da trasparente (interno) a neon (bordo esterno).
	var s := Shader.new()
	s.code = """
shader_type canvas_item;

uniform vec4  edge_color : source_color = vec4(0.55, 0.10, 1.0, 0.78);
// direction: 0 = sinistra | 1 = destra | 2 = sopra | 3 = sotto
uniform float direction = 0.0;

void fragment() {
	float t;
	if      (direction < 0.5) t = 1.0 - UV.x;   // sinistra: max al bordo sx
	else if (direction < 1.5) t = UV.x;           // destra:   max al bordo dx
	else if (direction < 2.5) t = 1.0 - UV.y;    // sopra:    max al bordo top
	else                       t = UV.y;            // sotto:    max al bordo bottom

	// Curva quadratica: sfuma dolcemente verso l'interno
	float alpha  = pow(t, 1.7) * edge_color.a;

	// Sottile linea neon solida sul bordo esterno (ultimo 8%)
	float neon   = step(0.92, t) * 0.55;

	COLOR = vec4(edge_color.rgb, clamp(alpha + neon, 0.0, 1.0));
}
"""
	return s


func _generate_world_bounds() -> void:
	## Crea 4 muri invisibili StaticBody2D ai bordi della zona
	## Impedisce al giocatore di uscire oltre il background
	var half_w := zone_size.x / 2.0
	var half_h := zone_size.y / 2.0
	var thickness := 120.0
	var extra    := 240.0  # Sovrapposizione negli angoli per evitare buchi

	# [posizione_centro, dimensione_rettangolo]
	var wall_defs: Array = [
		[Vector2(0.0, -half_h - thickness * 0.5), Vector2(zone_size.x + extra, thickness)],  # Top
		[Vector2(0.0,  half_h + thickness * 0.5), Vector2(zone_size.x + extra, thickness)],  # Bottom
		[Vector2(-half_w - thickness * 0.5, 0.0), Vector2(thickness, zone_size.y + extra)],  # Left
		[Vector2( half_w + thickness * 0.5, 0.0), Vector2(thickness, zone_size.y + extra)],  # Right
	]

	for wall_def in wall_defs:
		var wall := StaticBody2D.new()
		wall.collision_layer = 64  # Layer 6: environment (stesso degli ostacoli)
		wall.collision_mask  = 0

		var col   := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall_def[1]
		col.shape  = shape
		wall.add_child(col)

		wall.position = wall_def[0]
		add_child(wall)
