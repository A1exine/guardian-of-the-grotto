extends Camera2D

@export var player: Node2D
@export_range(0.0, 0.5) var follow_strength: float = 0.08
@export var smooth_speed: float = 4.0

var center_position: Vector2

var shake_strength: float = 0.0
var shake_decay: float = 18.0

func _ready() -> void:
	center_position = global_position
	add_to_group("camera")

func _process(delta: float) -> void:
	if not player:
		return
	var offset_from_center: Vector2 = (player.global_position - center_position) * follow_strength
	var target_position: Vector2 = center_position + offset_from_center
	
	global_position = global_position.lerp(target_position, smooth_speed * delta)
	
	if shake_strength > 0.0:
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		offset = Vector2.ZERO

func apply_shake(intensity: float) -> void:
	shake_strength = max(shake_strength, intensity)
