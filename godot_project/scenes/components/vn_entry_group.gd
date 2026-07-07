class_name VNEntryGroup
extends FoldableContainer
## Container that Groups VNEntryUI


# --- Attributes ---

@onready var _entry_flow_container: HFlowContainer = %EntryFlowContainer

## Used for searching
var _normalized_group_name: String

## Group Name, used for sorting
var group_name: String:
	get():
		return self.title

	set(val):
		self.title = val
		self._normalized_group_name = val.strip_edges().to_lower()

var entry_count: int:
	get():
		return self._entry_flow_container.get_child_count()

const _SCENE = preload("uid://bp8pwatctj4qh")


# --- Methods ---

## Get entries
func get_entries() -> Array[VNEntryUI]:
	var arr: Array[VNEntryUI]
	arr.assign(self._entry_flow_container.get_children())

	return arr


## Create new instance
static func create_instance() -> VNEntryGroup:
	var instance: VNEntryGroup = _SCENE.instantiate()
	return instance


## Add entry. Do removing from entry.get_parent() instead
func add_entry(entry: VNEntryUI) -> void:
	self._entry_flow_container.add_child(entry)


## Filter entries / match group name and report if self should be included.
## Keyword should be lowercase.
## Enter blank string to reset filter.
## Returns visible entry counts.
func filter_self(keyword: String, playable_only: bool) -> int:
	self.hide()
	var visible_count: int = 0

	# if fliter reset or group name is superset then show all
	if not keyword or self._normalized_group_name.contains(keyword):

		for entry: VNEntryUI in self.get_entries():
			entry.visible = not playable_only or entry.is_playable

			visible_count += int(entry.visible)
			self.visible = self.visible or entry.visible

		return visible_count

	# otherwise filter content
	# VERY EXPENSIVE AND DIRTY
	for entry: VNEntryUI in self.get_entries():
		entry.visible = (
			entry.entry.vn.normalized_title.contains(keyword)
			or entry.entry.vn.id.contains(keyword)
		) and (not playable_only or entry.is_playable)

		visible_count += int(entry.visible)
		self.visible = self.visible or entry.visible

	return visible_count


# --- Handlers ---

func _ready() -> void:
	# remove placeholders
	for entry: VNEntryUI in self.get_entries():
		entry.free()
