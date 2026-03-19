extends Node
## MetaHub v3 — Hub tra le run con tab navigation
##
## Tab: PERSONAGGIO | TALENTI | ARMI | POTERI | SKIN
## Dual power slots: Q (primo) + E (secondo, sbloccabile ψ500)
## Armi: 6 weapon con effetti unici acquistabili con Souls

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
const C_CYAN  := Color(0.20, 0.90, 1.00)
const C_ORA   := Color(1.00, 0.55, 0.15)

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

const POWERS: Array = [
	# ── DIFENSIVI (Slot Q) ──────────────────────────────────────────────────
	{
		"id": "shield_burst", "name": "Shield Burst", "icon": "🛡",
		"slot": "defensive",
		"description": "Invincibile 1.5s. Perfetto per sopravvivere nei momenti critici.",
		"cost": 0, "cooldown": "8s",
	},
	{
		"id": "void_dash", "name": "Void Dash", "icon": "⚡",
		"slot": "defensive",
		"description": "Scatto rapido verso la mira. Invincibile durante il dash.",
		"cost": 150, "cooldown": "6s",
	},
	{
		"id": "void_shroud", "name": "Void Shroud", "icon": "🌑",
		"slot": "defensive",
		"description": "-50% danno ricevuto per 6 secondi. Diventa semi-trasparente.",
		"cost": 250, "cooldown": "12s",
	},
	{
		"id": "phase_shift", "name": "Phase Shift", "icon": "🔮",
		"slot": "defensive",
		"description": "Teleportati istantaneamente nella direzione della mira (800px).",
		"cost": 220, "cooldown": "8s",
	},
	{
		"id": "healing_nova", "name": "Healing Nova", "icon": "💚",
		"slot": "defensive",
		"description": "Cura tutti i player di 30 HP in un'area. Co-op friendly.",
		"cost": 280, "cooldown": "14s",
	},
	{
		"id": "temporal_barrier", "name": "Temporal Barrier", "icon": "⏸",
		"slot": "defensive",
		"description": "Crea uno scudo immobile che assorbe 150 danno per 4 secondi.",
		"cost": 350, "cooldown": "18s",
	},
	# ── OFFENSIVI (Slot E) ──────────────────────────────────────────────────
	{
		"id": "plasma_bomb", "name": "Plasma Bomb", "icon": "💥",
		"slot": "offensive",
		"description": "Esplosione AOE 5× danno in 250px. Letale tra i gruppi.",
		"cost": 0, "cooldown": "12s",
	},
	{
		"id": "time_surge", "name": "Time Surge", "icon": "⏳",
		"slot": "offensive",
		"description": "Rallenta tutti i nemici al 25% per 4 secondi.",
		"cost": 300, "cooldown": "18s",
	},
	{
		"id": "death_blossom", "name": "Death Blossom", "icon": "🌸",
		"slot": "offensive",
		"description": "Lancia 12 proiettili in cerchio. Copertura totale a 360°.",
		"cost": 280, "cooldown": "14s",
	},
	{
		"id": "singularity", "name": "Singularity", "icon": "🕳",
		"slot": "offensive",
		"description": "Black hole per 3s: attira e danneggia tutti i nemici vicini.",
		"cost": 400, "cooldown": "22s",
	},
	{
		"id": "void_storm", "name": "Void Storm", "icon": "🌪",
		"slot": "offensive",
		"description": "Scatena 20 proiettili casuali che rimbalzano per 3 secondi.",
		"cost": 320, "cooldown": "18s",
	},
	{
		"id": "chain_nova", "name": "Chain Nova", "icon": "⚡",
		"slot": "offensive",
		"description": "Fulmine che si concatena tra 6 nemici vicini. Danno cumulativo.",
		"cost": 250, "cooldown": "12s",
	},
]

