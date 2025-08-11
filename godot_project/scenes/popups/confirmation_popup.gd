class_name ConfirmationPopup
extends CenterContainer
## Popup to get user confirmation


# --- Signals ---

## Emitted once ok is pressed
signal confirmed


# --- Attritbutes ---

var _text: String
@onready var _label: Label = %Label

const _SCENE = preload("uid://dk6qygmhxq72g")


# --- Methods ---

static func create_instance(text: String) -> ConfirmationPopup:
	var instance: ConfirmationPopup = _SCENE.instantiate()
	instance._text = text

	return instance


# --- Drivers ---

func _ready() -> void:
	self._label.text = self._text


func _on_ok_button_pressed() -> void:
	self.confirmed.emit()
	self.queue_free()


func _on_cancel_button_pressed() -> void:
	self.queue_free()
