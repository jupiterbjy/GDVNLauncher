extends Control
## Template for all UI nodes managed by UiStackManager autoload.
## All methods and variables are optional


# --- Signals ---


# --- Attributes ---

## Injected by manager
var ui_manager: UIStackManager = null

## Bitmask of UiStackManager.UI_* flags. Set to customize stack behavior.
var ui_flags: int = 0

## Preloaded or statically loaded scene
const _SCENE: PackedScene = null


# --- Interfaces ---

## Scene instancer. Change return type & param.
static func create_instance() -> Control:
	var instance: Control = _SCENE.instantiate()
	return instance


## Return false to abort stacking (the new UI will be freed and previous resumed).
func start() -> bool:
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
	}


# --- Methods ---


# --- Handlers ---