const WEAPONS: Array = [
	{
		"id": "standard", "name": "Blaster Standard", "icon": "🔵",
		"description": "Bilanciato e affidabile. La tua arma di partenza.",
		"stats": "Danno ×1.0  •  Cadenza ×1.0  •  1 proiettile",
		"cost": 0, "rarity": "common",
	},
	{
		"id": "rapid", "name": "Rapid Fire", "icon": "⚡",
		"description": "Cadenza estrema. Pioggia di fuoco contro ondate di nemici.",
		"stats": "Danno ×0.7  •  Cadenza ×1.8  •  1 proiettile",
		"cost": 180, "rarity": "uncommon",
	},
	{
		"id": "spread", "name": "Cannone Spread", "icon": "🔱",
		"description": "Tre proiettili a ventaglio (±15°). Copertura totale.",
		"stats": "Danno ×0.8×3  •  Cadenza ×1.0  •  3 proiettili",
		"cost": 200, "rarity": "uncommon",
	},
	{
		"id": "twin", "name": "Twin Blaster", "icon": "🔷",
		"description": "Due colpi paralleli per ogni sparo. Doppia copertura.",
		"stats": "Danno ×0.9×2  •  Cadenza ×1.0  •  2 proiettili paralleli",
		"cost": 250, "rarity": "rare",
	},
	{
		"id": "heavy", "name": "Cannone Pesante", "icon": "💣",
		"description": "Un colpo devastante che perfora fino a 2 nemici. Lento ma letale.",
		"stats": "Danno ×2.8  •  Cadenza ×0.57  •  Pierce +2",
		"cost": 300, "rarity": "rare",
	},
	{
		"id": "void_seeker", "name": "Void Seeker", "icon": "🌀",
		"description": "Il proiettile cerca il nemico più vicino entro 400px. Zero sprechi.",
		"stats": "Danno ×1.2  •  Cadenza ×1.0  •  Tracking auto",
		"cost": 350, "rarity": "legendary",
	},
]

const RARITY_COLORS: Dictionary = {
	"common":    Color(0.72, 0.72, 0.82),
	"uncommon":  Color(0.22, 0.92, 0.42),
	"rare":      Color(0.30, 0.60, 1.00),
	"legendary": Color(1.00, 0.68, 0.10),
}

const POWERS_SAVE_PATH   := "user://powers_selection.json"
const SLOT_E_UNLOCK_COST := 500

const TAB_ICONS:  Array = ["👤", "🌟", "🔫", "⚡", "🎨"]
const TAB_LABELS: Array = ["PERSONAGGIO", "TALENTI", "ARMI", "POTERI", "SKIN"]

# ── Stato ─────────────────────────────────────────────────────────────────────
var _canvas: CanvasLayer
var _souls_lbl: Label
var _ctrl_lbl:  Label
var _char_panels:  Dictionary = {}
var _talent_row:   HBoxContainer = null
var _skin_row:     HBoxContainer = null
var _weapon_row:   HBoxContainer = null
var _power_slots_row: HBoxContainer = null
var _power_list_row:  HBoxContainer = null
var _selected_char: String = ""
var _skin_sel:    Dictionary = {}
var _skin_owned:  Dictionary = {}
var _power_q:     String = ""
var _power_e:     String = ""
var _power_owned: Dictionary = {}
var _slot_e_unlocked: bool = false
var _weapon_sel:  String = "standard"
var _weapon_owned: Dictionary = {"standard": true}
var _tab_pages:   Array = []
var _tab_buttons: Array = []
var _active_tab:  int   = 0


# ══════════════════════════════════════════════
#  Init
# ══════════════════════════════════════════════

func _ready() -> void:
	for cid in SKINS:
		_skin_sel[cid] = 0
	_load_powers()

	_canvas = CanvasLayer.new()
	_canvas.layer = 5
	add_child(_canvas)
	_build_ui()

	var start_char: String = MetaManager.selected_character \
		if MetaManager.selected_character in MetaManager.CHARACTERS \
		else "void_sentinel"
	_select_char(start_char)

	if InputManager.has_signal("controller_connected"):
		InputManager.controller_connected.connect(func(_id): _refresh_ctrl_label())
		InputManager.controller_disconnected.connect(func(_id): _refresh_ctrl_label())
	_refresh_ctrl_label()

	# Controller: rende tutti i bottoni del MetaHub navigabili con D-pad/stick
	_set_all_buttons_focusable(_canvas)


# ══════════════════════════════════════════════
#  Build UI
# ══════════════════════════════════════════════

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 28; vbox.offset_right  = -28
	vbox.offset_top  = 14; vbox.offset_bottom = -14
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)

	_build_topbar(vbox)
	_build_tabbar(vbox)

	# Area contenuto con scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(content_vbox)

	for i in TAB_LABELS.size():
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 12)
		page.visible = false
		content_vbox.add_child(page)
		_tab_pages.append(page)
		_populate_page(i, page)

	_build_bottom(vbox)
	_switch_tab(0)


func _build_topbar(vbox: Control) -> void:
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, 52)
	bar.add_theme_stylebox_override("panel", _mk_style(C_PAN, C_ACC, 10, 2))
	vbox.add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 18; hbox.offset_right  = -18
	hbox.offset_top  = 9;  hbox.offset_bottom = -9
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


