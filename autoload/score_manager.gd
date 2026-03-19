extends Node
## ScoreManager — Classifica locale top-10 salvata su JSON.
##
## Ogni voce ha:
##   score, wave, kills, time, damage, victory, date
##
## Uso:
##   ScoreManager.submit(stats, victory)  → int (posizione 1-based)
##   ScoreManager.get_entries()           → Array[Dictionary]

const SAVE_PATH   := "user://leaderboard.json"
const MAX_ENTRIES := 10

var _entries: Array = []


func _ready() -> void:
	_load()


# ── API pubblica ────────────────────────────────────────────────────────────────

func submit(stats: Dictionary, victory: bool) -> int:
	## Inserisce la run, salva, ritorna la posizione in classifica (1-based, -1 se fuori top).
	var entry := {
		"score":   _calc_score(stats, victory),
		"wave":    stats.get("wave_reached", 1),
		"kills":   stats.get("kills", 0),
		"time":    stats.get("run_time", 0.0),
		"damage":  int(stats.get("damage_dealt", 0.0)),
		"victory": victory,
		"date":    Time.get_date_string_from_system(),
	}

	_entries.append(entry)
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)
	_save()

	for i in _entries.size():
		var e: Dictionary = _entries[i]
		if e["score"] == entry["score"] and e["date"] == entry["date"]:
			return i + 1
	return -1


func get_entries() -> Array:
	return _entries.duplicate()


func is_new_record(stats: Dictionary, victory: bool) -> bool:
	if _entries.is_empty():
		return true
	return _calc_score(stats, victory) > (_entries[0]["score"] as int)


# ── Calcolo punteggio ───────────────────────────────────────────────────────────

func _calc_score(stats: Dictionary, victory: bool) -> int:
	var s: int = 0
	s += stats.get("kills", 0)        * 100
	s += stats.get("wave_reached", 1) * 500
	s += int(stats.get("damage_dealt", 0.0))
	# Bonus sopravvivenza: +1 pt/secondo
	s += int(stats.get("run_time", 0.0))
	if victory:
		s = int(s * 2.5)
	return s


# ── Persistenza ─────────────────────────────────────────────────────────────────

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_entries, "\t"))
		file.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		_entries = parsed
