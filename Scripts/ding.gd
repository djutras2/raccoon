#extends Node
class_name Ding

static var time : float:
	get: return Time.get_ticks_msec() * .001

static func time_since(_time:float) -> float:
	return Ding.time - _time
	
static func flattened(vector:Vector3) -> Vector3:
	vector.y = 0
	return vector
	
static func flattened_length(vector:Vector3) -> float:
	return sqrt(vector.x * vector.x + vector.y * vector.y)