func _build_tabbar(vbox: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	for i in TAB_LABELS.size():
		var btn := Button.new()
		btn.text = "%s %s" % [TAB_ICONS[i], TAB_LABELS[i]]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 12)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ci := i
		btn.pressed.connect(func(): _switch_tab(ci))
		hbox.add_child(btn)
		_tab_buttons.append(btn)


func _populate_page(idx: int, page: VBoxContainer) -> void:
	match idx:
		0: _build_page_characters(page)
		1: _build_page_talents(page)
		2: _build_page_weapons(page)
		3: _build_page_powers(page)
		4: _build_page_skins(page)


func _switch_tab(idx: int) -> void:
	_active_tab = idx
	for i in _tab_pages.size():
		_tab_pages[i].visible = (i == idx)
	_update_tab_buttons()
	_refresh_tab(idx)


func _update_tab_buttons() -> void:
	for i in _tab_buttons.size():
		var btn: Button = _tab_buttons[i]
		var active := (i == _active_tab)
		btn.add_theme_stylebox_override("normal",
			_mk_style(C_ACC.darkened(0.5) if active else C_PAN,
					  C_ACC if active else C_DIM, 8, 2 if active else 1))
		btn.add_theme_color_override("font_color", C_HI if active else C_DIM)


func _refresh_tab(idx: int) -> void:
	_refresh_souls()
	match idx:
		0: _refresh_characters()
		1: _refresh_talents()
		2: _refresh_weapons()
		3: _refresh_powers()
		4: _refresh_skins()


# ── PAGE: PERSONAGGIO ────────────────────────────────────────────────────────

func _build_page_characters(page: VBoxContainer) -> void:
	page.add_child(_section_lbl("SCEGLI IL TUO PERSONAGGIO"))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	page.add_child(hbox)
	for char_id in MetaManager.CHARACTERS:
		var card := _build_char_card(char_id)
		_char_panels[char_id] = card
		hbox.add_child(card)


