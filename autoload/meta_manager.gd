extends Node
## MetaManager - Meta-progressione persistente tra run
## Autoload: aggiungilo in Project > Autoload con nome "MetaManager"
## Gestisce: personaggi, livelli, XP (Souls), talenti, salvataggio JSON

signal xp_gained(amount: int, total_for_char: int)
signal level_up(character_id: String, new_level: int)
signal character_unlocked(character_id: String)
signal talent_unlocked(talent_id: String)
signal save_completed

const SAVE_PATH := "user://meta_progress.json"

# ---------------------------------------------------------------------------
# DEFINIZIONE PERSONAGGI
# ---------------------------------------------------------------------------
const CHARACTERS: Dictionary = {
	"void_sentinel": {
		"name": "Void Sentinel",
		"description": "Tank corazzato. Sopravvivenza e melee focus.",
		"unlock_by_default": true,
		"unlock_condition": "",
		"base_stats": {
			"max_health":    150.0,
			"move_speed":    250.0,
			"damage_mult":   0.8,
			"fire_rate_mult": 1.2,
			"crit_chance":   0.05,
		},
		"color": Color(0.0, 1.0, 1.0),   # Cyan
		"talent_ids": [
			"sentinel_iron_skin",
			"sentinel_void_shield",
			"sentinel_melee_surge"
		]
	},
	"plasma_caster": {
		"name": "Plasma Caster",
		"description": "Mago del danno. Proiettili enormi, devastanti.",
		"unlock_by_default": false,
		"unlock_condition": "reach_wave_10",
		"base_stats": {
			"max_health":    80.0,
			"move_speed":    270.0,
			"damage_mult":   1.5,
			"fire_rate_mult": 0.85,
			"crit_chance":   0.10,
		},
		"color": Color(1.0, 0.2, 1.0),   # Magenta
		"talent_ids": [
			"caster_overcharge",
			"caster_plasma_nova",
			"caster_arcane_focus"
		]
	},
	"echo_knight": {
		"name": "Echo Knight",
		"description": "Assassino veloce. Crit, mobilità, equilibrio.",
		"unlock_by_default": false,
		"unlock_condition": "earn_1000_souls",
		"base_stats": {
			"max_health":    100.0,
			"move_speed":    380.0,
			"damage_mult":   1.1,
			"fire_rate_mult": 0.9,
			"crit_chance":   0.20,
		},
		"color": Color(0.2, 1.0, 0.2),   # Verde
		"talent_ids": [
			"knight_echo_strike",
			"knight_phantom_dash",
			"knight_crit_storm"
		]
	},
	"void_lord": {
		"name": "Void Lord",
		"description": "Hard mode. Scala lentamente ma domina tutto.",
		"unlock_by_default": false,
		"unlock_condition": "complete_run_all_chars",
		"base_stats": {
			"max_health":    120.0,
			"move_speed":    300.0,
			"damage_mult":   1.0,
			"fire_rate_mult": 1.0,
			"crit_chance":   0.08,
		},
		"color": Color(0.8, 0.2, 1.0),   # Viola
		"talent_ids": [
			"lord_void_mastery",
			"lord_singularity",
			"lord_entropy"
		]
	}
}

