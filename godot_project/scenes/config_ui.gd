extends PanelContainer

# TODO: add exporting importing config & cache via ZIPReader/Packer


# --- Attributes ---

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


# --- Utilities ---

func _reflect_from_config() -> void:
	self.title_lang_option_button.selected = _LANG_IDX_MAP[UserConfig.title_lang]

	var tag_types := UserConfig.vndb_tag_types.split(",")
	for idx: int in range(len(self._check_boxes)):
		self._check_boxes[idx].button_pressed = self._check_box_type_map[idx] in tag_types


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

	UserConfig.save_config()


func _ready() -> void:
	self._reflect_from_config()


func _on_image_cache_dir_button_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(CacheManager.WEB_CACHE_DIR))


func _on_save_button_pressed() -> void:
	self._reflect_to_config()
	self.queue_free()


func _on_cancel_button_pressed() -> void:
	self.queue_free()
