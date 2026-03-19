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
##   cdr_bonus       → riduce cooldown poteri del val% (es. 0.20 = -20%)
# ── Colori slot poteri (coerente con HUD) ─────────────────────────────────────
const C_SLOT_Q := Color(0.20, 0.88, 1.00)   # cyan  – slot Q
const C_SLOT_E := Color(1.00, 0.55, 0.12)   # arancio – slot E

# ── Catalogo poteri acquistabili ───────────────────────────────────────────────
const POWER_CATALOG: Array = [
	{
		"id": "void_dash",    "name": "Void Dash",     "icon": "💨",
		"desc": "Scatto rapidissimo nella direzione di mira.\nInvincibile per 0.25s durante il dash.",
		"cd": 6.0,  "cost": 100,
	},
	{
		"id": "shield_burst", "name": "Shield Burst",  "icon": "🛡️",
		"desc": "Scudo energetico: invincibile per 1.5s.\nFlash bianco che respinge i proiettili.",
		"cd": 8.0,  "cost": 120,
	},
	{
		"id": "plasma_bomb",  "name": "Plasma Bomb",   "icon": "💥",
		"desc": "Esplosione AOE raggio 250px a 5× danno.\nColpisce tutti i nemici nell'area.",
		"cd": 12.0, "cost": 150,
	},
	{
		"id": "time_surge",   "name": "Time Surge",    "icon": "⏳",
		"desc": "Rallenta tutti i nemici al 25% della velocità per 4 secondi.",
		"cd": 18.0, "cost": 200,
	},
]

# ── Skin navicella (acquisto permanente) ──────────────────────────────────────
const SKIN_CATALOG: Array = [
	{
		"id": "default",
		"name": "Voidrunner",
		"icon": "🛸",
		"desc": "La navicella standard.\nBilanciata e affidabile in ogni situazione.",
		"cost": 0,
		"color": Color(0.55, 0.22, 1.00),
	},
	{
		"id": "interceptor",
		"name": "Interceptor",
		"icon": "✈",
		"desc": "Caccia d'assalto aerodinamico.\nNose allungato, ali delta swept-back.",
		"cost": 250,
		"color": Color(0.30, 0.60, 1.00),
	},
	{
		"id": "titan",
		"name": "Titan",
		"icon": "🚀",
		"desc": "Incrociatore pesante corazzato.\nScafo largo, ali massive.",
		"cost": 400,
		"color": Color(0.90, 0.65, 0.20),
	},
	{
		"id": "phantom",
		"name": "Phantom",
		"icon": "👻",
		"desc": "Stealth puro. Silhouette a rombo,\nprofilo sottilissimo, quasi invisibile.",
		"cost": 600,
		"color": Color(0.50, 0.80, 0.90),
	},
]

# ── Moduli nave permanenti ─────────────────────────────────────────────────────
## Acquistati nello shop in-run, persistono tra TUTTE le run.
## Ogni modulo ha max_level livelli, ognuno con costo crescente.
const MODULE_CATALOG: Array = [
	{
		"id": "module_turret",
		"name": "Torretta Automatica", "icon": "🔫",
		"desc": "Mini-cannone rotante.\nLv1: 8 dir ogni 3s\nLv2: 8 dir ogni 2s\nLv3: 16 dir ogni 1.5s",
		"max_level": 3, "costs": [150, 300, 500],
		"color": Color(1.00, 0.52, 0.20),   # arancio-fuoco
	},
	{
		"id": "module_missile",
		"name": "Lanciamissili", "icon": "🚀",
		"desc": "Spara un missile guidato al nemico più vicino.\nLv1: 1 missile ogni 8s\nLv2: 2 missili ogni 5s",
		"max_level": 2, "costs": [200, 420],
		"color": Color(1.00, 0.20, 0.30),   # rosso
	},
	{
		"id": "module_shield_orb",
		"name": "Orb Scudo", "icon": "🔵",
		"desc": "Sfere energetiche orbitanti che bruciano i nemici al contatto.\nLv1: 2 orb\nLv2: 3 orb ×1.5 dmg\nLv3: 4 orb ×2 dmg",
		"max_level": 3, "costs": [180, 360, 600],
		"color": Color(0.20, 0.70, 1.00),   # blu
	},
	{
		"id": "module_drone",
		"name": "Drone Compagno", "icon": "🤖",
		"desc": "Droni autonomi che orbitano e sparano ai nemici vicini.\nLv1: 1 drone, 1.5s/colpo\nLv2: 2 droni, 0.8s/colpo",
		"max_level": 2, "costs": [250, 520],
		"color": Color(1.00, 0.82, 0.10),   # oro
	},
]

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
		"id": "cdr_up",     "name": "Nucleo Temporale",      "icon": "⏱",
		"desc": "Riduce il cooldown di tutti i poteri del 20%.\nCumulabile (max 75%).",
		"cost": 130, "rarity": "rare", "fx": "cdr_bonus", "val": 0.20,
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
var _item_grid:     HBoxContainer   # griglia oggetti (tab 0)
var _content_area:  Control         # contenitore generico sostituito ad ogni cambio tab
var _title_lbl:     Label
var _current_items:  Array = []
var _is_open:        bool  = false
var _items_rolled:   bool  = false   # true dopo _roll_items() della wave corrente
# Tab: 0=Potenziamenti  1=Potere Q  2=Potere E
var _current_tab:   int   = 0
var _tab_btns:      Array = []


