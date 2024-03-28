extends CharacterBody3D
class_name Raccoon

@export var camera: Camera3D
@export var meshes: Node3D
@export var noise: Noise
@export var acceleration_from_dot: Curve

@onready var collider: CollisionShape3D = get_node("CollisionShape3D")
@onready var skelly: Skeleton3D = get_node("Node3D/Raccoon") as Skeleton3D

var dead := false
var _previous_global_position : Vector3
var _previous_velocity : Vector3
var _previous_floor_velocity : Vector3
var _previous_air_velocity : Vector3
var rotation_direction: float

const SPEED = 380.0

var current_speed := 0.0
var current_direction : Vector3
const JUMP_VELOCITY = 10.0

# falling/rolling
var _fall_max_speed := 20.0
var _fall_max_speed_with_roll := 23.0
var rolling := false
var roll_duration := .25

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
var _slip := Vector3.ZERO
var _on_ledge := false
var _last_time_left_ledge := -100.0
var can_grab_ledge : bool:
	get: return !_on_ledge and is_on_wall() and velocity.y <= 1.0 and Ding.time - _last_time_left_ledge >= LEDGE_COOLDOWN

#tubing
var in_duct := false

@onready var checkpoint_transform : Transform3D = global_transform
@onready var checkpoint_position : Vector3 = global_position

const COYOTE = .3
const PRE_JUMP = .2
const LIFT = 20.0
const LEDGE_COOLDOWN = .2

var _was_on_floor := false

var GRAVITY := 30.0
var HOLD_JUMP_GRAVITY := 20.0
var calculated_gravity : float:
	get: # gravity is decreased when holding jump and moving up
		return HOLD_JUMP_GRAVITY if (Input.is_action_pressed("jump") and velocity.y > 0.0) else GRAVITY

var v_input_speed_factor := 5.0
@onready var max_speed := SPEED * v_input_speed_factor

var acceleration := Vector3.ZERO

func ready():
	#acceleration = 5.0 * -basis.z
	#print("max_speed: " + str(max_speed))
	skelly.physical_bones_stop_simulation()
	pass
	
func _physics_process(delta):
	if(in_duct || _on_ledge):
		return
	
	if(dead):
		velocity += GRAVITY * Vector3.DOWN
		move_and_slide()
		return
	
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_l", "move_r")
	input.y = Input.get_axis("move_d", "move_u")
	
	if(rolling):
		velocity.y = 0
		
		if(input.x != 0.0):
			#rotate(Vector3.UP, 1.5 * delta)
			velocity = velocity.rotated(Vector3.UP, 1.5 * delta)
		
		if is_on_floor(): velocity = get_projected_slope() * velocity.length()
		
		move_and_slide()
		return
	
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
	
	var lerp = (10.0 if Input.is_action_pressed("sprint") else 6.0)
			
	if(!cam_input.is_zero_approx() and !velocity.is_zero_approx()):
		lerp *= acceleration_from_dot.sample((cam_input.normalized().dot(velocity.normalized()) + 1) * .5)
	
	if is_on_floor():
		movement_velocity = project_on_current_floor_normal(cam_input) * speed * delta
		if(Input.is_action_pressed("sprint")):
			movement_velocity *= 1.3
		movement_velocity.y = velocity.y

		applied_velocity = velocity.lerp(movement_velocity, delta * lerp)
	else:
		lerp *= .25
		movement_velocity = cam_input * speed * delta
		movement_velocity.y = velocity.y
		applied_velocity = velocity.lerp(movement_velocity, delta * lerp)
		
		# ledge grabbing
		if can_grab_ledge and !cam_input.is_zero_approx() and cam_input.dot(get_wall_normal()) < -.85:
			var body_origin := global_position
			var body_query = PhysicsRayQueryParameters3D.create(body_origin, body_origin - get_wall_normal() * 1.5)
			body_query.exclude.append(get_rid())
			var result = get_world_3d().direct_space_state.intersect_ray(body_query)
			DebugDraw3D.draw_arrow(body_origin, body_origin - get_wall_normal() , Color.BLUE, .1)
			if result:
				var head_origin := global_position + Vector3.UP * 1.1
				var head_query = PhysicsRayQueryParameters3D.create(head_origin, head_origin - get_wall_normal() * 1.5)
				head_query.exclude.append(get_rid())
				var head_result = get_world_3d().direct_space_state.intersect_ray(head_query)
				DebugDraw3D.draw_arrow(head_origin, head_origin - get_wall_normal(), Color.BLUE, .1)
				if(!head_result):
					grab_ledge()
							
	velocity = applied_velocity
	
	velocity += _slip * delta
	velocity += acceleration * delta
	
	# record last frame stuff
	_previous_velocity = velocity
	
	if is_on_floor():
		_slip = _slip.lerp(Vector3.ZERO, delta * 7.0)
		_previous_floor_velocity = get_real_velocity()
	else:
		_slip = Vector3.ZERO
		_previous_air_velocity = get_real_velocity()
	
	_was_on_floor = is_on_floor()
		
	# FINALLY SLIDE
	move_and_slide()	
	
	# rotation
	if !cam_input.is_zero_approx():
		rotation_direction = Vector2(cam_input.z, cam_input.x).angle()
	else: if !Vector2(velocity.z, velocity.x).is_zero_approx():
		rotation_direction = Vector2(velocity.z, velocity.x).angle()
		
	rotation.y = lerp_angle(rotation.y, rotation_direction, delta * 25)	
	meshes.scale = meshes.scale.lerp(Vector3(1, 1, 1), delta * 10)
	
	#DebugDraw3D.draw_arrow(global_position, global_position + velocity, Color.BLUE, .1)
	#DebugDraw3D.draw_arrow(global_position, global_position + basis.z, Color.BLUE_VIOLET, .1)
	#DebugDraw3D.draw_arrow(global_position, global_position + -meshes.basis.z, Color.RED, .1)

