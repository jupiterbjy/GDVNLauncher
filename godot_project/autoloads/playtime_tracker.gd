extends Node
## Trackes processes launched from this launcher.
## Unlike old ps polling method this requires explicit launch from this launcher.
## May require admin privilage in windows if VN language patch requires such (i.e. Shinku_KR.exe)

# TODO: Workaround VNs that create new PID (e.g. YUZU's VNs), maybe full exe path check to get PID?
# maybe this is only from Jast originated ones? or Kirikiri?
# haven't bought enough DRM-free VN for figuring it out
#
# ... figured out, so NekoNyan's Angelic Chaos release has two exes, and one is mere launcher
# TODO: Add tooltip on exec selection to encourage users to add game itself, not launcher
#
# ... But seems like most of steam yuzusoft release can't be ran like that, still recreates PID


# TODO: Figure out why IroSeka Steam edition fails to find font unless Launcher is next to EXE,
# maybe requires cd before execution?


# --- Signals ---

## Triggered on db write, use this instead of timer to poll
signal db_updated(updated_ids: Array[String])

## Triggered on playtime update tick. Used in UI to trigger update
signal tick(updated_ids: Array[String])


# --- Classes ---

## Represent process
class Process:

	## emitted externally on process exit
	signal exited

	var path: String = ""
	var params: String = ""

	var pid: int = -1

	var start_utc: int = 0
	var end_utc: int = 0

	var elapsed_sec: float = 0

	## Only used in windows, indicates whether process is admin priv. or not.
	## Exists because godot can't get PID of non-child process for some reason
	var admin: bool = false

	# --- Handlers ---

	func _init(path_: String, params_: String, admin_ := false) -> void:
		self.path = path_
		self.params = params_

		# only enable admin in windows
		self.admin = admin_ and OS.get_name() == "Windows"

		self.start_utc = floori(Time.get_unix_time_from_system())
		self.end_utc = floori(Time.get_unix_time_from_system())

	func _to_string() -> String:
		return "Process(pid=%d, path=%s)" % [self.pid, self.path]

	# --- Methods ---

	# hope I can one day create PR for proper non-child process spawning & pid tracking..
	# or GDExtension maybe, but separate addon feels like overkill just for this,
	# or there could be cross platform issues too.
	# just adding this admin right mess cause I'm not willing to run godot editor itself as admin.

	## Checks whether process is alive or not.
	## Also updates pid to -1 when process is dead.
	func is_alive() -> bool:

		# fail fast
		if self.pid == -1:
			return false

		# if non-admin child process and not running invalidate PID and return
		if not self.admin:
			if not OS.is_process_running(self.pid):
				self.pid = -1
				#self.exited.emit()

				return false

			return true

		# if admin check in dumb slow laggy way, `Id` is there to supress bad return code
		var output: Array
		OS.execute(
			"powershell",
			["-NoProfile", "-Command", "(Get-Process -Id %d -eA SilentlyContinue).Id" % self.pid],
			output,
		)

		# if it has PID then alive else it's dead
		return not (output[0] as String).is_empty()

	## Tick elapsed time & update end_utc. Workaround for system freeze or sleep.
	func tick(sec: float) -> void:
		# hope error doesn't stack up too high...
		# but really it doesn't have to be too accurate does it
		self.elapsed_sec += sec
		self.end_utc = floori(Time.get_unix_time_from_system())

	## Start process. Returns false on failure.
	## On windows if `admin=true` then will launch non-child admin process which will
	## Slow down launcher a lot.
	## I'd rather suggest just running launcher as admin instead.
	func start() -> bool:

		# if not admin required just spawn casually
		if not self.admin:
			# from docs it just is `" ".join(param_arr)` so f it, pretend single argument
			self.pid = OS.create_process(self.path, [self.params])
			return self.pid != -1

		# now hell begins...
		var output: Array

		var full_cmd := "cd '%s'; (Start-Process '%s' -PassThru -Verb RunAs%s).Id" % [
			self.path.get_base_dir(),
			self.path,
			' -ArgumentList "%s"' % self.params if self.params else "",
		]
		var code := OS.execute(
			"powershell",
			[
				"-NoProfile",
				"-Command",
				full_cmd
			],
			output
		)

		# if execution of command failed eject
		if code == -1:
			return false

		# fetch output & strip, somehow Id field returns with space/newline
		var out := (output[0] as String).strip_edges(false)

		# prob should log non-int output for detail? i.e. param fail etc
		if not out.is_valid_int():
			return false

		self.pid = (output[0] as String).to_int()
		return self.pid != -1

	## Kill process. Silently fails if already ded.
	func kill() -> void:
		if self.pid != -1:
			OS.kill(self.pid)


