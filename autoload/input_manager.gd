extends Node
## InputManager - Gestisce input per multiplayer locale
## Supporta keyboard+mouse (P1) e controller (P1-P4)

signal controller_connected(device_id: int)
signal controller_disconnected(device_id: int)

# Mapping dispositivi ai giocatori
var device_to_player: Dictionary = {}
var player_to_device: Dictionary = {}

# Costanti per input
const KEYBOARD_MOUSE_DEVICE := -1


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Keyboard/Mouse sempre assegnato a P1 di default
	assign_device_to_player(KEYBOARD_MOUSE_DEVICE, 0)
	# Assegna controller già connessi
	for device_id in Input.get_connected_joypads():
		_on_joy_connection_changed(device_id, true)


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		# Trova il primo slot giocatore libero
		for player_id in range(4):
			if player_id not in player_to_device.values() or player_id == 0:
				if player_id == 0 and KEYBOARD_MOUSE_DEVICE in device_to_player:
					# P1 ha già keyboard, assegna controller a P2+
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
		# Keyboard input
		return Input.get_vector("move_left", "move_right", "move_up", "move_down")
	else:
		# Controller input
		var x := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		var vec := Vector2(x, y)
		# Deadzone
		if vec.length() < 0.2:
			return Vector2.ZERO
		return vec.normalized() * ((vec.length() - 0.2) / 0.8)


func get_aim_vector(player_id: int, player_position: Vector2) -> Vector2:
	var device_id: int = player_to_device.get(player_id, KEYBOARD_MOUSE_DEVICE)
	
	if device_id == KEYBOARD_MOUSE_DEVICE:
		# Mouse aim
		var mouse_pos := player_position.get_viewport().get_mouse_position()
		# Converti in coordinate world se necessario
		var viewport := player_position.get_viewport()
		if viewport:
			var camera := viewport.get_camera_2d()
			if camera:
				mouse_pos = camera.get_global_mouse_position()
		return (mouse_pos - player_position).normalized()
	else:
		# Right stick aim
		var x := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
		var y := Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
		var vec := Vector2(x, y)
		if vec.length() < 0.3:
			return Vector2.RIGHT  # Default aim direction
		return vec.normalized()


func is_shooting(player_id: int) -> bool:
	var device_id: int = player_to_device.get(player_id, KEYBOARD_MOUSE_DEVICE)
	
	if device_id == KEYBOARD_MOUSE_DEVICE:
		return Input.is_action_pressed("shoot")
	else:
		# Right trigger o right bumper
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
