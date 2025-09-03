extends Node
#class_name EntryManager
## Manages Visual Novel entries


# TODO: separate id column to type(vndb/custom) + id? (e.g. "v10028" -> "v" + 10028)
# since one can't just do `SELECT MAX(id) FROM ...` when assigning new Custom ID without padding


# --- Signals ---
# Changing to autoload just because of signals

#signal entry_added(id: String)

signal entries_removed(ids: Array[String])


# --- Classes ---

## Record representation
class Entry:
	# TODO: convert this to store dict directly and access via properties instead

	## Entry's ID in local DB(actually just rowid alias), not to be confused with `VndbVN.id`
	#var db_id: int = -1

	## VNDB(vxxxx) or user-defined(cvxxxx) id, basically syntax sugar
	var id: String:
		get():
			return self.vn.id

	## Executable path
	var exec_path: String = ""

	## Requires Windows Admin privilege?
	var admin: bool = false

	var vn: VndbVN = null

	# This feels like wasting a lot of computations but well..
	func _init(path := "", admin_ := false, vn_: VndbVN = null) -> void:
		self.exec_path = path
		self.admin = admin_
		self.vn = vn_ if vn_ else VndbVN.new()

	## DB Record based named constructor
	static func from_db(data: Dictionary) -> Entry:
		return Entry.new(
			data["exec_path"],
			data["admin"],
			VndbVN.from_db(data),
		)

	## VNInfo based named constructor
	static func from_vndb_info(vn_: VndbVN) -> Entry:
		return Entry.new("", false, vn_)

	func _to_string() -> String:
		return "Entry(id=%s)" % self.id


# --- Attributes ---

var _db := DBWrapper.new("user://data.sqlite")

# TODO: add progressive db alter if there's breaking change in future when 'released'

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
		label INT,
		exec_path TEXT,
		admin INT NOT NULL DEFAULT FALSE
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
		?, ?, ?, ?, ?, ?, ?, ?, ?, ?
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
		label = ?,
		exec_path = ?,
		admin = ?
	WHERE id = ?
	"""
	# WHERE rowid = ?

	const upsert_entry := """
	INSERT INTO "entries" VALUES(
		?, ?, ?, ?, ?, ?, ?, ?, ?, ?
	)
	ON CONFLICT(id) DO UPDATE SET
		title = ?,
		developers = ?,
		description = ?,
		released = ?,
		tags = ?,
		cover_url = ?,
		label = ?,
		exec_path = ?,
		admin = ?
	"""

	const upsert_entry_from_vndb := """
	INSERT INTO "entries" VALUES(
		?, ?, ?, ?, ?, ?, ?, ?, ?, ?
	)
	ON CONFLICT(id) DO UPDATE SET
		title = ?,
		developers = ?,
		description = ?,
		released = ?,
		tags = ?,
		cover_url = ?,
		label = ?
	"""

	const update_entry_play_status := """
	UPDATE "entries" SET label = ? WHERE id = ?
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

	const get_cover_urls := """
	SELECT cover_url FROM "entries" WHERE cover_url != ''
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

	var entries: Array[Entry]

	for dict in self._db.execute(_Query.get_entries).fetchall():
		entries.append(Entry.from_db(dict))

	return entries


## Fetch last entry from db id, else return null
#func get_last_entry() -> Entry:
	#var result := self._db.execute(_Query.get_last_entry)
	#return Entry.new(result.fetchone()) if result.success else null


## Returns false on failure
#func add_entry(entry: Entry) -> bool:
#
	##return self._db.execute(
	#if self._db.execute(
		#_Query.add_entry,
		#[
			#entry.vn.id,
			#entry.vn.title,
			#entry.vn.developers,
			#entry.vn.description,
			#entry.vn.released,
			#entry.vn.tags,
			#entry.vn.cover_url,
			#entry.exec_path,
			#entry.admin,
			#entry.vn.label,
		#]
	#).success:
		#self.entry_added.emit(entry.id)
		#return true
#
	#return false


## Returns false on failure
func update_entry(entry: Entry) -> bool:
	#if entry.db_id == -1:
		#return self.add_entry(entry)

	return self._db.execute(
		_Query.update_entry,
		[
			entry.vn.title,
			entry.vn.developers,
			entry.vn.description,
			entry.vn.released,
			entry.vn.tags,
			entry.vn.cover_url,
			entry.vn.label,
			entry.exec_path,
			entry.admin,
			entry.id,
		]
	).success


## Returns false on failure
func upsert_entry(entry: Entry) -> bool:
	return self._db.execute(
		_Query.upsert_entry,
		[
			# insert param
			entry.id,
			entry.vn.title,
			entry.vn.developers,
			entry.vn.description,
			entry.vn.released,
			entry.vn.tags,
			entry.vn.cover_url,
			entry.vn.label,
			entry.exec_path,
			entry.admin,

			# update param
			entry.vn.title,
			entry.vn.developers,
			entry.vn.description,
			entry.vn.released,
			entry.vn.tags,
			entry.vn.cover_url,
			entry.vn.label,
			entry.exec_path,
			entry.admin,
		]
	).success


## Returns false on failure. Does not overwrite executable path & admin priv.
func upsert_entry_from_vndb(vn: VndbVN) -> bool:
	return self._db.execute(
		_Query.upsert_entry_from_vndb,
		[
			# insert param
			vn.id,
			vn.title,
			vn.developers,
			vn.description,
			vn.released,
			vn.tags,
			vn.cover_url,
			vn.label,
			"",
			false,

			# update param
			vn.title,
			vn.developers,
			vn.description,
			vn.released,
			vn.tags,
			vn.cover_url,
			vn.label,
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