# ══════════════════════════════════════════════
#  Avvio
# ══════════════════════════════════════════════

func _ready() -> void:
	add_to_group("shop")
	# PROCESS_MODE_ALWAYS: continua a funzionare anche quando get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(true)
	set_process_unhandled_input(true)   # necessario per ricevere eventi joypad
	_build_ui()
	_hook_wave_signal()


## Tastiera: F2 apri/chiudi shop (debug), F3 regala souls (debug)
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	if debug_key_open and (event as InputEventKey).keycode == KEY_F2:
		# F2 — apri/chiudi shop
		get_viewport().set_input_as_handled()
		if _is_open:
			_close()
		else:
			_open()
	elif debug_key_open and (event as InputEventKey).keycode == KEY_F3:
		# F3 — DEBUG: regala 9999 souls
		get_viewport().set_input_as_handled()
		MetaManager.total_souls += 9999
		MetaManager.save_progress()
		_refresh_souls()
		if _is_open:
			_rebuild_grid()   # aggiorna bottoni acquistabili


## Controller: Select/Back = apri shop  |  B/Cerchio = chiudi shop
## A/X = conferma/compra (fallback esplicito se ui_accept non raggiunge il Button in focus)
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton):
		return
	var jb := event as InputEventJoypadButton
	if not jb.pressed:
		return

	match jb.button_index:
		JOY_BUTTON_BACK:
			# Select / Share / Back — apri shop se chiuso, chiudi se aperto
			get_viewport().set_input_as_handled()
			if _is_open:
				_close()
			else:
				_open()
		JOY_BUTTON_B:
			# B (Xbox) / Cerchio (PS) — chiudi shop
			if _is_open:
				get_viewport().set_input_as_handled()
				_close()
		JOY_BUTTON_A:
			# A (Xbox) / Croce (PS) — conferma / acquista il bottone in focus
			# Fallback necessario: i Button in CanvasLayer non sempre ricevono ui_accept
			# dal joypad in Godot 4, quindi gestiamo noi stessi il click.
			if _is_open:
				get_viewport().set_input_as_handled()
				var focused := get_viewport().gui_get_focus_owner()
				# is_instance_valid: evita crash se il bottone è in queue_free (rebuild griglia)
				if focused is Button and is_instance_valid(focused) \
						and not (focused as Button).disabled:
					(focused as Button).pressed.emit()
				else:
					# Fallback: se il focus è invalido/null, cerca il primo bottone abilitato
					# (succede raramente quando il rebuild della griglia è ancora in corso)
					var btn := _find_first_enabled_button(_content_area)
					if btn:
						btn.grab_focus()
						btn.pressed.emit()
		JOY_BUTTON_LEFT_SHOULDER:
			# L1 / LB — tab precedente (solo quando lo shop è aperto)
			# I poteri Q/E in player.gd sono bloccati quando state != PLAYING
			if _is_open:
				get_viewport().set_input_as_handled()
				_switch_tab(posmod(_current_tab - 1, _tab_btns.size()))
		JOY_BUTTON_RIGHT_SHOULDER:
			# R1 / RB — tab successiva
			if _is_open:
				get_viewport().set_input_as_handled()
				_switch_tab((_current_tab + 1) % _tab_btns.size())


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
	# Nuova wave: resetta il flag così _open() sa che può rullare
	_items_rolled = false
	_roll_items()
	_items_rolled = true   # blocca ulteriori re-roll fino alla prossima wave
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
	panel.custom_minimum_size = Vector2(1040, 560)
	panel.offset_left   = -520
	panel.offset_right  =  520
	panel.offset_top    = -280
	panel.offset_bottom =  280
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

	_title_lbl = _lbl("🛒  VOID SHOP", 30, C_ACC, 3, Color(0, 0, 0, 0.9))
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_lbl)

	var souls_icon := _lbl("ψ", 26, C_GOLD)
	souls_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(souls_icon)

	_souls_lbl = _lbl("0", 26, C_GOLD, 2, Color(0, 0, 0, 0.8))
	_souls_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_souls_lbl)

	# Linea separatrice neon
	var sep_line := ColorRect.new()
	sep_line.color              = Color(C_ACC.r, C_ACC.g, C_ACC.b, 0.35)
	sep_line.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sep_line)

	# ── Tab bar con hint spalle controller ──────────────────────────────────────
	# Riga esterna: hint L1/LB | tab_bar | hint R1/RB
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tab_row)

	# Hint lato sinistro (tab precedente)
	var lhint := _lbl("◄ L1 / LB", 13, Color(0.55, 0.55, 0.70))
	lhint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab_row.add_child(lhint)

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 6)
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_child(tab_bar)

	# Hint lato destro (tab successiva)
	var rhint := _lbl("R1 / RB ►", 13, Color(0.55, 0.55, 0.70))
	rhint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab_row.add_child(rhint)

	var tab_defs: Array = [
		["⚡  BOOST",        C_ACC],
		["◈  POTERE  Q",    C_SLOT_Q],
		["◈  POTERE  E",    C_SLOT_E],
		["🚀  MODULI",      Color(1.00, 0.82, 0.10)],
		["🎨  SKIN",        Color(0.90, 0.55, 1.00)],
	]
	for ti: int in tab_defs.size():
		var td: Array = tab_defs[ti]
		var tb := _action_btn(td[0] as String, td[1] as Color)
		tb.custom_minimum_size = Vector2(155, 40)
		tb.add_theme_font_size_override("font_size", 13)
		# FOCUS_NONE: i tab non sono raggiungibili col D-pad.
		# Si cambiano SOLO con L1/R1 (JOY_BUTTON_LEFT/RIGHT_SHOULDER).
		tb.focus_mode = Control.FOCUS_NONE
		var idx := ti   # capture
		tb.pressed.connect(func(): _switch_tab(idx))
		tab_bar.add_child(tb)
		_tab_btns.append(tb)

	_refresh_tab_buttons()

	# Linea sotto tab
	var tab_line := ColorRect.new()
	tab_line.color              = Color(C_ACC.r, C_ACC.g, C_ACC.b, 0.20)
	tab_line.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(tab_line)

	# ── Area contenuto (ricostruita ad ogni cambio tab) ────────────────────────
	_content_area = Control.new()
	_content_area.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_content_area)

	# Compatibilità: _item_grid punta al primo figlio dell'area
	_item_grid = HBoxContainer.new()
	_item_grid.add_theme_constant_override("separation", 16)
	_item_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_item_grid.alignment          = BoxContainer.ALIGNMENT_CENTER
	_item_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.add_child(_item_grid)

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
	skip_btn.focus_mode = Control.FOCUS_ALL
	skip_btn.name = "SkipBtn"
	footer.add_child(skip_btn)

	var ctrl_hint := _lbl("🎮  [Select] Apri  [A/X] Compra  [B/○] Chiudi  [D-pad/LS] Naviga", 13, C_DIM)
	ctrl_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl_hint.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(ctrl_hint)


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
	# NON ri-rollare se già eseguito in questa wave (_items_rolled == true).
	# Fallback solo per debug (F2 prima di qualsiasi wave) o prima apertura.
	if not _items_rolled:
		_roll_items()
		_items_rolled = true
	_rebuild_grid()
	_refresh_souls()
	_update_title()
	_canvas.visible = true
	GameManager.current_state = GameManager.GameState.PAUSED
	# Controller: dai focus al primo bottone acquistabile (o SkipBtn)
	_grab_first_focus()


