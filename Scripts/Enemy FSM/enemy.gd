class_name BaseEnemyState
extends Node2D

@export var enemy_hp: float = 50.0
@export var move_speed: float = 400.0
@export var water_steal: float = 5.0
@export var is_slimed: bool = false


func take_damage(amount: int) -> void:
	print("Damage: ", amount)

var state_machine: StateMachine

func enter():
	pass
	
func exit():
	pass

func update(delta: float):
	pass
	
func physics_udpate(delta: float):
	pass