# ---------------------------------------------------------------------------
# DEFINIZIONE TALENTI (3 per personaggio, 12 totali)
# ---------------------------------------------------------------------------
const TALENTS: Dictionary = {
	# ── Void Sentinel ────────────────────────────────────────────────────
	"sentinel_iron_skin": {
		"name": "Iron Skin",
		"description": "+30 HP massimi permanenti",
		"character": "void_sentinel",
		"cost": 50,
		"requires": "",
		"effect": { "max_health_bonus": 30.0 }
	},
	"sentinel_void_shield": {
		"name": "Void Shield",
		"description": "-15% danno ricevuto",
		"character": "void_sentinel",
		"cost": 80,
		"requires": "sentinel_iron_skin",
		"effect": { "damage_reduction": 0.15 }
	},
	"sentinel_melee_surge": {
		"name": "Melee Surge",
		"description": "+40% danno quando un nemico è a <100px",
		"character": "void_sentinel",
		"cost": 120,
		"requires": "sentinel_void_shield",
		"effect": { "melee_damage_bonus": 0.40 }
	},

	# ── Plasma Caster ────────────────────────────────────────────────────
	"caster_overcharge": {
		"name": "Overcharge",
		"description": "+25% danno base permanente",
		"character": "plasma_caster",
		"cost": 60,
		"requires": "",
		"effect": { "damage_mult_bonus": 0.25 }
	},
	"caster_plasma_nova": {
		"name": "Plasma Nova",
		"description": "Ogni 10 kill: esplosione AOE automatica attorno al giocatore",
		"character": "plasma_caster",
		"cost": 100,
		"requires": "caster_overcharge",
		"effect": { "plasma_nova_enabled": true }
	},
	"caster_arcane_focus": {
		"name": "Arcane Focus",
		"description": "+50% dimensione proiettili",
		"character": "plasma_caster",
		"cost": 130,
		"requires": "caster_plasma_nova",
		"effect": { "projectile_scale_bonus": 0.50 }
	},

	# ── Echo Knight ──────────────────────────────────────────────────────
	"knight_echo_strike": {
		"name": "Echo Strike",
		"description": "+15% crit chance permanente",
		"character": "echo_knight",
		"cost": 55,
		"requires": "",
		"effect": { "crit_chance_bonus": 0.15 }
	},
	"knight_phantom_dash": {
		"name": "Phantom Dash",
		"description": "+80 velocità di movimento permanente",
		"character": "echo_knight",
		"cost": 75,
		"requires": "knight_echo_strike",
		"effect": { "move_speed_bonus": 80.0 }
	},
	"knight_crit_storm": {
		"name": "Crit Storm",
		"description": "Crit consecutivi aumentano danno del 10% (max 5 stack, si azzera a morte)",
		"character": "echo_knight",
		"cost": 130,
		"requires": "knight_phantom_dash",
		"effect": { "crit_storm_enabled": true }
	},

	# ── Void Lord ────────────────────────────────────────────────────────
	"lord_void_mastery": {
		"name": "Void Mastery",
		"description": "+5% a tutti gli stats permanente",
		"character": "void_lord",
		"cost": 80,
		"requires": "",
		"effect": { "all_stats_bonus": 0.05 }
	},
	"lord_singularity": {
		"name": "Singularity",
		"description": "Ogni 60 sec: spawn black hole che attira e danneggia nemici",
		"character": "void_lord",
		"cost": 160,
		"requires": "lord_void_mastery",
		"effect": { "singularity_enabled": true }
	},
	"lord_entropy": {
		"name": "Entropy",
		"description": "Ogni kill aumenta danno di tutti i player del +1% per tutta la run (max 50%)",
		"character": "void_lord",
		"cost": 220,
		"requires": "lord_singularity",
		"effect": { "entropy_enabled": true }
	}
}

# Scala logaritmica XP per level-up
const BASE_XP_PER_LEVEL := 100
const XP_SCALE := 1.3

# ---------------------------------------------------------------------------
# STATO PERSISTENTE
# ---------------------------------------------------------------------------
var total_souls: int = 0               ## Souls spendibili (valuta talenti)
var total_souls_ever: int = 0          ## Souls guadagnati lifetime (per unlock)
var best_wave: int = 0                 ## Wave massima raggiunta in qualsiasi run
var best_wave_hardcore: int = 0        ## Wave massima in modalità Hardcore

var character_levels: Dictionary = {}  ## char_id → livello (int)
var character_xp: Dictionary = {}      ## char_id → xp corrente (int)

var unlocked_characters: Array = []    ## Lista char_id sbloccati
var unlocked_talents: Array = []       ## Lista talent_id acquistati

var selected_character: String = "void_sentinel"
var runs_per_character: Dictionary = {}  ## char_id → n° run completate

## Upgrade permanenti acquistati nello shop post-run
## Struttura: { "perm_hp": 3, "perm_dmg": 1, ... }  (count acquisti, cumulabili)
var perm_upgrades: Dictionary = {}

var selected_skin:   String = "default"       ## Skin navicella attiva
var unlocked_skins:  Array  = ["default"]     ## Skin sbloccate permanentemente
var unlocked_powers: Array  = []              ## Power-id sbloccati permanentemente (una-tantum)

## Contatori Hardcore per sblocco skin esclusive
var total_hc_bosses_killed: int = 0           ## Boss totali uccisi in modalità HC (cumulativi)
var best_wave_hardcore_all: int = 0           ## Alias: usa best_wave_hardcore, ridondante ma esplicito

