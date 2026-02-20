extends Camera2D
class_name PlayerCamera
## PlayerCamera - Camera che segue un player in modalità split screen
## Creata dinamicamente da SplitScreenManager, vive dentro un SubViewport
## che condivide il World2D principale.

var target: Node2D = null
var player_id: int = 0

## Velocità di smooth-follow (più alto = più reattivo)
@export var follow_speed: float = 6.0
## Zoom fisso in split screen (leggermente zoomato out rispetto al single player)
@export var split_zoom: float = 1.5


func _ready() -> void:
	zoom = Vector2(split_zoom, split_zoom)
	position_smoothing_enabled = false   # Lo gestiamo manualmente per smoothness


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	# Lerp verso la posizione del player nel World2D condiviso
	global_position = global_position.lerp(target.global_position, follow_speed * delta)
