extends Node
## Holds user configurations. All config values must be a string.


# --- Atrributes ---

const _CONFIG_TEMPLATE: Dictionary[StringName, Variant] = {
	&"title_lang": "en",
	&"vndb_token": "",
	&"vndb_tag_min_rating": 2.1,
	&"vndb_tag_types": "cont",
	&"poll_interval": 3000,
	&"custom": {},
}

## Raw JSON Config as it was annoying to manage stuffs
## Performance will be shete but less annoying for me
## Performance will be shete but less annoying for me
var _config_raw: Dictionary[StringName, Variant] = _CONFIG_TEMPLATE.duplicate_deep()

## Preferred title language
var title_lang: String:
	get():
		return self._config_raw[&"title_lang"]
	
	set(val):
		self._config_raw[&"title_lang"] = val


## VNDB Token. Will be used to sync play status to VNDB in turue
var vndb_token: String:
	get():
		return self._config_raw[&"vndb_token"]
	
	set(val):
		self._config_raw[&"vndb_token"] = val


## Config used to remove VNDB tags below given score.
var vndb_tag_min_rating: float:
	get():
		return self._config_raw[&"vndb_tag_min_rating"]
	
	set(val):
		self._config_raw[&"vndb_tag_min_rating"] = val


#var vndb_tag_max_spoiler: int = 0


# wish to use bitflag or enum but that would be unreadable
## Config used to filter VNDB tags via type. Comma Separated.
var vndb_tag_types: String:
	get():
		return self._config_raw[&"vndb_tag_types"]
	
	set(val):
		self._config_raw[&"vndb_tag_types"] = val


## Config used to determine playtime polling interval in msec
var poll_interval: int:
	get():
		return self._config_raw[&"poll_interval"]

	set(val):
		self._config_raw[&"poll_interval"] = val


## Per UI config
var custom: Dictionary:
	get():
		return self._config_raw[&"custom"]


## Non-saved param
var _user_id: String = ""

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
	
	# wont factor in for arr json case..
	var data: Dictionary = JSON.parse_string(fp.get_as_text())
	if not data:
		_LOGGER.error("Config file parsing failed")
		return false

	# simple sanity check on keys
	for key: StringName in (data as Dictionary):

		if key not in _CONFIG_TEMPLATE:
			_LOGGER.warn("Unknown key %s found while loading; Skipping" % key)
			continue

		var self_t := typeof(_CONFIG_TEMPLATE[key])
		var saved_t := typeof((data as Dictionary)[key])

		# if not same type but neither both are numbers throw tantrum
		if (
			self_t != saved_t
			and not (
				(self_t == Variant.Type.TYPE_INT or self_t == Variant.Type.TYPE_FLOAT)
				and (saved_t == Variant.Type.TYPE_INT or saved_t == Variant.Type.TYPE_FLOAT)
			)
		):
			_LOGGER.warn(
				"Found key %s with mismatching type (%s!=%s) while loading; Skipping" % [
					key, self_t, saved_t,
				]
			)
			continue
		
		self._config_raw[key] = data[key]
	
	_LOGGER.info("Load success")
	return true


## Save config. Returns false on failure.
func save_config() -> bool:

	var fp := FileAccess.open(_CONFIG_PATH, FileAccess.WRITE)
	if not fp:
		_LOGGER.warn("Can't open config file; Ignore this for first run")
		return false

	var config: Dictionary[String, Variant]

	for key in _CONFIG_TEMPLATE:
		config[key] = self.get(key)

	fp.store_string(JSON.stringify(config))

	_LOGGER.info("Save success")
	return true


## Fetch user id from token. Returns empty string on failure.
func async_get_user_id(force_refresh := false) -> String:

	# if cached use it
	if not force_refresh and self._user_id:
		return self._user_id

	# if no token fail fast
	if not self.vndb_token:
		return ""

	var resp := await VNDBClient.async_get_auth_info(self.vndb_token)

	if not resp:
		return ""

	# cache & return
	self._user_id = resp.id
	return resp.id


# --- Handlers ---

func _init() -> void:
	self.load_config()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		self.save_config()
