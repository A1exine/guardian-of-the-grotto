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
const JUMP_RELEASE_MULTIPLIER: float = 0.5

const BASE_GRAVITY_NORMAL: float = 1400.0
const BASE_GRAVITY_WALL: float = 250.0
const BASE_MAX_FALL_SPEED: float = 1100.0
const BASE_WALL_SLIDE_SPEED: float = 180.0
const BASE_WALL_JUMP_PUSH_FORCE: float = 180.0

const WALL_CLIMB_SPEED: float = -220.0
const WALL_CONTACT_COYOTE_TIME: float = 0.2
const WALL_JUMP_LOCK_TIME: float = 0.05
const WALL_JUMP_HEIGHT: float = -1000.0

const FAST_FALL_MULTIPLIER: float = 3.0
const MAX_FAST_FALL_SPEED: float = 3400.0
const PLUNGE_START_SPEED: float = 1250.0

const PLUNGE_MIN_IMPACT_VY: float = 1550.0
const PLUNGE_LAND_GLIDE_SPEED: float = 400.0
const PLUNGE_MICRO_HOP_VELOCITY: float = -400.0

const MAX_CHARGETIME: float = 0.5
const CHARGE_JUMP_MULTIPLIER: float = 1.35

const DASH_SPEED = 1000.0
const DASH_ARC_VELOCITY = -300.0
const AIR_DASH_ARC_VELOCITY = -140.0

# ==============================================================================
# EXPORTED TUNING VARIABLES
# ==============================================================================

@export var jump_height: float = -950.0
@export var current_speed: float = 350.0
@export var max_speed: float = 1150.0
@export var gravity_normal: float = 2400.0
@export var gravity_wall: float = 250.0
@export var max_fall_speed: float = 1400.0
@export var max_wall_slide_speed: float = 180.0
@export var wall_jump_push_force: float = 180.0
@export var fall_multiplier: float = 1.55

@export var acceleration: float = 2100.0
@export var deceleration: float = 1750.0
@export var air_acceleration: float = 1500.0
@export var air_deceleration: float = 850.0


# ==============================================================================
# STATE VARIABLES
# ==============================================================================
var trail_timer: float = 0.0 # TEMPORARY - ONLY FOR REDUCING EYE STRAIN ON PROTOTYPE
var wiggle_time: float = 0.0
var was_on_floor: bool = false
var coyote_time_activated: bool = false
var wall_contact_coyote: float = 0.0
var wall_jump_lock: float = 0.0
var wall_normal_x: float = 0.0
var look_dir_x: int = 1

var is_tweening_scale: bool = false
var scale_tween: Tween

var is_plunging: bool = false
var is_running: bool = false
var is_jumping_windup: bool = false

var has_jumped: bool = false
var has_plunged: bool = false

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
	handle_jumps()
	handle_verticle_movement(delta, x_input)
	
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
	
	# Floor vs. Air Coyote State
	if is_on_floor() and velocity.y >= 0.0:
		has_air_dashed = false
		has_jumped = false
		has_plunged = false
		coyote_time_activated = false
		wall_contact_coyote = 0.0
		PlungeLockTimer.stop()
	else:
		if CoyoteTimer.is_stopped() and !coyote_time_activated and not has_jumped:
			CoyoteTimer.start()
			coyote_time_activated = true
		if is_on_wall():
			has_air_dashed = false
			has_plunged = false
			CoyoteTimer.stop() # Prevents brushing a wall after jumping from granting a coyote double-jump
			coyote_time_activated = true
			if velocity.y >= 0.0:
				has_jumped = false
			wall_normal_x = get_wall_normal().x
			wall_contact_coyote = WALL_CONTACT_COYOTE_TIME
			PlungeLockTimer.stop()
		elif wall_contact_coyote > 0.0:
			wall_contact_coyote -= delta
		
func update_facing_direction(x_input: float) -> void:
	if x_input != 0.0 and wall_jump_lock <= 0.0 and not is_dashing:
		look_dir_x = sign(x_input)

func handle_dash() -> void:
	
	is_jumping_windup = false
	
	if Input.is_action_just_pressed("dash") and can_dash and (is_on_floor() or not has_air_dashed):
		var was_grounded: bool = is_on_floor()
		if not was_grounded:
			has_air_dashed = true
			has_plunged = false
		
		is_dashing = true
		is_plunging = false
		can_dash = false
		
		if was_grounded and is_running:
			velocity.y = DASH_ARC_VELOCITY
			coyote_time_activated = true
			CoyoteTimer.stop()
		else:
			velocity.y = AIR_DASH_ARC_VELOCITY
		
		if is_on_wall():
			wall_normal_x = get_wall_normal().x
			look_dir_x = sign(wall_normal_x)
			wall_contact_coyote = 0.0
		elif wall_contact_coyote > 0.0:
			look_dir_x = sign(wall_normal_x)
			wall_contact_coyote = 0.0
		
		velocity.x = look_dir_x * (current_speed + 250.0)
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

