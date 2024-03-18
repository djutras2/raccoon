extends CanvasLayer

@export var player : Sled
@export var grind_indicator : ProgressBar


func _ready():
	pass

func _process(delta):
	if(player.grinding):
		grind_indicator.visible = true
		grind_indicator.value = player.grind_balance
	else:
		grind_indicator.visible = false


