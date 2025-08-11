extends Node
## Some dumb global HTTP request manager


 # --- Classes ---

## Response dataclass. I miss TypedDict
class Response:
	var result: int
	var response_code: int
	var headers: PackedStringArray
	var body: PackedByteArray

	func _init(
		result_: HTTPRequest.Result, response_code_: int, headers_, body_: PackedByteArray
	) -> void:
		self.result = result_
		self.response_code = response_code_
		self.headers = headers_
		self.body = body_


## Request dataclass. Await for response by `done` signal.
#class Request:
	#var method: HTTPClient.Method
	#var url: String
	#var headers: PackedStringArray
	#var body: PackedByteArray
	## I don't think we'll never send raw bytes to vndb
#
	### Emitted once request is processed. Contains response.
	#signal done(resp: Response)
#
	#func _init(
		#method_: HTTPClient.Method, url_: String, headers_: PackedStringArray, body_: PackedByteArray
	#) -> void:
		#self.method = method_
		#self.url = url_
		#self.headers = headers_
		#self.body = body_


# --- Attributes ---

"""
Receiving
{'Accept': '*/*',
 'Accept-Encoding': 'gzip, deflate',
 'Directory': '/',
 'HTTP': 'HTTP/1.1',
 'Host': '127.0.0.1:8080',
 'Method': 'GET',
 'User-Agent': 'GodotEngine/4.5.beta4.official (Windows)'}
Received

Responding ---
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 9013
Connection: close


--- Body length: 9013
Response sent
"""

static var _LOGGER := Logging.get_logger("AsyncHTTPClient")

# since I can't access HTTPClient.Method directly...
const _METHOD_NAMES: PackedStringArray = [
	"GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE", "CONNECT", "PATCH"
]

# --- Methods ---

## Create new request and return result asynchronously, since signal connecting is annoying
func async_request(
	url: String,
	headers: PackedStringArray = [],
	method: HTTPClient.Method = HTTPClient.Method.METHOD_GET,
	body: String = "",
) -> Response:

	var http_req := HTTPRequest.new()
	self.add_child(http_req)

	http_req.request(
		url, headers, method, body
	)
	_LOGGER.debug("Request [%s] to [%s], body: %s" % [_METHOD_NAMES[method], url, body])

	# await signal directly and fetch parameters as array
	var resp_arr: Array = await http_req.request_completed
	var resp := Response.new(resp_arr[0], resp_arr[1], resp_arr[2], resp_arr[3])

	_LOGGER.debug("Received [%d] from [%s], body: %d bytes" % [resp.response_code, url, len(resp.body)])

	return resp


## Create new request and return result asynchronously, since signal connecting is annoying
func async_request_raw(
	url: String,
	headers: PackedStringArray = [],
	method: HTTPClient.Method = HTTPClient.Method.METHOD_GET,
	body: PackedByteArray = [],
) -> Response:

	var http_req := HTTPRequest.new()
	self.add_child(http_req)

	http_req.request_raw(
		url, headers, method, body
	)
	_LOGGER.debug("Request [%s] %s, body: %d bytes" % [_METHOD_NAMES[method], url, len(body)])

	# await signal directly and fetch parameters as array
	var resp: Array = await http_req.request_completed

	return Response.new(resp[0], resp[1], resp[2], resp[3])
