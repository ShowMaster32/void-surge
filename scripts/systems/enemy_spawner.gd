extends Node2D
class_name EnemySpawner
## EnemySpawner - Gestisce lo spawn continuo di nemici e il sistema boss.
## Boss ogni 5 wave: al termine dello shop, se current_wave % 5 == 0, spawna il boss.
## Durante la wave boss lo spawn normale è sospeso e il timer non avanza.

signal wave_changed(wave: int)
signal boss_wave_started(boss_id: int, boss: Node)
signal boss_killed

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 600.0
@export var spawn_margin: float = 100.0

@export_group("Spawn Settings")
@export var initial_spawn_rate: float = 1.2
@export var max_spawn_rate:     float = 8.0
@export var spawn_rate_increase: float = 0.07
@export var wave_duration:      float = 30.0
@export var max_enemies:        int   = 40

var current_wave: int = 1
var spawn_rate:   float
var spawn_timer:  float = 0.0
var wave_timer:   float = 0.0
var active_enemies: Array[Node2D] = []

var zone_generator: ZoneGenerator

# ── Boss state ─────────────────────────────────────────────────────────────────
var _boss_wave:    bool = false   # true mentre il boss è vivo
var _current_boss: Node = null    # riferimento al boss corrente

const BOSS_WAVE_INTERVAL_STANDARD  := 5   # ogni 5 wave (Standard)
const BOSS_WAVE_INTERVAL_HARDCORE  := 3   # ogni 3 wave (Hardcore)


func _ready() -> void:
	add_to_group("enemy_spawner")
	spawn_rate = initial_spawn_rate
	await get_tree().process_frame
	zone_generator = get_tree().get_first_node_in_group("zone_generator") as ZoneGenerator

	# Aggancio al segnale shop_closed per sapere quando iniziare la boss wave
	await get_tree().process_frame
	var shop_node := get_tree().get_first_node_in_group("shop")
	if shop_node and shop_node.has_signal("shop_closed"):
		shop_node.shop_closed.connect(_on_shop_closed)


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# ── Boss wave attiva: sospendi spawn normale e timer ────────────────────
	if _boss_wave:
		if not is_instance_valid(_current_boss) or _current_boss.get("is_dead"):
			_boss_wave    = false
			_current_boss = null
		return   # blocca timer e spawn durante boss wave

	# ── Avanzamento timer wave ────────────────────────────────────────────────
	wave_timer += delta
	if wave_timer >= wave_duration:
		_advance_wave()

	# ── Spawn nemici normali ──────────────────────────────────────────────────
	var zone_spawn_mult := 1.0
	if zone_generator and zone_generator.current_zone:
		zone_spawn_mult = zone_generator.current_zone.enemy_spawn_multiplier

	spawn_timer += delta
	var spawn_interval := 1.0 / (spawn_rate * zone_spawn_mult)

	while spawn_timer >= spawn_interval:
		spawn_timer -= spawn_interval
		_try_spawn_enemy()

	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))


func _advance_wave() -> void:
	wave_timer   = 0.0
	current_wave += 1
	GameManager.current_wave = current_wave

	spawn_rate = minf(initial_spawn_rate + (current_wave - 1) * spawn_rate_increase, max_spawn_rate)

	if current_wave % 3 == 0 and zone_generator:
		zone_generator.next_zone()

	wave_changed.emit(current_wave)   # apre lo shop


# ── Callback: lo shop si è chiuso ─────────────────────────────────────────────
func _on_shop_closed() -> void:
	var interval := BOSS_WAVE_INTERVAL_HARDCORE if GameManager.game_mode == "hardcore" \
		else BOSS_WAVE_INTERVAL_STANDARD
	if current_wave % interval == 0:
		_spawn_boss()


# ══════════════════════════════════════════════
#  Spawn boss
# ══════════════════════════════════════════════