# ---------------------------------------------------------------------------
# STATO RUNTIME (non salvato)
# ---------------------------------------------------------------------------
var crit_storm_stacks: int = 0         ## Stack per knight_crit_storm
var entropy_kill_bonus: float = 0.0    ## Bonus danno da lord_entropy


func _ready() -> void:
	_init_defaults()
	load_progress()


# ---------------------------------------------------------------------------
# INIT & DEFAULTS
# ---------------------------------------------------------------------------
func _init_defaults() -> void:
	for char_id in CHARACTERS:
		if not character_levels.has(char_id):
			character_levels[char_id] = 1
		if not character_xp.has(char_id):
			character_xp[char_id] = 0
		if not runs_per_character.has(char_id):
			runs_per_character[char_id] = 0

	# Void Sentinel sempre sbloccato
	if "void_sentinel" not in unlocked_characters:
		unlocked_characters.append("void_sentinel")

	# Skin default sempre disponibile
	if "default" not in unlocked_skins:
		unlocked_skins.append("default")


# ---------------------------------------------------------------------------
# XP / LIVELLI
# ---------------------------------------------------------------------------
func xp_for_next_level(char_id: String) -> int:
	var lv: int = character_levels.get(char_id, 1)
	return int(BASE_XP_PER_LEVEL * pow(XP_SCALE, lv - 1))


func gain_xp(char_id: String, amount: int) -> void:
	if char_id not in CHARACTERS:
		return

	character_xp[char_id] = character_xp.get(char_id, 0) + amount
	total_souls += amount
	total_souls_ever += amount

	xp_gained.emit(amount, character_xp[char_id])

	# Level-up loop (può salire più livelli insieme)
	while character_xp[char_id] >= xp_for_next_level(char_id):
		character_xp[char_id] -= xp_for_next_level(char_id)
		character_levels[char_id] = character_levels.get(char_id, 1) + 1
		level_up.emit(char_id, character_levels[char_id])


## Aggiunge souls senza richiedere un char_id — usato dai nemici durante la run.
## Non incrementa XP del personaggio (solo la valuta spendibile).
func gain_souls(amount: int) -> void:
	total_souls      += amount
	total_souls_ever += amount
	xp_gained.emit(amount, 0)


## Moltiplicatore logaritmico per le stats in base al livello.
## Lv1=1.0, Lv10≈1.23, Lv50≈1.59
func get_level_multiplier(char_id: String) -> float:
	var lv: int = character_levels.get(char_id, 1)
	return 1.0 + log(float(lv)) * 0.1


# ---------------------------------------------------------------------------
# FINE RUN
# ---------------------------------------------------------------------------
func on_run_complete(_success: bool, wave_reached: int, kills: int) -> void:
	## Chiamato da GameManager.end_game()
	runs_per_character[selected_character] = runs_per_character.get(selected_character, 0) + 1

	# Aggiorna record personale wave
	if wave_reached > best_wave:
		best_wave = wave_reached
	# Aggiorna record Hardcore separato
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.get("game_mode") == "hardcore":
		if wave_reached > best_wave_hardcore:
			best_wave_hardcore = wave_reached

	# Formula: kills × 2 + wave × 10 (+50% bonus in Hardcore)
	var souls_earned := kills * 2 + wave_reached * 10
	if gm and gm.get("game_mode") == "hardcore":
		souls_earned = int(souls_earned * 1.5)
	gain_xp(selected_character, souls_earned)

	# Controlla sblocchi standard
	_check_unlocks(wave_reached)
	# Controlla sblocchi skin HC
	_check_hc_skin_unlocks()

	# Reset runtime
	crit_storm_stacks = 0
	entropy_kill_bonus = 0.0

	save_progress()


## True se la modalità Hardcore è sbloccata
func is_hardcore_unlocked() -> bool:
	return total_souls_ever >= 500 or best_wave >= 8


## Chiamato dall'EnemySpawner quando un boss muore in modalità Hardcore
func on_boss_killed_hc() -> void:
	total_hc_bosses_killed += 1
	_check_hc_skin_unlocks()
	save_progress()