func _close() -> void:
	if not _is_open:
		return
	_is_open = false
	_canvas.visible = false
	# FIX: rilascia il focus GUI così nessun button invisible intercetta gli input
	get_viewport().gui_release_focus()
	if GameManager.current_state == GameManager.GameState.PAUSED:
		GameManager.current_state = GameManager.GameState.PLAYING
	shop_closed.emit()


## Apri manualmente — utile dal WaveSpawner o da un pulsante debug
func open() -> void:
	_open()


# ══════════════════════════════════════════════
#  Tab management
# ══════════════════════════════════════════════

func _switch_tab(idx: int) -> void:
	_current_tab = idx
	_refresh_tab_buttons()
	_rebuild_grid()
	_grab_first_focus()


func _refresh_tab_buttons() -> void:
	## Evidenzia il bottone della tab attiva, opacizza gli altri.
	for i: int in _tab_btns.size():
		var tb: Button = _tab_btns[i] as Button
		tb.modulate = Color.WHITE if i == _current_tab else Color(1, 1, 1, 0.45)


func _grab_first_focus() -> void:
	## Dà il focus al primo bottone ABILITATO per navigazione controller.
	## Usato ogni volta che lo shop apre, cambia tab o completa un acquisto.
	await get_tree().process_frame
	# FIX: se lo shop è già stato chiuso durante l'await, non dare focus
	if not _is_open:
		return
	# Raccoglie tutti i button abilitati e collega la catena focus esplicita.
	# Necessario perché Godot 4 non riesce a navigare automaticamente tra bottoni
	# annidati in PanelContainer→VBoxContainer con D-pad/freccette.
	var btns := _collect_focusable_buttons(_content_area)
	_setup_focus_chain(btns)
	if btns.size() > 0:
		btns[0].grab_focus()
		return
	# Fallback: pulsante "Continua ▶"
	var skip := _canvas.find_child("SkipBtn", true, false)
	if skip is Button:
		(skip as Button).grab_focus()