func _spawn_boss() -> void:
	# Uccidi tutti i nemici normali prima del boss
	for e in active_enemies:
		if is_instance_valid(e):
			e.queue_free()
	active_enemies.clear()

	# Carica scena boss (runtime, nessuna modifica a main.tscn necessaria)
	var boss_scene: PackedScene = load("res://scenes/enemies/boss.tscn")
	if not boss_scene:
		push_error("EnemySpawner: impossibile caricare res://scenes/enemies/boss.tscn")
		return

	var _interval := BOSS_WAVE_INTERVAL_HARDCORE if GameManager.game_mode == "hardcore" \
		else BOSS_WAVE_INTERVAL_STANDARD
	var boss_id := (int(current_wave / _interval) - 1) % 4

	# Posizione di spawn (fuori dallo schermo visibile)
	var spawn_pos := _get_spawn_position()
	if spawn_pos == Vector2.INF:
		spawn_pos = Vector2(700.0, 0.0)

	# Istanzia il boss
	var boss := boss_scene.instantiate()

	# boss_id DEVE essere impostato PRIMA di add_child (usato in _ready())
	if "boss_id" in boss:
		boss.boss_id = boss_id

	boss.global_position = spawn_pos
	boss.died.connect(_on_boss_died)
	_current_boss = boss
	_boss_wave    = true

	add_child(boss)   # _ready() corre qui → applica BOSS_DATA[boss_id] a max_health/damage

	# Scala HP e danno DOPO _ready() (che ha già impostato i valori base da BOSS_DATA)
	var wave_mult := 1.0 + (current_wave - 1) * 0.12
	if "max_health" in boss and "health" in boss:
		boss.max_health *= wave_mult
		boss.health      = boss.max_health   # riallinea health dopo il cambio
	if "damage" in boss:
		boss.damage *= wave_mult

	# HUD boss
	_spawn_boss_hud(boss)

	boss_wave_started.emit(boss_id, boss)

	# Notifica milestone
	var notifier := get_tree().get_first_node_in_group("milestone_notifier")
	if notifier and notifier.has_method("show_notification"):
		var boss_name: String = boss.get_boss_name() if boss.has_method("get_boss_name") else "BOSS"
		notifier.show_notification("⚔  " + boss_name + "  APPARE  ⚔", Color(1.0, 0.25, 0.25))


func _spawn_boss_hud(boss: Node) -> void:
	var hud_script := load("res://scripts/systems/boss_hud.gd")
	if not hud_script:
		return
	var hud: Node = Node.new()
	hud.set_script(hud_script)
	get_tree().current_scene.add_child(hud)
	if hud.has_method("setup"):
		hud.setup(boss)


func _on_boss_died(_boss: Node = null) -> void:
	_boss_wave    = false
	_current_boss = null

	boss_killed.emit()

	# Dai souls bonus al giocatore
	var mm := get_node_or_null("/root/MetaManager")
	if mm and mm.has_method("gain_souls"):
		mm.gain_souls(50)

	# Avanza alla wave successiva (apre lo shop)
	_advance_wave()


# ══════════════════════════════════════════════
#  Spawn nemici normali
# ══════════════════════════════════════════════

func _try_spawn_enemy() -> void:
	var zone_max_mult := 1.0
	if zone_generator and zone_generator.current_zone:
		zone_max_mult = zone_generator.current_zone.enemy_spawn_multiplier

	var effective_max := int(max_enemies * zone_max_mult)
	if active_enemies.size() >= effective_max:
		return

	if not enemy_scene:
		push_warning("EnemySpawner: enemy_scene non assegnata!")
		return

	var spawn_position := _get_spawn_position()
	if spawn_position == Vector2.INF:
		return

	var enemy := enemy_scene.instantiate() as Enemy
	enemy.global_position = spawn_position

	var wave_multiplier := 1.0 + (current_wave - 1) * 0.1

	var zone_health_mult := 1.0
	var zone_damage_mult := 1.0
	var zone_speed_mult  := 1.0

	if zone_generator and zone_generator.current_zone:
		var zone := zone_generator.current_zone
		zone_health_mult = zone.enemy_health_multiplier
		zone_damage_mult = zone.enemy_damage_multiplier
		zone_speed_mult  = zone.enemy_speed_multiplier
		enemy.setup_zone_color(zone.glow_color, 0.2)

	# Modificatori Hardcore
	var hc_hp  := 1.0
	var hc_dmg := 1.0
	var hc_spd := 1.0
	if GameManager.game_mode == "hardcore":
		hc_hp  = 2.0
		hc_dmg = 1.5
		hc_spd = 1.3

	enemy.max_health *= wave_multiplier * zone_health_mult * hc_hp
	enemy.damage     *= wave_multiplier * zone_damage_mult * hc_dmg
	enemy.move_speed *= (1.0 + (current_wave - 1) * 0.02) * zone_speed_mult * hc_spd

	enemy.died.connect(_on_enemy_died)
	active_enemies.append(enemy)
	add_child(enemy)


func _get_spawn_position() -> Vector2:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return Vector2.INF

	var center := Vector2.ZERO
	for player in players:
		center += player.global_position
	center /= players.size()

	for _attempt in range(10):
		var angle    := randf() * TAU
		var distance := spawn_radius + randf() * spawn_margin
		var spawn_pos := center + Vector2(cos(angle), sin(angle)) * distance

		var valid := true
		for player in players:
			if spawn_pos.distance_to(player.global_position) < spawn_radius * 0.8:
				valid = false
				break

		if valid:
			return spawn_pos

	return Vector2.INF


func _on_enemy_died(enemy: Enemy) -> void:
	active_enemies.erase(enemy)

	for player in get_tree().get_nodes_in_group("players"):
		if player.has_method("on_kill"):
			player.on_kill()


func get_enemy_count() -> int:
	return active_enemies.size()
