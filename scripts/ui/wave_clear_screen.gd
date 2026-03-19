extends CanvasLayer
## WaveClearScreen — Pannello statistiche mostrato per 2.8s tra una wave e l'altra.
## Ascolta EnemySpawner.wave_pre_clear(wave, stats) e si auto-nasconde dopo la durata.
## La chiusura emette wave_clear_done per sbloccare lo shop.

signal wave_clear_done

const SHOW_DURATION := 2.8

const C_BG   := Color(0.03, 0.02, 0.08, 0.88)
const C_ACC  := Color(0.55, 0.22, 1.00)
const C_GOLD := Color(1.00, 0.82, 0.10)
const C_HI   := Color(0.88, 0.88, 1.00)
const C_DIM  := Color(0.44, 0.44, 0.60)
const C_GRN  := Color(0.18, 1.00, 0.50)

var _root:    Control = null
var _visible: bool    = false
var _wave_souls_earned: int = 0   # accumulato durante la wave

# Statistiche correnti della wave
var _wave_kills:   int   = 0
var _wave_start_kills: int = 0
var _wave_start_time: float = 0.0


func _ready() -> void:
	layer        = 50
	visible      = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Traccia kills dall'inizio
	_wave_start_kills = GameManager.total_kills
	_wave_start_time  = GameManager.run_time

	# Connetti al segnale EnemySpawner
	_connect_spawner()


func _connect_spawner() -> void:
	await get_tree().process_frame
	var spawner := get_tree().get_first_node_in_group("enemy_spawner")
	if spawner and spawner.has_signal("wave_pre_clear"):
		spawner.wave_pre_clear.connect(_on_wave_pre_clear)


# ── Mostra schermata ──────────────────────────────────────────────────────────

func _on_wave_pre_clear(wave: int, stats: Dictionary) -> void:
	_build_panel(wave, stats)
	visible = true
	_visible = true

	# Tween entrata
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.25)
	tw.tween_interval(SHOW_DURATION - 0.45)
	tw.tween_property(_root, "modulate:a", 0.0, 0.20)
	await tw.finished

	visible  = false
	_visible = false
	# Reset kill counter per la prossima wave
	_wave_start_kills = GameManager.total_kills
	_wave_start_time  = GameManager.run_time
	wave_clear_done.emit()


func _build_panel(wave: int, stats: Dictionary) -> void:
	# Pulisce il pannello precedente
	for c in _root.get_children():
		c.queue_free()

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cc)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var sty := _mk_style(C_BG, C_ACC, 18, 2)
	sty.shadow_color = Color(0.40, 0.10, 0.90, 0.35)
	sty.shadow_size  = 20
	panel.add_theme_stylebox_override("panel", sty)
	cc.add_child(panel)

	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_left",   36)
	mg.add_theme_constant_override("margin_right",  36)
	mg.add_theme_constant_override("margin_top",    28)
	mg.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(mg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	mg.add_child(vbox)

	# ── Titolo ─────────────────────────────────────────────────────────────
	var title := _lbl("✓  WAVE %d COMPLETATA" % (wave - 1), 28, C_GOLD, 3, Color(0, 0, 0, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_hline(vbox, C_ACC, 0.45)

	# ── Stat grid ──────────────────────────────────────────────────────────
	var kills_this_wave: int = stats.get("kills_this_wave", 0)
	var wave_time: float     = stats.get("wave_time", 0.0)
	var souls_earned: int    = stats.get("souls_earned", 0)
	var damage_dealt: float  = stats.get("damage_dealt", 0.0)

	var rows: Array = [
		["☠  Nemici eliminati",  "%d" % kills_this_wave,            C_HI],
		["⏱  Tempo wave",        "%.1fs" % wave_time,               C_HI],
		["⚔  Danno inflitto",    "%d" % int(damage_dealt),          C_HI],
		["ψ  Souls guadagnate",  "+%d" % souls_earned,              C_GOLD],
	]

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation",  9)
	vbox.add_child(grid)

	for row: Array in rows:
		grid.add_child(_lbl(row[0] as String, 16, C_DIM))
		var val := _lbl(row[1] as String, 18, row[2] as Color, 1, Color(0, 0, 0, 0.8))
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)

	_hline(vbox, C_ACC, 0.25)

	# ── Prossima wave ──────────────────────────────────────────────────────
	var next_lbl := _lbl("▶  WAVE %d  in arrivo..." % wave, 15, C_DIM)
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(next_lbl)

	# ── Barra progresso countdown ─────────────────────────────────────────
	var prog := ProgressBar.new()
	prog.min_value        = 0
	prog.max_value        = 100
	prog.value            = 100
	prog.show_percentage  = false
	prog.custom_minimum_size = Vector2(0, 6)
	prog.add_theme_stylebox_override("fill",
		_mk_style(C_ACC, Color.TRANSPARENT, 3, 0))
	prog.add_theme_stylebox_override("background",
		_mk_style(Color(0.10, 0.05, 0.20), Color.TRANSPARENT, 3, 0))
	vbox.add_child(prog)

	# Anima la barra da 100 → 0 in SHOW_DURATION
	var tw2 := create_tween()
	tw2.tween_property(prog, "value", 0.0, SHOW_DURATION - 0.1)


# ── Helper ───────────────────────────────────────────────────────────────────

func _mk_style(bg: Color, border: Color, radius: int, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                   = bg
	s.border_color               = border
	s.border_width_left          = bw
	s.border_width_right         = bw
	s.border_width_top           = bw
	s.border_width_bottom        = bw
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	s.anti_aliasing = true
	return s


func _lbl(txt: String, sz: int, col: Color,
		outline: int = 0, out_col: Color = Color.BLACK) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", out_col)
	return l


func _hline(parent: Control, col: Color, alpha: float = 0.4) -> void:
	var r := ColorRect.new()
	r.color               = Color(col.r, col.g, col.b, alpha)
	r.custom_minimum_size = Vector2(0, 2)
	parent.add_child(r)
