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

var character_levels: Dictionary = {}  ## char_id → livello (int)
var character_xp: Dictionary = {}      ## char_id → xp corrente (int)

var unlocked_characters: Array = []    ## Lista char_id sbloccati
var unlocked_talents: Array = []       ## Lista talent_id acquistati

var selected_character: String = "void_sentinel"
var runs_per_character: Dictionary = {}  ## char_id → n° run completate

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

	# Formula: kills × 2 + wave × 10
	var souls_earned := kills * 2 + wave_reached * 10
	gain_xp(selected_character, souls_earned)

	# Controlla sblocchi
	_check_unlocks(wave_reached)

	# Reset runtime
	crit_storm_stacks = 0
	entropy_kill_bonus = 0.0

	save_progress()


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


## Ritorna il colore del personaggio selezionato
func get_active_color() -> Color:
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
		"total_souls":        total_souls,
		"total_souls_ever":   total_souls_ever,
		"character_levels":   character_levels,
		"character_xp":       character_xp,
		"unlocked_characters": unlocked_characters,
		"unlocked_talents":   unlocked_talents,
		"selected_character": selected_character,
		"runs_per_character": runs_per_character,
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

	total_souls          = parsed.get("total_souls", 0)
	total_souls_ever     = parsed.get("total_souls_ever", 0)
	character_levels     = parsed.get("character_levels", {})
	character_xp         = parsed.get("character_xp", {})
	unlocked_characters  = Array(parsed.get("unlocked_characters", []))
	unlocked_talents     = Array(parsed.get("unlocked_talents", []))
	selected_character   = parsed.get("selected_character", "void_sentinel")
	runs_per_character   = parsed.get("runs_per_character", {})

	_init_defaults()


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