## Controlla e sblocca automaticamente le skin HC-esclusive
func _check_hc_skin_unlocks() -> void:
	var conditions: Dictionary = {
		"void_reaper":   total_hc_bosses_killed >= 1,
		"hc_wave_5":     best_wave_hardcore >= 5,    # → "crimson_fury"
		"hc_boss_3":     total_hc_bosses_killed >= 3, # → "blood_angel"
		"hc_wave_10":    best_wave_hardcore >= 10,    # → "zero_kai"
	}
	# Mappa condition → skin_id
	var cond_to_skin: Dictionary = {
		"hc_boss_1":  "void_reaper",
		"hc_wave_5":  "crimson_fury",
		"hc_boss_3":  "blood_angel",
		"hc_wave_10": "zero_kai",
	}
	# Ridefinisci correttamente usando hc_unlock_condition come chiave
	var skin_conditions: Dictionary = {
		"void_reaper":  total_hc_bosses_killed >= 1,
		"crimson_fury": best_wave_hardcore >= 5,
		"blood_angel":  total_hc_bosses_killed >= 3,
		"zero_kai":     best_wave_hardcore >= 10,
	}
	for skin_id: String in skin_conditions:
		if skin_id not in unlocked_skins and skin_conditions[skin_id]:
			unlocked_skins.append(skin_id)
			character_unlocked.emit(skin_id)   # riusa il segnale per notifiche UI


func _check_unlocks(wave_reached: int) -> void:
	for char_id in CHARACTERS:
		if char_id in unlocked_characters:
			continue
		var condition: String = CHARACTERS[char_id].get("unlock_condition", "")
		var should_unlock := false

		match condition:
			"reach_wave_10":
				should_unlock = wave_reached >= 10
			"earn_1000_souls":
				should_unlock = total_souls_ever >= 1000
			"complete_run_all_chars":
				var all_done := true
				for cid in ["void_sentinel", "plasma_caster", "echo_knight"]:
					if runs_per_character.get(cid, 0) == 0:
						all_done = false
						break
				should_unlock = all_done
			"":
				should_unlock = CHARACTERS[char_id].get("unlock_by_default", false)

		if should_unlock:
			unlocked_characters.append(char_id)
			character_unlocked.emit(char_id)


# ---------------------------------------------------------------------------
# TALENTI
# ---------------------------------------------------------------------------
func can_unlock_talent(talent_id: String) -> bool:
	if talent_id not in TALENTS:
		return false
	if talent_id in unlocked_talents:
		return false

	var t: Dictionary = TALENTS[talent_id]
	if total_souls < t.get("cost", 9999):
		return false

	var req: String = t.get("requires", "")
	if req != "" and req not in unlocked_talents:
		return false

	var char_id: String = t.get("character", "")
	if char_id not in unlocked_characters:
		return false

	return true


func unlock_talent(talent_id: String) -> bool:
	if not can_unlock_talent(talent_id):
		return false

	total_souls -= TALENTS[talent_id].get("cost", 0)
	unlocked_talents.append(talent_id)
	talent_unlocked.emit(talent_id)
	save_progress()
	return true


