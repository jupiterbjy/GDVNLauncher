extends CenterContainer
## Popup to get URL from user


# --- Signals ---

## Emitted once ok is pressed
signal url_selected(url: String)


# --- Attributes ---

@onready var _url_line_edit: LineEdit = %URLLineEdit


# --- Drivers ---

func _on_ok_button_pressed() -> void:
	self.url_selected.emit(self._url_line_edit.text.strip_edges())
	self.hide()


func _on_cancel_button_pressed() -> void:
	self.hide()
