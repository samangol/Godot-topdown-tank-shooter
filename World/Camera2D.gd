extends Camera2D

onready var player = $"../Player"


var interpolate_val = 1

func _physics_process(delta):
	var target = player.global_position 
	var mid_x = (target.x + get_global_mouse_position().x) / 2
	var mid_y = (target.y + get_global_mouse_position().y) / 2

	global_position = global_position.linear_interpolate(Vector2(mid_x,mid_y), interpolate_val * delta) 
