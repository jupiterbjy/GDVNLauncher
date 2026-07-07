class_name UIStackManager
extends Control
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

	## Post-onready Start action. Should return false on startup failure.
	func start() -> bool:
		# wonder if variant was better but welp

		self._logger.debug("Starting %s" % self.ui_name)

		if self.ui_node.has_method(&"start"):
			return await self.ui_node.call(&"start")

		return true

	## Pause action.
	func pause() -> void:
		self._logger.debug("Pausing %s" % self.ui_name)

		if not self.ui_flags & UI_POPUP:
			self.ui_node.hide()

		if not self.ui_flags & UI_PROCESS_ON_PAUSE:
			self.ui_node.process_mode = Node.PROCESS_MODE_DISABLED

		if self.ui_node.has_method(&"pause"):
			self.ui_node.call(&"pause")

	## Resume action. Receives arbitary data from popped UI.
	## Up to this ui on how to handle it.
	func resume(data: Dictionary) -> void:
		self._logger.debug("Resuming %s w/ %s" % [self.ui_name, data])

		if self.ui_node.has_method(&"resume"):
			self.ui_node.call(&"resume", data)

		if not self.ui_flags & UI_POPUP:
			self.ui_node.show()

		# for now all UI better be always processing..
		if not self.ui_flags & UI_PROCESS_ON_PAUSE:
			self.ui_node.process_mode = Node.PROCESS_MODE_ALWAYS

	## Delete action for cleanup. Up to UI on how to handle `force` close.
	## Return dictionary with arbitary data, with StringName key 'closed' boolean
	## indicating whether ui has closed or not.
	func close(force := false) -> Dictionary:
		self._logger.debug("Closing %s (force=%s)" % [self.ui_name, force])

		var data: Dictionary = (
			self.ui_node.call(&"close", force)
			if self.ui_node.has_method(&"close")
			else {&"closed": true}
		)

		# asserted below so should be fine
		if data[&"closed"]:
			self.ui_node.get_parent().remove_child(self.ui_node)
			self.ui_node.queue_free()

		return data

	func free() -> void:
		self._logger.debug("Freeing %s" % self.ui_name)

		if self.ui_node:
			self.ui_node.queue_free()


# --- Attributes ---

## UI Config flag
enum {
	## Is this UI popup, and should previous UI kept visible?
	UI_POPUP = 1,

	## Is this UI need to process while paused inside stack?
	UI_PROCESS_ON_PAUSE = 2,
}

## UI Stack
var stack: Array[AbstractUIWrapper]

static var _LOGGER := Logging.get_logger(&"UIStackManager")


# --- Methods ---

## Stack new UI in stack. Returns false on failure and frees scene.
func stack_ui(instanced_scene: Control) -> bool:

	instanced_scene.set(&"ui_manager", self)

	self.add_child(instanced_scene)
	var new_ui := AbstractUIWrapper.new(instanced_scene)

	if self.stack:
		self.stack[-1].pause()

	if not await new_ui.start():
		_LOGGER.info("Failed to start %s" % instanced_scene.name)

		new_ui.free()

		if self.stack:
			self.stack[-1].resume({&"closed": true})

		return false

	self.stack.append(new_ui)

	return true


## Pop UI in stack and destroy it
func pop_ui(force := false) -> bool:
	var data := self.stack[-1].close(force)
	assert(&"closed" in data, "Close call's returned dictionary is missing 'closed' StringName!")

	if data[&"closed"]:
		# refcounted so it'll free itself later
		self.stack.pop_back()
		self.stack[-1].resume(data)

		return true
	return false


## Destroy all UI in case of close request
func cascade_ui(force := false) -> bool:
	while self.stack:
		if not self.pop_ui(force):
			return false

	return true


# --- Handlers ---

func _ready() -> void:
	# bootstrap
	await self.stack_ui(UIMain.create_instance())
