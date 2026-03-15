extends Node

# ══════════════════════════════════════════════════════════════════════════════
#  VOID SURGE – HUD  (v5 – top bar singola pulita)
#  • barra orizzontale unica in cima (wave / countdown / timer / kills)
#  • card giocatore arrotondate in basso
#  • barra HP smooth con StyleBoxFlat + clip_children
# ══════════════════════════════════════════════════════════════════════════════

const P_COLORS: Array[Color] = [
	Color(0.25, 0.85, 1.00),   # Cyan   P1
	Color(1.00, 0.30, 0.72),   # Magenta P2
	Color(0.30, 1.00, 0.45),   # Verde  P3
	Color(1.00, 0.82, 0.15),   # Giallo P4
]
const C_HI  := Color(0.15, 0.95, 0.50)   # verde pieno vita
const C_MID := Color(0.98, 0.80, 0.08)   # giallo metà vita
const C_LO  := Color(0.98, 0.20, 0.20)   # rosso vita bassa

const BAR_W   := 210.0
const BAR_H   := 18.0
const PWR_H   := 7.0    # altezza barra cooldown potere
const CARD_W  := BAR_W + 50.0
const CARD_H  := 148.0  # aumentata per due righe potere Q+E (era 114)
const RADIUS  := 10     # angoli card / barra

# Colori slot poteri
const C_SLOT_Q := Color(0.20, 0.88, 1.00)   # cyan  – slot Q
const C_SLOT_E := Color(1.00, 0.55, 0.12)   # arancio – slot E

# ── nodi ──────────────────────────────────────────────────────────────────────
var _canvas:         CanvasLayer
var _wave_lbl:       Label
var _wave_next_lbl:  Label   # "next: 18s"
var _timer_lbl:      Label
var _kills_lbl:      Label
var _zone_lbl:       Label   # (non mostrato, kept per compatibilità)
var _synergy_row:    Control
var _spawner:        Node = null
var _player_panels:  Array = []
var _hp_fills:       Array = []
var _hp_fill_styles: Array = []
var _hp_labels:      Array = []
# Slot Q (cyan) e Slot E (arancio) – uno per carta giocatore
var _pwr_q_fills:       Array = []
var _pwr_q_fill_styles: Array = []
var _pwr_q_labels:      Array = []   # ogni entry = [name_lbl, cd_lbl]
var _pwr_e_fills:       Array = []
var _pwr_e_fill_styles: Array = []
var _pwr_e_labels:      Array = []   # ogni entry = [name_lbl, cd_lbl]

# ── stato ─────────────────────────────────────────────────────────────────────
var _players:    Array = []
var _elapsed:    float = 0.0
var _kills:      int   = 0
var _wave:       int   = 1
var _poll_timer: float = 0.0


# ══════════════════════════════════════════════
#  Avvio
# ══════════════════════════════════════════════

func _ready() -> void:
	# PROCESS_MODE_ALWAYS: l'HUD continua ad aggiornarsi anche durante la pausa shop
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in get_children():
		c.queue_free()
	_canvas = CanvasLayer.new()
	_canvas.layer = 20
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_build_ui()
	_hook_signals()
	_find_players()


