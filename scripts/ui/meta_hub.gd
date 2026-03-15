extends Node
## MetaHub v2 — Schermata hub tra le run di Void Surge
##
## Funzionalità:
##   • Selezione personaggio (con XP, livello, stato unlock)
##   • Acquisto talenti (albero a catena per personaggio)
##   • Selezione skin (varianti colore, acquistabili con Souls)
##   • Acquisto e selezione Poteri Attivabili (E / Y per attivarli in run)
##   • Avvio 1 giocatore / 2 giocatori (controller auto-rilevato)
##
## Setup nel progetto:
##   1) Crea una scena menu/hub, aggiungi un Node, attacca questo script
##   2) Connetti il segnale start_run_requested(n) → change_scene_to_file(...)
##      OPPURE imposta @export game_scene_path per la transizione automatica
##   3) Assicurati che MetaManager, GameManager, InputManager siano Autoload

signal start_run_requested(player_count: int)

@export var game_scene_path: String = "res://scenes/game.tscn"

# ── Palette ────────────────────────────────────────────────────────────────────
const C_BG    := Color(0.04, 0.02, 0.10)
const C_PAN   := Color(0.08, 0.05, 0.18)
const C_ACC   := Color(0.55, 0.22, 1.00)
const C_GOLD  := Color(1.00, 0.82, 0.10)
const C_GREEN := Color(0.18, 1.00, 0.45)
const C_DIM   := Color(0.44, 0.44, 0.55)
const C_HI    := Color(0.88, 0.88, 1.00)
const C_RED   := Color(1.00, 0.28, 0.28)

# ── Skin data ──────────────────────────────────────────────────────────────────
const SKINS: Dictionary = {
	"void_sentinel": [
		{"name": "Cyan",    "color": Color(0.00, 1.00, 1.00), "cost": 0},
		{"name": "Crimson", "color": Color(1.00, 0.15, 0.20), "cost": 150},
		{"name": "Gold",    "color": Color(1.00, 0.82, 0.10), "cost": 250},
	],
	"plasma_caster": [
		{"name": "Magenta", "color": Color(1.00, 0.20, 1.00), "cost": 0},
		{"name": "Inferno", "color": Color(1.00, 0.45, 0.10), "cost": 150},
		{"name": "Ice",     "color": Color(0.40, 0.90, 1.00), "cost": 250},
	],
	"echo_knight": [
		{"name": "Verde",   "color": Color(0.20, 1.00, 0.20), "cost": 0},
		{"name": "Cobalt",  "color": Color(0.20, 0.50, 1.00), "cost": 150},
		{"name": "Plasma",  "color": Color(0.80, 0.20, 1.00), "cost": 250},
	],
	"void_lord": [
		{"name": "Viola",   "color": Color(0.80, 0.20, 1.00), "cost": 0},
		{"name": "Shadow",  "color": Color(0.22, 0.00, 0.50), "cost": 200},
		{"name": "White",   "color": Color(0.95, 0.95, 1.00), "cost": 300},
	],
}

# ── Dati Poteri Attivabili ─────────────────────────────────────────────────────
const POWERS: Array = [
	{
		"id":          "shield_burst",
		"name":        "Shield Burst",
		"icon":        "🛡",
		"description": "Diventa invincibile per 1.5 secondi. Perfetto per sopravvivere a situazioni disperate.",
		"cost":        200,
		"cooldown":    "8s",
	},
	{
		"id":          "plasma_bomb",
		"name":        "Plasma Bomb",
		"icon":        "💥",
		"description": "Esplode con 5× danno in un raggio di 250px. Devastante tra i gruppi nemici.",
		"cost":        300,
		"cooldown":    "12s",
	},
	{
		"id":          "void_dash",
		"name":        "Void Dash",
		"icon":        "⚡",
		"description": "Scatto rapido nella direzione di mira. Invincibile durante il dash.",
		"cost":        150,
		"cooldown":    "6s",
	},
	{
		"id":          "time_surge",
		"name":        "Time Surge",
		"icon":        "⏳",
		"description": "Rallenta tutti i nemici al 25% per 4 secondi. Spazio per respirare.",
		"cost":        400,
		"cooldown":    "18s",
	},
]

