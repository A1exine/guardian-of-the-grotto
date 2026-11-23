extends CharacterBody2D
#region VARIABLES
# ==============================================================================
# NODES & CONSTANTS
# ==============================================================================
@onready var CoyoteTimer: Timer = $CoyoteTimer
@onready var JumpBufferTimer: Timer = $JumpBufferTimer
@onready var PlungeLockTimer: Timer = $PlungeLockTimer
@onready var DashCoolDownTimer: Timer = $DashCoolDownTimer

@onready var visual: ColorRect = $ColorRect # Change to Sprite2D when assets come in!
@onready var base_color: Color = visual.color

const BASE_SPEED: float = 400.0
const RUN_SPEED: float = 800.0

const RUN_JUMP_HEIGHT: float = -950.0
const BASE_JUMP: float = -850.0
const JUMP_RELEASE_MULTIPLIER: float = 0.72

const BASE_GRAVITY_NORMAL: float = 1400.0
const BASE_GRAVITY_WALL: float = 250.0
const BASE_MAX_FALL_SPEED: float = 1100.0
const BASE_WALL_SLIDE_SPEED: float = 180.0
const BASE_WALL_JUMP_PUSH_FORCE: float = 180.0

const WALL_CLIMB_SPEED: float = -220.0
const WALL_CONTACT_COYOTE_TIME: float = 0.2
const WALL_JUMP_LOCK_TIME: float = 0.05
const WALL_JUMP_HEIGHT: float = -1000.0

const FAST_FALL_MULTIPLIER: float = 2.0
const MAX_FAST_FALL_SPEED: float = 2400.0
const PLUNGE_START_SPEED: float = 800.0

const PLUNGE_MIN_IMPACT_VY: float = 900.0
const PLUNGE_LAND_GLIDE_SPEED: float = 400.0

const MAX_CHARGETIME: float = 0.5
const CHARGE_JUMP_MULTIPLIER: float = 1.35

const DASH_SPEED = 1000.0
const DASH_ARC_VELOCITY = -500.0

# ==============================================================================
# EXPORTED TUNING VARIABLES
# ==============================================================================
@export var jump_height: float = -950.0
@export var current_speed: float = 350.0
@export var max_speed: float = 950.0
@export var gravity_normal: float = 2200.0
@export var gravity_wall: float = 250.0
@export var max_fall_speed: float = 1400.0
@export var max_wall_slide_speed: float = 180.0
@export var wall_jump_push_force: float = 180.0
@export var fall_multiplier: float = 1.5

@export var acceleration: float = 1600.0
@export var deceleration: float = 1200.0
@export var air_acceleration: float = 1200.0
@export var air_deceleration: float = 600.0


# ==============================================================================
# STATE VARIABLES
# ==============================================================================
var trail_timer: float = 0.0 # TEMPORARY - ONLY FOR REDUCING EYE STRAIN ON PROTOTYPE
var was_on_floor: bool = false
var coyote_time_activated: bool = false
var wall_contact_coyote: float = 0.0
var wall_jump_lock: float = 0.0
var wall_normal_x: float = 0.0
var look_dir_x: int = 1


var is_charging: bool = false
var charge_amount: float = 0.0

var is_dashing: bool = false
var can_dash: bool = true
var has_air_dashed: bool = false

var is_boomerang_out: bool = false
var mass_scale: float = 1.0

#endregion

func _physics_process(delta: float) -> void:
	
	#boomerang test
	if Input.is_action_just_pressed("throw_recall"): # Left Click
		set_boomerang_out(not is_boomerang_out)
	
	var x_input: float = get_x_input()
	
	update_timers(delta)
	update_facing_direction(x_input)
	
	handle_horizontal_movement(delta, x_input)
	handle_dash()
	handle_verticle_movement(delta, x_input)
	handle_jumps()
	handle_corner_correction()
	
	var pre_land_vy := velocity.y
	was_on_floor = is_on_floor()
	move_and_slide()
	
	handle_landing_effects(was_on_floor, pre_land_vy, x_input)
	update_squash_and_stretch(delta)
	
func get_x_input() -> float:
	return Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	
func update_timers(delta) -> void:
	if wall_jump_lock > 0.0:
			wall_jump_lock -= delta
	
	#Floor vs. Air Coyote State
	if is_on_floor():
		has_air_dashed = false
		coyote_time_activated = false
		wall_contact_coyote = 0.0
	else:
		if CoyoteTimer.is_stopped() and !coyote_time_activated:
			CoyoteTimer.start()
			coyote_time_activated = true
		if is_on_wall():
			has_air_dashed = false
			wall_normal_x = get_wall_normal().x
			wall_contact_coyote = WALL_CONTACT_COYOTE_TIME
		elif wall_contact_coyote > 0.0:
			wall_contact_coyote -= delta
		