# ══════════════════════════════════════════════
#  Costruzione UI
# ══════════════════════════════════════════════

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)

	# ── barra singola in cima ─────────────────────────────────────────────────
	var top_bar := Panel.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 60   # era 44 — aumentata per far stare wave + "next: Xs"
	top_bar.add_theme_stylebox_override("panel",
		_mk_style(Color(0.05, 0.04, 0.14, 0.92), Color.TRANSPARENT, 0, 0))
	root.add_child(top_bar)

	# linea neon sul fondo della barra
	var top_line := Panel.new()
	top_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	top_line.offset_top = -2
	top_line.add_theme_stylebox_override("panel",
		_mk_style(Color(0.50, 0.20, 0.90, 0.65), Color.TRANSPARENT, 0, 0))
	top_bar.add_child(top_line)

	# contenuto centrato
	var bar_cc := CenterContainer.new()
	bar_cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_bar.add_child(bar_cc)

	var bar_hbox := HBoxContainer.new()
	bar_hbox.add_theme_constant_override("separation", 24)
	bar_cc.add_child(bar_hbox)

	# wave + countdown
	_wave_lbl      = _lbl("◈  WAVE 1", 24, Color(0.88, 0.58, 1.00), 2, Color(0, 0, 0, 0.9))
	_wave_next_lbl = _lbl("",          12, Color(0.72, 0.66, 0.92))  # 14→12: più compatto nella barra
	_wave_next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var wave_vbox := VBoxContainer.new()
	wave_vbox.add_theme_constant_override("separation", 0)
	wave_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_vbox.add_child(_wave_lbl)
	wave_vbox.add_child(_wave_next_lbl)
	bar_hbox.add_child(wave_vbox)

	bar_hbox.add_child(_mk_vsep())
	_timer_lbl = _lbl("⏱  00:00", 20, Color(0.65, 0.90, 1.00), 1, Color(0, 0, 0, 0.7))
	bar_hbox.add_child(_timer_lbl)

	bar_hbox.add_child(_mk_vsep())
	_kills_lbl = _lbl("☠  0", 20, Color(1.00, 0.52, 0.20), 1, Color(0, 0, 0, 0.7))
	bar_hbox.add_child(_kills_lbl)

	# ── banner synergy co-op ──────────────────────────────────────────────────
	_synergy_row = Control.new()
	_synergy_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_synergy_row.offset_top    = 56   # segue la nuova altezza barra (60px)
	_synergy_row.offset_bottom = 78
	_synergy_row.modulate.a    = 0.0
	root.add_child(_synergy_row)

	var syn_panel := Panel.new()
	syn_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	syn_panel.add_theme_stylebox_override("panel",
		_mk_style(Color(0.05, 0.40, 0.70, 0.35), Color(0.20, 0.90, 1.00, 0.55), 0, 2))
	_synergy_row.add_child(syn_panel)

	var syn_lbl := _lbl("⚡   CO-OP SYNERGY   ⚡", 13, Color(0.20, 0.95, 1.00), 3, Color(0, 0, 0, 0.8))
	syn_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	syn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	syn_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_synergy_row.add_child(syn_lbl)

	# ── card giocatori ────────────────────────────────────────────────────────
	for i in 4:
		var col  := P_COLORS[i]
		var card := _build_player_card(i, col)
		card.visible = (i == 0)
		_player_panels.append(card)

		var stack := int(i >= 2)
		var off_y := -(CARD_H + 14.0) - (CARD_H + 8.0) * stack

		if i % 2 == 0:   # sinistra
			card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			card.offset_left   = 12
			card.offset_bottom = off_y + CARD_H
			card.offset_top    = off_y
			card.offset_right  = 12.0 + CARD_W
		else:             # destra
			card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			card.offset_right  = -12
			card.offset_bottom = off_y + CARD_H
			card.offset_top    = off_y
			card.offset_left   = -(CARD_W + 12.0)

		root.add_child(card)


# ── card giocatore ────────────────────────────────────────────────────────────

func _build_player_card(idx: int, col: Color) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)

	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel",
		_mk_style(Color(0.04, 0.03, 0.14, 0.93), Color(col.r, col.g, col.b, 0.55), RADIUS, 2))
	card.add_child(bg)

	var stripe_s := _mk_style(Color(col.r, col.g, col.b, 0.88), Color.TRANSPARENT, 0, 0)
	stripe_s.corner_radius_top_left  = RADIUS
	stripe_s.corner_radius_top_right = RADIUS
	var stripe := Panel.new()
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.offset_bottom = 4
	stripe.add_theme_stylebox_override("panel", stripe_s)
	card.add_child(stripe)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 14
	vbox.offset_right  = -14
	vbox.offset_top    = 12
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var badge := PanelContainer.new()
	var bs := _mk_style(Color(col.r, col.g, col.b, 0.22), col, 8, 1)
	bs.content_margin_left   = 9.0
	bs.content_margin_right  = 9.0
	bs.content_margin_top    = 1.0
	bs.content_margin_bottom = 1.0
	badge.add_theme_stylebox_override("panel", bs)
	badge.add_child(_lbl("P%d" % (idx + 1), 20, col, 2, Color(0, 0, 0, 0.9)))
	header.add_child(badge)

	var hp_lbl := _lbl("", 17, Color(0.82, 0.82, 1.00))
	hp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(hp_lbl)
	_hp_labels.append(hp_lbl)

	var bar_root := Control.new()
	bar_root.custom_minimum_size = Vector2(BAR_W, BAR_H)
	bar_root.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	vbox.add_child(bar_root)

	var bar_bg := Panel.new()
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_bg.add_theme_stylebox_override("panel",
		_mk_style(Color(0.07, 0.07, 0.18), Color.TRANSPARENT, RADIUS, 0))
	bar_root.add_child(bar_bg)

	var fill_style := _mk_style(C_HI, Color.TRANSPARENT, RADIUS, 0)
	var bar_fill := Panel.new()
	bar_fill.position = Vector2.ZERO
	bar_fill.size     = Vector2(BAR_W, BAR_H)
	bar_fill.add_theme_stylebox_override("panel", fill_style)
	bar_root.add_child(bar_fill)

	var hl := Panel.new()
	hl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hl.offset_bottom = 4
	hl.add_theme_stylebox_override("panel",
		_mk_style(Color(1, 1, 1, 0.22), Color.TRANSPARENT, RADIUS, 0))
	bar_fill.add_child(hl)

	_hp_fills.append(bar_fill)
	_hp_fill_styles.append(fill_style)

	# ── slot Q (cyan) ─────────────────────────────────────────────────────────
	_build_power_row(vbox, "Q", C_SLOT_Q, _pwr_q_fills, _pwr_q_fill_styles, _pwr_q_labels)

	# ── slot E (arancio) ──────────────────────────────────────────────────────
	_build_power_row(vbox, "E", C_SLOT_E, _pwr_e_fills, _pwr_e_fill_styles, _pwr_e_labels)

	return card


