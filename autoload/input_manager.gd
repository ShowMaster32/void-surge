extends Node
## InputManager - Gestisce input per multiplayer locale
## Supporta keyboard+mouse (P1) e controller (P1-P4)
## FIX: get_aim_vector chiamava .get_viewport() su Vector2 (bug parser)

signal controller_connected(device_id: int)
signal controller_disconnected(device_id: int)

var device_to_player: Dictionary = {}
var player_to_device: Dictionary = {}

const KEYBOARD_MOUSE_DEVICE := -1


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	assign_device_to_player(KEYBOARD_MOUSE_DEVICE, 0)
	for device_id in Input.get_connected_joypads():
		_on_joy_connection_changed(device_id, true)
	_setup_controller_ui_actions()


## Registra le action UI per controller se non già presenti nel progetto.
## ui_accept / ui_cancel / ui_up / ui_down / ui_left / ui_right sono già
## mappati da Godot (JOY_BUTTON_A, B, D-pad). Qui aggiungiamo anche lo
## stick sinistro come alternativa al D-pad per navigare i menu.
func _setup_controller_ui_actions() -> void:
	var stick_actions := {
		"ui_left":  Vector2(-1.0,  0.0),
		"ui_right": Vector2( 1.0,  0.0),
		"ui_up":    Vector2( 0.0, -1.0),
		"ui_down":  Vector2( 0.0,  1.0),
	}
	for action in stick_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		# Aggiunge JoypadMotion (stick sinistro) solo se non già presente
		var already_has_motion := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion:
				already_has_motion = true
				break
		if not already_has_motion:
			var dir: Vector2 = stick_actions[action]
			var jm := InputEventJoypadMotion.new()
			jm.axis        = JOY_AXIS_LEFT_X if absf(dir.x) > 0 else JOY_AXIS_LEFT_Y
			jm.axis_value  = dir.x if absf(dir.x) > 0 else dir.y
			InputMap.action_add_event(action, jm)


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		for player_id in range(4):
			if player_id not in player_to_device.values() or player_id == 0:
				if player_id == 0 and KEYBOARD_MOUSE_DEVICE in device_to_player:
					continue
				assign_device_to_player(device_id, player_id)
				break
		controller_connected.emit(device_id)
	else:
		if device_id in device_to_player:
			var player_id: int = device_to_player[device_id]
			device_to_player.erase(device_id)
			player_to_device.erase(player_id)
		controller_disconnected.emit(device_id)


func assign_device_to_player(device_id: int, player_id: int) -> void:
	device_to_player[device_id] = player_id
	player_to_device[player_id] = device_id


func get_movement_vector(player_id: int) -> Vector2:
	var device_id: int = player_to_device.get(player_id, KEYBOARD_MOUSE_DEVICE)

	if device_id == KEYBOARD_MOUSE_DEVICE:
		return Input.get_vector("move_left", "move_right", "move_up", "move_down")
	else:
		var x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		var vec := Vector2(x, y)
		if vec.length() < 0.2:
			return Vector2.ZERO
		return vec.normalized() * ((vec.length() - 0.2) / 0.8)


## FIX: il codice originale chiamava player_position.get_viewport() ma
## player_position è Vector2 → Parser Error.
## get_viewport() va chiamato su self (InputManager è un Node autoload).
## In split screen (SubViewports) get_camera_2d() può essere null:
## in quel caso convertiamo le coordinate via canvas_transform.
func get_aim_vector(player_id: int, player_position: Vector2) -> Vector2:
	var device_id: int = player_to_device.get(player_id, KEYBOARD_MOUSE_DEVICE)

	if device_id == KEYBOARD_MOUSE_DEVICE:
		# FIX: usa get_viewport() su self (Node), non su player_position (Vector2)
		var vp := get_viewport()
		var mouse_world: Vector2

		var active_cam := vp.get_camera_2d()
		if active_cam:
			# Single player: camera presente nel main viewport
			mouse_world = active_cam.get_global_mouse_position()
		else:
			# Split screen: le camere sono nei SubViewport
			# Convertiamo le coordinate schermo → world manualmente
			var mouse_screen := vp.get_mouse_position()
			mouse_world = vp.canvas_transform.affine_inverse() * mouse_screen

		var dir := mouse_world - player_position
		if dir.length_squared() < 0.01:
			return Vector2.RIGHT
		return dir.normalized()
	else:
		var x := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
		var y := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
		var vec := Vector2(x, y)
		if vec.length() < 0.3:
			return Vector2.RIGHT
		return vec.normalized()


func is_shooting(player_id: int) -> bool:
	var device_id: int = player_to_device.get(player_id, KEYBOARD_MOUSE_DEVICE)

	if device_id == KEYBOARD_MOUSE_DEVICE:
		return Input.is_action_pressed("shoot")
	else:
		return Input.is_joy_button_pressed(device_id, JOY_BUTTON_RIGHT_SHOULDER) \
			or Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5


func is_pause_pressed(player_id: int) -> bool:
	var device_id: int = player_to_device.get(player_id, KEYBOARD_MOUSE_DEVICE)

	if device_id == KEYBOARD_MOUSE_DEVICE:
		return Input.is_action_just_pressed("pause")
	else:
		return Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)


func get_connected_player_count() -> int:
	return player_to_device.size()
