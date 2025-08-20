class_name VNDBClient
## Not really a 'client' - but still wraps VNDB API.


# --- Attributes ---

static var _VN_FIELD: String = """
"title, titles.lang, titles.title,
released,
developers.name,
image.thumbnail,
description,
tags.name, tags.spoiler, tags.category, tags.rating
""".replace("\n", "")


static var _POST_VN_TEMPLATE: String = """
{
	"filters": ["id", "=", "%s"],
	"fields": VN_FIELD
}
""".strip_edges().replace("VN_FIELD", _VN_FIELD)

#const _USER_AGENT: String = "User-Agent: GDVNLauncher/0.0"

## VNDB POST /ulist template
static var _POST_ULIST_TEMPLATE: String = """
{
	"user": "%s",
	"fields": VN_FIELD,
	"sort": "added",
	"results": 75,
	"page": %d
}
""".strip_edges().replace("VN_FIELD", _VN_FIELD)

static var _VN_ID_VALIDATE_PATTERN := RegEx.new()
static var _USER_ID_VALIDATE_PATTERN := RegEx.new()


# --- Methods ---

## Basic vn id validation
static func validate_vn_id(id: String) -> bool:
	var matched := _VN_ID_VALIDATE_PATTERN.search(id)
	return matched and matched.get_string() == id


## Basic user id validation
static func validate_user_id(id: String) -> bool:
	var matched := _USER_ID_VALIDATE_PATTERN.search(id)
	return matched and matched.get_string() == id


## Get entry information from vndb. Returns null on failure.
static func async_post_vn(
	vndb_id: String,
	title_lang: String,
	tag_min_rating: float = 2.1,
	tag_max_spoiler: int = 0,
	tag_types: String = "cont",
) -> VndbVNInfo:
	# TODO: test nonexistent case and workaround it

	var resp := await AsyncHTTPClient.async_request(
		"https://api.vndb.org/kana/vn",
		["Content-Type: application/json"],
		HTTPClient.Method.METHOD_POST,
		_POST_VN_TEMPLATE % vndb_id,
	)

	if resp.response_code != 200:
		return null

	var data: String = resp.body.get_string_from_utf8()
	var parsed: Dictionary = JSON.parse_string(data)

	return VndbVNInfo.from_vndb(
		parsed["results"][0],
		title_lang,
		tag_min_rating,
		tag_max_spoiler,
		tag_types,
	)


## Get user name via user id. Returns emptry string on failure
static func async_get_user(u_id: String) -> String:
	# TODO: test nonexistent case and workaround it

	var resp := await AsyncHTTPClient.async_request(
		"https://api.vndb.org/kana/user?q=%s" % u_id
	)

	if resp.response_code != 200:
		return ""

	var data: String = resp.body.get_string_from_utf8()
	var parsed: Dictionary = JSON.parse_string(data)

	return parsed[u_id]["username"]


## Get user auth info via token. Returns null on failure.
static func async_get_auth_info(token: String) -> VndbAuthInfo:
	# TODO: test nonexistent case and workaround it

	var resp := await AsyncHTTPClient.async_request(
		"https://api.vndb.org/kana/authinfo",
		["Authorization: token " + token],
	)

	if resp.response_code != 200:
		return null

	var data: String = resp.body.get_string_from_utf8()
	var parsed: Dictionary = JSON.parse_string(data)

	return VndbAuthInfo.from_vndb(parsed)


## Get user vn list
static func async_get_ulist(
	u_id: String,
	title_lang: String,
	tag_min_rating: float = 2.1,
	tag_max_spoiler: int = 0,
	tag_types: String = "cont",
) -> Array[VndbVNInfo]:

	var results: Array[VndbVNInfo]
	var page: int = 0

	while true:
		page += 1

		var resp := await AsyncHTTPClient.async_request(
			"https://api.vndb.org/kana/ulist",
			["Content-Type: application/json"],
			HTTPClient.Method.METHOD_POST,
			_POST_ULIST_TEMPLATE % [u_id, page]
		)

		# on failure return results accumulated so far
		if resp.response_code != 200:
			return results

		var data: String = resp.body.get_string_from_utf8()
		var parsed: Dictionary = JSON.parse_string(data)

		# TODO: get as variant and check for null
		for vn_data: Dictionary in parsed["results"]:
			results.append(
				VndbVNInfo.from_vndb(
					vn_data,
					title_lang,
					tag_min_rating,
					tag_max_spoiler,
					tag_types,
				)
			)

		# if result is drained, end here
		if not parsed["more"]:
			return results

	return results


# --- Hanlders ---

static func _static_init() -> void:
	_VN_ID_VALIDATE_PATTERN.compile("^v[0-9]*$")
	_USER_ID_VALIDATE_PATTERN.compile("^u[0-9]*$")
