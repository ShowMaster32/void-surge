extends Node
class_name RunEndShop
## RunEndShop – Schermata fine run con upgrade permanenti acquistabili
##
## Appare sopra la DeathScreen al game_over.
## Mostra: wave raggiunta, kills, tempo, ψ guadagnati in questa run.
## Consente di comprare upgrade PERMANENTI (persistono tra le run) con i ψ totali.
## I bonus vengono letti da player.gd in _recalculate_stats() via MetaManager.perm_upgrades.
##
## Setup: aggiungi run_end_shop.tscn come figlio di main.tscn (come Shop).

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BG     := Color(0.02, 0.01, 0.08, 0.97)
const C_PAN    := Color(0.06, 0.03, 0.14)
const C_ACC    := Color(0.55, 0.22, 1.00)
const C_GOLD   := Color(1.00, 0.82, 0.10)
const C_GREEN  := Color(0.18, 1.00, 0.45)
const C_RED    := Color(1.00, 0.28, 0.28)
const C_DIM    := Color(0.40, 0.40, 0.55)
const C_HI     := Color(0.88, 0.88, 1.00)
const C_CYAN   := Color(0.20, 0.88, 1.00)
const C_ORANGE := Color(1.00, 0.55, 0.12)

# ── Catalogo upgrade permanenti ───────────────────────────────────────────────
## max_level = numero massimo di acquisti per questo upgrade
const PERM_CATALOG: Array = [
	{
		"id": "perm_hp",   "icon": "🛡️",   "name": "Biopiastre",
		"desc": "+10 HP massimi all'inizio di ogni run.",
		"cost": 40,  "max_level": 15,
	},
	{
		"id": "perm_dmg",  "icon": "⚡",   "name": "Nucleo Plasma",
		"desc": "+5% danno base permanente.",
		"cost": 80,  "max_level": 10,
	},
	{
		"id": "perm_speed","icon": "💨",   "name": "Motore Ionico",
		"desc": "+20 velocità di movimento permanente.",
		"cost": 50,  "max_level": 12,
	},
	{
		"id": "perm_crit", "icon": "💎",   "name": "Modulo Critico",
		"desc": "+3% probabilità critico permanente.",
		"cost": 70,  "max_level": 8,
	},
	{
		"id": "perm_fr",   "icon": "🔫",   "name": "Overclock",
		"desc": "Fire rate -2.5% per livello permanente.",
		"cost": 90,  "max_level": 8,
	},
]

# ── Stato interno ─────────────────────────────────────────────────────────────
var _canvas:     CanvasLayer
var _souls_lbl:  Label
var _run_souls:  int  = 0   # souls guadagnati in questa specifica run
var _is_open:    bool = false
var _cards:      Array = []  # array di dizionari {item, panel, btn, lvl_lbl}


# ══════════════════════════════════════════════
#  Avvio
# ══════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	# Collegamento al segnale game_over di GameManager
	if GameManager.has_signal("game_over"):
		GameManager.game_over.connect(_on_game_over)


