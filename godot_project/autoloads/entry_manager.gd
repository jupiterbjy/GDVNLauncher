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
		self.vn = vn_ if vn_ else VndbVN.new({})

	## V1 DB Record based named constructor
	static func from_db(data: Dictionary) -> Entry:
		return Entry.new(
			data["exec_path"] as String,
			data["admin"] as bool,
			VndbVN.from_db(data),
		)

	## V2 DB Record based named constructor
	static func from_db_v2(data: Dictionary) -> Entry:
		return Entry.new(
			data["exec_path"] as String,
			data["admin"] as bool,
			VndbVN.new(JSON.parse_string(data["vndb_json"] as String) as Dictionary),
		)

	## VNInfo based named constructor
	static func from_vndb_info(vn_: VndbVN) -> Entry:
		return Entry.new("", false, vn_)

	func _to_string() -> String:
		return "Entry(id=%s)" % self.id


# --- Attributes ---

const _DB_PATH := "user://data.sqlite"
const _DB_BACKUP_PATH := _DB_PATH + ".bak"

var _db := DBWrapper.new(_DB_PATH)

# TODO: add progressive db alter if there's breaking change in future when 'released'

## Namespace for SQL Query templates
class _QueryV1:
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

	#const update_entry := """
	#UPDATE "entries" SET
		#title = ?,
		#lang_title_map = ?,
		#developers = ?,
		#description = ?,
		#released = ?,
		#tags = ?,
		#cover_url = ?,
		#label = ?,
		#exec_path = ?,
		#admin = ?
	#WHERE id = ?
	#"""
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

	#const get_cover_urls := """
	#SELECT cover_url FROM "entries" WHERE cover_url != ''
	#"""

	const count_entries := """
	SELECT count(*) FROM "entries"
	"""

## New Schema + Query format since v0.0.2
## Now just stores VNDB data as raw json string blobs.
class _QueryV2:
	const check_v1_exists := """
	SELECT name FROM sqlite_master WHERE type='table' AND name='entries'
	"""

	const drop_v1 := """
	DROP TABLE IF EXISTS "entries"
	"""

	const create_table := """
	CREATE TABLE IF NOT EXISTS "entries_v2" (
		id TEXT PRIMARY KEY,
		vndb_json TEXT,
		exec_path TEXT,
		admin INT NOT NULL DEFAULT FALSE
	)
	"""

	# truncate table in case exists while migrating v1 to v2
	# insert rm -rf meme here
	const create_or_truncate_table := """
	DROP TABLE IF EXISTS "entries_v2";
	""" + create_table

	const get_entry := """
	SELECT * FROM "entries_v2" WHERE id = ?
	"""

	const get_entries := """
	SELECT * FROM "entries_v2"
	"""

	const upsert_entry := """
	INSERT INTO "entries_v2" VALUES(
		?, ?, ?, ?
	)
	ON CONFLICT(id) DO UPDATE SET
		vndb_json = ?,
		exec_path = ?,
		admin = ?
	"""

	const upsert_entry_from_vndb := """
	INSERT INTO "entries_v2" VALUES(
		?, ?, ?, ?
	)
	ON CONFLICT(id) DO UPDATE SET
		vndb_json = ?
	"""

	const get_entry_ids := """
	SELECT id FROM "entries_v2"
	"""

	const remove_entry := """
	DELETE FROM "entries_v2" WHERE id = ?
	"""

	const count_entries := """
	SELECT count(*) FROM "entries_v2"
	"""

static var _LOGGER := Logging.get_logger(&"EntryManager")


# --- Methods ---

## Backup DB. Will overwrite existing backup
func backup_db() -> void:
	if not FileAccess.file_exists(ProjectSettings.globalize_path(_DB_PATH)):
		_LOGGER.info("No DB to backup, skipping")
		return

	DirAccess.copy_absolute(
		ProjectSettings.globalize_path(_DB_PATH),
		ProjectSettings.globalize_path(_DB_BACKUP_PATH),
	)
	_LOGGER.info("DB Backup done at '%s'" % ProjectSettings.globalize_path(_DB_BACKUP_PATH))


# --- Methods V1 ---

## Returns false on failure
func create_table_v1() -> bool:
	return self._db.execute(_QueryV1.create_table).success


## Fetch entry from db id, else return null
func get_entry_v1(id: String) -> Entry:
	var result := self._db.execute(_QueryV1.get_entry, [id])

	return Entry.from_db(result.fetchone()) if result.success and result._rows else null


## Fetch entry from db id
func get_entries_v1() -> Array[Entry]:

	var entries: Array[Entry]

	for dict in self._db.execute(_QueryV1.get_entries).fetchall():
		entries.append(Entry.from_db(dict))

	return entries


