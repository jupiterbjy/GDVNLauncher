extends MarginContainer


# --- Attributes ---

## Dict[vn_id, VNEntry]
var _entries: Dictionary[String, VNEntryUI]

## Dict[group name, VNEntryGroup
var _groups: Dictionary[String, VNEntryGroup]

@onready var _group_list_container: VBoxContainer = %GroupListContainer

@onready var _sort_button: TextureButton = %SortButton

@onready var _playtime_label: Label = %PlaytimeLabel

const _CONFIG_SCENE = preload("uid://bo3ykybjvk4wo")

static var _LOGGER := Logging.get_logger("MainUI")

## Number of maxmimum parallel reloads on _reload_all()
const _MAX_PARALLEL_RELOADS: int = 5


# --- Methods ---

## Fetch group. Creates new if missing.
func _get_group(key: String) -> VNEntryGroup:

	if key not in self._groups:
		_LOGGER.debug("Adding group '%s'" % key)

		self._groups[key] = VNEntryGroup.create_instance()
		self._group_list_container.add_child(self._groups[key])
		self._groups[key].group_name = key

	return self._groups[key]


## Clear all groups w/o removing individual entries in it
func _remove_groups() -> void:

	_LOGGER.debug("Removing all groups")

	# unlink first
	for entry: VNEntryUI in self._entries.values():
		entry.get_parent().remove_child(entry)

	# remove groups
	for group: VNEntryGroup in self._groups.values():
		group.queue_free()
		self._group_list_container.remove_child(group)

	self._groups.clear()


## Clear empty groups
func _remove_empty_groups() -> void:

	for key: String in self._groups.keys():

		if not self._groups[key].entry_count:
			_LOGGER.debug("Removing group '%s'" % key)
			self._groups[key].queue_free()
			self._group_list_container.remove_child(self._groups[key])
			self._groups.erase(key)


## Sort groups
func _sort_groups(ascending := true) -> void:
	var groups := self._groups.values()

	if ascending:
		groups.sort_custom(
			func(a: VNEntryGroup, b: VNEntryGroup) -> bool:
				return a.group_name.naturalnocasecmp_to(b.group_name) < 0
		)
	else:
		groups.sort_custom(
			func(a: VNEntryGroup, b: VNEntryGroup) -> bool:
				return a.group_name.naturalnocasecmp_to(b.group_name) > 0
		)

	for idx: int in len(groups):
		self._group_list_container.move_child(groups[idx], idx)


## Reload existing entry. Does not checks for missing id
func _async_reload(id: String) -> void:

	# try reload
	if await self._entries[id].async_reload():
		_LOGGER.debug("Refreshed %s" % id)
		return

	# reload failed, then it's deleted - remove entry
	self._entries[id].queue_free()

	if self._entries[id].get_parent():
		self._entries[id].get_parent().remove_child(_entries[id])

	self._entries.erase(id)

	_LOGGER.debug("Deleted %s" % id)


# Create new entry and add to scene
func _add(id: String) -> void:

	var entry := EntryManager.get_entry(id)
	assert(entry, "No record found for %s" % id)

	var instance := VNEntryUI.create_instance(entry)
	instance.cover_clicked.connect(self._on_cover_pressed)

	self._entries[id] = instance
	self._get_group(self._entries[id].entry.vn.developers).add_entry(instance)


## Reload all UI Entry from DB. Does not factor in for deletion.
func _async_reload_all() -> void:
	_LOGGER.debug("Reloading all entries")

	# clear groups
	#self._remove_groups()

	for id: String in EntryManager.get_entry_ids():
		if id not in self._entries:
			self._add(id)

	# reload all, but check for deletion since one could erase before it's fetched
	var pending := self._entries.keys()

	while pending:

		var callable_param_pairs: Array[Array]

		for _idx: int in mini(len(pending), _MAX_PARALLEL_RELOADS):
			callable_param_pairs.append([self._entries[pending.pop_back()].async_reload, []])

		await ParallelAwait.async_join(callable_param_pairs)

	# was not allowing empty groups to be created in first place but this is cleaner
	self._remove_empty_groups()
	self._sort_groups(self._sort_button.button_pressed)

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
		"%s\n%d sessions" % [Time.get_time_string_from_unix_time(record[0]), record[1]]
	)


# --- Handlers ---

func _ready() -> void:

	# connect to playtime tracker to get playtime updates
	PlaytimeTracker.db_updated.connect(self._on_playtime_db_update)
	PlaytimeTracker.tick.connect(self._on_playtime_live_update)

	#EntryManager.entry_added.connect(self._add)
	EntryManager.entries_removed.connect(self._on_db_entries_removed)

	await self._async_reload_all()


## Called on EditUI.entry_saved
func _on_edit_ui_saved(id: String) -> void:
	if id in self._entries:
		await self._async_reload(id)
	else:
		self._add(id)


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
		EntryManager.upsert_entry_from_vndb(vn_info)
		PlaytimeTracker.unstash_sessions(vn_info.id)

		if vn_info.id not in self._entries:
			self._add(vn_info.id)

	await self._async_reload_all()


## Called on DetailUI.closed
func _on_detail_ui_closed(id: String) -> void:
	await self._async_reload(id)


## Handler for VN cover image press on VNEntryUI
func _on_cover_pressed(id: String) -> void:
	var instance := DetailUI.create_instance(id)
	instance.closed.connect(self._on_detail_ui_closed)

	self.add_sibling(instance)


func _on_config_button_pressed() -> void:
	self.add_sibling(_CONFIG_SCENE.instantiate())


## Connected in runtime, called when entry is removed from DB
func _on_db_entries_removed(ids: Array[String]) -> void:

	for id in ids:
		if id not in self._entries:
			continue

		self._entries[id].queue_free()
		self._entries[id].get_parent().remove_child(self._entries[id])
		self._entries.erase(id)

	self._remove_empty_groups()


## Connected in runtime, called when playtime is updated in db
func _on_playtime_db_update(ids: Array[String]) -> void:

	for id in ids:
		if id not in self._entries:
			_LOGGER.error("No entry with id %s" % id)
			continue

		self._entries[id].update_playtime_from_db()
		self._entries[id].update_playtime_live()

	self._update_aggregated_playtime()


## Connected in runtime, called when playtime is updated
func _on_playtime_live_update(vn_ids: Array[String]) -> void:
	for id in vn_ids:
		if id not in self._entries:
			_LOGGER.error("No entry with id %s" % id)
			continue

		self._entries[id].update_playtime_live()


func _on_sort_button_pressed() -> void:
	self._sort_groups(self._sort_button.button_pressed)
