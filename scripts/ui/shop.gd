extends Node
class_name Shop
## Shop v1 — Negozio in-run di Void Surge
##
## Appare alla fine di ogni wave. Offre 4 oggetti casuali acquistabili con Souls.
## Gli effetti bonus vengono salvati in GameManager.set_meta("shop_bonuses", {...})
## e letti da player.gd in _recalculate_stats(). Si azzerano a fine run.
##
## Setup nel progetto:
##   1) Crea una scena (es. shop.tscn): Node con questo script attaccato
##   2) Aggiungi shop.tscn come figlio della game scene
##   3) Il nodo si aggancia automaticamente al segnale wave_ended del GameManager
##   4) Debug: premi F2 per aprire/chiudere lo shop durante una partita

signal shop_closed

@export var items_per_visit: int = 4
@export var debug_key_open: bool = true   ## F2 apre/chiude lo shop (per test)

# ── Palette (coerente con HUD e MetaHub) ──────────────────────────────────────
const C_BG    := Color(0.03, 0.01, 0.09, 0.97)
const C_PAN   := Color(0.07, 0.04, 0.16)
const C_ACC   := Color(0.55, 0.22, 1.00)
const C_GOLD  := Color(1.00, 0.82, 0.10)
const C_GREEN := Color(0.18, 1.00, 0.45)
const C_DIM   := Color(0.44, 0.44, 0.55)
const C_HI    := Color(0.88, 0.88, 1.00)

# ── Colori rarity ──────────────────────────────────────────────────────────────
const RARITY_COLORS: Dictionary = {
	"common":    Color(0.72, 0.72, 0.82),
	"uncommon":  Color(0.22, 0.92, 0.42),
	"rare":      Color(0.30, 0.60, 1.00),
	"legendary": Color(1.00, 0.68, 0.10),
}
# Più alto = più frequente nel pool
const RARITY_WEIGHTS: Dictionary = {
	"common": 50, "uncommon": 30, "rare": 15, "legendary": 5,
}

# ── Catalogo completo ──────────────────────────────────────────────────────────
## "fx" = tipo effetto  |  "val" = valore numerico
## Effetti disponibili:
##   heal            → cura val HP ai giocatori vivi
##   heal_full       → cura completamente tutti i giocatori
##   health_bonus    → +val HP massimi (permanente per la run)
##   health_bonus_heal → +val HP max + cura 30 HP
##   damage_pct      → danno moltiplicato × (1 + val)
##   speed_bonus     → +val velocità di movimento
##   fire_rate_bonus → -val secondi di fire_rate (più veloce)
##   crit_bonus      → +val probabilità critico
##   pierce          → +val proiettili piercing
##   souls_bonus     → ricevi subito val Souls
##   reroll          → rimescola gli oggetti nello shop
const ITEM_CATALOG: Array = [
	{
		"id": "heal_small", "name": "Nano-Riparazione",     "icon": "💚",
		"desc": "Ripristina 30 HP.",
		"cost": 40, "rarity": "common", "fx": "heal", "val": 30.0,
	},
	{
		"id": "heal_large", "name": "Rigenerazione Totale",  "icon": "❤️",
		"desc": "Ripristina tutti gli HP al massimo.",
		"cost": 110, "rarity": "rare", "fx": "heal_full", "val": 0.0,
	},
	{
		"id": "damage_up",  "name": "Nucleo al Plasma",      "icon": "⚡",
		"desc": "+20% danno per questa run.",
		"cost": 80, "rarity": "uncommon", "fx": "damage_pct", "val": 0.20,
	},
	{
		"id": "damage_xl",  "name": "Amplificatore Void",    "icon": "🌀",
		"desc": "+40% danno. Solo per i coraggiosi.",
		"cost": 165, "rarity": "legendary", "fx": "damage_pct", "val": 0.40,
	},
	{
		"id": "speed_up",   "name": "Booster Ionico",        "icon": "💨",
		"desc": "+50 velocità di movimento.",
		"cost": 60, "rarity": "common", "fx": "speed_bonus", "val": 50.0,
	},
	{
		"id": "fire_rate",  "name": "Modulo Cadenza",        "icon": "🔫",
		"desc": "Spari il 25% più veloce (fire rate -0.04s).",
		"cost": 90, "rarity": "uncommon", "fx": "fire_rate_bonus", "val": 0.04,
	},
	{
		"id": "crit_up",    "name": "Cristallo Critico",     "icon": "💎",
		"desc": "+8% probabilità critico.",
		"cost": 75, "rarity": "uncommon", "fx": "crit_bonus", "val": 0.08,
	},
	{
		"id": "pierce",     "name": "Proiettile Perforante", "icon": "🎯",
		"desc": "+1 nemico attraversato per proiettile.",
		"cost": 120, "rarity": "rare", "fx": "pierce", "val": 1.0,
	},
	{
		"id": "health_up",  "name": "Corazza Rinforzata",    "icon": "🛡️",
		"desc": "+30 HP massimi.",
		"cost": 75, "rarity": "common", "fx": "health_bonus", "val": 30.0,
	},
	{
		"id": "health_xl",  "name": "Nucleo Vitale",         "icon": "💜",
		"desc": "+60 HP massimi + cura immediata 30 HP.",
		"cost": 140, "rarity": "rare", "fx": "health_bonus_heal", "val": 60.0,
	},
	{
		"id": "souls_bonus","name": "Anomalia Souls",        "icon": "✨",
		"desc": "Ricevi subito 70 Souls extra.",
		"cost": 35, "rarity": "common", "fx": "souls_bonus", "val": 70.0,
	},
	{
		"id": "reroll",     "name": "Rimescola",             "icon": "🔄",
		"desc": "Rigenera tutti gli oggetti nello shop.",
		"cost": 90, "rarity": "rare", "fx": "reroll", "val": 0.0,
	},
]

