extends Camera3D

@export var target: Sled
@export var offset : Vector2
var start_fov := 0.0

func _ready():
	start_fov = fov
	global_position = target.global_position + target.basis.z * offset.x + Vector3.UP * offset.y
	look_at(target.global_position)

func _process(delta):
	var direction
	if(target.velocity.is_equal_approx(Vector3.ZERO)):
		direction = target.basis.z
	else:
		direction = -target.velocity
	direction.y = 0
	
	direction = direction.normalized()
	
	global_position = global_position.slerp(target.global_position + direction * offset.x + Vector3.UP * offset.y, 3.2 * delta)
	look_at(target.global_position)
	fov = lerp(fov, start_fov + target.current_speed / target.max_speed, 3.0 * delta)