## Returns false on failure
func upsert_entry_v1(entry: Entry) -> bool:
	return self._db.execute(
		_QueryV1.upsert_entry,
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
func upsert_entry_from_vndb_v1(vn: VndbVN) -> bool:
	return self._db.execute(
		_QueryV1.upsert_entry_from_vndb,
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
func update_entry_play_status_v1(id: String, play_status: int) -> bool:

	return self._db.execute(
		_QueryV1.update_entry_play_status,
		[play_status, id],
	).success


## Returns all entries' `db_id`
func get_entry_ids_v1() -> Array[String]:

	var result := self._db.execute(_QueryV1.get_entry_ids)

	if not result.success:
		return []

	var data: Array[String]
	for record in result.fetchall():
		data.append(record["id"])

	return data


## Fetch last entry's db_id, else returns -1
#func get_last_entry_id() -> int:
	#var result := self._db.execute(_QueryV1.get_last_entry_db_id)
	#return result.fetchone()["db_id"] if result.success else -1


## Delete given entry. Also stashes sessions & clear url cache if exists
func _remove_entry_v1(id: String) -> bool:

	PlaytimeTracker.stash_sessions(id)
	CacheManager.clear_cache(self.get_entry_v1(id).vn.cover_url)

	return self._db.execute(_QueryV1.remove_entry, [id]).success


## Delete given entries. Also stashes sessions & clear url cache if exists
func remove_entries_v1(ids: Array[String]) -> void:

	for id in ids:
		assert(self._remove_entry_v1(id), "Delete for %s failed" % id)

	self.entries_removed.emit(ids)


## Get list of non-empty cover image urls
#func get_cover_urls() -> Array[String]:
	#var result := self._db.execute(_QueryV1.get_cover_urls)
#
	#var data: Array[String]
	#for record in result.fetchall():
		#data.append(record["cover_url"])
#
	#return data


## Get total entry count. Unlikely but returns -1 on failure
func get_entry_count_v1() -> int:
	var result := self._db.execute(_QueryV1.count_entries)
	return result.fetchone().values()[0] if result.success and result._rows else -1


# --- Methods V2 ---

## Update V1 to V2, and DROP old table.
## Returns false if migration was not required.
func _migrate_v1_to_v2() -> bool:

	# validate if update is needed
	var result := self._db.execute(_QueryV2.check_v1_exists)

	if not result.rowcount:
		_LOGGER.info("No V1->V2 migration required, skipping")
		return false

	# backup first
	self.backup_db()

	# prep to nuke. honestly at this point, V2 table SHOULD NOT exist at all.
	# so it's their fault.
	_LOGGER.info("Migrating V1->V2 Database, V2 WILL BE DESTROYED.")

	assert(
		self._db.execute(_QueryV2.create_or_truncate_table).success,
		"V2 creation/truncate failed"
	)

	for data: Dictionary in self._db.execute(_QueryV1.get_entries).fetchall():
		_LOGGER.info("Migrating %s" % data["id"])

		# make sure only theses keys are included as part of vn specific data
		var vn_dict := data.duplicate(true)
		vn_dict.erase("exec_path")
		vn_dict.erase("admin")

		self._db.execute(
			_QueryV2.upsert_entry,
			[
				data["id"],
				JSON.stringify(vn_dict),
				data["exec_path"],
				data["admin"],

				JSON.stringify(vn_dict),
				data["exec_path"],
				data["admin"],
			]
		)

	# now update session schema
	PlaytimeTracker.rebuild_db()

	_LOGGER.info("Dropping V1")
	assert(self._db.execute(_QueryV2.drop_v1).success, "Dropping V1 table failed")

	_LOGGER.info("All done!")

	return true


## Create new table. Returns false on failure
func create_table() -> bool:
	return self._db.execute(_QueryV2.create_table).success


## Nuke & recreate table. Returns false on failure
func create_or_truncate_table() -> bool:
	return self._db.execute(_QueryV2.create_or_truncate_table).success


## Fetch entry from db id, else return null
func get_entry(id: String) -> Entry:
	var result := self._db.execute(_QueryV2.get_entry, [id])

	return Entry.from_db_v2(result.fetchone()) if result.success and result._rows else null


## Fetch entry from db id
func get_entries() -> Array[Entry]:

	var entries: Array[Entry]

	for dict in self._db.execute(_QueryV2.get_entries).fetchall():
		entries.append(Entry.from_db_v2(dict))

	return entries


## Returns false on failure
func upsert_entry(entry: Entry) -> bool:
	"""
	id TEXT PRIMARY KEY,
	vndb_json TEXT,
	exec_path TEXT,
	admin INT NOT NULL DEFAULT FALSE
	"""
	var vndb_json := JSON.stringify(entry.vn.raw_dict)
	return self._db.execute(
		_QueryV2.upsert_entry,
		[
			# insert param
			entry.id,
			vndb_json,
			entry.exec_path,
			entry.admin,

			# update param
			vndb_json,
			entry.exec_path,
			entry.admin,
		]
	).success


## Returns false on failure. Does not overwrite executable path & admin priv.
func upsert_entry_from_vndb(vn: VndbVN) -> bool:

	var vndb_json := JSON.stringify(vn.raw_dict)
	return self._db.execute(
		_QueryV2.upsert_entry_from_vndb,
		[
			# insert param
			vn.id,
			vndb_json,
			"",
			false,

			# update param
			vndb_json,
		]
	).success


## Returns all entries' `db_id`
func get_entry_ids() -> Array[String]:

	var result := self._db.execute(_QueryV2.get_entry_ids)

	if not result.success:
		return []

	var data: Array[String]
	for record in result.fetchall():
		data.append(record["id"])

	return data


## Delete given entries. Also stashes sessions & clear url cache if exists
func remove_entries(ids: Array[String]) -> void:

	for id in ids:
		PlaytimeTracker.stash_sessions(id)
		CacheManager.clear_cache(self.get_entry(id).vn.cover_url)

		assert(
			self._db.execute(_QueryV2.remove_entry, [id]).success,
			"Delete for %s failed" % id
		)

	self.entries_removed.emit(ids)


## Get total entry count. Unlikely but returns -1 on failure
func get_entry_count() -> int:
	var result := self._db.execute(_QueryV2.count_entries)
	return result.fetchone().values()[0] if result.success and result._rows else -1


# --- Handlers ---

func _init() -> void:
	if not self._migrate_v1_to_v2():
		self.backup_db()
		self.create_table()
