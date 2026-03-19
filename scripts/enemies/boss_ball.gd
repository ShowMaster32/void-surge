extends Area2D
## BossBall — proiettile del boss Plasma Weaver.
## Creato a codice da boss.gd. Non ha bisogno di scena .tscn propria.

var direction: Vector2 = Vector2.RIGHT
var speed:     float   = 340.0
var damage:    float   = 14.0
var _lifetime: float   = 1.4   # secondi prima di autodistruggersi

var _elapsed: float = 0.0


func _ready() -> void:
	collision_layer = 8   # layer boss projectile
	collision_mask  = 1   # colpisce player (layer 1)
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_elapsed  += delta
	if _elapsed >= _lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	if is_instance_valid(VFX):
		VFX.spawn_hit_effect(global_position, Color(1.0, 0.5, 0.1))
	queue_free()
