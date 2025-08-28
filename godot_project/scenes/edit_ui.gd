class_name EditUI
extends PanelContainer

# TODO: add check for overlapping vndb id


# --- Signals ---

## Emitted on save.
signal entry_saved(id: String)
# emit entry or db_id? changed least 3 times back and forth


# --- Attributes ---

var entry: EntryManager.Entry = null

@onready var exec_path_line_edit: LineEdit = %ExecPathLineEdit
@onready var exec_file_dialog: FileDialog = $ExecutableFileDialog


@onready var cover_image_rect: TextureRect = %CoverImageTextureRect
@onready var vndb_id_line_edit: LineEdit = %VndbIdLineEdit
@onready var title_line_edit: LineEdit = %TitleLineEdit
@onready var developer_line_edit: LineEdit = %DeveloperLineEdit
@onready var spoiler_option_button: OptionButton = %SpoilerOptionButton

@onready var release_date_line_edit: LineEdit = %ReleaseDateLineEdit
@onready var tag_line_edit: LineEdit = %TagLineEdit
@onready var description_text_edit: TextEdit = %DescriptionTextEdit

@onready var label_option_large: OptionButton = %LabelOptionLarge

@onready var image_file_dialog: FileDialog = $ImageFileDialog
@onready var url_popup: CenterContainer = $URLPopup

static var _LOGGER := Logging.get_logger("EditUI")

const _SCENE = preload("uid://2henmqt3po33")


# --- Methods ---

static func create_instance(id: String = "") -> EditUI:
	var instance: EditUI = _SCENE.instantiate()
	instance.entry = (
		EntryManager.get_entry(id) if id else EntryManager.Entry.new()
	)

	return instance


func _update_cover_image() -> void:
	if not self.entry.vn_info.cover_url:
		return

	var tex := await self.entry.vn_info.get_cover_tex()
	if tex:
		self.cover_image_rect.texture = tex
	else:
		_LOGGER.warn("failed to load image from '%s'" % self.entry.vn_info.cover_url)


## Refresh UI to match self.entry
func _reflect_to_ui() -> void:

	self.exec_path_line_edit.text = self.entry.exec_path

	self.vndb_id_line_edit.text = self.entry.vn_info.id
	self.title_line_edit.text = self.entry.vn_info.title
	self.description_text_edit.text = self.entry.vn_info.description
	self.developer_line_edit.text = self.entry.vn_info.developers
	self.release_date_line_edit.text = self.entry.vn_info.released
	self.tag_line_edit.text = self.entry.vn_info.tags
	self.label_option_large.selected = self.entry.vn_info.label

	self._update_cover_image()


## Refresh self.entry to match UI
func _reflect_from_ui() -> void:

	self.entry.exec_path = self.exec_path_line_edit.text.strip_edges()

	self.entry.vn_info.id = self.vndb_id_line_edit.text.strip_edges()
	self.entry.vn_info.title = self.title_line_edit.text.strip_edges()
	self.entry.vn_info.description = self.description_text_edit.text.strip_edges()
	self.entry.vn_info.developers = self.developer_line_edit.text.strip_edges()
	self.entry.vn_info.released = self.release_date_line_edit.text.strip_edges()
	self.entry.vn_info.tags = self.tag_line_edit.text.strip_edges()
	self.entry.vn_info.label = self.label_option_large.selected


# --- Handlers ---

func _ready() -> void:
	ControlUtils.option_button_hide_radio(self.label_option_large)

	if self.entry.id:
		self._reflect_to_ui()


func _on_exec_select_button_pressed() -> void:

	# set dir to already set path if configured
	var path := self.exec_path_line_edit.text.strip_edges()
	if path:
		self.exec_file_dialog.current_dir = path.get_base_dir()

	self.exec_file_dialog.show()


func _on_executable_file_dialog_file_selected(path: String) -> void:
	self.exec_path_line_edit.text = path


func _on_fetch_vndb_button_pressed() -> void:

	if not VNDBClient.validate_vn_id(self.vndb_id_line_edit.text):
		_LOGGER.debug("Got invalid vn_id of '%s'" % self.vndb_id_line_edit.text)
		return

	var data := await VNDBClient.async_post_vn(
		self.vndb_id_line_edit.text,
		UserConfig.title_lang,
		UserConfig.vndb_tag_min_rating,
		self.spoiler_option_button.selected,
		UserConfig.vndb_tag_types,
	)

	if data:
		self.entry.vn_info = data

	self._reflect_to_ui()


func _on_image_file_dialog_file_selected(path: String) -> void:
	self.entry.vn_info.cover_url = path
	self._update_cover_image()


func _on_save_button_pressed() -> void:

	# save results to DB and emit result
	self._reflect_from_ui()
	EntryManager.upsert_entry(self.entry)

	self.entry_saved.emit(self.entry.id)
	self.queue_free()


func _on_cancel_button_pressed() -> void:
	self.queue_free()


func _on_cover_from_url_button_pressed() -> void:
	self.url_popup.show()


func _on_cover_from_local_button_pressed() -> void:
	self.image_file_dialog.show()


func _on_url_popup_url_selected(url: String) -> void:
	self.entry.vn_info.cover_url = url
	self._update_cover_image()
