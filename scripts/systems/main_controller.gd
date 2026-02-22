extends Node2D
## MainController - Gestisce la scena di gioco principale
## AGGIORNATO: supporto multi-player, SplitScreenManager, MetaManager

@onready var zone_generator: ZoneGenerator   = $ZoneGenerator
@onready var zone_indicator                  = $ZoneIndicator
@onready var split_screen_manager: SplitScreenManager = $SplitScreenManager

## Scena del player (assegna dall'Inspector)
@export var player_scene: PackedScene
## Scena del proiettile — deve essere assegnata dall'Inspector (main.tscn)
@export var projectile_scene: PackedScene

## Posizioni di spawn per i 4 player
const SPAWN_OFFSETS: Array[Vector2] = [
	Vector2(-80, 0),   # P1
	Vector2( 80, 0),   # P2
	Vector2(  0,-80),  # P3
	Vector2(  0, 80),  # P4
]

var _num_players: int = 1
var _spawned_players: Array = []


func _ready() -> void:
	# Connetti segnali zona
	if zone_generator:
		zone_generator.zone_changed.connect(_on_zone_changed)

	# Reset equipment per nuova run
	EquipmentManager.reset()

	# Leggi player_count (impostato prima da menu/lobby)
	_num_players = GameManager.player_count

	# Spawn player
	_spawned_players = _spawn_players(_num_players)

	# Setup split screen DOPO aver spawnato i player
	# (necessario: SplitScreenManager ha bisogno dei Node2D player)
	if split_screen_manager:
		split_screen_manager.setup(_num_players, _spawned_players)
	else:
		push_warning("MainController: SplitScreenManager non trovato!")

	# Non avviamo il gioco qui: aspettiamo begin_game() dalla StartScreen


func begin_game() -> void:
	## Chiamato dalla StartScreen quando il giocatore clicca "Inizia Partita"
	GameManager.start_game(_num_players)
	_setup_camera_limits()


func _setup_camera_limits() -> void:
	## Imposta i limiti della Camera2D entro i confini del mondo
	var half_w := int(zone_generator.zone_size.x / 2) if zone_generator else 1500
	var half_h := int(zone_generator.zone_size.y / 2) if zone_generator else 1500

	for player in _spawned_players:
		if not is_instance_valid(player):
			continue
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_left   = -half_w
			cam.limit_right  =  half_w
			cam.limit_top    = -half_h
			cam.limit_bottom =  half_h


func _spawn_players(count: int) -> Array:
	if not player_scene:
		player_scene = load("res://scenes/player/player.tscn")
	if not projectile_scene:
		projectile_scene = load("res://scenes/projectiles/projectile.tscn")

	if not player_scene:
		push_error("MainController: player_scene non trovata!")
		return []

	var spawned: Array = []
	var center := Vector2.ZERO  # Centro del world space (origine)

	for i in count:
		var player: Player = player_scene.instantiate()
		player.player_id = i
		player.global_position = center + SPAWN_OFFSETS[i]
		player.projectile_scene = projectile_scene

		# Applica colore personaggio (solo P1 usa MetaManager, gli altri usano colori co-op)
		if i == 0:
			player.apply_character_color(MetaManager.selected_character)

		add_child(player)
		spawned.append(player)

	return spawned


func _on_zone_changed(zone_data: ZoneData) -> void:
	if zone_indicator:
		zone_indicator.show_zone(zone_data)
