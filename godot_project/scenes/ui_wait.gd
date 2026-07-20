extends PanelContainer
class_name UIWait
## Just a waiting screen


# --- Signals ---


# --- Attributes ---

@onready var _progress_bar: TextureProgressBar = %TextureProgressBar

## Injected by manager
var ui_manager: UIStackManager = null

## Bitmask of UiStackManager.UI_* flags. Set to customize stack behavior.
var ui_flags: int = UIStackManager.UI_POPUP

## Preloaded or statically loaded scene
const _SCENE: PackedScene = preload("res://scenes/ui_wait.tscn")


# --- Interfaces ---

## Scene instancer. Change return type & param.
static func create_instance() -> UIWait:
	var instance: UIWait = _SCENE.instantiate()
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

func set_progress_by_percent(perc: float) -> void:
	self._progress_bar.value = clampf(perc, 0, 1)
	if perc == 1.0:
		self.ui_manager.pop_ui()


func set_progress_by_count(total: int, done: int) -> void:
	self.set_progress_by_percent(float(done) / float(total))


# --- Handlers ---

func _ready() -> void:
	self._progress_bar.value = 0
