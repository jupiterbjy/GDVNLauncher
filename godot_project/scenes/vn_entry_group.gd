class_name VNEntryGroup
extends VBoxContainer
## Container that Groups VNEntryUI


# --- Attributes ---

@onready var _entry_flow_container: HFlowContainer = $EntryFlowContainer

@onready var _group_name_label: Label = $GroupNameLabel

## Group Name, used for sorting
var group_name: String:
	get():
		return self._group_name_label.text

	set(val):
		self._group_name_label.text = val


var entry_count: int:
	get():
		return self._entry_flow_container.get_child_count()

const _SCENE = preload("uid://bp8pwatctj4qh")


# --- Methods ---

## Create new instance
static func create_instance() -> VNEntryGroup:
	var instance: VNEntryGroup = _SCENE.instantiate()
	return instance


## Add entry. Do removing from entry.get_parent() instead
func add_entry(entry: VNEntryUI) -> void:
	self._entry_flow_container.add_child(entry)
