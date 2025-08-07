class_name VNDBClient
## Not really a 'client' - but still wraps VNDB API.


# --- Attributes ---

const _INFO_REQ_DATA_TEMPLATE: String = """
{
	"filters": ["id", "=", "%s"],
	"fields": "title, released, developers.name, image.url, description, tags.name, tags.spoiler, tags.category, titles.lang, titles.title"
}
"""

const _USER_AGENT: String = "User-Agent: GDVNLauncher/0.0"

"""
❯ curl https://api.vndb.org/kana/vn --header 'Content-Type: application/json' --data '{
>     "filters": ["id", "=", "v5834"],
>     "fields": "title, released, developers.name, image.url, description, tags.name, tags.spoiler, tags.category"
> }' > output.json

{
  "more": false,
  "results": [
    {
      "description": "Our story follows Kanoue Yuuma, ...",
      "developers": [{"id": "p612", "name": "FAVORITE"}],
      "id": "v5834",
      "image": {"url": "https://t.vndb.org/cv/77/88277.jpg"},
      "released": "2011-07-29",
      "title": "Irotoridori no Sekai",
      "tags": [
        {"category": "cont", "id": "g2", "name": "Fantasy", "spoiler": 0},
        {"category": "tech", "id": "g133", "name": "Male Protagonist", "spoiler": 0}
      ]
    }
  ]
}
"""

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


## Get entry information from vndb. Returns null on failure
static func async_post_vn(vndb_id: String) -> VndbVNInfo:
	# TODO: test nonexistent case and workaround it

	var resp := await AsyncHTTPClient.async_request(
		"https://api.vndb.org/kana/vn",
		["Content-Type: application/json"],
		HTTPClient.Method.METHOD_POST,
		_INFO_REQ_DATA_TEMPLATE % vndb_id,
	)

	if resp.result != HTTPRequest.Result.RESULT_SUCCESS:
		return null

	var data: String = resp.body.get_string_from_utf8()
	var parsed: Dictionary = JSON.parse_string(data)

	return VndbVNInfo.from_vndb(parsed["results"][0])


## Get user name via user id
static func async_get_user(u_id: String) -> String:
	# TODO: test nonexistent case and workaround it

	var resp := await AsyncHTTPClient.async_request(
		"https://api.vndb.org/kana/user?q=%s" % u_id
	)

	var data: String = resp.body.get_string_from_utf8()
	var parsed: Dictionary = JSON.parse_string(data)

	return parsed[u_id]["username"]


## Get user auth info via token
static func async_get_auth_info(token: String) -> VndbAuthInfo:
	# TODO: test nonexistent case and workaround it

	var resp := await AsyncHTTPClient.async_request(
		"https://api.vndb.org/kana/authinfo",
		["Authorization: token " + token],
	)

	var data: String = resp.body.get_string_from_utf8()
	var parsed: Dictionary = JSON.parse_string(data)

	return VndbAuthInfo.from_vndb(parsed)


# --- Drivers ---

static func _static_init() -> void:
	_VN_ID_VALIDATE_PATTERN.compile("^v[0-9]*$")
	_USER_ID_VALIDATE_PATTERN.compile("^u[0-9]*$")
