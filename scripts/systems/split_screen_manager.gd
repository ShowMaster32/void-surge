extends Node
class_name SplitScreenManager
## SplitScreenManager - Gestisce split screen per 2-4 giocatori co-op
##
## ARCHITETTURA:
## Il game world (fisici, logica) gira normalmente nel main viewport.
## Per ogni player creiamo un SubViewportContainer che copre la sua
## porzione di schermo. Ogni SubViewport condivide il World2D del
## main viewport → vede gli stessi oggetti da una camera diversa.
##
## Layout:
##   2 player: P1 in alto, P2 in basso (split orizzontale)
##   3 player: P1 top-left, P2 top-right, P3 bottom-left
##   4 player: P1 top-left, P2 top-right, P3 bottom-left, P4 bottom-right

const SPLIT_LINE_COLOR   := Color(0.0, 1.0, 1.0, 0.7)  # Cyan
const SPLIT_LINE_W       := 3

## Se true, la camera del main viewport viene disabilitata in split screen
@export var disable_main_camera: bool = true

var _containers: Array[SubViewportContainer] = []
var _subviewports: Array[SubViewport] = []
var _cameras: Array[PlayerCamera] = []
var _players: Array[Node2D] = []
var _player_count: int = 0
var _screen_size: Vector2

# Script precaricato per le camere
var _camera_script: GDScript


func _ready() -> void:
	add_to_group("split_screen_manager")
	_camera_script = load("res://scripts/player/player_camera.gd")


# ---------------------------------------------------------------------------
# SETUP PRINCIPALE
# ---------------------------------------------------------------------------

## Chiama questo dopo aver spawnato tutti i player.
## players: array ordinato [P1, P2, ...] (Node2D)
func setup(player_count: int, players: Array) -> void:
	_player_count = clampi(player_count, 1, 4)
	_players = players
	_screen_size = get_viewport().get_visible_rect().size

	_clear()

	if _player_count <= 1:
		# Single player: nessun split, la Camera2D del player resta attiva
		return

	# In split screen: disabilita la camera built-in di ogni player
	if disable_main_camera:
		_disable_player_cameras()

	# Crea i SubViewports
	var shared_world := get_viewport().world_2d
	var rects := _calculate_rects(_screen_size, _player_count)

	for i in _player_count:
		_create_viewport_for_player(i, rects[i], shared_world)

	# Linee di separazione
	_add_split_lines(rects)

	# Etichette P1/P2
	_add_player_labels(rects)


# ---------------------------------------------------------------------------
# CREAZIONE VIEWPORT
# ---------------------------------------------------------------------------

func _create_viewport_for_player(idx: int, rect: Rect2, world: World2D) -> void:
	# Container (posizionamento su schermo)
	var container := SubViewportContainer.new()
	container.name = "ViewportContainer_P%d" % (idx + 1)
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	container.position = rect.position
	container.size     = rect.size
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(container)
	_containers.append(container)

	# SubViewport: condivide World2D con la scena principale
	var svp := SubViewport.new()
	svp.name = "SubViewport_P%d" % (idx + 1)
	svp.size = Vector2i(rect.size)
	svp.world_2d = world                         # ← il segreto dello split screen
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(svp)
	_subviewports.append(svp)

	# Camera che segue il player
	var cam: PlayerCamera
	if _camera_script:
		cam = Camera2D.new()
		cam.set_script(_camera_script)
	else:
		cam = PlayerCamera.new()

	cam.name = "PlayerCamera_P%d" % (idx + 1)
	cam.player_id = idx

	# Posiziona la camera già sul player (no jump all'avvio)
	if idx < _players.size() and is_instance_valid(_players[idx]):
		cam.global_position = _players[idx].global_position
		cam.target = _players[idx]

	svp.add_child(cam)
	_cameras.append(cam)


# ---------------------------------------------------------------------------
# LAYOUT RECTS
# ---------------------------------------------------------------------------

func _calculate_rects(screen: Vector2, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var hw := screen.x * 0.5
	var hh := screen.y * 0.5

	match count:
		2:
			# P1 top, P2 bottom
			rects.append(Rect2(0,  0,       screen.x, hh))
			rects.append(Rect2(0,  hh,      screen.x, hh))
		3:
			# P1 top-left, P2 top-right, P3 bottom (full width)
			rects.append(Rect2(0,  0,       hw,       hh))
			rects.append(Rect2(hw, 0,       hw,       hh))
			rects.append(Rect2(0,  hh,      screen.x, hh))
		4:
			# 4 quadranti
			rects.append(Rect2(0,  0,       hw, hh))
			rects.append(Rect2(hw, 0,       hw, hh))
			rects.append(Rect2(0,  hh,      hw, hh))
			rects.append(Rect2(hw, hh,      hw, hh))
		_:
			rects.append(Rect2(Vector2.ZERO, screen))

	return rects


# ---------------------------------------------------------------------------
# LINEE DI SEPARAZIONE
# ---------------------------------------------------------------------------

func _add_split_lines(rects: Array[Rect2]) -> void:
	var added_h := {}  ## Evita duplicati su split orizzontale

	for i in rects.size():
		var r := rects[i]

		# Bordo destro (se non tocca il bordo schermo)
		var right_x := r.position.x + r.size.x
		if right_x < _screen_size.x - 1:
			_make_line(Vector2(right_x - SPLIT_LINE_W / 2.0, 0),
					   Vector2(SPLIT_LINE_W, _screen_size.y))

		# Bordo inferiore (se non tocca il bordo schermo)
		var bottom_y := r.position.y + r.size.y
		if bottom_y < _screen_size.y - 1 and not added_h.has(bottom_y):
			added_h[bottom_y] = true
			_make_line(Vector2(0, bottom_y - SPLIT_LINE_W / 2.0),
					   Vector2(_screen_size.x, SPLIT_LINE_W))


func _make_line(pos: Vector2, size: Vector2) -> void:
	var rect := ColorRect.new()
	rect.color = SPLIT_LINE_COLOR
	rect.position = pos
	rect.size = size
	rect.z_index = 200
	get_parent().add_child(rect)


# ---------------------------------------------------------------------------
# ETICHETTE PLAYER
# ---------------------------------------------------------------------------

func _add_player_labels(rects: Array[Rect2]) -> void:
	for i in rects.size():
		var lbl := Label.new()
		lbl.text = "P%d" % (i + 1)
		lbl.position = rects[i].position + Vector2(10, 8)
		lbl.add_theme_color_override("font_color",
			Player.PLAYER_COLORS[clampi(i, 0, 3)])
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.z_index = 210
		get_parent().add_child(lbl)


# ---------------------------------------------------------------------------
# UTILITY
# ---------------------------------------------------------------------------

func _disable_player_cameras() -> void:
	for p in _players:
		if not is_instance_valid(p):
			continue
		var cam := p.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.enabled = false


func _clear() -> void:
	for c in _containers:
		if is_instance_valid(c):
			c.queue_free()
	_containers.clear()
	_subviewports.clear()
	_cameras.clear()


## Ritorna la camera del player dato (null se single player)
func get_camera(player_id: int) -> PlayerCamera:
	if player_id < _cameras.size():
		return _cameras[player_id]
	return null


## Aggiorna il target di una camera (utile dopo respawn)
func update_target(player_id: int, new_target: Node2D) -> void:
	if player_id < _cameras.size() and _cameras[player_id]:
		_cameras[player_id].target = new_target