func _build_char_card(char_id: String) -> PanelContainer:
	var cd: Dictionary  = MetaManager.CHARACTERS[char_id]
	var col: Color      = cd.get("color", Color.CYAN)
	var unlocked: bool  = char_id in MetaManager.unlocked_characters

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(175, 130)
	var cs := _mk_style(C_PAN, col if unlocked else C_DIM, 10, 2 if unlocked else 1)
	cs.content_margin_left   = 12.0; cs.content_margin_right  = 12.0
	cs.content_margin_top    = 10.0; cs.content_margin_bottom = 10.0
	pc.add_theme_stylebox_override("panel", cs)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	pc.add_child(vbox)
	vbox.add_child(_lbl(cd.get("name", char_id), 15, col if unlocked else C_DIM, 1, Color(0,0,0,0.7)))

	if not unlocked:
		var hint := _lbl("🔒  " + _unlock_hint(char_id), 11, C_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(hint)
	else:
		var lv: int = MetaManager.character_levels.get(char_id, 1)
		vbox.add_child(_lbl("Lv. %d" % lv, 12, C_HI))
		var xp_cur: int = MetaManager.character_xp.get(char_id, 0)
		var xp_max: int = MetaManager.xp_for_next_level(char_id)
		var xpbar := ProgressBar.new()
		xpbar.min_value = 0; xpbar.max_value = maxi(xp_max, 1); xpbar.value = xp_cur
		xpbar.show_percentage = false; xpbar.custom_minimum_size = Vector2(0, 8)
		xpbar.add_theme_stylebox_override("fill",
			_mk_style(col.lerp(Color.WHITE, 0.25), Color.TRANSPARENT, 4, 0))
		xpbar.add_theme_stylebox_override("background",
			_mk_style(Color(0.10, 0.10, 0.20), Color.TRANSPARENT, 4, 0))
		vbox.add_child(xpbar)
		vbox.add_child(_lbl("%d / %d XP" % [xp_cur, xp_max], 10, C_DIM))
		var desc := _lbl(cd.get("description", ""), 12, C_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

	var btn := Button.new()
	btn.text = "✓ Selezionato" if char_id == MetaManager.selected_character else \
			   ("Seleziona" if unlocked else "Locked")
	btn.disabled = not unlocked or char_id == MetaManager.selected_character
	btn.add_theme_font_size_override("font_size", 12)
	var cid := char_id
	btn.pressed.connect(func(): _select_char(cid))
	vbox.add_child(btn)
	return pc


func _refresh_characters() -> void:
	for cid in _char_panels:
		var unlocked := cid in MetaManager.unlocked_characters
		var col: Color = MetaManager.CHARACTERS[cid].get("color", Color.CYAN) if unlocked else C_DIM
		var is_sel := (cid == _selected_char)
		var s := _mk_style(
			Color(col.r * 0.14, col.g * 0.14, col.b * 0.14) if is_sel else C_PAN,
			col, 10, 3 if is_sel else (2 if unlocked else 1))
		s.content_margin_left = 12.0; s.content_margin_right  = 12.0
		s.content_margin_top  = 10.0; s.content_margin_bottom = 10.0
		_char_panels[cid].add_theme_stylebox_override("panel", s)
		for child in _char_panels[cid].get_children():
			if child is VBoxContainer:
				for w in child.get_children():
					if w is Button and unlocked:
						w.text     = "✓ Selezionato" if is_sel else "Seleziona"
						w.disabled = is_sel


# ── PAGE: TALENTI ─────────────────────────────────────────────────────────────

func _build_page_talents(page: VBoxContainer) -> void:
	page.add_child(_section_lbl("TALENTI"))
	_talent_row = HBoxContainer.new()
	_talent_row.add_theme_constant_override("separation", 0)
	page.add_child(_talent_row)


func _refresh_talents() -> void:
	if _talent_row == null: return
	for c in _talent_row.get_children(): c.queue_free()
	if _selected_char.is_empty(): return
	var talent_ids: Array = MetaManager.CHARACTERS.get(_selected_char, {}).get("talent_ids", [])
	for i in talent_ids.size():
		if i > 0:
			var arrow := _lbl("  ›  ", 20, C_ACC)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_talent_row.add_child(arrow)
		_talent_row.add_child(_build_talent_card(talent_ids[i]))


func _build_talent_card(tid: String) -> PanelContainer:
	var t: Dictionary = MetaManager.TALENTS.get(tid, {})
	var owned: bool   = tid in MetaManager.unlocked_talents
	var can_buy: bool = MetaManager.can_unlock_talent(tid)
	var cost: int     = t.get("cost", 0)
	var col := C_GREEN if owned else (C_ACC if can_buy else C_DIM)

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(195, 108)
	var s := _mk_style(C_PAN, col, 10, 2)
	s.content_margin_left = 12.0; s.content_margin_right  = 12.0
	s.content_margin_top  = 8.0;  s.content_margin_bottom = 8.0
	pc.add_theme_stylebox_override("panel", s)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	pc.add_child(vbox)
	vbox.add_child(_lbl(t.get("name", tid), 14, col, 1, Color(0,0,0,0.7)))
	var desc := _lbl(t.get("description", ""), 12, C_HI)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sp)

	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 11)
	if owned:
		btn.text = "✓ Acquistato"; btn.disabled = true; btn.modulate = C_GREEN
	elif can_buy:
		btn.text = "Acquista  ψ %d" % cost; btn.modulate = C_GOLD
		var ct := tid
		btn.pressed.connect(func():
			if MetaManager.unlock_talent(ct): _refresh_tab(1))
	else:
		var req: String = t.get("requires", "")
		if req != "" and req not in MetaManager.unlocked_talents:
			btn.text = "🔒 Prima: %s" % MetaManager.TALENTS.get(req, {}).get("name", req)
		elif MetaManager.total_souls < cost:
			btn.text = "ψ %d (insufficienti)" % cost
		else:
			btn.text = "🔒 Locked"
		btn.disabled = true; btn.modulate = C_DIM
	vbox.add_child(btn)
	return pc


# ── PAGE: ARMI ────────────────────────────────────────────────────────────────

func _build_page_weapons(page: VBoxContainer) -> void:
	page.add_child(_section_lbl("ARSENALE  —  scegli l'arma per la run"))
	_weapon_row = HBoxContainer.new()
	_weapon_row.add_theme_constant_override("separation", 14)
	page.add_child(_weapon_row)


