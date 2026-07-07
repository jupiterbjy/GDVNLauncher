class_name UIMain
extends MarginContainer


# --- Attributes ---

var ui_manager: UIStackManager = null

## Dict[vn_id, VNEntry]
var _entries: Dictionary[String, VNEntryUI]

## Dict[group name, VNEntryGroup
var _groups: Dictionary[String, VNEntryGroup]

## For game count display
var _total_game_count: int = 0
var _filtered_game_count: int = 0

@onready var _group_list_container: VBoxContainer = %GroupListContainer

@onready var _sort_button: TextureButton = %SortButton

@onready var _playtime_label: Label = %PlaytimeLabel

@onready var _search_line_edit: LineEdit = %SearchLineEdit

@onready var _show_unplayable_check_box: CheckBox = %ShowUnplayableCheckBox

@onready var _game_count_label: Label = %GameCountLabel

const _SCENE := preload("res://scenes/ui_main.tscn")

static var _LOGGER := Logging.get_logger("MainUI")

## Number of maxmimum parallel reloads on _reload_all()
const _MAX_PARALLEL_RELOADS: int = 5


# --- Interfaces ---

static func create_instance() -> UIMain:
	return _SCENE.instantiate() as UIMain


func start() -> bool:

	# connect to playtime tracker to get playtime updates
	PlaytimeTracker.db_updated.connect(self._on_playtime_db_update)
	PlaytimeTracker.tick.connect(self._on_playtime_live_update)

	#EntryManager.entry_added.connect(self._add)
	EntryManager.entries_removed.connect(self._on_db_entries_removed)

	await self._async_reload_all()

	return true


func resume(data: Dictionary) -> void:
	if (
		&"edited" not in data
		or &"old_id" not in data
		or &"new_id" not in data
	):
		_LOGGER.error("Missing 'id' and 'changed' in resume data")
		return

	# TODO: handle changed ID case & changed case
	if (data[&"old_id"] != data[&"new_id"]):
		_LOGGER.error("ID change handling is not implemented yet")

	if (data[&"edited"] as bool):
		await self._async_reload(data[&"new_id"] as String)


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
		self._group_list_container.move_child(groups[idx] as Node, idx)


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

	# update count & filter
	self._total_game_count -= 1
	self._filter_groups()

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

	# update count & filter
	#self._total_game_count = EntryManager.get_entry_count()
	self._total_game_count = 0
	for group: VNEntryGroup in self._groups.values():
		_LOGGER.info("Group %s count %s" % [group.group_name, group.entry_count])
		self._total_game_count += group.entry_count

	self._filter_groups()

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


## Filter all groups via name & playtime
func _filter_groups() -> void:
	var normalized_keyword := self._search_line_edit.text.strip_edges().to_lower()

	var filter_count: int = 0

	for group: VNEntryGroup in self._groups.values():
		filter_count += group.filter_self(
			normalized_keyword,
			not self._show_unplayable_check_box.button_pressed,
		)

	self._filtered_game_count = filter_count

	self._game_count_label.text = "%d / %d" % [
		self._filtered_game_count, self._total_game_count,
	]


# --- Handlers ---

func _ready() -> void:
	# cleanup viewport placeholder
	for child: Control in self._group_list_container.get_children():
		child.free()


## Called on EditUI.entry_saved
func _on_edit_ui_saved(id: String) -> void:
	if id in self._entries:
		await self._async_reload(id)
	else:
		self._add(id)


## Handler for adding new VN
func _on_add_button_pressed() -> void:
	await self.ui_manager.stack_ui(UIDetailEdit.create_instance())


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


## Connected in runtime, handler for VN cover image press on VNEntryUI
func _on_cover_pressed(id: String) -> void:
	await self.ui_manager.stack_ui(UIDetailView.create_instance(id))


func _on_config_button_pressed() -> void:
	await self.ui_manager.stack_ui(ConfigUI.create_instance())


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


func _on_show_unplayable_check_box_toggled(_toggled_on: bool) -> void:
	self._filter_groups()


func _on_search_line_edit_text_changed(_new_text: String) -> void:
	self._filter_groups()


func _on_search_line_edit_text_submitted(_new_text: String) -> void:
	self._search_line_edit.release_focus()


func _on_expand_all_button_pressed() -> void:
	for group: VNEntryGroup in self._groups.values():
		group.expand()


func _on_collapse_all_button_pressed() -> void:
	for group: VNEntryGroup in self._groups.values():
		group.fold()
