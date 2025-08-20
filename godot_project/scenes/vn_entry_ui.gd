class_name VNEntryUI
extends PanelContainer


# --- Signals ---

## Emitted when cover is clicked
signal cover_clicked(id: String)


# --- Attributes ---

## VNDB ID or custom ID
var id: String = ""

@onready var _cover_button: TextureButton = %CoverButton

@onready var status_option_button: OptionButton = %StatusOptionButton

@onready var playtime_label: Label = %PlaytimeLabel

## Used to decide whether to reload image or not
var _current_img_url: String = ""

static var _LOGGER := Logging.get_logger("VNEntryUI")

const _SCENE = preload("uid://b3xdas536yxk6")


# --- Methods ---

## Load and apply data from db index. Returns false on failure
func reload() -> bool:
	_LOGGER.debug("Reloading id=%s" % self.id)

	var entry := EntryManager.get_entry(self.id)

	# if failed it's deleted
	if not entry:
		return false

	# TODO: add playtime reload

	self.status_option_button.selected = entry.play_status

	if self._current_img_url != entry.vn_info.cover_url:
		self._current_img_url = entry.vn_info.cover_url
		self._cover_button.texture_normal = await entry.vn_info.get_cover_tex()

	return true


static func create_instance(id_: String) -> VNEntryUI:
	var instance: VNEntryUI = _SCENE.instantiate()
	instance.id = id_

	return instance


# --- Handlers ---

func _ready() -> void:
	ControlUtils.option_button_hide_radio(self.status_option_button)

	# must be placeholder for UI design, free self
	if not self.id:
		self.queue_free()
		return

	# otherwise load
	# TODO: see if this need to be deferred
	await self.reload()


func _on_status_option_button_item_selected(index: int) -> void:
	EntryManager.update_entry_play_status(self.id, index)


func _on_cover_button_pressed() -> void:
	self.cover_clicked.emit(self.id)