func handle_jumps() -> void:
	if Input.is_action_just_pressed("jump") and JumpBufferTimer.is_stopped():
		JumpBufferTimer.start()
			
	if JumpBufferTimer.is_stopped() or is_jumping_windup:
		return
	
	# 1. Normal Floor / Coyote Jump
	if (!CoyoteTimer.is_stopped() or is_on_floor()) and not has_jumped:
		is_dashing = false
		has_jumped = true
		has_plunged = false
		
		if is_running:
			start_charged_jump()
		else:
			apply_squash_stretch(Vector2(0.72, 1.32))
			velocity.y = jump_height
			PlungeLockTimer.start(0.08)
		
		JumpBufferTimer.stop()
		CoyoteTimer.stop()
		coyote_time_activated = true
	
	# 2. Wall Jump
	elif wall_contact_coyote > 0.0:
		velocity.y = WALL_JUMP_HEIGHT
		velocity.x = wall_normal_x * wall_jump_push_force
		look_dir_x = sign(wall_normal_x)
		apply_squash_stretch(Vector2(0.70, 1.35))
		wall_jump_lock = WALL_JUMP_LOCK_TIME
		wall_contact_coyote = 0.0
		has_plunged = false
		JumpBufferTimer.stop()

func handle_horizontal_movement(delta: float, x_input: float) -> void:
	
	var speed_multiplier: float = 1.25 if is_boomerang_out else 1.0
	var jump_multiplier: float = 1.15 if is_boomerang_out else 1.0

	is_running = Input.is_action_pressed("run")
	current_speed = (RUN_SPEED if is_running else BASE_SPEED) * speed_multiplier
	jump_height = (RUN_JUMP_HEIGHT if is_running else BASE_JUMP) * jump_multiplier
	
	if is_dashing:
		velocity.x = look_dir_x * (current_speed + 250.0)
		return
	
	#Acceleration
	var accel: float = acceleration if is_on_floor() else air_acceleration
	var decel: float = deceleration if is_on_floor() else air_deceleration
	
	if is_boomerang_out:
		accel *= 1.3
		decel *= 1.6
	
	if is_running:
		accel *= 1.75
		if is_on_floor():
			decel *= 0.8
				
		
	if wall_jump_lock > 0.0:
		velocity.x = move_toward(velocity.x, x_input * current_speed, (accel * 0.25) * delta)
	elif x_input != 0.0:
		var turn_boost: float = 2.2 if sign(x_input) != sign(velocity.x) and velocity.x != 0.0 else 1.0
		velocity.x = move_toward(velocity.x, x_input * current_speed, accel * turn_boost * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.x = clamp(velocity.x, -max_speed, max_speed)
	velocity.x = clamp(velocity.x, -max_speed, max_speed)
	
func handle_verticle_movement(delta: float, x_input: float) -> void:
	if is_on_floor():
		return
		
	var can_start_plunge: bool = (
		Input.is_action_just_pressed("move_down") 
		and not has_plunged 
		and PlungeLockTimer.is_stopped()
	)
		
	if is_dashing:
		if can_start_plunge or is_plunging:
			apply_plunge(delta)
			return
		if velocity.y == 0.0:
			return
	
	# Variable Jump and Ceiling Bonk
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_RELEASE_MULTIPLIER
	if is_on_ceiling() and velocity.y < 0:
		velocity.y = 0.0
		
	# Vertical air state: Wall slide / Plunge / Normal fall
	if is_on_wall() and velocity.y > 0.0 and x_input != 0.0:
		is_plunging = false
		look_dir_x = -sign(wall_normal_x)
		velocity.y = min(velocity.y + gravity_wall * delta, max_wall_slide_speed)
	elif (can_start_plunge or is_plunging) and not is_on_wall():
		apply_plunge(delta)
	else:
		var boomerang_grav_mult: float = 1.10 if is_boomerang_out else 1.0
		var active_gravity: float = gravity_normal * boomerang_grav_mult * (fall_multiplier if velocity.y > 0.0 else 1.0)
		velocity.y = min(velocity.y + active_gravity * delta, max_fall_speed)

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
	if is_on_wall() and velocity.y > -120.0 and velocity.y < -20.0 and abs(velocity.x) > 15.0:
		var ledge_hop_vy: float = jump_height / 2.2
		if $Left_LedgeHop.is_colliding() and !$Left_LedgeHop2.is_colliding() and velocity.x < 0:
			velocity.y = min(velocity.y, ledge_hop_vy)
		if $Right_LedgeHop.is_colliding() and !$Right_LedgeHop2.is_colliding() and velocity.x > 0:
			velocity.y = min(velocity.y, ledge_hop_vy)


func start_charged_jump() -> void:
	has_jumped = true
	velocity.y = jump_height
	PlungeLockTimer.start(0.08)
	apply_squash_stretch(Vector2(0.70, 1.35) * mass_scale)

func apply_plunge(delta) -> void:
	is_plunging = true
	has_plunged = true
	is_jumping_windup = false
	is_dashing = false
	if velocity.y < PLUNGE_START_SPEED:
		velocity.y = PLUNGE_START_SPEED
		
	var plunge_gravity: float = gravity_normal * fall_multiplier * FAST_FALL_MULTIPLIER
	velocity.y = min(velocity.y + plunge_gravity * delta, MAX_FAST_FALL_SPEED)
	visual.scale = visual.scale.lerp(Vector2(0.75, 1.30), 12.0 * delta)
	
func handle_landing_effects(was_grounded: bool, pre_land_vy: float, x_input: float) -> void:
	if is_on_floor() and not was_grounded:
		var impact: float = clamp((pre_land_vy - 450.0) / 1800.0, 0.0, 1.0)
		var squash_x: float = lerp(1.12, 1.75, impact)
		var squash_y: float = lerp(0.88, 0.45, impact)
		apply_squash_stretch(Vector2(squash_x, squash_y))
		
		# Reset landing flags immediately so nothing blocks an instant jump
		has_air_dashed = false
		has_jumped = false
		has_plunged = false
		coyote_time_activated = false
		PlungeLockTimer.stop()
		
		if is_plunging:
			is_plunging = false
			has_plunged = true # Blocks S-spam during the tiny hop
			
			if pre_land_vy > PLUNGE_MIN_IMPACT_VY:
				var glide_dir: float = sign(x_input) if x_input != 0.0 else look_dir_x
				velocity.x = glide_dir * PLUNGE_LAND_GLIDE_SPEED
				get_tree().call_group("camera", "apply_shake", 5.0)
			else:
				get_tree().call_group("camera", "apply_shake", 3.0)
			
			# If Jump was buffered before landing, jump immediately instead of doing the micro-hop
			if not JumpBufferTimer.is_stopped():
				JumpBufferTimer.stop()
				has_jumped = true
				has_plunged = false
				coyote_time_activated = true
				velocity.y = jump_height
				PlungeLockTimer.start(0.08)
				apply_squash_stretch(Vector2(0.72, 1.32) * mass_scale)
				return
			
			# Otherwise do the tiny visual/physical bounce
			velocity.y = PLUNGE_MICRO_HOP_VELOCITY
			play_visual_slime_bounce()
			return
		
		# Normal landing (not from a plunge): fire any buffered jump on frame 1
		if not JumpBufferTimer.is_stopped():
			JumpBufferTimer.stop()
			CoyoteTimer.stop()
			has_jumped = true
			coyote_time_activated = true
			if is_running:
				start_charged_jump()
			else:
				apply_squash_stretch(Vector2(0.72, 1.32) * mass_scale)
				velocity.y = jump_height
				PlungeLockTimer.start(0.08)

func play_visual_slime_bounce() -> void:
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	is_tweening_scale = true
	var base := Vector2.ONE * mass_scale
	scale_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# 1. Subtle impact squash
	scale_tween.tween_property(visual, "scale", Vector2(1.35, 0.70) * mass_scale, 0.05)
	# 2. Gentle upward stretch
	scale_tween.tween_property(visual, "scale", Vector2(0.86, 1.18) * mass_scale, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 3. Quick settle
	scale_tween.tween_property(visual, "scale", base, 0.08)
	scale_tween.tween_callback(func(): is_tweening_scale = false)

func apply_squash_stretch(new_scale: Vector2) -> void:
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	is_tweening_scale = false
	visual.scale = new_scale

func update_squash_and_stretch(delta: float) -> void:
	var target_scale: Vector2 = Vector2.ONE * mass_scale
	
	if is_on_floor() and get_x_input() == 0.0 and abs(velocity.x) > 150.0 and not is_dashing:
		target_scale = Vector2(1.16, 0.86) * mass_scale
	
	var speed_ratio: float = clamp(abs(velocity.x) / RUN_SPEED, 0.0, 1.2)
	if speed_ratio > 0.05 and not is_dashing and not is_plunging:
		wiggle_time += delta * lerp(5.0, 15.0, speed_ratio)
		var wave: float = sin(wiggle_time) * 0.12 * speed_ratio
		target_scale *= Vector2(1.0 + wave, 1.0 - wave)
	else:
		wiggle_time = 0.0
	
	if not is_tweening_scale:
		var scale_weight: float = 1.0 - exp(-16.0 * delta)
		visual.scale = visual.scale.lerp(target_scale, scale_weight)
	
	var max_lean_rad: float = deg_to_rad(5.0)
	var target_rotation: float = clamp(velocity.x / RUN_SPEED, -1.2, 1.2) * max_lean_rad
	if is_plunging:
		target_rotation = 0.0
		
	var rot_weight: float = 1.0 - exp(-14.0 * delta)
	visual.rotation = lerp_angle(visual.rotation, target_rotation, rot_weight)
	
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
	ghost.rotation = visual.rotation
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
	mass_scale = 0.75 if out else 1.0
	$CollisionShape2D.scale = Vector2.ONE * mass_scale
