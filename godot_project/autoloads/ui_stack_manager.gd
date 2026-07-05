extends Node
## Used to manage UI stacks by hiding all previous ones when stacking optionally

# --- Signals ---

# --- Classes ---

## Used to type hint for goose typing by pretending each UI is subclass of this
class AbstractUIWrapper:
	var ui_node: Control = null

	var ui_name: String:
		get():
			return self.ui_node.name

	var ui_flags: int = 0

	static var _logger := Logging.get_logger(&"AbstractUIWrapper")

	func _init(original_node: Control) -> void:
		self.ui_node = original_node

		if &"ui_flags" in original_node:
			self.ui_flags = original_node.get(&"ui_flags")

	## Post-onready Start action. Receives arbitary data from paused UI.
	## Up to this ui on how to handle it.
	## Should return false on startup failure.
	func start(data: Dictionary) -> bool:
		self._logger.debug("Starting %s w/ %s" % [self.ui_name, data])

		if self.ui_node.has_method(&"start"):
			return self.ui_node.call(&"start", data)

		return true

	## Pause action. Sends arbitary data to stacked UI if necessary.
	## This should NOT stop `_process` & `_physics_process` on it's own.
	## That is handled by UIStackManager using `ui_flags`.
	func pause() -> Dictionary:
		self._logger.debug("Pausing %s" % self.ui_name)

		if not self.ui_flags & UI_POPUP:
			self.ui_node.hide()

		if self.ui_flags & UI_NO_PROCESS_ON_PAUSE:
			self.ui_node.process_mode = Node.PROCESS_MODE_DISABLED

		if self.ui_node.has_method(&"pause"):
			return self.ui_node.call(&"pause")

		return {}

	## Resume action. Receives arbitary data from popped UI.
	## Up to this ui on how to handle it.
	func resume(data: Dictionary) -> void:
		self._logger.debug("Resuming %s w/ %s" % [self.ui_name, data])

		if self.ui_node.has_method(&"resume"):
			return self.ui_node.call(&"resume", data)

		if not self.ui_flags & UI_POPUP:
			self.ui_node.show()

		# for now all UI better be always processing..
		if self.ui_flags & UI_NO_PROCESS_ON_PAUSE:
			self.ui_node.process_mode = Node.PROCESS_MODE_ALWAYS

	## Delete action for cleanup. Up to UI on how to handle `force` close.
	## Should return true if UI is closed.
	func close(force := false) -> bool:
		self._logger.debug("Closing %s (force=%s)" % [self.ui_name, force])

		if self.ui_node.has_method(&"close"):
			return self.ui_node.call(&"close", force)

		self.ui_node.get_parent().remove_child(self.ui_node)
		self.ui_node.queue_free()

		return true

	func free() -> void:
		self._logger.debug("Freeing %s" % self.ui_name)

		if self.ui_node:
			self.ui_node.queue_free()

		super.free()


# --- Attributes ---

## UI Config flag
enum {
	UI_POPUP = 1,
	UI_NO_PROCESS_ON_PAUSE = 2,
}

## UI Stack
var stack: Array[AbstractUIWrapper]

var _logger := Logging.get_logger(&"UIStackManager")


# --- Methods ---

## Stack new UI in stack. Returns false on failure and frees scene.
func stack_ui(instanced_scene: Control) -> bool:
	self.add_sibling(instanced_scene)

	var last_ui := stack[-1]

	var new_ui := AbstractUIWrapper.new(instanced_scene)

	if not new_ui.start(last_ui.pause()):
		new_ui.free()
		last_ui.resume({})
		return false

	self.stack.append(new_ui)

	return true


## Pop UI in stack and destroy it
func pop_ui(force := false) -> bool:
	if self.stack[-1].close(force):
		(self.stack.pop_back() as AbstractUIWrapper).free()
		return true

	return false


# --- Handlers ---