func update_facing_direction(x_input: float) -> void:
	if x_input != 0.0 and wall_jump_lock <= 0.0 and not is_dashing:
		look_dir_x = sign(x_input)

func handle_dash() -> void:
	if Input.is_action_just_pressed("dash") and can_dash and (is_on_floor() or not has_air_dashed):
		if not is_on_floor():
			has_air_dashed = true
		is_dashing = true
		can_dash = false
		velocity.y = DASH_ARC_VELOCITY
		
		if is_on_wall():
			wall_normal_x = get_wall_normal().x
			look_dir_x = sign(wall_normal_x)
			wall_contact_coyote = 0.0
		elif wall_contact_coyote > 0.0:
			look_dir_x = sign(wall_normal_x)
			wall_contact_coyote = 0.0
		
		$DashTimer.start()
		$DashCoolDownTimer.start()
		apply_squash_stretch(Vector2(1.35, 0.70))

func _on_dash_timer_timeout() -> void:
	is_dashing = false
	
	var x_input: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if x_input == 0.0:
		velocity.x = look_dir_x * 600.0 # Slides to a stop over ~0.4s (480 / 1200 decel)
	else:
		velocity.x = clamp(velocity.x, -current_speed, current_speed)

func _on_dash_cool_down_timer_timeout() -> void:
	can_dash = true

func handle_horizontal_movement(delta: float, x_input: float) -> void:
	if is_dashing:
		velocity.x = look_dir_x * DASH_SPEED
		return
	
	var speed_multiplier: float = 1.25 if is_boomerang_out else 1.0
	var jump_multiplier: float = 1.15 if is_boomerang_out else 1.0

	var is_running: bool = Input.is_action_pressed("run")
	current_speed = (RUN_SPEED if is_running else BASE_SPEED) * speed_multiplier
	jump_height = (RUN_JUMP_HEIGHT if is_running else BASE_JUMP) * jump_multiplier
	
	#Acceleration
	var accel: float = acceleration if is_on_floor() else air_acceleration
	var decel: float = deceleration if is_on_floor() else air_deceleration
	
	if is_boomerang_out:
		accel *= 1.3
		decel *= 1.6
	
	if is_running:
			accel *= 1.75
			if is_on_floor():
				decel *= 0.80
				
		
	if wall_jump_lock > 0.0:
		velocity.x = move_toward(velocity.x, x_input * current_speed, (accel * 0.25) * delta)
	elif x_input != 0.0:
		var turn_boost: float = 1.5 if sign(x_input) != sign(velocity.x) and velocity.x != 0.0 else 1.0
		velocity.x = move_toward(velocity.x, x_input * current_speed, accel * turn_boost * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)	
		velocity.x = clamp(velocity.x, -max_speed, max_speed)
	
func handle_verticle_movement(delta: float, x_input: float) -> void:
	if is_on_floor():
		return
		
	#Variable Jump and Ceiling Bonk
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_RELEASE_MULTIPLIER
	if is_on_ceiling() and velocity.y < 0:
		velocity.y = 0.0
		
	#Verticle air state: Wall slide/plunge/normal fall
	if is_on_wall() and velocity.y > 0.0 and x_input != 0.0:
		look_dir_x = -sign(wall_normal_x)
		velocity.y = min(velocity.y + gravity_wall * delta, max_wall_slide_speed)
	elif Input.is_action_pressed("move_down") and not is_on_wall() and PlungeLockTimer.is_stopped():
		apply_plunge(delta)
	else:
		var active_gravity: float = gravity_normal * (fall_multiplier if velocity.y > 0.0 else 1.0)
		velocity.y = min(velocity.y + active_gravity * delta, max_fall_speed)
	
func apply_plunge(delta) -> void:
	is_dashing = false
	if velocity.y < PLUNGE_START_SPEED:
		velocity.y = PLUNGE_START_SPEED
		
	var plunge_gravity: float = gravity_normal * fall_multiplier * FAST_FALL_MULTIPLIER
	velocity.y = min(velocity.y + plunge_gravity * delta, MAX_FAST_FALL_SPEED)
	visual.scale = visual.scale.lerp(Vector2(0.75, 1.30), 12.0 * delta)
	
