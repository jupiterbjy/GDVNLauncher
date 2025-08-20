extends Node
## A very stupid way (I think) to poll process lists periodically and track playtime.
##
## But at least one doesn't have to rely on pressing 'start' at launcher,
## they could just use Steam and this will still track it.


# --- Attributes ---

## Dict[Currently Running process path, Session Start time]
var _started: Dictionary[String, int]

## Thread where to poll from, because OS.Execute causes 200~500ms spike..
var _thread := Thread.new()
var _mutex := Mutex.new()
var _thread_stop := false

## Play session DB
var _db := DBWrapper.new("sessions.sqlite")

## Namespace for SQL Queries
class _Query:
	# Should I cascade? idk

	const create_table := """
	CREATE TABLE IF NOT EXISTS "%s" (start_utc INTEGER, end_utc INTEGER, time REAL, PRIMARY KEY(start_utc))
	"""

	const drop_table := 'DROP TABLE IF EXISTS "%s"'

	const add_or_update_time := """
	INSERT INTO "%s" VALUES (?, ?, ?) ON CONFLICT(start_utc) DO UPDATE SET end_utc=?, time=time+?
	"""

	const get_total_time := 'SELECT SUM(time) FROM "%s"'

	const get_single_time := 'SELECT time FROM "%s" WHERE start_utc=?'

	const get_all_sessions := 'SELECT * FROM "%s"'

	# TODO: get last playtime


## Used to get more accurate runtime since OS.execute is freakin' unreliable, and also
## to compensate for system sleep.
var _time_since_update: float = 0

## Path to db_id mapping for faster lookup
## Dict[Process path, [db_id,]] in case for identical path for multiple VN for whatever reason.
var _path_to_db_id: Dictionary[String, PackedInt32Array]


# --- Methods ---

## Returns playtime from DB. Returns 0 on failure.
func get_playtime(db_id: int) -> float:
	var result := self._db.execute(
		_Query.get_total_time % db_id
	)
	if result:
		return result.fetchone()[0]

	return 0


# --- Utilities ---

func _update_runtime(processes: Dictionary[String, int]) -> void:
	#print("Processes %s, time since last: %s" % [len(processes), self._time_since_update])

	var proc_in_whitelist: Array[String]
	var now := int(Time.get_unix_time_from_system())

	# filter whitelisted (I miss set() & set())
	for proc in processes:
		if proc not in self._path_to_db_id:
			continue

			proc_in_whitelist.append(proc)

		# if this process just found set start time
		if proc not in self._started:
			self._started[proc] = now

		# update time; this is looped in case of same path for different vn...
		for db_id in self._path_to_db_id[proc]:
			self._db.execute(
				_Query.add_or_update_time % db_id,
				[self._started[proc], now, self._time_since_update, now, self._time_since_update]
			)

	# remove nonexistent processes' start time
	for proc in self._started.keys():
		if proc not in proc_in_whitelist:
			self._started.erase(proc)

	self._time_since_update = 0


# --- Handlers ---

func _ready() -> void:
	self._thread.start(self._thread_action)

	EntryManager.entry_added.connect(self._on_entry_added)
	EntryManager.entry_removed.connect(self._on_entry_removed)

	# populate cache; this is cursed
	for entry in EntryManager.get_entries():
		(
			self._path_to_db_id.get_or_add(entry.exec_path, PackedInt32Array()) as PackedInt32Array
		).append(
			entry.db_id
		)


func _thread_action() -> void:

	while true:
		# OS.execute is astonishingly slow
		# can take 200ms to even 2.5 second in some potato pc
		# ... so just keep it running in loop until I find better solution
		OS.delay_msec(1000)
		self._update_runtime.call_deferred(ActiveProcesses.poll_unique())

		self._mutex.lock()

		if self._thread_stop:
			self._mutex.unlock()
			return

		self._mutex.unlock()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:

		# cleanup thread
		self._mutex.lock()
		self._thread_stop = true
		self._mutex.unlock()

		self._thread.wait_to_finish()


func _process(delta: float) -> void:
	self._time_since_update += delta


## If entry is added, add or append db_id to cache
func _on_entry_added(entry: EntryManager.Entry) -> void:
	(
		self._path_to_db_id.get_or_add(entry.exec_path, PackedInt32Array()) as PackedInt32Array
	).append(
		entry.db_id
	)


## If entry is removed, remove corresponding db_id cache and drop table
func _on_entry_removed(entry: EntryManager.Entry) -> void:
	self._path_to_db_id[entry.exec_path].erase(entry.db_id)

	self._db.execute(_Query.drop_table % entry.db_id)
