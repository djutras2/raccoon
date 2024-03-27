extends Area3D
class_name Grindable

@onready var path: Path3D = get_node("Path3D")

func _ready():
	body_entered.connect(_body_entered)

func _body_entered(body):
	if(body as CharacterBody3D):
		var sled = body as CharacterBody3D
		var offset = path.curve.get_closest_offset(path.to_local(sled.global_position))
		var offset_after_velocity = path.curve.get_closest_offset(path.to_local(sled.global_position + sled.velocity * .1))
		var direction = sign(offset_after_velocity - offset)

		sled.enter_grind(path, clamp(offset, 0 + .0001, path.curve.get_baked_length()) - .0001, direction)
