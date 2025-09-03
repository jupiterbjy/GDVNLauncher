class_name CacheManager
## Caches various resources from web.

# TODO: add file date check and redownload


# --- Attributes ---

const WEB_CACHE_DIR := "user://cache_web/"
const LOCAL_CACHE_DIR := "user://cache_local/"

static var _LOGGER := Logging.get_logger("CacheManager")


# --- Methods ---

## Get resource from given url. Returns empty data if failed to fetch.
## Will consider empty file as failed download.
static func async_from_url(url: String, refresh_cache := false) -> PackedByteArray:

	# if ext exists good, if not welp
	var _cache_path := WEB_CACHE_DIR + url.sha256_text()

	if not refresh_cache:
		# EAFP-ish, sorta, something, idk. If it's empty it's doomed either way.
		var data := FileAccess.get_file_as_bytes(_cache_path)
		#if FileAccess.get_open_error() == Error.OK:
		if data:
			_LOGGER.debug("url '%s' cache hit" % url)
			return data

	# if it doesn't exist(or empty) download it first
	var resp := await AsyncHTTPClient.async_request(url)

	# if failed then rip, just return empty data
	if not resp.result == HTTPRequest.Result.RESULT_SUCCESS:
		_LOGGER.warn("Download from '%s' failed with %s" % [url, resp.response_code])
		return PackedByteArray()

	# store result. FileAccess closes automatically on context close
	_ensure_dir_exists(WEB_CACHE_DIR)

	var fp := FileAccess.open(_cache_path, FileAccess.WRITE)
	fp.store_buffer(resp.body)

	_LOGGER.debug("Download from '%s' Successful" % url)

	# m not sure if refcounted count attributes too but should't live too long
	return resp.body


## Get resource from given path. Returns empty data if failed to fetch.
## Will consider empty file as failed download.
## To ensure file is accessible even after source file is deleted, do not temper with cache.
static func from_local(path: String, refresh_cache := false) -> PackedByteArray:

	var _cache_path := LOCAL_CACHE_DIR + path.sha256_text()
	var data: PackedByteArray

	if not refresh_cache:
		data = FileAccess.get_file_as_bytes(_cache_path)
		if data:
			_LOGGER.debug("path '%s' cache hit" % path)
			return data

	# if it doesn't exist(or empty) fetch it first
	data = FileAccess.get_file_as_bytes(path)
	if not data:
		_LOGGER.warn("Fetch from '%s' failed, or file is empty?" % path)
		return PackedByteArray()

	_ensure_dir_exists(LOCAL_CACHE_DIR)

	var fp := FileAccess.open(_cache_path, FileAccess.WRITE)
	fp.store_buffer(data)

	_LOGGER.debug("Fetch from '%s' Successful" % path)

	return data


## Clear cache for given url/path. Preferrably only call this to remove that's not in use.
static func clear_cache(loc: String) -> void:

	var _cache_path := (
		(WEB_CACHE_DIR if loc.begins_with("http") else LOCAL_CACHE_DIR)
		+ loc.sha256_text()
	)

	if FileAccess.file_exists(_cache_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_cache_path))
		_LOGGER.debug("Dropped cache for '%s'" % loc)


# --- Utilities ---

## Ensure cache dir exists, someone might just delete it out of whim while running
static func _ensure_dir_exists(path: String) -> void:
	var result := DirAccess.make_dir_absolute(path)
	assert(
		result == Error.OK or result == Error.ERR_ALREADY_EXISTS,
		"Failed to create directory."
	)


## Test feature
static func _test() -> void:
	_LOGGER.debug("--- Test start ---")

	# Test CacheManager & AsyncHTTPClient
	var data = await CacheManager.async_from_url("https://t.vndb.org/cv/77/88277.jpg")
	var img := Image.new()
	img.load_jpg_from_buffer(data)

	_LOGGER.debug("Image Dim: %dx%d" % [img.get_width(), img.get_height()])

	_LOGGER.debug("--- Test Done ---")


# --- Handlers ---

static func _static_init() -> void:
	_test.call_deferred()
	pass
