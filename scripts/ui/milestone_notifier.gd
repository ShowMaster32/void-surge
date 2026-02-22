extends CanvasLayer
class_name MilestoneNotifier
## MilestoneNotifier - Toast centrali per wave, zone, kill e tempo
## Comunica al giocatore il senso del gioco: sopravvivi alle Void Surge
## AGGIORNATO: aggiunto sistema di notifiche pickup equipment (basso-sinistra)

const KILL_MILESTONES: Array[int]    = [10, 25, 50, 100, 200, 500]
const TIME_MILESTONES: Array[float]  = [60.0, 120.0, 300.0, 600.0]
const TIME_LABELS: Array[String]     = [
	"1 MINUTE SURVIVED!",
	"2 MINUTES SURVIVED!",
	"5 MINUTES SURVIVED!",
	"10 MINUTES SURVIVED!",
]

## Toast centrali (wave, kill, time)
const TOAST_DURATION  := 2.8
const TOAST_FADE_IN   := 0.18
const TOAST_FADE_OUT  := 0.4
const TOAST_SPACING   := 62.0
const TOAST_ORIGIN_Y  := 90.0

## Toast pickup equipment (in basso a sinistra)
const PICKUP_DURATION           := 3.5
const PICKUP_FADE_IN            := 0.15
const PICKUP_FADE_OUT           := 0.45
const PICKUP_SPACING            := 72.0
const PICKUP_MARGIN_LEFT        := 16.0
const PICKUP_MARGIN_FROM_BOTTOM := 130.0   ## distanza dal bordo inferiore

var _kill_milestone_idx: int = 0
var _time_milestone_idx: int = 0
var _toasts: Array[Control]        = []
var _pickup_toasts: Array[Control] = []

var _enemy_spawner: Node   = null
var _zone_generator: Node  = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	await get_tree().process_frame

	_enemy_spawner  = get_node_or_null("/root/Main/EnemySpawner")
	_zone_generator = get_tree().get_first_node_in_group("zone_generator")

	if _enemy_spawner and _enemy_spawner.has_signal("wave_changed"):
		_enemy_spawner.wave_changed.connect(_on_wave_changed)

	if _zone_generator and _zone_generator.has_signal("zone_changed"):
		_zone_generator.zone_changed.connect(_on_zone_changed)

	GameManager.game_started.connect(_on_game_started)
	EquipmentManager.equipment_collected.connect(_on_equipment_collected)


func _process(_delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Kill milestones
	if _kill_milestone_idx < KILL_MILESTONES.size():
		if GameManager.total_kills >= KILL_MILESTONES[_kill_milestone_idx]:
			_show_kill_toast(KILL_MILESTONES[_kill_milestone_idx])
			_kill_milestone_idx += 1

	# Time milestones
	if _time_milestone_idx < TIME_MILESTONES.size():
		if GameManager.run_time >= TIME_MILESTONES[_time_milestone_idx]:
			_show_time_toast(TIME_LABELS[_time_milestone_idx])
			_time_milestone_idx += 1


func _on_game_started() -> void:
	_kill_milestone_idx = 0
	_time_milestone_idx = 0
	for toast in _toasts:
		if is_instance_valid(toast):
			toast.queue_free()
	_toasts.clear()
	for toast in _pickup_toasts:
		if is_instance_valid(toast):
			toast.queue_free()
	_pickup_toasts.clear()


# ---------------------------------------------------------------------------
# TOAST CENTRALI (wave / kill / time)
# ---------------------------------------------------------------------------

func _on_wave_changed(wave: int) -> void:
	var t := clampf(float(wave - 2) / 10.0, 0.0, 1.0)
	var color := Color(1.0, lerp(0.9, 0.2, t), lerp(0.2, 0.1, t))
	_spawn_toast("WAVE %d" % wave, color, 42)


func _on_zone_changed(zone_data: ZoneData) -> void:
	_spawn_toast("ZONE: %s" % zone_data.zone_name.to_upper(), zone_data.glow_color, 28)


func _show_kill_toast(count: int) -> void:
	_spawn_toast("%d KILLS!" % count, Color(0.2, 1.0, 0.7), 30)


func _show_time_toast(label: String) -> void:
	_spawn_toast(label, Color(0.7, 0.4, 1.0), 26)


func _spawn_toast(text: String, color: Color, font_size: int) -> void:
	_toasts = _toasts.filter(func(t): return is_instance_valid(t))
	var vp_width := get_viewport().get_visible_rect().size.x

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color             = Color(0.04, 0.01, 0.12, 0.92)
	style.border_color         = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left   = 18.0
	style.content_margin_right  = 18.0
	style.content_margin_top    = 7.0
	style.content_margin_bottom = 7.0
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(lbl)
	add_child(panel)

	await get_tree().process_frame
	if not is_instance_valid(panel):
		return

	panel.position.x = vp_width / 2.0 - panel.size.x / 2.0
	panel.position.y = TOAST_ORIGIN_Y + _toasts.size() * TOAST_SPACING
	panel.modulate.a = 0.0
	panel.scale      = Vector2(0.85, 0.85)
	_toasts.append(panel)

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, TOAST_FADE_IN)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, TOAST_FADE_IN)
	tween.tween_interval(TOAST_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, TOAST_FADE_OUT)
	tween.tween_callback(panel.queue_free)


