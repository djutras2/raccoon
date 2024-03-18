#extends Node
class_name Ding

static var time : float:
	get: return Time.get_ticks_msec() * .001

static func time_since(_time:float) -> float:
	return Ding.time - _time