func _refresh_weapons() -> void:
	if _weapon_row == null: return
	for c in _weapon_row.get_children(): c.queue_free()

	for wp in WEAPONS:
		var wp_id: String = wp["id"]
		var owned: bool   = _weapon_owned.get(wp_id, wp["cost"] == 0)
		var is_sel: bool  = (wp_id == _weapon_sel)
		var rc: Color     = RARITY_COLORS.get(wp["rarity"], C_DIM)
		var col: Color    = C_GREEN if is_sel else (rc if owned else C_DIM)

		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(175, 175)
		var ps := _mk_style(
			Color(col.r*0.14, col.g*0.14, col.b*0.14, 0.95) if is_sel else C_PAN,
			col, 10, 3 if is_sel else (2 if owned else 1))
		ps.content_margin_left = 12.0; ps.content_margin_right  = 12.0
		ps.content_margin_top  = 10.0; ps.content_margin_bottom = 10.0
		pc.add_theme_stylebox_override("panel", ps)

		var iv := VBoxContainer.new()
		iv.add_theme_constant_override("separation", 5)
		pc.add_child(iv)

		var hdr := HBoxContainer.new()
		hdr.add_theme_constant_override("separation", 8)
		iv.add_child(hdr)
		hdr.add_child(_lbl(wp["icon"], 22, col))
		var nv := VBoxContainer.new()
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_theme_constant_override("separation", 2)
		hdr.add_child(nv)
		nv.add_child(_lbl(wp["name"], 13, col, 1, Color(0,0,0,0.7)))
		nv.add_child(_lbl(wp["rarity"].to_upper(), 9, rc))

		var sl := _lbl(wp["stats"], 10, C_CYAN)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		iv.add_child(sl)

		var dl := _lbl(wp["description"], 11, C_HI)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		iv.add_child(dl)

		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 11)
		var cid := wp_id
		var ccost: int = wp["cost"]

		if is_sel:
			btn.text = "✓ Equipaggiata"; btn.disabled = true; btn.modulate = C_GREEN
		elif owned:
			btn.text = "Equipaggia"; btn.modulate = C_ACC
			btn.pressed.connect(func():
				_weapon_sel = cid; _save_powers(); _refresh_weapons())
		elif MetaManager.total_souls >= ccost:
			btn.text = "Acquista  ψ %d" % ccost; btn.modulate = C_GOLD
			btn.pressed.connect(func():
				if MetaManager.total_souls >= ccost:
					MetaManager.total_souls -= ccost
					_weapon_owned[cid] = true; _weapon_sel = cid
					MetaManager.save_progress(); _save_powers(); _refresh_all())
		else:
			btn.text = "ψ %d (insufficienti)" % ccost
			btn.disabled = true; btn.modulate = C_DIM

		iv.add_child(btn)
		_weapon_row.add_child(pc)


# ── PAGE: POTERI ──────────────────────────────────────────────────────────────

func _build_page_powers(page: VBoxContainer) -> void:
	page.add_child(_section_lbl("SLOT POTERI ATTIVABILI"))

	_power_slots_row = HBoxContainer.new()
	_power_slots_row.add_theme_constant_override("separation", 20)
	page.add_child(_power_slots_row)

	var div := ColorRect.new()
	div.color = Color(C_ACC.r, C_ACC.g, C_ACC.b, 0.20)
	div.custom_minimum_size = Vector2(0, 1)
	page.add_child(div)

	page.add_child(_section_lbl("POTERI DISPONIBILI"))

	_power_list_row = HBoxContainer.new()
	_power_list_row.add_theme_constant_override("separation", 14)
	page.add_child(_power_list_row)

	# Pulsanti rimozione
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 14)
	page.add_child(nr)
	var nq := _btn_small("✕  Rimuovi da [Q]", C_DIM)
	nq.pressed.connect(func(): _power_q = ""; _save_powers(); _refresh_powers())
	nr.add_child(nq)
	var ne := _btn_small("✕  Rimuovi da [E]", C_DIM)
	ne.pressed.connect(func(): _power_e = ""; _save_powers(); _refresh_powers())
	nr.add_child(ne)