## Raccoglie depth-first TUTTI i Button abilitati e focalizzabili nell'albero.
func _collect_focusable_buttons(node: Node) -> Array:
	var result: Array = []
	if node is Button:
		var b := node as Button
		if not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			result.append(b)
		return result   # non scendere nei figli di un Button
	for child in node.get_children():
		result.append_array(_collect_focusable_buttons(child))
	return result


## Collega esplicitamente focus_neighbor_left/right tra i bottoni della lista.
## Avvolge circolarmente: l'ultimo→primo e primo→ultimo.
## Su/giù: rimane sul bottone stesso (impedisce uscita dalla riga).
func _setup_focus_chain(btns: Array) -> void:
	var n := btns.size()
	if n == 0:
		return
	for i in n:
		var b := btns[i] as Button
		b.focus_neighbor_left   = btns[posmod(i - 1, n)].get_path()
		b.focus_neighbor_right  = btns[(i + 1) % n].get_path()
		b.focus_neighbor_top    = b.get_path()   # rimani sulla riga (non uscire su)
		b.focus_neighbor_bottom = b.get_path()   # rimani sulla riga (non uscire giù)


## Ricerca depth-first del primo Button abilitato e focalizzabile.
## Salta i bottoni disabled o con focus_mode = FOCUS_NONE.
func _find_first_enabled_button(node: Node) -> Button:
	if node is Button:
		var b := node as Button
		if not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			return b
		return null   # non scendere nei figli di un bottone
	for child in node.get_children():
		var found := _find_first_enabled_button(child)
		if found:
			return found
	return null


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
	# Svuota l'area contenuto
	for c: Node in _content_area.get_children():
		c.queue_free()

	match _current_tab:
		0:  # Potenziamenti
			_item_grid = HBoxContainer.new()
			_item_grid.add_theme_constant_override("separation", 16)
			_item_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
			_item_grid.alignment          = BoxContainer.ALIGNMENT_CENTER
			_item_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_content_area.add_child(_item_grid)
			for item: Dictionary in _current_items:
				_item_grid.add_child(_build_item_card(item))
		1:
			_rebuild_powers_tab("q")
		2:
			_rebuild_powers_tab("e")
		3:
			_rebuild_modules_tab()
		4:
			_rebuild_skins_tab()


# ══════════════════════════════════════════════
#  Tab Poteri Q / E
# ══════════════════════════════════════════════

