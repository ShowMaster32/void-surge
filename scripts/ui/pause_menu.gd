extends CanvasLayer
class_name PauseMenu
## PauseMenu - Menu di pausa con resume, settings, quit

signal resumed
signal quit_to_menu

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var resume_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $CenterContainer/PanelContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/VBoxContainer/QuitButton
@onready var settings_panel: PanelContainer = $CenterContainer/SettingsPanel
@onready var master_slider: HSlider = $CenterContainer/SettingsPanel/VBoxContainer/MasterVolume/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/SettingsPanel/VBoxContainer/MusicVolume/MusicSlider
@onready var sfx_slider: HSlider = $CenterContainer/SettingsPanel/VBoxContainer/SFXVolume/SFXSlider
@onready var back_button: Button = $CenterContainer/SettingsPanel/VBoxContainer/BackButton

var is_paused: bool = false
var showing_settings: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connetti segnali GameManager
	GameManager.game_paused.connect(_on_game_paused)
	
	# Connetti pulsanti
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Connetti slider (audio - da implementare completamente)
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# Nascondi settings panel inizialmente
	if settings_panel:
		settings_panel.visible = false


func _on_game_paused(paused: bool) -> void:
	is_paused = paused
	visible = paused
	showing_settings = false
	
	if paused:
		panel.visible = true
		if settings_panel:
			settings_panel.visible = false
		resume_button.grab_focus()


func _on_resume_pressed() -> void:
	GameManager.toggle_pause()
	resumed.emit()


func _on_settings_pressed() -> void:
	showing_settings = true
	panel.visible = false
	if settings_panel:
		settings_panel.visible = true
		back_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	# Per ora ricarica, in futuro torna al menu
	get_tree().reload_current_scene()
	quit_to_menu.emit()


func _on_back_pressed() -> void:
	showing_settings = false
	if settings_panel:
		settings_panel.visible = false
	panel.visible = true
	resume_button.grab_focus()


func _on_master_volume_changed(value: float) -> void:
	# Imposta volume master (db lineare: 0 = -80db, 1 = 0db)
	var db := linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)


func _on_music_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))


func _on_sfx_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
