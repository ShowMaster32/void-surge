extends Node
## GameManager - Gestisce lo stato globale del gioco
## Autoload singleton accessibile ovunque come GameManager

signal game_started
signal game_paused(is_paused: bool)
signal game_over(stats: Dictionary)
signal player_spawned(player: Node2D)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var current_state: GameState = GameState.MENU
var run_time: float = 0.0
var total_kills: int = 0
var total_damage_dealt: float = 0.0
var current_wave: int = 1

# Player references per co-op
var players: Array[Node2D] = []
var player_count: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		run_time += delta


func start_game(num_players: int = 1) -> void:
	player_count = clampi(num_players, 1, 4)
	current_state = GameState.PLAYING
	run_time = 0.0
	total_kills = 0
	total_damage_dealt = 0.0
	current_wave = 1
	players.clear()
	game_started.emit()


func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		game_paused.emit(true)
	elif current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		game_paused.emit(false)


func end_game() -> void:
	current_state = GameState.GAME_OVER
	get_tree().paused = true
	var stats := {
		"run_time": run_time,
		"kills": total_kills,
		"damage_dealt": total_damage_dealt,
		"wave_reached": current_wave
	}
	game_over.emit(stats)


func register_player(player: Node2D) -> void:
	if player not in players:
		players.append(player)
		player_spawned.emit(player)


func unregister_player(player: Node2D) -> void:
	players.erase(player)
	if players.is_empty() and current_state == GameState.PLAYING:
		end_game()


func add_kill() -> void:
	total_kills += 1


func add_damage(amount: float) -> void:
	total_damage_dealt += amount


func get_formatted_time() -> String:
	var minutes := int(run_time) / 60
	var seconds := int(run_time) % 60
	return "%02d:%02d" % [minutes, seconds]
