extends Node2D

@onready var cpu_particles_2d: CPUParticles2D = $Area2D/CPUParticles2D
@onready var area_2d: Area2D = $Area2D
@onready var label: Label = $Label

var drag_start_pos: Vector2
var drag_end_pos: Vector2
var mouse_down: bool = false


func _report_status(pos: Vector2, drag_speed: float) -> void:
	self.label.text = """
	Dragging start: %.1v
	Dragging speed: %.1fpx/s
	Dist to center: %.1fpx
	""".strip_edges() % [
		self.drag_start_pos,
		drag_speed,
		(pos - self.area_2d.global_position).length(),
	]


func _on_mouse_down() -> void:
	self.mouse_down = true
	self.label.text = "mouse down"
	self.cpu_particles_2d.emitting = true


func _on_mouse_up() -> void:
	self.label.text = "mouse up"
	self.mouse_down = false
	self.cpu_particles_2d.emitting = false

	self.label.text = ""


func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:

	if event is InputEventMouseButton:

		if event.is_pressed():
			self.cpu_particles_2d.global_position = (event as InputEventMouseButton).global_position
			self._on_mouse_down()
			self.drag_start_pos = (event as InputEventMouseButton).global_position

		else:
			self._on_mouse_up()

		return

	if event is InputEventMouseMotion:
		if not self.mouse_down:
			return

		var ev := event as InputEventMouseMotion
		self.cpu_particles_2d.global_position = ev.global_position
		self._report_status(ev.global_position, ev.velocity.length())


func _on_area_2d_mouse_exited() -> void:
	self._on_mouse_up()