# ---------------------------------------------------------------------------
# TOAST PICKUP EQUIPMENT (in basso a sinistra)
# ---------------------------------------------------------------------------

func _on_equipment_collected(equipment: EquipmentData) -> void:
	if not equipment:
		return
	_spawn_pickup_toast(equipment)


func _spawn_pickup_toast(equipment: EquipmentData) -> void:
	_pickup_toasts = _pickup_toasts.filter(func(t): return is_instance_valid(t))

	var vp_height     := get_viewport().get_visible_rect().size.y
	var rarity_color  := equipment.get_rarity_color()
	var rarity_name   := equipment.get_rarity_name().to_upper()
	var stats_text    := equipment.get_stats_summary()

	# Icona tipo equipment (simbolo)
	var type_symbol: String
	match equipment.equipment_type:
		EquipmentData.EquipmentType.WEAPON:  type_symbol = "◆"  # diamante
		EquipmentData.EquipmentType.ARMOR:   type_symbol = "▲"  # scudo/triangolo
		EquipmentData.EquipmentType.UTILITY: type_symbol = "●"  # cerchio
		EquipmentData.EquipmentType.SPECIAL: type_symbol = "★"  # stella
		_:                                   type_symbol = "◇"

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color             = Color(0.03, 0.01, 0.10, 0.95)
	style.border_color         = rarity_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 12.0
	style.content_margin_right  = 14.0
	style.content_margin_top    = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Riga 1: simbolo + nome + rarità
	var title_lbl := Label.new()
	title_lbl.text = "%s  %s" % [type_symbol, equipment.equipment_name]
	title_lbl.add_theme_color_override("font_color", equipment.glow_color)
	title_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title_lbl)

	# Riga 2: rarità badge colorato
	var rarity_lbl := Label.new()
	rarity_lbl.text = rarity_name
	rarity_lbl.add_theme_color_override("font_color", rarity_color)
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(rarity_lbl)

	# Riga 3: stats (se non vuote)
	if stats_text != "No bonuses":
		var stats_lbl := Label.new()
		stats_lbl.text = stats_text
		stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		stats_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(stats_lbl)

	add_child(panel)

	# Posiziona in basso a sinistra, impilato verso l'alto
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return

	var stack_offset := _pickup_toasts.size() * PICKUP_SPACING
	panel.position.x = PICKUP_MARGIN_LEFT
	panel.position.y = vp_height - PICKUP_MARGIN_FROM_BOTTOM - panel.size.y - stack_offset
	panel.modulate.a = 0.0
	panel.scale      = Vector2(0.8, 0.8)
	_pickup_toasts.append(panel)

	# Slide-in da sinistra
	panel.position.x = -panel.size.x - 10.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "modulate:a", 1.0, PICKUP_FADE_IN)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, PICKUP_FADE_IN)
	tween.parallel().tween_property(panel, "position:x", PICKUP_MARGIN_LEFT, PICKUP_FADE_IN)
	tween.tween_interval(PICKUP_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, PICKUP_FADE_OUT)
	tween.tween_callback(panel.queue_free)