# ---------------------------------------------------------------------------
# STATS FINALI DEL PERSONAGGIO SELEZIONATO
# (comprende livello + talenti attivi)
# ---------------------------------------------------------------------------
func get_active_stats() -> Dictionary:
	if selected_character not in CHARACTERS:
		selected_character = "void_sentinel"

	var char_data: Dictionary = CHARACTERS[selected_character]
	var stats: Dictionary = char_data["base_stats"].duplicate(true)
	var lv_mult := get_level_multiplier(selected_character)

	# Applica moltiplicatore livello
	stats["max_health"]   = stats["max_health"]   * lv_mult
	stats["damage_mult"]  = stats["damage_mult"]  * lv_mult
	stats["move_speed"]   = stats["move_speed"]   + (lv_mult - 1.0) * 100.0

	# Aggiungi slot per bonus talenti (init 0)
	stats["damage_reduction"]    = 0.0
	stats["melee_damage_bonus"]  = 0.0
	stats["projectile_scale"]    = 1.0
	stats["plasma_nova_enabled"] = false
	stats["crit_storm_enabled"]  = false
	stats["singularity_enabled"] = false
	stats["entropy_enabled"]     = false

	# Applica talenti sbloccati
	for tid in unlocked_talents:
		if tid not in TALENTS:
			continue
		var eff: Dictionary = TALENTS[tid].get("effect", {})

		if eff.has("max_health_bonus"):
			stats["max_health"] += eff["max_health_bonus"]
		if eff.has("damage_mult_bonus"):
			stats["damage_mult"] += eff["damage_mult_bonus"]
		if eff.has("move_speed_bonus"):
			stats["move_speed"] += eff["move_speed_bonus"]
		if eff.has("crit_chance_bonus"):
			stats["crit_chance"] += eff["crit_chance_bonus"]
		if eff.has("damage_reduction"):
			stats["damage_reduction"] += eff["damage_reduction"]
		if eff.has("melee_damage_bonus"):
			stats["melee_damage_bonus"] += eff["melee_damage_bonus"]
		if eff.has("projectile_scale_bonus"):
			stats["projectile_scale"] += eff["projectile_scale_bonus"]
		if eff.has("plasma_nova_enabled"):
			stats["plasma_nova_enabled"] = true
		if eff.has("crit_storm_enabled"):
			stats["crit_storm_enabled"] = true
		if eff.has("singularity_enabled"):
			stats["singularity_enabled"] = true
		if eff.has("entropy_enabled"):
			stats["entropy_enabled"] = true
		if eff.has("all_stats_bonus"):
			var b: float = eff["all_stats_bonus"]
			stats["max_health"]  *= (1.0 + b)
			stats["damage_mult"] *= (1.0 + b)
			stats["move_speed"]  *= (1.0 + b)

	# Bonus runtime (entropy, ecc.)
	if entropy_kill_bonus > 0.0:
		stats["damage_mult"] *= (1.0 + entropy_kill_bonus)

	return stats


## Colori delle skin — deve restare sincronizzato con SKIN_CATALOG in shop.gd
const SKIN_COLOR_MAP: Dictionary = {
	"default":      Color(0.55, 0.22, 1.00),
	"interceptor":  Color(0.30, 0.60, 1.00),
	"titan":        Color(0.90, 0.65, 0.20),
	"phantom":      Color(0.50, 0.80, 0.90),
	"neon_ghost":   Color(0.15, 1.00, 0.45),
	"aurora":       Color(0.90, 0.30, 1.00),
	"eclipse":      Color(1.00, 0.78, 0.10),
	"void_reaper":  Color(0.90, 0.05, 0.05),
	"crimson_fury": Color(1.00, 0.35, 0.02),
	"blood_angel":  Color(0.75, 0.00, 0.18),
	"zero_kai":     Color(0.88, 0.95, 1.00),
}

## Ritorna il colore attivo: skin selezionata (se non default) altrimenti colore personaggio
func get_active_color() -> Color:
	if selected_skin != "default" and SKIN_COLOR_MAP.has(selected_skin):
		return SKIN_COLOR_MAP[selected_skin]
	return CHARACTERS.get(selected_character, CHARACTERS["void_sentinel"]).get("color", Color.CYAN)


## Ritorna true se il talento è acquistato
func has_talent(talent_id: String) -> bool:
	return talent_id in unlocked_talents


# ---------------------------------------------------------------------------
# RUNTIME: EFFETTI SPECIALI TALENTI
# ---------------------------------------------------------------------------

## Chiamato da Player quando ottiene un crit consecutivo
func on_crit_hit() -> void:
	if has_talent("knight_crit_storm"):
		crit_storm_stacks = mini(crit_storm_stacks + 1, 5)


## Chiamato da Player quando NON ottiene un crit (rompe la serie)
func on_non_crit_hit() -> void:
	crit_storm_stacks = 0


## Ritorna il bonus danno da Crit Storm (0.0–0.50)
func get_crit_storm_bonus() -> float:
	return crit_storm_stacks * 0.10


## Chiamato da GameManager.add_kill() → accumula bonus entropy
func on_enemy_killed_for_entropy() -> void:
	if has_talent("lord_entropy") and selected_character == "void_lord":
		entropy_kill_bonus = minf(entropy_kill_bonus + 0.01, 0.50)


