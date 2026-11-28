class_name HurtBox
extends Area2D

func _init() -> void:
	pass
	
func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if not area is HitBox:
		return
	if owner.has_method("take_damage"):
		owner.take_damage(area.damage)