# ── Nodi / stato ───────────────────────────────────────────────────────────────
var _canvas: CanvasLayer
var _souls_lbl: Label
var _ctrl_lbl: Label
var _char_panels: Dictionary = {}   # char_id → PanelContainer
var _talent_row: HBoxContainer = null
var _skin_row:   HBoxContainer = null
var _power_row:  HBoxContainer = null
var _selected_char: String = ""
var _skin_sel:      Dictionary = {}   # char_id → int (indice skin selezionata)
var _skin_owned:    Dictionary = {}   # "char_id_N" → bool
var _power_sel:     String     = ""   # id potere selezionato (o "" = nessuno)
var _power_owned:   Dictionary = {}   # power_id → bool


# ══════════════════════════════════════════════
#  Init
# ══════════════════════════════════════════════

func _ready() -> void:
	# init selezioni skin al default (0)
	for cid in SKINS:
		_skin_sel[cid] = 0

	_canvas = CanvasLayer.new()
	_canvas.layer = 5
	add_child(_canvas)
	_build_ui()

	var start_char: String = MetaManager.selected_character \
		if MetaManager.selected_character in MetaManager.CHARACTERS \
		else "void_sentinel"
	_select_char(start_char)

	# controller events
	if InputManager.has_signal("controller_connected"):
		InputManager.controller_connected.connect(func(_id): _refresh_ctrl_label())
		InputManager.controller_disconnected.connect(func(_id): _refresh_ctrl_label())
	_refresh_ctrl_label()


# ══════════════════════════════════════════════
#  Build UI
# ══════════════════════════════════════════════

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)

	# sfondo
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# layout verticale principale
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 28
	vbox.offset_right  = -28
	vbox.offset_top    = 14
	vbox.offset_bottom = -14
	vbox.add_theme_constant_override("separation", 14)
	root.add_child(vbox)

	_build_topbar(vbox)
	_build_characters(vbox)
	_build_talents(vbox)
	_build_skins(vbox)
	_build_powers(vbox)

	# push bottom bar verso il basso
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_build_bottom(vbox)


# ── Top bar ────────────────────────────────────────────────────────────────────

func _build_topbar(vbox: Control) -> void:
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, 52)
	bar.add_theme_stylebox_override("panel",
		_mk_style(C_PAN, C_ACC, 10, 2))
	vbox.add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left   = 18; hbox.offset_right  = -18
	hbox.offset_top    = 9;  hbox.offset_bottom = -9
	hbox.add_theme_constant_override("separation", 16)
	bar.add_child(hbox)

	var title := _lbl("◈  VOID SURGE", 24, C_ACC, 3, Color(0, 0, 0, 0.9))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	_ctrl_lbl = _lbl("", 14, C_DIM)
	_ctrl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_ctrl_lbl)

	var sep := ColorRect.new()
	sep.color = Color(C_ACC.r, C_ACC.g, C_ACC.b, 0.45)
	sep.custom_minimum_size = Vector2(2, 22)
	hbox.add_child(sep)

	_souls_lbl = _lbl("ψ  --- Souls", 20, C_GOLD, 2, Color(0, 0, 0, 0.8))
	hbox.add_child(_souls_lbl)


# ── Sezione personaggi ────────────────────────────────────────────────────────

func _build_characters(vbox: Control) -> void:
	vbox.add_child(_section_lbl("PERSONAGGIO"))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(hbox)

	for char_id in MetaManager.CHARACTERS:
		var card := _build_char_card(char_id)
		_char_panels[char_id] = card
		hbox.add_child(card)


