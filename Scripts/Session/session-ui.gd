extends CanvasLayer

@export var player : Raccoon
@export var grind_indicator : ProgressBar
@export var speed_label : Label
@export var speed_lines : TextureRect

func _ready():
	pass

func _process(delta):
	if(player.grinding):
		grind_indicator.visible = true
		grind_indicator.value = player.grind_balance
	else:
		grind_indicator.visible = false

	speed_label.text = "Speed: " + str(floor(player.get_real_velocity().length()))
	speed_lines.material.set("shader_parameter/line_density", remap(player.get_real_velocity().length(), 0.0, 50.0, 0.0, .4))