func _rebuild_powers_tab(slot_key: String) -> void:
	var slot_col: Color = C_SLOT_Q if slot_key == "q" else C_SLOT_E
	var meta_key: String = "active_power_" + slot_key

	# Potere attualmente equipaggiato in questo slot
	var equipped_id: String = ""
	if GameManager.has_meta(meta_key):
		equipped_id = GameManager.get_meta(meta_key) as String

	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 16)
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.alignment          = BoxContainer.ALIGNMENT_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.add_child(grid)

	for power: Dictionary in POWER_CATALOG:
		grid.add_child(_build_power_card(power, slot_key, slot_col, equipped_id))


func _build_power_card(
		power: Dictionary,
		slot_key: String,
		slot_col: Color,
		equipped_id: String) -> PanelContainer:

	var pid:         String = power["id"]
	var cost:        int    = power["cost"] as int
	var is_equipped: bool   = (pid == equipped_id)
	var is_unlocked: bool   = MetaManager.is_power_unlocked(pid)
	var can_afford:  bool   = MetaManager.total_souls >= cost
	# La card è "active" se è equipaggiata, sbloccata, o comprabile
	var active:      bool   = is_equipped or is_unlocked or can_afford

	var border_col := Color.WHITE if is_equipped else slot_col
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(212, 262)
	var sty := _mk_style(
		Color(slot_col.r * 0.07, slot_col.g * 0.07, slot_col.b * 0.07, 0.97),
		border_col if active else C_DIM,
		12, 2 if active else 1)
	sty.content_margin_left   = 14.0
	sty.content_margin_right  = 14.0
	sty.content_margin_top    = 12.0
	sty.content_margin_bottom = 12.0
	pc.add_theme_stylebox_override("panel", sty)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	pc.add_child(vbox)

	# Icona + badge SLOT
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vbox.add_child(top_row)
	top_row.add_child(_lbl(power["icon"] as String, 36, slot_col))
	var badge_extra := ("  ✓" if is_equipped else ("  🔓" if is_unlocked else ""))
	var badge_txt   := ("SLOT " + slot_key.to_upper()) + badge_extra
	var badge := _lbl(badge_txt, 12, Color.WHITE if is_equipped else slot_col)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment    = VERTICAL_ALIGNMENT_BOTTOM
	top_row.add_child(badge)

	# Nome
	vbox.add_child(_lbl(power["name"] as String, 17,
		Color.WHITE if is_equipped else slot_col, 1, Color(0, 0, 0, 0.7)))

	# Cooldown
	vbox.add_child(_lbl("⏱  CD: %.0fs" % (power["cd"] as float), 13, C_DIM))

	# Descrizione
	var desc := _lbl(power["desc"] as String, 13, C_HI)
	desc.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	# Hint sblocco permanente
	if not is_unlocked:
		var hint := _lbl("🔒 Sblocco permanente", 11, C_DIM)
		vbox.add_child(hint)

	# Bottone
	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(0, 40)
	btn.focus_mode          = Control.FOCUS_ALL

	if is_equipped:
		btn.text     = "✓  EQUIPAGGIATO"
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_stylebox_override("normal",
			_mk_style(Color(0.10, 0.40, 0.10, 0.85), Color.WHITE, 8, 2))
		btn.disabled = true
	elif is_unlocked:
		# Sbloccato ma non equipaggiato: equipaggia gratis
		btn.text = "EQUIPAGGIA  →"
		btn.add_theme_color_override("font_color", slot_col)
		btn.add_theme_stylebox_override("normal",
			_mk_style(Color(slot_col.r*0.14, slot_col.g*0.14, slot_col.b*0.14, 0.92),
				slot_col, 8, 1))
		btn.add_theme_stylebox_override("hover",
			_mk_style(Color(slot_col.r*0.22, slot_col.g*0.22, slot_col.b*0.22, 0.95),
				Color.WHITE, 8, 2))
		_apply_focus_style(btn, slot_col, 8)
		var cap_id  := pid
		var cap_key := slot_key
		btn.pressed.connect(func(): _buy_power(cap_id, cap_key, 0))
	elif can_afford:
		btn.text = "SBLOCCA  ψ %d" % cost
		btn.add_theme_color_override("font_color", C_GOLD)
		btn.add_theme_stylebox_override("normal",
			_mk_style(Color(0.14, 0.11, 0.01, 0.92), C_GOLD, 8, 1))
		btn.add_theme_stylebox_override("hover",
			_mk_style(Color(0.22, 0.18, 0.02, 0.95), Color.WHITE, 8, 2))
		_apply_focus_style(btn, C_GOLD, 8)
		var cap_id2  := pid
		var cap_key2 := slot_key
		var cap_cost := cost
		btn.pressed.connect(func(): _buy_power(cap_id2, cap_key2, cap_cost))
	else:
		btn.text     = "ψ %d" % cost
		btn.disabled  = true
		btn.modulate  = Color(0.5, 0.5, 0.5, 0.8)

	vbox.add_child(btn)
	return pc