func _build_char_card(char_id: String) -> PanelContainer:
	var cd: Dictionary = MetaManager.CHARACTERS[char_id]
	var col: Color   = cd.get("color", Color.CYAN)
	var unlocked: bool = char_id in MetaManager.unlocked_characters

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(175, 130)

	var card_style := _mk_style(C_PAN, col if unlocked else C_DIM, 10, 2 if unlocked else 1)
	card_style.content_margin_left   = 12.0
	card_style.content_margin_right  = 12.0
	card_style.content_margin_top    = 10.0
	card_style.content_margin_bottom = 10.0
	pc.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	pc.add_child(vbox)

	# nome personaggio
	var name_lbl := _lbl(cd.get("name", char_id), 15,
		col if unlocked else C_DIM, 1, Color(0, 0, 0, 0.7))
	vbox.add_child(name_lbl)

	if not unlocked:
		var hint := _lbl("🔒  " + _unlock_hint(char_id), 11, C_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(hint)
	else:
		var lv: int = MetaManager.character_levels.get(char_id, 1)
		vbox.add_child(_lbl("Lv. %d" % lv, 12, C_HI))

		# barra XP
		var xp_cur: int = MetaManager.character_xp.get(char_id, 0)
		var xp_max: int = MetaManager.xp_for_next_level(char_id)
		var xpbar := ProgressBar.new()
		xpbar.min_value = 0
		xpbar.max_value = maxi(xp_max, 1)
		xpbar.value = xp_cur
		xpbar.show_percentage = false
		xpbar.custom_minimum_size = Vector2(0, 8)
		var xp_fill := _mk_style(col.lerp(Color.WHITE, 0.25), Color.TRANSPARENT, 4, 0)
		var xp_bg   := _mk_style(Color(0.10, 0.10, 0.20), Color.TRANSPARENT, 4, 0)
		xpbar.add_theme_stylebox_override("fill",       xp_fill)
		xpbar.add_theme_stylebox_override("background", xp_bg)
		vbox.add_child(xpbar)

		var xp_lbl := _lbl("%d / %d XP" % [xp_cur, xp_max], 10, C_DIM)
		vbox.add_child(xp_lbl)

		var desc := _lbl(cd.get("description", ""), 12, C_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

	# bottone seleziona
	var btn := Button.new()
	btn.text = "✓ Selezionato" if char_id == MetaManager.selected_character else \
			   ("Seleziona" if unlocked else "Locked")
	btn.disabled = not unlocked or char_id == MetaManager.selected_character
	btn.add_theme_font_size_override("font_size", 12)
	var cid := char_id
	btn.pressed.connect(func(): _select_char(cid))
	vbox.add_child(btn)

	return pc


func _unlock_hint(char_id: String) -> String:
	var cond: String = MetaManager.CHARACTERS[char_id].get("unlock_condition", "")
	match cond:
		"reach_wave_10":          return "Raggiungi wave 10"
		"earn_1000_souls":        return "Guadagna 1000 Souls"
		"complete_run_all_chars": return "Completa run con tutti"
		_:                        return "Locked"


# ── Sezione talenti ────────────────────────────────────────────────────────────

func _build_talents(vbox: Control) -> void:
	vbox.add_child(_section_lbl("TALENTI"))

	_talent_row = HBoxContainer.new()
	_talent_row.add_theme_constant_override("separation", 0)
	vbox.add_child(_talent_row)


func _refresh_talents() -> void:
	for c in _talent_row.get_children():
		c.queue_free()

	if _selected_char.is_empty():
		return

	var char_data: Dictionary = MetaManager.CHARACTERS.get(_selected_char, {})
	var talent_ids: Array = char_data.get("talent_ids", [])

	for i in talent_ids.size():
		if i > 0:
			var arrow := _lbl("  ›  ", 20, C_ACC)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_talent_row.add_child(arrow)
		_talent_row.add_child(_build_talent_card(talent_ids[i]))


func _build_talent_card(tid: String) -> PanelContainer:
	var t: Dictionary  = MetaManager.TALENTS.get(tid, {})
	var owned: bool    = tid in MetaManager.unlocked_talents
	var can_buy: bool  = MetaManager.can_unlock_talent(tid)
	var cost: int      = t.get("cost", 0)
	var col := C_GREEN if owned else (C_ACC if can_buy else C_DIM)

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(195, 108)
	var s := _mk_style(C_PAN, col, 10, 2)
	s.content_margin_left   = 12.0
	s.content_margin_right  = 12.0
	s.content_margin_top    = 8.0
	s.content_margin_bottom = 8.0
	pc.add_theme_stylebox_override("panel", s)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	pc.add_child(vbox)

	vbox.add_child(_lbl(t.get("name", tid), 14, col, 1, Color(0, 0, 0, 0.7)))

	var desc := _lbl(t.get("description", ""), 12, C_HI)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# spacer
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sp)

	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 11)

	if owned:
		btn.text = "✓ Acquistato"
		btn.disabled = true
		btn.modulate = C_GREEN
	elif can_buy:
		btn.text = "Acquista  ψ %d" % cost
		btn.modulate = C_GOLD
		var captured_tid := tid
		btn.pressed.connect(func():
			if MetaManager.unlock_talent(captured_tid):
				_refresh_all())
	else:
		var req: String = t.get("requires", "")
		if req != "" and req not in MetaManager.unlocked_talents:
			var req_name: String = MetaManager.TALENTS.get(req, {}).get("name", req)
			btn.text = "🔒 Prima: %s" % req_name
		elif MetaManager.total_souls < cost:
			btn.text = "ψ %d (insufficienti)" % cost
		else:
			btn.text = "🔒 Locked"
		btn.disabled = true
		btn.modulate = C_DIM

	vbox.add_child(btn)
	return pc


