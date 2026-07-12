class_name UIConfig
extends MarginContainer

# TODO: add exporting importing config & cache via ZIPReader/Packer


# --- Signals ---


# --- Attributes ---

var ui_manager: UIStackManager = null

@onready var _version_label: Label = %VersionLabel

# VNDB CONF --
@onready var title_lang_option_button: OptionButton = %TitleLangOptionButton

@onready var cont_check_box: CheckBox = %ContCheckBox
@onready var ero_check_box: CheckBox = %EroCheckBox
@onready var tech_check_box: CheckBox = %TechCheckBox

@onready var _check_boxes: Array[CheckBox] = [
	self.cont_check_box, self.ero_check_box, self.tech_check_box
]

var _check_box_type_map: PackedStringArray = ["cont", "ero", "tech"]

@onready var tag_rating_spin_box: SpinBox = %TagRatingSpinBox

@onready var vndb_token_line_edit: LineEdit = %VNDBTokenLineEdit


# App Config --

@onready var poll_rate_spin_box: SpinBox = %PollRateSpinBox

## Dict[Lang name, OptionButton Index] mapping
const _LANG_IDX_MAP: Dictionary[String, int] = {
	"en": 0, "ja": 1, "ko": 2, "zh-Hans": 3,
}

const _SCENE := preload("res://scenes/ui_config.tscn")


# --- Interfaces ---

static func create_instance() -> UIConfig:
	return _SCENE.instantiate() as UIConfig


## Return false to abort stacking (the new UI will be freed and previous resumed).
func start() -> bool:
	self._reflect_from_config()

	# setup ver string
	self._version_label.text = "{} - {}" % [Globals.VERSION, Globals.COMMIT_HASH]
	return true


# --- Methods ---

func _reflect_from_config() -> void:
	self.title_lang_option_button.selected = _LANG_IDX_MAP[UserConfig.title_lang]

	var tag_types := UserConfig.vndb_tag_types.split(",")
	for idx: int in range(len(self._check_boxes)):
		self._check_boxes[idx].button_pressed = self._check_box_type_map[idx] in tag_types

	# fetch token
	self.vndb_token_line_edit.text = UserConfig.vndb_token

	self.poll_rate_spin_box.value = UserConfig.poll_interval


func _reflect_to_config() -> void:

	# Write title lang
	UserConfig.title_lang = self.title_lang_option_button.text

	# Write tag rating
	UserConfig.vndb_tag_min_rating = self.tag_rating_spin_box.value

	# Write tag filter
	var tag_types: Array[String]
	for idx: int in range(len(self._check_boxes)):
		if self._check_boxes[idx].button_pressed:
			tag_types.append(self._check_box_type_map[idx])

	UserConfig.vndb_tag_types = ",".join(tag_types)

	# Write token
	UserConfig.vndb_token = self.vndb_token_line_edit.text.strip_edges()

	UserConfig.poll_interval = int(self.poll_rate_spin_box.value)

	UserConfig.save_config()


# --- Handlers ---

func _on_image_cache_dir_button_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(CacheManager.WEB_CACHE_DIR))


func _on_save_button_pressed() -> void:
	self._reflect_to_config()
	self.ui_manager.pop_ui()


func _on_close_button_pressed() -> void:
	self.ui_manager.pop_ui()


func _on_clear_unplayed_entries_pressed() -> void:
	var pending_ids: Array[String]

	for id: String in EntryManager.get_entry_ids():
		if not PlaytimeTracker.get_proc_session_count(id):
			pending_ids.append(id)

	EntryManager.remove_entries(pending_ids)