# ── Stato ─────────────────────────────────────────────────────────────────────
var _canvas:        CanvasLayer
var _souls_lbl:     Label
var _item_grid:     HBoxContainer
var _title_lbl:     Label
var _current_items: Array = []
var _is_open:       bool  = false


# ══════════════════════════════════════════════
#  Avvio
# ══════════════════════════════════════════════

func _ready() -> void:
	add_to_group("shop")
	# PROCESS_MODE_ALWAYS: continua a funzionare anche quando get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(true)
	_build_ui()
	_hook_wave_signal()


## F2 via _unhandled_key_input: funziona anche con get_tree().paused = true
## e non viene "rubato" da altri nodi (più affidabile di _input per shortcut globali)
func _unhandled_key_input(event: InputEvent) -> void:
	if debug_key_open and event is InputEventKey \
			and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_F2:
		get_viewport().set_input_as_handled()
		if _is_open:
			_close()
		else:
			_open()


## Si aggancia al segnale wave_changed dell'EnemySpawner (trovato tramite gruppo).
## L'EnemySpawner deve avere add_to_group("enemy_spawner") nel suo _ready().
func _hook_wave_signal() -> void:
	await get_tree().process_frame
	var spawner := get_tree().get_first_node_in_group("enemy_spawner")
	if spawner and spawner.has_signal("wave_changed"):
		spawner.wave_changed.connect(_on_wave_changed)
	else:
		push_warning("Shop: EnemySpawner non trovato o segnale wave_changed mancante.")


func _on_wave_changed(_wave: int) -> void:
	_open()


# ══════════════════════════════════════════════
#  Build UI (tutto procedurale, nessun .tscn richiesto)
# ══════════════════════════════════════════════

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer        = 30   # sopra HUD (layer 20)
	_canvas.visible      = false
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	# Overlay scuro semi-trasparente
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color        = Color(0.00, 0.00, 0.06, 0.84)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(overlay)

	# Panel centrale
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(900, 460)
	panel.offset_left   = -450
	panel.offset_right  =  450
	panel.offset_top    = -245
	panel.offset_bottom =  245
	panel.add_theme_stylebox_override("panel", _mk_style(C_BG, C_ACC, 16, 2))
	_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 28
	vbox.offset_right  = -28
	vbox.offset_top    = 20
	vbox.offset_bottom = -18
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# ── Header ────────────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	_title_lbl = _lbl("🛒  VOID SHOP", 26, C_ACC, 3, Color(0, 0, 0, 0.9))
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_lbl)

	var souls_icon := _lbl("ψ", 22, C_GOLD)
	souls_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(souls_icon)

	_souls_lbl = _lbl("0", 22, C_GOLD, 2, Color(0, 0, 0, 0.8))
	_souls_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_souls_lbl)

	# Linea separatrice neon
	var sep_line := ColorRect.new()
	sep_line.color              = Color(C_ACC.r, C_ACC.g, C_ACC.b, 0.35)
	sep_line.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sep_line)

	# ── Griglia oggetti ────────────────────────────────────────────────────────
	_item_grid = HBoxContainer.new()
	_item_grid.add_theme_constant_override("separation", 16)
	_item_grid.alignment         = BoxContainer.ALIGNMENT_CENTER
	_item_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_item_grid)

	# ── Footer ────────────────────────────────────────────────────────────────
	var footer_sep := ColorRect.new()
	footer_sep.color              = Color(C_ACC.r, C_ACC.g, C_ACC.b, 0.20)
	footer_sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(footer_sep)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(footer)

	var hint := _lbl(
		"I bonus run si azzerano a fine partita  •  F2 = apri/chiudi (debug)",
		12, C_DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)

	var skip_btn := _action_btn("Continua  ▶", C_ACC)
	skip_btn.pressed.connect(_close)
	footer.add_child(skip_btn)