# ── Sezione skin ───────────────────────────────────────────────────────────────

func _build_skins(vbox: Control) -> void:
	vbox.add_child(_section_lbl("SKIN"))

	_skin_row = HBoxContainer.new()
	_skin_row.add_theme_constant_override("separation", 12)
	vbox.add_child(_skin_row)


func _refresh_skins() -> void:
	for c in _skin_row.get_children():
		c.queue_free()

	if _selected_char not in SKINS:
		return

	var skins: Array = SKINS[_selected_char]
	var sel_idx: int = _skin_sel.get(_selected_char, 0)

	for i in skins.size():
		var s      = skins[i]
		var col: Color = s["color"]
		var cost: int  = s["cost"]
		var is_sel := (i == sel_idx)
		var owned  := (cost == 0) or _skin_owned.get(_selected_char + "_" + str(i), false)

		var border_col := col if (is_sel or owned) else C_DIM
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(115, 80)
		var ps := _mk_style(C_PAN if not is_sel else Color(col.r * 0.18, col.g * 0.18, col.b * 0.18),
			border_col, 10, 3 if is_sel else 1)
		ps.content_margin_left   = 10.0
		ps.content_margin_right  = 10.0
		ps.content_margin_top    = 7.0
		ps.content_margin_bottom = 7.0
		pc.add_theme_stylebox_override("panel", ps)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		pc.add_child(vbox)

		# anteprima colore
		var dot := ColorRect.new()
		dot.color = col
		dot.custom_minimum_size = Vector2(24, 16)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(dot)

		vbox.add_child(_lbl(s["name"], 12, col if owned else C_DIM))

		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 11)
		var ci := i
		var char_id := _selected_char

		if is_sel:
			btn.text = "✓ Attiva"
			btn.disabled = true
		elif owned:
			btn.text = "Seleziona"
			btn.pressed.connect(func():
				_skin_sel[char_id] = ci
				_refresh_skins())
		else:
			btn.text = "ψ %d" % cost
			btn.modulate = C_GOLD
			btn.pressed.connect(func():
				if MetaManager.total_souls >= cost:
					MetaManager.total_souls -= cost
					_skin_owned[char_id + "_" + str(ci)] = true
					_skin_sel[char_id] = ci
					MetaManager.save_progress()
					_refresh_all())

		vbox.add_child(btn)
		_skin_row.add_child(pc)


# ── Sezione poteri attivabili ─────────────────────────────────────────────────

func _build_powers(vbox: Control) -> void:
	vbox.add_child(_section_lbl("POTERI ATTIVABILI  [E / Y]"))

	_power_row = HBoxContainer.new()
	_power_row.add_theme_constant_override("separation", 14)
	vbox.add_child(_power_row)
	_refresh_powers()


