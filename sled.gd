extends CharacterBody3D
class_name Sled

@export var camera: Camera3D
@export var extra_resistance_on_up_slope: Curve
@export var meshes: Node3D
@export var v_aoa_lift_curve: Curve
@export var noise: Noise
@export var slide_audio : AudioStreamPlayer3D
var slide_audio_tweening := false

var _previous_global_position : Vector3
var _previous_velocity : Vector3
var _previous_floor_velocity : Vector3
var _previous_air_velocity : Vector3

const SPEED = 20.0
var current_speed := 0.0
var current_direction : Vector3
const JUMP_VELOCITY = 15.0

# grinding
var grinding : bool:
	get: return rail != null
var rail : Path3D = null 
var _current_curve_offset := 0.0
var _current_grind_direction := 1.0
var grind_balance := 0.0
const GRIND_MAX_ANGLE = PI * .4
const GRINDING_DIFFICULTY = 3.5 # this might could be speed/location/difficulty sensitive in the future

# jumpin
var _jump_count = 0 # 1 = jumped, 2 = double_jumped
var _hasnt_jumped: bool:
	get: return _jump_count == 0
var _can_double_jump: bool:
	get: return false # _jump_count == 1 # double jump disabled rn
var last_time_jump_pressed := -100.0
var last_time_left_ground_not_jump := -100.0

#tubing
var in_duct := false

@onready var checkpoint_transform : Transform3D = global_transform
@onready var checkpoint_position : Vector3 = global_position

const COYOTE = .3
const PRE_JUMP = .2
const LIFT = 20.0

var _was_on_floor := false

# Get the gravity from the project settings to be synced with RigidBody nodes.
var GRAVITY := 30.0
var HOLD_JUMP_GRAVITY := 20.0
var calculated_gravity : float:
	get: # gravity is decreased when holding jump and moving up
		return HOLD_JUMP_GRAVITY if (Input.is_action_pressed("ui_accept") and velocity.y > 0.0) else GRAVITY

var v_input_speed_factor := 5.0
@onready var max_speed := SPEED * v_input_speed_factor

var acceleration := Vector3.ZERO

func ready():
	#acceleration = 5.0 * -basis.z
	#print("max_speed: " + str(max_speed))
	pass
	
func _physics_process(delta):
	#print(get_real_velocity().length())
	
	if(in_duct):
		return
	
	var h_input := Input.get_axis("move_l", "move_r")
	var v_input := Input.get_axis("move_d", "move_u")
	
	# grinding
	if(grinding):
		_current_curve_offset += _current_grind_direction * velocity.length() * delta
		
		if(_current_curve_offset >= rail.curve.get_baked_length() || _current_curve_offset <= 0):
			last_time_left_ground_not_jump = Ding.time
			exit_grind()
		else:
			grind_balance += noise.get_noise_1d(Ding.time) * delta * GRINDING_DIFFICULTY
			grind_balance += h_input * 4.0 * delta
			
			global_transform = rail.global_transform * rail.curve.sample_baked_with_rotation(_current_curve_offset)
			
			if(_current_grind_direction < 0):
				rotate_y(PI)
			
			rotate_object_local(-basis.z, GRIND_MAX_ANGLE * grind_balance * _current_grind_direction)
			
			if(abs(grind_balance) >= 1.0):
				exit_grind()
				print("failed grind")

			return
		
	# landing and taking off
	if(!_was_on_floor and is_on_floor()):
		_landed()
	else: if(_was_on_floor and !is_on_floor()):
		_took_off()

	# stuff
	var speed = SPEED
	acceleration = Vector3.DOWN * calculated_gravity
	
	if is_on_floor():
		# slope-based movement
		var drain_slope = get_drain_slope()
		if(get_projected_slope().y > 0): # moving up, add extra resistance
			drain_slope *= 1.0 + extra_resistance_on_up_slope.sample(get_floor_angle()) * 5.0
		DebugDraw3D.draw_arrow(global_position, global_position + drain_slope * 10.0, Color.CADET_BLUE, .2)
		acceleration += drain_slope * delta * GRAVITY * sin(get_floor_angle()) * 25.0
		
		## todo: friction
		#acceleration += drain_slope * delta * GRAVITY * sin(get_floor_angle()) * .25
		
		#if(!down.is_zero_approx()):
			#meshes.look_at(lerp(global_position + velocity, global_position + velocity, .5), Vector3.UP)
		#else:
		meshes.look_at(global_position + velocity, Vector3.UP)
	else:
		if(!velocity.is_zero_approx()):
			meshes.look_at(global_position + velocity, Vector3.UP)
		#meshes.rotate(basis.x, -v_input * delta)
		
		# todo: bail at extreme angles
		
		#var vertical_aoa = velocity.signed_angle_to(-meshes.basis.z, basis.x)
		#var horizontal_aoa = velocity.signed_angle_to(-meshes.basis.z, basis.x)
#
		#print("v: " + str(rad_to_deg(vertical_aoa)))
		#vertical_aoa = clamp(rad_to_deg(vertical_aoa), 0.0, 80.0)
