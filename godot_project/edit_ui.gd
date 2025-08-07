extends MarginContainer


@onready var exec_path_line_edit: LineEdit = %ExecPathLineEdit
@onready var file_dialog: FileDialog = $FileDialog

@onready var cover_image_button: TextureButton = %CoverImageButton
@onready var vndb_id_line_edit: LineEdit = %VndbIdLineEdit
@onready var title_line_edit: LineEdit = %TitleLineEdit
@onready var developer_line_edit: LineEdit = %DeveloperLineEdit
@onready var title_lang_option_button: OptionButton = %TitleLangOptionButton

@onready var release_date_line_edit: LineEdit = %ReleaseDateLineEdit
@onready var tag_line_edit: LineEdit = %TagLineEdit
@onready var description_text_edit: TextEdit = %DescriptionTextEdit


static var _LOGGER := Logging.get_logger("EditUI")


func test_http() -> void:
	#var data = await CacheManager.async_from_url("https://t.vndb.org/cv/77/88277.jpg")
	#var image := ImageLoader.from_buffer(data)
	#print(image.get_width(), image.get_height(), image.get_format())

	#var data2 = await CacheManager.async_from_url("http://127.0.0.1:8080")
	#print(data2.get_string_from_utf8())
	pass


func _ready() -> void:
	test_http.call_deferred()


func _on_exec_select_button_pressed() -> void:
	self.file_dialog.show()


func _on_file_dialog_file_selected(path: String) -> void:
	self.exec_path_line_edit.text = path

# TODO: connect url signal from richtextedit


func _on_fetch_vndb_button_pressed() -> void:
	var vn_id := vndb_id_line_edit.text
	if not VNDBClient.validate_vn_id(vn_id):
		_LOGGER.debug("Got invalid vn_id of '%s'" % vn_id)
		return

	var data := await VNDBClient.async_post_vn(vn_id)

	self.description_text_edit.text = data.description
	self.developer_line_edit.text = ",".join(data.developers)
	self.release_date_line_edit.text = data.released

	var lang := self.title_lang_option_button.text
	self.title_line_edit.text = (
		data.titles[lang] if lang in data.titles else data.title
	)
	self.tag_line_edit.text = ",".join(data.tags)

	# get cover image
	var bytes := await CacheManager.async_from_url(data.cover_url)
	var tex := ImageLoader.bytes_to_texture(bytes)
	if not tex:
		return

	self.cover_image_button.texture_normal = tex
