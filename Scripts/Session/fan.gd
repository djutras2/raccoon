extends Area3D
class_name Fan

@export var direction : Vector3
@export var strength : float

#func _ready():
	#body_entered.connect(_body_entered)
	#body_exited.connect(_body_entered)
#
#func _body_entered(body):
	#if(body as Sled):
		#var sled = body as Sled

func _physics_process(delta):
	for body in get_overlapping_bodies():#.filter(func(b): b as Sled):
		(body as CharacterBody3D).velocity += direction.normalized() * strength * Vector3.UP * delta
