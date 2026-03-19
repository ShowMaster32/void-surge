extends CanvasLayer
class_name PauseMenu
## PauseMenu - Resume / Settings / Controls / Quit

signal resumed
signal quit_to_menu

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var resume_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $CenterContainer/PanelContainer/VBoxContainer/SettingsButton
@onready var controls_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ControlsButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/VBoxContainer/QuitButton

@onready var settings_panel: PanelContainer = $CenterContainer/SettingsPanel
@onready var master_slider: HSlider = $CenterContainer/SettingsPanel/VBoxContainer/MasterVolume/MasterSlider
@onready var music_slider: HSlider = $CenterContainer/SettingsPanel/VBoxContainer/MusicVolume/MusicSlider
@onready var sfx_slider: HSlider = $CenterContainer/SettingsPanel/VBoxContainer/SFXVolume/SFXSlider
@onready var back_button: Button = $CenterContainer/SettingsPanel/VBoxContainer/BackButton

const SETTINGS_PATH := "user://settings.cfg"

@onready var controls_panel: PanelContainer = $CenterContainer/ControlsPanel
@onready var controls_back_button: Button = $CenterContainer/ControlsPanel/VBoxContainer/ControlsBackButton

var is_paused: bool = false
var showing_settings: bool = false
var showing_controls: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)

	GameManager.game_paused.connect(_on_game_paused)

	# Bottoni menu principale
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Bottoni pannello Settings
	back_button.pressed.connect(_on_back_pressed)
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	# Bottone pannello Controls
	controls_back_button.pressed.connect(_on_controls_back_pressed)

	# Nasconde tutti i sotto-pannelli all'avvio
	if settings_panel:
		settings_panel.visible = false
	if controls_panel:
		controls_panel.visible = false

	# Carica e applica impostazioni salvate
	_load_settings()


func _unhandled_input(event: InputEvent) -> void:
	if not is_paused:
		return
	if not (event is InputEventJoypadButton):
		return
	var jb := event as InputEventJoypadButton
	if not jb.pressed:
		return
	match jb.button_index:
		JOY_BUTTON_START:
			# Start riprende il gioco (toggles pause)
			get_viewport().set_input_as_handled()
			if showing_settings:
				_on_back_pressed()
			elif showing_controls:
				_on_controls_back_pressed()
			else:
				_on_resume_pressed()
		JOY_BUTTON_B:
			# B/○ = back (o riprende se nel pannello principale)
			get_viewport().set_input_as_handled()
			if showing_settings:
				_on_back_pressed()
			elif showing_controls:
				_on_controls_back_pressed()
			else:
				_on_resume_pressed()
		JOY_BUTTON_A:
			# A/X = conferma il bottone attualmente in focus
			get_viewport().set_input_as_handled()
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and not (focused as Button).disabled:
				(focused as Button).pressed.emit()


func _on_game_paused(paused: bool) -> void:
	is_paused = paused
	visible = paused
	showing_settings = false
	showing_controls = false

	if paused:
		panel.visible = true
		if settings_panel:
			settings_panel.visible = false
		if controls_panel:
			controls_panel.visible = false
		# Salvataggio automatico alla pausa
		var run_saver := get_node_or_null("/root/RunSaver")
		if run_saver and run_saver.has_method("save_run"):
			run_saver.save_run()
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


func _on_controls_pressed() -> void:
	showing_controls = true
	panel.visible = false
	if controls_panel:
		controls_panel.visible = true
		controls_back_button.grab_focus()


func _on_back_pressed() -> void:
	showing_settings = false
	if settings_panel:
		settings_panel.visible = false
	panel.visible = true
	resume_button.grab_focus()


func _on_controls_back_pressed() -> void:
	showing_controls = false
	if controls_panel:
		controls_panel.visible = false
	panel.visible = true
	resume_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
	quit_to_menu.emit()


func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	_save_settings()


func _on_music_volume_changed(value: float) -> void:
	# Lo slider "Music" controlla il bus Ambient (drone)
	var bus_idx := AudioServer.get_bus_index("Ambient")
	if bus_idx < 0:
		bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	_save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	_save_settings()


# ── Persistenza impostazioni ────────────────────────────────────────────────────

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_slider.value)
	cfg.set_value("audio", "ambient", music_slider.value)
	cfg.set_value("audio", "sfx",    sfx_slider.value)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		# Prima volta: imposta valori di default ragionevoli
		master_slider.value = 0.85
		music_slider.value  = 0.55
		sfx_slider.value    = 0.80
		_on_master_volume_changed(master_slider.value)
		_on_music_volume_changed(music_slider.value)
		_on_sfx_volume_changed(sfx_slider.value)
		return

	master_slider.value = cfg.get_value("audio", "master",  0.85)
	music_slider.value  = cfg.get_value("audio", "ambient", 0.55)
	sfx_slider.value    = cfg.get_value("audio", "sfx",     0.80)
	_on_master_volume_changed(master_slider.value)
	_on_music_volume_changed(music_slider.value)
	_on_sfx_volume_changed(sfx_slider.value)
