class_name DetailUI
extends PanelContainer
## Detailed VN information UI

# TODO: add delete option


# --- Signals ---

## Emitted when closing
signal closed(id: String)


# --- Attributes ---

var entry: EntryManager.Entry = null

@onready var title_label: Label = %TitleLabel

@onready var cover_image_texture_rect: TextureRect = %CoverImageTextureRect
@onready var developer_label: Label = %DeveloperLabel
@onready var release_date_label: Label = %ReleaseDateLabel

@onready var label_option_large: OptionButton = %LabelOptionLarge

@onready var vndb_link: LinkButton = %VNDBLink
@onready var launch_button: Button = %LaunchButton
@onready var exec_path_label: Label = %ExecPathLabel
@onready var tag_container: FlowContainer = %TagContainer
@onready var description_rich_label: RichTextLabel = %DescriptionRichLabel

@onready var session_label: Label = %SessionLabel
@onready var playtime_label: Label = %PlaytimeLabel

static var _LOGGER := Logging.get_logger("DetailUI")

const _SCENE = preload("uid://coektos3qbfg1")


# --- Methods ---

static func create_instance(id: String) -> DetailUI:
	var instance: DetailUI = _SCENE.instantiate()
	instance.entry = EntryManager.get_entry(id)

	return instance


func _update_cover_image() -> void:
	var tex := await self.entry.vn_info.get_cover_tex()
	if tex:
		self.cover_image_texture_rect.texture = tex
	else:
		_LOGGER.warn("failed to load image from '%s'" % self.entry.vn_info.cover_url)


## Refresh playtime & session count
func _update_playtime_n_session_count() -> void:
	var record := PlaytimeTracker.get_time_n_count(self.entry.id)

	self.playtime_label.text = (
		"%.1fh" % (record[0] / 3600.0) if record[0] > 1800 else "%.1fm" % (record[0] / 60.0)
	)
	self.session_label.text = str(record[1])


## Refresh UI to match self.entry
func _reflect_to_ui() -> void:

	# update executable path & start button if configured
	if self.entry.exec_path:

		self.exec_path_label.text = self.entry.exec_path
		self.launch_button.disabled = (
			not FileAccess.file_exists(self.entry.exec_path)
		)

	else:
		self.exec_path_label.text = "NOT SET"
		self.launch_button.disabled = true

	# set metadata
	self.description_rich_label.text = self.entry.vn_info.description
	self.developer_label.text = self.entry.vn_info.developers
	self.release_date_label.text = self.entry.vn_info.released
	self.title_label.text = self.entry.vn_info.title
	self.label_option_large.selected = self.entry.vn_info.label

	self._update_cover_image()

	# set VNDB link if id starts with v
	if self.entry.id.begins_with("v"):
		self.vndb_link.text = self.entry.vn_info.id
		self.vndb_link.uri = "https://vndb.org/" + self.entry.vn_info.id
	else:
		# TODO: hide if unset
		pass

	# free existing tags
	for child: Node in self.tag_container.get_children():
		child.queue_free()
		self.tag_container.remove_child(child)

	# populate tags
	for tag: String in self.entry.vn_info.tags.split(","):
		self.tag_container.add_child(TagUI.create_instance(tag))

	# update total runtime & sessions
	self._update_playtime_n_session_count()


# --- Handlers ---

func _ready() -> void:
	assert(self.entry, "No entry was provided for DetailUI")
	self._reflect_to_ui()


## Handler for BBCode hyperlink support
func _on_description_rich_label_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


func _on_edit_button_pressed() -> void:
	var instance := EditUI.create_instance(self.entry.id)
	instance.entry_saved.connect(self._on_entry_saved)

	self.add_sibling(instance)


## Called on EditUI.entry_saved
func _on_entry_saved(id: String) -> void:
	self.entry = EntryManager.get_entry(id)
	self._reflect_to_ui()


## Free self & emit entry id via signal
func _on_close_button_pressed() -> void:
	self.closed.emit(self.entry.id)
	self.queue_free()


func _on_label_option_large_item_selected(index: int) -> void:
	EntryManager.update_entry_play_status(self.entry.id, index)


func _on_delete_button_pressed() -> void:
	var instance := ConfirmationPopup.create_instance("Delete this novel?")
	instance.confirmed.connect(self._on_delete_confirmed)
	self.add_sibling(instance)


## Delete from db and signal & free self. Connected in runtime at _on_delete_button_pressed
func _on_delete_confirmed() -> void:
	EntryManager.remove_entry(self.entry.id)
	self._on_close_button_pressed()


func _on_launch_button_pressed() -> void:
	_LOGGER.info("Launching '%s'" % self.entry.exec_path)

	# TODO: add button change feature (to stop)
	if PlaytimeTracker.start_process(self.entry.id, self.entry.exec_path):
		pass

	# TODO: add noti on failure (e.g. IroHika_KR & AkaHito_KR requires admin priv. to godot)


func _on_playtime_update_timer_timeout() -> void:
	# if running request update
	if PlaytimeTracker.is_running(self.entry.id):
		self._update_playtime_n_session_count()
