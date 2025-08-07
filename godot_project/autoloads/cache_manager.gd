extends Node
## Caches various resources from web.

# TODO: add file date check and redownload


# --- Attributes ---

const _CACHE_DIR := "user://cache/"

static var _LOGGER := Logging.get_logger("CacheManager")


# --- Methods ---

## Get resource from given url. Returns empty data if failed to fetch.
## Will consider empty file as failed download.
func async_from_url(url: String, force_redownload := false) -> PackedByteArray:

	# if ext exists good, if not welp
	var _path := _CACHE_DIR + url.sha256_text()

	if not force_redownload:
		# EAFP-ish, sorta, something, idk. If it's empty it's doomed either way.
		var data := FileAccess.get_file_as_bytes(_path)
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
	self._ensure_dir_exists()

	var fp := FileAccess.open(_path, FileAccess.WRITE)
	fp.store_buffer(resp.body)

	_LOGGER.debug("Download from '%s' Successful" % url)

	# m not sure if refcounted count attributes too but should't live too long
	return resp.body


# --- Utilities ---

## Ensure cache dir exists, someone might just delete it out of whim while running
static func _ensure_dir_exists() -> void:
	var result := DirAccess.make_dir_absolute(_CACHE_DIR)
	assert(
		result == Error.OK or result == Error.ERR_ALREADY_EXISTS,
		"Failed to create directory."
	)


## Generate cached(or to be cached) path from given url, with extension
#static func _url_to_cached_path_w_ext(url: String) -> String:
	#var last := url.split("/")[-1]
	#var ext := ("." + last.split(".")[-1]) if "." in last else ""
#
	#return _CACHE_DIR + last + ext