func _refresh_powers() -> void:
	if _power_slots_row == null or _power_list_row == null:
		return

	# ── Slot preview ─────────────────────────────────────────────────────────
	for c in _power_slots_row.get_children(): c.queue_free()

	for slot_idx in 2:
		var is_q    := (slot_idx == 0)
		var sid     := "Q" if is_q else "E"
		var pw_id   := _power_q if is_q else _power_e
		var locked  := (not is_q) and (not _slot_e_unlocked)
		var sc: Color = C_CYAN if is_q else C_ORA

		var pw: Dictionary = {}
		for p in POWERS:
			if p["id"] == pw_id: pw = p; break

		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(270, 85)
		var ps := _mk_style(
			Color(sc.r*0.10, sc.g*0.10, sc.b*0.10, 0.95),
			sc if not locked else C_DIM, 10, 2)
		ps.content_margin_left = 14.0; ps.content_margin_right  = 14.0
		ps.content_margin_top  = 10.0; ps.content_margin_bottom = 10.0
		pc.add_theme_stylebox_override("panel", ps)

		var ih := HBoxContainer.new()
		ih.add_theme_constant_override("separation", 12)
		pc.add_child(ih)

		# Badge tasto
		var bc: Color = sc if not locked else C_DIM
		var bp := PanelContainer.new()
		var bps := _mk_style(Color(bc.r*0.20, bc.g*0.20, bc.b*0.20), bc, 8, 2)
		bps.content_margin_left = 8.0; bps.content_margin_right  = 8.0
		bps.content_margin_top  = 4.0; bps.content_margin_bottom = 4.0
		bp.add_theme_stylebox_override("panel", bps)
		bp.add_child(_lbl("[%s]" % sid, 18, bc, 1, Color(0,0,0,0.9)))
		ih.add_child(bp)

		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 3)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ih.add_child(tv)

		if locked:
			tv.add_child(_lbl("🔒  Slot bloccato", 13, C_DIM))
			var ub := Button.new()
			ub.text = "Sblocca  ψ %d" % SLOT_E_UNLOCK_COST
			ub.add_theme_font_size_override("font_size", 12)
			ub.modulate = C_GOLD if MetaManager.total_souls >= SLOT_E_UNLOCK_COST else C_DIM
			ub.pressed.connect(func():
				if MetaManager.total_souls >= SLOT_E_UNLOCK_COST:
					MetaManager.total_souls -= SLOT_E_UNLOCK_COST
					_slot_e_unlocked = true
					MetaManager.save_progress(); _save_powers()
					_refresh_powers(); _refresh_souls())
			tv.add_child(ub)
		elif pw_id.is_empty():
			tv.add_child(_lbl("— Nessun potere —", 13, C_DIM))
			tv.add_child(_lbl("Assegna dal catalogo qui sotto.", 10, C_DIM))
		else:
			tv.add_child(_lbl("%s  %s" % [pw.get("icon",""), pw.get("name","")], 14, sc, 1, Color(0,0,0,0.8)))
			tv.add_child(_lbl("CD: %s  —  %s" % [pw.get("cooldown","?"), pw.get("description","")], 10, C_HI))

		_power_slots_row.add_child(pc)

	# ── Catalogo poteri ───────────────────────────────────────────────────────
	for c in _power_list_row.get_children(): c.queue_free()

	for pw in POWERS:
		var pw_id: String = pw["id"]
		var owned: bool   = (pw["cost"] == 0) or _power_owned.get(pw_id, false)
		var in_q := (_power_q == pw_id)
		var in_e := (_power_e == pw_id)
		var col: Color = (C_CYAN if in_q else (C_ORA if in_e else (C_ACC if owned else C_DIM)))

		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(190, 145)
		var ps := _mk_style(
			Color(col.r*0.10, col.g*0.10, col.b*0.10, 0.95) if (in_q or in_e) else C_PAN,
			col, 10, 3 if (in_q or in_e) else (2 if owned else 1))
		ps.content_margin_left = 12.0; ps.content_margin_right  = 12.0
		ps.content_margin_top  = 8.0;  ps.content_margin_bottom = 8.0
		pc.add_theme_stylebox_override("panel", ps)

		var iv := VBoxContainer.new()
		iv.add_theme_constant_override("separation", 4)
		pc.add_child(iv)

		var hr := HBoxContainer.new()
		hr.add_theme_constant_override("separation", 6)
		iv.add_child(hr)
		hr.add_child(_lbl(pw["icon"], 20, col))
		var nv := VBoxContainer.new()
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_theme_constant_override("separation", 2)
		hr.add_child(nv)
		nv.add_child(_lbl(pw["name"], 13, col if owned else C_DIM, 1, Color(0,0,0,0.7)))
		nv.add_child(_lbl("CD: " + pw["cooldown"], 10, C_DIM))

		var dl := _lbl(pw["description"], 11, C_HI)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		iv.add_child(dl)

		var br := HBoxContainer.new()
		br.add_theme_constant_override("separation", 6)
		iv.add_child(br)

		var cid := pw_id
		var ccost: int = pw["cost"]

		if owned:
			var qb := Button.new()
			qb.text = "✓[Q]" if in_q else "→[Q]"
			qb.add_theme_font_size_override("font_size", 11)
			qb.disabled = in_q
			qb.add_theme_color_override("font_color", C_CYAN if in_q else C_HI)
			qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			qb.pressed.connect(func(): _power_q = cid; _save_powers(); _refresh_powers())
			br.add_child(qb)

			var eb := Button.new()
			eb.text = "✓[E]" if in_e else "→[E]"
			eb.add_theme_font_size_override("font_size", 11)
			eb.disabled = in_e or not _slot_e_unlocked
			eb.add_theme_color_override("font_color",
				C_ORA if in_e else (C_HI if _slot_e_unlocked else C_DIM))
			eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			eb.pressed.connect(func(): _power_e = cid; _save_powers(); _refresh_powers())
			br.add_child(eb)
		elif MetaManager.total_souls >= ccost:
			var bb := Button.new()
			bb.text = "Acquista  ψ %d" % ccost
			bb.add_theme_font_size_override("font_size", 11)
			bb.modulate = C_GOLD
			bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bb.pressed.connect(func():
				if MetaManager.total_souls >= ccost:
					MetaManager.total_souls -= ccost
					_power_owned[cid] = true; _power_q = cid
					MetaManager.save_progress(); _save_powers(); _refresh_all())
			br.add_child(bb)
		else:
			var lb := Button.new()
			lb.text = "ψ %d (insufficienti)" % ccost
			lb.add_theme_font_size_override("font_size", 11)
			lb.disabled = true; lb.modulate = C_DIM
			lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			br.add_child(lb)

		_power_list_row.add_child(pc)


