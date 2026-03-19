extends Node
## BossHUD — overlay CanvasLayer che mostra la health bar del boss corrente.
## Istanziato a runtime da EnemySpawner._spawn_boss(). Si auto-distrugge alla morte del boss.

var _canvas:     CanvasLayer
var _name_lbl:   Label
var _bar_fill:   Panel
var _fill_style: StyleBoxFlat
var _phase_lbl:  Label
var _boss_ref:   Node = null

const BAR_W := 480.0
const BAR_H := 22.0


func setup(boss: Node) -> void:
	_boss_ref = boss
	if boss.has_signal("phase_changed"):
		boss.phase_changed.connect(_on_phase_changed)
	_build_ui()


func _build_ui() -> void:
	_canvas           = CanvasLayer.new()
	_canvas.layer     = 25
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)

	# ── Pannello centrato in alto (sotto HUD) ────────────────────────────────
	var container := VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	container.offset_top    = 68.0
	container.offset_bottom = 68.0 + BAR_H + 52.0
	container.offset_left   = -BAR_W * 0.5
	container.offset_right  =  BAR_W * 0.5
	container.add_theme_constant_override("separation", 4)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(container)

	# Nome boss
	_name_lbl = _lbl("", 18, Color(1.0, 0.35, 0.35), 3, Color(0, 0, 0, 0.9))
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(_name_lbl)

	# Barra HP
	var bar_root := Control.new()
	bar_root.custom_minimum_size = Vector2(BAR_W, BAR_H)
	bar_root.clip_children       = CanvasItem.CLIP_CHILDREN_ONLY
	container.add_child(bar_root)

	var bar_bg := Panel.new()
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color                  = Color(0.10, 0.04, 0.20, 0.92)
	bg_s.corner_radius_top_left    = 6
	bg_s.corner_radius_top_right   = 6
	bg_s.corner_radius_bottom_left  = 6
	bg_s.corner_radius_bottom_right = 6
	bar_bg.add_theme_stylebox_override("panel", bg_s)
	bar_root.add_child(bar_bg)

	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color                  = Color(0.85, 0.18, 0.22)
	_fill_style.corner_radius_top_left    = 6
	_fill_style.corner_radius_top_right   = 6
	_fill_style.corner_radius_bottom_left  = 6
	_fill_style.corner_radius_bottom_right = 6

	_bar_fill = Panel.new()
	_bar_fill.position = Vector2.ZERO
	_bar_fill.size     = Vector2(BAR_W, BAR_H)
	_bar_fill.add_theme_stylebox_override("panel", _fill_style)
	bar_root.add_child(_bar_fill)

	# Indicatore fase
	_phase_lbl = _lbl("FASE 1", 11, Color(0.70, 0.70, 1.00))
	_phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(_phase_lbl)

	# Aggiorna subito il nome
	if _boss_ref and _boss_ref.has_method("get_boss_name"):
		_name_lbl.text = "⚔  " + _boss_ref.get_boss_name() + "  ⚔"


func _process(_delta: float) -> void:
	if not is_instance_valid(_boss_ref) or _boss_ref.get("is_dead"):
		# Boss morto: auto-distruggi con fade out
		var tw := create_tween()
		tw.tween_property(_canvas, "offset", Vector2(0, -20), 0.4)
		tw.parallel().tween_property(_canvas, "modulate", Color(1, 1, 1, 0), 0.4)
		tw.tween_callback(queue_free)
		set_process(false)
		return

	# ── Aggiorna HP bar ──────────────────────────────────────────────────────
	var ratio := 1.0
	var hp:  Variant = _boss_ref.get("health")
	var mhp: Variant = _boss_ref.get("max_health")
	if hp is float and mhp is float and mhp > 0:
		ratio = clampf(hp / mhp, 0.0, 1.0)

	_bar_fill.size.x = lerpf(_bar_fill.size.x, BAR_W * ratio, 0.12)

	# Colore barra: verde → giallo → rosso
	var col := Color(0.85, 0.18, 0.22)   # default rosso
	if ratio > 0.6:
		col = Color(0.18, 0.85, 0.35)
	elif ratio > 0.3:
		col = Color(0.92, 0.72, 0.08)
	_fill_style.bg_color = _fill_style.bg_color.lerp(col, 0.1)


func _on_phase_changed(new_phase: int) -> void:
	_phase_lbl.text = "FASE %d" % new_phase
	_phase_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.35, 0.12) if new_phase >= 2 else Color(0.70, 0.70, 1.00))

	# Lampeggio nome
	var tw := create_tween()
	tw.tween_property(_name_lbl, "modulate", Color(1, 0.3, 0.1), 0.15)
	tw.tween_property(_name_lbl, "modulate", Color.WHITE, 0.15)


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
