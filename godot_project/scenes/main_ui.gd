extends MarginContainer


# --- Attributes ---

## Dict[DB_ID, VNEntry]
var _entries: Dictionary[String, VNEntryUI]

@onready var vn_entry_flow_container: HFlowContainer = %VNEntryFlowContainer

const _CONFIG_SCENE = preload("uid://bo3ykybjvk4wo")

static var _LOGGER := Logging.get_logger("MainUI")


# --- Methods ---

## Just bunch of random library testing bits
func _test() -> void:
	CacheManager._test()
	DBWrapper._test()

	_LOGGER.info("Received user id %s" % await UserConfig.async_get_user_id())
	#print(ActiveProcesses.poll())


## Reload existing entry. Does not checks for missing id
func _reload(id: String) -> void:

	# try reload
	if await self._entries[id].reload():
		_LOGGER.debug("Refreshed %s" % id)
		return

	# reload failed, then it's deleted - remove entry
	self._entries[id].queue_free()
	self._entries.erase(id)
	_LOGGER.debug("Deleted %s" % id)


## Convenient func for add/removing on single go
func _add_or_reload(id: String) -> void:

	if id in self._entries:
		self._reload(id)
		return

	# else create new
	var instance := VNEntryUI.create_instance(id)
	instance.cover_clicked.connect(self._on_cover_pressed)

	self._entries[id] = instance

	# TODO: Think about sorting options
	self.vn_entry_flow_container.add_child(instance)


## Reload all UI Entry from DB. Does not factor in for deletion.
func _reload_all() -> void:
	_LOGGER.debug("Reloading all entries")

	for id in EntryManager.get_entry_ids():
		self._add_or_reload(id)


# --- Handlers ---

func _ready() -> void:
	_test.call_deferred()
	self._reload_all()


## Called on EditUI.entry_saved
func _on_edit_ui_saved(id: String) -> void:
	self._add_or_reload(id)


## Handler for adding new VN
func _on_add_button_pressed() -> void:
	var instance: EditUI = EditUI.create_instance()
	instance.entry_saved.connect(self._on_edit_ui_saved)

	self.add_child(instance)


## Called on DetailUI.closed
func _on_detail_ui_closed(id: String) -> void:
	# TODO: remove deleted param if it stays unused
	self._add_or_reload(id)


## Handler for VN cover image press on VNEntryUI
func _on_cover_pressed(id: String) -> void:
	var instance := DetailUI.create_instance(id)
	instance.closed.connect(self._on_detail_ui_closed)

	self.add_sibling(instance)


func _on_config_button_pressed() -> void:
	self.add_sibling(_CONFIG_SCENE.instantiate())
