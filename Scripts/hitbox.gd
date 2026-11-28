class_name HitBox
extends Area2D

@export var damage: float = 40
@export var knockback_force: float = 450.0
@export var is_slam: bool = false
@export var applies_slime: bool = false

var hit_targets: Array[Node] = []

func reset_hits() -> void:
	hit_targets.clear()

func can_hit(target: Node) -> bool:
	if target in hit_targets:
		return false
	hit_targets.append(target)
	return true