func _refresh_powers() -> void:
	if _power_row == null:
		return
	for c in _power_row.get_children():
		c.queue_free()

	for pw in POWERS:
		var pw_id: String  = pw["id"]
		var owned: bool    = (pw["cost"] == 0) or _power_owned.get(pw_id, false)
		var is_sel: bool   = (pw_id == _power_sel)
		var col: Color     = C_ACC if owned else C_DIM
		if is_sel:
			col = C_GREEN

		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(180, 110)
		var ps := _mk_style(
			Color(col.r * 0.14, col.g * 0.14, col.b * 0.14, 0.95) if is_sel else C_PAN,
			col, 10, 3 if is_sel else 1)
		ps.content_margin_left   = 12.0
		ps.content_margin_right  = 12.0
		ps.content_margin_top    = 8.0
		ps.content_margin_bottom = 8.0
		pc.add_theme_stylebox_override("panel", ps)

		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		pc.add_child(inner)

		# Riga icona + nome
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 6)
		inner.add_child(title_row)
		title_row.add_child(_lbl(pw["icon"], 18, col))
		var nm := _lbl(pw["name"], 13, col, 1, Color(0, 0, 0, 0.7))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(nm)

		# Cooldown
		inner.add_child(_lbl("CD: " + pw["cooldown"], 10, C_DIM))

		# Descrizione
		var desc := _lbl(pw["description"], 11, C_HI)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(desc)

		# Spacer
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inner.add_child(sp)

		# Bottone
		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 11)
		var captured_id := pw_id
		var captured_cost: int = pw["cost"]

		if is_sel:
			btn.text = "✓ Equipaggiato"
			btn.disabled = true
			btn.modulate = C_GREEN
		elif owned:
			btn.text = "Equipaggia"
			btn.modulate = C_ACC
			btn.pressed.connect(func():
				_power_sel = captured_id
				_refresh_powers())
		elif MetaManager.total_souls >= captured_cost:
			btn.text = "Acquista  ψ %d" % captured_cost
			btn.modulate = C_GOLD
			btn.pressed.connect(func():
				if MetaManager.total_souls >= captured_cost:
					MetaManager.total_souls -= captured_cost
					_power_owned[captured_id] = true
					_power_sel = captured_id
					MetaManager.save_progress()
					_refresh_all())
		else:
			btn.text = "ψ %d (insufficienti)" % captured_cost
			btn.disabled = true
			btn.modulate = C_DIM

		inner.add_child(btn)
		_power_row.add_child(pc)

	# Card "Nessun potere" (per de-selezionare)
	var none_pc := PanelContainer.new()
	none_pc.custom_minimum_size = Vector2(90, 110)
	var none_sel := (_power_sel == "")
	var none_col := C_DIM if not none_sel else C_RED
	var nps := _mk_style(
		Color(none_col.r * 0.12, none_col.g * 0.12, none_col.b * 0.12, 0.9) if none_sel else C_PAN,
		none_col, 10, 2 if none_sel else 1)
	nps.content_margin_left   = 12.0
	nps.content_margin_right  = 12.0
	nps.content_margin_top    = 8.0
	nps.content_margin_bottom = 8.0
	none_pc.add_theme_stylebox_override("panel", nps)

	var ni := VBoxContainer.new()
	ni.alignment = BoxContainer.ALIGNMENT_CENTER
	ni.add_theme_constant_override("separation", 6)
	none_pc.add_child(ni)
	ni.add_child(_lbl("✕", 22, none_col))
	ni.add_child(_lbl("Nessuno", 11, none_col))

	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ni.add_child(sp2)

	var none_btn := Button.new()
	none_btn.add_theme_font_size_override("font_size", 10)
	if none_sel:
		none_btn.text = "✓ Selezionato"
		none_btn.disabled = true
	else:
		none_btn.text = "Rimuovi"
		none_btn.modulate = C_DIM
		none_btn.pressed.connect(func():
			_power_sel = ""
			_refresh_powers())
	ni.add_child(none_btn)
	_power_row.add_child(none_pc)


# ── Bottom bar (start run) ────────────────────────────────────────────────────

func _build_bottom(vbox: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 22)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var btn1 := _action_btn("▶   GIOCA  1P", C_ACC)
	btn1.pressed.connect(func(): _start_run(1))
	hbox.add_child(btn1)

	var btn2 := _action_btn("▶▶   GIOCA  2P", Color(0.20, 0.85, 1.00))
	btn2.pressed.connect(func(): _start_run(2))
	hbox.add_child(btn2)