# ══════════════════════════════════════════════
#  Apri / Chiudi
# ══════════════════════════════════════════════

func _open() -> void:
	if _is_open:
		return
	# Non aprire se il gioco è già in game over o al menu
	if GameManager.current_state == GameManager.GameState.GAME_OVER or \
	   GameManager.current_state == GameManager.GameState.MENU:
		return
	_is_open = true
	_roll_items()
	_rebuild_grid()
	_refresh_souls()
	_update_title()
	_canvas.visible = true
	# Usa current_state invece di get_tree().paused:
	# così i bottoni UI ricevono normalmente input e click,
	# mentre player/nemici/spawner si fermano perché controllano current_state == PLAYING
	GameManager.current_state = GameManager.GameState.PAUSED


func _close() -> void:
	if not _is_open:
		return
	_is_open = false
	_canvas.visible = false
	if GameManager.current_state == GameManager.GameState.PAUSED:
		GameManager.current_state = GameManager.GameState.PLAYING
	shop_closed.emit()


## Apri manualmente — utile dal WaveSpawner o da un pulsante debug
func open() -> void:
	_open()


# ══════════════════════════════════════════════
#  Selezione oggetti
# ══════════════════════════════════════════════

## Sceglie items_per_visit oggetti con probabilità pesata per rarity.
func _roll_items() -> void:
	_current_items.clear()
	var pool: Array = ITEM_CATALOG.duplicate()
	pool.shuffle()

	while _current_items.size() < items_per_visit and pool.size() > 0:
		var total_w: int = 0
		for it in pool:
			total_w += RARITY_WEIGHTS.get(it["rarity"], 10)

		var roll: int = randi() % maxi(total_w, 1)
		var acc:  int = 0
		var picked    = null

		for it in pool:
			acc += RARITY_WEIGHTS.get(it["rarity"], 10)
			if roll < acc:
				picked = it
				break

		if picked == null:
			picked = pool[0]

		_current_items.append(picked)
		pool.erase(picked)


func _rebuild_grid() -> void:
	for c in _item_grid.get_children():
		c.queue_free()
	for item in _current_items:
		_item_grid.add_child(_build_item_card(item))


# ══════════════════════════════════════════════
#  Carta oggetto
# ══════════════════════════════════════════════

func _build_item_card(item: Dictionary) -> PanelContainer:
	var rarity: String   = item.get("rarity", "common")
	var col: Color       = RARITY_COLORS.get(rarity, C_DIM)
	var cost: int        = item["cost"]
	var affordable: bool = MetaManager.total_souls >= cost

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(188, 215)

	var sty := _mk_style(
		Color(col.r * 0.08, col.g * 0.08, col.b * 0.08, 0.97),
		col if affordable else C_DIM, 12, 2 if affordable else 1)
	sty.content_margin_left   = 14.0
	sty.content_margin_right  = 14.0
	sty.content_margin_top    = 12.0
	sty.content_margin_bottom = 12.0
	pc.add_theme_stylebox_override("panel", sty)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	pc.add_child(vbox)

	# Icona grande + badge rarity in alto a destra
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vbox.add_child(top_row)

	top_row.add_child(_lbl(item["icon"], 32, col))

	var rar_lbl := _lbl(rarity.to_upper(), 9, col)
	rar_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rar_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	rar_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_BOTTOM
	top_row.add_child(rar_lbl)

	# Nome
	var name_col := col if affordable else C_DIM
	vbox.add_child(_lbl(item["name"], 14, name_col, 1, Color(0, 0, 0, 0.7)))

	# Descrizione
	var desc := _lbl(item["desc"], 11, C_HI)
	desc.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	# Bottone acquisto
	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 14)
	btn.custom_minimum_size = Vector2(0, 36)

	var captured := item
	if affordable:
		btn.text = "  ψ %d  " % cost
		btn.add_theme_color_override("font_color", C_GOLD)
		var btn_bg  := Color(0.14, 0.11, 0.01, 0.92)
		var btn_hov := Color(0.22, 0.18, 0.02, 0.95)
		btn.add_theme_stylebox_override("normal",
			_mk_style(btn_bg,  C_GOLD, 8, 1))
		btn.add_theme_stylebox_override("hover",
			_mk_style(btn_hov, Color.WHITE, 8, 2))
		btn.add_theme_stylebox_override("pressed",
			_mk_style(btn_hov, Color.WHITE, 8, 1))
		btn.pressed.connect(func(): _buy(captured))
	else:
		btn.text    = "  ψ %d  " % cost
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 0.8)

	vbox.add_child(btn)
	return pc