func _buy_power(power_id: String, slot_key: String, cost: int) -> void:
	# Se cost > 0 → prima volta, sblocca permanentemente
	if cost > 0:
		if not MetaManager.unlock_power(power_id, cost):
			return   # souls insufficienti
	# Equipaggia nello slot (sempre gratis dopo sblocco)
	var meta_key: String = "active_power_" + slot_key
	GameManager.set_meta(meta_key, power_id)
	# Forza il ricalcolo delle stats di tutti i giocatori
	_recalc_all_players()
	_refresh_souls()
	_rebuild_grid()
	_grab_first_focus()


# ══════════════════════════════════════════════
#  Tab Moduli Nave (upgrade permanenti)
# ══════════════════════════════════════════════

func _rebuild_modules_tab() -> void:
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 14)
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.alignment          = BoxContainer.ALIGNMENT_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.add_child(grid)

	for mod: Dictionary in MODULE_CATALOG:
		grid.add_child(_build_module_card(mod))


func _build_module_card(mod: Dictionary) -> PanelContainer:
	var mod_id:    String = mod["id"]
	var mod_col:   Color  = mod["color"] as Color
	var max_lv:    int    = mod["max_level"] as int
	var costs:     Array  = mod["costs"] as Array
	var cur_level: int    = MetaManager.get_perm_level(mod_id)
	var maxed:     bool   = cur_level >= max_lv
	var cost:      int    = 0 if maxed else costs[cur_level] as int
	var affordable: bool  = maxed or MetaManager.total_souls >= cost

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(218, 272)
	var sty := _mk_style(
		Color(mod_col.r * 0.07, mod_col.g * 0.06, mod_col.b * 0.04, 0.97),
		mod_col if affordable else C_DIM, 12, 2 if affordable else 1)
	sty.content_margin_left   = 14.0
	sty.content_margin_right  = 14.0
	sty.content_margin_top    = 12.0
	sty.content_margin_bottom = 12.0
	pc.add_theme_stylebox_override("panel", sty)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pc.add_child(vbox)

	# Header: icona + badge livello
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vbox.add_child(top)
	top.add_child(_lbl(mod["icon"] as String, 34, mod_col))

	var lv_box := VBoxContainer.new()
	lv_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(lv_box)

	# Barra livelli (puntini)
	var dots_row := HBoxContainer.new()
	dots_row.add_theme_constant_override("separation", 4)
	dots_row.alignment = BoxContainer.ALIGNMENT_END
	lv_box.add_child(dots_row)
	for i in max_lv:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = mod_col if i < cur_level else Color(mod_col.r * 0.2, mod_col.g * 0.2, mod_col.b * 0.2, 0.6)
		dots_row.add_child(dot)

	# Label stato
	var state_txt := "MAX" if maxed else ("Lv %d / %d" % [cur_level, max_lv])
	var state_col := Color(0.20, 1.00, 0.40) if maxed else (mod_col if cur_level > 0 else C_DIM)
	var state_lbl := _lbl(state_txt, 12, state_col)
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lv_box.add_child(state_lbl)

	# Nome
	vbox.add_child(_lbl(mod["name"] as String, 16, mod_col, 1, Color(0, 0, 0, 0.7)))

	# Descrizione
	var desc_lbl := _lbl(mod["desc"] as String, 13, C_HI)
	desc_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	# Badge PERMANENTE
	var perm_lbl := _lbl("⭐ PERMANENTE", 12, Color(mod_col.r, mod_col.g, mod_col.b, 0.70))
	vbox.add_child(perm_lbl)

	# Bottone acquisto/upgrade
	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(0, 40)
	btn.focus_mode          = Control.FOCUS_ALL

	if maxed:
		btn.text = "✓  AL MASSIMO"
		btn.add_theme_color_override("font_color", Color(0.20, 1.00, 0.40))
		btn.add_theme_stylebox_override("normal",
			_mk_style(Color(0.04, 0.18, 0.04, 0.85), Color(0.20, 1.00, 0.40), 8, 1))
		btn.disabled = true
	elif affordable:
		var lbl_txt := ("ψ %d  SBLOCCA" % cost) if cur_level == 0 else ("ψ %d  UPGRADE" % cost)
		btn.text = lbl_txt
		btn.add_theme_color_override("font_color", C_GOLD)
		btn.add_theme_stylebox_override("normal",
			_mk_style(Color(0.14, 0.11, 0.01, 0.92), C_GOLD, 8, 1))
		btn.add_theme_stylebox_override("hover",
			_mk_style(Color(0.22, 0.18, 0.02, 0.95), Color.WHITE, 8, 2))
		_apply_focus_style(btn, mod_col, 8)
		var cap_id   := mod_id
		var cap_cost := cost
		btn.pressed.connect(func(): _buy_module(cap_id, cap_cost))
	else:
		btn.text     = "ψ %d" % cost
		btn.disabled  = true
		btn.modulate  = Color(0.5, 0.5, 0.5, 0.8)

	vbox.add_child(btn)
	return pc


