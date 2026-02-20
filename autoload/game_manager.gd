extends Node
## GameManager - Gestisce lo stato globale del gioco
## Autoload singleton accessibile ovunque come GameManager

signal game_started
signal game_paused(is_paused: bool)
signal game_over(stats: Dictionary)
signal player_spawned(player: Node2D)
signal coop_synergy_active(active: bool)  ## NUOVO: segnala synergy co-op

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var current_state: GameState = GameState.MENU
var run_time: float = 0.0
var total_kills: int = 0
var total_damage_dealt: float = 0.0
var current_wave: int = 1

# Player references per co-op
var players: Array[Node2D] = []
var player_count: int = 1

# NUOVO: Co-op synergy
const COOP_SYNERGY_RANGE := 200.0       ## Distanza entro cui scatta il bonus
const COOP_SYNERGY_BONUS := 0.10        ## +10% danno quando vicini
var coop_synergy_enabled: bool = false  ## True se almeno 2 player sono vicini

# NUOVO: timer per check synergy (non ogni frame per performance)
var _synergy_check_timer: float = 0.0
const SYNERGY_CHECK_INTERVAL := 0.25   ## Check ogni 250ms


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		run_time += delta
		_update_coop_synergy(delta)


## NUOVO: controlla se i player sono vicini per attivare la synergy co-op
func _update_coop_synergy(delta: float) -> void:
	if player_count < 2:
		return

	_synergy_check_timer += delta
	if _synergy_check_timer < SYNERGY_CHECK_INTERVAL:
		return
	_synergy_check_timer = 0.0

	var was_active := coop_synergy_enabled
	coop_synergy_enabled = false

	# Controlla se almeno 2 player sono entro la distanza
	for i in players.size():
		for j in range(i + 1, players.size()):
			if not is_instance_valid(players[i]) or not is_instance_valid(players[j]):
				continue
			var dist := players[i].global_position.distance_to(players[j].global_position)
			if dist <= COOP_SYNERGY_RANGE:
				coop_synergy_enabled = true
				break
		if coop_synergy_enabled:
			break

	# Emetti segnale solo se cambia stato
	if coop_synergy_enabled != was_active:
		coop_synergy_active.emit(coop_synergy_enabled)


func start_game(num_players: int = 1) -> void:
	player_count = clampi(num_players, 1, 4)
	current_state = GameState.PLAYING
	run_time = 0.0
	total_kills = 0
	total_damage_dealt = 0.0
	current_wave = 1
	coop_synergy_enabled = false
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

	# NUOVO: notifica MetaManager per XP e unlock
	if Engine.has_singleton("MetaManager") or get_node_or_null("/root/MetaManager") != null:
		var meta := get_node("/root/MetaManager")
		meta.on_run_complete(false, current_wave, total_kills)

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


## NUOVO: restituisce il bonus danno co-op se attivo
func get_coop_damage_bonus() -> float:
	return COOP_SYNERGY_BONUS if coop_synergy_enabled else 0.0
