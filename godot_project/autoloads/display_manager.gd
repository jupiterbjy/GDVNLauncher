extends Node

var MIN_SIZE := Vector2i(720, 850)


func _ready() -> void:
	DisplayServer.window_set_min_size(self.MIN_SIZE)
