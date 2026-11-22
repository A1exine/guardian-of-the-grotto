extends Camera2D

@export var player: Node2D
@export_range(0.0, 0.5) var follow_strength: float = 0.08
@export var smooth_speed: float = 4.0

var center_position: Vector2

func _ready() -> void:
	center_position = global_position

func _process(delta: float) -> void:
	if not player:
		return
	var offset_from_center: Vector2 = (player.global_position - center_position) * follow_strength
	var target_position: Vector2 = center_position + offset_from_center
	
	global_position = global_position.lerp(target_position, smooth_speed * delta)
