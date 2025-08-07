class_name VndbVNInfo
## VNDB visual novel info dataclass


# --- Attributes ---

## VNDB ID
var id: String

## Romanized original title
var title: String

## Dict[language, title]
var titles: Dictionary[String, String]

var description: String
var released: String
var developers: Array[String]

var tags: Array[String]

var cover_url: String


# example json response from vndb
"""
{
	"description": "Our story follows Kanoue Yuuma, ...",
	"developers": [{"id": "p612", "name": "FAVORITE"}],
	"id": "v5834",
	"image": {"url": "https://t.vndb.org/cv/77/88277.jpg"},
	"released": "2011-07-29",
	"title": "Irotoridori no Sekai",
	"tags": [
		{"category": "cont", "id": "g2", "name": "Fantasy", "spoiler": 0},
		{"category": "tech", "id": "g133", "name": "Male Protagonist", "spoiler": 0},
		...
	]
}

{
	"id":"v17147",
	"title":"Akai Hitomi ni Utsuru Sekai",
	"titles":[
		{"lang":"ja","title":"紅い瞳に映るセカイ"},
		{"lang":"ko","title":"붉은 눈동자에 비치는 세계"},
		{"lang":"zh-Hans","title":"映入红瞳的世界"}
	]
}
"""


# --- Constructors ---

func _init(
	id_: String = "",
	title_: String = "",
	description_: String = "",
	released_: String = "",
	developers_: Array[String] = [],
	tags_: Array[String] = [],
	cover_url_: String = "",
) -> void:
	# I miss TypedDicts

	self.id = id_
	self.title = title_
	self.description = description_
	self.released = released_
	self.developers = developers_
	self.tags = tags_
	self.cover_url = cover_url_


## Create new VNData instance from vndb's json response
static func from_vndb(json: Dictionary) -> VndbVNInfo:

	# seriously idk if I should store all tag and have spoiler filtering or not
	# gonna just keep content tags without spoilers which is still plently cause
	# there's already freakin 26 tags with that condition for v5834...
	var _tags: Array[String]

	for tag in json["tags"]:
		if tag["category"] == "cont" and tag["spoiler"] == 0:
			_tags.append(tag["name"])

	var _devs: Array[String]

	for dev: Dictionary in json["developers"]:
		_devs.append(dev["name"])

	var instance := VndbVNInfo.new(
		json["id"],
		json["title"],
		json["description"],
		json["released"],
		_devs,
		_tags,
		json["image"]["url"],
	)

	# add per lang titles
	for dict: Dictionary in json["titles"]:
		instance.titles[dict["lang"]] = dict["title"]

	return instance
