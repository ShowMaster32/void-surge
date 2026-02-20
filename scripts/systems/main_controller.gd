extends Node2D
## MainController - Gestisce la scena di gioco principale
## AGGIORNATO: supporto multi-player, SplitScreenManager, MetaManager

@onready var zone_generator: ZoneGenerator   = $ZoneGenerator
@onready var zone_indicator                  = $ZoneIndicator
@onready var split_screen_manager: SplitScreenManager = $SplitScreenManager

## Scena del player (assegna dall'Inspector o lascia auto-load)
@export var player_scene: PackedScene

## Posizioni di spawn per i 4 player
const SPAWN_OFFSETS: Array[Vector2] = [
	Vector2(-80, 0),   # P1
	Vector2( 80, 0),   # P2
	Vector2(  0,-80),  # P3
	Vector2(  0, 80),  # P4
]


func _ready() -> void:
	# Connetti segnali zona
	if zone_generator:
		zone_generator.zone_changed.connect(_on_zone_changed)

	# Reset equipment per nuova run
	EquipmentManager.reset()

	# Leggi player_count (impostato prima da menu/lobby)
	var num_players := GameManager.player_count

	# Spawn player
	var spawned_players := _spawn_players(num_players)

	# Avvia il gioco
	GameManager.start_game(num_players)

	# Setup split screen DOPO aver spawnato i player
	# (necessario: SplitScreenManager ha bisogno dei Node2D player)
	if split_screen_manager:
		split_screen_manager.setup(num_players, spawned_players)
	else:
		push_warning("MainController: SplitScreenManager non trovato!")


func _spawn_players(count: int) -> Array:
	if not player_scene:
		player_scene = load("res://scenes/player/player.tscn")

	if not player_scene:
		push_error("MainController: player_scene non trovata!")
		return []

	var spawned: Array = []
	var center := Vector2.ZERO  # Centro schermo nel world space

	for i in count:
		var player: Player = player_scene.instantiate()
		player.player_id = i
		player.global_position = center + SPAWN_OFFSETS[i]

		# Applica colore personaggio (solo P1 usa MetaManager, gli altri usano colori co-op)
		if i == 0:
			player.apply_character_color(MetaManager.selected_character)

		add_child(player)
		spawned.append(player)

	return spawned


func _on_zone_changed(zone_data: ZoneData) -> void:
	if zone_indicator:
		zone_indicator.show_zone(zone_data)
