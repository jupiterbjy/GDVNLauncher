class_name VndbAuthInfo
## VNDB Auth info dataclass


# --- Attributes ---

var id: String
var username: String
var permissions: Array[StringName]

## Does this token has read perm?
var read: bool:
	get():
		return &"listread" in self.permissions

## Does this token has write perm?
var write: bool:
	get():
		return &"listwrite" in self.permissions


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
		json["id"] as String,
		json["username"] as String,
		json["permissions"] as Array,
	)


# --- Handlers ---

func _init(
	id_: String = "",
	username_: String = "",
	permissions_: Array = [],
) -> void:

	self.id = id_
	self.username = username_
	self.permissions.assign(permissions_)
