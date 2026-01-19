extends CanvasLayer
class_name HUD
## HUD - Interfaccia in-game minimalista
## Mostra HP, wave, timer, kills, zona

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthBar/HealthLabel
@onready var wave_label: Label = $MarginContainer/VBoxContainer/WaveLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/TimerLabel
@onready var kills_label: Label = $MarginContainer/VBoxContainer/KillsLabel
@onready var zone_label: Label = $MarginContainer/VBoxContainer/ZoneLabel

var tracked_player: Player
var zone_generator: ZoneGenerator


func _ready() -> void:
	# Connetti ai segnali di GameManager
	GameManager.player_spawned.connect(_on_player_spawned)
	GameManager.game_over.connect(_on_game_over)
	
	# Trova ZoneGenerator
	await get_tree().process_frame
	zone_generator = get_tree().get_first_node_in_group("zone_generator") as ZoneGenerator
	if zone_generator:
		zone_generator.zone_changed.connect(_on_zone_changed)


func _process(_delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		_update_timer()
		_update_kills()
		_update_wave()


func _on_player_spawned(player: Node2D) -> void:
	if player is Player and tracked_player == null:
		tracked_player = player
		tracked_player.health_changed.connect(_on_health_changed)
		# Inizializza health bar
		health_bar.max_value = tracked_player.max_health
		health_bar.value = tracked_player.current_health
		_update_health_label()


func _on_health_changed(current: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current
	_update_health_label()


func _on_zone_changed(zone_data: ZoneData) -> void:
	if zone_label and zone_data:
		zone_label.text = zone_data.zone_name.to_upper()
		zone_label.add_theme_color_override("font_color", zone_data.glow_color)


func _update_health_label() -> void:
	if health_label and tracked_player:
		health_label.text = "%d / %d" % [int(tracked_player.current_health), int(tracked_player.max_health)]


func _update_timer() -> void:
	if timer_label:
		timer_label.text = "TIME: %s" % GameManager.get_formatted_time()


func _update_kills() -> void:
	if kills_label:
		kills_label.text = "KILLS: %d" % GameManager.total_kills


func _update_wave() -> void:
	if wave_label:
		wave_label.text = "WAVE %d" % GameManager.current_wave


func _on_game_over(_stats: Dictionary) -> void:
	# Potrebbe mostrare messaggio game over
	pass