# --- Attributes ---

## Dict[VN ID, Process]
var id_process_map: Dictionary[String, Process]

## Accumulated time, used as timer
var _accumulated_sec: float = 0

## Process alive check interval
const _PROC_CHECK_INTERVAL: float = 1

## Remaining cycle until DB write
var _accumulated_cycles: int = 0

## DB write interval in cycles of process alive check interval
const _DB_WRITE_CYCLES: int = 300

## Play session DB
var _db := DBWrapper.new("user://data.sqlite")

## Ref table name of EntryManager
const REF_TABLE := "entries_v2"

## Namespace for SQL Queries
class _Query:

	# should I cascade or not, that's the question.
	# user might delete entry by accident.
	const create_table := """
	CREATE TABLE IF NOT EXISTS sessions (
		id TEXT NOT NULL,
		start_utc INTEGER NOT NULL,
		end_utc INTEGER NOT NULL,
		time REAL NOT NULL,
		PRIMARY KEY(id, start_utc),
		FOREIGN KEY(id) REFERENCES """ + REF_TABLE + """(id)
	)
	"""

	## instead of cascade used to store deleted entry's sesions
	const create_backup_table := """
	CREATE TABLE IF NOT EXISTS sessions_hidden (
		id TEXT NOT NULL,
		start_utc INTEGER NOT NULL,
		end_utc INTEGER NOT NULL,
		time REAL NOT NULL,
		PRIMARY KEY(id, start_utc)
	)
	"""

	const upsert_session := """
	INSERT INTO sessions VALUES (?, ?, ?, ?)
	ON CONFLICT(id, start_utc) DO UPDATE SET end_utc = ?, time = ?
	"""

	const get_proc_total_time := 'SELECT IFNULL(SUM(time), 0) FROM sessions WHERE id = ?'

	## Used to fetch total playtime excluding specific session, usually running one
	const get_proc_total_time_excl := """
	SELECT IFNULL(SUM(time), 0) FROM sessions WHERE id = ? AND start_utc != ?
	"""

	const get_proc_session_time := 'SELECT time FROM sessions WHERE id = ? AND start_utc = ?'

	const get_proc_all_sessions := 'SELECT * FROM sessions WHERE id = ?'

	const get_proc_session_count := 'SELECT COUNT(*) FROM sessions WHERE id = ?'

	const get_proc_session_count_excl := """
	SELECT COUNT(*) FROM sessions WHERE id = ? AND start_utc != ?
	"""

	## Used to fetch total playtime & session count, for UI usage.
	## Exists to discard temporarily saved record
	const get_proc_time_n_count := 'SELECT IFNULL(SUM(time), 0), COUNT(*) FROM sessions WHERE id = ?'

	## Used to fetch total playtime & session count excluding specific session, for UI usage.
	## Exists to discard temporarily saved record
	const get_proc_time_n_count_excl := """
	SELECT IFNULL(SUM(time), 0), COUNT(*) FROM sessions WHERE id = ? AND start_utc != ?
	"""

	## Used to get total time & session in main ui
	const get_all_proc_time_n_count :=  'SELECT IFNULL(SUM(time), 0), COUNT(*) FROM sessions'

	## Used to stash sessions for givn id, which actually just moves to different table
	const stash_sessions := """
	INSERT INTO sessions_hidden (id, start_utc, end_utc, time)
	SELECT * FROM sessions WHERE id = ?;
	DELETE FROM sessions WHERE id = ?
	"""

	## Used to unstash sessions
	const unstash_sessions := """
	INSERT INTO sessions (id, start_utc, end_utc, time)
	SELECT * FROM sessions_hidden WHERE id = ?;
	DELETE FROM sessions_hidden WHERE id = ?
	"""

