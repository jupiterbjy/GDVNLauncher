class_name TagUI
extends Label
## Represents a tag


const _SCENE = preload("uid://bu7ymo1b0i052")


static func create_instance(txt: String) -> TagUI:
	var instance: TagUI = _SCENE.instantiate()
	instance.text = txt

	return instance
