class_name VndbVNInfo
## VNDB visual novel info dataclass


# --- Attributes ---

# TODO: convert this to store dict directly and access via properties instead

## VNDB ID
var id: String

var title: String

var description: String
var released: String
var developers: String

var tags: String

var cover_url: String


# example json response from vndb
"""
{
	"description": "Our story follows Kanoue Yuuma ...",
	"developers": [{"id": "p612","name": "FAVORITE"}],
	"id": "v5834",
	"image": {
		"url": "https://t.vndb.org/cv/77/88277.jpg",
		"thumbnail": "https://t.vndb.org/cv.t/77/88277.jpg"
	},
	"released": "2011-07-29",
	"tags": [
		{
			"category": "tech",
			"id": "g1335",
			"name": "Central Heroine",
			"rating": 2.85714292526245,
			"spoiler": 2
		},
		...
	],
	"title": "Irotoridori no Sekai",
	"titles": [
		{"lang": "en","title": "Irotoridori No Sekai - The Colorful World"},
		{"lang": "ja","title": "いろとりどりのセカイ"},
		{"lang": "ko","title": "형형색색의 세계"},
		{"lang": "zh-Hans","title": "五彩斑斓的世界"}
	]
}
"""


# --- Methods ---

## Named Constructor to create new VNData instance from DB Record
static func from_db(record: Dictionary) -> VndbVNInfo:
	return VndbVNInfo.new(
		record["id"],
		record["title"],
		record["description"],
		record["released"],
		record["developers"],
		record["tags"],
		record["cover_url"],
	)


## Named Constructor to create new VNData instance from vndb's json response
static func from_vndb(
	json: Dictionary,
	title_lang: String,
	tag_min_rating: float,
	tag_max_spoiler: int,
	tag_types: String,
) -> VndbVNInfo:

	var type_filter := tag_types.split(",")

	# seriously idk if I should store all tag and have spoiler filtering or not
	# gonna just keep content tags without spoilers which is still plently cause
	# there's already freakin 26 tags with that condition for v5834...
	var _tags: Array[String]

	for tag in json["tags"]:
		if (
			tag["category"] in type_filter
			and tag["spoiler"] <= tag_max_spoiler
			and tag["rating"] >= tag_min_rating
		):
			_tags.append(tag["name"])

	var _devs: Array[String]

	for dev: Dictionary in json["developers"]:
		_devs.append(dev["name"])

	var titles: Dictionary[String, String]
	for dict: Dictionary in json["titles"]:
		titles[dict["lang"]] = dict["title"]

	var instance := VndbVNInfo.new(
		json["id"],
		titles[title_lang] if title_lang in titles else json["title"],
		json["description"],
		json["released"],
		",".join(_devs),
		",".join(_tags),
		#json["image"]["url"],
		json["image"]["thumbnail"],
	)

	return instance


## Fetch cover image from given url or from cache. Returns null on failure.
func get_cover_tex(refresh_cache := false) -> ImageTexture:
	if not self.cover_url:
		return null

	var bytes: PackedByteArray = (
		(await CacheManager.async_from_url(self.cover_url, refresh_cache))
		if self.cover_url.begins_with("http")
		else CacheManager.from_local(self.cover_url)
		# we don't refresh local cache, it might get lost...
	)

	# no need for size check, ImageLoader Already does that
	return ImageLoader.bytes_to_tex(bytes)


# --- Handlers ---

func _init(
	id_: String = "",
	title_: String = "",
	description_: String = "",
	released_: String = "",
	developers_: String = "",
	tags_: String = "",
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


func _to_string() -> String:
	return "VndbVNInfo(id=%s)" % self.id
