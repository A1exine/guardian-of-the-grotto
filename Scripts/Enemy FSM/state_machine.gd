extends Node

class_name StateMachine

@export var initial_state: BaseEnemyState
var current_state: BaseEnemyState
var states: Dictionary = {}

func _ready() -> void:
	
	for child in get_children():
		if child is BaseEnemyState:
			states[child.name.to_lower()] = child
			child.state_machine = self
	
	if initial_state:
		change_state(initial_state.name.to_lower())
	
func _process(delta: float) -> void:
	if current_state:
		current_state.udpate(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_udpate(delta)

func change_state(new_state_name: String) -> void:
	if current_state:
		current_state.exit()
		
	current_state = states.get(new_state_name.to_lower())
	
	if current_state:
		current_state.enter()