# events
func _landed():
	print("landed")
	
	var floor = get_slide_collision(0).get_collider() as StaticBody3D
	if floor:
		if floor.physics_material_override:			
			if !floor.physics_material_override.absorbent:
				velocity.y = -_previous_air_velocity.y * floor.physics_material_override.bounce
				meshes.scale = Vector3(1.25, 0.75, 1.25)
			else:
				velocity.y = 0.0
				meshes.scale = Vector3(1.25, 1.0 - floor.physics_material_override.bounce, 1.25)
			return
	
	if(Input.is_action_pressed("duck")):
		if abs(_previous_air_velocity.y) > _fall_max_speed_with_roll: crash()
		else: enter_roll()
		return
				
	if abs(_previous_air_velocity.y) > _fall_max_speed:
		crash()
		return
	
	_jump_count = 0
	meshes.scale = Vector3(1.25, 0.75, 1.25)

	if(Ding.time_since(last_time_jump_pressed) <= PRE_JUMP):
		print("pre-jump")
		_jump()
	else:	
		if(rad_to_deg(get_floor_angle()) >= 1.0 and rad_to_deg(get_floor_angle()) <= 45.0):
			print(rad_to_deg(get_floor_angle()))
			_slip = get_drain_slope() * get_floor_angle() * abs(_previous_air_velocity.y) * 30.0
		
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
	_slip = Vector3.ZERO
	
	if(_on_ledge || grinding || is_on_floor() || Ding.time_since(last_time_left_ground_not_jump) <= COYOTE):
		if(grinding): exit_grind()
		if(_on_ledge): exit_ledge()
		velocity.y = JUMP_VELOCITY
		_jump_count = 1 # has jumped once
		meshes.scale = Vector3(0.5, 1.5, 0.5)
		if(Ding.time_since(last_time_left_ground_not_jump) <= COYOTE):
			print("coyote")
	else:
		if(_can_double_jump):
			velocity.y = max(JUMP_VELOCITY * .8, velocity.y + JUMP_VELOCITY * .8)
			_jump_count = 2

func enter_roll():
	print("roll")
	meshes.scale.y = .2
	velocity.y = 0
	velocity = velocity.normalized() * _previous_air_velocity.length() * .5
	rolling = true
	
	await get_tree().create_timer(roll_duration).timeout
	rolling = false
	meshes.scale.y = 1.0

func enter_grind(path: Path3D, offset: float, direction:float):
	rail = path
	_current_curve_offset = offset
	_current_grind_direction = direction
	grind_balance = 0.0
	_jump_count = 0
	
	velocity *= 1.5
	
	meshes.rotation = Vector3.ZERO

func exit_grind():
	var transfor = rail.global_transform * rail.curve.sample_baked_with_rotation(_current_curve_offset)
	velocity = -basis.z * velocity.length() + Vector3.UP * 2.0
	#basis.z = transfor.basis.z * _current_grind_direction
	#basis.y = transfor.basis.y * _current_grind_direction
	#look_at(position, position + velocity)
		
	rail = null
	#global_basis.y = Vector3.UP
	#velocity = -transfor.basis.z.normalized() * velocity.length() * _current_grind_direction

func grab_ledge():
	print("grabbed ledge")
	_on_ledge = true
	_jump_count = 0
	
func exit_ledge():
	_last_time_left_ledge = Ding.time
	_on_ledge = false
	
func crash():
	print("crashed")
	
	#collider.disabled = true
	#skelly.process_mode = Node.PROCESS_MODE_INHERIT
	dead = true
	skelly.physical_bones_start_simulation()

func reset():
	print("reset")
	dead = false
	velocity = Vector3.ZERO
	global_transform = checkpoint_transform
	skelly.physical_bones_stop_simulation()
	#global_position = checkpoint_position

# input
func _input(_event):		
	if Input.is_action_just_pressed("reset"):
		reset()
	
	if dead: return	
	
	if Input.is_action_just_pressed("jump"):
		_jump()

	if Input.is_key_pressed(KEY_X):
		crash()
		
	if Input.is_action_just_pressed("duck"):
		if _on_ledge:
			exit_ledge()
			_jump_count = 1

# helpers
func project_on_current_floor_normal(vector:Vector3) -> Vector3:
	if !is_on_floor():
		printerr("don't call drain slope when not on ground silly")
		return Vector3.DOWN
		
	return Plane(get_floor_normal()).project(vector).normalized()

func get_drain_slope() -> Vector3:
	if !is_on_floor():
		printerr("don't call drain slope when not on ground silly")
		return Vector3.DOWN

	var down = get_floor_normal()
	down.y = 0
	return Plane(get_floor_normal()).project(down).normalized()

func get_projected_slope() -> Vector3:
	if !is_on_floor():
		printerr("don't call drain slope when not on ground silly")
		return Vector3.DOWN
		
	return Plane(get_floor_normal()).project(velocity).normalized()