# ══════════════════════════════════════════════
#  Logica acquisto
# ══════════════════════════════════════════════

func _buy(item: Dictionary) -> void:
	if MetaManager.total_souls < item["cost"]:
		return

	MetaManager.total_souls -= item["cost"]
	_apply_effect(item["fx"], item.get("val", 0.0))
	MetaManager.save_progress()

	# Rimuovi l'oggetto acquistato (eccetto reroll che ricrea la griglia)
	if item["fx"] != "reroll":
		_current_items.erase(item)
		_rebuild_grid()

	_refresh_souls()


func _apply_effect(fx: String, val: float) -> void:
	match fx:

		"heal":
			_apply_to_players(func(p): p.heal(val))

		"heal_full":
			_apply_to_players(func(p): p.heal(p.max_health))

		"health_bonus_heal":
			_add_shop_bonus("health_bonus", val)
			_recalc_all_players()
			_apply_to_players(func(p): p.heal(30.0))

		"souls_bonus":
			MetaManager.total_souls += int(val)

		"reroll":
			_roll_items()
			_rebuild_grid()

		"pierce":
			# Pierce letto da player.gd → _shoot() via GameManager.get_meta("shop_pierce")
			var cur: int = 0
			if GameManager.has_meta("shop_pierce"):
				cur = GameManager.get_meta("shop_pierce") as int
			GameManager.set_meta("shop_pierce", cur + int(val))

		_:
			# damage_pct, speed_bonus, fire_rate_bonus, crit_bonus, health_bonus
			# → salvati in GameManager.shop_bonuses, letti da player._recalculate_stats()
			_add_shop_bonus(fx, val)
			_recalc_all_players()


## Aggiunge o accumula un bonus nel dizionario "shop_bonuses" di GameManager
func _add_shop_bonus(key: String, val: float) -> void:
	var bonuses: Dictionary = {}
	if GameManager.has_meta("shop_bonuses"):
		bonuses = GameManager.get_meta("shop_bonuses") as Dictionary
	bonuses[key] = bonuses.get(key, 0.0) + val
	GameManager.set_meta("shop_bonuses", bonuses)


func _apply_to_players(fn: Callable) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p):
			fn.call(p)


func _recalc_all_players() -> void:
	_apply_to_players(func(p):
		if p.has_method("_recalculate_stats"):
			p._recalculate_stats())


# ══════════════════════════════════════════════
#  Refresh UI
# ══════════════════════════════════════════════

func _refresh_souls() -> void:
	if _souls_lbl:
		_souls_lbl.text = "%d" % MetaManager.total_souls


func _update_title() -> void:
	if not _title_lbl:
		return
	var wave: int = GameManager.current_wave
	_title_lbl.text = "🛒  VOID SHOP  —  Wave %d" % wave if wave > 0 \
		else "🛒  VOID SHOP"


# ══════════════════════════════════════════════
#  Helper UI
# ══════════════════════════════════════════════

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
	btn.custom_minimum_size = Vector2(160, 44)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color",         col)
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	var bg  := Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.92)
	var hov := Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.95)
	btn.add_theme_stylebox_override("normal",  _mk_style(bg,  col, 10, 2))
	btn.add_theme_stylebox_override("hover",   _mk_style(hov, col, 10, 3))
	btn.add_theme_stylebox_override("pressed", _mk_style(hov, Color.WHITE, 10, 2))
	return btn
