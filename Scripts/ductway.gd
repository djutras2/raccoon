extends Area3D
class_name DuctWay

@onready var path: Path3D = get_node("Path3D")
@export var exit_strength: float
@export var duration: float
@export var noise: Noise

func _ready():
	body_entered.connect(_body_entered)

func _body_entered(body):
	if(body as Sled):
		var sled = body as Sled
		sled.in_duct = true
		
		var collision_layer = sled.collision_layer
		sled.collision_layer = 0 # collider off
		
		var tween = sled.create_tween()
		tween.tween_method(func(i:float):
				print(i)
				var transform = path.global_transform * path.curve.sample_baked_with_rotation(i)
				sled.global_position = path.global_transform *  path.curve.sample_baked(i)
				#var forward = path.global_transform * path.curve.sample_baked(i + .01) - sled.global_position
				#sled.basis.z = -forward.normalized()
				sled.look_at(path.global_transform * path.curve.sample_baked(i + .1), Vector3.UP)
				#sled.basis = transform.basis.orthonormalized()
				,
			0.0, path.curve.get_baked_length() - .1, duration)
		
		tween.tween_callback(func():
			sled.collision_layer = collision_layer
			print("done in ducts")
			sled.velocity = -sled.basis.z * exit_strength
			sled.in_duct = false)
		
		
		
