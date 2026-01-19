extends CanvasLayer
class_name DeathScreen
## DeathScreen - Schermata di morte con stats finali

signal retry_pressed
signal menu_pressed

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var stats_container: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/StatsContainer
@onready var time_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatsContainer/TimeLabel
@onready var kills_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatsContainer/KillsLabel
@onready var wave_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatsContainer/WaveLabel
@onready var damage_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatsContainer/DamageLabel
@onready var retry_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonsContainer/RetryButton
@onready var menu_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonsContainer/MenuButton

var is_visible: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connetti segnali
	GameManager.game_over.connect(_on_game_over)
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


func _on_game_over(stats: Dictionary) -> void:
	show_death_screen(stats)


func show_death_screen(stats: Dictionary) -> void:
	is_visible = true
	visible = true
	
	# Popola stats
	time_label.text = "TIME: %s" % _format_time(stats.get("run_time", 0.0))
	kills_label.text = "KILLS: %d" % stats.get("kills", 0)
	wave_label.text = "WAVE REACHED: %d" % stats.get("wave_reached", 1)
	damage_label.text = "DAMAGE DEALT: %d" % int(stats.get("damage_dealt", 0.0))
	
	# Focus sul pulsante retry
	retry_button.grab_focus()


func hide_death_screen() -> void:
	is_visible = false
	visible = false


func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d" % [mins, secs]


func _on_retry_pressed() -> void:
	hide_death_screen()
	get_tree().paused = false
	get_tree().reload_current_scene()
	retry_pressed.emit()


func _on_menu_pressed() -> void:
	hide_death_screen()
	get_tree().paused = false
	# Per ora ricarica la scena, in futuro andrà al menu principale
	get_tree().reload_current_scene()
	menu_pressed.emit()
