class_name VndbAuthInfo
## VNDB Auth info dataclass


# --- Attributes ---

## user id
var id: String
var username: String
var permissions: Array[StringName]


const PERMISSION_LIST_READ := &"listread"
const PERMISSION_LIST_WRITE := &"listwrite"


# example json response from vndb
"""
{
	"id": "u291709",
	"permissions": [
		"listread",
		"listwrite"
	],
	"username": "jupiterbjy"
}
"""


# --- Methods ---

## Named Constructor to create new VNData instance from vndb's json response
static func from_vndb(json: Dictionary) -> VndbAuthInfo:
	return VndbAuthInfo.new(
		json["id"],
		json["username"],
		json["permissions"],
	)


# --- Handlers ---

func _init(
	id_: String = "",
	username_: String = "",
	permissions_: Array[StringName] = [],
) -> void:

	self.id = id_
	self.username = username_
	self.permissions = permissions_
