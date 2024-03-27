extends CanvasLayer

@export var player : Raccoon
@export var grind_indicator : ProgressBar
@export var speed_label : Label
@export var speed_lines : TextureRect
@export var input_label : Label

func _ready():
	pass

func _process(delta):
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_l", "move_r")
	input.y = Input.get_axis("move_d", "move_u")
	
	if(player.grinding):
		grind_indicator.visible = true
		grind_indicator.value = player.grind_balance
	else:
		grind_indicator.visible = false

	speed_label.text = "Speed: " + str(floor(player.get_real_velocity().length()))
	speed_lines.material.set("shader_parameter/line_density", remap(player.get_real_velocity().length(), 0.0, 50.0, 0.0, .4))
	
	input_label.text = "Input: " + str(input)

