extends Camera3D

@export var target: Raccoon
@export var offset : Vector3
var start_fov := 0.0

func _ready():
	start_fov = fov
	offset = global_position - target.global_position

func _process(delta):
	global_position = global_position.slerp(target.global_position + offset, 10.0 * delta)
	var amount = clamp(target.get_real_velocity().y / 30.0, 0.0, 1.0)
	fov = lerp(fov, start_fov + amount * 30.0, 3.0 * delta)

