extends Node
## Trackes processes launched from this launcher.
## Unlike old ps polling method this requires explicit launch from this launcher.
## May require admin privilage in windows if VN language patch requires such (i.e. Shinku_KR.exe)

# TODO: Workaround VNs that create new PID (e.g. YUZU's VNs), maybe full exe path check to get PID?
# maybe this is only from Jast originated ones? or Kirikiri?
# haven't bought enough DRM-free VN for figuring it out
#
# ... figured out, so NekoNyan's Angelic Chaos release has two exes, and one is mere launcher
# TODO: Add tooltip on exec selection to encourage users to add valid game


# --- Signals ---


# --- Classes ---

## Represent process
class _Process:

	var path: String = ""
	var params: PackedStringArray = []

	var pid: int = -1

	var start_utc: int = 0
	var end_utc: int = 0

	var elapsed_sec: float = 0

	# --- Handlers ---

	func _init(path_: String, params_: Array[String]) -> void:
		self.path = path_
		self.params.append_array(params_)

		self.start_utc = floori(Time.get_unix_time_from_system())
		self.end_utc = floori(Time.get_unix_time_from_system())

	func _to_string() -> String:
		return "_Process(pid=%d, path=%s)" % [self.pid, self.path]

	# --- Methods ---

	## Checks whether process is alive or not.
	## Also updates pid to -1 when process is dead.
	func is_alive() -> bool:
		if self.pid == -1:
			return false

		if not OS.is_process_running(self.pid):
			self.pid = -1
			return false

		return true

	## Tick elapsed time & update end_utc. Workaround for system freeze or sleep.
	func tick(sec: float) -> void:
		# hope error doesn't stack up too high...
		# but really it doesn't have to be too accurate does it
		self.elapsed_sec += sec
		self.end_utc = floori(Time.get_unix_time_from_system())

	## Start process. Returns false on failure.
	func start() -> bool:
		self.pid = OS.create_process(self.path, self.params)
		return self.pid != -1

	## Kill process. Silently fails.
	func kill() -> void:
		if self.pid != -1:
			OS.kill(self.pid)


# --- Attributes ---

## Dict[VN ID, _Process]
var _processes: Dictionary[String, _Process]

## Play session DB
var _db := DBWrapper.new("user://data.sqlite")

## Namespace for SQL Queries
class _Query:

	# should I cascade or not, that's the question.
	# user might delete entry by accident,
	const create_table := """
	CREATE TABLE IF NOT EXISTS "sessions" (
		id TEXT NOT NULL,
		start_utc INTEGER NOT NULL,
		end_utc INTEGER NOT NULL,
		time REAL NOT NULL,
		PRIMARY KEY(id, start_utc),
		FOREIGN KEY(id) REFERENCES entries(id)
	)
	"""

	const upsert_session := """
	INSERT INTO "sessions" VALUES (?, ?, ?, ?)
	ON CONFLICT(id, start_utc) DO UPDATE SET end_utc = ?, time = ?
	"""

	const get_total_time := 'SELECT IFNULL(SUM(time), 0) FROM "sessions" WHERE id = ?'

	## Used to fetch total playtime excluding specific session, usually running one
	const get_total_time_excl := """
	SELECT IFNULL(SUM(time), 0) FROM sessions WHERE id = ? AND start_utc != ?
	"""

	const get_session_time := 'SELECT time FROM "sessions" WHERE id = ? AND start_utc = ?'

	const get_all_sessions := 'SELECT * FROM "sessions" WHERE id = ?'

	const get_count := 'SELECT COUNT(*) FROM "sessions" WHERE vn_id = ?'

	## Used to fetch total playtime & session count, for UI usage
	const get_time_n_count := 'SELECT IFNULL(SUM(time), 0), COUNT(*) FROM "sessions" WHERE id = ?'

	## Used to fetch total playtime & session count excluding specific session, for UI usage
	const get_time_n_count_excl := """
	SELECT IFNULL(SUM(time), 0), COUNT(*) FROM "sessions" WHERE id = ? AND start_utc != ?
	"""


## Accumulated time, used as timer
var _accumulated_sec: float = 0

## Process alive check interval
const _PROC_CHECK_INTERVAL: float = 1

## Remaining cycle until DB write
var _accumulated_cycles: int = 0

## DB write interval in cycles of process alive check interval
const _DB_WRITE_CYCLES: int = 300

static var _LOGGER := Logging.get_logger("PlaytimeTracker")


# --- Methods ---

## Start tracking runtime time for given process. Returns false on process start failure.
func start_process(vn_id: String, path: String, params: PackedStringArray = []) -> bool:

	var proc := _Process.new(path, params)

	if proc.start():
		_LOGGER.debug("Started: %s" % proc)
		self._processes[vn_id] = proc
		return true

	_LOGGER.warn("Start failed: %s" % proc)
	return false