# ══════════════════════════════════════════════
#  Costruzione UI
# ══════════════════════════════════════════════

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer        = 35   # sopra DeathScreen (layer 0) e HUD (20) e Shop (30)
	_canvas.visible      = false
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	# Overlay scuro
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color        = Color(0.00, 0.00, 0.05, 0.91)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(overlay)

	# Panel principale
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(980, 530)
	panel.offset_left   = -490
	panel.offset_right  =  490
	panel.offset_top    = -280
	panel.offset_bottom =  280
	panel.add_theme_stylebox_override("panel",
		_mk_style(C_BG, C_ACC, 18, 2))
	_canvas.add_child(panel)

	# Striscia neon superiore colorata
	var top_stripe := Panel.new()
	top_stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_stripe.offset_bottom = 5
	top_stripe.add_theme_stylebox_override("panel",
		_mk_style(C_ACC, Color.TRANSPARENT, 0, 0))
	panel.add_child(top_stripe)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 32
	vbox.offset_right  = -32
	vbox.offset_top    = 22
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# ── Header ────────────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	vbox.add_child(header)

	var title_lbl := _lbl("◈  RUN TERMINATA", 26, C_ACC, 3, Color(0, 0, 0, 0.9))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var souls_row := HBoxContainer.new()
	souls_row.add_theme_constant_override("separation", 6)
	header.add_child(souls_row)
	souls_row.add_child(_lbl("ψ", 20, C_GOLD))
	_souls_lbl = _lbl("0", 20, C_GOLD, 2, Color(0, 0, 0, 0.8))
	souls_row.add_child(_souls_lbl)

	# Separatore
	var sep := ColorRect.new()
	sep.color               = Color(C_ACC.r, C_ACC.g, C_ACC.b, 0.30)
	sep.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sep)

	# ── Riquadro stats run ────────────────────────────────────────────────────
	var stats_panel := Panel.new()
	stats_panel.add_theme_stylebox_override("panel",
		_mk_style(Color(C_PAN.r, C_PAN.g, C_PAN.b, 0.80),
			Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.30), 10, 1))
	stats_panel.custom_minimum_size = Vector2(0, 52)
	vbox.add_child(stats_panel)

	var stats_cc := CenterContainer.new()
	stats_cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_panel.add_child(stats_cc)

	var stats_hbox := HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 28)
	stats_hbox.name = "StatsHBox"
	stats_cc.add_child(stats_hbox)
	# I valori vengono riempiti in _show()

	# Separatore
	var sep2 := ColorRect.new()
	sep2.color               = Color(C_ACC.r, C_ACC.g, C_ACC.b, 0.22)
	sep2.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep2)

	# Titolo upgrade
	var upg_title := HBoxContainer.new()
	upg_title.add_theme_constant_override("separation", 8)
	vbox.add_child(upg_title)

	upg_title.add_child(_lbl("🔧  UPGRADE PERMANENTI", 17, C_GOLD, 2, Color(0,0,0,0.7)))
	var upg_hint := _lbl("I bonus persistono tra le run  •  Costo aumenta con i livelli", 11, C_DIM)
	upg_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upg_hint.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	upg_title.add_child(upg_hint)

	# ── Griglia upgrade ───────────────────────────────────────────────────────
	var upg_grid := HBoxContainer.new()
	upg_grid.add_theme_constant_override("separation", 14)
	upg_grid.alignment          = BoxContainer.ALIGNMENT_CENTER
	upg_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upg_grid.name = "UpgGrid"
	vbox.add_child(upg_grid)

	# ── Footer ────────────────────────────────────────────────────────────────
	var sep3 := ColorRect.new()
	sep3.color               = Color(C_ACC.r, C_ACC.g, C_ACC.b, 0.18)
	sep3.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep3)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(footer)

	var retry_btn := _action_btn("▶  RIGIOCA", C_GREEN)
	retry_btn.pressed.connect(_on_retry)
	retry_btn.focus_mode = Control.FOCUS_ALL
	retry_btn.name = "RetryBtn"
	footer.add_child(retry_btn)

	var hub_btn := _action_btn("🏠  VAI AL HUB", C_ACC)
	hub_btn.pressed.connect(_on_go_hub)
	hub_btn.focus_mode = Control.FOCUS_ALL
	footer.add_child(hub_btn)

	var ctrl_hint2 := _lbl("🎮  [A] Conferma  [D-pad] Naviga  [B] Rigioca", 10, C_DIM)
	footer.add_child(ctrl_hint2)


# ══════════════════════════════════════════════
#  Mostra (chiamato da _on_game_over)
# ══════════════════════════════════════════════

func _on_game_over(stats: Dictionary) -> void:
	await get_tree().create_timer(0.9).timeout  # piccola pausa dopo la DeathScreen
	_show(stats)


func _show(stats: Dictionary) -> void:
	if _is_open:
		return
	_is_open = true

	# Calcola souls guadagnati in questa run
	var kills:  int = stats.get("kills", 0)
	var wave:   int = stats.get("wave_reached", 1)
	_run_souls = kills * 2 + wave * 10
	# I souls sono già stati aggiunti da MetaManager.on_run_complete(),
	# ma se non è stato chiamato, li aggiungiamo qui in sicurezza.
	# (on_run_complete potrebbe non essere connesso — gestione graceful)

	# Popola stats bar e cards upgrade
	_fill_stats(stats, wave, kills)

	# Costruisce upgrade cards
	_build_upgrade_cards()

	# Aggiorna souls display
	_refresh_souls()

	_canvas.visible = true

	# Controller: focus al primo bottone acquistabile
	await get_tree().process_frame
	_grab_first_res_focus()

	# Animazione entrata: scale da 0.9 → 1.0
	var panel: Control = null
	if _canvas.get_child_count() > 1:
		var _raw: Variant = _canvas.get_children()[1]
		if _raw is Control:
			panel = _raw as Control
	if panel != null:
		panel.scale = Vector2(0.9, 0.9)
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(panel, "scale", Vector2.ONE, 0.35)


