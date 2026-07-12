class_name VNEntryUI
extends PanelContainer


# --- Signals ---

## Emitted when cover is clicked
signal cover_clicked(id: String)


# --- Attributes ---

## VNDB ID or custom ID
var entry: EntryManager.Entry = null

@onready var _cover_texture_rect: TextureRect = %CoverTextureRect

@onready var _label_option: OptionButton = %LabelOption

@onready var _playtime_label: Label = %PlaytimeLabel

@onready var _current_playtime_label: Label = %CurrentPlaytimeLabel

@onready var _play_status_overlay: PanelContainer = %PlayStatusOverlay

var is_playable: bool:
	get():
		return false if not entry else len(entry.exec_path) > 0

## Used to decide whether to reload image or not
var _current_img_url: String = ""

static var _LOGGER := Logging.get_logger("VNEntryUI")

const _SCENE = preload("uid://b3xdas536yxk6")


# --- Methods ---

static func create_instance(entry_: EntryManager.Entry) -> VNEntryUI:
	var instance: VNEntryUI = _SCENE.instantiate()
	instance.entry = entry_

	return instance


## Load and apply data from db index. Returns false on failure
func async_reload() -> bool:
	_LOGGER.debug("Reloading %s" % self.entry)

	self.entry = EntryManager.get_entry(self.entry.id)

	# if failed it's deleted
	if not entry:
		return false

	self._label_option.selected = self.entry.vn.label

	if self._current_img_url != self.entry.vn.cover_url:
		self._current_img_url = self.entry.vn.cover_url
		self._cover_texture_rect.texture = await self.entry.vn.get_cover_tex()

	self.update_playtime_from_db()
	self.update_playtime_live()

	return true


## Update playtime from DB
func update_playtime_from_db() -> void:
	var record := PlaytimeTracker.get_proc_time_n_count(self.entry.id)

	self._playtime_label.text = (
		"%.1fh (%d)" % [(record[0] / 3600.0), record[1]]
		if record[0] > 1800
		else "%.1fm (%d)" % [(record[0] / 60.0), record[1]]
	)


## Update current session's playtime
func update_playtime_live() -> void:

	if not PlaytimeTracker.is_running(self.entry.id):
		self._play_status_overlay.hide()
		return

	self._current_playtime_label.text = Time.get_time_string_from_unix_time(
		floori(PlaytimeTracker.get_proc_current_session_time(self.entry.id))
	)
	self._play_status_overlay.show()


# --- Handlers ---

func _ready() -> void:
	# must be placeholder for UI design, free self
	#if not self.entry:
		#self.queue_free()
		#return

	# otherwise load
	# TODO: see if this need to be deferred
	#await self.async_reload()
	pass


func _on_status_option_button_item_selected(index: int) -> void:
	self.entry.vn.label = index
	EntryManager.upsert_entry(self.entry)


func _on_mouse_entered() -> void:
	self.modulate = Color(1.2, 1.2, 1.2)


func _on_mouse_exited() -> void:
	self.modulate = Color.WHITE


func _on_gui_input(event: InputEvent) -> void:

	# if option is hovered or expanded ignore
	if (
		self._label_option.is_hovered()
		or self._label_option.get_popup().visible
	):
		return

	# detect non-cover clicks
	if event.is_action_pressed("mouse_l"):
		self.cover_clicked.emit(self.entry.id)
