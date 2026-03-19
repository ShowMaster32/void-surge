extends Enemy
class_name Boss
## Boss — nemico speciale con meccaniche uniche.
## Spawna ogni 5 wave. boss_id (0-3) determina tipo, colore e special attack.
##
## boss_id 0 – VOID TITAN    : rush charge + danno doppio sul colpo
## boss_id 1 – PLASMA WEAVER : ring di 8 proiettili in tutte le direzioni
## boss_id 2 – NULL SHADE    : phase shift invincibile + teletrasporto
## boss_id 3 – ENTROPY CORE  : esplosione AOE + screen shake
##
## Impostare boss_id PRIMA di add_child() (come power_level in projectile.gd).

signal phase_changed(new_phase: int)

## ID del boss (0-3). Impostato dall'EnemySpawner prima di add_child().
var boss_id: int = 0

const BOSS_DATA: Array = [
	# 0: Void Titan
	{
		"name":         "VOID TITAN",
		"hp":           2500.0,
		"speed":        48.0,
		"damage":       22.0,
		"souls":        60,
		"special_cd":   5.5,
		"color":        Color(0.55, 0.02, 1.00),
		"phase2_color": Color(0.90, 0.30, 1.00),
	},
	# 1: Plasma Weaver
	{
		"name":         "PLASMA WEAVER",
		"hp":           2000.0,
		"speed":        88.0,
		"damage":       16.0,
		"souls":        70,
		"special_cd":   4.0,
		"color":        Color(1.00, 0.40, 0.02),
		"phase2_color": Color(1.00, 0.80, 0.10),
	},
	# 2: Null Shade
	{
		"name":         "NULL SHADE",
		"hp":           1800.0,
		"speed":        135.0,
		"damage":       14.0,
		"souls":        80,
		"special_cd":   3.2,
		"color":        Color(0.05, 0.90, 0.55),
		"phase2_color": Color(0.10, 0.60, 1.00),
	},
	# 3: Entropy Core
	{
		"name":         "ENTROPY CORE",
		"hp":           3500.0,
		"speed":        52.0,
		"damage":       20.0,
		"souls":        100,
		"special_cd":   5.0,
		"color":        Color(1.00, 0.82, 0.02),
		"phase2_color": Color(1.00, 0.40, 0.10),
	},
]

var boss_name: String   = ""
var phase:     int      = 1
var _phase2_triggered:  bool  = false
var _special_timer:     float = 0.0
var _special_cd:        float = 5.0

# Void Titan: rush charge
var _is_charging:  bool    = false
var _charge_timer: float   = 0.0
var _charge_dir:   Vector2 = Vector2.ZERO

# Null Shade: phase shift (invincibile + semi-trasparente)
var _is_phasing:   bool  = false
var _phase_timer:  float = 0.0


# ══════════════════════════════════════════════
#  Lifecycle
# ══════════════════════════════════════════════

func _ready() -> void:
	var idx  := boss_id % BOSS_DATA.size()
	var data: Dictionary = BOSS_DATA[idx]

	# Applica stat boss PRIMA di super._ready() che imposta health = max_health
	max_health   = data["hp"]
	move_speed   = data["speed"]
	damage       = data["damage"]
	soul_value   = data["souls"]
	_special_cd  = data["special_cd"]
	boss_name    = data["name"]
	xp_value     = 100
	drop_chance  = 1.0   # il boss droppa sempre
	attack_range = 55.0  # raggio maggiore

	super._ready()   # crea visuale, imposta health, ecc.

	# Sovrascrive il colore casuale di Enemy con il colore specifico del boss
	base_color = data["color"]
	if sprite != null:
		sprite.modulate = base_color

	# Collisione più grande (28px invece di 16px di default)
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is CircleShape2D:
		(cs.shape as CircleShape2D).radius = 28.0

	# Scala visuale (2× rispetto ai nemici normali)
	if sprite != null:
		sprite.scale = Vector2(2.2, 2.2)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# ── Transizione fase 2 ────────────────────────────────────────────────────
	if not _phase2_triggered and health <= max_health * 0.5:
		_enter_phase2()

	# ── Timer special attack ──────────────────────────────────────────────────
	_special_timer += delta
	if _special_timer >= _special_cd:
		_special_timer = 0.0
		_trigger_special()

	# ── Meccanica Void Titan: rush charge ─────────────────────────────────────
	if _is_charging:
		_charge_timer -= delta
		velocity = _charge_dir * 700.0
		move_and_slide()
		# Attacco a contatto durante il carico (doppio danno, doppio range)
		_attack_timer -= delta
		if _attack_timer <= 0.0 and is_instance_valid(target):
			var d := global_position.distance_to(target.global_position)
			if d <= attack_range * 2.0:
				if target.has_method("take_damage"):
					target.take_damage(damage * 2.0)
				_attack_timer = attack_cooldown
		if _charge_timer <= 0.0:
			_is_charging = false
		return   # salta AI normale durante il carico

	# ── Meccanica Null Shade: phase shift ────────────────────────────────────
	if _is_phasing:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_is_phasing = false
			modulate.a = 1.0
			_teleport_near_player()
		return   # fermo durante la fase

	# ── Movimento AI normale (ereditato da Enemy) ────────────────────────────
	super._physics_process(delta)