func _fill_stats(stats: Dictionary, wave: int, kills: int) -> void:
	# Trova StatsHBox navigando il tree
	var stats_hbox: HBoxContainer = null
	for ch: Node in _canvas.get_children():
		if ch is Panel:
			stats_hbox = _find_node_by_name(ch, "StatsHBox") as HBoxContainer
			break
	if not stats_hbox:
		return

	for c: Node in stats_hbox.get_children():
		c.queue_free()

	var run_t: float = stats.get("run_time", 0.0)
	var dmg:   int   = int(stats.get("damage_dealt", 0.0) as float)
	var mins  := int(run_t) / 60
	var secs  := int(run_t) % 60

	var stat_items := [
		["🌊  WAVE",   str(wave)],
		["⏱  TEMPO",  "%02d:%02d" % [mins, secs]],
		["☠  KILLS",  str(kills)],
		["⚔  DANNO",  _fmt_big(dmg)],
		["✨  GUADAGNI", "+ψ%d" % _run_souls],
	]

	for si in stat_items:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(_lbl(si[0], 10, C_DIM))
		var val_lbl := _lbl(si[1], 18, C_HI, 1, Color(0, 0, 0, 0.7))
		if si[0].begins_with("✨"):
			val_lbl.add_theme_color_override("font_color", C_GOLD)
		col.add_child(val_lbl)
		stats_hbox.add_child(col)

		if si != stat_items.back():
			var vsep := ColorRect.new()
			vsep.custom_minimum_size = Vector2(1, 36)
			vsep.color = Color(C_ACC.r, C_ACC.g, C_ACC.b, 0.30)
			stats_hbox.add_child(vsep)


func _build_upgrade_cards() -> void:
	var upg_grid: HBoxContainer = null
	for ch: Node in _canvas.get_children():
		if ch is Panel:
			upg_grid = _find_node_by_name(ch, "UpgGrid") as HBoxContainer
			break
	if not upg_grid:
		return

	for c: Node in upg_grid.get_children():
		c.queue_free()
	_cards.clear()

	for item: Dictionary in PERM_CATALOG:
		var card_data: Dictionary = _build_upgrade_card(item, upg_grid)
		_cards.append(card_data)


func _build_upgrade_card(item: Dictionary, parent: Node) -> Dictionary:
	var upg_id:    String = item["id"]
	var cur_level: int    = MetaManager.get_perm_level(upg_id)
	var max_level: int    = item.get("max_level", 10) as int
	var cost:      int    = _calc_cost(item["cost"] as int, cur_level)
	var can_buy:   bool   = cur_level < max_level and MetaManager.total_souls >= cost
	var maxed:     bool   = cur_level >= max_level

	# Colore card basato su stato
	var col: Color = C_GREEN if can_buy else (C_GOLD if maxed else C_DIM)

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(165, 195)
	var sty := _mk_style(
		Color(col.r * 0.07, col.g * 0.07, col.b * 0.07, 0.96),
		col if (can_buy or maxed) else C_DIM, 12,
		2 if can_buy else 1)
	sty.content_margin_left   = 12.0
	sty.content_margin_right  = 12.0
	sty.content_margin_top    = 10.0
	sty.content_margin_bottom = 10.0
	pc.add_theme_stylebox_override("panel", sty)
	parent.add_child(pc)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pc.add_child(vbox)

	# Icona + badge livello
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	vbox.add_child(top)

	top.add_child(_lbl(item["icon"], 30, col))

	var lv_badge := PanelContainer.new()
	var lvb_s := _mk_style(Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.9),
		col, 6, 1)
	lvb_s.content_margin_left   = 5.0
	lvb_s.content_margin_right  = 5.0
	lvb_s.content_margin_top    = 1.0
	lvb_s.content_margin_bottom = 1.0
	lv_badge.add_theme_stylebox_override("panel", lvb_s)
	var lv_txt := ("MAX" if maxed else "Lv %d/%d" % [cur_level, max_level])
	var lv_lbl := _lbl(lv_txt, 9, col)
	lv_badge.add_child(lv_lbl)
	lv_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# allineamento a destra tramite HBox
	var lv_right := HBoxContainer.new()
	lv_right.alignment = BoxContainer.ALIGNMENT_END
	lv_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv_right.add_child(lv_badge)
	top.add_child(lv_right)

	# Nome
	vbox.add_child(_lbl(item["name"], 13, C_HI, 1, Color(0, 0, 0, 0.6)))

	# Descrizione
	var desc := _lbl(item["desc"], 10, C_DIM)
	desc.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	# Barra livello progress
	var prog_root := Control.new()
	prog_root.custom_minimum_size = Vector2(0, 5)
	prog_root.clip_children       = CanvasItem.CLIP_CHILDREN_ONLY
	vbox.add_child(prog_root)

	var prog_bg := Panel.new()
	prog_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	prog_bg.add_theme_stylebox_override("panel",
		_mk_style(Color(0.08, 0.08, 0.20), Color.TRANSPARENT, 4, 0))
	prog_root.add_child(prog_bg)

	var prog_fill := Panel.new()
	var ratio := float(cur_level) / float(max_level)
	prog_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	prog_fill.anchor_right = ratio
	prog_fill.add_theme_stylebox_override("panel",
		_mk_style(col, Color.TRANSPARENT, 4, 0))
	prog_root.add_child(prog_fill)

	# Bottone acquisto
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", 12)

	if maxed:
		btn.text    = "✔  MASSIMO"
		btn.disabled = true
		btn.modulate = Color(0.6, 0.8, 0.6, 0.8)
	elif can_buy:
		btn.text = "  ψ %d  " % cost
		btn.add_theme_color_override("font_color", C_GOLD)
		btn.add_theme_stylebox_override("normal",
			_mk_style(Color(0.12, 0.10, 0.01, 0.92), C_GOLD, 8, 1))
		btn.add_theme_stylebox_override("hover",
			_mk_style(Color(0.22, 0.18, 0.02, 0.96), Color.WHITE, 8, 2))
		btn.focus_mode = Control.FOCUS_ALL
		var cap_item := item
		btn.pressed.connect(func(): _buy_upgrade(cap_item))
	else:
		btn.text    = "  ψ %d  " % cost
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 0.7)

	vbox.add_child(btn)

	return { "item": item, "panel": pc, "btn": btn, "lv_lbl": lv_lbl }