static var _LOGGER := Logging.get_logger("PlaytimeTracker")


# --- Methods ---

## Start tracking runtime time for given process. Returns false on process start failure.
func start_process(id: String, path: String, params := "", as_admin := false) -> bool:

	var proc := Process.new(path, params, as_admin)

	if proc.start():
		_LOGGER.debug("Started: %s" % proc)
		self.id_process_map[id] = proc
		return true

	_LOGGER.warn("Start failed: %s" % proc)
	return false


## Stop process & async wait for it. Fails sliently if process is not running
func async_stop_process(id: String) -> void:

	if id in self.id_process_map:
		var proc := self.id_process_map[id]
		proc.kill()
		_LOGGER.debug("Stopping: %s" % proc)

		await self.id_process_map[id].exited
		return

	_LOGGER.warn("No process to stop for %s")


## Is process started & running?
func is_running(id: String) -> bool:
	return id in self.id_process_map


## Get running processes' identifiers
func get_ids() -> Array[String]:
	return self.id_process_map.keys()


## Get running processes
func get_processes() -> Array[Process]:
	return self.id_process_map.values()


## Returns current session's playtime, not from DB. Returns 0 if not running.
func get_proc_current_session_time(id: String) -> float:
	return self.id_process_map[id].elapsed_sec if id in self.id_process_map else 0.0


## Returns total playtime of current session + DB. Returns 0 on failure.
func get_proc_total_playtime(id: String) -> float:
	var result: DBWrapper.QueryResult

	# Would this need db read caching, that's the problem

	# if running get time from DB excl. running session + current session time
	# since running session in DB is updated in relatively long interval
	if id in self.id_process_map:
		result = self._db.execute(
			_Query.get_proc_total_time, [id],
		)
		return (
			result.fetchone().values()[0] if result.rowcount else 0
		) + self.id_process_map[id].elapsed_sec

	# otherwise return DB time
	result = self._db.execute(
		_Query.get_proc_total_time_excl, [id, self.id_process_map[id].start_utc],
	)
	return result.fetchone().values()[0] if result.rowcount else 0


## Returns total session count. Returns 0 on failure.
func get_proc_session_count(id: String) -> int:
	var result: DBWrapper.QueryResult

	if id not in self.id_process_map:
		result = self._db.execute(
			_Query.get_proc_session_count, [id],
		)
		return result.fetchone().values()[0] if result.rowcount else 0

	result = self._db.execute(
		_Query.get_proc_session_count_excl, [id, self.id_process_map[id].start_utc]
	)
	return result.fetchone().values()[0] + 1 if result.rowcount else 1


## Returns [total playtime, total session count]
## Feels like it might be faster & simpler to just run two queries...
func get_proc_time_n_count(id: String) -> PackedInt32Array:
	var result: DBWrapper.QueryResult

	# if not running just fetch from db
	if id not in self.id_process_map:
		result = self._db.execute(_Query.get_proc_time_n_count, [id])
		return result.fetchone().values() if result.rowcount else [0, 0]

	# if running fetch from db excluding active session then return added result
	result = self._db.execute(
		_Query.get_proc_time_n_count_excl, [id, self.id_process_map[id].start_utc],
	)

	if result.rowcount:
		var record := result.fetchone().values()
		return [
			record[0] + self.id_process_map[id].elapsed_sec, record[1] + 1,
		]

	return [0, 0]


## Returns [all VNs' total playtime, total session count]
func get_all_proc_time_n_count() -> PackedInt32Array:
	var result := self._db.execute(_Query.get_all_proc_time_n_count)
	return result.fetchone().values() if result.rowcount else [0, 0]


