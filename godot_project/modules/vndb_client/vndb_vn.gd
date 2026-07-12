class_name VndbVN
## VNDB visual novel info dataclass


# --- Attributes ---

## Actual data dict. This overhead is bloated af compared to previous versions.
## But is easier to expand & pass around, between other interfaces...
var raw_dict: Dictionary[String, Variant]

## VNDB ID
var id: String:
	get():
		return self.raw_dict.get_or_add("id", "")

	set(val):
		self.raw_dict["id"] = val

## Primary title
var title: String:
	get():
		return self.raw_dict.get_or_add("title", "")

	set(val):
		self.raw_dict["title"] = val
		self.update_search_str()

## Alternative title per language.
## Do note this returns COPY of actual data, so make sure to overwrite this.
var lang_title_map: Dictionary[String, String]:
	get():
		var temp: Dictionary[String, String]
		temp.assign(self.raw_dict.get_or_add("lang_title_map", temp) as Dictionary)
		return temp

	set(val):
		self.raw_dict["lang_title_map"] = val
		self.update_search_str()

var description: String:
	get():
		return self.raw_dict.get_or_add("description", "")

	set(val):
		self.raw_dict["description"] = val

var released: String:
	get():
		return self.raw_dict.get_or_add("released", "")

	set(val):
		self.raw_dict["released"] = val

## Comma sep devs
var developers: PackedStringArray:
	get():
		var temp: PackedStringArray
		var data: Variant = self.raw_dict.get_or_add("developers", temp)

		# validate if it's < 0.0.1 data format with raw csv string.
		# then just return whole string without trying to separate that mess
		return [data] if data is String else data

	set(val):
		self.raw_dict["developers"] = val

## Comma sep tags
var tags: PackedStringArray:
	get():
		var temp: PackedStringArray
		var data: Variant = self.raw_dict.get_or_add("tags", temp)

		# validate if it's < 0.0.1 data format with raw csv string
		if data is not String:
			return data

		return StringUtils.csv_sep(data as String, false)

	set(val):
		self.raw_dict["tags"] = val

var cover_url: String:
	get():
		return self.raw_dict.get_or_add("cover_url", "")

	set(val):
		self.raw_dict["cover_url"] = val

## Active label for this vn. Wont think about multi label situation with id < 7
var label: int:
	get():
		return self.raw_dict.get_or_add("label", "")

	set(val):
		self.raw_dict["label"] = val

## for faster title search.
## This basically append all available titles in lowercase
var normalized_title: String

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

{
	"id": "v19073",
	"labels": [
		{"id": 2, "label": "Finished"},
		{"id": 7, "label": "Voted"}
	],
	"vn": {"title":"Senren * Banka"}
}
"""


# --- Methods ---

## Named Constructor to create new VNData instance from DB Record
static func from_db(record: Dictionary) -> VndbVN:
	# in case record is using old version (< 0.0.1) then
	# lang_title_map is missing
	return VndbVN.new(record)


## Named Constructor to create new VNData instance from vndb's json response
static func from_vndb(
	json: Dictionary,
	labels: Array,
	tag_min_rating: float,
	tag_max_spoiler: int,
	tag_types: String,
) -> VndbVN:

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

	# extract dev names
	var _devs: Array[String]

	for dev: Dictionary in json["developers"]:
		_devs.append(dev["name"])

	# extract translated titles
	var titles: Dictionary[String, String]

	for dict: Dictionary in json["titles"]:
		titles[dict["lang"]] = dict["title"]

	# extract label
	var label_id: int = 0

	for dict: Dictionary in labels:
		if dict["id"] < 7:
			label_id = dict["id"]
			break

	# TODO: add vndb label
	var instance := VndbVN.new(
		{
			"id": json["id"],
			"title": json["title"],
			"lang_title_map": titles,

			# could be empty string if not released
			"description": json["description"],
			"released": json["released"],

			"developers": _devs,
			"tags": _tags,

			#json["image"]["url"],
			"cover_url": json["image"]["thumbnail"] as String,
			"label": label_id,
		}
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


## Update normalized title search string.
## This must run after update
func update_search_str() -> void:
	#var str_arr: PackedStringArray = [

	# this code is trash but works for now
	self.normalized_title = "\n".join(
		([self.title.strip_edges().to_lower()] + self.lang_title_map.values()).map(
			func (string: String):
				return string.strip_edges().to_lower(),
		)
	)


# --- Handlers ---

func _init(json_data: Dictionary) -> void:
	# I miss TypedDicts
	self.raw_dict.assign(json_data)
	self.update_search_str()


func _to_string() -> String:
	return "VndbVNInfo(id=%s)" % self.id
