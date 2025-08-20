extends Node
#class_name EntryManager
## Manages Visual Novel entries


# --- Signals ---
# Changing to autoload just becase of signals

signal entry_added(entry: Entry)

signal entry_removed(entry: Entry)


# --- Classes ---

## Record representation
class Entry:
	# TODO: convert this to store dict directly and access via properties instead

	## Entry's ID in local DB(actually just rowid alias), not to be confused with `VndbVNInfo.id`
	#var db_id: int = -1

	## VNDB(vxxxx) or user-defined(cvxxxx) id
	var id: String:
		get():
			return self.vn_info.id

	## Executable path
	var exec_path: String = ""

	## Play status
	var play_status: int = 2

	var vn_info: VndbVNInfo = null

	# This feels like wasting a lot of computations but well..
	func _init(path: String = "", play_status_: int = 2, vn_info_: VndbVNInfo = null) -> void:
		self.exec_path = path
		self.play_status = play_status_
		self.vn_info = vn_info_ if vn_info_ else VndbVNInfo.new()

	## DB Record based named constructor
	static func from_db(data: Dictionary) -> Entry:
		return Entry.new(
			data["exec_path"],
			data["play_status"],
			VndbVNInfo.from_db(data),
		)

	## VNInfo based named constructor
	static func from_vndb_info(vn_info_: VndbVNInfo) -> Entry:
		return Entry.new("", 2, vn_info_)

	func _to_string() -> String:
		return "Entry(id=%d)" % self.id


# --- Attributes ---

var _db := DBWrapper.new("user://entry.sqlite")


## Namespace for SQL Query templates
class _Query:

	const create_table := """
	CREATE TABLE IF NOT EXISTS "entries" (
		id TEXT PRIMARY KEY,
		title TEXT,
		developers TEXT,
		description TEXT,
		released TEXT,
		tags TEXT,
		cover_url TEXT,
		exec_path TEXT,
		play_status INT
	)
	"""
	# db_id INTEGER PRIMARY KEY,

	const get_entry := """
	SELECT * FROM "entries" WHERE id = ?
	"""

	const get_entries := """
	SELECT * FROM "entries"
	"""

	#const get_last_entry := """
	#SELECT * FROM "entries" ORDER BY db_id LIMIT 1
	#"""

	const add_entry := """
	INSERT INTO "entries" VALUES(
		?, ?, ?, ?, ?, ?, ?, ?, ?,
	)
	"""

	const update_entry := """
	UPDATE "entries" SET
		title = ?,
		developers = ?,
		description = ?,
		released = ?,
		tags = ?,
		cover_url = ?,
		exec_path = ?,
		play_status = ?
	WHERE id = ?
	"""
	# WHERE rowid = ?

	const upsert_entry := """
	INSERT INTO "entries" VALUES(
		?, ?, ?, ?, ?, ?, ?, ?, ?
	)
	ON CONFLICT(id) DO UPDATE SET
		title = ?,
		developers = ?,
		description = ?,
		released = ?,
		tags = ?,
		cover_url = ?,
		exec_path = ?,
		play_status = ?
	"""

	const update_entry_play_status := """
	UPDATE "entries" SET play_status = ? WHERE id = ?
	"""

	const get_entry_ids := """
	SELECT id FROM "entries"
	"""

	#const get_last_entry_db_id := """
	#SELECT db_id FROM "entries" ORDER BY db_id DESC LIMIT 1
	#"""

	const remove_entry := """
	DELETE FROM "entries" WHERE id = ?
	"""


# --- Methods ---

## Returns false on failure
func create_table() -> bool:
	return self._db.execute(_Query.create_table).success


## Fetch entry from db id, else return null
func get_entry(id: String) -> Entry:
	var result := self._db.execute(_Query.get_entry, [id])
	return Entry.from_db(result.fetchone()) if result.success and result._rows else null


## Fetch entry from db id
func get_entries() -> Array[Entry]:

	var result := self._db.execute(_Query.get_entries)

	var entries: Array[Entry]

	for dict in result.fetchall():
		entries.append(Entry.from_db(dict))

	return entries


## Fetch last entry from db id, else return null
#func get_last_entry() -> Entry:
	#var result := self._db.execute(_Query.get_last_entry)
	#return Entry.new(result.fetchone()) if result.success else null


## Returns false on failure
func add_entry(entry: Entry) -> bool:
	#return self._db.execute(
	if self._db.execute(
		_Query.add_entry,
		[
			entry.vn_info.id,
			entry.vn_info.title,
			entry.vn_info.developers,
			entry.vn_info.description,
			entry.vn_info.released,
			entry.vn_info.tags,
			entry.vn_info.cover_url,
			entry.exec_path,
			entry.play_status,
		]
	).success:
		self.entry_added.emit(entry)
		return true

	return false


## Returns false on failure
func update_entry(entry: Entry) -> bool:
	#if entry.db_id == -1:
		#return self.add_entry(entry)

	return self._db.execute(
		_Query.update_entry,
		[
			entry.vn_info.title,
			entry.vn_info.developers,
			entry.vn_info.description,
			entry.vn_info.released,
			entry.vn_info.tags,
			entry.vn_info.cover_url,
			entry.exec_path,
			entry.play_status,
			entry.id,
		]
	).success


## Returns false on failure
func upsert_entry(entry: Entry) -> bool:
	return self._db.execute(
		_Query.upsert_entry,
		[
			entry.id,
			entry.vn_info.title,
			entry.vn_info.developers,
			entry.vn_info.description,
			entry.vn_info.released,
			entry.vn_info.tags,
			entry.vn_info.cover_url,
			entry.exec_path,
			entry.play_status,

			entry.vn_info.title,
			entry.vn_info.developers,
			entry.vn_info.description,
			entry.vn_info.released,
			entry.vn_info.tags,
			entry.vn_info.cover_url,
			entry.exec_path,
			entry.play_status,

			entry.id,
		]
	).success


## Returns false on failure.
func update_entry_play_status(id: String, play_status: int) -> bool:

	return self._db.execute(
		_Query.update_entry_play_status,
		[play_status, id],
	).success


## Returns all entries' `db_id`
func get_entry_ids() -> Array[String]:

	var result := self._db.execute(_Query.get_entry_ids)

	if not result.success:
		return []

	var data: Array[String]
	for record in result.fetchall():
		data.append(record["id"])

	return data


## Fetch last entry's db_id, else returns -1
#func get_last_entry_id() -> int:
	#var result := self._db.execute(_Query.get_last_entry_db_id)
	#return result.fetchone()["db_id"] if result.success else -1


## Delete given entry
func remove_entry(id: String) -> bool:
	#return self._db.execute(_Query.remove_entry, [db_id]).success

	#var entry := self.get_entry(db_id)

	if self._db.execute(_Query.remove_entry, [id]).success:
		self.entry_removed.emit(id)
		return true

	return false


# --- Handlers ---

func _init() -> void:
	self.create_table()