## Stop process. Fails sliently if process is not running
func stop_process(vn_id: String) -> void:

	if vn_id in self._processes:
		var proc := self._processes[vn_id]
		proc.kill()
		_LOGGER.debug("Stopped: %s" % proc)
		return

	_LOGGER.warn("No process to stop for %s")


## Is process started & running?
func is_running(vn_id: String) -> bool:
	return vn_id in self._processes


## Get running process list
func get_running_vn_id_list() -> Array[String]:
	return self._processes.keys()


## Returns current session's playtime, not from DB. Returns 0 if not running.
func get_current_session_time(vn_id: String) -> float:
	return self._processes[vn_id].elapsed_sec if vn_id in self._processes else 0.0


## Returns total playtime of current session + DB. Returns 0 on failure.
func get_total_playtime(vn_id: String) -> float:
	var result: DBWrapper.QueryResult

	# if running get time from DB excl. running session + current session time
	# since running session in DB is updated in relatively long interval
	if vn_id in self._processes:
		result = self._db.execute(
			_Query.get_total_time, [vn_id],
		)
		return (
			result.fetchone().values()[0] if result.rowcount else 0
		) + self._processes[vn_id].elapsed_sec

	# otherwise return DB time
	result = self._db.execute(
		_Query.get_total_time_excl, [vn_id, self._processes[vn_id].start_utc],
	)
	return result.fetchone().values()[0] if result.rowcount else 0


## Returns total session count. Returns 0 on failure.
func get_session_count(vn_id: String) -> int:
	var result := self._db.execute(
		_Query.get_count, [vn_id],
	)
	return result.fetchone().values()[0] if result.rowcount else 0


## Returns [total playtime, total session count]
## Feels like it might be faster & simpler to just run two queries...
func get_time_n_count(vn_id: String) -> PackedInt32Array:
	var result: DBWrapper.QueryResult

	# if not running just fetch from db
	if vn_id not in self._processes:
		result = self._db.execute(_Query.get_time_n_count, [vn_id])

		if result.rowcount:
			var record := result.fetchone().values()
			return record
			#return [floori(record[0]), record[1]]

		return [0, 0]

	# if running fetch from db excluding active session then return added result
	result = self._db.execute(
		_Query.get_time_n_count_excl, [vn_id, self._processes[vn_id].start_utc],
	)

	if result.rowcount:
		var record := result.fetchone().values()
		return [
			record[0] + self._processes[vn_id].elapsed_sec, record[1] + 1,
		]

	return [0, 0]


## Add/Set session to DB
func _upsert_session(vn_id: String, proc: _Process) -> void:

	# upsert session info
	self._db.execute(
		_Query.upsert_session,
		[
			vn_id,
			proc.start_utc,
			proc.end_utc,
			proc.elapsed_sec,

			proc.end_utc,
			proc.elapsed_sec,
		]
	)


## Update all currently active processes' runtime, and removes dead processes.
## DB will be updated once processes are dead.
func _track_processes(delta: float) -> void:

	var keys_to_erase: Array[String]

	# find dead processes & tick runtime
	for key: String in self._processes:
		var proc: _Process = self._processes[key]

		# might loose time of < delta but acceptable
		if not proc.is_alive():
			keys_to_erase.append(key)
			continue

		# otherwise update runtime
		proc.tick(delta)
		#print(proc)
		#self.upsert_session(key, proc)

	# cleanup & write session for dead processes
	for key: String in keys_to_erase:
		_LOGGER.debug("Removing %s" % self._processes[key])
		self._upsert_session(key, self._processes[key])
		self._processes.erase(key)


# --- Handlers ---

func _init() -> void:
	self._db.execute(_Query.create_table)


#func _ready() -> void:
	#EntryManager.entry_removed.connect(self._on_entry_removed)


func _physics_process(delta: float) -> void:

	self._accumulated_sec += delta

	if self._accumulated_sec < _PROC_CHECK_INTERVAL:
		return

	# subtract for slightly better interval & update runtimes
	self._accumulated_sec -= _PROC_CHECK_INTERVAL

	self._track_processes(_PROC_CHECK_INTERVAL)

	# write to DB if cycle arrives
	self._accumulated_cycles += 1

	if self._accumulated_cycles >= _DB_WRITE_CYCLES:
		self._accumulated_cycles = 0

		for vn_id: String in self._processes:
			_LOGGER.debug("Written %s session time to DB" % vn_id)
			self._upsert_session(vn_id, self._processes[vn_id])

# TODO: do I need to remove deleted entry's histories or not
## If entry is removed, remove corresponding records from vn_id table
#func _on_entry_removed(entry: EntryManager.Entry) -> void:
	#self._db.execute(_Query.drop_table % entry.id)