func handle_jumps() -> void:
	if Input.is_action_just_pressed("jump") and JumpBufferTimer.is_stopped():
			JumpBufferTimer.start()
			
	if JumpBufferTimer.is_stopped():
		return
	
	# Normal Floor Jump
	if !CoyoteTimer.is_stopped() or is_on_floor():
		velocity.y = jump_height
		PlungeLockTimer.start()
		apply_squash_stretch(Vector2(0.72, 1.32))
		JumpBufferTimer.stop()
		CoyoteTimer.stop()
		coyote_time_activated = true
	
	#Wall Jump
	elif wall_contact_coyote > 0.0:
		velocity.y = WALL_JUMP_HEIGHT
		velocity.x = wall_normal_x * wall_jump_push_force
		look_dir_x = sign(wall_normal_x)
		apply_squash_stretch(Vector2(0.70, 1.35))
		wall_jump_lock = WALL_JUMP_LOCK_TIME
		wall_contact_coyote = 0.0
		JumpBufferTimer.stop()

func handle_corner_correction() -> void:
	#Head Nudge
	if velocity.y < jump_height / 2.0:
		var head_collision: Array = [
			$Left_HeadNudge.is_colliding(),
			$Left_HeadNudge2.is_colliding(),
			$Right_HeadNudge.is_colliding(),
			$Right_HeadNudge2.is_colliding()
		]
		if head_collision.count(true) == 1:
			if head_collision[0]:
				global_position.x += 6.0
			if head_collision[2]:
				global_position.x -= 6.0
				
	# Ledge Hop
	if velocity.y > -120.0 and velocity.y < -20.0 and abs(velocity.x) > 15.0:
		if $Left_LedgeHop.is_colliding() and !$Left_LedgeHop2.is_colliding() and velocity.x < 0:
			velocity.y += jump_height / 3.25
		if $Right_LedgeHop.is_colliding() and !$Right_LedgeHop2.is_colliding() and velocity.x > 0:
			velocity.y += jump_height / 3.25
	
func handle_landing_effects(was_grounded: bool, pre_land_vy: float, x_input: float) -> void:
	if is_on_floor() and not was_grounded:
		var impact: float = clamp((pre_land_vy - 450.0) / 1800.0, 0.0, 1.0)
		var squash_x: float = lerp(1.08, 1.38, impact)
		var squash_y: float = lerp(0.92, 0.65, impact)
		apply_squash_stretch(Vector2(squash_x, squash_y))
		
		#Glides a little after landing
		if Input.is_action_pressed("move_down") and pre_land_vy > PLUNGE_MIN_IMPACT_VY:
			var glide_dir: float = sign(x_input) if x_input != 0.0 else look_dir_x
			velocity.x = glide_dir * PLUNGE_LAND_GLIDE_SPEED
	
func apply_squash_stretch(new_scale: Vector2) -> void:
	visual.scale = new_scale

func update_squash_and_stretch(delta) -> void:
	# Elastic recovery back to Vector2(1, 1)
	visual.scale = visual.scale.lerp(Vector2.ONE * mass_scale, 6.0 * delta)
	
	#Flashes white and cools off to show dash cooldown
	if not $DashCoolDownTimer.is_stopped():
		var progress: float = $DashCoolDownTimer.time_left / $DashCoolDownTimer.wait_time
		var flash_color = base_color.lerp(Color.WHITE, 0.5)
		visual.color = base_color.lerp(flash_color, progress)
	else:
		visual.color = base_color
	
	# TEMPORARY: Ghost trail for high-speed prototype readability
	if velocity.length() > 380.0:
		trail_timer -= delta
		if trail_timer <= 0.0:
			spawn_trail_ghost()
			trail_timer = 0.03

func spawn_trail_ghost() -> void: #TEMPORARY: Ghost trail for high-speed prototype readability
	var ghost := ColorRect.new()
	ghost.size = visual.size
	ghost.scale = visual.scale
	ghost.pivot_offset = visual.pivot_offset
	ghost.color = visual.color
	ghost.color.a = 0.35
	ghost.global_position = visual.global_position
	ghost.z_index = visual.z_index - 1
	
	get_parent().add_child(ghost)
	
	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)

#===============================================================================
# BOOMERANG AND ATTACKS
#===============================================================================
func set_boomerang_out(out: bool) -> void:
	is_boomerang_out = out
	mass_scale = 0.6 if out else 1.0
	$CollisionShape2D.scale = Vector2.ONE * mass_scale