# ── PAGE: SKIN ────────────────────────────────────────────────────────────────

func _build_page_skins(page: VBoxContainer) -> void:
	page.add_child(_section_lbl("SKIN  —  personalizza il tuo personaggio"))
	_skin_row = HBoxContainer.new()
	_skin_row.add_theme_constant_override("separation", 12)
	page.add_child(_skin_row)


func _refresh_skins() -> void:
	if _skin_row == null: return
	for c in _skin_row.get_children(): c.queue_free()
	if _selected_char not in SKINS: return

	var skins: Array = SKINS[_selected_char]
	var sel_idx: int = _skin_sel.get(_selected_char, 0)

	for i in skins.size():
		var s = skins[i]
		var col: Color = s["color"]
		var cost: int  = s["cost"]
		var is_sel := (i == sel_idx)
		var owned  := (cost == 0) or _skin_owned.get(_selected_char + "_" + str(i), false)

		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(115, 80)
		var ps := _mk_style(
			C_PAN if not is_sel else Color(col.r*0.18, col.g*0.18, col.b*0.18),
			col if (is_sel or owned) else C_DIM, 10, 3 if is_sel else 1)
		ps.content_margin_left = 10.0; ps.content_margin_right  = 10.0
		ps.content_margin_top  = 7.0;  ps.content_margin_bottom = 7.0
		pc.add_theme_stylebox_override("panel", ps)

		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 4)
		pc.add_child(vb)

		var dot := ColorRect.new()
		dot.color = col; dot.custom_minimum_size = Vector2(24, 16)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(dot)
		vb.add_child(_lbl(s["name"], 12, col if owned else C_DIM))

		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 11)
		var ci := i; var char_id := _selected_char
		if is_sel:
			btn.text = "✓ Attiva"; btn.disabled = true
		elif owned:
			btn.text = "Seleziona"
			btn.pressed.connect(func(): _skin_sel[char_id] = ci; _refresh_skins())
		else:
			btn.text = "ψ %d" % cost; btn.modulate = C_GOLD
			btn.pressed.connect(func():
				if MetaManager.total_souls >= cost:
					MetaManager.total_souls -= cost
					_skin_owned[char_id + "_" + str(ci)] = true
					_skin_sel[char_id] = ci
					MetaManager.save_progress(); _refresh_all())
		vb.add_child(btn)
		_skin_row.add_child(pc)


# ── Bottom bar ────────────────────────────────────────────────────────────────

func _build_bottom(vbox: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 22)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var b1 := _btn_action("▶   GIOCA  1P", C_ACC)
	b1.pressed.connect(func(): _start_run(1))
	hbox.add_child(b1)

	var b2 := _btn_action("▶▶   GIOCA  2P", C_CYAN)
	b2.pressed.connect(func(): _start_run(2))
	hbox.add_child(b2)


# ══════════════════════════════════════════════
#  Logica
# ══════════════════════════════════════════════

func _select_char(char_id: String) -> void:
	if char_id not in MetaManager.CHARACTERS: return
	if char_id not in MetaManager.unlocked_characters: return
	_selected_char = char_id
	MetaManager.selected_character = char_id
	_refresh_characters()
	_refresh_talents()
	_refresh_skins()


func _start_run(player_count: int) -> void:
	var skin_idx: int = _skin_sel.get(_selected_char, 0)
	if _selected_char in SKINS and skin_idx < SKINS[_selected_char].size():
		MetaManager.CHARACTERS[_selected_char]["color"] = SKINS[_selected_char][skin_idx]["color"]

	GameManager.set_meta("active_power_q", _power_q)
	GameManager.set_meta("active_power_e", _power_e)
	GameManager.set_meta("active_weapon",  _weapon_sel)
	GameManager.player_count = player_count

	if start_run_requested.get_connections().size() == 0:
		if ResourceLoader.exists(game_scene_path):
			get_tree().change_scene_to_file(game_scene_path)
		else:
			push_warning("MetaHub: connetti start_run_requested o imposta game_scene_path")
		return
	start_run_requested.emit(player_count)


