extends Node
## RunSaver — Salva e ripristina lo stato di una run in corso.
##
## Il salvataggio è "run resume": se chiudi il gioco a metà run,
## al prossimo avvio puoi continuare da dove eri rimasto.
## (NON è un checkpoint tradizionale — la run resta roguelite.)
##
## Salvataggio automatico:
##   - Ad ogni cambio wave (prima che si apra lo shop)
##   - Ogni 60 secondi durante la partita
##
## Cancellazione automatica:
##   - Al game over / vittoria (run terminata correttamente)
##
## API pubblica:
##   RunSaver.has_save() -> bool
##   RunSaver.save_run()
##   RunSaver.load_run() -> Dictionary  (vuoto se nessun salvataggio)
##   RunSaver.delete_save()

const SAVE_PATH   := "user://run_resume.json"
const AUTOSAVE_INTERVAL := 60.0   ## salvataggio automatico ogni 60 secondi

var _autosave_timer: float = 0.0
var _active: bool = false   ## true solo mentre siamo in partita


# ═══════════════════════════════════════════════════════════════════════════════
#  Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connetti ai segnali di GameManager
	await get_tree().process_frame
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_over.connect(_on_run_ended)
	GameManager.game_won.connect(_on_run_ended)

	# Connetti ai cambi wave (salva prima dello shop)
	await get_tree().process_frame
	_connect_spawner()


func _process(delta: float) -> void:
	if not _active:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_run()


func _connect_spawner() -> void:
	var spawner := get_tree().get_first_node_in_group("enemy_spawner")
	if spawner and spawner.has_signal("wave_pre_clear"):
		spawner.wave_pre_clear.connect(func(_w, _s): save_run())


func _on_game_started() -> void:
	_active = true
	_autosave_timer = 0.0


func _on_run_ended(_stats: Dictionary) -> void:
	_active = false
	delete_save()   ## run completata/terminata → cancella il resume


# ═══════════════════════════════════════════════════════════════════════════════
#  API pubblica
# ═══════════════════════════════════════════════════════════════════════════════

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_run() -> void:
	if GameManager.current_state == GameManager.GameState.MENU:
		return

	var data := _collect_state()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	else:
		push_warning("RunSaver: impossibile scrivere " + SAVE_PATH)


func load_run() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var raw: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ═══════════════════════════════════════════════════════════════════════════════
#  Raccolta stato
# ═══════════════════════════════════════════════════════════════════════════════

func _collect_state() -> Dictionary:
	var state: Dictionary = {}

	# Stato globale
	state["wave"]          = GameManager.current_wave
	state["run_time"]      = GameManager.run_time
	state["total_kills"]   = GameManager.total_kills
	state["damage_dealt"]  = GameManager.total_damage_dealt
	state["game_mode"]     = GameManager.game_mode

	# Configurazione run
	state["active_power_q"] = GameManager.get_meta("active_power_q", "") as String
	state["active_power_e"] = GameManager.get_meta("active_power_e", "") as String
	state["active_weapon"]  = GameManager.get_meta("active_weapon", "standard") as String

	# Bonus shop acquistati
	if GameManager.has_meta("shop_bonuses"):
		state["shop_bonuses"] = GameManager.get_meta("shop_bonuses")

	# Stato player (HP, posizione)
	var players_data: Array = []
	for p in GameManager.players:
		if not is_instance_valid(p):
			continue
		var pd: Dictionary = {}
		pd["id"]             = p.get("player_id") if p.get("player_id") != null else 0
		pd["current_health"] = p.get("current_health") if p.get("current_health") != null else 100.0
		pd["max_health"]     = p.get("max_health") if p.get("max_health") != null else 100.0
		pd["pos_x"]          = p.global_position.x
		pd["pos_y"]          = p.global_position.y
		players_data.append(pd)
	state["players"] = players_data

	# Timestamp salvataggio
	state["saved_at"] = Time.get_unix_time_from_system()

	return state


# ═══════════════════════════════════════════════════════════════════════════════
#  Ripristino stato  (chiamato da MetaHub / StartScreen dopo confirm)
# ═══════════════════════════════════════════════════════════════════════════════

func apply_saved_state() -> void:
	## Ripristina GameManager e player dallo stato salvato.
	## Chiamare DOPO che la scena di gioco è stata caricata e i player sono spawnati.
	var data: Dictionary = load_run()
	if data.is_empty():
		return

	# Ripristina GameManager
	GameManager.current_wave        = data.get("wave", 1) as int
	GameManager.run_time            = data.get("run_time", 0.0) as float
	GameManager.total_kills         = data.get("total_kills", 0) as int
	GameManager.total_damage_dealt  = data.get("damage_dealt", 0.0) as float
	GameManager.game_mode           = data.get("game_mode", "standard") as String

	# Ripristina metadati run
	var pq: String = data.get("active_power_q", "") as String
	var pe: String = data.get("active_power_e", "") as String
	var pw: String = data.get("active_power_e", "standard") as String
	GameManager.set_meta("active_power_q", pq)
	GameManager.set_meta("active_power_e", pe)
	GameManager.set_meta("active_weapon",  data.get("active_weapon", "standard") as String)

	if data.has("shop_bonuses"):
		GameManager.set_meta("shop_bonuses", data["shop_bonuses"])

	# Ripristina HP player
	var players_data: Array = data.get("players", []) as Array
	for pd: Dictionary in players_data:
		var pid: int = pd.get("id", 0) as int
		for p in GameManager.players:
			if not is_instance_valid(p):
				continue
			if p.get("player_id") == pid:
				var hp: float = pd.get("current_health", 100.0) as float
				if p.has_method("heal"):
					var cur_hp_var = p.get("current_health")
					var cur_hp: float = cur_hp_var as float if cur_hp_var != null else hp
					p.heal(hp - cur_hp)
				var px: float = pd.get("pos_x", 0.0) as float
				var py: float = pd.get("pos_y", 0.0) as float
				p.global_position = Vector2(px, py)
				break

	# Avanza spawner alla wave corretta
	var target_wave: int = data.get("wave", 1) as int
	if target_wave > 1:
		var spawner := get_tree().get_first_node_in_group("enemy_spawner")
		if spawner and spawner.get("current_wave") != null:
			spawner.current_wave = target_wave

	print("RunSaver: stato ripristinato — wave %d, tempo %ds" % [
		GameManager.current_wave, int(GameManager.run_time)
	])
