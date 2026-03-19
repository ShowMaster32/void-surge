extends Node
## CameraShake — Scuote tutte le Camera2D nel gruppo "game_cameras"
## Usa il modello "trauma" quadratico: shake² per curva più naturale.
##
## Uso:
##   CameraShake.light()              # colpo leggero
##   CameraShake.medium()             # esplosione media
##   CameraShake.heavy()              # boss spawn / morte
##   CameraShake.shake(0.0..1.0)      # intensità libera

const MAX_OFFSET   := Vector2(20.0, 16.0)
const MAX_ROTATION := 0.024   # radianti (~1.4°)
const DECAY        := 2.0     # trauma al secondo che decade

var _trauma: float = 0.0


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		_reset_cameras()
		return

	_trauma = maxf(_trauma - DECAY * delta, 0.0)
	var s: float = _trauma * _trauma   # quadratico

	for cam in get_tree().get_nodes_in_group("game_cameras"):
		if not is_instance_valid(cam):
			continue
		var cam2d := cam as Camera2D
		if cam2d == null or not cam2d.enabled:
			continue
		cam2d.offset = Vector2(
			randf_range(-1.0, 1.0) * MAX_OFFSET.x * s,
			randf_range(-1.0, 1.0) * MAX_OFFSET.y * s
		)
		cam2d.rotation = randf_range(-1.0, 1.0) * MAX_ROTATION * s


func _reset_cameras() -> void:
	for cam in get_tree().get_nodes_in_group("game_cameras"):
		if not is_instance_valid(cam):
			continue
		var cam2d := cam as Camera2D
		if cam2d == null:
			continue
		if cam2d.offset != Vector2.ZERO:
			cam2d.offset   = Vector2.ZERO
			cam2d.rotation = 0.0


# ── API pubblica ────────────────────────────────────────────────────────────────

func shake(intensity: float) -> void:
	## intensity: 0.0..1.0 — si accumula fino a 1.0
	_trauma = minf(_trauma + intensity, 1.0)


func light() -> void:
	shake(0.22)   # proiettile nemico, danno leggero


func medium() -> void:
	shake(0.50)   # esplosione nemico, potere speciale


func heavy() -> void:
	shake(0.82)   # boss spawn, morte del player
