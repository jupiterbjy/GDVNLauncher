class_name ControlUtils
## Control node utilities


# https://www.reddit.com/r/godot/comments/oz45zd/comment/h7x8iav
static func option_button_hide_radio(option_button: OptionButton) -> void:
	var pm: PopupMenu = option_button.get_popup()
	for i in pm.get_item_count():
		if pm.is_item_radio_checkable(i):
			pm.set_item_as_radio_checkable(i, false)
