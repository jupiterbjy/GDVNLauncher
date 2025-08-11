extends Node
## Holds user configurations. All config values must be a string.


# --- Atrributes ---

var title_lang: String = "en"

## VNDB Token. Will be used to sync play status to VNDB in turue
var vndb_token: String = ""

## Config used to remove VNDB tags below given score.
var vndb_tag_min_rating: float = 2.1

#var vndb_tag_max_spoiler: int = 0

## Config used to filter VNDB tags via type. Comma Separated.
var vndb_tag_types: String = "cont"
#var vndb_tag_types: Array[String] = ["cont"]
# wish to use bitflag or enum but that would be unreadable

## Config used to determine playtime polling interval in msec
var poll_interval: int = 3000

## Attribute whitelist for config. Since it's more annoying to make a lot of properties!
const _ATTR_WHITELIST: Array[StringName] = [
	"title_lang",
	"vndb_token",
	"vndb_tag_min_level",
	#"vndb_tag_max_spoiler",
	"vndb_tag_type",
	"poll_interval",
]

## Path to configuration file
const _CONFIG_PATH := "user://config.json"

static var _LOGGER := Logging.get_logger("UserConfig")


# --- Methods ---

## Load config. Returns false on failure.
func load_config() -> bool:

	var fp := FileAccess.open(_CONFIG_PATH, FileAccess.READ)
	if not fp:
		_LOGGER.info("Config file open failed; This is normal for first run")
		return false

	# if parsing failes or has invalid data abort
	var data = JSON.parse_string(fp.get_as_text())
	if not data or data is not Dictionary:
		_LOGGER.warn("Config file parsing failed")
		return false

	# fetch values
	for key in (data as Dictionary):

		if key not in _ATTR_WHITELIST:
			_LOGGER.warn("Unknown key %s found while loading; Skipping" % key)
			continue

		if typeof(self.get(key)) != typeof((data as Dictionary)[key]):
			_LOGGER.warn("Found key %s with mismatching type while loading; Skipping" % key)
			continue

		self.set(key, (data as Dictionary)[key])

	_LOGGER.info("Load success")
	return true


## Save config. Returns false on failure.
func save_config() -> bool:

	var fp := FileAccess.open(_CONFIG_PATH, FileAccess.WRITE)
	if not fp:
		_LOGGER.warn("Can't open config file; Ignore this for first run")
		return false

	var config: Dictionary[String, Variant]

	for key in _ATTR_WHITELIST:
		config[key] = self.get(key)

	fp.store_string(JSON.stringify(config))

	_LOGGER.info("Save success")
	return true


# --- Drivers ---

func _init() -> void:
	self.load_config()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		self.save_config()