## Costruisce una riga potere (key label + nome + cd text + barra) e popola gli array.
func _build_power_row(
		vbox: VBoxContainer,
		key_txt: String,
		slot_col: Color,
		fills: Array, fill_styles: Array, labels: Array) -> void:

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.custom_minimum_size = Vector2(BAR_W, 0)
	vbox.add_child(row)

	# badge tasto [Q] / [E]
	var key_badge := PanelContainer.new()
	var kb_style := _mk_style(Color(slot_col.r, slot_col.g, slot_col.b, 0.18),
		slot_col, 5, 1)
	kb_style.content_margin_left   = 5.0
	kb_style.content_margin_right  = 5.0
	kb_style.content_margin_top    = 0.0
	kb_style.content_margin_bottom = 0.0
	key_badge.add_theme_stylebox_override("panel", kb_style)
	key_badge.add_child(_lbl("[%s]" % key_txt, 10, slot_col))
	row.add_child(key_badge)

	var name_lbl := _lbl("", 11, Color(0.78, 0.78, 0.95))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_lbl)

	var cd_lbl := _lbl("", 11, Color(0.20, 1.00, 0.55))
	row.add_child(cd_lbl)

	labels.append([name_lbl, cd_lbl])

	# barra cooldown
	var bar_root := Control.new()
	bar_root.custom_minimum_size = Vector2(BAR_W, PWR_H)
	bar_root.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	vbox.add_child(bar_root)

	var bar_bg := Panel.new()
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_bg.add_theme_stylebox_override("panel",
		_mk_style(Color(0.07, 0.07, 0.18), Color.TRANSPARENT, RADIUS, 0))
	bar_root.add_child(bar_bg)

	var base_col := slot_col.darkened(0.35)
	var fill_style := _mk_style(base_col, Color.TRANSPARENT, RADIUS, 0)
	var fill := Panel.new()
	fill.position = Vector2.ZERO
	fill.size     = Vector2(BAR_W, PWR_H)
	fill.add_theme_stylebox_override("panel", fill_style)
	bar_root.add_child(fill)

	fills.append(fill)
	fill_styles.append(fill_style)


# ══════════════════════════════════════════════
#  Helper – stile / label / separatore
# ══════════════════════════════════════════════