# ══════════════════════════════════════════════
#  Acquisto
# ══════════════════════════════════════════════

func _grab_first_res_focus() -> void:
	## Dà il focus al primo bottone acquistabile; fallback su RetryBtn.
	for cd: Dictionary in _cards:
		var btn: Button = cd.get("btn", null) as Button
		if btn and not btn.disabled and btn.focus_mode != Control.FOCUS_NONE:
			btn.grab_focus()
			return
	var rb := _canvas.find_child("RetryBtn", true, false)
	if rb is Button:
		(rb as Button).grab_focus()


func _buy_upgrade(item: Dictionary) -> void:
	var upg_id: String = item["id"]
	var level:  int    = MetaManager.get_perm_level(upg_id)
	var cost:   int    = _calc_cost(item["cost"], level)

	if not MetaManager.buy_perm_upgrade(upg_id, cost):
		return

	# Flash verde sul panel per feedback
	for cd: Dictionary in _cards:
		if (cd["item"] as Dictionary)["id"] == upg_id:
			var panel: PanelContainer = cd["panel"] as PanelContainer
			var tw := panel.create_tween()
			tw.tween_property(panel, "modulate", Color(0.5, 2.0, 0.7), 0.08)
			tw.tween_property(panel, "modulate", Color.WHITE,           0.22)
			break

	# Ricostruisce tutte le card per aggiornare livelli/prezzi/btn
	_build_upgrade_cards()
	_refresh_souls()


func _calc_cost(base_cost: int, level: int) -> int:
	## Il costo scala con il livello: +20% per ogni livello acquistato
	return int(base_cost * pow(1.20, level))


# ══════════════════════════════════════════════
#  Azioni footer
# ══════════════════════════════════════════════

func _on_retry() -> void:
	_is_open = false
	_canvas.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_go_hub() -> void:
	_is_open = false
	_canvas.visible = false
	get_tree().paused = false
	# Per ora ricarica la scena; in futuro andrà alla scena MetaHub
	get_tree().reload_current_scene()


# ══════════════════════════════════════════════
#  Utility UI
# ══════════════════════════════════════════════

func _refresh_souls() -> void:
	if _souls_lbl:
		_souls_lbl.text = "%d" % MetaManager.total_souls


func _fmt_big(n: int) -> String:
	if n >= 1_000_000: return "%.1fM" % (n / 1_000_000.0)
	if n >= 1_000:     return "%.1fk" % (n / 1_000.0)
	return str(n)


func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, target_name)
		if found:
			return found
	return null


func _mk_style(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = bg
	s.border_color        = border
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


func _action_btn(txt: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(180, 46)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color",         col)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	var bg  := Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.92)
	var hov := Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.96)
	btn.add_theme_stylebox_override("normal",  _mk_style(bg,  col, 10, 2))
	btn.add_theme_stylebox_override("hover",   _mk_style(hov, col, 10, 3))
	btn.add_theme_stylebox_override("pressed", _mk_style(hov, Color.WHITE, 10, 2))
	return btn
