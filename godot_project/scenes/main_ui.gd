extends MarginContainer


# --- Attributes ---

## Dict[DB_ID, VNEntry]
var _entries: Dictionary[String, VNEntryUI]

@onready var _vn_entry_flow_container: HFlowContainer = %VNEntryFlowContainer
@onready var _playtime_label: Label = %PlaytimeLabel

const _CONFIG_SCENE = preload("uid://bo3ykybjvk4wo")

static var _LOGGER := Logging.get_logger("MainUI")


# --- Methods ---

## Reload existing entry. Does not checks for missing id
func _reload(id: String) -> void:

	# try reload
	if await self._entries[id].reload():
		_LOGGER.debug("Refreshed %s" % id)
		return

	# reload failed, then it's deleted - remove entry
	self._entries[id].queue_free()
	self._vn_entry_flow_container.remove_child(_entries[id])
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
	self._vn_entry_flow_container.add_child(instance)


## Reload all UI Entry from DB. Does not factor in for deletion.
func _reload_all() -> void:
	_LOGGER.debug("Reloading all entries")

	for key: String in self._entries.keys():
		self._entries[key].reload()

	# repopulate & reorder existing nodes
	for id in EntryManager.get_entry_ids():
		if id in self._entries:
			self._vn_entry_flow_container.move_child(self._entries[id], -1)

		self._add_or_reload(id)

	# update aggregated time
	self._update_aggregated_playtime()


## Update each VNs' playtime & session count if it's running
func _update_vn_playtime() -> void:
	for vn_id: String in PlaytimeTracker.get_ids():
		if vn_id in self._entries:
			self._entries[vn_id].update_playtime_from_db()


## Update all VNs' aggregated playtime & session count
func _update_aggregated_playtime() -> void:
	# only update if anything is running

	var record := PlaytimeTracker.get_all_proc_time_n_count()

	self._playtime_label.text = (
		"%.1fh\n%d sessions" % [record[0] / 3600.0, record[1]]
		if record[0] > 1800
		else "%.1fm\n%d sessions" % [record[0] / 60.0, record[1]]
	)


# --- Handlers ---

func _ready() -> void:
	self._reload_all()

	# connect to playtime tracker to get playtime updates
	PlaytimeTracker.db_updated.connect(self._on_playtime_db_update)


## Called on EditUI.entry_saved
func _on_edit_ui_saved(id: String) -> void:
	self._add_or_reload(id)


## Handler for adding new VN
func _on_add_button_pressed() -> void:
	var instance: EditUI = EditUI.create_instance()
	instance.entry_saved.connect(self._on_edit_ui_saved)

	self.add_sibling(instance)


func _on_batch_add_button_pressed() -> void:
	for vn_info: VndbVN in await VNDBClient.async_get_ulist(
		await UserConfig.async_get_user_id(),
		UserConfig.title_lang,
		UserConfig.vndb_tag_min_rating,
		0,
		UserConfig.vndb_tag_types,
	):
		EntryManager.upsert_entry(
			EntryManager.Entry.from_vndb_info(vn_info)
		)

	self._reload_all()


## Called on DetailUI.closed
func _on_detail_ui_closed(id: String) -> void:
	self._add_or_reload(id)


## Handler for VN cover image press on VNEntryUI
func _on_cover_pressed(id: String) -> void:
	var instance := DetailUI.create_instance(id)
	instance.closed.connect(self._on_detail_ui_closed)

	self.add_sibling(instance)


func _on_config_button_pressed() -> void:
	self.add_sibling(_CONFIG_SCENE.instantiate())


## Connected in runtime, called when playtime is updated
func _on_playtime_db_update(vn_ids: Array[String]) -> void:

	for id in vn_ids:
		self._entries[id].update_playtime_from_db()

	self._update_aggregated_playtime()