func _buy_module(mod_id: String, cost: int) -> void:
	if not MetaManager.buy_perm_upgrade(mod_id, cost):
		return
	MetaManager.save_progress()
	_refresh_souls()
	# Notifica i player di ricaricare i moduli
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.has_method("apply_modules"):
			p.apply_modules()
	_rebuild_grid()
	_grab_first_focus()


# ══════════════════════════════════════════════
#  Tab Skin Navicella (acquisto + selezione permanente)
# ══════════════════════════════════════════════

func _rebuild_skins_tab() -> void:
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 14)
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.alignment          = BoxContainer.ALIGNMENT_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.add_child(grid)

	for skin: Dictionary in SKIN_CATALOG:
		grid.add_child(_build_skin_card(skin))


func _build_skin_card(skin: Dictionary) -> PanelContainer:
	var skin_id:     String = skin["id"]
	var skin_col:    Color  = skin["color"] as Color
	var cost:        int    = skin["cost"] as int
	var is_selected: bool   = (MetaManager.selected_skin == skin_id)
	var is_unlocked: bool   = MetaManager.is_skin_unlocked(skin_id)
	var can_afford:  bool   = is_unlocked or MetaManager.total_souls >= cost
	var active:      bool   = is_selected or is_unlocked or can_afford

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(218, 272)
	var sty := _mk_style(
		Color(skin_col.r * 0.07, skin_col.g * 0.06, skin_col.b * 0.04, 0.97),
		skin_col if active else C_DIM, 12, 3 if is_selected else (2 if active else 1))
	sty.content_margin_left   = 14.0
	sty.content_margin_right  = 14.0
	sty.content_margin_top    = 12.0
	sty.content_margin_bottom = 12.0
	pc.add_theme_stylebox_override("panel", sty)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pc.add_child(vbox)

	# Header: icona + badge stato
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vbox.add_child(top)
	top.add_child(_lbl(skin["icon"] as String, 36, skin_col))

	var badge_txt: String
	if is_selected:
		badge_txt = "✓ ATTIVA"
	elif is_unlocked:
		badge_txt = "🔓 SBLOCCATA"
	else:
		badge_txt = "🔒 ψ %d" % cost
	var badge_col := Color.WHITE if is_selected else (C_GREEN if is_unlocked else C_GOLD)
	var badge_lbl := _lbl(badge_txt, 12, badge_col)
	badge_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	badge_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_BOTTOM
	top.add_child(badge_lbl)

	# Nome
	vbox.add_child(_lbl(skin["name"] as String, 17, skin_col, 1, Color(0, 0, 0, 0.7)))

	# Descrizione
	var desc_lbl := _lbl(skin["desc"] as String, 13, C_HI)
	desc_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	# Badge PERMANENTE
	var perm_lbl := _lbl("⭐ PERMANENTE", 12, Color(skin_col.r, skin_col.g, skin_col.b, 0.65))
	vbox.add_child(perm_lbl)

	# Bottone
	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(0, 40)
	btn.focus_mode          = Control.FOCUS_ALL

	if is_selected:
		btn.text = "✓  IN USO"
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_stylebox_override("normal",
			_mk_style(Color(0.10, 0.40, 0.10, 0.85), Color.WHITE, 8, 2))
		btn.disabled = true
	elif is_unlocked:
		# Sbloccata, seleziona gratis
		btn.text = "SELEZIONA  →"
		btn.add_theme_color_override("font_color", skin_col)
		btn.add_theme_stylebox_override("normal",
			_mk_style(Color(skin_col.r*0.14, skin_col.g*0.14, skin_col.b*0.14, 0.92),
				skin_col, 8, 1))
		btn.add_theme_stylebox_override("hover",
			_mk_style(Color(skin_col.r*0.22, skin_col.g*0.22, skin_col.b*0.22, 0.95),
				Color.WHITE, 8, 2))
		_apply_focus_style(btn, skin_col, 8)
		var cap_id   := skin_id
		var cap_cost := 0
		btn.pressed.connect(func(): _buy_equip_skin(cap_id, cap_cost))
	elif can_afford:
		btn.text = "ACQUISTA  ψ %d" % cost
		btn.add_theme_color_override("font_color", C_GOLD)
		btn.add_theme_stylebox_override("normal",
			_mk_style(Color(0.14, 0.11, 0.01, 0.92), C_GOLD, 8, 1))
		btn.add_theme_stylebox_override("hover",
			_mk_style(Color(0.22, 0.18, 0.02, 0.95), Color.WHITE, 8, 2))
		_apply_focus_style(btn, C_GOLD, 8)
		var cap_id2   := skin_id
		var cap_cost2 := cost
		btn.pressed.connect(func(): _buy_equip_skin(cap_id2, cap_cost2))
	else:
		btn.text     = "ψ %d" % cost
		btn.disabled  = true
		btn.modulate  = Color(0.5, 0.5, 0.5, 0.8)

	vbox.add_child(btn)
	return pc


