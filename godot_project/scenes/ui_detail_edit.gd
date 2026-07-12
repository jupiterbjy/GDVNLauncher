class_name UIDetailEdit
extends MarginContainer

# TODO: add check for overlapping vndb id


# --- Signals ---


# --- Attributes ---

var ui_manager: UIStackManager = null

var entry: EntryManager.Entry = null

var is_edited: bool = false

@onready var cover_image_rect: TextureRect = %CoverImageTextureRect
@onready var title_line_edit: LineEdit = %TitleLineEdit
@onready var developer_line_edit: LineEdit = %DeveloperLineEdit
@onready var release_date_line_edit: LineEdit = %ReleaseDateLineEdit

@onready var vndb_id_line_edit: LineEdit = %VndbIdLineEdit
@onready var spoiler_option_button: OptionButton = %SpoilerOptionButton

@onready var exec_path_line_edit: LineEdit = %ExecPathLineEdit
@onready var admin_priv_check_box: CheckBox = %AdminPrivCheckBox
@onready var exec_file_dialog: FileDialog = $ExecFileDialog

@onready var tag_line_edit: LineEdit = %TagLineEdit

@onready var description_text_edit: TextEdit = %DescriptionTextEdit

@onready var label_option_large: OptionButton = %LabelOptionLarge

@onready var image_file_dialog: FileDialog = $ImageFileDialog
@onready var url_popup: CenterContainer = $URLPopup

static var _LOGGER := Logging.get_logger("UIDetailEdit")

const _SCENE = preload("res://scenes/ui_detail_edit.tscn")


# --- Interfaces ---

static func create_instance(id: String = "") -> UIDetailEdit:
	var instance: UIDetailEdit = _SCENE.instantiate()
	instance.entry = (
		EntryManager.get_entry(id) if id else EntryManager.Entry.new()
	)

	return instance


## Return false to abort stacking (the new UI will be freed and previous resumed).
func start() -> bool:

	ControlUtils.option_button_hide_radio(self.label_option_large)

	if self.entry.id:
		await self._reflect_to_ui()

	return true


## Return a dictionary to pass that data to this UI's resume() later.
func pause() -> Dictionary:
	return {}


## `data` contains the return value of pause() from the UI that was just closed.
func resume(_data: Dictionary) -> void:
	pass


## Delete action for cleanup. Up to UI on how to handle `force` close.
## Return dictionary with arbitary data, with StringName key 'closed' boolean
## indicating whether ui has closed or not.
func close(_force := false) -> Dictionary:
	return {
		&"closed": true,
		&"ui_detail_edit": {
			&"id": self.entry.id,
			&"edited": self.is_edited,
		}
	}


# --- Methods ---

func _update_cover_image() -> void:
	if not self.entry.vn.cover_url:
		return

	var tex := await self.entry.vn.get_cover_tex()
	if tex:
		self.cover_image_rect.texture = tex
	else:
		_LOGGER.warn("failed to load image from '%s'" % self.entry.vn.cover_url)


## Refresh UI to match self.entry
func _reflect_to_ui() -> void:

	self.exec_path_line_edit.text = self.entry.exec_path

	self.vndb_id_line_edit.text = self.entry.vn.id
	self.title_line_edit.text = self.entry.vn.title
	self.description_text_edit.text = self.entry.vn.description
	self.developer_line_edit.text = ",".join(self.entry.vn.developers)
	self.release_date_line_edit.text = self.entry.vn.released
	self.tag_line_edit.text = ",".join(self.entry.vn.tags)
	self.label_option_large.selected = self.entry.vn.label

	self.admin_priv_check_box.button_pressed = self.entry.admin

	await self._update_cover_image()


## Refresh self.entry to match UI
func _reflect_from_ui() -> void:

	self.entry.exec_path = self.exec_path_line_edit.text.strip_edges()

	self.entry.vn.id = self.vndb_id_line_edit.text.strip_edges()
	self.entry.vn.title = self.title_line_edit.text.strip_edges()
	self.entry.vn.description = self.description_text_edit.text.strip_edges()
	self.entry.vn.developers = StringUtils.csv_sep(self.developer_line_edit.text, true, ";;")
	self.entry.vn.released = self.release_date_line_edit.text.strip_edges()
	self.entry.vn.tags = StringUtils.csv_sep(self.tag_line_edit.text, true)
	self.entry.vn.label = self.label_option_large.selected

	self.entry.admin = self.admin_priv_check_box.button_pressed


# --- Handlers ---

func _on_exec_select_button_pressed() -> void:

	# set dir to already set path if configured
	var path := self.exec_path_line_edit.text.strip_edges()
	if path:
		self.exec_file_dialog.current_dir = path.get_base_dir()

	self.exec_file_dialog.show()


func _on_exec_file_dialog_file_selected(path: String) -> void:
	self.exec_path_line_edit.text = path


func _on_fetch_vndb_button_pressed() -> void:

	if not VNDBClient.validate_vn_id(self.vndb_id_line_edit.text):
		_LOGGER.debug("Got invalid vn_id of '%s'" % self.vndb_id_line_edit.text)
		return

	var data := await VNDBClient.async_post_vn(
		self.vndb_id_line_edit.text,
		UserConfig.vndb_tag_min_rating,
		self.spoiler_option_button.selected,
		UserConfig.vndb_tag_types,
	)

	if data:
		data.label = self.entry.vn.label
		self.entry.vn = data

	await self._reflect_to_ui()


func _on_image_file_dialog_file_selected(path: String) -> void:
	self.entry.vn.cover_url = path
	await self._update_cover_image()


func _on_save_button_pressed() -> void:

	# save results to DB and emit result
	self._reflect_from_ui()

	if not EntryManager.upsert_entry(self.entry):
		_LOGGER.error("SQL Error while updating entry %s" % self.entry.id)
	else:
		PlaytimeTracker.unstash_sessions(self.entry.id)

	self.is_edited = true
	self.ui_manager.pop_ui()


func _on_close_button_pressed() -> void:
	self.ui_manager.pop_ui()


func _on_cover_from_url_button_pressed() -> void:
	self.url_popup.show()


func _on_cover_from_local_button_pressed() -> void:
	self.image_file_dialog.show()


func _on_url_popup_url_selected(url: String) -> void:
	self.entry.vn.cover_url = url
	await self._update_cover_image()