# ══════════════════════════════════════════════
#  Fase 2
# ══════════════════════════════════════════════

func _enter_phase2() -> void:
	_phase2_triggered = true
	phase             = 2
	move_speed       *= 1.4
	_special_cd      *= 0.65

	var data: Dictionary = BOSS_DATA[boss_id % BOSS_DATA.size()]
	base_color = data["phase2_color"]
	if sprite != null:
		sprite.modulate = base_color

	phase_changed.emit(2)

	# Screen shake sul giocatore più vicino
	for player in get_tree().get_nodes_in_group("players"):
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam and is_instance_valid(VFX):
			VFX.screen_shake(cam, 12.0, 0.55)
		break

	# Notifica
	var notifier := get_tree().get_first_node_in_group("milestone_notifier")
	if notifier and notifier.has_method("show_notification"):
		notifier.show_notification("⚠  " + boss_name + " – FASE 2  ⚠", Color(1.0, 0.3, 0.1))


# ══════════════════════════════════════════════
#  Special attacks
# ══════════════════════════════════════════════

func _trigger_special() -> void:
	match boss_id % BOSS_DATA.size():
		0: _special_void_titan()
		1: _special_plasma_weaver()
		2: _special_null_shade()
		3: _special_entropy_core()


## Void Titan: rush charge verso il giocatore
func _special_void_titan() -> void:
	if not is_instance_valid(target):
		_find_nearest_player()
	if not is_instance_valid(target):
		return
	_charge_dir   = (target.global_position - global_position).normalized()
	_is_charging  = true
	_charge_timer = 0.42

	# Flash bianco per annunciare la carica
	if sprite != null:
		sprite.modulate = Color(1, 1, 1)
		# Tween diretto sul nodo sprite (non tramite path stringa)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", base_color, 0.35)


## Plasma Weaver: ring di 8 proiettili
func _special_plasma_weaver() -> void:
	for i in 8:
		var angle := i * TAU / 8.0
		var dir   := Vector2(cos(angle), sin(angle))
		_fire_boss_ball(dir, damage * 0.75)


## Null Shade: diventa invincibile + si teletrasporta
func _special_null_shade() -> void:
	_is_phasing  = true
	_phase_timer = 1.5
	modulate.a   = 0.18


## Entropy Core: esplosione AOE che danneggia tutti i giocatori entro 200px
func _special_entropy_core() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(player):
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist < 220.0:
			if player.has_method("take_damage"):
				player.take_damage(damage * 1.3)
		# Screen shake per ogni giocatore colpito
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam and is_instance_valid(VFX):
			VFX.screen_shake(cam, 9.0, 0.35)

	# Burst VFX sulla posizione del boss
	if is_instance_valid(VFX):
		VFX.spawn_death_effect(global_position, base_color)


# ══════════════════════════════════════════════
#  Utility
# ══════════════════════════════════════════════

func _teleport_near_player() -> void:
	if not is_instance_valid(target):
		_find_nearest_player()
	if not is_instance_valid(target):
		return
	var angle       := randf() * TAU
	global_position  = target.global_position + Vector2(cos(angle), sin(angle)) * 110.0


## Crea un proiettile boss direttamente in codice (no .tscn)
func _fire_boss_ball(dir: Vector2, ball_dmg: float) -> void:
	var ball := Area2D.new()
	ball.global_position = global_position
	ball.collision_layer = 8   # boss projectile layer
	ball.collision_mask  = 1   # player layer

	# Sprite luminoso usando la stessa texture radiale dei proiettili player
	# _make_glow_texture è static: chiamata diretta sulla classe, senza has_method
	var sprite2 := Sprite2D.new()
	sprite2.modulate = base_color
	sprite2.texture  = Projectile._make_glow_texture(22)
	ball.add_child(sprite2)

	# Collision shape
	var cs    := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	cs.shape = shape
	ball.add_child(cs)

	# Script
	var ball_script := load("res://scripts/enemies/boss_ball.gd")
	if ball_script:
		ball.set_script(ball_script)
		ball.direction = dir
		ball.damage    = ball_dmg
		get_tree().current_scene.add_child(ball)


## Override: Null Shade è invincibile durante il phase shift
func take_damage(amount: float, crit: bool = false, source_id: int = -1) -> void:
	if _is_phasing:
		return
	super.take_damage(amount, crit, source_id)


func get_boss_name() -> String:
	return boss_name
