extends Node2D
class_name EnemySpawner
## EnemySpawner - Gestisce lo spawn continuo di nemici
## Aumenta difficoltà nel tempo

signal wave_changed(wave: int)

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 600.0  # Distanza minima dal giocatore
@export var spawn_margin: float = 100.0  # Margine extra random

@export_group("Spawn Settings")
@export var initial_spawn_rate: float = 2.0  # Nemici al secondo iniziali
@export var max_spawn_rate: float = 10.0
@export var spawn_rate_increase: float = 0.1  # Aumento per wave
@export var wave_duration: float = 30.0  # Secondi per wave
@export var max_enemies: int = 50

var current_wave: int = 1
var spawn_rate: float
var spawn_timer: float = 0.0
var wave_timer: float = 0.0
var active_enemies: Array[Node2D] = []


func _ready() -> void:
	spawn_rate = initial_spawn_rate


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# Wave timer
	wave_timer += delta
	if wave_timer >= wave_duration:
		_advance_wave()
	
	# Spawn timer
	spawn_timer += delta
	var spawn_interval := 1.0 / spawn_rate
	
	while spawn_timer >= spawn_interval:
		spawn_timer -= spawn_interval
		_try_spawn_enemy()
	
	# Pulizia nemici morti
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))


func _advance_wave() -> void:
	wave_timer = 0.0
	current_wave += 1
	GameManager.current_wave = current_wave
	
	# Aumenta difficoltà
	spawn_rate = minf(initial_spawn_rate + (current_wave - 1) * spawn_rate_increase, max_spawn_rate)
	
	wave_changed.emit(current_wave)


func _try_spawn_enemy() -> void:
	if active_enemies.size() >= max_enemies:
		return
	
	if not enemy_scene:
		push_warning("EnemySpawner: enemy_scene non assegnata!")
		return
	
	# Trova posizione spawn (lontano dai giocatori)
	var spawn_position := _get_spawn_position()
	if spawn_position == Vector2.INF:
		return
	
	# Spawn nemico
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.global_position = spawn_position
	
	# Scala stats con wave
	var wave_multiplier := 1.0 + (current_wave - 1) * 0.1
	enemy.max_health *= wave_multiplier
	enemy.damage *= wave_multiplier
	enemy.move_speed *= 1.0 + (current_wave - 1) * 0.02
	
	# Traccia e aggiungi alla scena
	enemy.died.connect(_on_enemy_died)
	active_enemies.append(enemy)
	add_child(enemy)


func _get_spawn_position() -> Vector2:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return Vector2.INF
	
	# Posizione centro tra tutti i giocatori
	var center := Vector2.ZERO
	for player in players:
		center += player.global_position
	center /= players.size()
	
	# Prova posizioni random finché non trovi una valida
	for _attempt in range(10):
		var angle := randf() * TAU
		var distance := spawn_radius + randf() * spawn_margin
		var spawn_pos := center + Vector2(cos(angle), sin(angle)) * distance
		
		# Verifica che sia abbastanza lontana da tutti i giocatori
		var valid := true
		for player in players:
			if spawn_pos.distance_to(player.global_position) < spawn_radius * 0.8:
				valid = false
				break
		
		if valid:
			return spawn_pos
	
	return Vector2.INF


func _on_enemy_died(enemy: Enemy) -> void:
	active_enemies.erase(enemy)


func get_enemy_count() -> int:
	return active_enemies.size()