func _action_btn(txt: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(210, 54)
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	var bg_col  := Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.92)
	var hov_col := Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.95)

	var sn := _mk_style(bg_col,  col, 12, 2)
	var sh := _mk_style(hov_col, col, 12, 3)
	var sp := _mk_style(hov_col, Color.WHITE, 12, 2)

	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sp)
	return btn


# ══════════════════════════════════════════════
#  Logica selezione + avvio
# ══════════════════════════════════════════════

func _select_char(char_id: String) -> void:
	if char_id not in MetaManager.CHARACTERS:
		return
	if char_id not in MetaManager.unlocked_characters:
		return

	_selected_char = char_id
	MetaManager.selected_character = char_id

	# Aggiorna highlight carte
	for cid in _char_panels:
		var unlocked := cid in MetaManager.unlocked_characters
		var col: Color = MetaManager.CHARACTERS[cid].get("color", Color.CYAN) if unlocked else C_DIM
		var is_sel := (cid == _selected_char)
		var s := _mk_style(
			Color(col.r * 0.14, col.g * 0.14, col.b * 0.14) if is_sel else C_PAN,
			col, 10, 3 if is_sel else (2 if unlocked else 1))
		s.content_margin_left   = 12.0
		s.content_margin_right  = 12.0
		s.content_margin_top    = 10.0
		s.content_margin_bottom = 10.0
		_char_panels[cid].add_theme_stylebox_override("panel", s)

		# Aggiorna testo bottone selezione
		for child in _char_panels[cid].get_children():
			if child is VBoxContainer:
				for widget in child.get_children():
					if widget is Button:
						if unlocked:
							widget.text = "✓ Selezionato" if is_sel else "Seleziona"
							widget.disabled = is_sel

	_refresh_talents()
	_refresh_skins()


func _start_run(player_count: int) -> void:
	# Applica skin colore (modifica temporanea runtime)
	var skin_idx: int = _skin_sel.get(_selected_char, 0)
	if _selected_char in SKINS and skin_idx < SKINS[_selected_char].size():
		var skin_col: Color = SKINS[_selected_char][skin_idx]["color"]
		# GDScript const dict: la variabile è const, il contenuto è mutabile
		MetaManager.CHARACTERS[_selected_char]["color"] = skin_col

	# Salva il potere selezionato — player.gd lo legge con GameManager.get_meta("active_power")
	GameManager.set_meta("active_power", _power_sel)

	GameManager.player_count = player_count

	# Se nessuno ha connesso il segnale, naviga direttamente
	if start_run_requested.get_connections().size() == 0:
		if ResourceLoader.exists(game_scene_path):
			get_tree().change_scene_to_file(game_scene_path)
		else:
			push_warning("MetaHub: connetti start_run_requested oppure imposta game_scene_path")
		return

	start_run_requested.emit(player_count)


# ══════════════════════════════════════════════
#  Refresh
# ══════════════════════════════════════════════

func _refresh_all() -> void:
	_refresh_souls()
	_refresh_talents()
	_refresh_skins()
	_refresh_powers()


func _refresh_souls() -> void:
	if _souls_lbl:
		_souls_lbl.text = "ψ  %d Souls" % MetaManager.total_souls


func _refresh_ctrl_label() -> void:
	if _ctrl_lbl == null:
		return
	var controllers := Input.get_connected_joypads().size()
	if controllers > 0:
		_ctrl_lbl.text = "🎮  %d controller — 2P pronto" % controllers
		_ctrl_lbl.add_theme_color_override("font_color", C_GREEN)
	else:
		_ctrl_lbl.text = "Nessun controller"
		_ctrl_lbl.add_theme_color_override("font_color", C_DIM)


# ══════════════════════════════════════════════
#  Helpers
# ══════════════════════════════════════════════

func _mk_style(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
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


func _section_lbl(txt: String) -> Label:
	var l := _lbl("── " + txt + " ──", 15, C_ACC.darkened(0.10))
	return l