func _mk_style(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = bg
	s.border_color = border
	s.border_width_left   = border_w
	s.border_width_right  = border_w
	s.border_width_top    = border_w
	s.border_width_bottom = border_w
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	s.anti_aliasing      = true
	s.anti_aliasing_size = 1.5
	return s


func _mk_vsep() -> Control:
	var c := ColorRect.new()
	c.custom_minimum_size = Vector2(2, 20)
	c.color = Color(0.50, 0.20, 0.90, 0.45)
	return c


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


# ══════════════════════════════════════════════
#  Segnali (opzionali)
# ══════════════════════════════════════════════

func _hook_signals() -> void:
	for sig in ["wave_started", "on_wave_start", "wave_changed", "new_wave", "wave_begin"]:
		if GameManager.has_signal(sig):
			GameManager.connect(sig, _on_wave)
			break
	for sig in ["enemy_killed", "on_enemy_killed", "kill", "enemy_died", "enemy_death"]:
		if GameManager.has_signal(sig):
			GameManager.connect(sig, _on_kill)
			break
	if GameManager.has_signal("coop_synergy_active"):
		GameManager.coop_synergy_active.connect(_on_synergy)


func _on_wave(arg = null) -> void:
	_wave = arg if arg is int else _read_gm_wave()
	_wave_lbl.text = "◈  WAVE %d" % _wave
	_wave_lbl.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(_wave_lbl, "scale", Vector2.ONE, 0.4
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _on_kill(_a = null) -> void:
	_kills += 1
	_kills_lbl.text = "☠  %d" % _kills


func _on_synergy(active: bool) -> void:
	create_tween().tween_property(_synergy_row, "modulate:a",
		1.0 if active else 0.0, 0.4)


# ══════════════════════════════════════════════
#  _process
# ══════════════════════════════════════════════

func _process(delta: float) -> void:
	# Il timer si blocca quando il gioco non è in PLAYING (shop aperto, pausa menu, ecc.)
	if GameManager.current_state == GameManager.GameState.PLAYING:
		_elapsed += delta
	_timer_lbl.text = "%02d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60]

	_poll_timer += delta
	if _poll_timer >= 0.4:
		_poll_timer = 0.0
		_slow_poll()

	_update_hp_bars()


func _find_spawner() -> void:
	var sp = get_tree().get_first_node_in_group("enemy_spawner")
	if sp:
		_spawner = sp
		return
	var scene := get_tree().current_scene
	if scene:
		for child in scene.get_children():
			if child.get("wave_timer") != null and child.get("wave_duration") != null:
				_spawner = child
				return


func _slow_poll() -> void:
	if _players.is_empty():
		_find_players()

	# ── wave countdown ────────────────────────────────────────────────────────
	if _spawner == null or not is_instance_valid(_spawner):
		_find_spawner()
	if _spawner != null and is_instance_valid(_spawner):
		var wt = _spawner.get("wave_timer")
		var wd = _spawner.get("wave_duration")
		if wt != null and wd != null:
			var remaining := maxf(float(wd) - float(wt), 0.0)
			_wave_next_lbl.text = "next: %ds" % int(remaining)

	# wave
	var gw := _read_gm_wave()
	if gw > 0 and gw != _wave:
		_wave = gw
		_wave_lbl.text = "◈  WAVE %d" % _wave

	# kills
	for prop in ["total_kills", "kill_count", "kills", "_kill_count",
				 "enemy_kill_count", "wave_kills", "score"]:
		var v = GameManager.get(prop)
		if v is int and v >= 0:
			_kills = v
			_kills_lbl.text = "☠  %d" % _kills
			break

	# zona (non mostrata nella barra, kept per compatibilità)
	for m in ["get_current_zone_name", "get_zone_name"]:
		if GameManager.has_method(m):
			if _zone_lbl:
				_zone_lbl.text = str(GameManager.call(m)).to_upper()
			return
	for p in ["current_zone", "zone_name", "zone"]:
		var v = GameManager.get(p)
		if v is String and v != "":
			if _zone_lbl:
				_zone_lbl.text = v.to_upper()
			break


# ── ricerca player ─────────────────────────────────────────────────────────────

func _find_players() -> void:
	var found: Array = []

	for grp in ["players", "player", "Players", "Player", "protagonists", "heroes"]:
		found = Array(get_tree().get_nodes_in_group(grp))
		if not found.is_empty():
			break

	if found.is_empty():
		for prop in ["players", "player_list", "active_players",
					 "spawned_players", "_players", "player_nodes", "player_refs"]:
			var v = GameManager.get(prop)
			if v is Array and not v.is_empty():
				found = v
				break
		if found.is_empty() and GameManager.has_method("get_players"):
			var v = GameManager.get_players()
			if v is Array:
				found = v

	if found.is_empty():
		var scene := get_tree().current_scene
		if scene:
			for child in scene.get_children():
				if child.get("current_health") != null and child.get("max_health") != null:
					found.append(child)
				elif child.get("health") != null and child.get("max_health") != null:
					found.append(child)
			if found.is_empty():
				for child in scene.get_children():
					for sub in child.get_children():
						if sub.get("current_health") != null and sub.get("max_health") != null:
							found.append(sub)

	if not found.is_empty():
		_players = found
		for i in min(_players.size(), 4):
			_player_panels[i].visible = true


# ── aggiorna barre HP ─────────────────────────────────────────────────────────

func _update_hp_bars() -> void:
	if _players.is_empty():
		return

	for i in min(_players.size(), 4):
		var p = _players[i]
		if not is_instance_valid(p):
			continue

		# ── HP bar ────────────────────────────────────────────────────────────
		var hp:     float = _rf(p, ["current_health", "health", "hp", "_health", "life"])
		var max_hp: float = _rf(p, ["max_health", "max_hp", "_max_health", "max_life"])
		if max_hp <= 0.0:
			max_hp = 100.0

		var ratio := clampf(hp / max_hp, 0.0, 1.0)

		var fill: Panel = _hp_fills[i]
		fill.size.x = lerpf(fill.size.x, BAR_W * ratio, 0.18)

		var fs: StyleBoxFlat = _hp_fill_styles[i]
		var target_col := C_HI if ratio > 0.55 else (C_MID if ratio > 0.28 else C_LO)
		fs.bg_color = fs.bg_color.lerp(target_col, 0.12)

		_hp_labels[i].text = "%d / %d" % [int(hp), int(max_hp)]

		# ── slot Q ────────────────────────────────────────────────────────────
		if i < _pwr_q_labels.size():
			var pq_name:  String = p.get_power_q_name()  if p.has_method("get_power_q_name")  else ""
			var pq_ratio: float  = p.get_cd_ratio_q()    if p.has_method("get_cd_ratio_q")    else 0.0
			_update_power_slot(i, pq_name, pq_ratio, p, "q",
				_pwr_q_labels, _pwr_q_fills, _pwr_q_fill_styles, C_SLOT_Q)

		# ── slot E ────────────────────────────────────────────────────────────
		if i < _pwr_e_labels.size():
			var pe_name:  String = p.get_power_e_name()  if p.has_method("get_power_e_name")  else \
				(p.get_active_power_name()    if p.has_method("get_active_power_name")   else "")
			var pe_ratio: float  = p.get_cd_ratio_e()    if p.has_method("get_cd_ratio_e")    else \
				(p.get_power_cooldown_ratio() if p.has_method("get_power_cooldown_ratio") else 0.0)
			_update_power_slot(i, pe_name, pe_ratio, p, "e",
				_pwr_e_labels, _pwr_e_fills, _pwr_e_fill_styles, C_SLOT_E)


## Aggiorna un singolo slot potere (Q o E) nella card del giocatore i.
func _update_power_slot(
		i: int, pname: String, cd_ratio: float, p: Object, slot: String,
		labels: Array, fills: Array, fill_styles: Array, slot_col: Color) -> void:

	var pair = labels[i]
	if not (pair is Array and pair.size() == 2):
		return
	var name_lbl: Label      = pair[0]
	var cd_lbl:   Label      = pair[1]
	var pwr_fill: Panel      = fills[i]
	var pwr_fs: StyleBoxFlat = fill_styles[i]

	if pname.is_empty():
		name_lbl.text   = ""
		cd_lbl.text     = ""
		pwr_fill.size.x = 0.0
	else:
		name_lbl.text = pname
		var ready := 1.0 - cd_ratio
		pwr_fill.size.x = lerpf(pwr_fill.size.x, BAR_W * ready, 0.20)
		if cd_ratio <= 0.0:
			cd_lbl.text = "PRONTO"
			cd_lbl.add_theme_color_override("font_color", Color(0.20, 1.00, 0.55))
			pwr_fs.bg_color = pwr_fs.bg_color.lerp(slot_col.lightened(0.15), 0.15)
		else:
			var cd_max := _get_power_cd_max(p, slot)
			cd_lbl.text = "%.1fs" % (cd_ratio * cd_max)
			cd_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.85))
			pwr_fs.bg_color = pwr_fs.bg_color.lerp(slot_col.darkened(0.35), 0.15)


## Legge il cooldown massimo per lo slot ("q" o "e") dal player.
func _get_power_cd_max(p: Object, slot: String = "e") -> float:
	var key := "_cd_max_q" if slot == "q" else "_cd_max_e"
	var v = p.get(key)
	if v is float and v > 0.0:
		return v
	# fallback legacy
	var v2 = p.get("_power_cooldown_max")
	if v2 is float and v2 > 0.0:
		return v2
	return 1.0


# ══════════════════════════════════════════════
#  Utility
# ══════════════════════════════════════════════

func _read_gm_wave() -> int:
	for p in ["current_wave", "wave_number", "wave", "_wave", "_current_wave"]:
		var v = GameManager.get(p)
		if v is int and v > 0:
			return v
	return 0


func _rf(obj: Object, names: Array) -> float:
	for n in names:
		var v = obj.get(n)
		if v is float or v is int:
			return float(v)
	return 0.0


func setup(players: Array) -> void:
	_players = players
	for i in min(players.size(), 4):
		_player_panels[i].visible = true
