extends CanvasLayer
class_name HUD
## HUD - Interfaccia in-game: health, wave, timer, kills, souls, nemici, wave progress

@onready var health_bar: ProgressBar       = $HUDPanel/InnerMargin/VBoxContainer/HealthBar
@onready var health_label: Label           = $HUDPanel/InnerMargin/VBoxContainer/HealthBar/HealthLabel
@onready var wave_label: Label             = $HUDPanel/InnerMargin/VBoxContainer/TopRow/WaveLabel
@onready var timer_label: Label            = $HUDPanel/InnerMargin/VBoxContainer/BottomRow/TimerLabel
@onready var kills_label: Label            = $HUDPanel/InnerMargin/VBoxContainer/BottomRow/KillsLabel
@onready var zone_label: Label             = $HUDPanel/InnerMargin/VBoxContainer/TopRow/ZoneLabel
@onready var wave_progress_bar: ProgressBar = $HUDPanel/InnerMargin/VBoxContainer/WaveProgressBar
@onready var souls_label: Label            = $HUDPanel/InnerMargin/VBoxContainer/InfoRow/SoulsLabel
@onready var enemies_label: Label          = $HUDPanel/InnerMargin/VBoxContainer/InfoRow/EnemiesLabel

var tracked_player: Player
var zone_generator: ZoneGenerator
var _enemy_spawner: Node       ## Riferimento a EnemySpawner per leggere wave_timer
var _health_fill_style: StyleBoxFlat

## Feedback visivo danno ambientale
var _hazard_overlay: ColorRect   ## Flash rosso a schermo quando colpisce un hazard
var _hazard_label: Label          ## Label "⚠ ZONA PERICOLOSA" mostrata in hazard zone


func _ready() -> void:
	GameManager.player_spawned.connect(_on_player_spawned)
	GameManager.game_over.connect(_on_game_over)

	# Stile fill dinamico health bar
	_health_fill_style = StyleBoxFlat.new()
	_health_fill_style.bg_color = Color(0.1, 0.85, 0.35)
	_health_fill_style.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("fill", _health_fill_style)

	await get_tree().process_frame

	zone_generator = get_tree().get_first_node_in_group("zone_generator") as ZoneGenerator
	if zone_generator:
		zone_generator.zone_changed.connect(_on_zone_changed)
		zone_generator.hazard_hit.connect(_on_hazard_hit)

	# Trova EnemySpawner per leggere wave_timer
	_enemy_spawner = get_node_or_null("/root/Main/EnemySpawner")

	# Flash rosso a schermo per danno hazard (creato a runtime nel CanvasLayer)
	_hazard_overlay = ColorRect.new()
	_hazard_overlay.color = Color(0.9, 0.05, 0.05, 0.0)
	_hazard_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hazard_overlay.z_index = 10
	var vp_size := get_viewport().get_visible_rect().size
	_hazard_overlay.size = vp_size
	add_child(_hazard_overlay)

	# Label warning zona pericolosa
	_hazard_label = Label.new()
	_hazard_label.text = "⚠  ZONA PERICOLOSA  ⚠"
	_hazard_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.1))
	_hazard_label.add_theme_font_size_override("font_size", 16)
	_hazard_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hazard_label.offset_top = 8
	_hazard_label.offset_left = -120
	_hazard_label.visible = false
	add_child(_hazard_label)


func _process(_delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		_update_timer()
		_update_kills()
		_update_wave()
		_update_wave_progress()
		_update_souls()
		_update_enemies()


func _on_player_spawned(player: Node2D) -> void:
	if player is Player and tracked_player == null:
		tracked_player = player
		tracked_player.health_changed.connect(_on_health_changed)
		health_bar.max_value = tracked_player.max_health
		health_bar.value = tracked_player.current_health
		_update_health_label()


func _on_health_changed(current: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current
	_update_health_label()
	_update_health_bar_color(current / max(max_hp, 1.0))


## Colore fill barra HP: verde → giallo → rosso in base alla percentuale
func _update_health_bar_color(percent: float) -> void:
	if not _health_fill_style:
		return
	if percent > 0.6:
		_health_fill_style.bg_color = Color(0.1, 0.85, 0.35)
	elif percent > 0.3:
		_health_fill_style.bg_color = Color(1.0, 0.75, 0.1)
	else:
		_health_fill_style.bg_color = Color(0.95, 0.2, 0.2)


func _on_zone_changed(zone_data: ZoneData) -> void:
	if zone_label and zone_data:
		var name_text := zone_data.zone_name.to_upper()
		if zone_data.hazard_enabled:
			name_text += "  ⚠"
		zone_label.text = name_text
		zone_label.add_theme_color_override("font_color", zone_data.glow_color)

	# Mostra/nasconde label avvertimento hazard
	if _hazard_label:
		_hazard_label.visible = zone_data.hazard_enabled if zone_data else false


## Flash rosso a schermo quando la zona applica danno ambientale
func _on_hazard_hit(_damage: float) -> void:
	if not _hazard_overlay:
		return
	var tween := create_tween()
	tween.tween_property(_hazard_overlay, "color:a", 0.35, 0.06)
	tween.tween_property(_hazard_overlay, "color:a", 0.0,  0.55)


func _update_health_label() -> void:
	if health_label and tracked_player:
		health_label.text = "%d / %d" % [
			int(tracked_player.current_health),
			int(tracked_player.max_health)
		]


func _update_timer() -> void:
	if timer_label:
		timer_label.text = GameManager.get_formatted_time()


func _update_kills() -> void:
	if kills_label:
		kills_label.text = "%d kills" % GameManager.total_kills


func _update_wave() -> void:
	if wave_label:
		wave_label.text = "WAVE %d" % GameManager.current_wave


## Barra sottile che riempie i 30 secondi fino alla prossima wave
func _update_wave_progress() -> void:
	if not wave_progress_bar or not _enemy_spawner:
		return
	var duration: float = _enemy_spawner.wave_duration if _enemy_spawner.get("wave_duration") != null else 30.0
	var timer: float    = _enemy_spawner.wave_timer    if _enemy_spawner.get("wave_timer")    != null else 0.0
	wave_progress_bar.value = clampf((timer / duration) * 100.0, 0.0, 100.0)


## Souls = kills × 2 + wave_reached × 10 (formula MetaManager)
func _update_souls() -> void:
	if souls_label:
		var souls := GameManager.total_kills * 2 + GameManager.current_wave * 10
		souls_label.text = "SOULS: %d" % souls


## Nemici attivi su schermo letti da EnemySpawner
func _update_enemies() -> void:
	if not enemies_label:
		return
	if _enemy_spawner and _enemy_spawner.has_method("get_enemy_count"):
		enemies_label.text = "%d enemies" % _enemy_spawner.get_enemy_count()
	else:
		enemies_label.text = ""


func _on_game_over(_stats: Dictionary) -> void:
	pass
