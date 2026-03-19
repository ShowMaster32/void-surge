extends CanvasLayer
class_name DeathScreen
## DeathScreen - Schermata di morte/vittoria con stats finali e classifica

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
var _lb_container: VBoxContainer = null   # leaderboard iniettato runtime


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	GameManager.game_over.connect(_on_game_over)
	GameManager.game_won.connect(_on_game_won)
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


func _on_game_over(stats: Dictionary) -> void:
	show_death_screen(stats, false)


func _on_game_won(stats: Dictionary) -> void:
	show_death_screen(stats, true)


func show_death_screen(stats: Dictionary, victory: bool = false) -> void:
	is_visible = true
	visible = true

	# ── Titolo e stile pannello ────────────────────────────────────────────────
	if victory:
		title_label.text = "VOID SOVEREIGN DEFEATED"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.02, 0.01, 0.96)
		style.border_color = Color(1.0, 0.75, 0.0)
		style.set_border_width_all(3)
		style.set_corner_radius_all(10)
		panel.add_theme_stylebox_override("panel", style)
	else:
		title_label.text = "YOU DIED"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

	# ── Stats run ─────────────────────────────────────────────────────────────
	time_label.text   = "TIME: %s"         % _format_time(stats.get("run_time", 0.0))
	kills_label.text  = "KILLS: %d"        % stats.get("kills", 0)
	wave_label.text   = "WAVE REACHED: %d" % stats.get("wave_reached", 1)
	damage_label.text = "DAMAGE DEALT: %d" % int(stats.get("damage_dealt", 0.0))

	# ── Leaderboard ───────────────────────────────────────────────────────────
	var rank: int = ScoreManager.submit(stats, victory)
	_build_leaderboard(rank, victory)

	retry_button.grab_focus()


func _build_leaderboard(player_rank: int, victory: bool) -> void:
	# Rimuovi leaderboard precedente se esiste
	if is_instance_valid(_lb_container):
		_lb_container.queue_free()
		_lb_container = null

	var vbox: VBoxContainer = panel.get_node_or_null("VBoxContainer") as VBoxContainer
	if not vbox:
		return

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)
	vbox.move_child(sep, vbox.get_child_count() - 3)   # sopra i bottoni

	_lb_container = VBoxContainer.new()
	_lb_container.add_theme_constant_override("separation", 3)
	vbox.add_child(_lb_container)
	vbox.move_child(_lb_container, vbox.get_child_count() - 3)

	# Titolo classifica
	var header := Label.new()
	header.text = "— TOP SCORES —"
	header.add_theme_font_size_override("font_size", 14)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lb_title_col := Color(1.0, 0.85, 0.0) if victory else Color(0.7, 0.5, 1.0)
	header.add_theme_color_override("font_color", lb_title_col)
	_lb_container.add_child(header)

	# Rank annuncio
	if player_rank >= 1:
		var rank_lbl := Label.new()
		rank_lbl.text = "YOUR RANK: #%d" % player_rank
		rank_lbl.add_theme_font_size_override("font_size", 13)
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
		_lb_container.add_child(rank_lbl)

	# Voci top-5
	var entries: Array = ScoreManager.get_entries()
	var show_count: int = mini(5, entries.size())
	for i in show_count:
		var e: Dictionary = entries[i]
		var is_me: bool   = (i + 1 == player_rank)
		var row := Label.new()
		var crown: String = "★ " if is_me else "   "
		var vic_tag: String = " [V]" if e.get("victory", false) else ""
		row.text = "%s#%d  %s  W%d  K%d%s" % [
			crown, i + 1,
			_format_score(e.get("score", 0)),
			e.get("wave", 1),
			e.get("kills", 0),
			vic_tag,
		]
		row.add_theme_font_size_override("font_size", 12)
		var row_col: Color
		if is_me:
			row_col = Color(1.0, 0.9, 0.3)
		elif i == 0:
			row_col = Color(1.0, 0.75, 0.2)
		else:
			row_col = Color(0.75, 0.75, 0.85)
		row.add_theme_color_override("font_color", row_col)
		_lb_container.add_child(row)


func _format_score(score: int) -> String:
	if score >= 1_000_000:
		return "%.1fM" % (score / 1_000_000.0)
	if score >= 1_000:
		return "%.1fK" % (score / 1_000.0)
	return str(score)


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
	get_tree().reload_current_scene()
	menu_pressed.emit()