## Add/Set session to DB
func _upsert_session(id: String, proc: Process) -> void:

	# upsert session info
	self._db.execute(
		_Query.upsert_session,
		[
			id,
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
	for key: String in self.id_process_map:
		var proc: Process = self.id_process_map[key]

		# might loose time of < delta but acceptable
		if not proc.is_alive():
			keys_to_erase.append(key)
			continue

		# otherwise update runtime
		proc.tick(delta)

	# cleanup & write session for dead processes
	for key: String in keys_to_erase:
		var proc: Process = self.id_process_map[key]

		_LOGGER.debug("Removing dead process: %s" % proc)

		self._upsert_session(key, proc)
		self.id_process_map.erase(key)

		proc.exited.emit()

	# if there was dead processes involving write, emit signal
	if keys_to_erase:
		self.db_updated.emit(keys_to_erase)


## Delete session for given id. Returns true on success.
## Wait until process is stopped if it was running.
func stash_sessions(id: String) -> bool:

	if id in self.id_process_map:
		#await self.async_stop_process(id)
		self.id_process_map[id].kill()
		self.id_process_map.erase(id)

	_LOGGER.debug("Removed sessions for %s" % id)

	return self._db.execute(
		_Query.stash_sessions, [id, id],
	).success


## Unstash session for given id. Returns true on success.
func unstash_sessions(id: String) -> bool:
	return self._db.execute(
		_Query.unstash_sessions, [id, id],
	).success


## Rebuild DB if EntryManager's DB table name was changed.
## Returns true when updated. Called by EntryManager.
func rebuild_db() -> bool:

	# sanity check, see if sessions table exists
	var result := self._db.execute(
		"SELECT sql FROM sqlite_master WHERE type='table' AND name='sessions'"
	)
	if not result.success or not result.rowcount:
		return false

	# master table contains schema as 'sql' so that can be used to check
	# see if it (loosely) references table name
	var existing_schema: String = result.fetchone()["sql"]
	if "REFERENCES " + REF_TABLE in existing_schema:
		return false

	# otherwise time to rebuild
	_LOGGER.info("Rebuilding sessions table")

	# rebuild: create new → copy data → drop old → rename
	assert(
		self._db.execute(_Query.create_table.replace("sessions", "sessions_new")).success
		and self._db.execute('INSERT INTO "sessions_new" SELECT * FROM "sessions"').success
		and self._db.execute('DROP TABLE "sessions"').success
		and self._db.execute('ALTER TABLE "sessions_new" RENAME TO "sessions"').success,
		"DB recreation failed!"
	)

	_LOGGER.info("Sessions table rebuilt")
	return true


# --- Handlers ---

func _init() -> void:
	self._db.execute(_Query.create_table)
	self._db.execute(_Query.create_backup_table)


func _physics_process(delta: float) -> void:

	# if nothing's running don't tick
	if not self.id_process_map:
		return

	# timer
	self._accumulated_sec += delta
	if self._accumulated_sec < _PROC_CHECK_INTERVAL:
		return

	# subtract for slightly better interval & update runtimes
	self._accumulated_sec -= _PROC_CHECK_INTERVAL

	self._track_processes(_PROC_CHECK_INTERVAL)
	self.tick.emit(self.id_process_map.keys())

	# write to DB if cycle arrives
	self._accumulated_cycles += 1

	if self._accumulated_cycles >= _DB_WRITE_CYCLES:
		self._accumulated_cycles = 0

		for id: String in self.id_process_map:
			_LOGGER.debug("Written %s session time to DB" % id)
			self._upsert_session(id, self.id_process_map[id])
			self.db_updated.emit(self.id_process_map.keys())

# TODO: do I need to remove deleted entry's histories or not
## If entry is removed, remove corresponding records from vn_id table
#func _on_entry_removed(entry: EntryManager.Entry) -> void:
	#self._db.execute(_Query.drop_table % entry.id)