#
		#velocity.y += v_aoa_lift_curve.sample((vertical_aoa) / 80.0) * delta * LIFT
		#print("v: " + str(v_aoa_lift_curve.sample((vertical_aoa) / 80.0)))

	#speed += v_input * v_input_speed_factor
	#current_speed = lerp(current_speed, speed, 2.0 * delta)
	
	var camRight = camera.global_basis.x
	camRight.y = 0
	camRight = camRight.normalized()

	#var new_velocity = -basis.z * current_speed
	#new_velocity.y = velocity.y
	#velocity = velocity.lerp(new_velocity, 2.0 * delta)

	velocity += acceleration * delta
	
	if is_on_floor():
		velocity = velocity.lerp(Vector3.ZERO, .001) # friction
		
		if(!slide_audio_tweening):
			slide_audio.volume_db = -30 + velocity.length()
	
	if is_on_floor():
		var max_speed = 50
		if(velocity.x * velocity.x + velocity.z * velocity.z > max_speed * max_speed):
			var velocity_y = velocity.y
			velocity.y = 0
			velocity = velocity.normalized() * max_speed
			velocity.y = velocity_y
		
	var turn = -h_input * 1.5 #if is_on_floor() else .5
	if(v_input < 0.0):
		turn *= 1.5
	
	if(h_input != 0.0):
		rotate(Vector3.UP, turn * delta)
		velocity = velocity.rotated(Vector3.UP, turn * delta)
			
	get_node("Node3D/Rider").position.x = lerp(get_node("Node3D/Rider").position.x, -turn * .2, 12.0 * delta)
	get_node("Node3D/Rider").position.z = lerp(get_node("Node3D/Rider").position.z, -v_input * .8, 12.0 * delta)
	get_node("Node3D/Box").rotation.z = lerp(get_node("Node3D/Box").rotation.z, turn * .3, 15.0 * delta)
	
	# record last frame stuff
	_previous_velocity = velocity
	
	if is_on_floor():
		_previous_floor_velocity = get_real_velocity()
	else:
		_previous_air_velocity = get_real_velocity()
	
	_was_on_floor = is_on_floor()
		
	# FINALLY SLIDE
	move_and_slide()	
	#DebugDraw3D.draw_arrow(global_position, global_position + velocity, Color.BLUE, .1)
	#DebugDraw3D.draw_arrow(global_position, global_position + basis.z, Color.BLUE_VIOLET, .1)
	#DebugDraw3D.draw_arrow(global_position, global_position + -meshes.basis.z, Color.RED, .1)

# events
func _landed():
	print("landed")
	_jump_count = 0
	slide_audio.play()
	slide_audio.volume_db = 80.0
	slide_audio_tweening = true
	var tween = slide_audio.create_tween()
	tween.tween_property(slide_audio, "volume_db", -10, .1) #.set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): slide_audio_tweening = false)
	
	if(Ding.time_since(last_time_jump_pressed) <= PRE_JUMP):
		print("pre-jump")
		_jump()
	else:		
		# maintain momentum!
		#var momentum = get_drain_slope() * _previous_velocity.length() * sin(get_floor_angle())
		#if(momentum.length_squared() > velocity.length_squared()):
			#print("momentum maintained")
			#velocity = momentum
		#if(_previous_air_velocity.length_squared() > velocity.length_squared()):
			#print("momentum maintained")
			#velocity = get_drain_slope() * _previous_air_velocity.length()
			
		var momentum = velocity.lerp(get_drain_slope() * _previous_air_velocity.length(), .2)
		if(momentum.length_squared() > velocity.length_squared()):
			print("momentum maintained")
			velocity = momentum
			# todo: need to check dot product with velocity direction and down slope

func _took_off():
	slide_audio.stop()
	
	if(_hasnt_jumped):
		last_time_left_ground_not_jump = Ding.time

func _jump():
	last_time_jump_pressed = Ding.time
	
	if(grinding || is_on_floor() || Ding.time_since(last_time_left_ground_not_jump) <= COYOTE):
		if(grinding): exit_grind()
		velocity.y = JUMP_VELOCITY
		_jump_count = 1 # has jumped once
		if(Ding.time_since(last_time_left_ground_not_jump) <= COYOTE):
			print("coyote")
	else:
		if(_can_double_jump):
			velocity.y = max(JUMP_VELOCITY * .8, velocity.y + JUMP_VELOCITY * .8)
			_jump_count = 2

func enter_grind(path: Path3D, offset: float, direction:float):
	rail = path
	_current_curve_offset = offset
	_current_grind_direction = direction
	grind_balance = 0.0
	_jump_count = 0
	
	velocity *= 1.5
	
	meshes.rotation = Vector3.ZERO
	get_node("Node3D/Rider").position = Vector3.ZERO
	get_node("Node3D/Box").rotation = Vector3.ZERO

func exit_grind():
	var transfor = rail.global_transform * rail.curve.sample_baked_with_rotation(_current_curve_offset)
	velocity = -basis.z * velocity.length() + Vector3.UP * 2.0
	#basis.z = transfor.basis.z * _current_grind_direction
	#basis.y = transfor.basis.y * _current_grind_direction
	#look_at(position, position + velocity)
		
	rail = null
	#global_basis.y = Vector3.UP
	#velocity = -transfor.basis.z.normalized() * velocity.length() * _current_grind_direction

func reset():
	velocity = Vector3.ZERO
	global_transform = checkpoint_transform
	#global_position = checkpoint_position

func _input(_event):
	if Input.is_action_just_pressed("ui_accept"):
		_jump()
		
	if Input.is_key_pressed(KEY_R):
		reset()

# helpers
func get_drain_slope() -> Vector3:
	if(!is_on_floor()):
		printerr("don't call drain slope when not on ground silly")
		return Vector3.DOWN

	var down = get_floor_normal()
	down.y = 0
	return Plane(get_floor_normal()).project(down).normalized()

func get_projected_slope() -> Vector3:
	if(!is_on_floor()):
		printerr("don't call drain slope when not on ground silly")
		return Vector3.DOWN
		
	return Plane(get_floor_normal()).project(velocity).normalized()
