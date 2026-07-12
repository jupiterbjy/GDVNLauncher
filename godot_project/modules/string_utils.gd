class_name StringUtils


# --- Attritbutes ---

## Pattern for sanitizing string to eng, ascii and '- +='
static var _RE_ASCII_FILTER := RegEx.new()


# --- Methods ---

## Sanitize string to ASCII range
static func sanitize_to_ascii(string: String) -> String:
	var parts: Array[String]

	for result in _RE_ASCII_FILTER.search_all(string):
		parts.append(result.get_string())

	return "".join(parts)


## CSV with edge stripping
static func csv_sep(string: String, allow_empty: bool, sep := ",") -> PackedStringArray:
	var result: PackedStringArray

	for val: String in string.strip_edges().split(sep, allow_empty):
		result.append(val.strip_edges())

	return result


# --- Handlers ---

static func _static_init() -> void:
	_RE_ASCII_FILTER.compile("[ -~]")
