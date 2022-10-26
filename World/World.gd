extends Node2D


onready var player = $Player
onready var camera_2d: Camera2D = $Camera2D

func _ready() -> void:
	randomize()
	player.get_node('Turret/RemoteTransform2D').remote_path = camera_2d.get_path()
