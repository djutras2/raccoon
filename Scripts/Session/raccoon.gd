extends CharacterBody3D
class_name Raccoon

@export var camera: Camera3D
@export var meshes: Node3D
@export var noise: Noise

var _previous_global_position : Vector3
var _previous_velocity : Vector3
var _previous_floor_velocity : Vector3
var _previous_air_velocity : Vector3
var rotation_direction: float

const SPEED = 350.0
var current_speed := 0.0
var current_direction : Vector3
const JUMP_VELOCITY = 10.0

# grinding
var grinding : bool:
	get: return rail != null
var rail : Path3D = null 
var _current_curve_offset := 0.0
var _current_grind_direction := 1.0
var grind_balance := 0.0
const GRIND_MAX_ANGLE = PI * .4
const GRINDING_DIFFICULTY = 3.5 # this might could be speed/location/difficulty sensitive in the future

# jumping
var _jump_count = 0 # 1 = jumped, 2 = double_jumped
var _hasnt_jumped: bool:
	get: return _jump_count == 0
var _can_double_jump: bool:
	get: return false # _jump_count == 1 # double jump disabled rn
var last_time_jump_pressed := -100.0
var last_time_left_ground_not_jump := -100.0

# landing
var _slide := Vector3.ZERO

#tubing
var in_duct := false

@onready var checkpoint_transform : Transform3D = global_transform
@onready var checkpoint_position : Vector3 = global_position

const COYOTE = .3
const PRE_JUMP = .2
const LIFT = 20.0

var _was_on_floor := false

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
	if(in_duct):
		return
	
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_l", "move_r")
	input.y = Input.get_axis("move_d", "move_u")
	
	# grinding
	if(grinding):
		_current_curve_offset += _current_grind_direction * velocity.length() * delta
		
		if(_current_curve_offset >= rail.curve.get_baked_length() || _current_curve_offset <= 0):
			last_time_left_ground_not_jump = Ding.time
			exit_grind()
		else:
			grind_balance += noise.get_noise_1d(Ding.time) * delta * GRINDING_DIFFICULTY
			grind_balance += input.x * 4.0 * delta
			
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
	
	var cam_forward = -camera.global_basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized() * input.y

	var cam_right = camera.global_basis.x
	cam_right.y = 0
	cam_right = cam_right.normalized() * input.x
	
	var cam_input = (cam_forward + cam_right).normalized()
	var movement_velocity: Vector3
	var applied_velocity: Vector3
	
	if is_on_floor():
		movement_velocity = project_on_current_floor_normal(cam_input) * speed * delta
		movement_velocity.y = velocity.y
		applied_velocity = velocity.lerp(movement_velocity, delta * 10)
	else:
		movement_velocity = cam_input * speed * delta
		movement_velocity.y = velocity.y
		applied_velocity = velocity.lerp(movement_velocity, delta * 1)
	
	velocity = applied_velocity
	
	velocity += _slide * delta
	velocity += acceleration * delta
	
	# record last frame stuff
	_previous_velocity = velocity
	
	if is_on_floor():
		_slide = _slide.lerp(Vector3.ZERO, delta * 5.0)
		_previous_floor_velocity = get_real_velocity()
	else:
		_previous_air_velocity = get_real_velocity()
	
	_was_on_floor = is_on_floor()
		
	# FINALLY SLIDE
	move_and_slide()	
	
	# rotation
	if Vector2(velocity.z, velocity.x).length() > 0:
		rotation_direction = Vector2(velocity.z, velocity.x).angle()
		
	rotation.y = lerp_angle(rotation.y, rotation_direction, delta * 10)	
	meshes.scale = meshes.scale.lerp(Vector3(1, 1, 1), delta * 10)
	
	#DebugDraw3D.draw_arrow(global_position, global_position + velocity, Color.BLUE, .1)
	#DebugDraw3D.draw_arrow(global_position, global_position + basis.z, Color.BLUE_VIOLET, .1)
	#DebugDraw3D.draw_arrow(global_position, global_position + -meshes.basis.z, Color.RED, .1)

# events
func _landed():
	print("landed")
	_jump_count = 0
	
	meshes.scale = Vector3(1.25, 0.75, 1.25)

	if(Ding.time_since(last_time_jump_pressed) <= PRE_JUMP):
		print("pre-jump")
		_jump()
	else:	
		if(rad_to_deg(get_floor_angle()) >= 1.0):
			_slide = get_drain_slope() * get_floor_angle() * abs(_previous_air_velocity.y) * 50.0
		
		pass	
		# maintain momentum!
		# todo
			
		#var momentum = velocity.lerp(get_drain_slope() * _previous_air_velocity.length(), .2)
		#if(momentum.length_squared() > velocity.length_squared()):
			#print("momentum maintained")
			#velocity = momentum
			# todo: need to check dot product with velocity direction and down slope

func _took_off():	
	if(_hasnt_jumped):
		last_time_left_ground_not_jump = Ding.time

func _jump():
	last_time_jump_pressed = Ding.time
	_slide = Vector3.ZERO
	
	if(grinding || is_on_floor() || Ding.time_since(last_time_left_ground_not_jump) <= COYOTE):
		if(grinding): exit_grind()
		velocity.y = JUMP_VELOCITY
		_jump_count = 1 # has jumped once
		meshes.scale = Vector3(0.5, 1.5, 0.5)
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
func project_on_current_floor_normal(vector:Vector3) -> Vector3:
	if(!is_on_floor()):
		printerr("don't call drain slope when not on ground silly")
		return Vector3.DOWN
		
	return Plane(get_floor_normal()).project(vector).normalized()

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