# ---------------------------------------------------------------------------
# SAVE / LOAD
# ---------------------------------------------------------------------------
func save_progress() -> void:
	var data := {
		"total_souls":             total_souls,
		"total_souls_ever":        total_souls_ever,
		"best_wave":               best_wave,
		"best_wave_hardcore":      best_wave_hardcore,
		"total_hc_bosses_killed":  total_hc_bosses_killed,
		"character_levels":        character_levels,
		"character_xp":            character_xp,
		"unlocked_characters":     unlocked_characters,
		"unlocked_talents":        unlocked_talents,
		"selected_character":      selected_character,
		"runs_per_character":      runs_per_character,
		"perm_upgrades":           perm_upgrades,
		"selected_skin":           selected_skin,
		"unlocked_skins":          unlocked_skins,
		"unlocked_powers":         unlocked_powers,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		save_completed.emit()
	else:
		push_error("MetaManager: impossibile scrivere su " + SAVE_PATH)


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_init_defaults()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("MetaManager: impossibile leggere " + SAVE_PATH)
		return

	var content := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if parsed == null or not parsed is Dictionary:
		push_warning("MetaManager: save corrotto, reset al default")
		_init_defaults()
		return

	total_souls               = parsed.get("total_souls", 0)
	total_souls_ever          = parsed.get("total_souls_ever", 0)
	best_wave                 = parsed.get("best_wave", 0)
	best_wave_hardcore        = parsed.get("best_wave_hardcore", 0)
	total_hc_bosses_killed    = parsed.get("total_hc_bosses_killed", 0)
	character_levels     = parsed.get("character_levels", {})
	character_xp         = parsed.get("character_xp", {})
	unlocked_characters  = Array(parsed.get("unlocked_characters", []))
	unlocked_talents     = Array(parsed.get("unlocked_talents", []))
	selected_character   = parsed.get("selected_character", "void_sentinel")
	runs_per_character   = parsed.get("runs_per_character", {})
	perm_upgrades        = parsed.get("perm_upgrades", {})
	selected_skin        = parsed.get("selected_skin",    "default")
	unlocked_skins       = Array(parsed.get("unlocked_skins",  ["default"]))
	unlocked_powers      = Array(parsed.get("unlocked_powers", []))

	_init_defaults()


## Acquista un upgrade permanente (run_end_shop lo chiama direttamente)
func buy_perm_upgrade(upgrade_id: String, cost: int) -> bool:
	if total_souls < cost:
		return false
	total_souls -= cost
	perm_upgrades[upgrade_id] = perm_upgrades.get(upgrade_id, 0) + 1
	save_progress()
	return true


## Ritorna il livello (count acquisti) di un upgrade permanente
func get_perm_level(upgrade_id: String) -> int:
	return perm_upgrades.get(upgrade_id, 0)


func reset_all_progress() -> void:
	total_souls         = 0
	total_souls_ever    = 0
	character_levels    = {}
	character_xp        = {}
	unlocked_characters = []
	unlocked_talents    = []
	selected_character  = "void_sentinel"
	runs_per_character  = {}
	_init_defaults()
	save_progress()


# ---------------------------------------------------------------------------
# SKIN NAVICELLA
# ---------------------------------------------------------------------------

## Sblocca (se necessario) e seleziona una skin. Ritorna false se non si hanno souls.
func unlock_and_select_skin(skin_id: String, cost: int) -> bool:
	if skin_id not in unlocked_skins:
		if total_souls < cost:
			return false
		total_souls -= cost
		unlocked_skins.append(skin_id)
	selected_skin = skin_id
	save_progress()
	return true


## Seleziona una skin già sbloccata (gratis).
func select_skin(skin_id: String) -> void:
	if skin_id in unlocked_skins:
		selected_skin = skin_id
		save_progress()


## True se la skin è già sbloccata.
func is_skin_unlocked(skin_id: String) -> bool:
	return skin_id in unlocked_skins


# ---------------------------------------------------------------------------
# POTERI Q/E  (sblocco permanente una-tantum)
# ---------------------------------------------------------------------------

## Sblocca un potere pagando una sola volta. Ritorna true se ha già il potere o se
## l'acquisto va a buon fine. Ritorna false se non bastano i souls.
func unlock_power(power_id: String, cost: int) -> bool:
	if power_id in unlocked_powers:
		return true   # già sbloccato, equipaggiare è gratis
	if total_souls < cost:
		return false
	total_souls -= cost
	unlocked_powers.append(power_id)
	save_progress()
	return true


## True se il potere è stato sbloccato almeno una volta.
func is_power_unlocked(power_id: String) -> bool:
	return power_id in unlocked_powers