func _buy_equip_skin(skin_id: String, cost: int) -> void:
	if not MetaManager.unlock_and_select_skin(skin_id, cost):
		return   # souls insufficienti
	_refresh_souls()
	_rebuild_grid()
	_grab_first_focus()


# ══════════════════════════════════════════════
#  Carta oggetto
# ══════════════════════════════════════════════

func _build_item_card(item: Dictionary) -> PanelContainer:
	var rarity: String   = item.get("rarity", "common")
	var col: Color       = RARITY_COLORS.get(rarity, C_DIM)
	var cost: int        = item["cost"]
	var affordable: bool = MetaManager.total_souls >= cost

	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(204, 250)

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

	top_row.add_child(_lbl(item["icon"], 36, col))

	var rar_lbl := _lbl(rarity.to_upper(), 12, col)
	rar_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rar_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	rar_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_BOTTOM
	top_row.add_child(rar_lbl)

	# Nome
	var name_col := col if affordable else C_DIM
	vbox.add_child(_lbl(item["name"], 16, name_col, 1, Color(0, 0, 0, 0.7)))

	# Descrizione
	var desc := _lbl(item["desc"], 13, C_HI)
	desc.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	# Bottone acquisto
	var btn := Button.new()
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(0, 40)

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
		btn.focus_mode = Control.FOCUS_ALL
		_apply_focus_style(btn, C_GOLD, 8)
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
	# Dopo l'acquisto i bottoni vengono ricreati → ri-dai il focus al primo disponibile
	_grab_first_focus()


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

## Applica uno stile focus ben visibile al bottone: bordo bianco spesso + bg leggermente acceso.
## Chiamato su OGNI bottone interattivo perché Godot 4 con stili custom non mostra il focus di default.
func _apply_focus_style(btn: Button, accent: Color, radius: int = 8) -> void:
	var focus_bg := Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.98)
	var s := _mk_style(focus_bg, Color.WHITE, radius, 3)
	# Shadow neon colorata per risaltare su sfondo scuro
	s.shadow_color = Color(accent.r, accent.g, accent.b, 0.55)
	s.shadow_size  = 6
	btn.add_theme_stylebox_override("focus", s)


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
	_apply_focus_style(btn, col, 10)
	return btn
