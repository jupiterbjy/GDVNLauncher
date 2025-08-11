extends MarginContainer


# --- Attributes ---

## Dict[DB_ID, VNEntry]
var _entries: Dictionary[int, VNEntryUI]

@onready var vn_entry_flow_container: HFlowContainer = %VNEntryFlowContainer

const _CONFIG_SCENE = preload("uid://bo3ykybjvk4wo")

static var _LOGGER := Logging.get_logger("MainUI")


# --- Utilities ---

## Just bunch of random library testing bits
func _test() -> void:
	CacheManager._test()
	DBWrapper._test()
	#print(ActiveProcesses.poll())


## Reload or add UI Entry of given db_idx
func _reload_one(db_id: int) -> void:

	assert(db_id != -1, "invalid entry(%d) received" % db_id)

	# if exists reload it
	if db_id in self._entries:
		if not await self._entries[db_id].reload():
			self._entries[db_id].queue_free()
			self._entries.erase(db_id)

		return

	# else create new
	var instance := VNEntryUI.create_instance(db_id)
	instance.cover_clicked.connect(self._on_cover_pressed)

	self._entries[db_id] = instance

	# TODO: Think about sorting options
	self.vn_entry_flow_container.add_child(instance)


## Reload all UI Entry from DB
func _reload_all() -> void:
	_LOGGER.debug("Reloading all entries")

	# this is dumb and makes n queries to DB but sufficent for now...
	for db_id in EntryManager.get_entry_db_ids():
		self._reload_one(db_id)


func _ready() -> void:
	_test()
	self._reload_all()


## Called on EditUI.entry_saved
func _on_edit_ui_saved(db_id: int) -> void:

	# if -1 should be new, fetch from db
	self._reload_one(
		EntryManager.get_last_entry_db_id()
		if db_id == -1
		else db_id
	)


## Handler for adding new VN
func _on_add_button_pressed() -> void:
	var instance: EditUI = EditUI.create_instance()
	instance.entry_saved.connect(self._on_edit_ui_saved)

	self.add_child(instance)


## Called on DetailUI.closed
func _on_detail_ui_closed(db_id: int, deleted: bool) -> void:
	self._reload_one(db_id)


## Handler for VN cover image press on VNEntryUI
func _on_cover_pressed(db_id: int) -> void:
	var instance := DetailUI.create_instance(db_id)
	instance.closed.connect(self._on_detail_ui_closed)

	self.add_child(instance)


func _on_config_button_pressed() -> void:
	self.add_child(_CONFIG_SCENE.instantiate())