# ══════════════════════════════════════════════
#  Refresh
# ══════════════════════════════════════════════

func _refresh_all() -> void:
	_refresh_souls()
	_refresh_tab(_active_tab)


func _refresh_souls() -> void:
	if _souls_lbl:
		_souls_lbl.text = "ψ  %d Souls" % MetaManager.total_souls


func _refresh_ctrl_label() -> void:
	if _ctrl_lbl == null: return
	var controllers := Input.get_connected_joypads().size()
	if controllers > 0:
		_ctrl_lbl.text = "🎮  %d controller" % controllers
		_ctrl_lbl.add_theme_color_override("font_color", C_GREEN)
	else:
		_ctrl_lbl.text = "Nessun controller"
		_ctrl_lbl.add_theme_color_override("font_color", C_DIM)


# ══════════════════════════════════════════════
#  Persistenza
# ══════════════════════════════════════════════

func _save_powers() -> void:
	var data := {
		"power_q":         _power_q,
		"power_e":         _power_e,
		"power_owned":     _power_owned,
		"slot_e_unlocked": _slot_e_unlocked,
		"weapon_sel":      _weapon_sel,
		"weapon_owned":    _weapon_owned,
	}
	var file := FileAccess.open(POWERS_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
	else:
		push_warning("MetaHub: impossibile salvare in " + POWERS_SAVE_PATH)


func _load_powers() -> void:
	if not FileAccess.file_exists(POWERS_SAVE_PATH):
		return
	var file := FileAccess.open(POWERS_SAVE_PATH, FileAccess.READ)
	if not file: return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary: return

	# Compat con v2 (power_sel → power_e)
	_power_q         = parsed.get("power_q", "")
	_power_e         = parsed.get("power_e", parsed.get("power_sel", ""))
	_power_owned     = parsed.get("power_owned",     {})
	_slot_e_unlocked = parsed.get("slot_e_unlocked", false)
	_weapon_sel      = parsed.get("weapon_sel",  "standard")
	_weapon_owned    = parsed.get("weapon_owned", {"standard": true})
	_weapon_owned["standard"] = true   # sempre disponibile


# ══════════════════════════════════════════════
#  Helpers UI
# ══════════════════════════════════════════════

func _unlock_hint(char_id: String) -> String:
	match MetaManager.CHARACTERS[char_id].get("unlock_condition", ""):
		"reach_wave_10":          return "Raggiungi wave 10"
		"earn_1000_souls":        return "Guadagna 1000 Souls"
		"complete_run_all_chars": return "Completa run con tutti"
		_:                        return "Locked"


## Imposta focus_mode = FOCUS_ALL su ogni Button nel sub-tree di root.
## Permette navigazione con D-pad / stick sinistro del controller.
func _set_all_buttons_focusable(root: Node) -> void:
	if root is Button:
		(root as Button).focus_mode = Control.FOCUS_ALL
	for child in root.get_children():
		_set_all_buttons_focusable(child)


func _mk_style(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.border_width_left   = border_w; s.border_width_right  = border_w
	s.border_width_top    = border_w; s.border_width_bottom = border_w
	s.corner_radius_top_left     = radius; s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius; s.corner_radius_bottom_right = radius
	s.anti_aliasing = true; s.anti_aliasing_size = 1.5
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
	return _lbl("── " + txt + " ──", 15, C_ACC.darkened(0.10))


func _btn_action(txt: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(210, 54)
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	var bg  := Color(col.r*0.12, col.g*0.12, col.b*0.12, 0.92)
	var hov := Color(col.r*0.22, col.g*0.22, col.b*0.22, 0.95)
	btn.add_theme_stylebox_override("normal",  _mk_style(bg,  col, 12, 2))
	btn.add_theme_stylebox_override("hover",   _mk_style(hov, col, 12, 3))
	btn.add_theme_stylebox_override("pressed", _mk_style(hov, Color.WHITE, 12, 2))
	return btn


func _btn_small(txt: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = txt; btn.custom_minimum_size = Vector2(160, 34)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	var bg  := Color(col.r*0.12, col.g*0.12, col.b*0.12, 0.85)
	var hov := Color(col.r*0.22, col.g*0.22, col.b*0.22, 0.90)
	btn.add_theme_stylebox_override("normal",  _mk_style(bg,  col, 8, 1))
	btn.add_theme_stylebox_override("hover",   _mk_style(hov, col, 8, 2))
	btn.add_theme_stylebox_override("pressed", _mk_style(hov, Color.WHITE, 8, 1))
	return btn
