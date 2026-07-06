class_name DBWrapper
## Wrapper of wrapper, to make interface more simpler and python-like


# --- Classes ---

## Result dataclass to mimic python's sqlite3 tiny bit
class QueryResult:
	var success: bool
	var _rows: Array[Dictionary]

	var rowcount: int:
		get():
			return len(self._rows)

	# --- Handlers ---

	func _init(success_: bool, rows: Array[Dictionary]) -> void:
		self.success = success_
		self._rows = rows

	func _to_string() -> String:
		return "QueryResult(success=%s, %d rows: %s)" % [self.success, len(self._rows), self._rows]

	# --- Methods ---

	## Fetch last record. Returns empty dict when not available.
	func fetchone() -> Dictionary:
		return self._rows[-1] if self._rows else {}

	## Fetch all records.
	func fetchall() -> Array[Dictionary]:
		return self._rows


# --- Attritbutes ---

var _db := SQLite.new()

## Exists purely so we can see user:// path not real abs path.
## Not property because it's inaccessible in `NOTIFICATION_PREDELETE`
var path: String


const _LEVEL: SQLite.VerbosityLevel = SQLite.VerbosityLevel.QUIET

static var _LOGGER := Logging.get_logger("DBWrapper")


# --- Methods ---

## Act slightly similar to python's `sqlite3.Connection.execute`.
func execute(query: String, param: Array = []) -> QueryResult:
	_LOGGER.debug("Execute: %s" % query)

	if self._db.query_with_bindings(query, param):
		return QueryResult.new(true, self._db.query_result)

	return QueryResult.new(false, [])


## Runs some test
static func _test() -> void:
	_LOGGER.debug("--- Test start ---")

	var db := DBWrapper.new("user://test.sqlite")

	_LOGGER.debug(
		db.execute('CREATE TABLE IF NOT EXISTS "hina" (start INTEGER PRIMARY KEY, end INTEGER)')
	)

	var t := int(Time.get_unix_time_from_system())
	_LOGGER.debug(
		db.execute(
			'INSERT INTO "hina" VALUES (?, ?) ON CONFLICT(start) DO UPDATE SET end=?',
			[0, t, t]
		)
	)

	_LOGGER.debug(
		db.execute(
			'SELECT * FROM "hina" WHERE start=?',
			[0],
		)
	)

	# cleanup
	var p := db.path
	db = null
	DirAccess.remove_absolute(p)

	_LOGGER.debug("Deleted '%s'" % p)
	_LOGGER.debug("--- Test Done ---")


# --- Handlers ---

static func _static_init() -> void:
	if Globals.DEBUG:
		_test()


func _init(path_: String) -> void:

	self.path = path_

	self._db.path = path_
	self._db.verbosity_level = _LEVEL
	self._db.foreign_keys = true

	self._db.open_db()

	_LOGGER.debug("Created DB Conn to '%s'" % path)


func _notification(what: int) -> void:

	if what == NOTIFICATION_PREDELETE:
		self._db.close_db()
		_LOGGER.debug("Closed DB Conn to '%s'" % self.path)
