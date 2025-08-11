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
	var db_id: int = -1
	var exec_path: String
	var play_status: int
	var vn_info: VndbVNInfo = null

	# This feels like wasting a lot of computations but well..
	func _init(data: Dictionary = {}) -> void:
		if data:
			self.db_id = data["db_id"]
			self.exec_path = data["exec_path"]
			self.play_status = data["play_status"]

			self.vn_info = VndbVNInfo.from_db(data)
		else:
			# if no data is provided, create empty
			self.vn_info = VndbVNInfo.new()

	func _to_string() -> String:
		return "Entry(db_id=%d, vndb_info.id=%s)" % [self.db_id, self.vn_info.id]



# --- Attributes ---

var _db := DBWrapper.new("user://entry.sqlite")


## Namespace for SQL Query templates
class _Query:
	const create_table := """
	CREATE TABLE IF NOT EXISTS "entries"
	(
		db_id INTEGER PRIMARY KEY,
		exec_path TEXT,
		play_status INT,
		title TEXT,
		id TEXT,
		developers TEXT,
		description TEXT,
		released TEXT,
		tags TEXT,
		cover_url TEXT
	)
	"""

	const get_entry := """
	SELECT * FROM "entries" WHERE db_id=?
	"""

	const get_entries := """
	SELECT * FROM "entries"
	"""

	const get_last_entry := """
	SELECT * FROM "entries" ORDER BY db_id LIMIT 1
	"""

	const add_entry := """
	INSERT INTO "entries" VALUES (
		NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?
	)
	"""

	const update_entry := """
	UPDATE "entries" SET
		exec_path = ?,
		play_status = ?,
		title = ?,
		id = ?,
		developers = ?,
		description = ?,
		released = ?,
		tags = ?,
		cover_url = ?
	WHERE rowid = ?
	"""

	const update_entry_play_status := """
	UPDATE "entries" SET play_status = ? WHERE rowid = ?
	"""

	const get_entry_db_ids := """
	SELECT db_id FROM "entries"
	"""

	const get_last_entry_db_id := """
	SELECT db_id FROM "entries" ORDER BY db_id DESC LIMIT 1
	"""

	const remove_entry := """
	DELETE FROM "entries" WHERE db_id=?
	"""


# --- Methods ---

## Returns false on failure
func create_table() -> bool:
	return self._db.execute(_Query.create_table).success


## Fetch entry from db id, else return null
func get_entry(id: int) -> Entry:
	var result := self._db.execute(_Query.get_entry, [id])
	return Entry.new(result.fetchone()) if result.success and result._rows else null


## Fetch entry from db id
func get_entries() -> Array[Entry]:
	var result := self._db.execute(_Query.get_entries)
	var entries: Array[Entry]
	for dict in result.fetchall():
		entries.append(Entry.new(dict))

	return entries


## Fetch last entry from db id, else return null
func get_last_entry() -> Entry:
	var result := self._db.execute(_Query.get_last_entry)
	return Entry.new(result.fetchone()) if result.success else null


## Returns false on failure
func add_entry(entry: Entry) -> bool:
	#return self._db.execute(
	if self._db.execute(
		_Query.add_entry,
		[
			entry.exec_path,
			entry.play_status,
			entry.vn_info.title,
			entry.vn_info.id,
			entry.vn_info.developers,
			entry.vn_info.description,
			entry.vn_info.released,
			entry.vn_info.tags,
			entry.vn_info.cover_url,
		]
	).success:
		self.entry_added.emit(entry)
		return true

	return false

	# TODO: return newly saved entry's rowid to let UI decide wheter to refresh or not?


## Returns false on failure.
## If `entry.db_id == -1` will add new entry instead
func update_entry(entry: Entry) -> bool:
	if entry.db_id == -1:
		return self.add_entry(entry)

	return self._db.execute(
		_Query.update_entry,
		[
			entry.exec_path,
			entry.play_status,
			entry.vn_info.title,
			entry.vn_info.id,
			entry.vn_info.developers,
			entry.vn_info.description,
			entry.vn_info.released,
			entry.vn_info.tags,
			entry.vn_info.cover_url,
			entry.db_id,
		]
	).success


## Returns false on failure.
func update_entry_play_status(db_id: int, play_status: int) -> bool:
	return self._db.execute(
		_Query.update_entry_play_status,
		[
			play_status,
			db_id,
		]
	).success


## Returns all entries' `db_id`
func get_entry_db_ids() -> Array[int]:
	var result := self._db.execute(
		_Query.get_entry_db_ids
	)
	if not result.success:
		return []

	var data: Array[int]
	for record in result.fetchall():
		data.append(record["db_id"])

	return data


## Fetch last entry's db_id, else returns -1
func get_last_entry_db_id() -> int:
	var result := self._db.execute(_Query.get_last_entry_db_id)
	return result.fetchone()["db_id"] if result.success else -1


## Delete given entry
func remove_entry(db_id: int) -> bool:
	#return self._db.execute(_Query.remove_entry, [db_id]).success

	var entry := self.get_entry(db_id)

	if self._db.execute(_Query.remove_entry, [db_id]).success:
		self.entry_removed.emit(entry)
		return true

	return false


# --- Drivers ---

func _init() -> void:
	self.create_table()
